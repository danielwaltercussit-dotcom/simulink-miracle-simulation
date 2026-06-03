function [sig, fix] = ai_in_loop_diagnose(ME)
%AI_IN_LOOP_DIAGNOSE  Map an MException to a failure signature + proposed fix.
%   Signatures match references/failure-signatures.md in the ai-in-loop skill.
msg = lower(ME.message);
id  = char(ME.identifier);
sig = 'UNKNOWN';
fix = 'No automated fix. Capture log and ask user.';

if contains(msg, 'unrecognized function') || contains(msg, 'undefined function or variable')
    sig = 'FS-001';
    fix = 'Ensure InitFcn runs NE39bus_dataV2 and PSS aliases are injected.';
elseif strcmp(id,'AIInLoop:SpecValidationFail')
    sig = 'FS-019';
    fix = 'Fix the spec contract: required system fields, convergence_targets, topology/replacement intent, timing, and fault window before rebuilding.';
elseif strcmp(id,'AIInLoop:AdapterContractFail')
    sig = 'FS-020';
    fix = 'Fix the device adapter contract in S2: self-contained InitFcn, adapter-facing ports, unique device names, and trace metadata before compile/sim.';
elseif strcmp(id,'AIInLoop:ModelQualityLayoutFail')
    sig = 'FS-021';
    fix = 'Fix the S3 model quality/layout contract: root overlap, signal-only Goto/From tags, measurement logging surface, and oracle/reference hygiene.';
elseif strcmp(id,'AIInLoop:StageFailed')
    sig = 'FS-015';
    fix = 'A stage returned FAIL or a blocking SKIPPED status. Inspect the stage note in iter status.json and fix that stage before declaring PASS.';
elseif strcmp(id,'AIInLoop:ReportArtifactMissing') || strcmp(id,'AIInLoop:ReportArtifactEmpty') || strcmp(id,'AIInLoop:ReportStatusMismatch') || strcmp(id,'AIInLoop:TopPngExportFailed')
    sig = 'FS-015';
    fix = 'S9 verification failed. Regenerate the missing report artifact or fix status.json booleans before declaring PASS.';
elseif strcmp(id,'AIInLoop:FunctionalTestFail')
    sig = 'FS-006';
    fix = 'Functional S7 test failed. Inspect sltest_summary.md, then fix update/smoke/output finite-value failures before retrying.';
elseif strcmp(id,'Simulink:Commands:ParamUnknown') || (contains(msg,'没有名为') && contains(msg,'的参数'))
    sig = 'FS-017';
    fix = 'In the build script, before set_param on this block run get_param(blk,''MaskNames'') and pick the real name. Common: Programmable Voltage Source uses PositiveSequence / VariationEntity / VariationStep / VariationTiming; Transformer uses Winding1Connection / Winding2Connection / Rm / Lm.';
elseif strcmp(id,'Simulink:Parameters:BlkParamUndefined') || (contains(msg,'blkparamundefined')) || (contains(msg,'参数') && (contains(msg,'ts') || contains(msg,' ts ')))
    sig = 'FS-018';
    fix = 'Donor subsystem expects workspace vars (Ts, Tsample, ...). In the build script add set_param(model,''InitFcn'',''Ts=5e-5; Tsample=Ts;''). Then the .slx is self-contained and runnable outside the project. Re-build, isolation-test with restoredefaultpath.';
elseif contains(msg, 'algebraic loop')
    sig = 'FS-002';
    fix = 'Insert Memory at solver-suggested loop break; revert last layout move.';
elseif contains(msg, 'nan') && contains(msg, 'state')
    sig = 'FS-003';
    fix = 'Re-apply DFIG mask defaults (WindSpeed, Vdc0); verify UserData benchmark_machine_id.';
elseif contains(msg, 'loss of synchronism') || contains(msg, 'synchronism')
    sig = 'FS-004';
    fix = 'Zero out governor refs for replaced rows; recompute Pref from spec.';
elseif strcmp(id,'AIInLoop:LayoutOverlap')
    sig = 'FS-005';
    fix = 'Two or more root blocks overlap. Run scan_block_overlap(model) to list pairs. Shift Constant/source signal blocks to the empty gap between physical chain blocks (see references/layout-cookbook.md "Hard rule: zero overlap").';
elseif contains(msg, 'voltage') && contains(msg, 'range')
    sig = 'FS-006';
    fix = 'Switch DFIG q_control to voltage mode at the offending bus.';
elseif strcmp(id,'AIInLoop:MissingOracle')
    sig = 'FS-008';
    fix = 'Stop loop. Restore the missing oracle file from project history.';
elseif contains(msg, 'wpll') || (contains(msg, 'pll') && contains(msg, 'frequency'))
    sig = 'FS-009';
    fix = 'Verify dq rotation uses theta_pll - theta_s; scale PLL kp by sqrt(2) (M01).';
elseif contains(msg, 'vtmag') || (contains(msg, 'terminal') && contains(msg, 'voltage'))
    sig = 'FS-010';
    fix = 'Initialise x_ut1 = 0.53, x_ut2 = 0.79 (per M01 Initial_data file).';
elseif contains(msg, 'alpha_inv') || (contains(msg, 'lcc') && contains(msg, 'lock'))
    sig = 'FS-011';
    fix = 'Set T_filt_V = 0.02, Vdc_inv_filt(1) = 1.0 pu (per M06).';
elseif contains(msg, 'arm') && contains(msg, 'current')
    sig = 'FS-012';
    fix = 'Carm = 6.17e-5 SI, Lm_pu = 0.05/Lbase against MMC-side base (M05).';
elseif contains(msg, '50 hz') || contains(msg, '50hz')
    sig = 'FS-013';
    fix = 'Reset Co_Rrs / Co_Lm / Co_Lls / Co_Lrs / Ls2 multipliers to 1.0.';
elseif contains(msg, '2 hz') || contains(msg, 'low freq')
    sig = 'FS-014';
    fix = 'Drop Covol to 0.6-0.8; if PLL kp was scaled by sqrt(2), halve it.';
elseif strcmp(id,'AIInLoop:ModelAdvisorFail')
    sig = 'FS-016';
    fix = 'Inspect model_advisor_summary.md; fix sample-time / data-type roots in S2; do not bypass checks.';
end
end
