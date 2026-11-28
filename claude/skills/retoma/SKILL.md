---
name: retoma
description: Resumes in this session a task paused with /pausa, by reading its handoff. Use with "/retoma <task>", "retoma <n or name>", "sigue con <task>".
argument-hint: <task number or name>
allowed-tools: Bash(~/.claude/scripts/handoff.sh *), Bash(git status *), Bash(git log *), Bash(git branch *)
---

Handoff of the task "$ARGUMENTS":

!`~/.claude/scripts/handoff.sh take "$ARGUMENTS"`

Steps:

1. If a list of tasks shows above instead of a handoff (there was no argument, or none or several tasks match), show it and ask which one. Do nothing else.
2. If the handoff's folder is not this session's directory, say so in one line and ask whether to carry on here or open the session in that folder.
3. If you are in the handoff's folder, check only with `git status --short` and `git log -1 --oneline` whether the branch has changed since the pause. Do not reread the key files until the next step needs them.
4. Reply in 3-5 lines: what the task is, where it stopped and the next step. If the next step does not need a decision from Pedro, start on it. If it does, ask.

While the session lasts:

- If Pedro pauses again, `/pausa` reuses this same task name.
- When the task ends (PR merged or work done), close it with `~/.claude/scripts/handoff.sh done <name>` before telling him he can archive the conversation.
