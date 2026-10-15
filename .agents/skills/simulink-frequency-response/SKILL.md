---
name: simulink-frequency-response
description: Estimate Simulink frequency responses with bounded frestimate experiments, qualified operating points, explicit frequency units, and amplitude/rate checks for VSC, DFIG, synchronous-machine, and coupled-control analysis.
license: https://www.mathworks.com/content/dam/mathworks/license/pmrl/license.md
metadata:
  author: MathWorks
  upstream: matlab/simulink-agentic-toolkit
  upstream_commit: 0ed76364e5af8098c9731f317a4ee4b17d947d3d
  adaptation_date: "2026-10-15"
---

# Simulink Frequency Response Estimation

Project adaptation of the MathWorks skill. Copyright 2026 The MathWorks, Inc.
Retain LICENSE.md. Use with MathWorks products and service offerings.

Use simulation-based `frestimate` for local I/O response, to validate an
analytical linearization or when its derivative is unsuitable. It complements
[simulink-linearize](../simulink-linearize/SKILL.md); clean linearization does
not eliminate the need for independent injection validation.

## Start From the Existing Contract

Read [impedance-frequency-analysis](../impedance-frequency-analysis/SKILL.md)
and its [contract](../impedance-frequency-analysis/references/impedance-contract.md).
They own source/operating-point metadata, scalar versus MIMO limits, and
stability wording. Use the existing base-MATLAB injection helper if Simulink
Control Design is unavailable; do not install products or modify MCP here.

1. Identify the authorized model, stationary operating point, I/O boundaries,
   controller/limiter state, frequency band, and runtime budget.
2. Trace output measurements upstream to valid `linio` output ports. Record
   openings and injection/current-direction conventions. A command-to-output
   FRF is not an impedance unless the measured voltage/current ratio defines it.
3. Check rates against the selected excitation and installed API. Use
   rate-compatible points and explicit conversion when justified.
4. Inspect time-varying sources with `frest.findSources` when applicable.
   Hold only explicitly selected exogenous sources at recorded values using
   `frestimateOptions.BlocksToHoldConstant`. Retain control/plant states and
   protection, and preserve the intended physical experiment.
5. Choose the excitation from the question. PRBS is a broadband option;
   sinestream resolves selected resonances. Neither makes a nonlinear,
   limiting, drifting, or periodic response automatically LTI.

## Frequency Units and Discrete Compatibility

The local impedance pipeline uses Hz. The fixed-Ts constructor below takes
rad/s: convert exactly once. A supported explicit vector is allowed only when
every frequency has an integer number of samples per period:

```matlab
% Illustrative setup only: replace with the authorized band and signal rate.
Ts = 1e-4;
bandHz = [1, 100];
```

For actual construction, use the range-cell form:

```matlab
in = frest.createFixedTsSinestream(Ts, {2*pi*bandHz(1), 2*pi*bandHz(2)});
in.Amplitude = 1e-3; % illustrative in injected-signal units; qualify locally
in.NumPeriods = 8;
in.SettlingPeriods = 3;
tFinal = getSimulationTime(in);
```

For an explicit vector `w`, verify `2*pi./(w*Ts)` is integer within numerical
tolerance and that the selected band meets the sampling/aliasing requirements.
Do not pass an arbitrary log grid and assume that it is valid. Continuous
sinestream can instead declare `FreqUnits='Hz'` explicitly.

When sinestream filtering is enabled, satisfy the documented measurement-period
constraint (at least three periods after settling). Check actual returned
frequencies; the constructor can select a different grid from the requested range.

## Bounded Estimation

After qualifying the duration, amplitude, `op`, `io`, and `opts`:

```matlab
sysest = frestimate(mdl, op, io, in, opts);
```

- Judge both simulated duration and expected wall time before launching.
  If the required low-frequency cycles exceed the task budget, report that
  band as untested or schedule an authorized bounded run. Raising the lower
  frequency merely to finish faster can exclude the decisive mode.
- Compare at least two suitable perturbation amplitudes when local linearity
  is uncertain; inspect drift, saturation, fit quality, and repeatability.
- For coupled dq/sequence studies, use independent excitations and record every
  cross-channel response, reference angle, and frequency shift. A scalar sweep
  cannot prove the coupled interface stable.
- Preserve the FRD result and returned frequency units. `tfest`/`ssest` fitting
  is optional and requires System Identification Toolbox; fit quality does not
  prove physical states, participation, or internal stability.
- Restore temporary changes and save raw input/output evidence before analysis.

## Sources and Adaptation

- [Pinned upstream](https://github.com/matlab/simulink-agentic-toolkit/tree/0ed76364e5af8098c9731f317a4ee4b17d947d3d/skills-catalog/control-systems/simulink-frequency-response).
- [Fixed-Ts constructor](https://www.mathworks.com/help/slcontrol/ug/frest.createfixedtssinestream.html):
  radians/second, range-cell and compatible vector forms.
- [Sinestream](https://www.mathworks.com/help/slcontrol/ug/frest.sinestream.html):
  explicit Hz option and measurement settings.

Reviewed 2026-10-15. The adaptation removes universal PRBS claims and blanket
bans on explicit frequency vectors, retains independent validation, and
preserves low-frequency coverage and project operating-point gates.
