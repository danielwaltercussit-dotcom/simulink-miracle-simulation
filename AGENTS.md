# Project Simulink Agent Instructions

This project has a project-local Simulink agent setup. Do not install or register
these Simulink skills globally unless the user explicitly asks for that.

Before doing workflow-driven power-system model generation in this project, read
`docs/MODELING_WORKFLOW_DRAFT.md`. Treat it as the current living specification
for the user's desired portable Simulink modeling process.

For Codex / Claude Code division of labor, handoff packets, and the ordered
skills-library optimization backlog, read `docs/CODEX_CLAUDE_COLLABORATION.md`.

Project-local repositories:

- `external/simulink-agentic-toolkit`
- `external/simulink-skills`

Project-local skill registry:

- `.agents/skills`

When the user asks for Simulink modeling, simulation, testing, debugging, or
profiling work in this project, first inspect the relevant `SKILL.md` file under
`.agents/skills`. Prefer the official Model-Based Design core skills from
`simulink-agentic-toolkit` for model creation, editing, simulation, requirements,
and testing. Use the supplemental `simulink-skills` entries for interactive
model edits, command-line debugging, and profiler analysis.

MATLAB-side initialization is project-local:

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
init_simulink_agent_project
```

That function adds `external/simulink-agentic-toolkit` to the MATLAB path and
runs `satk_initialize`, which shares the current MATLAB session for MCP access.

For Codex MCP configuration, avoid writing `~/.codex/config.toml` without user
permission. If MCP tools are needed, use a project-scoped launch/configuration
that points the MCP server at:

```text
C:\Users\jonas\Desktop\simulink_agent_v1\external\simulink-agentic-toolkit\tools\tools.json
```
