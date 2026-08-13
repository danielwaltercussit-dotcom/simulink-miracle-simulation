# Closed-Loop Tuning Experience Library

Purpose: retain compact, reviewed controller-tuning lessons that can be reused
without re-reading old chats or long simulation logs.

## Entry Contract

Add an entry only after Codex reviews the disk evidence. Keep each entry under
20 lines and include:

- model/fidelity, scenario, and immutable-boundary statement;
- observed dominant band, owned signals, and root-cause classification;
- one control family changed, exact `before -> after`, and bounds;
- accepted/rejected result with machine-readable metrics;
- rollback outcome, evidence paths, and reuse limits.

Never record plant/device parameter changes as tuning experience. Never turn a
single-model direction into a universal rule. Raw logs and waveform data remain
in task report folders; this file stores only the reviewed decision.

## Current Readiness Lessons

### IEEE39 SG5/DFIG5 tuning entry

- Status: T0/T1 in progress; no accepted parameter-change round exists.
- Proven: real-model registry exposes 25 classified control-only DFIG knobs
  across W33-W37; helper-level write/rollback contract passes.
- Structural limit: W36 Qref authority at the studied high-P operating point is
  blocked by the rotor-current circle and must not be claimed as a PLL/current
  PI tuning outcome.
- Metric guard: headroom or filtered-magnitude ratios that normalize by real
  power must require finite telemetry and a strictly positive, physically owned
  base-P denominator. Near-zero, negative, missing, or wrong-owner denominator
  evidence blocks the candidate instead of driving a positive-feedback tuning
  decision.
- Evidence anchor: `build/reports/agent_handoff/dfig_voltage_control_claude_packet.md`.
- Reuse limit: do not select a tuning direction until unchanged-parameter T1
  evidence classifies the dominant band and signal owner.
- Launch lesson: a detached T1 long baseline must be treated as disk-backed
  evidence. `RUNNING` is not a failure, network/VPN switching is not normally a
  simulation control input, and S6 remains blocked until postrun plus causal
  perturbation confirms control authority.

## Reviewed Tuning Rounds

_No accepted or rejected parameter-change round has been reviewed yet._

### T1IDVDC60 / T1RD45 — causal confirmed, damping unidentifiable (2026-06-23)

Terminal: `NO_S6_DAMPING_UNIDENTIFIABLE_AT_AUTHORIZED_AMPLITUDE`
(see Claude_demo/.../reports/control/t1rd45_terminal_decision.{md,json}).

- Causal confirmation is NOT S6 authorization; do not tune until damping is
  actually identified.
- Cross-unit FRF magnitude sums (A+V+Hz+pu) are invalid for ownership ranking;
  use dimensionless within-channel metrics (peak-to-shoulder, participation,
  coherence, phase transition). Separate feedthrough channels: W36 vdc_ref
  injection makes vdc_W36 read flat ~unity (feedthrough), not a mode.
- Ambient-masked ringdown supports NEITHER low- nor stable-damping claims; when a
  line is present with no injection and the free decay does not rise above it,
  near-zero zeta is an artifact and estimator disagreement means UNRESOLVED.
- Do not repeat the same 0.01 pu class to "try again"; escalate to a Codex/user
  authority decision (reports/control/t1rd45_ambient_mask_next_authority_options.md).
- Validators for expensive Simulink bundles must parameterize runId, stop time,
  fingerprint, and coverage — never hardcode the previous run (a hardcoded
  t1idvdc60 validator falsely invalidated the valid t1rd45 bundle).

### S6 closed: 1.6333 Hz ambient line not tunable (2026-06-24)
Terminal: `S6_CLOSED_UNRESOLVED_AMBIENT_NOT_TUNABLE`
(Claude_demo/.../reports/control/t1s6_closure/s6_closure_decision.md).
- An ambient-masked persistent line does NOT authorize S6: damping unidentifiable +
  no confirmed converter-gain-tunable owner = no tuning.
- If Tier-1 rejects the leading source hypothesis (here mechanical/torsional, via
  Ksh insensitivity), CLOSE the S6 branch — do not loop back through Tier0/Tier1 or
  re-run active-ID. Reopening S6 requires ALL of: explicit source identity, a
  converter-gain-tunable owner, and a non-ambient-masked damping estimate < 0.03.
- Further physical-source identity needs a user-authorized Tier-2 source-disable
  experiment (.../t1s6_closure/tier2_source_disable_approval_packet.md), not tuning.
