# Harness Contract

Use this reference when creating or reviewing S7 test artifacts.

## True Harness When Possible

Use Simulink Test when:

- the target exposes signal-based Inport/Outport interfaces
- a repeatable test sequence or baseline comparison is meaningful
- the required toolbox is available

Record the `.mldatx` or MATLAB test file path and the exact run command.

## Fallback When Needed

Use `simulink-model-verification` fallback when:

- the model is mostly physical SPS wiring
- Simulink Test is unavailable
- the quickest hard gate is compile + smoke + finite logged outputs

The fallback still writes `sltest_summary.md`; it must state that Simulink Test
was skipped and name the verification artifact used instead.

## Minimum Assertions

At least one of:

- required signal exists
- logged numeric outputs are finite
- voltage/current metric remains inside threshold
- baseline/candidate difference stays within tolerance
- scenario recovery metric passes

## Routing

- Regression drift: `baseline-regression`
- Missing or non-finite signal: `simulink-model-verification`
- Visual failure evidence: `diagnostic-plotting`
- Specific block-level failure: `simulink-debug-commandline`
