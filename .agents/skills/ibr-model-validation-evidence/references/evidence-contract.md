# IBR Validation Evidence Contract

Use this contract when preparing a handoff-ready model evidence package.

## Required Sections

Include:

- model identity and intended use
- source model and spec provenance
- parameter provenance
- controller mode and setting provenance
- fidelity decision
- initialization evidence
- small disturbance evidence
- large disturbance or fault-recovery evidence
- weak-grid evidence if applicable
- regression or cross-fidelity comparison if applicable
- snapshot audit status
- limitations and excluded claims

## Evidence Status

Use these labels:

- `PASS`: evidence exists, was re-read, and supports the claim.
- `WARN`: evidence exists but is incomplete, indirect, or outside the exact
  intended range.
- `MISSING`: evidence is required but absent.
- `N/A`: evidence is not required for the stated intended use.

## Minimum Handoff Bar

For a model package to be handoff-ready:

- no required section is `MISSING`,
- fidelity limitations are explicit,
- parameter changes are traceable,
- at least one disturbance case exists beyond no-fault smoke,
- weak-grid claims are backed by SCR/ESCR evidence, and
- snapshot audit is `PASS` or the missing files are explicitly listed.

## Routing

- Missing fidelity decision: `model-fidelity-selector`.
- Missing low-SCR coverage: `weak-grid-scr-scenario`.
- Missing modal explanation: `small-signal-modal-analysis`.
- Missing control fairness: `gfl-gfm-control-comparison`.
- Missing package completeness: `snapshot-auditor`.
