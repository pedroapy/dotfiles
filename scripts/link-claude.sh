#!/bin/bash
# Link the shared Claude Code material in $DOTFILES/claude into ~/.claude:
# every agent file, skill directory and script, at the same relative path, and
# the import of claude/CLAUDE.md from ~/.claude/CLAUDE.md. setup.sh runs it;
# doctor.sh runs it with --check.
#
# Usage: link-claude.sh [--check]
#   --check  change nothing; report every item and exit 1 if any needs work
#
# For each ~/.claude/<group>/<name>:
#   - missing: link it
#   - already the right link: nothing, so a rerun is a no-op
#   - real file or directory, or a broken link (its target is gone): move it
#     to ~/.dotfiles-backups/claude-<time>/<path>, then link. Not inside
#     ~/.claude: Claude Code would load a backed-up skill as a duplicate, and
#     it rotates the files in ~/.claude/backups
#   - a working link to somewhere else: leave it, another installer (such as a
#     private config repo) owns that name
# A group directory (~/.claude/agents, skills or scripts) that is itself a
# symlink belongs to another repo: the whole group is skipped and nothing is
# written into it. ~/.claude/CLAUDE.md is created with the import when missing;
# an existing one, file or symlink, is never changed, only reported when it
# lacks the import.
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
# Without trailing slashes, or the links it made would not match their targets
while [ "${DOTFILES%/}" != "$DOTFILES" ] && [ -n "${DOTFILES%/}" ]; do
    DOTFILES="${DOTFILES%/}"
done
SRC="$DOTFILES/claude"
CLAUDE_DIR="$HOME/.claude"
BACKUP_ROOT="$HOME/.dotfiles-backups"
LINK_GROUPS="agents skills scripts"

# The import line, written with ~ when the repo lives under HOME
case "$DOTFILES" in
    "$HOME"/*) IMPORT="@~/${DOTFILES#"$HOME"/}/claude/CLAUDE.md" ;;
    *) IMPORT="@$DOTFILES/claude/CLAUDE.md" ;;
esac
IMPORT_ABS="@$DOTFILES/claude/CLAUDE.md"

CHECK=0
case "${1:-}" in
    "") ;;
    --check) CHECK=1 ;;
    *)
        echo "usage: link-claude.sh [--check]" >&2
        exit 2
        ;;
esac

problems=0
BACKUP=""

# Paths are shown with ~ so pasted output does not reveal the user name
# shellcheck disable=SC2088 # the literal ~ is the point
short() {
    case "$1" in
        "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;;
        *) printf '%s' "$1" ;;
    esac
}

# report <ok|skip|fail|warn|linked|backup|created> <path> [detail]
# --check prints doctor.sh's OK/SKIP/FAIL lines; a run prints setup.sh's style.
report() {
    local name detail="${3:-}"
    name=$(short "$2")
    case "$1" in
        ok)
            if [ "$CHECK" = 1 ]; then printf '  OK    %s%s\n' "$name" "${detail:+ ($detail)}"; fi
            ;;
        skip)
            if [ "$CHECK" = 1 ]; then
                printf '  SKIP  %s (%s)\n' "$name" "$detail"
            else
                printf '[skip] %s (%s)\n' "$name" "$detail"
            fi
            ;;
        fail)
            printf '  FAIL  %s: %s\n' "$name" "$detail"
            problems=$((problems + 1))
            ;;
        warn)
            if [ "$CHECK" = 1 ]; then
                printf '  FAIL  %s: %s\n' "$name" "$detail"
                problems=$((problems + 1))
            else
                printf '[!] %s: %s\n' "$name" "$detail"
            fi
            ;;
        linked) printf '[+] %s -> %s\n' "$name" "$detail" ;;
        backup) printf '[backup] %s moved to %s\n' "$name" "$detail" ;;
        created) printf '[+] %s %s\n' "$name" "$detail" ;;
    esac
}

# The one list of what gets linked: the names in one group of $SRC.
items() {
    local p
    for p in "$SRC/$1"/*; do
        case "$1" in
            agents) if [ -f "$p" ] && [ "${p%.md}" != "$p" ]; then echo "${p##*/}"; fi ;;
            skills) if [ -d "$p" ]; then echo "${p##*/}"; fi ;;
            scripts) if [ -f "$p" ]; then echo "${p##*/}"; fi ;;
        esac
    done
}

# Move what is at ~/.claude/<rel> (a real file or directory, or a broken link)
# into this run's backup.
backup() {
    local rel=$1 base n=1
    if [ -z "$BACKUP" ]; then
        base="$BACKUP_ROOT/claude-$(date +%Y%m%d-%H%M%S)"
        BACKUP=$base
        while [ -e "$BACKUP" ]; do
            BACKUP="$base-$n"
            n=$((n + 1))
        done
    fi
    mkdir -p "$(dirname "$BACKUP/$rel")"
    mv "$CLAUDE_DIR/$rel" "$BACKUP/$rel"
    report backup "$CLAUDE_DIR/$rel" "$(short "$BACKUP/$rel")"
}

link_item() {
    local rel=$1 src="$SRC/$1" dst="$CLAUDE_DIR/$1" what
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        report ok "$dst"
    elif [ -L "$dst" ] && [ -e "$dst" ]; then
        report skip "$dst" "points to $(short "$(readlink "$dst")"), managed elsewhere"
    elif [ -L "$dst" ] || [ -e "$dst" ]; then
        if [ -L "$dst" ]; then
            what="broken link to $(short "$(readlink "$dst")")"
        elif [ -d "$dst" ]; then
            what="real directory, not a link"
        else
            what="real file, not a link"
        fi
        if [ "$CHECK" = 1 ]; then
            report fail "$dst" "$what (scripts/link-claude.sh backs it up and links it)"
        else
            backup "$rel"
            # -n: never follow an existing link to a directory and link inside it
            ln -sfn "$src" "$dst"
            report linked "$dst" "$(short "$src")"
        fi
    elif [ "$CHECK" = 1 ]; then
        report fail "$dst" "missing (run scripts/link-claude.sh)"
    else
        mkdir -p "$(dirname "$dst")"
        ln -sfn "$src" "$dst"
        report linked "$dst" "$(short "$src")"
    fi
}

link_claude_md() {
    local f="$CLAUDE_DIR/CLAUDE.md"
    if [ -e "$f" ] || [ -L "$f" ]; then
        if grep -qxF -e "$IMPORT" -e "$IMPORT_ABS" "$f" 2>/dev/null; then
            report ok "$f" "imports claude/CLAUDE.md"
        else
            report warn "$f" "does not import the shared file; add the line $IMPORT (left untouched)"
        fi
    elif [ "$CHECK" = 1 ]; then
        report fail "$f" "missing (run scripts/link-claude.sh to create it with the line $IMPORT)"
    else
        mkdir -p "$CLAUDE_DIR"
        printf '%s\n' "$IMPORT" > "$f"
        report created "$f" "with the line $IMPORT"
    fi
}

for group in $LINK_GROUPS; do
    names=$(items "$group")
    [ -n "$names" ] || continue
    gdir="$CLAUDE_DIR/$group"
    if [ -L "$gdir" ]; then
        count=$(printf '%s\n' "$names" | wc -l | tr -d ' ')
        report skip "$gdir" "symlink to $(short "$(readlink "$gdir")"), its $count item(s) managed elsewhere"
        continue
    fi
    while IFS= read -r name; do
        link_item "$group/$name"
    done <<< "$names"
done
link_claude_md

if [ "$CHECK" = 1 ]; then
    if [ "$problems" -gt 0 ]; then exit 1; fi
    exit 0
fi
echo "[ok] Claude Code links from $(short "$SRC")"
