#!/bin/bash
# Merge the shared Claude Code settings from this repo into the local, untracked
# ~/.claude/settings.json. Claude Code and other tools (Orca, "always allow")
# write to that file, so it must not be a symlink into this public repo.
#   - objects merge recursively; repo values win on scalar conflicts
#   - arrays (permissions, hooks) are unioned, keeping local entries
#   - except local PreToolUse hooks that run guard-main-and-merge.py: a union
#     never drops an entry whose command changed, so unless the local groups
#     holding a guard equal the repo's ones as whole objects, the guard hooks
#     are removed first and the repo's current groups put back
#
# Usage: merge-claude-settings.sh [--check]
#   --check  change nothing; exit 0 if the local file already holds every
#            shared setting, 1 if a merge would change it (the order of the
#            PreToolUse groups does not count)
set -e

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
BASE="$DOTFILES/config/claude-settings.json"
LIVE="$HOME/.claude/settings.json"

# shellcheck disable=SC2016 # jq programs, $vars are jq's
GUARD='
  def guard: type == "object" and ((.command // "") | type == "string" and contains("guard-main-and-merge.py"));
  def groups: .hooks | objects | .PreToolUse | arrays | .[] | objects;
  # PreToolUse groups that hold a guard hook, whole, in a fixed order
  def guard_groups: [groups | select((.hooks | type) == "array" and any(.hooks[]; guard))] | sort;
'
# Drop the guard hooks from PreToolUse, keeping the other hooks of their group;
# a group goes only when no hook is left in it. Other events are untouched.
# shellcheck disable=SC2016
PRUNE="$GUARD"'
  def prune:
    if (.hooks | type) == "object" and (.hooks.PreToolUse | type) == "array" then
      .hooks.PreToolUse |= [.[] |
        if type == "object" and (.hooks | type) == "array" and any(.hooks[]; guard)
        then .hooks |= map(select(guard | not)) | select(.hooks | length > 0)
        else . end]
    else . end;
'
# One line per local guard hook that the merge does not put back
# shellcheck disable=SC2016
REMOVED="$GUARD"'
  [.[1] | groups | .hooks | arrays | .[] | objects | .command] as $shared
  | .[0] | groups | .matcher as $m
  | .hooks | arrays | .[] | select(guard) | select(.command as $c | any($shared[]; . == $c) | not)
  | "[-] removed an old guard hook (PreToolUse, \($m)): \(.command)"
'
# shellcheck disable=SC2016
MERGE="$PRUNE"'
  def merge($a; $b):
    if ($a|type) == "object" and ($b|type) == "object" then
      reduce (($a + $b) | keys_unsorted[]) as $k ({};
        .[$k] = if ($a|has($k)) and ($b|has($k)) then merge($a[$k]; $b[$k])
                elif ($b|has($k)) then $b[$k] else $a[$k] end)
    elif ($a|type) == "array" and ($b|type) == "array" then
      reduce ($a + $b)[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end)
    else $b end;
  merge(if (.[0] | guard_groups) == (.[1] | guard_groups) then .[0] else .[0] | prune end; .[1])
'
# PreToolUse groups in a fixed order, for --check: Claude Code runs them all
# shellcheck disable=SC2016
SORTED='if (.hooks | type) == "object" and (.hooks.PreToolUse | type) == "array" then .hooks.PreToolUse |= sort else . end'

if [ "${1:-}" = "--check" ]; then
    if [ -L "$LIVE" ]; then
        echo "$LIVE is a symlink; run merge-claude-settings.sh to replace it" >&2
        exit 1
    fi
    if [ ! -f "$LIVE" ]; then
        echo "$LIVE is missing" >&2
        exit 1
    fi
    merged=$(jq -S -s "$MERGE | $SORTED" "$LIVE" "$BASE")
    current=$(jq -S "$SORTED" "$LIVE")
    if [ "$merged" != "$current" ]; then
        echo "$LIVE is missing shared settings from $BASE, or holds an old guard hook" >&2
        exit 1
    fi
    exit 0
fi

# The shared hooks run the guard from ~/dotfiles, whatever DOTFILES says; from
# anywhere else every guarded call asks for the user's OK.
if [ "$(cd "$DOTFILES" 2>/dev/null && pwd -P)" != "$(cd "$HOME/dotfiles" 2>/dev/null && pwd -P)" ]; then
    echo "[!] DOTFILES is $DOTFILES, but config/claude-settings.json runs its hooks from ~/dotfiles; clone or link the repo there" >&2
fi

mkdir -p "$HOME/.claude"

# Replace an old symlink into the repo with a real file holding its content
if [ -L "$LIVE" ]; then
    cp "$LIVE" "$LIVE.tmp" && rm "$LIVE" && mv "$LIVE.tmp" "$LIVE"
fi
trap 'rm -f "$LIVE.new"' EXIT
[ -f "$LIVE" ] || echo '{}' > "$LIVE"

jq -r -s "$REMOVED" "$LIVE" "$BASE"
jq -s "$MERGE" "$LIVE" "$BASE" > "$LIVE.new"
mv "$LIVE.new" "$LIVE"
echo "[ok] Claude Code settings merged into $LIVE"
