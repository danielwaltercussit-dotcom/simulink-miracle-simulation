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
- Reuse limit: do not select a tuning direction until unchanged-parameter T1
  evidence classifies the dominant band and signal owner.
- Launch lesson: a detached T1 long baseline must be treated as disk-backed
  evidence. `RUNNING` is not a failure, network/VPN switching is not normally a
  simulation control input, and S6 remains blocked until postrun plus causal
  perturbation confirms control authority.

## Reviewed Tuning Rounds

_No accepted or rejected parameter-change round has been reviewed yet._
