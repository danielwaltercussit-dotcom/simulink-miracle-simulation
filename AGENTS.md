# Project Simulink Agent Instructions

This project has a project-local Simulink agent setup. Do not install or register
these Simulink skills globally unless the user explicitly asks for that.

Codex's default role in this folder is review and repository hygiene. When
Claude Code has written code, Codex should first look for bugs, boundary
conditions, missing tests, stale artifacts, and unnecessary edits. When handing
work back to Claude Code, remind it to avoid broad refactors and to modify only
the files needed for the current critical issue until that issue is validated
and ready to merge.

Claude Code must overwrite the named package packet with a compact `HANDBACK`
result after every work chunk. `latest_claude_packet.md` is a tiny Codex pointer,
not a history log or mandatory Claude read.

Every Claude Code work chunk starts in a fresh conversation. Codex owns the
externalized context boundary: after review, overwrite the package packet with
the next compact `READY` task, refresh the tiny latest pointer, then generate
`build/reports/agent_handoff/next_claude_prompt.md` with
`scripts/maintenance/prepare_claude_fresh_session.ps1`. The prompt is
self-contained; Claude reads only it plus at most three named evidence files.
It must not read the package at startup or recover context from old chats.
The script must also write `next_claude_prompt.txt` so the user can transfer the
prompt without relying on clipboard contents.

External Claude review through `claude_assistant` / `ask_claude` is not Claude
Code execution. For review-only calls, Codex must prepare the three-layer review
packet defined in `docs/CODEX_CLAUDE_COLLABORATION.md` and keep Claude advisory:
no repo scan, no MATLAB, no model edits, no handoff pointer updates.

Use `docs/FRESH_SESSION_HANDOFF_TEMPLATES.md` for the exact compact format and
size limits. Never append history to handoff files.

If a Claude response repeats text, emits runaway tool output, loses the task
boundary, or a long synchronous simulation stalls, stop that conversation.
Trust disk artifacts, let Codex review them, refresh the handoff packet, and
continue in another fresh conversation.

Default Claude task packages should be long coherent chunks that reach the next
scientific or merge decision, including focused implementation, boundary tests,
artifact read-back, and the decision package. Do not create a new conversation
for every small fix when those phases share one approved objective.

Long coherent chunks still require phase checkpoints. Every prompt must name a
compact disk resume/status artifact. Claude overwrites it after each phase and
before long commands. At roughly 60k input tokens, 45 minutes of active work,
an API 5xx/524 response, repeated timeout, or interruption, Claude must write a
partial HANDBACK and stop so Codex can continue in a fresh session. Do not use
chat history or Claude's internal task list as the only progress record.

Claude Code client streaming output is capped at two user-visible lines in
QuietExecutor mode: one `START`, then one terminal `DONE` or `BLOCKED`. It must
not stream progress, tool narration, reasoning, findings, suggestions, or
periodic wait messages; those go to disk. Any task expected to exceed 60 seconds
should preferentially run as a user-visible Background Task with ETA-scaled
low-frequency polling. If background execution is unavailable, stop instead of
silently starting a long synchronous run.

Before doing workflow-driven power-system model generation in this project, read
`docs/MODELING_WORKFLOW_DRAFT.md`. Treat it as the current living specification
for the user's desired portable Simulink modeling process.

Before any controller-parameter tuning or S6 write, read
`docs/CONTROL_TUNING_PRIORITY_AND_BOUNDARY.md`. Device/plant physical parameters
and ratings are immutable; only proven control parameters may be tuned.

For Codex / Claude Code division of labor, handoff packets, and the ordered
skills-library optimization backlog, read `docs/CODEX_CLAUDE_COLLABORATION.md`.

Project-local repositories:

- `external/simulink-agentic-toolkit`
- `external/simulink-skills`

Project-local skill registry:

- `.agents/skills`

For skills-library optimization and migration work, treat
`simulink_agent_v1/.agents/skills` as the authoritative portable skill library
and follow the detailed portability boundary in
`docs/CODEX_CLAUDE_COLLABORATION.md`. Do not include active models, tests, or
run artifacts unless the user explicitly widens scope.

When the user asks for Simulink modeling, simulation, testing, debugging, or
profiling work in this project, first inspect the relevant `SKILL.md` file under
`.agents/skills`. Prefer the official Model-Based Design core skills from
`simulink-agentic-toolkit` for model creation, editing, simulation, requirements,
and testing. Use the supplemental `simulink-skills` entries for interactive
model edits, command-line debugging, and profiler analysis.

Token budget rule: use `docs/CODEX_CLAUDE_COLLABORATION.md` as the local skill
and handoff profile before loading optional skills. Default to the
modeling/review allowlist there;
do not load unrelated global skills, document/office skills, design skills,
Notion/Slack/Gmail style skills, or skill discovery/creation skills unless the
user explicitly asks for that capability in this project. This is a project-local
routing rule, not permission to uninstall or globally archive those skills.

MATLAB-side initialization is project-local:

```matlab
projectRoot = getenv("SIMULINK_AGENT_ROOT");
if isempty(projectRoot), projectRoot = pwd; end
cd(projectRoot)
init_simulink_agent_project
```

That function adds `external/simulink-agentic-toolkit` to the MATLAB path and
runs `satk_initialize`, which shares the current MATLAB session for MCP access.

For Codex MCP configuration, avoid writing `~/.codex/config.toml` without user
permission. If MCP tools are needed, use a project-scoped launch/configuration
that points the MCP server at:

```text
${SIMULINK_AGENT_ROOT}\external\simulink-agentic-toolkit\tools\tools.json
```
