# Layout Policy

## Selection

Choose one mode per Simulink scope:

- **Full:** only for a new or empty ordinary signal-flow scope. When the
  official `model_edit` tool is available, pass `layout_mode="full"`. With
  project-local MATLAB APIs, `arrangeSystem(scope,'FullLayout','true')` is the
  corresponding fallback.
- **Incremental:** for an existing ordinary signal-flow scope. When
  `model_edit` is available, pass `layout_mode="incremental"`. Otherwise keep
  existing block positions, assign explicit positions only to new blocks, and
  route affected lines after placement. Do not emulate incremental mode by
  running `FullLayout` over the whole scope.
- **Deterministic:** for a power-system top level, SPS/Simscape electrical
  one-line view, benchmark topology, busbar view, or any canvas where position
  carries electrical meaning. Use the project coordinate templates and never
  call root-level `arrangeSystem`.

Apply the choice independently at each hierarchy level. A deterministic power
network root may contain ordinary control subsystems that safely use full or
incremental layout internally.

## Required Sequence

From the repository root:

```matlab
addpath("scripts")
addpath("scripts/layout")
before = capture_layout_structure(modelName, "Scope", targetScope);

% Apply the selected layout policy here.

structure = verify_layout_structure(modelName, before, "ThrowOnFail", true);
quality = audit_model_quality_layout(modelName, ...
    "ReportPath", fullfile("build","reports","layout", ...
    string(modelName) + "_layout.md"));
assert(quality.passed, quality.message)
set_param(modelName, "SimulationCommand", "update")
```

Run `cleanup_dangling_lines` only for lines explicitly marked
`Connected='off'`; do not infer disconnected SPS/Simscape physical lines from
negative source or destination port handles. If cleanup intentionally removes
lines, capture a new approved structure snapshot after cleanup and before
layout.

When the official MCP tools are available, also run `model_read` and
`model_check` on the edited scope. Treat any partial edit or error-severity
connectivity issue as a stop condition.

## Acceptance

Accept layout only when:

- the structure snapshot comparison passes
- root overlap and dangling-line checks pass
- Goto/From remains limited to signal and measurement paths
- the model updates or compiles
- a visual preview confirms readable flow, symmetry, polarity, and labels

For power-system roots, visual symmetry and electrical-flow semantics outrank
generic graph compactness.
