# Candidate Label Taxonomy

Labels are candidate review hints. They must not be treated as model verdicts.
Every label needs deterministic follow-up before it affects acceptance,
tuning, modal identity, or experiment launch decisions.

## Labels

### ambient_masked

- Meaning: a suspected response may be hidden by persistent ambient or baseline
  content in the observation window.
- Evidence clues: similar nonzero content in null windows, weak event contrast,
  or report notes that a forced perturbation is masked by ambient behavior.
- Required gate: current simulation experience plus modal or plotting review.
- Forbidden action: do not accept modal identity or tune from this label alone.

### modal_identity_unproven

- Meaning: a frequency, decay, or oscillation candidate has not been tied to a
  verified mode.
- Evidence clues: peak-only reasoning, missing eigenvalue linkage, or a report
  that names a mode without deterministic modal evidence.
- Required gate: `small-signal-modal-analysis` modal contract.
- Forbidden action: do not confirm modal identity from classifier confidence.

### memory_unbounded

- Meaning: a workflow may accumulate data, figures, history, or MATLAB state
  without a bounded retention policy.
- Evidence clues: growing run folders, repeated appended logs, unbounded
  iteration history, or report warnings about memory pressure.
- Required gate: relevant execution or report-generation contract.
- Forbidden action: do not continue a long run solely to gather more data.

### operating_point_unqualified

- Meaning: a comparison or diagnosis lacks a qualified operating point.
- Evidence clues: missing scenario, load flow, initial condition, solver,
  StopTime, or disturbance contract.
- Required gate: simulation execution and model-verification contracts.
- Forbidden action: do not compare baselines or candidates as equivalent.

### degenerate_time_axis

- Meaning: a plot, metric, or exported signal has an invalid or uninformative
  time axis.
- Evidence clues: duplicate timestamps, zero duration, unsorted time vectors,
  or a single sample used as a waveform.
- Required gate: diagnostic plotting and simulation-output checks.
- Forbidden action: do not derive oscillation, settling, or damping claims.

### physical_injection_observability_split

- Meaning: physical disturbance injection and measured observability may not
  align.
- Evidence clues: perturbation is present at one location but absent or
  ambiguous in selected measurement channels.
- Required gate: source identity and measurement-channel review.
- Forbidden action: do not confirm physical source identity.

### validator_hardcoded_runid

- Meaning: a validator or report may depend on a fixed run id instead of the
  active evidence bundle.
- Evidence clues: hardcoded folder names, stale latest pointers, or mismatch
  between claimed and inspected run ids.
- Required gate: bundle manifest and validator input review.
- Forbidden action: do not promote validation results without confirming the
  active bundle.

### layout_structure_drift

- Meaning: an auto-layout or cleanup step may have changed model structure
  instead of only moving blocks.
- Evidence clues: changed block count, line count, subsystem path, or port
  topology after a layout operation.
- Required gate: pre/post layout structure snapshot.
- Forbidden action: do not treat layout as move-only evidence until snapshots
  match.

### control_feedback_polarity_mismatch

- Meaning: a control loop may have the wrong feedback sign or polarity.
- Evidence clues: sign mismatch notes, unstable response after controller
  insertion, or disagreement between derivation and Simulink wiring.
- Required gate: derivation review, wiring review, and deterministic polarity
  gate.
- Forbidden action: do not tune gains to mask polarity uncertainty.
