#!/bin/bash
# Merge the shared Claude Code settings from this repo into the local, untracked
# ~/.claude/settings.json. Claude Code and other tools (Orca, "always allow")
# write to that file, so it must not be a symlink into this public repo.
#   - objects merge recursively; repo values win on scalar conflicts
#   - arrays (permissions, hooks) are unioned, keeping local entries
#
# Usage: merge-claude-settings.sh [--check]
#   --check  change nothing; exit 0 if the local file already holds every
#            shared setting, 1 if a merge would change it
set -e

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
BASE="$DOTFILES/config/claude-settings.json"
LIVE="$HOME/.claude/settings.json"

# shellcheck disable=SC2016 # jq program, $vars are jq's
MERGE='
  def merge($a; $b):
    if ($a|type) == "object" and ($b|type) == "object" then
      reduce (($a + $b) | keys_unsorted[]) as $k ({};
        .[$k] = if ($a|has($k)) and ($b|has($k)) then merge($a[$k]; $b[$k])
                elif ($b|has($k)) then $b[$k] else $a[$k] end)
    elif ($a|type) == "array" and ($b|type) == "array" then
      reduce ($a + $b)[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end)
    else $b end;
  merge(.[0]; .[1])
'

if [ "${1:-}" = "--check" ]; then
    if [ -L "$LIVE" ]; then
        echo "$LIVE is a symlink; run merge-claude-settings.sh to replace it" >&2
        exit 1
    fi
    if [ ! -f "$LIVE" ]; then
        echo "$LIVE is missing" >&2
        exit 1
    fi
    merged=$(jq -S -s "$MERGE" "$LIVE" "$BASE")
    current=$(jq -S . "$LIVE")
    if [ "$merged" != "$current" ]; then
        echo "$LIVE is missing shared settings from $BASE" >&2
        exit 1
    fi
    exit 0
fi

mkdir -p "$HOME/.claude"

# Replace an old symlink into the repo with a real file holding its content
if [ -L "$LIVE" ]; then
    cp "$LIVE" "$LIVE.tmp" && rm "$LIVE" && mv "$LIVE.tmp" "$LIVE"
fi
trap 'rm -f "$LIVE.new"' EXIT
[ -f "$LIVE" ] || echo '{}' > "$LIVE"

jq -s "$MERGE" "$LIVE" "$BASE" > "$LIVE.new"
mv "$LIVE.new" "$LIVE"
echo "[ok] Claude Code settings merged into $LIVE"
