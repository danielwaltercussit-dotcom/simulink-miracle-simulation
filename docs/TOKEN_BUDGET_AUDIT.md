# Token Budget Audit for `simulink_agent_v1`

Date: 2026-06-05

Purpose: keep Codex and Claude Code focused on Simulink power-system modeling
review, while reducing token waste from unrelated skills, long history, and
broad file reads.

## Summary

The largest recurring prompt cost is the skills surface, not the current repo
state. This project exposes project-local Simulink skills, global user skills,
system skills, and plugin skills at the same time. Most global skills are not
useful for this repository and should be treated as disabled for this project.

Observed local state from the read-only `keep-codex-fast` report:

- active sessions: 13 rows, about 0.016 GB total
- archived sessions: about 0.042 GB total
- largest active sessions: 1.6 MB, 1.2 MB, 0.7 MB, 0.5 MB, 0.3 MB
- title/preview metadata: 1 repair candidate, no >10k preview
- logs database: 136.7 MB
- old session candidates: 5
- config prune candidates: 1
- worktree candidates: 0

This means the immediate token win should come from skill routing and context
discipline, not from deleting repo files or continuing old chat history.

## Project Skill Profile

Default keep list for this project:

- `ai-in-loop`
- `simulink-modeling-assistant`
- `simulink-power-electronics`
- `building-simulink-models`
- `specifying-plant-models`
- `specifying-mbd-algorithms`
- `simulating-simulink-models`
- `testing-simulink-models`
- `simulink-model-verification`
- `simulink-spec-validator`
- `simulink-device-adapters`
- `simulink-model-quality-layout`
- `simulink-auto-layout-github`
- `model-fidelity-selector`
- `power-electronics-tuning`
- `scenario-fault-library`
- `weak-grid-scr-scenario`
- `baseline-regression`
- `diagnostic-plotting`
- `sltest-harness-generation`
- `snapshot-auditor`
- `ibr-model-validation-evidence`
- `small-signal-modal-analysis`
- `multitimescale-analysis`
- `gfl-gfm-control-comparison`
- `power-electronics-component-libraries`
- `simulink-debug-commandline`
- `simulink-interactions`
- `simulink-profile-initialization`
- `simulink-profiler-analyzer`
- `simulink-solver-profiler-analyzer`

Project-local optional, load only when directly needed:

- `lab-model-pattern-miner`: only when checking the read-only lab archive
- `matlab-modernize-code`: only when MATLAB Code Analyzer reports deprecated APIs
- `matlab-optimize-performance`: only after measuring a real performance issue
- `matlab-write-performance-tests`: only when adding performance tests
- `generate-requirement-drafts`: only for requirements artifacts
- `filing-bug-reports`: only when the user asks for a standalone bug report

Project-local skills to avoid by default in this repository:

- `find-skill`
- `skill-creator`
- `document-skills`
- `code-simplifier`

Reason: they are not part of the Simulink modeling path, they invite broad
search/refactor/document workflows, and they duplicate global/system skills.

## Largest Project Skill Surfaces

Approximate `SKILL.md` sizes from this checkout:

| Skill | `SKILL.md` KB | Total folder KB | Default |
| --- | ---: | ---: | --- |
| `skill-creator` | 21.9 | 71.8 | avoid |
| `ai-in-loop` | 16.9 | 31.7 | keep |
| `find-skill` | 11.3 | 119.8 | avoid |
| `matlab-write-performance-tests` | 11.7 | 37.4 | optional |
| `simulink-solver-profiler-analyzer` | 12.6 | 74.0 | keep for solver profiling only |
| `document-skills` | 8.2 | 8.2 | avoid |
| `matlab-optimize-performance` | 8.2 | 42.8 | optional |
| `matlab-modernize-code` | 8.0 | 103.5 | optional |
| `specifying-plant-models` | 8.7 | 44.6 | keep when planning plant specs |
| `simulink-power-electronics` | 6.5 | 617.1 | keep, but load references narrowly |

The heaviest folder is `simulink-power-electronics`; keep the entrypoint, but
do not open its full reference tree unless a specific subtask needs it.

## Global Skills to Treat as Disabled Here

The following global skills under `C:\Users\jonas\.codex\skills` are unrelated
to the current Simulink project and should not be loaded during normal work:

- visual/design/content: `canvas-design`, `brand-guidelines`, `theme-factory`,
  `image-enhancer`, `slack-gif-creator`, `video-downloader`
- writing/documents: `content-research-writer`, `document-skills`,
  `email-draft-polish`, `internal-comms`, `meeting-notes-and-actions`,
  `nature-citation`, `nature-figure`, `nature-polishing`, `paperjsx`,
  `spreadsheet-formula-helper`, `support-ticket-triage`,
  `tailored-resume-generator`
- apps/business: `connect`, `connect-apps`, `datadog-logs`,
  `deploy-pipeline`, `follow-builders`, `invoice-organizer`, `issue-triage`,
  `lead-research-assistant`, `linear`, `notion-knowledge-capture`,
  `notion-meeting-intelligence`, `notion-research-documentation`,
  `notion-spec-to-implementation`, `raffle-winner-picker`, `sentry-triage`
- meta/discovery/migration: `developer-growth-analysis`, `domain-name-brainstormer`,
  `file-organizer`, `find-skill`, `mcp-builder`, `skill-share`,
  `webapp-testing`, `changelog-generator`, `codebase-migrate`

Keep these global skills available only when explicitly requested:

- `keep-codex-fast`: local Codex maintenance, report-only first
- `context-management`: searching old indexed handoffs when the latest local
  docs and `build/reports/agent_handoff/latest_claude_packet.md` are insufficient
- `gh-fix-ci` / `gh-address-comments`: only for GitHub PR checks or comments
- `repomix-explorer`: only for one-off repository packing, not default review
- `andrej-karpathy-skills`: optional coding discipline reminder

Global cleanup policy:

- Do not archive or uninstall global skills just to optimize this project.
- The intended optimization is project-local routing: ignore unrelated skills
  while doing Simulink modeling or review, but keep them available for other
  user tasks.
- `scripts/maintenance/archive_unrelated_codex_skills.ps1` is retained only as
  an emergency maintenance helper. It defaults to dry-run mode and requires both
  `-Apply` and `-ConfirmGlobalArchive` before it moves any global skill.

2026-06-05 correction:

- A temporary global archive was created at
  `C:\Users\jonas\.codex\archived_skills\simulink_agent_v1_token_slim_20260605-102556`.
- It was immediately restored with the generated restore script after the user
  clarified that skills should only be disabled for modeling-skill optimization.
- Verification after restore showed all global skill directories back under
  `C:\Users\jonas\.codex\skills`.
- Verification also showed all expected project-local modeling/review skills
  present under `.agents/skills`, including junctions to
  `external/simulink-agentic-toolkit`, `external/matlab-agentic-toolkit`, and
  `external/simulink-skills`.

## Review Token Rules

When Codex reviews Claude Code work:

1. Read `build/reports/agent_handoff/latest_claude_packet.md` if present.
2. Run `git status --short --branch`.
3. Run `git diff --name-status` before opening files.
4. Open only changed files and their closest tests/contracts.
5. Check for bugs, boundary cases, missing tests, stale artifact use, and
   unnecessary edits.
6. Ask Claude Code to fix only the necessary files. Do not ask for refactors
   until the critical issue is validated and ready to merge.
7. Put long evidence under `build/reports/`; summarize only the result in chat.

When Claude Code implements:

1. Start from the relevant skill entrypoint and at most one reference file.
2. Avoid reading all skills, all docs, or the old Codex history.
3. Use the ignored handoff packet for local communication.
4. After every work chunk, update `build/reports/agent_handoff/latest_claude_packet.md`
   with changed files, validation, important findings, and next steps before
   handing the task back to Codex.
5. Do not touch `build/`, `.ctx/`, `slprj/`, `.slxc`, or the lab archive unless
   the task explicitly concerns generated artifacts.
