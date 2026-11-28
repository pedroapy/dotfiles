#!/bin/bash
# Handoffs between Claude Code sessions: /pausa saves them, /retoma reads them,
# /pendientes lists them. One Markdown file per task in $HANDOFF_DIR.
# Compatible with the bash 3.2 that macOS ships.
set -euo pipefail

DIR="${HANDOFF_DIR:-$HOME/.claude/handoffs}"
# Closed handoffs move to cerradas/ ("closed"), where earlier ones already live.
mkdir -p "$DIR/cerradas"

usage() {
  cat >&2 <<'EOF'
usage: handoff.sh list
       handoff.sh show <n|name>     print the handoff without changing it
       handoff.sh take <n|name>     print it and mark it "in progress"
       handoff.sh save <slug> <title> < body
       handoff.sh done <n|name>     close it (moves it to cerradas/)
EOF
  exit 1
}

# Read a frontmatter field.
field() { awk -v k="$2" 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f&&index($0,k": ")==1{print substr($0,length(k)+3);exit}' "$1"; }

# Body without the frontmatter.
body() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{f=0;next} !f' "$1"; }

ago() {
  local s=$(( $(date +%s) - $1 ))
  if (( s < 3600 )); then echo "$(( s / 60 )) min"
  elif (( s < 86400 )); then echo "$(( s / 3600 )) h"
  else echo "$(( s / 86400 )) d"; fi
}

# Open handoffs, newest first (the same order as list).
sorted() {
  local f
  for f in "$DIR"/*.md; do
    [[ -e "$f" ]] || continue
    echo "$(field "$f" updated_epoch) $f"
  done | sort -rn | cut -d' ' -f2-
}

# Resolve a number from the list, an exact slug, or part of a slug or title.
resolve() {
  local q="$1" files f n=0 hits=()
  files=$(sorted)
  if [[ "$q" =~ ^[0-9]+$ ]]; then
    f=$(printf '%s\n' "$files" | sed -n "${q}p")
    [[ -n "$f" ]] && { echo "$f"; return; }
    echo "There is no task number $q." >&2; list >&2; exit 2
  fi
  [[ -f "$DIR/$q.md" ]] && { echo "$DIR/$q.md"; return; }
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    if basename "$f" .md | grep -qi -- "$q" || field "$f" title | grep -qi -- "$q"; then
      hits+=("$f"); n=$(( n + 1 ))
    fi
  done <<< "$files"
  if (( n == 1 )); then echo "${hits[0]}"; return; fi
  if (( n == 0 )); then echo "No open task matches \"$q\"." >&2
  else echo "Several tasks match \"$q\"; pick one:" >&2; fi
  list >&2
  exit 2
}

set_field() { # file field value
  local tmp="$1.tmp.$$"
  awk -v k="$2" -v v="$3" 'NR==1&&$0=="---"{f=1;print;next} f&&$0=="---"{f=0} f&&index($0,k": ")==1{print k": "v;next} {print}' "$1" > "$tmp"
  mv "$tmp" "$1"
}

list() {
  local f i=0 files
  files=$(sorted)
  if [[ -z "$files" ]]; then echo "No paused tasks."; return; fi
  echo "| # | Task | Status | Folder | Branch | Last change | Next step |"
  echo "|---|---|---|---|---|---|---|"
  while IFS= read -r f; do
    i=$(( i + 1 ))
    echo "| $i | \`$(basename "$f" .md)\` $(field "$f" title) | $(field "$f" status) | $(basename "$(field "$f" cwd)") | $(field "$f" branch) | $(ago "$(field "$f" updated_epoch)") | $(field "$f" next) |"
  done <<< "$files"
}

save() {
  local slug="${1:-}" title="${2:-}" f created next cwd branch dirty ahead last
  [[ "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "invalid slug: use lowercase letters, digits and hyphens" >&2; exit 1; }
  [[ -n "$title" ]] || usage
  title=$(printf "%s" "$title" | tr "|\n" "/ ")
  f="$DIR/$slug.md"
  local content; content=$(cat)
  [[ -n "$content" ]] || { echo "empty body: pass the handoff on stdin" >&2; exit 1; }
  created=$(date '+%Y-%m-%d %H:%M')
  [[ -f "$f" ]] && created=$(field "$f" created)
  # Next step: the first non-empty line under "## Next step".
  next=$(printf '%s\n' "$content" | awk '/^## Next step/{f=1;next} /^## /{f=0} f&&NF{sub(/^[-*0-9.) ]+/,"");print;exit}' | cut -c1-120 | tr '|' '/')
  cwd=$PWD branch="-" dirty="-" ahead="-" last="-"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    cwd=$(git rev-parse --show-toplevel)
    branch=$(git branch --show-current 2>/dev/null || true); branch=${branch:-detached}
    dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo "no upstream")
    last=$(git log -1 --format='%h %s' 2>/dev/null | cut -c1-100 || true)
  fi
  {
    echo "---"
    echo "title: $title"
    echo "status: paused"
    echo "cwd: $cwd"
    echo "branch: $branch"
    echo "uncommitted: $dirty"
    echo "unpushed: $ahead"
    echo "last_commit: $last"
    echo "next: ${next:--}"
    echo "created: $created"
    echo "updated: $(date '+%Y-%m-%d %H:%M')"
    echo "updated_epoch: $(date +%s)"
    echo "---"
    printf '%s\n' "$content"
  } > "$f.tmp.$$"
  mv "$f.tmp.$$" "$f"
  echo "Saved: $slug ($f)"
}

show() {
  local f; f=$(resolve "$1")
  echo "Task: $(basename "$f" .md) - $(field "$f" title)"
  echo "Folder: $(field "$f" cwd) | branch $(field "$f" branch) | uncommitted at pause: $(field "$f" uncommitted) | unpushed: $(field "$f" unpushed)"
  echo "Last commit at pause: $(field "$f" last_commit) | paused: $(field "$f" updated)"
  echo
  body "$f"
}

take() {
  local f; f=$(resolve "$1")
  set_field "$f" status "in progress since $(date "+%d-%m %H:%M")"
  show "$(basename "$f" .md)"
}

done_() {
  local f slug; f=$(resolve "$1"); slug=$(basename "$f" .md)
  set_field "$f" status "closed $(date '+%Y-%m-%d')"
  mv "$f" "$DIR/cerradas/$slug-$(date +%Y%m%d%H%M).md"
  echo "Closed: $slug"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  list) list ;;
  show) [[ -n "${1:-}" ]] || usage; show "$1" ;;
  take) [[ -n "${1:-}" ]] || usage; take "$1" ;;
  save) save "$@" ;;
  done) [[ -n "${1:-}" ]] || usage; done_ "$1" ;;
  *) usage ;;
esac
