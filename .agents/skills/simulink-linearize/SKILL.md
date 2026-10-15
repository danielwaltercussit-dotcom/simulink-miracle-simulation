---
name: simulink-linearize
description: Extract and qualify state-space linearizations from Simulink models for modal participation, parameter sensitivity, and I/O validation; use with the project operating-point and model-verification gates.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  upstream: matlab/simulink-agentic-toolkit
  upstream_commit: 0ed76364e5af8098c9731f317a4ee4b17d947d3d
  adaptation_date: "2026-10-15"
---

# Simulink Linearization

Project adaptation of the MathWorks skill. Copyright 2026 The MathWorks, Inc.
Retain LICENSE.md. Use with MathWorks products and service offerings.

Use this for a model-backed A/B/C/D extraction or an I/O linear model. Route
interpretation and tuning to
[small-signal-modal-analysis](../small-signal-modal-analysis/SKILL.md).
A fitted transfer function does not establish physical state participation.

## Qualify the Experiment

1. Read the authorized model and operating-point evidence. Check the installed
   release and availability of Simulink Control Design and Control System
   Toolbox. The upstream manifest lists minimum R2023a; individual options may
   need newer releases. Use the existing math-model path if products are absent.
2. Apply [device contracts](../simulink-device-adapters/references/machine-converter-contract.md)
   when VSC, DFIG, or synchronous-machine bases, angles, signs, or initialization
   are involved. Preserve the canonical model and active task ownership.
3. Infer analysis I/O from the task, inspected paths, or existing `getlinio(mdl)`.
   A `linio` point refers to a block output port. Trace Scope, Terminator, and
   Outport sinks upstream. Record whether an opening changes the feedback
   topology. A closed-loop tuning study must preserve its intended feedback.
4. Use a qualified equilibrium or an explicitly identified trajectory snapshot.
   `findop` convergence, initial conditions, or elapsed simulation time alone
   does not establish equilibrium; inspect residuals, drift, limits, and dispatch.
   Switching-periodic or limiter-active dynamics may need a different analysis.
5. Record intended state coverage before extraction. A reduced I/O realization
   can omit unobservable internal unstable modes. For full-state participation,
   retain state paths/order and check the applicable reduction options.

## Extract

The following assumes that `mdl`, `io`, and `op` already describe the qualified
experiment; it does not launch a trim or a simulation:

```matlab
opts = linearizeOptions;
opts.StoreAdvisor = true;
opts.BlockReduction = 'off'; % preserve states for block-by-block analysis
[sys, opUsed, info] = linearize(mdl, io, op, opts);
[A, B, C, D] = ssdata(sys);
stateNames = sys.StateName;
sampleTime = sys.Ts;
```

`BlockReduction='off'` is meaningful for the block-by-block algorithm.
Numerical perturbation algorithms can still reduce states. Check state paths,
dimensions, active variants, and state identity in the returned result; the
option is not a full-state proof. Keep the unreduced result before `minreal`,
balanced reduction, or a conversion that removes state ownership.

Respect the continuous/discrete domain and actual sample time. Do not force
`SampleTime=0` or drop discrete states to make mixed-rate dynamics easier to
interpret. The modal skill supports discrete poles with a positive sample time.

For several transfer paths, consider `slLinearizer` with named analysis points
to avoid repeated compiles, while recording loop-opening and feedback signs.

## Diagnose and Validate

- For suspicious zero or nonfinite results, enable the advisor and capture
  `result = advise(info.Advisor)`; omitting the output may open a GUI.
  Inspect the reported blocks rather than guessing new gains.
- Zero DC gain is valid for high-pass/washout paths. Check finite-frequency
  response and state coverage before calling it a failed linearization.
- A hard discontinuity can make a local derivative unsuitable. Route to
  [simulink-frequency-response](../simulink-frequency-response/SKILL.md) for
  qualified injection evidence; it cannot recover physical state identities.
- Compare a small perturbation at the same I/O and operating point with the
  model response before using A for accepted sensitivities. Same-A transfer
  functions and eigenvalues are internal consistency, not independent evidence.

## Parameter Batches and Release Compatibility

Use `copy(opSpec)` for independent operating-point specification objects;
plain assignment aliases a handle object. Check state paths/order across every
parameter point before differencing A matrices or matching modes.

`BatchConsistency` was added in R2025a. Feature-detect it before setting it:

```matlab
if isprop(opts, 'BatchConsistency')
    opts.BatchConsistency = 'on';
end
```

On an older release, preserve the intended state coverage and explicitly
align states; do not treat skipping the option as equivalent functionality.
For LPV work, separately verify `ssInterpolant`, offset-storage options, and
state consistency in the installed release. LPV is optional to modal tuning.

## Handback

Save A/B/C/D, domain/sample time, state paths/order, I/O and opening definitions,
operating-point evidence, parameters, options, release, and qualification result
in the existing analysis artifact. Restore temporary settings. Route the next
step through modal participation -> parameter sensitivity -> constrained
candidate -> relinearization -> bounded nonlinear verification.

No new model, broad sweep, or active-task launch is implied by this skill.

## Sources

- [Pinned upstream](https://github.com/matlab/simulink-agentic-toolkit/tree/0ed76364e5af8098c9731f317a4ee4b17d947d3d/skills-catalog/control-systems/simulink-linearize).
- [Official linearizeOptions](https://www.mathworks.com/help/slcontrol/ug/linearize.linearizeoptions.html):
  reduction, discrete-state, and R2025a batch-option boundaries, checked 2026-10-15.
