# Compact Fresh-Session Handoff Contract

Purpose: make every new Claude conversation start from precise current state
without re-reading history or guessing intent.

## One Startup Artifact, Three Exchange Artifacts

1. `next_claude_prompt.md`: the canonical startup artifact. It is
   self-contained. `next_claude_prompt.txt` is an identical user-transfer copy.
2. `<package>_claude_packet.md`: latest result OR next task, never both.
3. `latest_claude_packet.md`: tiny pointer for Codex, not a Claude read target.

Detailed evidence belongs in task JSON/Markdown/log artifacts. Never paste
tables, logs, historical narrative, or repeated rules into handoff files.
Claude reads only the prompt at startup, then at most three evidence files named
inside it. Claude never reads the package packet before execution; the packet is
the required handback destination.

## Size Limits

- execution prompt: at most 60 lines;
- quiet-executor prompt: at most 25 lines and exactly one startup read;
- package packet: at most 60 lines;
- latest pointer: at most 8 lines;
- mandatory evidence reads: at most 3 files.

If more context seems necessary, improve the compact verified-state summary or
name one evidence index. Do not add more historical files.

The generator must reject a missing evidence path, a non-`READY` package,
oversized fields, or a prompt/pointer mismatch before a new session starts.

## Package States

Codex writes `state: READY` before a new Claude session. Claude overwrites the
same packet with `state: HANDBACK` when the chunk ends. Do not append.

Required package fields:

```text
id / state / objective / final_state
verified facts: max 5 bullets
review findings or blocker: max 3 bullets
evidence: max 3 paths
changed files: grouped paths, max 5 bullets
validation: max 3 command-result bullets
next decision: one sentence
optional executor suggestions: max 2 bullets, evidence-backed, advisory only
```

`READY` contains only the next task. `HANDBACK` contains only the completed
result. Codex must not leave old result prose in `READY`; Claude must not add a
new task to `HANDBACK`.

## Execution Prompt Fields

```text
objective
verified context: max 5 bullets
work phases and transition gates
write scope: directories or grouped paths
acceptance and early-stop conditions
required result fields
mandatory evidence reads: max 3
```

The prompt is self-contained. Claude must not read the package packet at
session start; it only overwrites that packet during handback.

## Precision Rules

- Label every claim `verified`, `inference`, `untested`, or `blocked`.
- State exact numeric gates and final-state vocabulary.
- Separate current result from next task.
- Link evidence instead of restating it.
- Record intentionally untouched boundaries once.
- A failed gate is a valid result when its final state and evidence are clear.
- Prefer one evidence index over several leaf artifacts.
- Do not repeat `AGENTS.md`, collaboration rules, or generic safety prose in
  every packet; the prompt states only task-specific boundaries.

## Required Write Order

Codex:

1. Overwrite the package packet with compact `READY`.
2. Run `scripts/maintenance/prepare_claude_fresh_session.ps1`.
3. The script validates `READY`, verifies evidence paths, writes the prompt,
   writes the identical TXT transfer copy, synchronizes the tiny latest
   pointer, and optionally copies the prompt.

Claude:

1. Read the prompt and its named evidence only.
2. Execute one bounded chunk.
3. Overwrite the named packet with compact `HANDBACK` and stop.

## Quiet Executor Mode

Use `prepare_claude_fresh_session.ps1 -QuietExecutor` when Claude is only the
bounded execution worker and Codex owns review. Claude reads one compact index,
keeps logs and findings on disk, and writes only these chat lines:

```text
START <package>
BLOCKED <gate> <reason> <evidence-path>
DONE <final_state> <handback-path>
```

Client streaming output is capped at two lines: one `START`, followed by exactly
one terminal `BLOCKED` or `DONE`. Do not emit `WAIT`, narrative progress, tool
output, or global review. Claude may leave at most two evidence-backed
suggestions in the disk handback; Codex decides whether to use them.

For runs over 60 seconds, Claude must launch a user-visible Background Tasks
sidebar task whenever a background-capable tool exists, record ETA and compact
status path, poll flags/status at intervals scaled to the ETA, inspect logs only
on failure or material overrun, and close the background task promptly after
terminal evidence is read. If background execution is unavailable, return
`BLOCKED`; do not start a long synchronous call.

QuietExecutor uses zero narrative. Tool reasoning, progress, findings,
recommendations, and background progress go to disk; the client sees at most
the two lifecycle lines.

## Copy-Paste Session Transfer Text

```text
Start a fresh Claude Code conversation for exactly one bounded work chunk.
Read only build/reports/agent_handoff/next_claude_prompt.md, then only the
mandatory evidence files named inside it. Do not read old chats, scan the
repository, or read the package packet/global pointer at startup.

Before editing, report one line confirming package_id, workdir, objective,
write scope, validation, and stop condition. If any item is missing,
inconsistent, or a mandatory evidence file is absent, stop and write a blocker.

Execute the ordered phases and stop at the named gate. Before ending, re-read
the generated evidence, overwrite the prompt's handback_packet with a compact
HANDBACK under 60 lines, and stop. Do not begin the next chunk.
```
