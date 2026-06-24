# Current Simulation Experience Contract

Use this reference for SG/DFIG replacement studies, 4-machine 2-area
oscillation studies, IEEE39 long baselines, and any derived model whose result
will be reused as modeling-library evidence.

## 1. Separate the acceptance gates

Never collapse these into one PASS:

1. **Structural**: topology, ports, physical wiring, InitFcn, masks, and compile.
2. **Runtime**: simulation completed, lifecycle is consistent, outputs are finite.
3. **Physical energization**: device injects plausible P/Q and bus voltage/current
   evidence is alive.
4. **Observability**: required channels have valid samples, units, signs, bases,
   and their own time vectors.
5. **Operating point**: pre-event dispatch and voltage are within declared
   tolerance of the audited target.
6. **Scientific evidence**: record length, frequency resolution, prominence,
   damping, and comparison gates support the claimed conclusion.

A later gate may fail while all earlier gates pass. Report that exact boundary.

## 2. Device replacement contract

For SG-to-DFIG or other source replacement:

- copy a validated donor subsystem instead of rebuilding its internals;
- preserve donor controller and per-unit design unless the study authorizes a
  parameter change;
- scale capacity through aggregation or parallel instances;
- use an explicit transformer/collector interface for terminal-voltage and
  rating conversion;
- remove or repoint stale SG-only measurement chains;
- define common comparison channels that survive replacement, normally physical
  active-power channels on one declared system base;
- keep physical injection evidence separate from internal DFIG signals such as
  rotor speed, DC-link voltage, or donor m-bus telemetry.

Compile success does not prove capacity compatibility, energization, or usable
observability.

## 3. Signal and time-base contract

Every analysis input must record:

- signal name and physical owner;
- units, sign convention, and per-unit base;
- native time vector and sample count;
- pre-event, event, and post-event windows;
- whether interpolation or alignment was applied.

Do not use a one-sample or degenerate channel as the global time axis. Align
signals explicitly only after validating each native time vector. A constant or
single-sample internal DFIG signal does not prove the electrical device is dead
when independent physical P/Q or PMU evidence is alive.

## 4. Operating-point qualification

Before modal, damping, or cross-stage comparison, compare the measured
pre-event operating point with the audited target:

- P/Q dispatch per retained or replaced device;
- bus voltage and frequency when logged;
- device enable/ramp state;
- transformer and collector loading.

If the operating point is outside tolerance, classify the run as
`RUNTIME_VALID_OPERATING_POINT_UNQUALIFIED`. It may support debugging and
logging conclusions, but it cannot support replacement-stage modal comparison
or physical-absence claims.

## 5. Oscillation and modal evidence

- Derive Rayleigh resolution from the selected observation duration.
- Decimate or resample only after anti-aliasing and only to improve useful
  low-frequency resolution; do not analyze an arbitrary short raw prefix.
- Treat band separation and prominence as hard gates.
- Report damping as inconclusive when the estimator or peak sequence is not
  validated.
- If a band is not observed, say "not observed in this qualified record".
  Do not infer structural or physical absence from time-domain non-observation.
- Suppress frequency-shift language when either stage lacks the band or when the
  shift is below the declared resolution.
- Require model-based modal evidence or a controlled experiment before claiming
  that topology removed a mode.

## 6. Long-run memory safety

Final MAT or bundle size is not a memory-safety metric. Gate long runs with:

- the real `MATLAB.exe` compute child PID, resolved from the launcher/stub PID;
- private-byte slope after compile/warm-up;
- peak private bytes and minimum free commit;
- projected memory at the requested StopTime;
- required-signal retention.

Measured IEEE39 T1 experience:

- `LogDecimation=16` reduced consumed signal volume but did not bound process
  memory;
- disabling Scope `DataLogging` alone did not remove growth because Scope blocks
  still executed;
- commenting out all executing Scope sinks reduced growth from about 3.76 GB/h
  to about 0.24 GB/h while retaining 35/35 required `logsout` signals;
- disabling SDI recording also removed required `logsout` capture and is not an
  acceptable memory fix;
- detached 24 s and 60 s validation survived only when launched as an OS-level
  process, not as a session-owned background shell task.

Use fresh run ids, immutable evidence bundles, a read-only resource guard, and
staged 3 s -> 24 s -> 60 s validation before authorizing longer horizons.

## 7. Scientific language

Use:

- `observed`, `not observed`, `qualified`, `unqualified`, `inconclusive`;
- `structural PASS`, `runtime PASS`, `energization PASS`, `observability FAIL`;
- `unresolved below frequency resolution`.

Avoid:

- treating compile/smoke PASS as model validity;
- treating a zero internal signal as electrical disconnection without physical
  evidence;
- treating an unqualified operating point as a replacement-stage result;
- treating non-observation as proof of physical absence;
- treating a sudden memory drop as optimization before checking process exit and
  Windows crash evidence.

## 8. Ambient-masked tuning and modal identity

For S6/tuning decisions, causal confirmation alone is not enough. A confirmed
FRF resonance remains non-tunable when damping is ambient-masked or the owner is
not proven converter-gain-tunable.

Use the following gates:

- If the target spectral line is already strong in a no-injection/null window,
  classify it as ambient until a controlled record rises above that floor.
- Do not fit damping to a flat envelope at the ambient floor. Near-zero zeta
  from Prony/Hilbert disagreement or a non-decaying envelope is unidentifiable,
  not proof of low damping.
- Do not repeat the same authorized-amplitude ringdown or broadband class when
  it cannot separate the line from ambient content. Escalate to an explicit
  authority decision or close the branch.
- A persistent ambient line does not authorize S6. To reopen tuning require all
  of: explicit physical source identity, a converter-gain-tunable owner, and a
  non-ambient-masked damping estimate below threshold.
- Do not claim modal identity from near-frequency coincidence. Require parameter
  sensitivity, named-state participation, or another physical identity bridge.
  For shaft/torsional claims, frequency should respond to shaft stiffness with
  the expected trend; a Ksh-insensitive mode is not a shaft mode.
