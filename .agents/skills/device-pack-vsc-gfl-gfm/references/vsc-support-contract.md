# VSC / GFL-GFM Support Contract

Use this contract when generating or reviewing VSC device support evidence for
grid-following / grid-forming renewable-interconnection studies.

## Required Metadata

Record:

- case name and evidence source: `measured`, `simulated`, `analytic`,
  `synthetic`, or `planned`
- control mode: `GFL`, `GFM`, or `grid_support`
- operating point (load/dispatch level, SCR/ESCR, control mode) the case is
  taken at
- base values: any subset of `s_base_mva`, `v_base_kv`, `f_base_hz`
- grid strength: SCR and/or ESCR plus the method used to realize it
  (e.g. `thevenin_L`)
- synchronization paradigm: `pll`, `vsg`, `droop`, `voc`, or `vsm`
- active-power control mode and reactive-power control mode
- evidence artifact pointers: fault-ride-through, modal, impedance, and
  time-domain (EMT/RMS) validation

## Dimensions

Assumption dimensions (documented vs not):

- `control_mode`, `grid_strength`, `synchronization`,
  `active_power_control`, `reactive_power_control`

Artifact dimensions (evidence pointer present vs not):

- `fault_ride_through`, `modal_evidence`, `impedance_evidence`,
  `time_domain_validation`

## Evidence Status

Use these labels, consistent with the IBR evidence contract:

- `PASS`: assumption documented, or artifact backed by a real file on disk that
  is present and same-study. A fault-case *label* or other intent with no
  artifact file is `WARN`, not `PASS` -- a label is not evidence.
- `WARN`: present but provisional, indirect, intent-only (label without a file),
  or downgraded because the case identity is undocumented.
- `MISSING`: required dimension undocumented, or required artifact absent (or a
  supplied path does not exist).
- `N/A`: not required for the stated control mode / intended use.

## Provisional Rule

A case is provisional when any of `control_mode`, `operating_point`,
`grid_strength`, or `base_values` is undocumented. While provisional:

- every artifact `PASS` is downgraded to `WARN`, so a draft case cannot present
  validation-grade evidence; and
- the case is never handoff-ready.

## Control-Mode Consistency

The consistency screen surfaces declared assumptions that contradict the stated
mode. It is a `WARN`, not a hard error (a study may intentionally explore a
hybrid), but it blocks handoff readiness until resolved or justified:

- `GFL` with grid-forming synchronization (`vsg` / `droop` / `voc` / `vsm`)
- `GFM` with `pll` synchronization (grid-forming usually self-synchronizes)
- `GFM` with a fixed `q_setpoint` (grid-forming typically regulates voltage)

## Minimum Handoff Bar

For a VSC device case to be handoff-ready:

- it is not provisional (identity documented),
- no dimension is `MISSING`,
- the control-mode consistency screen is clean or the deviation is justified,
  and
- the fault-ride-through and time-domain dimensions are backed by same-study
  artifacts (not downgraded WARN).

## Same-Iteration Evidence Rule

When composing a case from existing artifact files (weak-grid SCR/ESCR, modal,
impedance, time-domain), an artifact is admissible only when it belongs to the
current study iteration:

- An artifact path is same-iteration iff its canonical absolute path equals, or
  is a child of, the canonical current iteration directory. The child test uses
  a trailing separator so a sibling directory whose name is a string prefix
  (e.g. `iter2` vs `iter`) does not false-match.
- `used`: file exists and is same-iteration; it feeds the support helper.
- `stale`: file exists but lives under another iteration; rejected, never fed
  to the helper, so it cannot produce a `PASS`.
- `missing`: a path was supplied but the file is absent; rejected.
- `not_set`: no path supplied; the dimension is `N/A` downstream.

Same-iteration acceptance is bookkeeping that an artifact belongs to this
iteration, not a model-backed or hardware-backed proof of its own claim.

## GFL/GFM Comparison Completeness

A GFL-vs-GFM comparison is `comparison_complete` only when:

- the pair covers exactly one `GFL` and one `GFM` device (not two of one mode,
  not `grid_support`);
- each case is individually handoff-ready (see Minimum Handoff Bar); and
- the fairness axes (`network`, `dispatch`, `disturbance`, `observables`) are
  present and equal across both cases, unless an axis is listed in BOTH cases'
  `justified_differences`.

Completeness is the precondition for routing to `gfl-gfm-control-comparison`; it
is not a performance verdict and runs no model.

## Interpretation Rules

- A `PASS` records documentation or pointer presence, never a proven physical
  result. Stability, fault-ride-through, and weak-grid claims still require the
  named time-domain and, where applicable, modal/impedance evidence.
- A single positive-sequence impedance artifact can miss dq-frame or
  sequence-coupled effects; defer to `impedance-frequency-analysis` limitations.
- GFL weak-grid risk is PLL-band and SCR-dependent; GFM risk is
  inertia/voltage-forming and fault-current-limit dependent. Do not transfer one
  mode's acceptance metric to the other without justification.
- No HIL / real-time validation is implied by any status here.

## Relation To Other Evidence

- `gfl-gfm-control-comparison`: this pack supplies the per-device support
  intake; the comparison skill owns fair head-to-head scenario setup.
- `weak-grid-scr-scenario`: source of the grid-strength matrix the
  `grid_strength` dimension references.
- `small-signal-modal-analysis` / `impedance-frequency-analysis`: producers of
  the `modal_evidence` / `impedance_evidence` artifacts.
- `ibr-model-validation-evidence`: consumes this summary as the VSC-device
  frequency/control intake; pass the report path explicitly.

## Failure Routing

- No documented operating point or grid strength: report provisional and
  request the point; route to `weak-grid-scr-scenario`.
- Missing modal explanation: route to `small-signal-modal-analysis`.
- Missing frequency-domain artifact: route to `impedance-frequency-analysis`.
- Mode/sync contradiction: resolve the control declaration or document the
  hybrid intent before handoff.
- Comparing GFL vs GFM: route to `gfl-gfm-control-comparison` once both device
  cases have comparable support summaries.
