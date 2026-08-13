# Current Simulation Experience Contract

Use this reference for SG/DFIG replacement studies, 4-machine 2-area
oscillation studies, IEEE39 long baselines, and any derived model whose result
will be reused as modeling-library evidence.

## Contents

- Acceptance gates, device replacement, signals, and operating point.
- Oscillation/modal evidence and long-run memory safety.
- Process-product hygiene and scientific wording.
- Ambient-masked tuning and modal-identity limits.

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

ML or data-driven helpers are advisory only. They may rank hypotheses, suggest
next probes, or flag suspicious signatures, but they do not own PASS/FAIL
status. Promote a conclusion only when the deterministic gate for that layer
has on-disk evidence.

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

For IEEE39 SG-to-DFIG replacement studies, prefer an incremental replacement
ladder before treating a 5-DFIG model as the primary scientific case:

1. **1DFIG** at one carefully chosen bus: prove adapter wiring, rating/base
   conversion, energization, observability, operating point, and layout pattern.
2. **2DFIG** on an electrically meaningful pair or cluster: prove interaction,
   shared base comparison, and weak-grid / oscillation observability.
3. **5DFIG** only after the one- and two-device gates pass: use it for cluster
   behavior, boundary scans, and final multi-device conclusions.

Do not let a 5-device failure obscure which layer failed. If 5DFIG fails, route
the diagnosis back to the smallest ladder stage that can reproduce the symptom.

Replacement locations are not arbitrary. Prefer buses that satisfy the current
study objective and have usable comparison evidence:

- **single-device smoke / adapter proof**: choose the cleanest electrically
  accessible generator/bus position with simple local measurement and rating
  conversion;
- **weak-grid / oscillation source study**: choose the bus whose DFIG current,
  voltage, PLL, DC-link, and P/Q signals are observable and whose network
  position participates in the target mode;
- **cluster study**: choose adjacent or electrically coupled wind positions as
  a staged group, and keep one nearby non-participating device as a comparison
  channel when available.

Record why a bus was chosen. "Available slot" is not enough for a scientific
replacement claim.

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
- Save raw simulation outputs before any classifier or analyzer runs. A bug in
  the analyzer must be fixable offline without repeating an expensive run.
- Treat band separation and prominence as hard gates.
- Report damping as inconclusive when the estimator or peak sequence is not
  validated.
- Do not promote short cold-start ringdown to `UNSTABLE` merely because early
  peaks are non-monotonic or zeta fits near zero. If voltage remains finite and
  in band, classify the short record as inconclusive unless growth, voltage
  violation, or non-finite data proves instability.
- If a band is not observed, say "not observed in this qualified record".
  Do not infer structural or physical absence from time-domain non-observation.
- Suppress frequency-shift language when either stage lacks the band or when the
  shift is below the declared resolution.
- Require model-based modal evidence or a controlled experiment before claiming
  that topology removed a mode.

Local evidence anchors: `Claude_demo/ieee39_sg5_dfig5_skills_test/reports/
dual_track_weakgrid/dualtrack_resume_status.md`,
`Claude_demo/ieee39_sg5_dfig5_skills_test/reports/
multiscale_oscillation_evidence/reuse_inventory.md`, and
`Claude_demo/4m2a_sg_dfig_oscillation_skills_test/reports/agent_handoff/
4m2a_dfig_oscillation_status.md`.

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

## 7. Process-product hygiene

Do not treat another report, manifest, fixture, bundle, validator, or handoff
layer as the default fix for a workspace already overloaded with process
artifacts. Distill first:

- promote only durable rules into an existing skill reference;
- keep run-level reports, manifests, raw outputs, and handoff packets as
  provenance instead of copying them into skills;
- prefer editing an existing compact reference over creating a new audit file,
  taskbook, bundle, or migration wrapper;
- for cloud or new-host migration, carry portable skills, templates, bootstrap
  conventions, and distilled modeling experience, not simulation models,
  generated test artifacts, or long-run evidence directories;
- add a new validator or packaging layer only when it removes a repeated manual
  failure mode and has a named owner.

If the lesson can be expressed as one rule in an existing reference, do that
instead of creating another process artifact.

## 8. Scientific language

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

## 9. Ambient-masked tuning and modal identity

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
