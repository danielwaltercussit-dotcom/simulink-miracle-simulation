---
name: baseline-regression
description: Use when comparing generated Simulink power-system models against baselines or golden runs in simulink_agent_v1, including oracle models, baseline/candidate smoke simulations, tolerance bands, regression reports, reusable S7 checks, and AI-in-loop pass/fail evidence.
---

# Baseline Regression

Use this skill when a generated model must be compared with a known-good model,
golden run, or prior snapshot before accepting a change.

## Core Rule

Compare like with like. A regression result is meaningful only when the baseline
and candidate use the same scenario, stop time, solver assumptions, signal list,
and tolerance policy.

## Baseline Sources

Prefer baselines in this order:

1. A project oracle explicitly marked read-only.
2. A previous AI-in-loop PASS snapshot.
3. A prior generated model with matching spec and build provenance.
4. A recorded metrics file from the same scenario.

Never modify oracle models to make a regression pass.

## Workflow

1. Name the baseline and candidate.
2. Record scenario, stop time, solver, and initialization path.
3. Select required signals and tolerances before inspecting results.
4. Run or reuse paired simulations.
5. Compare metrics and, when useful, route overlays to `diagnostic-plotting`.
6. Write a regression report and route failures to tuning, model verification,
   or debugging.

## Output

Write reports under:

```text
build/reports/regression/<candidate>_vs_<baseline>.md
build/reports/regression/<candidate>_vs_<baseline>.json
```

The report should include:

- baseline and candidate paths
- signals compared
- tolerances and units
- pass/fail summary
- largest deviations
- linked diagnostic plots, if generated

Read `references/regression-contract.md` before defining new tolerances.
