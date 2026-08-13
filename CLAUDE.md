# Claude Code Project Instructions

Use a fresh Claude Code conversation for every work chunk in this project.
Conversation history is disposable; project-local handoff files are the source
of truth.

This file governs Claude Code executor sessions launched from
`build/reports/agent_handoff/next_claude_prompt.md`. If Claude is invoked by
Codex through `claude_assistant` / `ask_claude` with a `Claude Review Packet`,
it is review-only: do not edit files, start MATLAB, run simulations, update
handoff pointers, or decide the final direction. Return only the requested
advisory review sections with `verified`, `inference`, `untested`, or `blocked`
labels.

## Start Contract

1. Read `build/reports/agent_handoff/next_claude_prompt.md`.
2. Read only the mandatory evidence files named by that prompt, at most three.
3. Confirm the working directory, branch, task, allowed write paths, validation,
   and stop condition before editing.
4. If any of those are missing or inconsistent, stop and hand back to Codex.

Do not scan the repository to reconstruct context. Do not read old chats, the
package packet, or the global pointer at startup. The prompt is self-contained.
All work launched from `build/reports/agent_handoff/next_claude_prompt.md` is a
quiet disk-backed executor task by default, even if the prompt forgets the exact
`QUIET EXECUTOR` phrase.

## Modeling-Test Routing

For a model test, load only the project-local skills explicitly named by the
prompt or its one compact task index. Do not enumerate or scan `.agents/skills`,
global skills, or external skill catalogs. If the prompt names no skill, execute
from the prompt and task index only. Never invoke skill discovery, broad review,
or refactor skills during a bounded model test.

## Execution Contract

- Own one bounded work chunk. A chunk may contain several ordered phases such
  as contract repair, negative test, conditional model probe, artifact
  analysis, and handback when they share one objective and explicit gates.
- Default to a long coherent chunk that reaches the next scientific or merge
  decision. Do not stop after one small fix when the prompt already authorizes
  its focused tests, contract alignment, artifact read-back, and decision pack.
- Continue through all pre-approved gates in the same conversation. Stop early
  only for a failed gate, scientific decision requiring user approval, write
  boundary, or named stop condition.
- Do not broaden the task, refactor sibling areas, merge branches, or restore
  stale artifacts.
- For simulations expected to exceed 60 seconds, use detached batch execution
  with `running.flag`, validated `success.flag`, and `failed.flag`.
- A completion flag is not evidence by itself. Re-read the required JSON,
  Markdown, MAT, or model artifact before claiming success.
- Keep tool output targeted and below 40 lines. Redirect verbose validation to
  disk and read only exit code, failing names, and a compact summary.
- Use `rg`, filename filters, and sliced reads. Do not re-read unchanged files,
  print whole large files, or repeatedly inspect the same evidence.
- Batch independent validation into one command when practical. Run the full
  suite once after focused tests pass; do not repeatedly rerun successful suites.
- If output starts repeating, a tool stalls, or the task boundary becomes
  unclear, stop immediately and write the handoff packet from disk evidence.
- Continue through pre-approved conditional phases without asking for a new
  conversation after every small step. Stop at a scientific decision gate,
  failed acceptance gate, write-scope boundary, or the named stop condition.
- After every ordered phase, overwrite the prompt-named resume/status artifact
  with completed gates, current files, validation, and the exact next action.
  The status artifact is the recovery source after an API timeout; do not rely
  on chat history or the internal task list.
- The configured API supports a 1M-token context window. Keep a fresh-session
  chunk below roughly 600k input tokens, with a hard stop near 800k input
  tokens or four hours of active editing/analysis, whichever comes first. The
  remaining context is reserved for tool results, validation, recovery, and the
  final handback. At the soft limit, checkpoint disk status and finish the
  current ordered phase or safe validation gate. At the hard limit, write a
  compact partial HANDBACK with `state: HANDBACK`, final state
  `BLOCKED_EXECUTOR_RESUME_REQUIRED`, and stop. Codex will issue a fresh
  continuation prompt.
- A single transient API 5xx/524, connection reset, tool timeout, or interrupted
  response is not by itself a stop condition. Allow the client retry policy to
  recover, then continue from the latest disk checkpoint. If retries are
  exhausted, the same failure recurs, or session state becomes uncertain,
  persist the resume/status artifact and compact partial HANDBACK at the next
  opportunity, then stop.

## Quiet Execution

For handoff work, chat is a lifecycle display, not a work report. Client
streaming output is capped at exactly one `START` line and one terminal `DONE`
or `BLOCKED` line. Do not emit `WAIT`, progress lines, tool narration, pasted
output, reasoning, findings, suggestions, repeated status, generated code,
MATLAB functions, JSON, log tails, or stack traces to the client. Put all detail
in the named disk handback and status artifacts.

Quiet execution does not mean silent failure. Update the prompt-named disk
resume/status artifact after every phase and before any long command. If no
resume/status path is named, stop as `BLOCKED_EXECUTOR_CONTRACT` before editing.

For a run expected to exceed 60 seconds:

- prefer an OS-durable background path (for example a Windows Scheduled Task
  writing flags/heartbeats) when the run must survive app/session teardown;
  otherwise launch it as a Claude Code background task only when that is the
  safest available option;
- if no background-capable tool is available, stop and report `BLOCKED` rather
  than silently using a long synchronous call;
- record the estimated wall time and status path before launch;
- do not chat-poll. The process writes heartbeat/status files. For ETA under
  20 minutes, inspect flags at most every 5 minutes. For ETA 20-90 minutes,
  inspect at most every 15 minutes. For ETA above 90 minutes, inspect at most
  every 30 minutes. Reading only flags or compact status JSON counts as a poll;
- inspect a targeted log tail only after failure or material overrun;
- close the completed background task promptly after terminal evidence is read.
- If an ordered phase launches a durable simulation expected to run longer than
  the current reliable interactive window, write `DONE RUNNING <status path>` and
  stop instead of remaining in chat just to poll.

## Handback Contract

Before ending the chunk:

1. Run the smallest meaningful validation.
2. Re-read generated evidence from disk.
3. Overwrite the named package packet using the compact `HANDBACK` format in
   `docs/FRESH_SESSION_HANDOFF_TEMPLATES.md`; never append history.
4. State the exact final state, verified facts, evidence paths, changed files,
   validation, and next decision. Keep the packet under 60 lines.
5. Optional executor suggestions are advisory only, max two bullets, and must
   identify the new disk evidence that motivated them.

Do not continue into the next chunk. Codex reviews results and prepares the next
fresh-session prompt.
