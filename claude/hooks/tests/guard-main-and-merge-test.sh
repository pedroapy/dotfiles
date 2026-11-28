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
  'sudo bash -c "git push origin main"'; do
  check deny clean "$cmd"
done
check ask   clean   'bash -c "gh pr merge 7 --squash"'
check allow clean   'bash -c "git push origin feature/x"'
check allow clean   'sudo git push origin feature/x'
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
}

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
# each shell, with HOME at a fake home: a missing or crashing guard asks, a
# working one decides.
home_missing="$bin/home-missing"; home_crash="$bin/home-crash"; home_ok="$bin/home-ok"
mkdir -p "$home_missing" "$home_crash/dotfiles/claude/hooks" "$home_ok/dotfiles/claude/hooks"
printf 'def broken(:\n' >"$home_crash/dotfiles/claude/hooks/guard-main-and-merge.py"
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
  wired deny  "$shell" Bash "$home_ok"      Bash 'git push origin main' 'never allowed'
  wired allow "$shell" Bash "$home_ok"      Bash 'git status'
  wired ask   "$shell" mcp__ccd_pr__set_auto_merge "$home_missing" mcp__ccd_pr__set_auto_merge '' 'is missing'
  wired ask   "$shell" mcp__ccd_pr__set_auto_merge "$home_crash"   mcp__ccd_pr__set_auto_merge '' 'failed (exit 1)'
  wired ask   "$shell" mcp__ccd_pr__set_auto_merge "$home_ok"      mcp__ccd_pr__set_auto_merge '' 'Auto-merge'
done
exit $fail
