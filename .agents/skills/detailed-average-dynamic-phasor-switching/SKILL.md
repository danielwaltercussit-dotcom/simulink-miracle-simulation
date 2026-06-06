---
name: detailed-average-dynamic-phasor-switching
description: Use when switching a converter-grid study between detailed-switching, averaged, dynamic-phasor, RMS, or phasor model abstractions in simulink_agent_v1, to record the equivalence evidence (operating point, base values, retained bandwidth, losses, initialization mapping, error metric, time-step ratio) needed before treating two fidelities as comparable.
---

# Detailed / Average / Dynamic-Phasor Model Switching

Use this skill when a study must move between model abstractions - detailed
switching EMT, averaged EMT, dynamic phasor, RMS/positive-sequence, or
load-flow phasor - and the results from one fidelity will be compared against,
or substituted for, the other. It complements `model-fidelity-selector`: that
skill picks a fidelity for a single study; this skill governs a *transition*
between two fidelities and the evidence that keeps the transition honest.

## Core Rule

A fidelity switch is only trustworthy when the two models are shown equivalent
at the operating point and within the bandwidth that matters for the decision.
Never assume a coarser model reproduces a finer model's answer. Record the
equivalence evidence first; a switch with incomplete evidence is `provisional`,
not `pass`, and must not be presented as interchangeable.

## Decision Table

Choose the fidelity the *destination* study needs, then justify the switch.

| Study objective | Source fidelity | Target fidelity | Must not silently drop |
|---|---|---|---|
| Microsecond EMT / protection / harmonics | detailed switching | (stay) | modulation, dead-time, device losses, sub-cycle waveform |
| Control-loop transient (PLL/VSG, DC-link) | detailed switching | averaged EMT | current limit, controller states, DC-link dynamics |
| Low-frequency oscillation / mode interaction | averaged EMT | dynamic phasor | retained bandwidth, phase/unbalance structure, damping |
| Fault ride-through / recovery | detailed or averaged EMT | averaged EMT or dynamic phasor | fault timing, voltage recovery, current limiting |
| Planning-level sweep / load flow | dynamic phasor / averaged EMT | RMS or phasor | fast-control failure modes, switching-driven stress |

Switching *up* (refine) toward more detail is usually safe but costs step size.
Switching *down* (coarsen) toward less detail is where equivalence evidence is
mandatory, because fast dynamics are being deliberately removed.

## Equivalence Evidence Contract

Before a switch is `pass`, record all of:

1. **operating_point** - the bias point the equivalence is asserted at.
2. **base_values** - per-unit / SI bases shared by both models.
3. **bandwidth_retained_hz** - frequency band the target model still represents.
4. **losses** - which losses are retained vs neglected by the target model.
5. **initialization_mapping** - how source states map to target initial states.
6. **error_metric** - the agreed comparison metric and its acceptance bound.
7. **time_step_ratio** - target_dt / source_dt, consistent with the direction
   (coarsen expects ratio >= 1, refine expects ratio <= 1).

Any missing field, an unrecognized fidelity name, or a time-step ratio that
contradicts the switch direction forces `provisional` status.

## Documented vs Measured Equivalence

The skill reports two independent axes and never conflates them:

- **documented_equivalence** - the contract above is complete and
  self-consistent. This is a metadata check; on its own it is *not* proof that
  the two models actually agree.
- **measured_equivalence** - a real baseline-regression comparison was supplied:
  an actual numeric error value, a numeric acceptance bound, the compared run
  ids, and same-study artifact files that exist on disk under a study root.

A documented `error_metric` *target* (e.g. "peak |Vpcc| error < 2%") is part of
documented equivalence only. It can never produce a measured pass. Only a real
numeric error within its numeric bound, backed by on-disk same-study artifacts,
yields `measured_status = pass` and `overall_status = measured_pass`. Treat
`measured_pass` as the single state that asserts model-backed numerical
equivalence.

## Workflow

1. Name the source and target fidelity and the study objective.
2. Classify the direction (refine, coarsen, or same).
3. Fill the equivalence-evidence contract above.
4. Run the helper to record the switch and its status.
5. If `provisional`, resolve the missing/inconsistent fields before comparing
   results across the two models.

## Helper

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/analysis")
s = summarize_fidelity_switch_evidence( ...
    "CaseName","vsc_weakgrid_emt_to_avg", ...
    "StudyObjective","PLL transient after coarsening to averaged EMT", ...
    "FromFidelity","switching_emt", ...
    "ToFidelity","averaged_emt", ...
    "OperatingPoint","P=0.8pu Q=0 Vg=1.0pu SCR=2.5", ...
    "BaseValues","Sb=2MVA Vb=690V fb=50Hz", ...
    "BandwidthRetainedHz",2000, ...
    "Losses","switching losses neglected; conduction lumped", ...
    "InitializationMapping","trim averaged model to switching steady state", ...
    "ErrorMetric","peak |Vpcc| error < 2% over 0-200ms", ...
    "TimeStepRatio",20);
```

To attach a real baseline-regression comparison (measured equivalence), add the
measured fields. Without them the switch stays documented-only:

```matlab
s = summarize_fidelity_switch_evidence( ...
    "CaseName","vsc_weakgrid_emt_to_avg", ...
    "FromFidelity","switching_emt", "ToFidelity","averaged_emt", ...
    "OperatingPoint","P=0.8pu Q=0 Vg=1.0pu SCR=2.5", ...
    "BaseValues","Sb=2MVA Vb=690V fb=50Hz", ...
    "BandwidthRetainedHz",2000, "Losses","switching neglected", ...
    "InitializationMapping","trim to switching steady state", ...
    "ErrorMetric","peak |Vpcc| error < 2%", "TimeStepRatio",20, ...
    "MeasuredErrorValue",0.013, ...      % actual number from the comparison
    "MeasuredErrorBound",0.02, ...       % numeric acceptance bound
    "ErrorMetricDefinition","max|Vpcc_switch - Vpcc_avg|/Vbase, 0-200ms", ...
    "ComparedFromRunId","run_switch_001", "ComparedToRunId","run_avg_001", ...
    "SameStudyArtifactPaths",[ ...
        "build/reports/baseline_regression/study42/switch_vpcc.csv", ...
        "build/reports/baseline_regression/study42/avg_vpcc.csv"], ...
    "SameStudyRoot","build/reports/baseline_regression/study42");
% s.overall_status == "measured_pass" only if 0.013 <= 0.02 AND both artifact
% files exist on disk under study42 AND the documented contract is complete.
```

## Output

```text
build/reports/e2_fidelity_switching/<case>/fidelity_switch_summary.md
build/reports/e2_fidelity_switching/<case>/fidelity_switch_summary.json
```

## Routing

- Use `model-fidelity-selector` first to choose each fidelity in isolation.
- Use `baseline-regression` to compare the two fidelities against a golden run.
- Use `small-signal-modal-analysis` when the switch must preserve a damping or
  mode-ownership result.
- Use `ibr-model-validation-evidence` before declaring the switched-to model
  ready for external study use.

## Scope Limit

This skill records and checks equivalence *evidence*. For documented
equivalence it proves the metadata is present and self-consistent. For measured
equivalence it ingests a real baseline-regression result (numeric error vs
numeric bound) and verifies the backing artifacts exist on disk under one study
root - but it does not itself build, run, or simulate a model, and it does not
compute the error. Supply the measured number from an actual
`baseline-regression` comparison. A documented target alone never reaches
`measured_pass`. Read `references/equivalence-contract.md` before changing field
names, fidelity labels, or status wording.
