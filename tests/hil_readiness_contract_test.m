function result = hil_readiness_contract_test()
%HIL_READINESS_CONTRACT_TEST Synthetic contract test for the M2 helper.
%   Exercises summarize_hil_readiness on five synthetic readiness manifests.
%   No Simulink, no model: pure metadata through the base-MATLAB helper. This
%   verifies CONTRACT CONSISTENCY only - it does not prove any model is
%   real-time deployable, and a PASS here is explicitly software-readiness.
%
%   Cases:
%     A) Complete, clean, software-only manifest -> contract PASS,
%        readiness_class software_readiness_only, handoff_ready=1,
%        real_time_deployable=0 (no hardware evidence).
%     B) Sparse manifest (missing solver/loops/codegen) -> contract MISSING,
%        blocking findings present, handoff_ready=0.
%     C) Blocking WARN (variable-step solver + latency overrun) -> contract
%        WARN, handoff_ready=0 because a BLOCKING check is not PASS.
%     D) Non-blocking WARN only (I/O placeholders, continuous-state note) ->
%        contract WARN but handoff_ready=1 (WARNs carry forward).
%     E) Same clean manifest WITH real HIL hardware evidence ->
%        readiness_class hardware_backed, real_time_deployable=1.
%
%   Artifacts written under build/reports/m2_hil_readiness/<case>/.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

checks = struct([]);
checks = iAddCheck(checks, iCaseCleanSoftware(projectRoot));
checks = iAddCheck(checks, iCaseSparseMissing(projectRoot));
checks = iAddCheck(checks, iCaseBlockingWarn(projectRoot));
checks = iAddCheck(checks, iCaseNonBlockingWarn(projectRoot));
checks = iAddCheck(checks, iCaseHardwareBacked(projectRoot));

allPass = all([checks.passed]);
fprintf('\n=== hil_readiness_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), nnz([checks.passed]), numel(checks));

result = struct('passed', allPass, 'checks', checks);
end


function m = iCleanManifest()
% A fully documented, real-time-friendly software manifest.
m = struct();
m.case_name = 'clean_software';
m.source_model_or_script = 'synthetic_vsc_rt_candidate';
m.target_platform = 'generic_rt_software_only';
m.solver_type = 'fixed_step';
m.fixed_step_s = 20e-6;          % 20 us
m.fastest_event_s = 100e-6;      % 100 us PWM event => 5x margin
m.algebraic_loops_present = false;
m.unsupported_blocks_checked = true;
m.unsupported_blocks = {};
m.continuous_states_present = false;
m.codegen_target_supported = true;
m.partitions = struct( ...
    'name', {'plant', 'control'}, ...
    'rate_s', {20e-6, 100e-6}, ...
    'compute_s', {3e-6, 2e-6});
m.io_channels = struct( ...
    'name', {'Vabc_in', 'Sw_out'}, ...
    'direction', {'in', 'out'}, ...
    'placeholder', {false, false});
m.cpu_cores = 2;
m.step_budget_s = 20e-6;
end


function c = iCaseCleanSoftware(projectRoot)
m = iCleanManifest();
outDir = fullfile(projectRoot, 'build', 'reports', 'm2_hil_readiness', 'clean_software');
s = summarize_hil_readiness(m, 'OutputDir', outDir);

okContract = strcmp(s.contract_status, 'PASS');
okClass    = strcmp(s.readiness_class, 'software_readiness_only');
okHandoff  = s.handoff_ready == true;
okNotDeploy= s.real_time_deployable == false;   % no hardware evidence
okFiles    = iArtifactsExist(outDir);

c.name = 'Case A: complete clean software manifest -> PASS, software-only';
c.passed = okContract && okClass && okHandoff && okNotDeploy && okFiles;
c.detail = sprintf(['contract=%s(PASS:%d) class=%s(sw:%d) handoff=%d(want1) ', ...
    'deployable=%d(want0) artifacts=%d'], s.contract_status, okContract, ...
    s.readiness_class, okClass, s.handoff_ready, s.real_time_deployable, okFiles);
end


function c = iCaseSparseMissing(projectRoot)
% Only a name: solver, loops, codegen, blocks all undocumented => MISSING.
m = struct('case_name', 'sparse_missing');
outDir = fullfile(projectRoot, 'build', 'reports', 'm2_hil_readiness', 'sparse_missing');
s = summarize_hil_readiness(m, 'OutputDir', outDir);

okContract = strcmp(s.contract_status, 'MISSING');
okMissing  = s.n_missing >= 3;          % fixed-step, loops, unsupported, codegen
okBlocking = ~isempty(s.blocking_findings);
okHandoff  = s.handoff_ready == false;
okClass    = strcmp(s.readiness_class, 'software_readiness_only');

c.name = 'Case B: sparse manifest -> MISSING, blocked, no handoff';
c.passed = okContract && okMissing && okBlocking && okHandoff && okClass;
c.detail = sprintf('contract=%s n_missing=%d blocking=%d handoff=%d(want0)', ...
    s.contract_status, s.n_missing, numel(s.blocking_findings), s.handoff_ready);
end


function c = iCaseBlockingWarn(projectRoot)
% Variable-step solver (blocking WARN) + compute exceeds the step budget.
m = iCleanManifest();
m.case_name = 'blocking_warn';
m.solver_type = 'variable_step';        % blocking: RT needs fixed step
m.partitions = struct( ...
    'name', {'plant', 'control'}, ...
    'rate_s', {20e-6, 20e-6}, ...
    'compute_s', {30e-6, 25e-6});       % 55us total >> 20us budget => overrun
m.cpu_cores = 1;
outDir = fullfile(projectRoot, 'build', 'reports', 'm2_hil_readiness', 'blocking_warn');
s = summarize_hil_readiness(m, 'OutputDir', outDir);

okContract = strcmp(s.contract_status, 'WARN');
okHandoff  = s.handoff_ready == false;       % blocking check not PASS
okStepWarn = iCheckStatus(s, 'fixed_step_feasibility', 'WARN');
okLatWarn  = iCheckStatus(s, 'latency_budget', 'WARN');
okBlocking = any(contains(s.blocking_findings, 'fixed_step_feasibility')) && ...
             any(contains(s.blocking_findings, 'latency_budget'));

c.name = 'Case C: blocking WARN (var-step + overrun) -> no handoff';
c.passed = okContract && okHandoff && okStepWarn && okLatWarn && okBlocking;
c.detail = sprintf('contract=%s handoff=%d(want0) stepWARN=%d latWARN=%d blocking={%s}', ...
    s.contract_status, s.handoff_ready, okStepWarn, okLatWarn, strjoin(s.blocking_findings, ','));
end


function c = iCaseNonBlockingWarn(projectRoot)
% Only non-blocking WARNs: I/O placeholders + continuous-state note. Everything
% blocking still PASSes, so handoff is allowed to carry forward.
m = iCleanManifest();
m.case_name = 'nonblocking_warn';
m.continuous_states_present = true;     % non-blocking codegen WARN (discretize note)
m.io_channels = struct( ...
    'name', {'Vabc_in', 'Sw_out'}, ...
    'direction', {'in', 'out'}, ...
    'placeholder', {true, true});       % non-blocking io WARN
outDir = fullfile(projectRoot, 'build', 'reports', 'm2_hil_readiness', 'nonblocking_warn');
s = summarize_hil_readiness(m, 'OutputDir', outDir);

okContract = strcmp(s.contract_status, 'WARN');
okHandoff  = s.handoff_ready == true;        % WARNs are non-blocking
okIoWarn   = iCheckStatus(s, 'io_mapping', 'WARN');
okNoBlock  = isempty(s.blocking_findings);

c.name = 'Case D: non-blocking WARN only -> handoff still allowed';
c.passed = okContract && okHandoff && okIoWarn && okNoBlock;
c.detail = sprintf('contract=%s handoff=%d(want1) ioWARN=%d blocking_empty=%d', ...
    s.contract_status, s.handoff_ready, okIoWarn, okNoBlock);
end


function c = iCaseHardwareBacked(projectRoot)
% Clean manifest plus real HIL evidence => hardware_backed + deployable.
m = iCleanManifest();
m.case_name = 'hardware_backed';
m.hardware_evidence = struct('supplied', true, ...
    'artifact_path', 'build/reports/m2_hil_readiness/hw/opalrt_run_log.csv', ...
    'overruns', false, 'note', 'synthetic HIL evidence stub for contract test');
outDir = fullfile(projectRoot, 'build', 'reports', 'm2_hil_readiness', 'hardware_backed');
s = summarize_hil_readiness(m, 'OutputDir', outDir);

okClass    = strcmp(s.readiness_class, 'hardware_backed');
okDeploy   = s.real_time_deployable == true;
okHandoff  = s.handoff_ready == true;

c.name = 'Case E: clean + HIL evidence -> hardware_backed, deployable';
c.passed = okClass && okDeploy && okHandoff;
c.detail = sprintf('class=%s(hw:%d) deployable=%d(want1) handoff=%d', ...
    s.readiness_class, okClass, s.real_time_deployable, s.handoff_ready);
end


function tf = iCheckStatus(summary, checkName, wantStatus)
tf = false;
for k = 1:numel(summary.checks)
    if strcmp(summary.checks(k).name, checkName)
        tf = strcmp(summary.checks(k).status, wantStatus);
        return
    end
end
end


function tf = iArtifactsExist(outDir)
tf = isfile(fullfile(outDir, 'hil_readiness_summary.md')) && ...
     isfile(fullfile(outDir, 'hil_readiness_summary.json'));
end


function checks = iAddCheck(checks, c)
if isempty(checks)
    checks = c;
else
    checks(end+1) = c;
end
end


function t = iTag(passed)
if passed; t = 'PASS'; else; t = 'FAIL'; end
end
