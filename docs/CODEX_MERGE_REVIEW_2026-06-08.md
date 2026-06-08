# Codex Global Merge Review - 2026-06-08

Target branch: `integration/skills-maturation-2026-06`

## Merged

- `codex/d3-storage-bms`
- `codex/e1-emt-switching-level`
- `codex/f1-analytic-fha-impedance`
- `codex/f2-control-cross-regulation`
- `codex/f3-stability-boundary-scan`
- `codex/m2-hil-readiness`

`codex/m1-hybrid-solver-multirate` was not merged again because its reviewed
baseline is already present on the integration branch. Uncommitted next-stage
M1 work in the primary workspace was deliberately preserved and excluded.

## Not Merged

### D1 VSC/GFL-GFM

`summarize_vsc_weakgrid_delay_benchmark` classifies the root cause from evidence
file presence alone. An existing M1 path yields
`numerical_pseudo_instability`; an existing F3 path yields
`physical_instability`, without parsing the artifact verdict, status, study
identity, or attribution result.

Required repair:

- parse and validate F3/M1 evidence content;
- require same-study identity and an affirmative usable verdict;
- use `insufficient_evidence` when evidence is absent, invalid, stale,
  inconclusive, or contradictory;
- add negative tests for empty, malformed, WARN, and non-attributing evidence.

### D2 MMC/HVDC

The contract states that a `stiff_source` DC line cannot carry DC-line
fault/cable transient evidence, but the helper records this as an advisory WARN.
Advisory WARNs are allowed through `handoff_ready`, so a physically incapable
line representation can currently support a handoff-ready DC-fault package.

Required repair:

- make this combination blocking when DC-line fault/cable-transient evidence is
  claimed;
- keep it advisory only when no such transient claim is being made;
- change Case L and add a negative handoff-readiness assertion.

### E2 Fidelity Model Switching

The new Skill text gives the dynamic-phasor relation as:

```text
dI/dt = (-R/L + j*w0)*(-I) + Vdc*D/L
```

The extra negation reverses the resistive damping sign. The runnable prototype
also compares switching and averaged RL branches; it is not a runnable
dynamic-phasor solver.

Required repair:

- correct and derive the frame/sign convention;
- label the current runnable prototype strictly as switching-versus-average;
- do not claim a dynamic-phasor engine until one is actually simulated;
- add a test that rejects an unstable-sign passive RL dynamic-phasor equation.

## Reproduced Validation

Branch-local:

- D1: 6/6, 8/8, 12/12 contract cases passed, but semantic review blocked merge.
- D2: 12/12 plus 3/3 real model probe passed, but semantic review blocked merge.
- D3: 10/10 passed.
- E1: 7/7, 5/5, 5/5 plus 1/1 real Simulink run passed.
- E2: 11/11 plus 5/5 real prototype run passed, but semantic review blocked merge.
- F1: 16/16 passed.
- F2: 14/14 passed.
- F3: 11/11 passed.
- M1: 10/10 passed; reviewed baseline already integrated.
- M2: 5/5 plus 3/3 real load/update/simulate passed.

Integration regression:

- all merged-package tests passed after merge;
- E1 and M2 model-backed simulations reran successfully;
- existing D1, D2, and E2 baseline tests remained green;
- `git diff --check` passed after removing one M2 end-of-file blank line.

## Preserved Work

- No private model was restored.
- No lab-archive file was edited.
- No branch-specific Claude packet was overwritten.
- Dirty primary-workspace M1 and sibling-package files were not staged, deleted,
  or merged.
