---
name: pendientes
description: Lists the tasks paused with /pausa that are still to be resumed. Use when Pedro asks what he has pending or left to resume ("pendientes", "listado pendiente", "qué me queda"), or asks to close one ("cierra la tarea X").
argument-hint: "[cerrar <n|name>]"
allowed-tools: Bash(~/.claude/scripts/handoff.sh *)
---

!`~/.claude/scripts/handoff.sh list`

If the arguments start with "cerrar" (close), run `~/.claude/scripts/handoff.sh done <rest>` and show the list that remains with `~/.claude/scripts/handoff.sh list`.

Otherwise, show the list above as it is, without commenting on it or reading any handoff, and end with one line, in Spanish, telling Pedro that to resume one he opens a new session in its folder and types /retoma <number or name>.
