#!/usr/bin/env python3
"""PreToolUse guard for Bash, the two limits the user keeps in every mode.

Deny any `git push` that reaches main or master: a refspec naming them, `--all`,
`--mirror`, or a push with no refspec (or `HEAD`) from a checkout on them. Pushes
to other branches, forced or not, pass. This holds on every machine.

Ask before merging a pull request: `gh pr merge` and `gh api` calls that merge
(REST merge endpoint, GraphQL merge or auto-merge mutations). With
CLAUDE_GUARD_ALLOW_MERGE=1 in this hook's own environment (the `env` of a local
settings.json), merges pass without asking. A variable typed in the command
itself does not count, so the default stays the safe one.

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
WRAPPERS = {"env", "command", "nohup", "time", "exec"}
MERGE_API = re.compile(r"pulls/\d+/merge\b|mergePullRequest|enablePullRequestAutoMerge")
MERGE_OPTIONS_WITH_VALUE = {
    "-b", "--body", "-F", "--body-file", "-t", "--subject", "-A", "--author-email",
    "--match-head-commit", "-R", "--repo",
}
FULL_SHA = re.compile(r"^[0-9a-fA-F]{40}$")
GH_TIMEOUT = 10
SEPARATORS = {"&&", "||", ";", "|", "&", "|&", ";;"}
ALLOW_MERGE_VARIABLE = "CLAUDE_GUARD_ALLOW_MERGE"


def merges_allowed():
    """True only when this process was started with the variable set to 1."""
    return os.environ.get(ALLOW_MERGE_VARIABLE) == "1"


def tokenize(command):
    lexer = shlex.shlex(command.replace("\n", " ; "), posix=True, punctuation_chars=";&|<>")
    lexer.whitespace_split = True
    try:
        return list(lexer)
    except ValueError:
        return command.split()


def segments(tokens):
    """Split on shell separators and drop redirections (`2>&1`, `> file`)."""
    current, skip_next = [], False
    for token in tokens:
        if skip_next:
            skip_next = False
        elif token in SEPARATORS:
            yield current
            current = []
        elif set(token) <= set("<>&"):
            if current and current[-1].isdigit():
                current.pop()
            skip_next = True
        else:
            current.append(token)
    yield current


def words(segment):
    while segment and (segment[0] in WRAPPERS or re.match(r"^\w+=", segment[0])):
        segment = segment[1:]
    return segment


def current_branch(directory):
    result = subprocess.run(
        ["git", "-C", directory, "symbolic-ref", "--quiet", "--short", "HEAD"],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def push_target(args, directory):
    """Return the protected branch this push reaches, or None."""
    positional = []
    skip_next = False
    for arg in args:
        if skip_next:
            skip_next = False
        elif arg in PUSH_EVERYTHING:
            return arg
        elif arg in PUSH_OPTIONS_WITH_VALUE:
            skip_next = True
        elif not arg.startswith("-"):
            positional.append(arg)
    refspecs = positional[1:]
    if not refspecs:
        refspecs = ["HEAD"]
    for refspec in refspecs:
        source, _, destination = refspec.lstrip("+").partition(":")
        target = destination or source
        if target in ("HEAD", "@"):
            target = current_branch(directory)
        target = target.removeprefix("refs/heads/")
        if target in PROTECTED:
            return target
    return None


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
    """Deny wins over ask, so every segment is checked before asking."""
    ask_reason = None
    for segment in segments(tokenize(command)):
        tokens = words(segment)
        if not tokens:
            continue
        program = os.path.basename(tokens[0])
        if program == "cd" and len(tokens) > 1:
            directory = os.path.join(directory, os.path.expanduser(tokens[1]))
        elif program == "gh" and "api" in tokens and MERGE_API.search(" ".join(tokens)):
            if not merges_allowed():
                ask_reason = ask_reason or (
                    "This gh api call merges a pull request; merging needs the user's OK."
                )
        elif program == "gh" and tokens[1:3] == ["pr", "merge"]:
            reason = check_merge(tokens[3:], directory)
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
                        git_directory = os.path.join(git_directory, os.path.expanduser(value))
            if rest and rest[0] == "push":
                target = push_target(rest[1:], git_directory)
                if target:
                    return "deny", f"Pushing to main is never allowed (this push reaches {target})."
    if ask_reason:
        return "ask", ask_reason
    return None, None


def main():
    payload = json.load(sys.stdin)
    command = payload.get("tool_input", {}).get("command", "")
    if "push" not in command and "merge" not in command and "Merge" not in command:
        return
    decision, reason = decide(command, payload.get("cwd") or os.getcwd())
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
