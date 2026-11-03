# Agentic Simulink Modeling Policy

This file distills external Simulink modeling skill experience into the
project-local workflow. It is a reference only; do not install external skills
or global skill links from here.

## Official SATK Gates

Before model construction or extension, check whether the project has:

- `.satk/reuse-libraries.json`
- `.satk/block-policy.json`
- `.satk/library-kg/index.md`

If present, these files constrain block choice, custom-library preference,
blocked library blocks, and protected parameters. If
`reuse-libraries.json` declares `confirmedNone: true`, no custom-library gate
is required. If the files are missing, do not assume a custom-library policy;
ask before creating `.satk` policy state.

Use `model_read` before edits, `model_edit` for structural edits, `model_read`
after edits, and `model_check` before declaring the scope complete. When
`model_edit` reports a partial edit, immediately run both `model_read` and
`model_check`.

## Debug And Profiling Routing

- Wrong value at a specific time step or block method: use
  `simulink-debug-commandline` / `sldebug` before speculative rewiring.
- Slow update diagram or initialization: use
  `simulink-profile-initialization`.
- Slow simulation or release-to-release runtime regression: use
  `simulink-profiler-analyzer`.
- Solver resets, zero crossings, algebraic loops, Jacobian churn, or stiffness
  suspicion: use `simulink-solver-profiler-analyzer`.

Keep these as diagnostic routes, not as default build steps.

## Power-Electronics Evidence Boundary

For converter, HVDC, DFIG, VSG/GFL/GFM, weak-grid, storage, BMS, or Simscape
Electrical work:

- classify domain, topology, control objective, and active validation signals
  before editing;
- inspect active/commented/variant paths, From/Goto tags, sample times, solver
  settings, measurement polarity, and generated artifacts;
- track validation state explicitly as `opened`, `compiled`, `simulated`, and
  `measured`;
- do not call a waveform or controller issue fixed until relevant controller
  outputs and plant-side signals have numeric evidence.

## Layout Boundary

Ordinary signal-flow subsystems may use official `model_edit` layout modes:
`full` for empty scopes and `incremental` for existing scopes. Power-system
top-level canvases, SPS/Simscape one-line diagrams, benchmark topology views,
and busbar layouts use deterministic project coordinates. Never run global
root-level `arrangeSystem` on those scopes.

## External Skill Intake (2026-09-14)

User-authorized GitHub review installed only two lean, project-local MIT
adaptations. Fixed revisions below record what was inspected, not a promise
to follow upstream automatically. Preserve each installed skill's LICENSE.

| Repository | Inspected commit | Decision |
|---|---|---|
| [h4vzz/awesome-ai-agent-skills](https://github.com/h4vzz/awesome-ai-agent-skills/tree/1615e6bb5fc09492de89fa864cf3d1dc88a5db9e) | `1615e6bb5fc09492de89fa864cf3d1dc88a5db9e` | Adapt `knowledge-graph-creation`; Markdown relationships, no graph database or mandatory exports |
| [BESSER-PEARL/research-agent-skills](https://github.com/BESSER-PEARL/research-agent-skills/tree/03d3c49ac1698c9d29cc4c0f5e8eeca17210bd51) | `03d3c49ac1698c9d29cc4c0f5e8eeca17210bd51` | Adapt `research-paper-review`; formula/evidence/transfer checks, no venue-review boilerplate |
| [matlab/simulink-agentic-toolkit](https://github.com/matlab/simulink-agentic-toolkit/tree/9c591b28d998c51a87ca802d228c5c6a11a4bcd9) | `9c591b28d998c51a87ca802d228c5c6a11a4bcd9` | Distill frequency-response and fault-injection workflows into existing references; do not bulk-copy MathWorks-licensed skills |
| [K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills/tree/0b2afe68a5f9379097ad815e028af664f1e222b7) | `0b2afe68a5f9379097ad815e028af664f1e222b7` | MIT; reviewed literature workflow, not installed: mandatory generated visuals and additional outputs do not fit this scope |
| [huanhyougo/matlab-power-electronics-skill](https://github.com/huanhyougo/matlab-power-electronics-skill/tree/4a0db6cf1c3e52da8ce12c41e8d38de1f36b7817) | `4a0db6cf1c3e52da8ce12c41e8d38de1f36b7817` | No declared repository license verified; retain existing local PE workflow, no new code/model copying |

Official upstream pointers inspected: `skills-catalog/control-systems/`
`simulink-frequency-response/SKILL.md` and
`skills-catalog/verification-validation-and-test/inject-faults/SKILL.md`.

For sweeps use the qualified experiment and duration gates in
[impedance contract](../../impedance-frequency-analysis/references/impedance-contract.md).
Do not inherit a zero-DC-gain failure heuristic or imply that PRBS always
identifies a meaningful linear model under discontinuities.

Fault-injection APIs are optional and toolbox/version-gated. A corrupted
measurement or signal is not an electrical short circuit. Define the actual
physical fault topology, impedance, timing, clearing/protection, and monitored
quantities for a power-system fault study. Record baseline fault states and
restore them after a probe; never remove another task's fault definitions.
No new fault-injection runtime was installed by this knowledge update.

## VSC, DFIG, and SG Skill Refresh (2026-10-15)

The following are default-branch revisions inspected on this date; repository
recency alone does not establish a better modeling rule. The earlier intake
above remains a historical snapshot. Install into this repository's
`.agents/skills`, preserving the active worktree and existing task files.

| Repository and inspected revision | Local decision |
|---|---|
| [MathWorks SATK](https://github.com/matlab/simulink-agentic-toolkit/tree/0ed76364e5af8098c9731f317a4ee4b17d947d3d), `0ed76364e5af8098c9731f317a4ee4b17d947d3d` (2026-10-14) | Install adapted `simulink-linearize` and `simulink-frequency-response`, retaining manifests and MathWorks license; no toolkit runtime upgrade |
| [npuzsy/simulink-power-electronics](https://github.com/npuzsy/simulink-power-electronics/tree/74d2b967db8a6735b6bbf79c1f24034ab4709b14), `74d2b967db8a6735b6bbf79c1f24034ab4709b14` (2026-05-24) | Apache-2.0; existing local derivative already includes this scope; preserve local extensions |
| [power-simulink-rule](https://github.com/1841220388zzzcccxxx-star/power-simulink-rule/tree/9086c157ae5f96536a67bee08fb7bcfe3cd68736), `9086c157ae5f96536a67bee08fb7bcfe3cd68736` (2026-09-10) | MIT; distill measurement/rate/gate inspection into device contracts; do not install overlapping rulebook |
| [NotPracticingGold builder](https://github.com/NotPracticingGold/simulink-power-electronics-builder/tree/8b56e9af51cce9aaecb6be218924f12cc3206174), `8b56e9af51cce9aaecb6be218924f12cc3206174` (2026-07-22) | MIT; distill port-adjacency and save/reopen layout checks; no universal name hiding or duplicated backup/audit scripts |
| [OrangeXxin agent](https://github.com/OrangeXxin/power-electronics-agent/tree/20219a4c0f8a10a6d07fa1fdc0569c57051d24ff), `20219a4c0f8a10a6d07fa1fdc0569c57051d24ff` (2026-08-16) | MIT; retain source/version/port probing idea; PFC-specific formulas and unsupported library/license generalizations are not transferred |
| [AIPE-Simulation-Skills](https://github.com/FulongLi/AIPE-Simulation-Skills/tree/454738f06547e5ccca1087c6d33e83c67a4d6c86), `454738f06547e5ccca1087c6d33e83c67a4d6c86` (2026-10-07) | Catalog inspected; no repository license found, no content copied |
| [matlab/skills](https://github.com/matlab/skills/tree/f93265a6477ea05028927530f02cd1e847c73d7e), `f93265a6477ea05028927530f02cd1e847c73d7e` (2026-10-14) | Catalog primarily tutoring, assessment, MBSE, and generic utilities; no targeted device skill selected |
| [huanhyougo PE skill](https://github.com/huanhyougo/matlab-power-electronics-skill/tree/4a0db6cf1c3e52da8ce12c41e8d38de1f36b7817), `4a0db6cf1c3e52da8ce12c41e8d38de1f36b7817` (2026-05-17) | Unchanged revision and unresolved license; no new copying |

Searches for dedicated DFIG and wound-field synchronous-machine `SKILL.md`
entries did not identify a qualified addition. Generic motor/PMSG control and
ordinary model repositories are not substitutes for those device contracts.
The shared [machine/converter contract](../../simulink-device-adapters/references/machine-converter-contract.md)
therefore strengthens existing local device knowledge rather than claiming
that a specialized external device skill was found.

Corrections made while adapting the official skills:

- `BatchConsistency` is R2025a+, so feature-detect it for R2024b; check state
  identity explicitly before sensitivity differencing.
- Fixed-Ts sinestream supports a compatible explicit rad/s vector as well as
  a range cell. Preserve Hz/rad/s metadata and adequate low-frequency cycles.
- Independent injection can validate a clean analytical linearization. PRBS
  does not automatically yield a meaningful LTI model under discontinuities.

Rejected community generalizations include mandatory SPS-only libraries,
fixed solver/gain values, NOT-only shoot-through protection, silent filters to
break physical loops, and assuming `ee_lib` needs only a base Simscape license.
Verify actual installed blocks and products. These decisions preserve the
existing sensitivity-first tuning and model-verification authority.

## Targeted GitHub Gap Review (2026-11-03)

Web search covered power-system, impedance, converter, and DFIG skill terms;
repository API trees supplemented indexed results. This is a bounded search,
not a claim to enumerate all GitHub content. Existing VSC-K entries and their
single-source device-pack evidence remain unchanged.

| Candidate / inspected revision | Gap decision |
|---|---|
| MathWorks SATK `f7330c565877a2bce42eb029baa988398e0dc415` (2026-10-29) | New variant-management workflow distilled into the simulation skill; no runtime/toolkit upgrade or bulk installation |
| datathings/marketplace `16729afb6224050a7f6ef2c8511dcfc9b1f5cab4` (2026-10-26) | Pandapower skill and power-flow reference reviewed; add independent network crosscheck, not dynamic-model substitution; Apache-2.0 repository |
| zunyiqingfeng-code/skills `fd9f8c5e6fe8b5f9529dc05b4e21890063087453` | Catalog has Simulink builder but no verified applicable license; no copying |
| qcsui/HiLCoder `9819b4cb6cfed83cc8b654d583cf114dd746e0d7` | Current SKILL.md declares PolyForm Noncommercial, unlike older MIT descriptions; FPGA-specific runtime not installed |
| npuzsy/simulink-power-electronics | Search result scope overlaps the existing local derivative; no duplicate skill |
| ndpvt-web/arxiv-claude-skills ProOPF entry | Search-level candidate only; no primary-method or implementation verification, no admission |

Read only the triggered addition:
[network crosscheck](../../weak-grid-scr-scenario/references/network-crosscheck.md)
or [variant experiment boundary](../../simulating-simulink-models/variant-experiment-boundary.md).
Both are source-reviewed guidance with local model status `untested`. No new
database, generated index, model copy, package dependency, or global skill was
added. Future executions still require qualified operating points, mathematical
sensitivity where applicable, and deterministic model verification.
