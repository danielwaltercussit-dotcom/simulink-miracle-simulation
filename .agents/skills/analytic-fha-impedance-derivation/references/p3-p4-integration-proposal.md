# F1 -> P3 / P4 Integration Proposal (for Codex review)

Status: PROPOSAL ONLY. This branch (`codex/f1-analytic-fha-impedance`) does NOT
edit any P3/P4 shared file. F1 reuses the P3 canonical band labels and the
`real(Z)<0` passivity screen by copy so the curves are comparable, but it writes
no P3/P4 code. The changes below are for Codex to schedule on the integration
branch, not for F1 to make.

## Why integrate

F1 closes the analytic side of the impedance loop: it DERIVES `Z(jw)` from a
stated topology and grades that model against supplied data
(`compare_fha_measured_impedance`). P3 SUMMARIZES a supplied curve; P4
(`ibr-model-validation-evidence`) assembles same-iteration evidence. Today an
analytic model and a P3 sweep can disagree silently, and P4 cannot cite an
analytic/comparison artifact.

## Proposal A — P3 cross-check (low risk, no P3 code change required)

P3 and F1 already share band labels + passivity screen. A user can today:

1. derive with `summarize_fha_impedance_response` (F1),
2. feed the same grid+curve to `summarize_impedance_frequency_response` (P3),
3. compare dominant resonance frequencies by hand.

Optional convenience (Codex decision): a thin wrapper under P3 that accepts an
F1 `derived` struct and runs the P3 summary, reporting frequency agreement. This
is additive; it must not change P3's existing signature or contract.

## Proposal B — P4 frequency-domain intake of the comparison artifact

P4's S10C already downgrades a provisional P3 impedance summary to WARN. Mirror
that for the F1 comparison artifact:

- New optional input to `write_ibr_validation_evidence_plan.m`:
  `FhaComparisonPath` (+ `FhaComparisonCurrentIterationDir`), exactly parallel
  to the existing `ImpedanceEvidencePath` plumbing.
- Status mapping (reuse the existing PASS/WARN/MISSING/N-A machine):
  - `evidence_grade=data_backed` AND same-iteration            -> PASS
  - `data_backed_mismatch`                                     -> WARN
    (model contradicts data; surface, do not hide)
  - `contract_only` / `provisional` / stale / unparseable JSON -> WARN
  - path supplied but file absent                              -> MISSING
  - not requested                                              -> N/A
- Same-iteration defense: reuse the canonicalized-prefix match P4 already uses
  for impedance evidence; a prior-iteration comparison must not PASS.
- Hard rule for P4: never let an F1 artifact reach a hardware-backed claim. The
  F1 grade caps at `data_backed`; P4 must treat that as model-backed evidence,
  not hardware validation.

## Files Codex would touch (NOT touched in this branch)

- `scripts/verification/write_ibr_validation_evidence_plan.m` (P4)
- `scripts/loop/ai_in_loop_stage_ibr_validation_evidence.m` (P4 S10C wiring)
- optionally a new thin P3-side wrapper (Proposal A)

## Validation Codex should require before merging the integration

- A P4 contract test case per status row (PASS/WARN/MISSING/N-A), including a
  `data_backed_mismatch -> WARN` case and a stale-artifact -> WARN case.
- Re-read the rendered P4 evidence section from disk; confirm the F1 artifact is
  cited and that a provisional/mismatch comparison cannot read as PASS.
- Confirm no F1 file is required to change for the intake (F1 stays read-only to
  P4; only P4 grows the optional input).
