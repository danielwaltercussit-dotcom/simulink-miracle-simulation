# Claude Code Project Instructions

Use a fresh Claude Code conversation for every work chunk in this project.
Conversation history is disposable; project-local handoff files are the source
of truth.

## Start Contract

1. Read `build/reports/agent_handoff/next_claude_prompt.md`.
2. Read only the mandatory evidence files named by that prompt, at most three.
3. Confirm the working directory, branch, task, allowed write paths, validation,
   and stop condition before editing.
4. If any of those are missing or inconsistent, stop and hand back to Codex.

Do not scan the repository to reconstruct context. Do not read old chats, the
package packet, or the global pointer at startup. The prompt is self-contained.

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
- Keep tool output targeted and below about 100 lines.
- If output starts repeating, a tool stalls, or the task boundary becomes
  unclear, stop immediately and write the handoff packet from disk evidence.
- Continue through pre-approved conditional phases without asking for a new
  conversation after every small step. Stop at a scientific decision gate,
  failed acceptance gate, write-scope boundary, or the named stop condition.

## Quiet Execution

When the prompt says `QUIET EXECUTOR`, chat is a lifecycle display, not a work
report. Client streaming output is capped at exactly one `START` line and one
terminal `DONE` or `BLOCKED` line. Do not emit `WAIT`, progress lines, tool
narration, pasted output, reasoning, findings, suggestions, or repeated status
to the client. Put all detail in the named disk handback and status artifacts.

For a run expected to exceed 60 seconds:

- prefer launching it as a Claude Code background task so it is visible in the
  Background Tasks sidebar; do not use a blocking foreground run when a
  background-capable tool is available;
- if no background-capable tool is available, stop and report `BLOCKED` rather
  than silently using a long synchronous call;
- record the estimated wall time and status path before launch;
- first poll after `max(60 s, min(10 min, 0.5 * ETA))`; later polls after
  `max(60 s, min(5 min, 0.2 * ETA))`, reading only flags or compact status JSON;
- inspect a targeted log tail only after failure or material overrun;
- close the completed background task promptly after terminal evidence is read.

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
