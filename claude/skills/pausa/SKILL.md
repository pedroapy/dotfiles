---
name: pausa
description: Saves a handoff of this session's task so that a new session can carry it on after a long break (lunch, end of day). Use with "/pausa", "pausa", "me voy, guarda esto".
argument-hint: "[short-task-name]"
allowed-tools: Bash(~/.claude/scripts/handoff.sh *), mcp__ccd_sidebar__list_groups, mcp__ccd_sidebar__move_sessions
---

Save the state of this session so that another session, which cannot see this conversation, can carry on the work.

1. **Name** (lowercase slug with hyphens): the argument "$ARGUMENTS" if there is one; if this session started with /retoma, the same name; otherwise a short one derived from the ticket or the task (`login-retries`, `retro-context`). **Title**: one line in Spanish.
2. Write from what this session already knows: do not search or read anything new for the handoff.
3. **Body**, with these sections and at most about 40 lines. Only what the new session cannot get from the repo or from git:

   ```
   ## Goal
   ## State
   (done, half done, what is left; uncommitted changes if there are any)
   ## Decisions
   (taken with Pedro and why; what was ruled out)
   ## Next step
   (the first one, concrete and actionable, on the first line)
   ## Waiting on Pedro
   ## Key files
   (paths, no content)
   ## Pitfalls
   (what took effort to find out)
   ```

   Do not copy code or diffs, do not retell the conversation step by step, and drop empty sections.

4. Save it with:

   ```bash
   ~/.claude/scripts/handoff.sh save <name> "<title>" <<'EOF'
   <body>
   EOF
   ```

   The script adds the folder, the branch, what is left uncommitted or unpushed, the last commit and the date by itself.

5. Only in the desktop app (the `mcp__ccd_sidebar__*` tools exist; if they are deferred, load them with ToolSearch): move this session to the group "Pausadas" with `move_sessions` (`session_ids: ["self"]` and the id that `list_groups` gives), so that it is not resumed by mistake. If the group does not exist, do not create it: say so in one line. In the terminal, skip this step.

6. Reply with a single line, in Spanish, saying that `<name>` is saved and that Pedro can resume it with /retoma <name> in a new session in <folder>. If background tasks or uncommitted changes are left, add that on another line.
