#!/usr/bin/env python3
"""PreToolUse guard for Bash and the desktop app's PR tool, the two limits the
user keeps in every mode.

Deny any `git push` that reaches main or master: a refspec naming them, `--all`,
`--mirror`, or a push with no refspec (or `HEAD`) from a checkout on them. The
checkout is the one in place when the push runs: an earlier `git checkout` or
`git switch` in the same command counts (`git checkout main && git push` is
denied, `git checkout -- <file>` keeps the branch), and a `cd` inside `( )` or
`$( )` ends with it, as in the shell. A refspec `$(git branch --show-current)`,
`$(git rev-parse --abbrev-ref HEAD)` or `$(git symbolic-ref --short HEAD)` is
the branch checked out where the shell runs it, and `$NAME` or `${NAME}` the
value of a literal `NAME=value` earlier in the command, which `( )` ends like a
`cd`. Pushes to other branches, forced or not, pass. This holds on every
machine. When the guard cannot tell which branch a push reaches, ask instead: a
refspec, branch name, `cd` or `git -C` target with any other `$` or a backtick,
or `cd -`; a push with no refspec (or `HEAD`) in a directory that is missing,
not a repository or on a detached HEAD, after a checkout it cannot follow (a
commit, `-`, `--detach`, a branch before `--`) or one in a directory it cannot
resolve, or in a repository an earlier `git clone` in the command creates.

Each command is matched after its leading keywords and wrappers (`(`, `{`, `!`,
`then`, `do`, `sudo`, `env`, `nice`, `command`, `time`, `timeout`, `stdbuf`,
`caffeinate`, ...). The string given to `bash|sh|zsh -c` is checked as a
command of its own, and so is the body of each `$( )` or backtick pair inside a
word (`echo "$(git push origin main)"`), with the checkouts of the whole line.
The bodies of the heredocs inside it are text, not commands, so the message of
`git commit -m "$(cat <<'EOF' ... EOF)"` is not checked as commands (except
that a pair of double quotes in it can leave a `$( )` of the text unquoted for
the lexer, which then gets checked and errs on the safe side); only the
substitutions in the body of a heredoc whose delimiter is unquoted are checked,
as the shell runs them.

Ask before merging a pull request: `gh pr merge`, `gh api` calls that merge
(REST merge endpoint, GraphQL merge or auto-merge mutations) and the desktop
app's auto-merge tool (mcp__ccd_pr__set_auto_merge). With
CLAUDE_GUARD_ALLOW_MERGE=1 in this hook's own environment (the `env` of a local
settings.json), merges pass without asking. A variable typed in the command
itself does not count, so the default stays the safe one. Other tools get no
decision.

Deny two `gh pr merge` mistakes, with or without that variable: `--delete-branch`
while open PRs are stacked on the head branch (GitHub closes them instead of
retargeting), and `--match-head-commit` with anything but a full 40-hex SHA. If
`gh` fails or times out, skip that check and warn.

Known limits. Outside `$( )`, each line of a heredoc body is checked as a
command, so a body line `git push origin main` is denied, and `gh api
.../merge -X GET` asks although it only reads. When quoting is unbalanced (an
odd `"` in a heredoc), the lines are lexed one by one, so the body lines of a
heredoc inside `$( )` are checked as commands too and can change the tracked
branch. All of these err on the safe side. `eval`, `xargs`, a backtick pair
split across words (`` echo `git push` ``), `env -S`, git aliases and `pushd`
are not parsed, so a push or merge run through them is not seen; nor is one in
a double-quoted word with spaces inside a quoted `$( )`, which shlex has split
(`"$(bash -c "git push")"` reads as `bash -c git`). A `git
checkout`, `git switch` or `NAME=value` is taken to succeed, even when `;` or
`||` would run the push after it failed, and other commands that change the
branch (`git branch -m`, `git rebase <base> <branch>`, `gh pr checkout`) are not
followed. A `cd` or `NAME=value` on the left of a pipe is treated as
persistent, although the shell runs it in a subshell. A push with no refspec is
taken to push the current branch to the same name, as `push.default=current` in
`git/.gitconfig_base` does; the `upstream` mode, which can push to another
name, is not modelled.
"""

import io
import json
import os
import re
import shlex
import subprocess
import sys

PROTECTED = {"main", "master"}
GIT_OPTIONS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}
PUSH_OPTIONS_WITH_VALUE = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
PUSH_EVERYTHING = {"--all", "--mirror", "--branches"}
# Words that can start a command without being the program
PREFIX_WORDS = {"(", "{", "!", "if", "then", "elif", "else", "while", "until", "do"}
# Programs that run the rest of the line as a command, with their options that take a value
WRAPPERS = {
    "env": {"-u", "--unset", "-C", "--chdir", "-P", "-S", "--split-string"},
    "sudo": {
        "-u", "--user", "-g", "--group", "-p", "--prompt", "-C", "--close-from",
        "-D", "--chdir", "-R", "--chroot", "-r", "--role", "-t", "--type",
        "-T", "--command-timeout", "-U", "--other-user",
    },
    "nice": {"-n", "--adjustment"},
    "command": set(),
    "exec": {"-a"},
    "time": {"-o", "--output", "-f", "--format"},
    "nohup": set(),
    "timeout": {"-s", "--signal", "-k", "--kill-after"},
    "gtimeout": {"-s", "--signal", "-k", "--kill-after"},
    "stdbuf": {"-i", "--input", "-o", "--output", "-e", "--error"},
    "caffeinate": {"-t", "-w"},
}
# Wrappers with positional arguments before the command: timeout's duration
WRAPPER_ARGUMENTS = {"timeout": 1, "gtimeout": 1}
# `git checkout|switch` options that name the branch they create
CREATE_OPTIONS = {
    "checkout": {"-b", "-B", "--orphan"},
    "switch": {"-c", "-C", "--create", "--force-create", "--orphan"},
}
TRACK_OPTIONS = {"-t", "--track"}
# `git checkout|switch` options that leave the branch to the other arguments
CHECKOUT_FLAGS = {
    "-q", "--quiet", "-f", "--force", "-m", "--merge", "-l", "--progress", "--no-progress",
    "--no-track", "--guess", "--no-guess", "--recurse-submodules", "--no-recurse-submodules",
    "--overwrite-ignore", "--no-overwrite-ignore", "--ignore-other-worktrees", "--discard-changes",
}
CLONE_OPTIONS_WITH_VALUE = {
    "-o", "--origin", "-b", "--branch", "-u", "--upload-pack", "--reference",
    "--reference-if-able", "--separate-git-dir", "--depth", "--shallow-since",
    "--shallow-exclude", "-c", "--config", "--server-option", "-j", "--jobs", "--filter",
    "--bundle-uri", "--template", "--ref-format",
}
SHELLS = {"bash", "sh", "zsh", "dash", "ksh"}
SHELL_OPTIONS_WITH_VALUE = {"-o", "+o", "-O", "+O", "--rcfile", "--init-file"}
GH_PR_OPTIONS_WITH_VALUE = {"-R", "--repo"}
MERGE_TOOL = "mcp__ccd_pr__set_auto_merge"
MERGE_API = re.compile(r"pulls/\d+/merge\b|mergePullRequest|enablePullRequestAutoMerge")
MERGE_OPTIONS_WITH_VALUE = {
    "-b", "--body", "-F", "--body-file", "-t", "--subject", "-A", "--author-email",
    "--match-head-commit", "-R", "--repo",
}
FULL_SHA = re.compile(r"^[0-9a-fA-F]{40}$")
GH_TIMEOUT = 10
PUNCTUATION = ";&|<>()"
ROUGH_TOKEN = re.compile(r"[;&|<>()]+|[^\s;&|<>()]+")
ALLOW_MERGE_VARIABLE = "CLAUDE_GUARD_ALLOW_MERGE"
# The substitutions that print the branch checked out where the shell runs them,
# and the word that stands for them once found: it holds `$`, so anywhere but a
# push refspec it stays a value the guard cannot know.
CURRENT_BRANCH_SUBSTITUTION = re.compile(
    r"\$\(\s*git\s+(?:branch\s+--show-current|rev-parse\s+--abbrev-ref\s+HEAD"
    r"|symbolic-ref\s+--short\s+HEAD)\s*\)"
)
CURRENT_BRANCH = "$\3current-branch\3"
NAME = r"[A-Za-z_]\w*"
VARIABLE = re.compile(rf"\$(?:\{{({NAME})\}}|({NAME}))")
# A heredoc operator (not `<<<`) and its delimiter, quoted when the body is literal
HEREDOC = re.compile(r"<<-?[ \t]*(\\?)(['\"]?)([^\s'\"();&|<>`]+)\2")
# Returned by checkout_branch for a checkout that keeps the branch
KEEP = object()
SINGLE_QUOTED = str.maketrans("$`", "\1\2")
UNMASKED = str.maketrans("\1\2", "$`")


def merges_allowed():
    """True only when this process was started with the variable set to 1."""
    return os.environ.get(ALLOW_MERGE_VARIABLE) == "1"


class Word(str):
    """A token, and in `masked` the same token with the `$` and backticks it had
    inside single quotes, which the shell keeps literal, hidden."""

    def __new__(cls, text, masked):
        word = super().__new__(cls, text)
        word.masked = masked
        return word


class SingleQuoteMask(io.StringIO):
    """Input for shlex that hides `$` and backticks inside single quotes."""

    lexer = None

    def read(self, size=-1):
        text = super().read(size)
        return text.translate(SINGLE_QUOTED) if self.lexer.state == "'" else text


def lex(text, mask=False):
    stream = SingleQuoteMask(text) if mask else text
    lexer = shlex.shlex(stream, posix=True, punctuation_chars=PUNCTUATION)
    lexer.whitespace_split = True
    if mask:
        stream.lexer = lexer
    return list(lexer)


def words_of(text):
    """The tokens of `text` as Words; masking changes no token boundary."""
    return [Word(token, masked) for token, masked in zip(lex(text), lex(text, mask=True))]


def tokenize(command):
    try:
        return words_of(command.replace("\n", " ; "))
    except ValueError:
        # An unbalanced quote, such as an apostrophe in a heredoc body: lex each
        # line on its own (roughly when that fails too), so the commands on the
        # other lines are still checked.
        tokens = []
        for line in command.splitlines():
            try:
                tokens += words_of(line)
            except ValueError:
                rough = (token.replace("'", "").replace('"', "") for token in ROUGH_TOKEN.findall(line))
                tokens += [token for token in rough if token]
            tokens.append(";")
        return tokens


def segments(tokens):
    """Split where a new command starts and drop redirections (`2>&1`, `> file`).
    Yield each command with the separator before it ("" for the first)."""
    current, before, skip_next = [], "", False
    for token in tokens:
        if skip_next:
            skip_next = False
        elif token and set(token) <= set(PUNCTUATION):
            if "(" in token or ")" in token or not set(token) & set("<>"):
                # `;`, `&&`, `|`, `&`, a subshell or a command substitution
                yield before, current
                before, current = token, []
            else:
                if current and current[-1].isdigit():
                    current.pop()
                skip_next = True
        else:
            current.append(token)
    yield before, current


def words(segment):
    """The command a segment runs, without leading keywords, assignments and wrappers."""
    tokens = list(segment)
    while tokens:
        if tokens[0] in PREFIX_WORDS or re.match(r"^\w+=", tokens[0]):
            tokens = tokens[1:]
            continue
        wrapper = os.path.basename(tokens[0])
        with_value = WRAPPERS.get(wrapper)
        if with_value is None:
            break
        tokens = tokens[1:]
        while tokens and tokens[0].startswith("-"):
            option = tokens.pop(0)
            if option == "--":
                break
            if option in with_value and tokens:
                tokens.pop(0)
        tokens = tokens[WRAPPER_ARGUMENTS.get(wrapper, 0):]
    return tokens


def expands(word):
    """True when the shell rewrites `word` ($VAR, $(...), a backtick), so the
    guard cannot know its value."""
    return "$" in word or "`" in word


def skip_heredoc(text, index, delimiter, expanded):
    """Index after the heredoc body that starts at `text[index]` and ends with a
    `delimiter` line. Each body line goes to `expanded` unless it is None."""
    while index < len(text):
        end = text.find("\n", index)
        end = len(text) if end < 0 else end
        line = text[index:end]
        word = line.replace("\0", " ").strip()
        if word == delimiter:
            return end + 1
        if word.startswith(delimiter + ")"):
            # `EOF)`: the heredoc and the substitution end on one line
            return index + line.index(delimiter) + len(delimiter)
        if expanded is not None:
            expanded.append(line)
        index = end + 1
    return index


def substitution_body(text, start):
    """Read the `$(` substitution whose body starts at `text[start]`. Return its
    body without the bodies of its heredocs, the index after its `)` (the end of
    `text` when it has none) and the heredoc bodies the shell expands (those with
    an unquoted delimiter), whose own substitutions run."""
    body, expanded, heredocs = [], [], []
    depth, index, quoted = 1, start, False
    while index < len(text):
        char = text[index]
        if quoted:
            quoted = char != "'"
        elif char == "'":
            quoted = True
        elif char == "\\":
            body.append(text[index:index + 2])
            index += 2
            continue
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return "".join(body), index + 1, "\n".join(expanded)
        elif char == "<" and text[index - 1] != "<" and (heredoc := HEREDOC.match(text, index)):
            heredocs.append((heredoc[3], not (heredoc[1] or heredoc[2])))
            body.append(heredoc[0])
            index = heredoc.end()
            continue
        elif char == "\n" and heredocs:
            body.append(char)
            index += 1
            for delimiter, unquoted in heredocs:
                index = skip_heredoc(text, index, delimiter, expanded if unquoted else None)
            heredocs = []
            continue
        body.append(char)
        index += 1
    return "".join(body), len(text), "\n".join(expanded)


def substitutions(text):
    """Bodies of the `$( )` and backtick substitutions in `text`, the words of one
    command as shlex left them, joined by NUL. A quoted `"$( )"` is one word
    there; an unquoted one was split at its parentheses, which `decide` follows."""
    text = text.replace(" ; ", "\n")  # tokenize turned each line break into ` ; `
    index = 0
    while index < len(text):
        if text.startswith("$(", index):
            body, index, expanded = substitution_body(text, index + 2)
            yield body.replace("\0", " ").translate(UNMASKED)
            yield from substitutions(expanded)
        elif text[index] == "`" and text[index - 1:index] != "\\":
            # a pair inside one word: an unquoted one with spaces is split across words
            end = index + 1
            while end < len(text) and text[end] not in "`\0":
                end += 2 if text[end] == "\\" else 1
            if end < len(text) and text[end] == "`":
                yield text[index + 1:end].translate(UNMASKED)
                index = end + 1
            else:
                index += 1
        else:
            index += 1


def track_variables(segment, variables):
    """Keep the literal values that a command of bare `NAME=value` words assigns,
    and forget a name that any other command may set (`read NAME`, `export
    NAME=...`, `for NAME in`, or `NAME=value command`, whose `$NAME` is still
    the old value)."""
    tokens = list(segment)
    while tokens and tokens[0] in PREFIX_WORDS:
        tokens.pop(0)
    if tokens and all(re.match(rf"{NAME}=", token) for token in tokens):
        for token in tokens:
            name, _, value = token.partition("=")
            if value and not expands(value):
                variables[name] = value
            else:
                variables.pop(name, None)
        return
    for token in segment:
        match = re.match(rf"({NAME})(?:\+?=|\[|$)", token)
        if match:
            variables.pop(match[1], None)


def expand_variables(word, variables):
    """`word` with each `$NAME` or `${NAME}` whose literal value is known replaced by it."""
    return VARIABLE.sub(lambda match: variables.get(match[1] or match[2], match[0]), word)


def resolve_directory(directory, target):
    """`target` seen from `directory`, or None when either cannot be known."""
    if target == "-" or expands(target):
        return None
    target = os.path.expanduser(target)
    if os.path.isabs(target):
        return target
    if directory is None:
        return None
    return os.path.join(directory, target)


def shell_script(args):
    """The command string of `bash|sh|zsh -c <string>`, or None."""
    reads_string, skip_next = False, False
    for arg in args:
        if skip_next:
            skip_next = False
        elif arg in SHELL_OPTIONS_WITH_VALUE:
            skip_next = True
        elif re.match(r"^-[A-Za-z]*c[A-Za-z]*$", arg):
            reads_string = True
        elif not arg.startswith(("-", "+")):
            return arg if reads_string else None
    return None


def gh_pr_merge_args(args):
    """Arguments of `gh pr merge`, flags given before `merge` included, or None."""
    flags, positional, skip_next = [], [], False
    for index, arg in enumerate(args):
        if skip_next:
            flags.append(arg)
            skip_next = False
        elif arg.startswith("-"):
            flags.append(arg)
            skip_next = arg in GH_PR_OPTIONS_WITH_VALUE
        else:
            positional.append(arg)
            if len(positional) == 2:
                return flags + args[index + 1:] if positional == ["pr", "merge"] else None
    return None


def git_output(directory, *args):
    """Output of `git -C directory args`, or None when git fails."""
    try:
        result = subprocess.run(["git", "-C", directory, *args], capture_output=True, text=True)
    except OSError:
        return None
    return result.stdout.strip() if result.returncode == 0 else None


def current_branch(directory):
    """The branch checked out in `directory`, or None when there is none to read
    (a missing directory, not a repository, a detached HEAD)."""
    return git_output(directory, "symbolic-ref", "--quiet", "--short", "HEAD") or None


def repository_root(directory):
    root = git_output(directory, "rev-parse", "--show-toplevel")
    return os.path.realpath(root) if root else None


def is_branch(directory, name):
    """True when `git checkout <name>` in `directory` switches to a branch: a
    local one, or a remote one it creates the local branch from."""
    refs = git_output(directory, "for-each-ref", "--format=%(refname)",
                      f"refs/heads/{name}", f"refs/remotes/*/{name}") or ""
    pattern = re.compile(rf"refs/heads/{re.escape(name)}|refs/remotes/[^/]+/{re.escape(name)}")
    return any(pattern.fullmatch(ref) for ref in refs.splitlines())


class Checkouts:
    """Branches that earlier commands in the line check out, by repository. A
    checkout changes the repository on disk, so unlike `cd` it outlasts a
    subshell or a nested shell."""

    def __init__(self):
        self.branches = {}  # real path -> branch, or None when it cannot be known
        self.anywhere = False  # a checkout or clone ran where the guard cannot tell

    def checkout(self, directory, branch):
        """`branch` (None when unknown) is now checked out in `directory`'s repository."""
        if directory is None:
            self.unknown_everywhere()
        else:
            self.branches[repository_root(directory) or os.path.realpath(directory)] = branch

    def clone(self, directory):
        """`directory` now holds a new repository whose branch is unknown."""
        if directory is None:
            self.unknown_everywhere()
        else:
            self.branches[os.path.realpath(directory)] = None

    def unknown_everywhere(self):
        self.branches.clear()
        self.anywhere = True

    def branch(self, directory):
        """The branch checked out in `directory` once the earlier commands ran,
        or None when it cannot be known."""
        if directory is None:
            return None
        path, root = os.path.realpath(directory), repository_root(directory)
        while True:
            if path in self.branches:
                return self.branches[path]
            parent = os.path.dirname(path)
            if path == root or parent == path:
                break
            path = parent
        return None if self.anywhere else current_branch(directory)


def checkout_branch(command, args, directory):
    """The branch `git checkout|switch args` leaves checked out in `directory`
    (None when that cannot be known), None for a form the guard does not follow
    (a commit, `-`, `--detach`, a branch before `--`, an unknown option), or KEEP
    for `git checkout -- <file>`, which restores files and keeps the branch."""
    creates = CREATE_OPTIONS[command]
    created, positional, tracks = None, [], False
    index = 0
    while index < len(args):
        arg = args[index]
        index += 1
        option, has_value, value = arg.partition("=")
        if arg == "--" and command == "checkout" and not positional and created is None and not tracks:
            return KEEP
        if arg in creates:
            if index == len(args):
                return None
            created = args[index]
            index += 1
        elif option in creates and option.startswith("--") and has_value:
            created = value
        elif arg[:2] in creates and len(arg) > 2:
            created = arg[2:]
        elif option in TRACK_OPTIONS:
            tracks = True
        elif arg in CHECKOUT_FLAGS or option == "--conflict":
            continue
        elif arg.startswith("-"):
            return None
        else:
            positional.append(arg)
    if created is not None:
        # the one positional argument, if any, is the start point
        return created if len(positional) <= 1 and not expands(created) else None
    if tracks or len(positional) != 1 or expands(positional[0]):
        return None
    name = positional[0]
    # `git switch` only takes branches; `git checkout` also takes files and commits
    if command == "switch" or name in PROTECTED or (directory is not None and is_branch(directory, name)):
        return name
    return None


def clone_directory(args, directory):
    """The directory `git clone args` creates, seen from `directory`, or None."""
    positional, skip_next, bare = [], False, False
    for arg in args:
        if skip_next:
            skip_next = False
        elif arg in CLONE_OPTIONS_WITH_VALUE:
            skip_next = True
        elif arg in ("--bare", "--mirror"):
            bare = True
        elif not arg.startswith("-"):
            positional.append(arg)
    if len(positional) > 1:
        return resolve_directory(directory, positional[1])
    if not positional:
        return None
    # git's own default: the last part of the URL without `.git`
    name = re.split(r"[/:]", re.sub(r"(/\.git)?/*$", "", positional[0]))[-1]
    name = re.sub(r"\.(git|bundle)$", "", name)
    return resolve_directory(directory, name + ".git" if bare else name) if name else None


def push_target(args, git_directory, shell_directory, checkouts, variables):
    """Return (the protected branch this push reaches or None, whether a branch
    it may reach cannot be known). `HEAD` is the branch in `git_directory` (the
    one `git -C` names), `$(git branch --show-current)` the one in
    `shell_directory`, where the shell runs it."""
    positional = []
    skip_next = False
    for arg in args:
        if skip_next:
            skip_next = False
        elif arg in PUSH_EVERYTHING:
            return arg, False
        elif arg in PUSH_OPTIONS_WITH_VALUE:
            skip_next = True
        elif not arg.startswith("-"):
            positional.append(arg)
    refspecs = positional[1:]
    if not refspecs:
        refspecs = ["HEAD"]
    unknown = False
    for refspec in refspecs:
        expanded = expand_variables(refspec, variables)
        if "${" in expanded:
            # An unresolved ${NAME:-default} holds a colon of its own, so
            # splitting the refspec at it would invent a destination.
            unknown = True
            continue
        source, _, destination = expanded.lstrip("+").partition(":")
        target = destination or source
        if target == CURRENT_BRANCH:
            target = checkouts.branch(shell_directory)
        elif target in ("HEAD", "@"):
            target = checkouts.branch(git_directory)
        elif expands(target):
            target = None
        if target is None:
            unknown = True
            continue
        target = target.removeprefix("refs/heads/")
        if target in PROTECTED:
            return target, False
    return None, unknown


def option_value(args, names):
    """Value of the first option in `names`, as `--opt value` or `--opt=value`."""
    for index, arg in enumerate(args):
        for name in names:
            if arg == name and index + 1 < len(args):
                return args[index + 1]
            if arg.startswith(name + "=") and name.startswith("--"):
                return arg.split("=", 1)[1]
    return None


def merge_selector(args):
    """First positional argument of `gh pr merge` (number, URL or branch), or None."""
    skip_next = False
    for arg in args:
        if skip_next:
            skip_next = False
        elif arg in MERGE_OPTIONS_WITH_VALUE:
            skip_next = True
        elif not arg.startswith("-"):
            return arg
    return None


def gh_json(args, directory):
    result = subprocess.run(
        ["gh", *args], capture_output=True, text=True, timeout=GH_TIMEOUT, cwd=directory
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"gh exited {result.returncode}")
    return json.loads(result.stdout)


def check_merge(args, directory):
    """Return a deny reason for a risky `gh pr merge`, or None."""
    sha = option_value(args, ["--match-head-commit"])
    if sha is not None and not FULL_SHA.match(sha):
        return (
            f"--match-head-commit needs the full 40-hex SHA, got '{sha}'. Read it with: "
            "gh pr view <n> --json headRefOid -q .headRefOid"
        )
    if "--delete-branch" not in args and "-d" not in args:
        return None
    selector = merge_selector(args)
    repo = option_value(args, ["-R", "--repo"])
    repo_args = ["-R", repo] if repo else []
    try:
        pr = gh_json(
            ["pr", "view", *([selector] if selector else []), *repo_args,
             "--json", "number,headRefName,baseRefName"],
            directory,
        )
        stacked = gh_json(
            ["pr", "list", "--base", pr["headRefName"], "--state", "open", *repo_args,
             "--json", "number"],
            directory,
        )
    except Exception as error:
        print(f"guard-main-and-merge: could not check stacked PRs ({error}); skipping that check", file=sys.stderr)
        return None
    if not stacked:
        return None
    numbers = ", ".join(f"#{item['number']}" for item in stacked)
    base = pr["baseRefName"]
    retarget = "; ".join(f"gh pr edit {item['number']} --base {base}" for item in stacked)
    return (
        f"PR #{pr['number']}: open PRs are stacked on its head branch '{pr['headRefName']}' "
        f"({numbers}). --delete-branch would make GitHub close them instead of retargeting. "
        f"Retarget them first: {retarget}"
    )


def decide(command, directory, checkouts=None, variables=None):
    """Deny wins over ask, so every segment is checked before asking.
    `directory` is None once a `cd` makes it unknown. `variables` holds the
    literal values of the shell variables assigned so far."""
    checkouts = Checkouts() if checkouts is None else checkouts
    variables = {} if variables is None else variables
    ask_reason = None
    outer = []  # the directories and variables to return to when a subshell ends
    command = CURRENT_BRANCH_SUBSTITUTION.sub(CURRENT_BRANCH, command)
    for separator, segment in segments(tokenize(command)):
        for char in separator:
            if char == "(":
                outer.append((directory, dict(variables)))
            elif char == ")" and outer:
                directory, variables = outer.pop()
        # The shell runs the substitutions in a command's words before the command
        for body in substitutions("\0".join(getattr(token, "masked", token) for token in segment)):
            decision, reason = decide(body, directory, checkouts, dict(variables))
            if decision == "deny":
                return decision, reason
            ask_reason = ask_reason or reason
        track_variables(segment, variables)
        tokens = words(segment)
        if not tokens:
            continue
        program = os.path.basename(tokens[0])
        if program == "cd":
            targets = [arg for arg in tokens[1:] if arg == "-" or not arg.startswith("-")]
            directory = resolve_directory(directory, targets[0] if targets else "~")
        elif program in SHELLS:
            script = shell_script(tokens[1:])
            if script is not None:
                # a new shell does not see the variables this one did not export
                decision, reason = decide(script, directory, checkouts, {})
                if decision == "deny":
                    return decision, reason
                ask_reason = ask_reason or reason
        elif program == "gh" and "api" in tokens and MERGE_API.search(" ".join(tokens)):
            if not merges_allowed():
                ask_reason = ask_reason or (
                    "This gh api call merges a pull request; merging needs the user's OK."
                )
        elif program == "gh":
            merge_args = gh_pr_merge_args(tokens[1:])
            if merge_args is None:
                continue
            reason = check_merge(merge_args, directory)
            if reason:
                return "deny", reason
            if not merges_allowed():
                ask_reason = ask_reason or "Merging a pull request needs the user's OK."
        elif program == "git":
            rest = tokens[1:]
            git_directory = directory
            while rest and rest[0].startswith("-"):
                option = rest.pop(0)
                if option in GIT_OPTIONS_WITH_VALUE and rest:
                    value = rest.pop(0)
                    if option == "-C":
                        git_directory = resolve_directory(git_directory, value)
            subcommand = rest[0] if rest else None
            if subcommand == "push":
                target, unknown = push_target(rest[1:], git_directory, directory, checkouts, variables)
                if target:
                    return "deny", f"Pushing to main is never allowed (this push reaches {target})."
                if unknown:
                    ask_reason = ask_reason or (
                        "The guard cannot tell which branch this git push runs on (a directory "
                        "it cannot resolve, a detached HEAD, or a checkout or clone it cannot "
                        "follow), so it cannot tell whether the push reaches main; pushing "
                        "needs the user's OK."
                    )
            elif subcommand in CREATE_OPTIONS:
                branch = checkout_branch(subcommand, rest[1:], git_directory)
                if branch is not KEEP:
                    checkouts.checkout(git_directory, branch)
            elif subcommand == "clone":
                checkouts.clone(clone_directory(rest[1:], git_directory))
    if ask_reason:
        return "ask", ask_reason
    return None, None


def main():
    payload = json.load(sys.stdin)
    tool = payload.get("tool_name", "Bash")
    if tool == MERGE_TOOL:
        if merges_allowed():
            return
        decision, reason = "ask", "Auto-merge merges the pull request; merging needs the user's OK."
    elif tool == "Bash":
        command = payload.get("tool_input", {}).get("command", "")
        if "push" not in command and "merge" not in command and "Merge" not in command:
            return
        decision, reason = decide(command, payload.get("cwd") or os.getcwd())
    else:
        return
    if decision:
        print(
            json.dumps(
                {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": decision,
                        "permissionDecisionReason": reason,
                    }
                }
            )
        )


main()
