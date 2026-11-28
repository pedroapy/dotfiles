#!/usr/bin/env bash
# Cases for guard-main-and-merge.py and its wiring in config/claude-settings.json.
# Run: bash claude/hooks/tests/guard-main-and-merge-test.sh
# `gh` is a fake on PATH (FAKE_GH_MODE: stacked | clean | fail); GitHub is never called.
# Cases run with cwd /tmp unless CHECK_CWD is set, and as the Bash tool unless
# CHECK_TOOL names another one.
HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/guard-main-and-merge.py"
SETTINGS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/config/claude-settings.json"
# Start from the default (variable missing), whatever the calling shell has.
unset CLAUDE_GUARD_ALLOW_MERGE
fail=0
bin=$(mktemp -d); trap 'rm -rf "$bin"' EXIT
cat >"$bin/gh" <<'GH'
#!/usr/bin/env bash
echo "$*" >>"$FAKE_GH_LOG"
[ "$FAKE_GH_MODE" = fail ] && { echo "boom" >&2; exit 1; }
case "$1 $2" in
  "pr view") echo '{"number":7,"headRefName":"feat/base","baseRefName":"main"}' ;;
  "pr list") [ "$FAKE_GH_MODE" = stacked ] && echo '[{"number":8},{"number":9}]' || echo '[]' ;;
esac
GH
chmod +x "$bin/gh"
export FAKE_GH_LOG="$bin/calls.log"
check() { # expected mode command [stderr-substring]
  local expected=$1 mode=$2 cmd=$3 want_err=$4 out rc got err
  : >"$FAKE_GH_LOG"
  out=$(jq -cn --arg t "${CHECK_TOOL:-Bash}" --arg c "$cmd" --arg d "${CHECK_CWD:-/tmp}" \
    '{tool_name:$t, tool_input:{command:$c}, cwd:$d}' |
    PATH="$bin:$PATH" FAKE_GH_MODE=$mode python3 -I "$HOOK" 2>"$bin/err")
  rc=$?
  got=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null)
  [ -z "$got" ] && got=allow
  err=$(cat "$bin/err")
  local label="${CLAUDE_GUARD_ALLOW_MERGE+ALLOW_MERGE=$CLAUDE_GUARD_ALLOW_MERGE }${CHECK_TOOL:+[$CHECK_TOOL] }${CHECK_CWD:+[in ${CHECK_CWD##*/}] }"
  if [ "$rc" = 0 ] && [ "$got" = "$expected" ] && { [ -z "$want_err" ] || [[ $err == *"$want_err"* ]]; }; then
    echo "ok   $expected  $mode  $label$cmd"
  else echo "FAIL want $expected got $got (exit $rc)  $mode  $label$cmd  $out  $err"; fail=1; fi
}
# Same check with CLAUDE_GUARD_ALLOW_MERGE=1 in the hook's environment.
check_allowing() { CLAUDE_GUARD_ALLOW_MERGE=1 check "$@"; }
FULL=0123456789abcdef0123456789abcdef01234567

# Merging asks by default.
check ask   clean   'gh pr merge 7 --squash'
check ask   clean   'gh pr merge 7 --squash --delete-branch'
check ask   clean   "gh pr merge 7 --squash --match-head-commit $FULL"
check ask   clean   'gh api -X PUT repos/o/r/pulls/1/merge'
check ask   fail    'gh pr merge 7 --squash --delete-branch' 'skipping'
# Only the hook's own environment counts, not a variable in the command.
check ask   clean   'CLAUDE_GUARD_ALLOW_MERGE=1 gh pr merge 7 --squash'
check ask   clean   'env CLAUDE_GUARD_ALLOW_MERGE=1 gh pr merge 7 --squash'
check ask   clean   'export CLAUDE_GUARD_ALLOW_MERGE=1; gh pr merge 7 --squash'
CLAUDE_GUARD_ALLOW_MERGE=0 check ask clean 'gh pr merge 7 --squash'
CLAUDE_GUARD_ALLOW_MERGE=true check ask clean 'gh pr merge 7 --squash'
# A push to main later in the command is still denied, not just asked.
check deny  clean   'gh pr merge 7 --squash && git push origin main'
check deny  clean   'gh api -X PUT repos/o/r/pulls/1/merge; git push origin main'

# With the variable set, merges pass.
check_allowing allow clean   'gh pr merge 7 --squash'
check_allowing allow clean   'gh pr merge 7 --squash --delete-branch'
check_allowing allow stacked 'gh pr merge 7 --squash'
check_allowing allow clean   'gh api -X PUT repos/o/r/pulls/1/merge'
check_allowing allow clean   'gh api graphql -f query="mutation { mergePullRequest(input: {}) { clientMutationId } }"'
# gh unreachable: skip the stacked-PR check with a warning.
check_allowing allow fail    'gh pr merge 7 --squash --delete-branch' 'skipping'
check_allowing allow clean   "gh pr merge 7 --squash --match-head-commit $FULL"
check_allowing allow clean   "gh pr merge 7 --squash --delete-branch --match-head-commit $FULL"
# ...but pushes to main stay blocked.
check_allowing deny  clean   'git push origin main'
check_allowing deny  clean   'git push --all origin'
check_allowing deny  clean   'gh pr merge 7 --squash && git push origin main'

# Stacked PRs and short SHAs are denied with or without the variable.
check deny  stacked 'gh pr merge 7 --squash --delete-branch'
check deny  stacked 'gh pr merge -d --squash'
check deny  stacked 'gh pr merge https://github.com/o/r/pull/7 --delete-branch'
check deny  clean   'gh pr merge 7 --squash --match-head-commit a1f789c'
check deny  clean   'gh pr merge 7 --squash --match-head-commit=a1f789c89a1'
check deny  stacked "gh pr merge 7 --squash --delete-branch --match-head-commit $FULL"
check_allowing deny stacked 'gh pr merge 7 --squash --delete-branch'
check_allowing deny clean   'gh pr merge 7 --squash --match-head-commit a1f789c'

# Reason texts and gh calls.
out=$(jq -cn --arg c 'gh pr merge 7 --delete-branch' '{tool_input:{command:$c},cwd:"/tmp"}' |
  PATH="$bin:$PATH" FAKE_GH_MODE=stacked python3 -I "$HOOK")
if [[ $out == *"#8, #9"* && $out == *"gh pr edit 8 --base main"* ]]; then
  echo "ok   reason lists PRs and retarget command"
else echo "FAIL reason: $out"; fail=1; fi
out=$(jq -cn --arg c 'gh pr merge 7 --squash' '{tool_input:{command:$c},cwd:"/tmp"}' |
  PATH="$bin:$PATH" FAKE_GH_MODE=clean python3 -I "$HOOK")
if [[ $out == *"the user's OK"* ]]; then
  echo "ok   ask reason names the user"
else echo "FAIL ask reason: $out"; fail=1; fi

# Keywords, wrappers and nested shells in front of a push to main do not hide it.
# shellcheck disable=SC2016 # the $(...) is the command under test
for cmd in \
  '(git push origin main)' \
  '{ git push origin main; }' \
  'if true; then git push origin main; fi' \
  'if git push origin main; then :; fi' \
  'if false; then :; else git push origin main; fi' \
  'for x in a; do git push origin main; done' \
  'while true; do git push origin main; done' \
  'until false; do git push origin main; done' \
  '! git push origin main' \
  'true || ! git push origin main' \
  'sudo git push origin main' \
  'sudo -u me git push origin main' \
  'env -i git push origin main' \
  'env -u HOME FOO=1 git push origin main' \
  'nice git push origin main' \
  'nice -n 5 git push origin main' \
  'command git push origin main' \
  'exec git push origin main' \
  'time -p git push origin main' \
  'x=$(git push origin main)' \
  'bash -c "git push origin main"' \
  'bash -lc "git push origin main"' \
  'sh -c "git push origin main"' \
  'zsh -c "git push origin main"' \
  '/bin/bash -o pipefail -c "cd /tmp && git push origin main"' \
  'sudo bash -c "git push origin main"' \
  'timeout 60 git push origin main' \
  'timeout -s KILL -k 5 60 git push origin main' \
  'timeout --foreground --kill-after=5 1m git push origin main' \
  'gtimeout 60 git push origin main' \
  'stdbuf -oL git push origin main' \
  'stdbuf -o L -e 0 git push origin main' \
  'caffeinate -i git push origin main' \
  'caffeinate -t 600 -w 1 git push origin main' \
  'nohup timeout 60 caffeinate -s git push origin main'; do
  check deny clean "$cmd"
done
check ask   clean   'bash -c "gh pr merge 7 --squash"'
check allow clean   'bash -c "git push origin feature/x"'
check allow clean   'sudo git push origin feature/x'
check allow clean   'timeout 60 git push origin feature/x'
check allow clean   'caffeinate -t 600 git push origin feature/x'
# A heredoc body with an apostrophe breaks shlex; the lines after it still count.
# (read, not $(cat <<...): bash 3.2 cannot parse an apostrophe in a heredoc inside $(...))
IFS= read -r -d '' heredoc <<'CMD' || true
cat <<EOF > notes.txt
it's done
EOF
git push origin main
CMD
heredoc=${heredoc%$'\n'}
check deny  clean   "$heredoc"
check allow clean   "${heredoc%main}feature/x"
check deny  clean   "echo 'it's'; git push origin main"
# A substitution inside a quoted word is checked like a command of its own.
# shellcheck disable=SC2016 # the $( ) and backticks are the command under test
{
check deny  clean   'echo "$(git push origin main)"'
check deny  clean   'out="$(git push origin main 2>&1)"; echo "$out"'
check deny  clean   'echo "pushed: $(git push --force origin HEAD:main)"'
check deny  clean   'echo "`git push origin main`"'
check deny  clean   'git log -1 --format="$(bash -c '\''git push origin main'\'')"'
check ask   clean   'echo "$(gh pr merge 7 --squash)"'
check allow clean   'echo "$(git push origin feature/x)"'
check allow clean   'echo "$(date)" "`whoami`"'
}

# gh flags before `merge` do not hide it, and their values reach the stacked-PR check.
check ask   clean   'gh pr -R owner/repo merge 7'
check ask   clean   'gh pr --repo owner/repo merge 7 --squash'
check deny  stacked 'gh pr -R owner/repo merge 7 --delete-branch'
if grep -q -- '-R owner/repo' "$FAKE_GH_LOG"; then
  echo "ok   gh flags before merge reach the stacked-PR check"
else echo "FAIL gh calls lack -R owner/repo: $(cat "$FAKE_GH_LOG")"; fail=1; fi
check allow clean   'gh pr view 7 --json mergeable'
check allow clean   'gh pr -R owner/repo view 7 --json mergeStateStatus'

# The current branch comes from a real repo on main or on a feature branch.
on_main="$bin/on-main"; on_feature="$bin/on-feature"
git init -q "$on_main" && git -C "$on_main" checkout -q -b main
git init -q "$on_feature" && git -C "$on_feature" checkout -q -b feature/x
CHECK_CWD=$on_main check deny  clean 'git push'
CHECK_CWD=$on_main check deny  clean 'git push origin HEAD'
CHECK_CWD=$on_main check deny  clean 'git push -u origin @'
CHECK_CWD=$on_main check allow clean 'git push origin feature/y'
check deny  clean   "git -C '$on_main' push"
check deny  clean   "cd '$on_main' && git push"
check deny  clean   "cd '$on_feature' && cd ../on-main && git push origin HEAD"
check allow clean   "cd '$on_feature' && git push"
CHECK_CWD=$on_feature check allow clean 'git push'
CHECK_CWD=$on_feature check deny  clean 'git -C ../on-main push'
# A directory built from `$` or a backtick is unknown: ask when the branch matters.
# shellcheck disable=SC2016 # the $ and backticks are the command under test
{
CHECK_CWD=$on_main check ask   clean 'cd "$PWD" && git push'
CHECK_CWD=$on_main check ask   clean 'cd `pwd` && git push origin HEAD'
CHECK_CWD=$on_main check ask   clean 'cd - && git push'
CHECK_CWD=$on_main check ask   clean 'git -C "$PWD" push'
CHECK_CWD=$on_main check deny  clean 'cd "$PWD" && git push origin main'
CHECK_CWD=$on_main check allow clean 'cd "$PWD" && git push origin feature/x'
CHECK_CWD=$on_main check deny  clean "cd \"\$PWD\" && cd '$on_main' && git push"
# A branch name built from `$` or a backtick is unknown too.
check ask   clean   'git push origin "$BRANCH"'
check ask   clean   'git push origin HEAD:"$BRANCH"'
check allow clean   'git push origin "$BRANCH":feature/x'
CHECK_CWD=$on_feature check ask clean 'git switch "$BRANCH" && git push'
CHECK_CWD=$on_feature check ask clean 'git checkout -b `whoami` && git push -u origin HEAD'
CHECK_CWD=$on_feature check ask clean 'git push origin "$(git branch)"'
CHECK_CWD=$on_feature check ask clean 'git push origin "$(git branch --show-current)-x"'
# ...except the substitutions that print the current branch, read where the
# shell runs them (not where `git -C` points), and literal assignments.
CHECK_CWD=$on_feature check allow clean 'git push -u origin "$(git branch --show-current)"'
CHECK_CWD=$on_feature check allow clean 'git push origin $(git rev-parse --abbrev-ref HEAD)'
CHECK_CWD=$on_feature check allow clean 'git push origin HEAD:"$(git symbolic-ref --short HEAD)"'
CHECK_CWD=$on_main    check deny  clean 'git push -u origin "$(git branch --show-current)"'
CHECK_CWD=$on_main    check deny  clean 'git push origin $(git rev-parse --abbrev-ref HEAD)'
CHECK_CWD=$on_main    check deny  clean "git -C '$on_feature' push origin \"\$(git branch --show-current)\""
CHECK_CWD=$on_main    check allow clean "cd '$on_feature' && git -C '$on_main' push origin \"\$(git branch --show-current)\""
check ask   clean   'git push origin "$(git branch --show-current)"'
check allow clean   'B=feature/x; git push origin "$B"'
check allow clean   'B=feature/x && git push -u origin ${B}'
check deny  clean   'B=main; git push origin "$B"'
check deny  clean   'R=origin B=main; git push "$R" HEAD:refs/heads/$B'
check deny  clean   'B=feature/x; (B=main; git push origin "$B")'
check allow clean   'B=feature/x; (B=main); git push origin "$B"'
check deny  clean   'B=main; (B=feature/x); git push origin "$B"'
check ask   clean   'B=main git push origin "$B"'
check ask   clean   'B=feature/x; export B=main; git push origin "$B"'
check ask   clean   'B=feature/x; read -r B; git push origin "$B"'
check ask   clean   'B=feature/x; for B in main; do git push origin "$B"; done'
check ask   clean   'B=$X; git push origin "$B"'
check ask   clean   'B=feature/x; bash -c "git push origin \$B"'
}

# A branch the guard cannot resolve (missing directory, not a repo, detached
# HEAD) is unknown: ask before a push that needs it.
detached="$bin/detached"
git init -q "$detached" && git -C "$detached" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m init
git -C "$detached" checkout -q --detach
CHECK_CWD=$detached check ask   clean 'git push'
CHECK_CWD=$detached check ask   clean 'git push origin HEAD'
CHECK_CWD=$detached check allow clean 'git push origin HEAD:feature/x'
check ask   clean   'git push'
check ask   clean   'git push -u origin HEAD'
check ask   clean   'cd /nonexistent && git push'
check ask   clean   'git -C /nonexistent push'
check ask   clean   "cd '$on_main/missing' && git push origin HEAD"

# Earlier segments that change the branch count, run from a repo on `feature`
# with a branch `other`, a subdirectory `sub` and empty directories `empty` and
# `r` (clone targets).
repo="$bin/repo"
git init -q "$repo" && git -C "$repo" checkout -q -b feature
git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m init
git -C "$repo" branch other
mkdir -p "$repo/sub" "$repo/empty" "$repo/r"
for cmd in \
  'git checkout main && git merge feature && git push' \
  'git switch main && git push origin' \
  'git checkout main && git push origin HEAD' \
  'git checkout main && git checkout -- README.md && git push' \
  'git checkout -q main && git push' \
  'git switch -C main && git push -u origin @' \
  'git checkout -b master origin/master && git push' \
  'git checkout -B main && git push' \
  'git switch --create=main && git push' \
  'git checkout -b feat && git checkout main && git push' \
  'git checkout main && cd sub && git push' \
  'git -C sub checkout main && git push' \
  "git -C '$repo' checkout main && git -C sub push" \
  '(git checkout main) && git push' \
  'bash -c "git checkout main" && git push' \
  'git checkout main && bash -c "git push"' \
  'timeout 60 git switch main && git push'; do
  CHECK_CWD=$repo check deny clean "$cmd"
done
for cmd in \
  'mkdir -p x && git clone https://example.invalid/r.git x && cd x && git push' \
  'git clone https://example.invalid/r.git empty && cd empty && git push' \
  'git clone https://example.invalid/r.git && cd r && git push origin HEAD' \
  'git clone -b dev --depth 1 https://example.invalid/r.git && git -C r/ push' \
  'git clone https://example.invalid/r.git empty && cd empty/deeper && git push' \
  'git checkout 0123abc && git push' \
  'git checkout - && git push' \
  'git checkout --detach && git push' \
  'git checkout no-such-branch && git push' \
  'git checkout -t origin/feat && git push' \
  'git checkout --patch && git push' \
  'git checkout other -- README.md && git push' \
  'git switch --detach main && git push' \
  'git switch - && git push' \
  'git checkout feature other && git push'; do
  CHECK_CWD=$repo check ask clean "$cmd"
done
# A checkout in a directory the guard cannot resolve could be in any repo.
CHECK_CWD=$repo check ask clean "cd \"\$X\" && git checkout main; cd '$repo' && git push"
# shellcheck disable=SC2016 # the $( ) is the command under test
for cmd in \
  'git checkout -b feat && git push -u origin HEAD' \
  'git switch -c feat && git push' \
  'git checkout -b feat origin/main && git push -u origin HEAD' \
  'git checkout main && git checkout -b feat && git push' \
  'git checkout other && git push' \
  'git checkout -- README.md && git push' \
  'git checkout -q -- . && git push' \
  'git switch other && git push' \
  'git checkout main && git push origin HEAD:feat' \
  "git checkout main && cd '$on_feature' && git push" \
  "git -C '$on_main' checkout main && git push" \
  'git clone https://example.invalid/r.git empty && git push' \
  'mkdir -p x && git clone https://example.invalid/r.git x && cd x && git checkout -b feat && git push' \
  '(cd /tmp && true) && git push' \
  'x=$(cd /tmp && pwd) && git push'; do
  CHECK_CWD=$repo check allow clean "$cmd"
done
# A `cd` inside ( ) or $( ) does not leave it, as in the shell.
CHECK_CWD=$on_main check deny  clean "(cd '$repo' && true) && git push"
CHECK_CWD=$on_main check deny  clean "(cd '$repo')&&(cd /tmp) && git push"
CHECK_CWD=$on_main check allow clean "(cd /tmp && cd '$repo' && git push)"
# A quoted substitution shares the checkouts of the line and keeps its own `cd`.
# shellcheck disable=SC2016 # the $( ) is the command under test
{
CHECK_CWD=$repo check deny  clean 'echo "$(git checkout main)" && git push'
CHECK_CWD=$repo check deny  clean "x=\"\$(cd '$on_main' && git push)\""
CHECK_CWD=$repo check allow clean "x=\"\$(cd '$on_main' && pwd)\" && git push"
CHECK_CWD=$repo check allow clean 'echo "$(git push)"'
# Single quotes keep a substitution literal, unless a nested shell runs the string.
CHECK_CWD=$on_main check allow clean 'gh pr comment 1 --body '\''Run `git push` or $(git push origin main) by hand'\'''
CHECK_CWD=$on_main check deny  clean 'bash -c '\''echo "$(git push)"'\'''
}
# A heredoc inside a quoted substitution is text: a commit message can name any
# command. Only a `$( )` in the body of an unquoted heredoc runs.
IFS= read -r -d '' commit <<'CMD' || true
git commit -m "$(cat <<'EOF'
fix(guard): it's done, 1) see below
Say "hi there" and run $(git push origin main) by hand
git push origin main
git checkout main
EOF
)" && git push
CMD
commit=${commit%$'\n'}
CHECK_CWD=$repo check allow clean "$commit"
CHECK_CWD=$repo check deny  clean "$commit origin main"
CHECK_CWD=$repo check allow clean "${commit/\'EOF\'/\\EOF}"
CHECK_CWD=$repo check deny  clean "${commit/\'EOF\'/EOF}"

# The desktop app's auto-merge tool asks like `gh pr merge`; other tools get no decision.
CHECK_TOOL=mcp__ccd_pr__set_auto_merge check ask clean ''
CHECK_TOOL=mcp__ccd_pr__set_auto_merge check_allowing allow clean ''
CHECK_TOOL=Read check allow clean 'git push origin main'
CHECK_TOOL=mcp__other__merge_pull_request check allow clean 'gh pr merge 7'

# Other pushes and commands pass.
check deny  clean   'git push origin main'
check allow clean   'git push origin HEAD:feature/x'
check allow clean   'git log --grep merge'
check allow clean   'git log --grep "merge (main)" | head -1'

# The wiring in config/claude-settings.json, run exactly as written there under
# each shell, with HOME at a fake home: a missing guard or one that exits with
# anything but 0 (2 included, which Python uses when it cannot open the file)
# asks, and its output is dropped; a working one decides.
home_missing="$bin/home-missing"; home_crash="$bin/home-crash"; home_ok="$bin/home-ok"; home_exit2="$bin/home-exit2"
mkdir -p "$home_missing" "$home_crash/dotfiles/claude/hooks" "$home_ok/dotfiles/claude/hooks" "$home_exit2/dotfiles/claude/hooks"
printf 'def broken(:\n' >"$home_crash/dotfiles/claude/hooks/guard-main-and-merge.py"
cat >"$home_exit2/dotfiles/claude/hooks/guard-main-and-merge.py" <<'PY2'
import sys
print('{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}')
sys.exit(2)
PY2
ln -s "$HOOK" "$home_ok/dotfiles/claude/hooks/guard-main-and-merge.py"
wired() { # expected shell matcher home tool command [reason-substring]
  local expected=$1 shell=$2 matcher=$3 home=$4 tool=$5 cmd=$6 want=${7:-} script out rc got
  script=$(jq -r --arg m "$matcher" '.hooks.PreToolUse[] | select(.matcher == $m) | .hooks[].command' "$SETTINGS")
  out=$(jq -cn --arg t "$tool" --arg c "$cmd" '{tool_name:$t, tool_input:{command:$c}, cwd:"/tmp"}' |
    HOME="$home" "$shell" -c "$script" 2>"$bin/err")
  rc=$?
  got=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)
  if [ -z "$out" ]; then got=allow; fi
  if [ -n "$script" ] && [ "$rc" = 0 ] && [ "$got" = "$expected" ] && [[ $out == *"$want"* ]]; then
    echo "ok   wiring $expected  $shell  $matcher  ${home##*/}  $cmd"
  else echo "FAIL wiring want $expected got $got (exit $rc)  $shell  $matcher  ${home##*/}  $cmd  $out  $(cat "$bin/err")"; fail=1; fi
}
for shell in sh bash zsh; do
  command -v "$shell" >/dev/null || continue
  wired ask   "$shell" Bash "$home_missing" Bash 'git status' 'dotfiles/claude/hooks/guard-main-and-merge.py is missing'
  wired ask   "$shell" Bash "$home_crash"   Bash 'git status' 'failed (exit 1)'
  wired ask   "$shell" Bash "$home_exit2"   Bash 'git status' 'failed (exit 2)'
  wired deny  "$shell" Bash "$home_ok"      Bash 'git push origin main' 'never allowed'
  wired allow "$shell" Bash "$home_ok"      Bash 'git status'
  wired ask   "$shell" mcp__ccd_pr__set_auto_merge "$home_missing" mcp__ccd_pr__set_auto_merge '' 'is missing'
  wired ask   "$shell" mcp__ccd_pr__set_auto_merge "$home_crash"   mcp__ccd_pr__set_auto_merge '' 'failed (exit 1)'
  wired ask   "$shell" mcp__ccd_pr__set_auto_merge "$home_exit2"   mcp__ccd_pr__set_auto_merge '' 'failed (exit 2)'
  wired ask   "$shell" mcp__ccd_pr__set_auto_merge "$home_ok"      mcp__ccd_pr__set_auto_merge '' 'Auto-merge'
done
exit $fail
