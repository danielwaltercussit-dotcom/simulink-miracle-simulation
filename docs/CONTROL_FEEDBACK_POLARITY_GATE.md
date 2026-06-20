# Control Feedback Polarity Gate

Purpose: catch control-logic sign regressions that generic compile/smoke
verification can miss, such as wiring a negative-feedback summing junction as
positive feedback.

## Current Capability

The reusable helper is:

```matlab
scripts/verification/verify_control_feedback_polarity.m
```

It checks declared `Sum` block `Inputs` strings. A contract is intentionally
explicit:

```matlab
contract = struct( ...
    "block_path", "VoltageController/Sum", ...
    "expected_inputs", "+-", ...
    "description", "Vref minus measured terminal voltage");
```

The model-level gate accepts the same contract:

```matlab
r = verify_power_system_model("candidate_model", ...
    "ControlFeedbackContracts", contract, ...
    "ReportPath", "build/reports/verification/candidate_model.md");
```

When a contract is supplied, `r.checks.control_feedback_polarity` is a hard PASS
condition. When no contract is supplied, the check defaults to true so existing
smoke verification behavior is preserved.

`AutoFixControlFeedback=true` may repair the declared `Sum` block `Inputs`, but
only after the intended sign has been declared in the contract.

## Per-Contract Classification Codes

Each contract in `result.contracts` carries a `classification` field:

| Code | Meaning |
|---|---|
| `PASS` | Block exists, is Sum, Inputs match expected |
| `MISMATCH` | Block exists, is Sum, Inputs differ from expected |
| `FIXED` | Was MISMATCH, AutoFix corrected it successfully |
| `BAD_CONTRACT` | Contract missing required fields (`block_path` or `expected_inputs`) |
| `MISSING_BLOCK` | `block_path` does not resolve to a block in the model |
| `NOT_SUM_BLOCK` | Block exists but is not a Sum block |
| `ERROR` | Unexpected error during check (see `error_id` and `message`) |

The overall result `status` is `PASS` only when every contract classifies as
`PASS` or `FIXED`.

## JSON Report Artifact

A machine-readable JSON report is generated alongside the Markdown report. The
path is derived automatically by replacing the `.md` extension with `.json`, or
can be set explicitly:

```matlab
r = verify_control_feedback_polarity(modelName, contracts, ...
    "ReportPath", "build/reports/feedback.md", ...
    "ReportJsonPath", "build/reports/feedback.json");
```

When called via `verify_power_system_model`, use:

```matlab
r = verify_power_system_model("candidate_model", ...
    "ControlFeedbackContracts", contract, ...
    "ControlFeedbackJsonPath", "build/reports/feedback.json", ...
    "ReportPath", "build/reports/verification/candidate_model.md");
```

JSON schema (stable fields):

```json
{
  "name": "CONTROL_FEEDBACK_POLARITY",
  "model": "<model_name>",
  "status": "PASS|FAIL",
  "passed": true|false,
  "message": "<summary>",
  "contract_count": <int>,
  "mismatch_count": <int>,
  "fixed_count": <int>,
  "contracts": [
    {
      "block_path": "<resolved_path>",
      "expected_inputs": "<string>",
      "actual_inputs": "<string>",
      "actual_inputs_after_fix": "<string>",
      "passed": true|false,
      "fixed": true|false,
      "classification": "PASS|MISMATCH|FIXED|BAD_CONTRACT|MISSING_BLOCK|NOT_SUM_BLOCK|ERROR",
      "message": "<detail>",
      "description": "<from_contract>"
    }
  ]
}
```

## Markdown Report Columns

The Markdown table includes:

| block | expected | actual | after fix | classification | message | description |

## Regression Probe

Run:

```matlab
cd("C:\Users\PC\Desktop\simulink_agent_workspace\simulink_agent_v1")
addpath("tests")
control_feedback_polarity_test
```

The test builds disposable models under `build/generated_models/`:

- `cfp_negative_feedback`: `r - K*y`, expected to pass.
- `cfp_positive_feedback`: `r + K*y`, expected MISMATCH classification.
- `cfp_positive_feedback_autofix`: starts as positive feedback, verifies
  `AutoFix` rewrites it and classifies as FIXED.
- `cfp_gain_block`: minimal model with a Gain block for NOT_SUM_BLOCK test.

Test cases covered:

1. Backward compatibility without contracts (generic smoke still PASS).
2. Negative feedback PASS classification.
3. Positive feedback MISMATCH classification.
4. AutoFix produces FIXED classification.
5. Missing block produces MISSING_BLOCK classification.
6. Non-Sum block produces NOT_SUM_BLOCK classification.
7. Empty `block_path` produces BAD_CONTRACT.
8. Empty `expected_inputs` produces BAD_CONTRACT.
9. JSON report generated with correct schema fields.

## Behavior Gate Placeholder (Future)

A companion behavior-level gate could verify declared step-response or
disturbance-rejection expectations. This would complement the static sign check
by proving dynamic adequacy. Interface sketch (not yet implemented):

```matlab
behavior_contract = struct( ...
    "signal", "y", ...
    "stimulus", "step", ...
    "expected_settling_time", 0.5, ...
    "expected_overshoot_pct", 10, ...
    "description", "Closed-loop voltage step response");
```

This is deferred until real controller models with tuned parameters are
integrated. The polarity gate must pass before any behavior gate runs.

## Pilot Contract Workflow

The first real-model pilot is in:

```
build/reports/control_feedback_polarity_pilot/
```

### Where a contract comes from

A contract must originate from documented project metadata, not from block-name
inference. Acceptable sources:

1. Build script that explicitly constructs the Sum block with a known sign
   (e.g. `run_feedback_logic_probe.m`).
2. Adapter/spec metadata that names the feedback point and its intended
   polarity.
3. Manual declaration by a domain engineer who has reviewed the model.

### Why AutoFix is disabled for first real-model pilots

The pilot contract runs with `AutoFixControlFeedback = false`. Rationale:

- A real model's sign may be intentionally different from a naive expectation
  (e.g. a pre-inverted measurement or a positive-feedback damping loop).
- The polarity gate declares intent but must not silently fix until a domain
  reviewer confirms the contract is correct.
- AutoFix is available for build scripts and test models where the intent is
  programmatically documented.

### What evidence files to read

| Artifact | Purpose |
|---|---|
| `pilot_contract.md` | Human-readable rationale and usage |
| `pilot_contract.json` | Machine-readable contract |
| `pilot_result.md` | Full `verify_power_system_model` report |
| `pilot_result_control_feedback.md` | Polarity gate Markdown detail |
| `pilot_result_feedback.json` | Polarity gate JSON detail |
| `_pilot_run_log.txt` | Raw MATLAB execution log |

### Extending to Simscape SPS masked models

The real DFIG models (`nebus39_dfig*`) have zero visible `Sum` blocks because
feedback paths live inside masked Simscape subsystems. To extend the pilot:

1. A build adapter or model-spec must emit a contract naming the mask-internal
   `Sum` block path.
2. The polarity gate already resolves model-relative paths; the mask path just
   needs to be accurate.
3. Do not search the mask hierarchy automatically without an explicit contract.

## Claude Code Continuation Scope

Continue on branch:

```text
feature/control-feedback-polarity-gate
```

Recommended next steps:

1. Add contract generation for known controller templates in derived DFIG, VSC,
   PLL, voltage, reactive-power, and current-loop subsystems.
2. Implement the behavior-level companion gate when real controller models are
   available.
3. Thread optional contracts through AI-in-loop S7 handoff artifacts so each
   generated model records which control feedback points were checked.

Stop condition: do not infer feedback intent from block names alone for real
models. Require either spec metadata, adapter metadata, or a task-local contract
before a sign mismatch is auto-fixed.
