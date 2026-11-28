Shared by all of Pedro's machines from `~/dotfiles/claude/CLAUDE.md`. Each machine's `~/.claude/CLAUDE.md` imports this file and adds its own rules below the import. The routing values here (models, effort, compaction) are measured in a monthly review on one machine; change them through that review, not ad hoc.

## Changes go through a pull request

Every change to a repository goes on its own branch and reaches the default branch only through a pull request, however small the repository or the change (Pedro, 28 Nov 2026). Never push to `main` or `master`: the guard hook denies it on every machine, and the default branches of Pedro's GitHub repositories require a pull request. Merging follows each machine's own rules.

## Code navigation

Use the native `LSP` tool for structural questions (definition, references, callers/callees, symbols); Grep for literal text. CodeGraph was removed on 2026-11-13 (about 200 open issues, many of them wrong symbol links; one index per worktree). Needs `typescript-language-server` and a global `typescript@5.9.3` (7.x ships no `tsserver.js`).

## CLI over MCP

Prefer a CLI (`gh`, a cloud provider's or an error tracker's own CLI) over an MCP connector whenever both cover the task. MCP responses are large unfiltered JSON; CLI output can be field-filtered and piped through `jq`/`head`, consuming far fewer tokens.

## Model routing and token budget

The weekly quota is the constraint, and most of it goes to re-reading and re-writing the main session's context, not to effort or subagent models. Spend on judgement and on code that ships; save on reading, searching and drafting prose.

The main session is the orchestrator: Opus 5.5 at `xhigh`, with `/effort max` for a hard decision that comes up mid-session (changing effort does not break the cache on Opus 5.5). It understands, plans, decides, talks to Pedro and makes small edits that depend on the conversation. It does not pull bulk material into its own context.

| Agent               | Model / effort  | Use for                                                                                                                                                    |
| ------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `implementer`       | opus / xhigh    | production code and its tests, from an approved plan                                                                                                       |
| `personal-reviewer` | opus / xhigh    | read-only review of a diff before a PR (my review rounds)                                                                                                  |
| `worker`            | sonnet / medium | fixes that tools validate (lint, typecheck, CI), root cause of failures (tests, large logs, traces), docs or web research, memory upkeep, analysis scripts |
| `scribe`            | sonnet / low    | PR titles and bodies, commit messages, ticket text                                                                                                         |
| `scout`             | haiku           | locate code and usages, extract what matters from big files, logs or docs pages                                                                            |

- Load deferred tools in batches: one `ToolSearch` with `select:a,b,c` naming every deferred tool the task will use, and again in one call after a compaction, which drops the loaded schemas.
- Change a `settings.json` by reading and editing the file yourself. The `update-config` skill loads about 78k tokens, enough to force a compaction (21 Nov 2026).
- Delegate by volume, not importance: anything that would bring more than ~10k tokens of raw material (large files, diffs, logs, MCP JSON) or take more than 3-4 tool calls goes to a subagent. One or two targeted reads stay inline.
- Production logic is written and reviewed only by Opus 5.5 (`implementer`, `personal-reviewer` or the orchestrator). Sonnet and Haiku only do work that tools validate, that never ships, or prose Pedro reviews. This still holds with Sonnet 5.5, although since 7 Oct 2026 it costs half of Opus 5.5 on every token type (cache reads $0.10): it trails Opus 5.5 by 8 points on FrontierCode, and code that ships is where quality pays.
- `haiku` resolves to Haiku 5.5 (Claude Code 2.1.293+), about 10x cheaper than Haiku 4.5 below 100k tokens of prompt. Keep it to search, extraction and summaries: Anthropic does not recommend it for agentic coding, and it scores 39 on Terminal-Bench 4.0 against Sonnet 5.5's 71, so `worker` stays on Sonnet. At `low` effort it skips searches and stops early, so `scout` stays on its default `medium`.
- Always pick one of these agents. Do not use `general-purpose`, `Explore` or `Plan` without an explicit `model`: they inherit Opus and the session effort. When a skill says to dispatch a general-purpose implementer, use `implementer`.
- Write each brief for a reader who has not seen this conversation: the agent starts with nothing but the brief. Use plain words, since Claude 5 models take instructions literally and overreact to capitals or "CRITICAL". A brief says:
  - the goal, why it matters, and the reason behind each constraint;
  - what is already known (paths, decisions) and what is out of scope;
  - whether to change things or only report ("fix X" versus "find why X fails and change nothing");
  - what done looks like: the check to run and its output to include, or, for research, what answers the question. Sonnet may skip checks it is not given; Opus verifies unprompted, so do not ask it to double-check;
  - when an early stop is acceptable: only when blocked or before a risky step;
  - the shape of the report: conclusions first, file:line evidence, one line per minor item and a word cap, since the report stays in the orchestrator's context for the rest of the session. Ask for everything found rather than only what looks serious, and filter it yourself.
- Run independent tasks in parallel in one message. Send follow-ups to the same agent only right away (its cache lives 5 minutes).
- Never Opus 5. For a session known up front to be hard (design, a stubborn bug), start it on Fable 5.2 at `high` instead of Opus 5.5 at `max`. Pick it when the session starts: switching model mid-session rewrites the whole cache. It costs about 1.6x a session (2x per token, same price on cache reads) and draws from the shared weekly limit.
- Review rounds before a PR (Pedro, 11 Nov 2026). Each round is one fresh `personal-reviewer` agent with the `superpowers:requesting-code-review` template, filled by the orchestrator (what was built, the requirements or ACs, the git range). Our additions to that template live in its definition (`~/.claude/agents/personal-reviewer.md`, "Extras", plus `~/.claude/agent-extras/personal-reviewer.md` on a machine that has one); new checks go there. Run lint, typecheck and the related tests before each round, and send the Critical and Important findings to one refuter agent, where the repo defines one, before fixing.
  - Rounds 1 and 2 review the whole diff. Round 2 runs only when round 1 led to Critical or Important fixes; a clean round 1 ends the loop. Round 1 at the reviewer's own model and effort, round 2 at `high`. Not Fable: a blind A/B on 15 tasks (19 Nov 2026) found it no better at round 1 (Opus 5.5 rated more real issues Critical or Important and cost ~8% less on the same diffs).
  - From round 3, a round reviews only what changed since the previous one, with the full diff as context, at `high`, and runs only while the previous round led to Critical or Important fixes. Fixing only Minor or NIT findings needs no new round.
  - If round 4 still finds Critical or Important issues, stop and tell Pedro: repeated findings usually point at a design problem that more rounds will not fix.
- Never set `model:` on a skill without `context: fork`: the inline model switch drops the cache twice.

Sessions:

- One task per session. Before leaving a large session for more than an hour, write a handoff (or `/compact`) and continue in a new session instead of resuming it: a resume after more than an hour rewrites the whole context.
- The handoff tools are `/pausa` (saves it and, in the desktop app, files the session under the sidebar group "Pausadas"), `/pendientes` (lists the paused tasks) and `/retoma <n|name>` (picks one up in a new session). When Pedro says he is leaving for a while (lunch, end of day), or writes in a session idle for more than an hour, suggest `/pausa` and a new session with `/retoma`, at most once per session: if he carries on, that is his choice. The app archives sessions inactive for 7 days.
- Start side sessions fresh. Once this session is past ~100k tokens, start linked sessions with `context: "fresh"` and a brief, and move a task elsewhere with `/pausa` + `/retoma` rather than handing it off: a fork or hand-off copies the whole conversation into a new cache (195-250k measured on 13 Oct 2026, against ~124k for a fresh session) and lands right below the auto-compact threshold.
- Auto-compact is set to 300k tokens and fires at about 267k (`autoCompactWindow`). Idle compaction (terminal since 2.1.299, desktop Code tab since 2.1.314) compacts a conversation over 150k (`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`) after about 54 idle minutes, before the 1h cache expires. Opus 5.5's effort is saved under `modelSettings`: the top-level `effortLevel` no longer applies to it. These settings live in `~/dotfiles/config/claude-settings.json`, which `~/dotfiles/scripts/merge-claude-settings.sh` merges into `~/.claude/settings.json`. Desktop sessions keep the model and effort they were created with, and a session started from another inherits both.

## Replies

Always talk to Pedro in Spanish. Everything that goes into a repository (code, comments, docs, commit messages, pull requests) is in English.

In the conversation, Pedro prefers direct, concise replies, and Claude 5 models keep length in check only when told to. Open with the answer or the decision, then give only what he needs to act on it: no preamble, no recap of his message or of what the tools already showed, nothing said twice. Match the length to the question, and use a list or table only when it is clearer than a sentence.

## Suggesting new work

Pedro decides whether work outside the current task happens, and he often reads a suggestion without context: he comes from another session, or has lost the thread of a long one. A one-line suggestion does not let him judge it, so he tends to accept, and tasks that suggest further tasks end up as too many parallel sessions.

- Explain each suggestion so it stands on its own, in a few plain sentences: the problem, what fixing it achieves, why it matters (what it affects, for example a bug that will reach production) and roughly how big it is.
- Recommend new work only for bugs that reach or will reach production, security issues and improvements with a clear payoff. Perfection does not exist: smaller things can still be mentioned, labelled as polish, and he decides case by case.
- Give the options with your recommendation: a parallel task now, a ticket to fix it later (often his preference when it is not a priority), or leaving it. Create the task or the ticket only after he chooses.
- Several suggestions at once go in one short table: what, why it matters, recommendation.

## Closing a session

Pedro archives each conversation once its work is finished, so he needs a clear answer on whether he can. When he says a PR is merged, or asks whether we are done ("¿ya está?", "¿hemos terminado?"):

- Check the real state instead of assuming: the PR is merged (`gh pr view`), and nothing is left open in the session (uncommitted changes, pending steps, background tasks, follow-ups he agreed to).
- If nothing is pending, do the cleanup: remove the session's worktree (the ccd_host `clean_up_worktrees` tool when the app made it) and delete the merged local branch. Check for uncommitted or unpushed changes first and stop to ask if there are any.
- End with an explicit line: "Sí, ya puedes archivar la conversación." If something is still open, say what it is instead, in one line per item.
