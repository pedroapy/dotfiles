#!/usr/bin/env python3
"""PreToolUse guard for Bash and the desktop app's PR tool, the two limits the
user keeps in every mode.

Deny any `git push` that reaches main or master: a refspec naming them, `--all`,
`--mirror`, or a push with no refspec (or `HEAD`) from a checkout on them. Pushes
to other branches, forced or not, pass. This holds on every machine. When the
push needs the current branch but runs in a directory that cannot be known (a
`cd` or `git -C` target with `$` or a backtick, or `cd -`), ask instead.

Each command is matched after its leading keywords and wrappers (`(`, `{`, `!`,
`then`, `do`, `sudo`, `env`, `nice`, `command`, `time`, ...), and the string
given to `bash|sh|zsh -c` is checked as a command of its own.

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
"""

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


def merges_allowed():
    """True only when this process was started with the variable set to 1."""
    return os.environ.get(ALLOW_MERGE_VARIABLE) == "1"


def lex(text):
    lexer = shlex.shlex(text, posix=True, punctuation_chars=PUNCTUATION)
    lexer.whitespace_split = True
    return list(lexer)


def tokenize(command):
    try:
        return lex(command.replace("\n", " ; "))
    except ValueError:
        # An unbalanced quote, such as an apostrophe in a heredoc body: lex each
        # line on its own (roughly when that fails too), so the commands on the
        # other lines are still checked.
        tokens = []
        for line in command.splitlines():
            try:
                tokens += lex(line)
            except ValueError:
                rough = (token.replace("'", "").replace('"', "") for token in ROUGH_TOKEN.findall(line))
                tokens += [token for token in rough if token]
            tokens.append(";")
        return tokens


def segments(tokens):
    """Split where a new command starts and drop redirections (`2>&1`, `> file`)."""
    current, skip_next = [], False
    for token in tokens:
        if skip_next:
            skip_next = False
        elif token and set(token) <= set(PUNCTUATION):
            if "(" in token or ")" in token or not set(token) & set("<>"):
                # `;`, `&&`, `|`, `&`, a subshell or a command substitution
                yield current
                current = []
            else:
                if current and current[-1].isdigit():
                    current.pop()
                skip_next = True
        else:
            current.append(token)
    yield current


def words(segment):
    """The command a segment runs, without leading keywords, assignments and wrappers."""
    tokens = list(segment)
    while tokens:
        if tokens[0] in PREFIX_WORDS or re.match(r"^\w+=", tokens[0]):
            tokens = tokens[1:]
            continue
        with_value = WRAPPERS.get(os.path.basename(tokens[0]))
        if with_value is None:
            break
        tokens = tokens[1:]
        while tokens and tokens[0].startswith("-"):
            option = tokens.pop(0)
            if option == "--":
                break
            if option in with_value and tokens:
                tokens.pop(0)
    return tokens


def resolve_directory(directory, target):
    """`target` seen from `directory`, or None when either cannot be known."""
    if target == "-" or "$" in target or "`" in target:
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


def current_branch(directory):
    result = subprocess.run(
        ["git", "-C", directory, "symbolic-ref", "--quiet", "--short", "HEAD"],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def push_target(args, directory):
    """Return (the protected branch this push reaches or None, whether the
    current branch was needed but `directory` is unknown)."""
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
        source, _, destination = refspec.lstrip("+").partition(":")
        target = destination or source
        if target in ("HEAD", "@"):
            if directory is None:
                unknown = True
                continue
            target = current_branch(directory)
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


def decide(command, directory):
    """Deny wins over ask, so every segment is checked before asking.
    `directory` is None once a `cd` makes it unknown."""
    ask_reason = None
    for segment in segments(tokenize(command)):
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
                decision, reason = decide(script, directory)
                if decision == "deny":
                    return decision, reason
                if decision == "ask":
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
            if rest and rest[0] == "push":
                target, unknown = push_target(rest[1:], git_directory)
                if target:
                    return "deny", f"Pushing to main is never allowed (this push reaches {target})."
                if unknown:
                    ask_reason = ask_reason or (
                        "This git push runs in a directory the guard cannot resolve, so it "
                        "cannot tell whether the push reaches main; pushing needs the user's OK."
                    )
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
