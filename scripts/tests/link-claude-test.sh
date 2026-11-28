#!/usr/bin/env bash
# Cases for link-claude.sh. Run: bash scripts/tests/link-claude-test.sh
# Every case runs in its own temporary HOME with a fake dotfiles tree, so the
# real ~/.claude and this repo are never touched.
# shellcheck disable=SC2329 # the assertion helpers run through check "$@"
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/link-claude.sh"
fail=0
root=$(mktemp -d); trap 'rm -rf "$root"' EXIT
out="$root/out"

check() { # description command...
  local d=$1; shift
  if "$@"; then echo "ok   $d"; else echo "FAIL $d"; sed 's/^/     | /' "$out"; fail=1; fi
}
absent() { ! "$@"; }
links_to() { [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; }
same() { [ "$1" = "$2" ]; }
entries() { find "$1" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' '; }

# new_home <name> [dotfiles dir]: an empty HOME (H) and a fake dotfiles tree (D)
new_home() {
  H="$root/$1"; D="${2:-$H/dotfiles}"
  mkdir -p "$H" "$D/claude/agents" "$D/claude/skills/alpha" "$D/claude/skills/beta" "$D/claude/scripts"
  echo "agent one" >"$D/claude/agents/one.md"
  echo "agent two" >"$D/claude/agents/two.md"
  echo "skill alpha" >"$D/claude/skills/alpha/SKILL.md"
  echo "skill beta" >"$D/claude/skills/beta/SKILL.md"
  printf '#!/bin/sh\n' >"$D/claude/scripts/handoff.sh"
}
run() { HOME="$H" DOTFILES="$D" "$SCRIPT" "$@" >"$out" 2>&1; }
# Paths, link targets and CLAUDE.md content under ~/.claude
snapshot() {
  (cd "$H/.claude" && find . | sort && find . -type l | sort | while read -r l; do echo "$l -> $(readlink "$l")"; done && cat CLAUDE.md)
}
ITEMS="agents/one.md agents/two.md skills/alpha skills/beta scripts/handoff.sh"

# Fresh HOME, as on a new machine or in CI: no ~/.claude at all.
new_home fresh
run --check; rc=$?
check "fresh: --check exits 1" same "$rc" 1
check "fresh: --check reports missing items" grep -q '^  FAIL  ~/.claude/agents/one.md: missing' "$out"
check "fresh: --check creates nothing" [ ! -e "$H/.claude" ]
run; rc=$?
check "fresh: install exits 0" same "$rc" 0
for rel in $ITEMS; do
  check "fresh: $rel linked" links_to "$H/.claude/$rel" "$D/claude/$rel"
done
check "fresh: CLAUDE.md holds only the import" same "$(cat "$H/.claude/CLAUDE.md")" "@~/dotfiles/claude/CLAUDE.md"
check "fresh: no backup" [ ! -e "$H/.dotfiles-backups" ]
run --check; rc=$?
check "fresh: --check after install exits 0" same "$rc" 0
check "fresh: --check reports OK lines" grep -q '^  OK    ~/.claude/skills/alpha$' "$out"

# A rerun is a no-op.
before=$(snapshot)
run; rc=$?
check "rerun: exits 0" same "$rc" 0
check "rerun: nothing changes" same "$(snapshot)" "$before"
check "rerun: no backup" [ ! -e "$H/.dotfiles-backups" ]
check "rerun: no link or backup lines" absent grep -qE '^\[(\+|backup)\]' "$out"

# Real files and a real skill directory are backed up, then linked.
new_home real
mkdir -p "$H/.claude/agents" "$H/.claude/skills/alpha" "$H/.claude/scripts"
echo "old agent" >"$H/.claude/agents/one.md"
echo "old skill" >"$H/.claude/skills/alpha/SKILL.md"
echo "old notes" >"$H/.claude/skills/alpha/notes.md"
echo "old script" >"$H/.claude/scripts/handoff.sh"
echo "keep me" >"$H/.claude/scripts/other.sh"
run --check; rc=$?
check "real: --check exits 1" same "$rc" 1
check "real: --check names the real file" grep -q '^  FAIL  ~/.claude/agents/one.md: real file' "$out"
check "real: --check names the real directory" grep -q '^  FAIL  ~/.claude/skills/alpha: real directory' "$out"
check "real: --check moves nothing" [ ! -L "$H/.claude/agents/one.md" ]
run; rc=$?
check "real: install exits 0" same "$rc" 0
backups=$(ls "$H/.dotfiles-backups" 2>/dev/null)
check "real: one backup directory" same "$(printf '%s\n' "$backups" | grep -c '^claude-')" 1
check "real: nothing backed up inside ~/.claude" [ ! -e "$H/.claude/backups" ]
b="$H/.dotfiles-backups/$backups"
check "real: agent backed up" same "$(cat "$b/agents/one.md" 2>/dev/null)" "old agent"
check "real: skill directory backed up whole" same "$(cat "$b/skills/alpha/notes.md" 2>/dev/null)" "old notes"
check "real: script backed up" same "$(cat "$b/scripts/handoff.sh" 2>/dev/null)" "old script"
for rel in $ITEMS; do
  check "real: $rel linked" links_to "$H/.claude/$rel" "$D/claude/$rel"
done
check "real: ~/.claude/skills holds only links" same "$(find "$H/.claude/skills" -mindepth 1 -maxdepth 1 ! -type l | wc -l | tr -d ' ')" 0
check "real: unrelated script untouched" same "$(cat "$H/.claude/scripts/other.sh")" "keep me"
check "real: nothing written into the dotfiles skill" same "$(ls -A "$D/claude/skills/alpha")" "SKILL.md"
run; rc=$?
check "real: rerun exits 0" same "$rc" 0
check "real: rerun makes no new backup" same "$(entries "$H/.dotfiles-backups")" 1
rm "$H/.claude/agents/two.md"; echo "old two" >"$H/.claude/agents/two.md"
run
check "real: a later backup gets its own directory" same "$(entries "$H/.dotfiles-backups")" 2
check "real: the first backup is intact" same "$(cat "$b/agents/one.md" 2>/dev/null)" "old agent"

# A link that points somewhere else belongs to another installer.
new_home foreign
mkdir -p "$H/private" "$H/.claude/agents"
echo "private" >"$H/private/one.md"
ln -s "$H/private/one.md" "$H/.claude/agents/one.md"
run; rc=$?
check "foreign: install exits 0" same "$rc" 0
check "foreign: link left alone" links_to "$H/.claude/agents/one.md" "$H/private/one.md"
check "foreign: skip reported" grep -q '^\[skip\] ~/.claude/agents/one.md (points to ~/private/one.md' "$out"
check "foreign: other agents linked" links_to "$H/.claude/agents/two.md" "$D/claude/agents/two.md"
check "foreign: target untouched" same "$(cat "$H/private/one.md")" "private"
run --check; rc=$?
check "foreign: --check exits 0" same "$rc" 0
check "foreign: --check reports SKIP" grep -q '^  SKIP  ~/.claude/agents/one.md' "$out"

# A broken link (its target is gone) is backed up and replaced, not skipped.
new_home broken
mkdir -p "$H/.claude/agents" "$H/.claude/skills"
ln -s "$H/gone/one.md" "$H/.claude/agents/one.md"
ln -s "$H/gone/alpha" "$H/.claude/skills/alpha"
run --check; rc=$?
check "broken: --check exits 1" same "$rc" 1
check "broken: --check reports the broken link" grep -q '^  FAIL  ~/.claude/agents/one.md: broken link to ~/gone/one.md' "$out"
check "broken: --check changes nothing" links_to "$H/.claude/agents/one.md" "$H/gone/one.md"
run; rc=$?
check "broken: install exits 0" same "$rc" 0
check "broken: agent relinked" links_to "$H/.claude/agents/one.md" "$D/claude/agents/one.md"
check "broken: skill relinked" links_to "$H/.claude/skills/alpha" "$D/claude/skills/alpha"
b="$H/.dotfiles-backups/$(ls "$H/.dotfiles-backups" 2>/dev/null)"
check "broken: old agent link kept in the backup" links_to "$b/agents/one.md" "$H/gone/one.md"
check "broken: old skill link kept in the backup" links_to "$b/skills/alpha" "$H/gone/alpha"
run --check; rc=$?
check "broken: --check after install exits 0" same "$rc" 0

# A symlinked group directory is skipped whole and never written into.
new_home group
mkdir -p "$H/private-agents" "$H/.claude"
ln -s "$H/private-agents" "$H/.claude/agents"
run; rc=$?
check "group: install exits 0" same "$rc" 0
check "group: nothing written into the agents target" same "$(ls -A "$H/private-agents")" ""
check "group: agents directory still the same link" links_to "$H/.claude/agents" "$H/private-agents"
check "group: skip reported" grep -q '^\[skip\] ~/.claude/agents (symlink to ~/private-agents' "$out"
check "group: skills still linked" links_to "$H/.claude/skills/alpha" "$D/claude/skills/alpha"
run --check; rc=$?
check "group: --check exits 0" same "$rc" 0
check "group: --check reports the group as managed elsewhere" grep -q '^  SKIP  ~/.claude/agents (symlink to' "$out"

# An existing CLAUDE.md, file or symlink, is never changed.
new_home claudemd
mkdir -p "$H/.claude"
echo "my rules" >"$H/.claude/CLAUDE.md"
run; rc=$?
check "CLAUDE.md: install exits 0" same "$rc" 0
check "CLAUDE.md: file without the import untouched" same "$(cat "$H/.claude/CLAUDE.md")" "my rules"
check "CLAUDE.md: missing import warned" grep -q '^\[!\] ~/.claude/CLAUDE.md: does not import' "$out"
run --check; rc=$?
check "CLAUDE.md: --check exits 1 without the import" same "$rc" 1
rm "$H/.claude/CLAUDE.md"
echo "private rules" >"$H/private.md"
ln -s "$H/private.md" "$H/.claude/CLAUDE.md"
run
check "CLAUDE.md: symlink left as it was" links_to "$H/.claude/CLAUDE.md" "$H/private.md"
check "CLAUDE.md: symlink target untouched" same "$(cat "$H/private.md")" "private rules"
check "CLAUDE.md: symlink without the import skipped" grep -q '^\[skip\] ~/.claude/CLAUDE.md (symlink to ~/private.md, managed elsewhere)' "$out"
run --check; rc=$?
check "CLAUDE.md: --check exits 0 for a symlink managed elsewhere" same "$rc" 0
check "CLAUDE.md: --check reports the symlink as managed elsewhere" grep -q '^  SKIP  ~/.claude/CLAUDE.md (symlink to' "$out"
printf 'intro\n@~/dotfiles/claude/CLAUDE.md\nmore\n' >"$H/private.md"
run --check; rc=$?
check "CLAUDE.md: --check exits 0 once it imports the shared file" same "$rc" 0
rm "$H/private.md"
run --check; rc=$?
check "CLAUDE.md: --check exits 1 for a broken symlink" same "$rc" 1
check "CLAUDE.md: broken symlink not skipped" absent grep -q 'SKIP  ~/.claude/CLAUDE.md' "$out"

# A repo outside HOME is imported by its absolute path.
new_home outside "$root/elsewhere/dots"
run
check "outside: import uses the absolute path" same "$(cat "$H/.claude/CLAUDE.md")" "@$root/elsewhere/dots/claude/CLAUDE.md"
check "outside: agents linked" links_to "$H/.claude/agents/one.md" "$root/elsewhere/dots/claude/agents/one.md"

# A trailing slash on DOTFILES makes the same links, so they stay its own.
new_home slash
HOME="$H" DOTFILES="$D/" "$SCRIPT" >"$out" 2>&1; rc=$?
check "slash: install exits 0" same "$rc" 0
for rel in $ITEMS; do
  check "slash: $rel linked without the slash" links_to "$H/.claude/$rel" "$D/claude/$rel"
done
HOME="$H" DOTFILES="$D//" "$SCRIPT" --check >"$out" 2>&1; rc=$?
check "slash: --check exits 0" same "$rc" 0
check "slash: --check skips nothing" absent grep -q 'SKIP' "$out"

run --bogus; rc=$?
check "unknown option exits 2" same "$rc" 2
exit $fail
