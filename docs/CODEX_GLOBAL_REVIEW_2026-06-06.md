# Codex Global Review - 2026-06-06

Scope: E/F/M/D parallel task packages created from commit `8e7a799`.

Review method:

- inspected branch/worktree state and branch-specific Claude packets;
- ran MATLAB R2024b `checkcode` on new analysis helpers;
- ran the package contract tests from disk;
- re-read generated artifacts where tests produced them;
- checked whether package work was actually attached to its assigned branch.

## Findings

### P0 - Parallel branch isolation failed

Except for E2, package deliverables were left untracked in the primary working
directory while all assigned branch pointers remained at `8e7a799`. Multiple
Claude conversations switched the same working directory, so the files are not
reliably attributable to their named branches and cannot be merged safely.

Required correction: recover each package into a dedicated worktree, stage only
its explicit write scope, rerun validation, and commit it on its assigned
branch. Do not delete the shared untracked staging files until every package is
committed and reviewed.

### P0 - D3 storage/BMS helper crashes

`scripts/analysis/summarize_storage_bms_support.m` fails in
`iExcludedClaims` because multi-line character vectors of different lengths are
vertically concatenated inside a cell literal. The first contract-test case
never completes.

Observed command result:

- `storage_bms_support_contract_test` -> FAIL at
  `summarize_storage_bms_support>iExcludedClaims`.
- `checkcode` -> two stale `MSNU` suppressions at lines 493 and 503.

Required correction: fix the cell construction, remove stale suppressions, run
`checkcode`, rerun all D3 contract cases, and read back artifacts.

### P1 - M2 HIL readiness package is missing

No M2 skill, helper, test, handoff packet, or package artifact exists. M2 must
remain `MISSING`, not `DONE`.

### P1 - D2 can mark warning-bearing evidence handoff-ready

`summarize_mmc_hvdc_support.m` sets `handoff_ready` whenever there is no
`MISSING` section. A half-bridge station that incorrectly claims converter
blocking receives `dc_fault=WARN` but can still be handoff-ready. The Case B
test verifies the warning but does not assert that handoff readiness is false.

Required correction: define which WARN states block handoff, implement the
policy, and add negative readiness assertions.

### P1 - M1 returns `pass` without model-backed verification

`summarize_multirate_solver_plan.m` returns `pass` for a documented plan even
when `verified_against_model=false`; it also returns `pass` with warnings for an
under-sampled slow mode. This is acceptable only as a contract-consistency
result, but the current headline status can be mistaken for solver validation.

Required correction: separate `contract_status` from
`model_validation_status`/`handoff_ready`, and require an actual model-backed
probe before the package can claim solver readiness.

### P2 - F3 skill package is structurally incomplete

`.agents/skills/perturbation-stability-boundary-scan/` lacks
`agents/openai.yaml`, unlike the established project-local skill structure.

### P2 - Handoff packets exceeded the compact protocol

`latest_claude_packet.md` grew to 411 lines, while F1, F3, and M1 branch packets
also exceeded the 120-line limit. The packets contain useful evidence, but the
global index is no longer token-efficient.

## Reproduced Validation

PASS:

- E1 `emt_switching_evidence_contract_test` -> 5/5
- E2 `fidelity_switching_contract_test` -> 5/5
- F1 `fha_impedance_derivation_contract_test` -> 5/5
- F2 `cross_regulation_tuning_contract_test` -> 5/5
- F3 `stability_boundary_scan_contract_test` -> 4/4
- M1 `multirate_solver_contract_test` -> 6/6
- D1 `vsc_gfl_gfm_support_contract_test` -> 6/6
- D2 `mmc_hvdc_support_contract_test` -> 5/5

FAIL:

- D3 `storage_bms_support_contract_test` -> runtime error before Case A

MISSING:

- M2 implementation and validation

## Global Assessment

The round successfully created useful contract-first scaffolding, but it did
not yet establish model-backed capability. No E/F/M/D package ran a real
Simulink/Simscape model. The next round should first repair branch ownership and
blocking defects, then move selected packages from metadata contracts toward
actual evidence ingestion or small non-private runnable model probes.

## Draft Next-Round Order

Plan approval: `approved_by_user` on 2026-06-06.

1. Recover every package into a dedicated worktree and commit package-local
   files on the assigned branch.
2. Repair D3, implement missing M2, harden D2 readiness, and separate M1
   contract/model statuses.
3. Add model-backed evidence adapters for E1/E2/M1 and same-iteration evidence
   composition for D1.
4. Extend F1/F2/F3 from summary-only helpers toward measured comparison,
   coupled-control evidence, and executable/refined scans.
5. Keep D2 and D3 device expansions behind their repaired validation gates.
6. Do not merge any branch until Codex reruns branch-local validation.
