#!/usr/bin/env bash
# Cases for guard-main-and-merge.py. Run: bash claude/hooks/tests/guard-main-and-merge-test.sh
# `gh` is a fake on PATH (FAKE_GH_MODE: stacked | clean | fail); GitHub is never called.
HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/guard-main-and-merge.py"
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
  local expected=$1 mode=$2 cmd=$3 want_err=$4 out got err
  : >"$FAKE_GH_LOG"
  out=$(jq -cn --arg c "$cmd" '{tool_name:"Bash", tool_input:{command:$c}, cwd:"/tmp"}' |
    PATH="$bin:$PATH" FAKE_GH_MODE=$mode python3 -I "$HOOK" 2>"$bin/err")
  got=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null)
  [ -z "$got" ] && got=allow
  err=$(cat "$bin/err")
  local env_label="${CLAUDE_GUARD_ALLOW_MERGE+ALLOW_MERGE=$CLAUDE_GUARD_ALLOW_MERGE }"
  if [ "$got" = "$expected" ] && { [ -z "$want_err" ] || [[ $err == *"$want_err"* ]]; }; then
    echo "ok   $expected  $mode  $env_label$cmd"
  else echo "FAIL want $expected got $got  $mode  $env_label$cmd  $out  $err"; fail=1; fi
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
[[ $out == *"#8, #9"* && $out == *"gh pr edit 8 --base main"* ]] && echo "ok   reason lists PRs and retarget command" || { echo "FAIL reason: $out"; fail=1; }
out=$(jq -cn --arg c 'gh pr merge 7 --squash' '{tool_input:{command:$c},cwd:"/tmp"}' |
  PATH="$bin:$PATH" FAKE_GH_MODE=clean python3 -I "$HOOK")
[[ $out == *"the user's OK"* ]] && echo "ok   ask reason names the user" || { echo "FAIL ask reason: $out"; fail=1; }

# Other pushes and commands pass.
check deny  clean   'git push origin main'
check allow clean   'git push origin HEAD:feature/x'
check allow clean   'git log --grep merge'
exit $fail
