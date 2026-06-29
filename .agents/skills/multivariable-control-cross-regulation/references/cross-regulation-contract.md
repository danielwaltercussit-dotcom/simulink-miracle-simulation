# Multivariable Control / Cross-Regulation Tuning Contract

Use this contract when generating or reviewing tuning evidence for strongly
coupled converter control loops. It defines what separates a documented tuning
result from an undocumented gain tweak.

## Required Metadata

### Case level

- case name and source model path
- operating point (load level, SCR/ESCR, control mode GFL/GFM)
- control frame: `dq`, `sequence`, `abc`, or other
- cross-coupling matrix when 2+ loops interact (see below); its absence makes
  the case provisional because cross-regulation risk is unscreened
- optional `gain_matrix` `G` (square, loop order) to enable the RGA /
  singular-value interaction metric
- optional `time_domain` struct linking a measured/simulated disturbance run
  (see "Time-Domain Link and Evidence Tiers")
- optional `delays` struct (control-path latency inventory) and `delay_cases`
  struct array (declared delay scenarios) to enable delay-aware margins
  (see "Delay Inventory and Phase Loss" and "Delay-Case Comparison")

### Per loop

- loop name and controller type (`PI`, `PID`, ...)
- gains before -> after: `kp`, `ki`, and `kd` for PID
- `sample_time_s` (control sample time, > 0)
- `bandwidth_target_hz` (target closed-loop / crossover bandwidth)
- saturation limits `output_min`/`output_max`, or `unsaturated = true`
- anti-windup scheme when the loop is saturated
- at least one stability margin: `phase_margin_deg`, `gain_margin_db`, or
  `damping_ratio`
- optional before/after margins for an improvement claim:
  `phase_margin_before_deg`/`phase_margin_after_deg`,
  `gain_margin_before_db`/`gain_margin_after_db`, `damping_before`/`damping_after`
- `rationale`: WHY this loop was (re)tuned
- disturbance channels the loop rejects (optional but recommended)

A loop missing any of `sample_time_s`, `bandwidth_target_hz`, saturation
handling, a stability margin, or a rationale is reported `provisional` and its
missing fields are listed namespaced as `<loop>.<field>`.

## Cross-Coupling Matrix

- square `NxN` over the loops in `.loops` order, entries are relative coupling
  magnitudes (diagonal = self, nominally 1; off-diagonal 0..1)
- `max_off_diagonal` is the strongest off-diagonal magnitude
- an off-diagonal magnitude at or above `StrongCouplingThreshold` (default 0.30)
  marks a strongly coupled pair; the set must then be tuned as a coupled MIMO
  system, not independent SISO loops
- below threshold, near-decoupled SISO tuning is acceptable but should still be
  stated, not assumed

## Multivariable Interaction Metric (RGA / singular values)

When a square steady-state (or at-frequency) gain matrix `gain_matrix` `G` is
supplied over the loops in order, the helper computes a reproducible interaction
metric (base-MATLAB `inv`/`svd`, no toolbox):

- **RGA** (Bristol) = `G .* inv(G).'`. Report the diagonal and the maximum
  absolute off-diagonal element.
- **Pairing verdict** at tolerance `RgaPairingTolerance` (default 0.30):
  - `diagonal_recommended`: every diagonal RGA element within tolerance of 1;
  - `strong_interaction_review_pairing`: a diagonal element is far from 1;
  - `avoid_diagonal_negative_rga`: any diagonal RGA element is negative (the
    diagonal pairing is closed-loop unstable for that element).
- **Singular-value screen**: `sigma_max`, `sigma_min`, and condition number
  `cond(G)=sigma_max/sigma_min`. `cond(G) >= 10` is flagged `ill_conditioned`
  (an interactive, hard-to-decouple plant).
- A singular/near-singular `G` (`rcond < eps`) reports singular values only and
  marks RGA unreliable, rather than erroring.

The RGA/sigma evidence is contract-consistent (it characterizes a supplied gain
matrix); it is not a model run by itself.

## Before/After Margin Comparison

Per loop, supply `phase_margin_before_deg`/`phase_margin_after_deg`,
`gain_margin_before_db`/`gain_margin_after_db`, and/or
`damping_before`/`damping_after`. The plain `phase_margin_deg`/`gain_margin_db`/
`damping_ratio` fields are read as the "after" value when an explicit `*_after`
is absent. Per-loop verdict:

- `improved`: at least one metric strictly increases and none decreases;
- `worsened`: any metric decreases;
- `unchanged`: endpoints present but equal;
- `no_before_after`: no metric has both endpoints.

## Time-Domain Link and Evidence Tiers

A `time_domain` struct links a disturbance run: `artifact_path`, `source`
(`simulation`/`measurement`/`synthetic`), `disturbance`, and optional measured
metrics (`settling_time_s`, `overshoot_pct`, `peak_coupling`). With
`CurrentIterationDir` set, the artifact must live under it (canonical prefix
match) to be same-iteration.

Evidence tier (reported as `evidence_tier`):

- `hardware_backed`: a same-iteration `measurement` artifact exists;
- `model_backed`: a same-iteration `simulation` (or measurement) artifact exists;
- `contract_consistency`: metadata only (no artifact, stale, or synthetic).

## Improvement Gate

`improvement.status` is the guard against overclaiming:

- `supported`: before/after margins improved AND the run is model-backed;
- `margin_only_unverified`: margins improved on paper but no model-backed run;
- `regression`: any loop margin worsened;
- `claimed_unverified`: gains changed but no before/after margin evidence;
- `supported`: before/after margins improved AND the run is model-backed;
- `margin_only_unverified`: margins improved on paper but no model-backed run;
- `regression`: any loop margin worsened;
- `claimed_unverified`: gains changed but no before/after margin evidence;
- `pseudo_improvement_numeric_delay`: apparent margin gain is attributable to
  reduced NUMERIC delay with unchanged gains (a modelling artifact);
- `blocked_undocumented_delay_change`: a delay changed across cases without
  documentation;
- `no_change`: nothing measurable to report.

The two delay states have the HIGHEST precedence: they block any improvement
claim even if margins and a model-backed run are present. Only `supported` may
be described as a tuning improvement. A documented gain change is never, by
itself, an improvement; neither is removing a numerical delay.

## Delay Inventory and Phase Loss

`delays.sources` is a struct array; each source has `name`, `seconds`, `kind`
(`numeric` for control computation, sample, ZOH, Rate Transition, Unit Delay,
Memory; `physical` for transport/plant), and an optional `block`. The helper:

- sums `total_s`, `numeric_s`, and `physical_s` separately;
- at each evaluation frequency (explicit `delays.eval_freqs_hz`, else the
  maximum documented loop bandwidth target) reports the phase loss of a pure
  transport delay, `phase_loss_deg = 360 * f * tau`, split into numeric and
  physical contributions;
- per loop, subtracts the phase loss at the loop crossover
  (`bandwidth_target_hz`) from the after phase margin to give
  `phase_margin_delay_adjusted_deg`.

Numeric vs physical separation is the point: a margin restored by deleting a
numerical delay is not a physical improvement.

## Delay-Case Comparison

`delay_cases` is a struct array of declared scenarios; the first is the
baseline. Each case has `numeric_delay_s`, `physical_delay_s`,
`phase_margin_deg`, `gains_changed_vs_baseline`, and `documented`. Per
non-baseline case the helper reports `dpm_deg`, `dnumeric_s`, `dphysical_s`,
and a verdict:

- `pseudo_improvement_numeric_delay`: `dpm > 0` AND numeric delay decreased AND
  gains unchanged;
- `margin_gain_with_gain_change`: `dpm > 0` with a documented gain change;
- `margin_loss`: `dpm < 0`;
- `no_margin_change`: otherwise.

`undocumented_delay_change` is set on any case whose delay differs from baseline
without `documented = true`. Either `any_pseudo_improvement` or
`any_undocumented_delay_change` blocks the top-level improvement claim.

## Margin Classification

Per loop, the worst class across whichever margins are supplied:

- `good`: phase margin >= 45 deg, gain margin >= 6 dB, or damping >= 0.10
- `weak`: phase margin >= 30 deg, gain margin >= 3 dB, or damping >= 0.03
- `at_risk`: below the weak thresholds, or any non-positive margin/damping
- `unknown`: no margin supplied

Thresholds are helper parameters; record any non-default value in the report.

## Classification (top-level verdict)

- `documented_tuning`: all required metadata present, worst margin `good`
- `documented_marginal`: required metadata present, worst margin `weak`
- `documented_at_risk`: required metadata present, worst margin `at_risk`
- `undocumented_gain_tweak`: at least one gain changed but NO loop is fully
  documented (the case to reject as evidence)
- `provisional`: required metadata missing but not a pure blind tweak
- `incomplete_no_loops`: no loops supplied

## Interpretation Rules

- Linear margins (phase/gain margin, damping ratio) are small-signal screens at
  one operating point. They do not prove closed-loop stability or acceptable
  cross-regulation. Confirm with a time-domain step/disturbance run.
- A documented gain change is necessary but not sufficient: a documented change
  with an `at_risk` margin is still a problem, just a *traceable* one.
- Sampling adequacy uses `fs / bandwidth_target >= 10` as a rule of thumb. A
  ratio below 10 is reported, not auto-failed, because some loops are
  intentionally bandwidth-limited; explain it in the rationale.
- A single positive sample time and a bandwidth target do not validate the
  discrete implementation; delay, ZOH, and computational latency still matter.
- Cross-regulation typically worsens as SCR drops; a result tuned only at a
  stiff grid does not transfer to weak grid.

## Relation To Other Evidence

- `power-electronics-tuning`: owns the S6 registry knob mechanics and bounds.
  This contract owns the multivariable evidence around a coupled tuning result.
- `small-signal-modal-analysis`: a weak per-loop margin and a low-damping
  coupled mode at a similar frequency are agreeing, non-circular evidence.
- `impedance-frequency-analysis`: if a current-loop bandwidth change moves a
  negative-resistance band, link the impedance summary at the same operating
  point.
- `weak-grid-scr-scenario`: re-tune and re-report margins at the weak-grid
  operating point so margin and large-disturbance evidence share a point.

## Failure Routing

- Undocumented gain tweak: request the missing per-loop metadata before
  treating the change as a result.
- Strong cross-coupling but per-loop SISO margins only: request a MIMO margin
  (e.g. disk margin) or a coupled time-domain test.
- `at_risk` margin after retune: route to `power-electronics-tuning` for a
  bounded knob change and re-screen.
- Weak grid sensitivity suspected: route to `weak-grid-scr-scenario` and re-run
  at low SCR.
- Frequency-domain side effect suspected: route to
  `impedance-frequency-analysis`.

## Boundaries

- Do not run broad controller rewrites in existing device models.
- Do not claim a stability improvement without a reproducible metric or report.
- Do not restore or recreate `NEBUS39V2.slx`; use the read-only desktop lab
  archive for reference only.
