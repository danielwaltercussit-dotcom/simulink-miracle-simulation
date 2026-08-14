# simulink_agent_v1

Project-local Simulink agent workspace for power-electronics dominated power-system modeling.

Start here:

- `AGENTS.md`
- `docs/CODEX_CLAUDE_COLLABORATION.md`
- `docs/MODELING_WORKFLOW_DRAFT.md`
- `docs/MODELING_PATTERN_LIBRARY.md`

MATLAB initialization:

```matlab
projectRoot = getenv("SIMULINK_AGENT_ROOT");
if strlength(projectRoot) == 0
    projectRoot = pwd;
end
cd(projectRoot)
init_simulink_agent_project
```

Generated artifacts under `build/`, `.ctx/`, `slprj/`, and `*.slxc` are disposable unless the latest handoff explicitly says otherwise.
