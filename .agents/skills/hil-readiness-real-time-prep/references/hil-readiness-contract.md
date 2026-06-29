# HIL / Real-Time Readiness Contract

Use this contract when generating or reviewing software-side HIL / real-time
readiness evidence for a power-electronics model bound for RTDS / OPAL-RT /
Speedgoat-style deployment.

## Scope And Honesty Boundary

- This contract covers software-side readiness. It has two entry points: a
  contract-only path (`summarize_hil_readiness`, runs on a hand-supplied
  manifest, never touches a model) and a model-backed path
  (`hil_readiness_from_model`, compiles/simulates a real model and reads facts
  from it). Neither path runs on real-time hardware.
- A `PASS` contract means the manifest is complete and internally consistent and
  no blocking risk remains - i.e. it is reasonable to *attempt* real-time
  bring-up. It is not proof of real-time execution.
- `real_time_deployable` is true only when a real HIL run log (no overruns) is
  attached via `hardware_evidence`. Do not claim hardware validation otherwise.
- The four status axes are independent and must not be collapsed:
  `contract_status` (manifest quality), `model_validation_status`
  (`not_model_backed` | `model_backed`), `readiness_class`
  (`software_readiness_only` | `hardware_backed`), and `real_time_deployable`.

## Required Manifest Metadata

Record:

- `case_name`, `source_model_or_script`, `target_platform`
- `solver_type` (`fixed_step` | `variable_step`) and `fixed_step_s`
- `fastest_event_s`: shortest event the target must resolve (PWM carrier
  period, switching event, fastest control tick)
- `algebraic_loops_present` (logical) and `algebraic_loops_broken`
- `unsupported_blocks_checked` (logical) and `unsupported_blocks` (cellstr of
  remaining offenders; empty = none)
- `codegen_target_supported` (logical) and `continuous_states_present`
- `partitions`: struct array of `name`, `rate_s`, `compute_s`
- `io_channels`: struct array of `name`, `direction`, `placeholder`
- `cpu_cores` and `step_budget_s` (defaults to `fixed_step_s` if absent)
- `hardware_evidence`: struct `supplied`, `artifact_path`, `overruns`, `note`

Undocumented blocking fields (solver, algebraic loops, unsupported-block scan,
codegen support) yield `MISSING`, never a silent pass.

## Status Semantics

Per check: `PASS` | `WARN` | `MISSING` | `N/A`, plus a `blocking` flag.

- `contract_status` = `MISSING` if any check is MISSING, else `WARN` if any is
  WARN, else `PASS`.
- `blocking_findings` = blocking checks whose status is not PASS/N/A.
- `handoff_ready` = `blocking_findings` is empty. Non-blocking WARN/MISSING
  (partitioning, io_mapping) do not block.
- `readiness_class` = `hardware_backed` only when `hardware_evidence.supplied`
  is true, an `artifact_path` is set, and `overruns` is false; else
  `software_readiness_only`.
- `model_validation_status` = `model_backed` only when `model_provenance` is
  present AND `model_provenance.compiled_ok` is true (the model actually
  compiled); else `not_model_backed`. Default on a hand-supplied manifest is
  `not_model_backed`.
- `real_time_deployable` = `handoff_ready` AND `hardware_backed`.

## Model-Backed Evidence

The model-backed path (`hil_readiness_from_model`) attaches a `model_provenance`
struct to the manifest with: `is_model_backed`, `model`, `update_ok`,
`compiled_ok`, `simulated`, `n_continuous_states`, `n_discrete_states`,
`discrete_rates_s`, and any error strings. The status engine reads it to set
`model_validation_status`.

Honesty ladder (each rung is strictly stronger than the one before):

1. config metadata - a hand-supplied manifest only.
2. compile - `compiled_ok=true`; solver/step/rates/states are real. This is the
   bar for `model_backed`.
3. host simulation - `simulated=true`; the model runs on the host. Still not a
   timing guarantee.
4. codegen build - NOT performed by this skill; `codegen_target_supported` stays
   undocumented (MISSING) unless asserted out of band.
5. hardware run - a real HIL log; the only path to `hardware_backed` and
   `real_time_deployable`.

Facts a compile cannot reveal, so the caller must supply them (never fake from
the model):

- `fastest_event_s` - the fastest discrete rate equals the fixed step, so it
  cannot stand in for the physical event the target must resolve. Caller-only;
  NaN => feasibility reports it undocumented.
- per-partition `compute_s` - not measurable by a software probe, so
  `latency_budget` is MISSING (non-blocking) on a pure model-backed run. Host
  simulation time is NOT target latency; do not substitute it.

## Check Rules

1. **fixed_step_feasibility** (blocking): variable-step => WARN; fixed step must
   be >0 and resolve the fastest event with `fastest_event_s / fixed_step_s >= 2`
   (a minimum resolution rule, not a sufficiency guarantee). Undocumented step
   or fastest event => MISSING/WARN.
2. **algebraic_loop_risk** (blocking): undocumented => MISSING; present and
   unbroken => blocking WARN; present but broken => non-blocking WARN
   (confirm numerics on target); absent => PASS.
3. **unsupported_blocks** (blocking): scan not run => MISSING; offenders remain
   => WARN; none => PASS.
4. **codegen_constraints** (blocking): support undocumented => MISSING; target
   unsupported => blocking WARN; continuous states under fixed step =>
   non-blocking WARN (discretize / local solver); else PASS.
5. **partitioning** (non-blocking): no partitions => MISSING (single-rate
   assumption); partitions missing `rate_s` => WARN; else PASS.
6. **io_mapping** (non-blocking): no channels => MISSING; placeholder channels
   => WARN (bind before HIL); else PASS.
7. **latency_budget** (blocking): needs `step_budget_s` (or `fixed_step_s`) and
   per-partition `compute_s`; without cores, single-core worst case
   (serialized); with cores, optimistic even-split; compute over budget =>
   blocking WARN (overrun risk). Missing inputs => non-blocking MISSING.

## Interpretation Rules

- The latency estimate is an order-of-magnitude screen. Even-split across cores
  is optimistic; real task mapping, I/O latency, and solver overhead can be
  worse. A PASS here is a go-ahead to measure, not a timing guarantee.
- The `>=2x` step rule is a floor; stiff converter dynamics often need far more
  margin. Pair with M1 (`hybrid-solver-multirate-simulation`) for solver/step
  sizing across time scales.
- A broken algebraic loop changes numerics; re-verify behavior on the target.

## Relation To Other Evidence

- M1 hybrid-solver: solver type, step sizing, and rate-transition decisions
  feed checks 1 and 7. Keep step/rate numbers consistent across both packages.
- Device packs (D1/D2/D3): unsupported-block and partitioning realities come
  from the device model; cite the device skill that produced the manifest.
- IBR validation: a HIL run log can become a hardware-backed evidence artifact
  for `ibr-model-validation-evidence`; pass the artifact path explicitly.

## Failure Routing

- Blocking findings present: resolve them before any hardware time. Variable
  step / under-resolved step => choose a fixed step (route to M1). Unbroken
  algebraic loop => break it. Unsupported blocks => replace or stub. Latency
  overrun => re-budget, re-partition, or coarsen the step.
- `MISSING` contract: request the undocumented metadata; do not infer defaults.
- Hardware claim requested but no evidence: keep `software_readiness_only` and
  state that a real-time run log is required.
