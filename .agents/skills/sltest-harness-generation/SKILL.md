---
name: sltest-harness-generation
description: Use when creating, reviewing, or expanding Simulink Test harnesses for simulink_agent_v1 generated power-system models, including ai-in-loop S7, signal-port subsystem tests, smoke regression tests, baseline/candidate comparisons, and fallback test summaries when Simulink Test is unavailable.
---

# SLTest Harness Generation

Use this skill when the task is to make S7 more repeatable through persistent
tests rather than one-off manual simulation.

## Core Rule

Create the smallest harness that can fail for the right reason. Prefer a
component or subsystem harness when ports are signal-based; use model-level
verification fallback when the model exposes mostly physical SPS connections.

## Workflow

1. Inspect the model or subsystem interface.
2. Decide whether a true Simulink Test harness is possible.
3. If possible, create or update a persistent test artifact under `tests/`.
4. If not possible, document the fallback to `simulink-model-verification`.
5. Write or update the S7 summary under the loop iteration directory.
6. Connect failures to `baseline-regression`, `diagnostic-plotting`, or
   `simulink-debug-commandline` as needed.

## Harness Criteria

A useful harness has:

- named model/subsystem under test
- explicit setup/init command
- stop time and solver assumptions
- required logged outputs or assessed signals
- pass/fail criteria with units
- deterministic output report path

Do not create a test that only checks that MATLAB did not throw; include at
least one model-specific observable.

## Output

Preferred locations:

```text
tests/<model>_<purpose>_test.m
build/reports/loop/iter_<NN>/sltest_summary.md
build/reports/sltest/<model>_<purpose>.md
```

Read `references/harness-contract.md` before adding a new S7 artifact shape.
