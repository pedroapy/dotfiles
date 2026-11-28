#!/usr/bin/env bash
# Cases for merge-claude-settings.sh. Run: bash scripts/tests/merge-claude-settings-test.sh
# Every case runs in its own temporary HOME whose ~/dotfiles links to this repo,
# so the real ~/.claude is never touched.
# shellcheck disable=SC2329 # the assertion helpers run through check "$@"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO/scripts/merge-claude-settings.sh"
BASE="$REPO/config/claude-settings.json"
fail=0
root=$(mktemp -d); trap 'rm -rf "$root"' EXIT
out="$root/out"

check() { # description command...
  local d=$1; shift
  if "$@"; then echo "ok   $d"; else echo "FAIL $d"; sed 's/^/     | /' "$out"; fail=1; fi
}
absent() { ! "$@"; }
same() { [ "$1" = "$2" ]; }
# jq_is <expected> <jq arguments...>: compact jq output on the local settings
jq_is() { local want=$1; shift; [ "$(jq -c "$@" "$H/.claude/settings.json")" = "$want" ]; }

new_home() { H="$root/$1"; mkdir -p "$H/.claude"; ln -s "$REPO" "$H/dotfiles"; }
run() { HOME="$H" DOTFILES="$H/dotfiles" bash "$SCRIPT" "$@" >"$out" 2>&1; }

# Older guard entries (unwrapped from ~/dotfiles, and a machine's own copy in
# ~/.claude/hooks) next to a local hook in the same group, a group of their own,
# an unrelated group and another event.
# shellcheck disable=SC2016 # commands as settings.json holds them, $HOME unexpanded
{
OLD_DOTFILES='python3 -I $HOME/dotfiles/claude/hooks/guard-main-and-merge.py'
OLD_LOCAL='python3 -I $HOME/.claude/hooks/guard-main-and-merge.py'
QUIET='$HOME/.claude/hooks/quiet-hours.sh'
LINT='$HOME/.claude/hooks/lint.sh'
}
POST='echo guard-main-and-merge.py ran'
new_home stale
jq -n --arg old "$OLD_DOTFILES" --arg own "$OLD_LOCAL" --arg quiet "$QUIET" --arg lint "$LINT" --arg post "$POST" '{
  permissions: {allow: ["Bash(ls:*)"]},
  hooks: {
    PreToolUse: [
      {matcher: "Bash", hooks: [{type: "command", command: $old}, {type: "command", command: $quiet}]},
      {matcher: "mcp__ccd_pr__set_auto_merge", hooks: [{type: "command", command: $own}]},
      {matcher: "Edit", hooks: [{type: "command", command: $lint}]}
    ],
    PostToolUse: [{matcher: "Bash", hooks: [{type: "command", command: $post}]}]
  }
}' >"$H/.claude/settings.json"
before_post=$(jq -c '.hooks.PostToolUse' "$H/.claude/settings.json")

run --check; rc=$?
check "stale: --check exits 1" same "$rc" 1
run; rc=$?
check "stale: merge exits 0" same "$rc" 0
check "stale: reports the unwrapped guard it removed" grep -qF "[-] removed an old guard hook (PreToolUse, Bash): $OLD_DOTFILES" "$out"
check "stale: reports the machine's own guard it removed" grep -qF "[-] removed an old guard hook (PreToolUse, mcp__ccd_pr__set_auto_merge): $OLD_LOCAL" "$out"
# shellcheck disable=SC2016 # jq programs, $vars are jq's
{
check "stale: no old guard command is left" jq_is 0 --arg a "$OLD_DOTFILES" --arg b "$OLD_LOCAL" \
  '[.hooks.PreToolUse[].hooks[].command | select(. == $a or . == $b)] | length'
check "stale: guard hooks are exactly the shared ones" jq_is "$(jq -c '.hooks.PreToolUse' "$BASE")" \
  '[.hooks.PreToolUse[] | .hooks |= map(select(.command | contains("guard-main-and-merge.py"))) | select(.hooks | length > 0)]'
check "stale: the local hook stays alone in its Bash group" jq_is '[1]' --arg quiet "$QUIET" \
  '[.hooks.PreToolUse[] | select(.matcher == "Bash" and any(.hooks[]; .command == $quiet)) | .hooks | length]'
check "stale: no group is left empty" jq_is 0 '[.hooks.PreToolUse[] | select(.hooks | length == 0)] | length'
check "stale: the unrelated group is unchanged" jq_is "[{\"matcher\":\"Edit\",\"hooks\":[{\"type\":\"command\",\"command\":\"$LINT\"}]}]" \
  '[.hooks.PreToolUse[] | select(.matcher == "Edit")]'
check "stale: other events are untouched" jq_is "$before_post" '.hooks.PostToolUse'
check "stale: local permissions are kept" jq_is '["Bash(ls:*)"]' '.permissions.allow'
check "stale: shared settings are merged" jq_is "$(jq -c '.autoCompactWindow' "$BASE")" '.autoCompactWindow'
}

# A rerun changes nothing and removes nothing it does not put back.
after=$(cat "$H/.claude/settings.json")
run; rc=$?
check "rerun: exits 0" same "$rc" 0
check "rerun: nothing changes" same "$(cat "$H/.claude/settings.json")" "$after"
check "rerun: reports no removal" absent grep -q '^\[-\]' "$out"
run --check; rc=$?
check "rerun: --check exits 0" same "$rc" 0

# An old guard entry back next to the merged settings: --check sees it.
# shellcheck disable=SC2016 # jq program, $old is jq's
jq --arg old "$OLD_DOTFILES" '.hooks.PreToolUse += [{matcher: "Bash", hooks: [{type: "command", command: $old}]}]' \
  "$H/.claude/settings.json" >"$root/readded" && mv "$root/readded" "$H/.claude/settings.json"
run --check; rc=$?
check "readded: --check exits 1" same "$rc" 1
run; rc=$?
check "readded: merge exits 0" same "$rc" 0
check "readded: back to the merged settings" same "$(cat "$H/.claude/settings.json")" "$after"

# No local settings yet: the shared ones are written as they are.
new_home fresh
rmdir "$H/.claude"
run; rc=$?
check "fresh: merge exits 0" same "$rc" 0
check "fresh: hooks are the shared ones" jq_is "$(jq -c '.hooks' "$BASE")" '.hooks'
check "fresh: reports no removal" absent grep -q '^\[-\]' "$out"

exit $fail
