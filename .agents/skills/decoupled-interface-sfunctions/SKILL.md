---
name: decoupled-interface-sfunctions
description: Use when designing, reviewing, or contract-checking cross-scale decoupling interfaces between EMT and averaged/electromechanical Simulink models in simulink_agent_v1 - Thevenin/Norton equivalents, controlled-source or measurement boundaries, and S-Function / MATLAB Function interface wrappers, including hold policy (ZOH / rate transition), transport delay, algebraic-loop breaking, energy-consistency, and exchange-variable contracts. Portable slice with contract helper plus optional tiny probes/wrappers; no real plant execution claim without a ModelProbe.
---

# Decoupled Interface S-Functions

Use this skill when a model couples two simulation domains across a scale or
fidelity boundary and the data exchange needs an explicit, testable contract:

- EMT model exchanging data with an averaged / electromechanical model
- Thevenin or Norton equivalent decoupling between subsystems
- controlled-source or measurement boundary between two solvers
- S-Function or MATLAB Function wrapper that carries the interface
- rate transition, transport delay, or algebraic-loop breaking at the boundary

This is the cross-scale equivalent-source decoupling layer. It does NOT pick
solvers/step sizes, condition signals, or define device ports - see Routing.

## Three-axis semantics

Like the sibling contract skills, this skill reports three independent axes and
never collapses them:

- `contract_status`: `pass` | `provisional` | `fail`
  Static plan check only. `pass` means the declared interface plan is internally
  consistent and complete. It does NOT mean the interface was run.
- `model_validation_status`: `not_attempted` | `pass` | `fail`
  Evidence axis. `not_attempted` unless a ModelProbe is attached; `pass` only
  when a probe actually ran and the simulation succeeded; `fail` when a probe
  ran but the simulation did not succeed.
- `handoff_ready`: `true` ONLY when `contract_status == pass` AND
  `model_validation_status == pass` AND there are zero warnings. Any warning,
  any provisional/fail, or a missing probe keeps it `false`.

## Evidence discipline

- A `contract pass` is NOT a claim that the model was validated. It is a
  static-plan verdict only.
- A bare `verified_against_model = true` in the plan, with no ModelProbe
  attached, is downgraded to a **warning** and the derived
  `verified_against_model` is forced to `false`. Claims are never trusted.
- Only an attached ModelProbe with `ran == true` and `sim_success == true` can
  set `model_validation_status = pass` and derive
  `verified_against_model = true`.
- A synthetic/hand-built ModelProbe is a test fixture, not real validation; do
  not present it as proof a real interface was exercised.

## Helper

The contract helper is bundled in this skill, so it migrates with the skill
library. It is pure base-MATLAB, has no Simulink dependency, and opens no model:

```matlab
projectRoot = getenv("SIMULINK_AGENT_ROOT");
if isempty(projectRoot), projectRoot = pwd; end
skillRoot = fullfile(projectRoot, ".agents", "skills", "decoupled-interface-sfunctions");
addpath(fullfile(skillRoot, "scripts", "analysis"))
summary = summarize_decoupled_interface_plan(plan);
summary = summarize_decoupled_interface_plan(plan, 'ModelProbe', probe);
summary = summarize_decoupled_interface_plan(plan, 'OutputDir', outDir);
assert(strcmp(summary.contract_status, 'pass'))
```

When the skill is installed outside this repository layout, set `skillRoot` to
the filesystem path of this skill folder; do not hard-code host Desktop paths.

It writes machine-readable evidence (jsondecode-safe JSON + Markdown) under
`build/reports/decoupled_interface/<case>/`. Read
`references/decoupled-interface-contract.md` before adding plan fields or
failure rules.

## Agent execution gates

When another agent is asked to modify or validate a real plant model, keep the
task executable and bounded. Read
`references/agent-execution-gates.md` before drafting handoff prompts, accepting
validation claims, or moving from wrapper probes into full-plant integration.

## Routing

- `hybrid-solver-multirate-simulation` - solver choice and step sizes.
- `signal-conditioning-and-zoh` - signal conditioning, ZOH, filtering, AI delay.
- `simulink-device-adapters` - device-side port boundaries and adapters.
- **this skill** - the equivalent-source decoupling interface contract that sits
  between two solver domains (EMT <-> averaged / electromechanical).

Use this skill when defining or reviewing the cross-domain interface itself,
after the per-domain solver and conditioning decisions are made.
