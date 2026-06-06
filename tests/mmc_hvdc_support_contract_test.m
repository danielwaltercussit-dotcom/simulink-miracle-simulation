function result = mmc_hvdc_support_contract_test()
%MMC_HVDC_SUPPORT_CONTRACT_TEST Synthetic contract test for the D2 helper.
%   Exercises summarize_mmc_hvdc_support, asserting the three evidence tiers
%   (contract / model_validation / hardware) and the readiness policy:
%   handoff_ready requires contract_status==PASS AND model_validation==PASS.
%
%     A) consistent contract, NO model probe -> contract PASS, model MISSING,
%        NOT handoff-ready (metadata alone is never enough);
%     B) consistent contract + passing model probe -> handoff-ready;
%     C) half-bridge claiming converter_blocking, WITH a passing probe ->
%        dc_fault blocking WARN, contract BLOCKED, NOT handoff-ready
%        (a correctness defect overrides a good model probe);
%     D) arm-averaged model carrying switching metadata, WITH passing probe ->
%        modulation_balancing blocking WARN, contract BLOCKED, NOT ready;
%     E) advisory WARN only (energy out of band) + passing probe -> contract
%        WARN (advisory), STILL handoff-ready (advisory never blocks);
%     F) clean contract + a model probe that RAN BUT FAILED -> model WARN,
%        NOT handoff-ready (model tier is required, not optional);
%     G) missing required fields -> contract MISSING, NOT handoff-ready;
%     H) full-bridge claiming converter_blocking -> dc_fault PASS.
%
%   No Simulink, no toolbox dependency: pure synthetic metadata + synthetic
%   model-probe structs through the base-MATLAB helper. The real model-backed
%   probe lives in the skill assets/ and is exercised separately.
%
%   Artifacts written under build/reports/d2_mmc_hvdc/<case>/.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

checks = struct([]);
checks = iAddCheck(checks, iCaseConsistentNoProbe(projectRoot));
checks = iAddCheck(checks, iCaseConsistentWithProbe(projectRoot));
checks = iAddCheck(checks, iCaseHalfBridgeDcBlockBlocks(projectRoot));
checks = iAddCheck(checks, iCaseAveragedSwitchingBlocks(projectRoot));
checks = iAddCheck(checks, iCaseAdvisoryDoesNotBlock(projectRoot));
checks = iAddCheck(checks, iCaseModelProbeFailed(projectRoot));
checks = iAddCheck(checks, iCaseMissingRequired(projectRoot));
checks = iAddCheck(checks, iCaseFullBridgeDcBlockPass(projectRoot));

allPass = all([checks.passed]);
fprintf('\n=== mmc_hvdc_support_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), nnz([checks.passed]), numel(checks));

result = struct('passed', allPass, 'checks', checks);
end


function ev = iBaseEvidence()
% A complete, internally consistent switching-level half-bridge VSC-HVDC station.
ev = struct( ...
    'case_name', 'd2_base', ...
    'source_model_or_script', 'models/mmc_station.slx', ...
    'station_topology', 'symmetric_monopole', ...
    'submodule_type', 'half_bridge', ...
    'n_submodules_per_arm', 200, ...
    'submodule_capacitance_F', 10e-3, ...
    'arm_inductance_H', 50e-3, ...
    'rated_power_MW', 1000, ...
    'dc_voltage_kV', 640, ...
    'ac_voltage_kV', 333, ...
    'model_fidelity', 'switching', ...
    'control_mode', 'vdc_q', ...
    'modulation', 'nlc', ...
    'capacitor_voltage_balancing', 'sorting', ...
    'circulating_current_control', 'ccsc', ...
    'dc_link_dynamics', 'dc_voltage_control_with_cable', ...
    'ac_fault_handling', 'current_limit_ride_through', ...
    'dc_fault_handling', 'ac_breaker_clearing', ...
    'related_time_domain_run', 'build/reports/d2_mmc_hvdc/_runs/emt_run.json');
end


function p = iPassingProbe()
p = struct('ran', true, 'stage', 'simulate', 'model', 'mmc_dc_link_fixture', ...
    'passed', true, 'note', 'synthetic passing probe');
end


function p = iFailingProbe()
p = struct('ran', true, 'stage', 'update', 'model', 'mmc_dc_link_fixture', ...
    'passed', false, 'note', 'synthetic probe ran but acceptance check failed');
end


function st = iStatusOf(summary, name)
st = '';
for k = 1:numel(summary.sections)
    if strcmp(summary.sections(k).name, name)
        st = summary.sections(k).status;
        return
    end
end
end


function sv = iSeverityOf(summary, name)
sv = '';
for k = 1:numel(summary.sections)
    if strcmp(summary.sections(k).name, name)
        sv = summary.sections(k).severity;
        return
    end
end
end


function c = iCaseConsistentNoProbe(projectRoot)
% Clean contract, NO model probe: contract PASS but model tier MISSING, so the
% package must NOT be handoff-ready. Metadata consistency alone is insufficient.
ev = iBaseEvidence();
ev.case_name = 'd2_consistent_no_probe';
outDir = fullfile(projectRoot, 'build', 'reports', 'd2_mmc_hvdc', ev.case_name);
s = summarize_mmc_hvdc_support(ev, 'OutputDir', outDir);

okContract = strcmp(s.contract_status, 'PASS');
okModel    = strcmp(s.model_validation_status, 'MISSING');
okHw       = strcmp(s.hardware_validation_status, 'N/A');
okNotReady = ~s.handoff_ready && s.provisional;
okFiles    = iArtifactsExist(outDir);

c.name = 'Case A: clean contract, no probe -> NOT handoff-ready';
c.passed = okContract && okModel && okHw && okNotReady && okFiles;
c.detail = sprintf('contract=%s model=%s hw=%s ready=%d (want 0) artifacts=%d', ...
    s.contract_status, s.model_validation_status, s.hardware_validation_status, ...
    s.handoff_ready, okFiles);
end


function c = iCaseConsistentWithProbe(projectRoot)
% Clean contract + passing model probe: the only handoff-ready path.
ev = iBaseEvidence();
ev.case_name = 'd2_consistent_with_probe';
outDir = fullfile(projectRoot, 'build', 'reports', 'd2_mmc_hvdc', ev.case_name);
s = summarize_mmc_hvdc_support(ev, 'ModelProbe', iPassingProbe(), 'OutputDir', outDir);

okContract = strcmp(s.contract_status, 'PASS');
okModel    = strcmp(s.model_validation_status, 'PASS');
okReady    = s.handoff_ready && ~s.provisional;
okEnergy   = s.energy_per_mva_kJ >= 10 && s.energy_per_mva_kJ <= 80;
okFiles    = iArtifactsExist(outDir);

c.name = 'Case B: clean contract + passing probe -> handoff-ready';
c.passed = okContract && okModel && okReady && okEnergy && okFiles;
c.detail = sprintf('contract=%s model=%s ready=%d energy=%.1f kJ/MVA artifacts=%d', ...
    s.contract_status, s.model_validation_status, s.handoff_ready, ...
    s.energy_per_mva_kJ, okFiles);
end


function c = iCaseHalfBridgeDcBlockBlocks(projectRoot)
% Negative readiness: half-bridge converter_blocking is a blocking WARN. Even
% WITH a passing model probe, the correctness defect keeps it out of handoff.
ev = iBaseEvidence();
ev.case_name = 'd2_halfbridge_dcblock';
ev.dc_fault_handling = 'converter_blocking';   % impossible for half-bridge
outDir = fullfile(projectRoot, 'build', 'reports', 'd2_mmc_hvdc', ev.case_name);
s = summarize_mmc_hvdc_support(ev, 'ModelProbe', iPassingProbe(), 'OutputDir', outDir);

okWarn      = strcmp(iStatusOf(s, 'dc_fault'), 'WARN');
okBlocking  = strcmp(iSeverityOf(s, 'dc_fault'), 'blocking');
okContract  = strcmp(s.contract_status, 'BLOCKED');
okModel     = strcmp(s.model_validation_status, 'PASS');   % probe was fine...
okNotReady  = ~s.handoff_ready;                            % ...but defect blocks
okOther     = strcmp(iStatusOf(s, 'topology'), 'PASS');    % only dc_fault flips
okFiles     = iArtifactsExist(outDir);

c.name = 'Case C: half-bridge converter_blocking -> BLOCKED, NOT ready';
c.passed = okWarn && okBlocking && okContract && okModel && okNotReady && okOther && okFiles;
c.detail = sprintf(['dc_fault=%s/%s contract=%s model=%s ready=%d (want 0) ', ...
    'topology=%s artifacts=%d'], iStatusOf(s,'dc_fault'), iSeverityOf(s,'dc_fault'), ...
    s.contract_status, s.model_validation_status, s.handoff_ready, ...
    iStatusOf(s,'topology'), okFiles);
end


function c = iCaseAveragedSwitchingBlocks(projectRoot)
% Negative readiness: averaged model carrying switching metadata is a blocking
% WARN -> contract BLOCKED, NOT handoff-ready even with a passing probe.
ev = iBaseEvidence();
ev.case_name = 'd2_averaged_switching_meta';
ev.model_fidelity = 'arm_averaged';
% modulation/balancing left as switching-level (nlc/sorting): inconsistent.
outDir = fullfile(projectRoot, 'build', 'reports', 'd2_mmc_hvdc', ev.case_name);
s = summarize_mmc_hvdc_support(ev, 'ModelProbe', iPassingProbe(), 'OutputDir', outDir);

okModWarn   = strcmp(iStatusOf(s, 'modulation_balancing'), 'WARN');
okBlocking  = strcmp(iSeverityOf(s, 'modulation_balancing'), 'blocking');
okContract  = strcmp(s.contract_status, 'BLOCKED');
okNotReady  = ~s.handoff_ready;
okCcMeaning = ~strcmp(iStatusOf(s, 'circulating_current'), 'MISSING'); % CCSC valid for arm_averaged
okFiles     = iArtifactsExist(outDir);

c.name = 'Case D: averaged model + switching metadata -> BLOCKED, NOT ready';
c.passed = okModWarn && okBlocking && okContract && okNotReady && okCcMeaning && okFiles;
c.detail = sprintf(['modulation_balancing=%s/%s contract=%s ready=%d (want 0) ', ...
    'circulating_current=%s artifacts=%d'], iStatusOf(s,'modulation_balancing'), ...
    iSeverityOf(s,'modulation_balancing'), s.contract_status, s.handoff_ready, ...
    iStatusOf(s,'circulating_current'), okFiles);
end


function c = iCaseAdvisoryDoesNotBlock(projectRoot)
% An advisory WARN (energy out of band) must NOT block handoff when the model
% probe passes. Shrinking the capacitor 100x drops energy below the 10 kJ/MVA
% floor without creating any correctness contradiction.
ev = iBaseEvidence();
ev.case_name = 'd2_advisory_only';
ev.submodule_capacitance_F = 50e-6;   % ~0.3 kJ/MVA, below band -> advisory WARN
outDir = fullfile(projectRoot, 'build', 'reports', 'd2_mmc_hvdc', ev.case_name);
s = summarize_mmc_hvdc_support(ev, 'ModelProbe', iPassingProbe(), 'OutputDir', outDir);

okEnergyWarn  = strcmp(iStatusOf(s, 'arm_energy'), 'WARN');
okAdvisory    = strcmp(iSeverityOf(s, 'arm_energy'), 'advisory');
okNoBlocking  = s.n_warn_blocking == 0;
okContract    = strcmp(s.contract_status, 'WARN');   % advisory-only contract
okReady       = s.handoff_ready;                      % still handoff-ready
okFiles       = iArtifactsExist(outDir);

c.name = 'Case E: advisory WARN only -> STILL handoff-ready';
c.passed = okEnergyWarn && okAdvisory && okNoBlocking && okContract && okReady && okFiles;
c.detail = sprintf(['arm_energy=%s/%s n_block=%d contract=%s ready=%d (want 1) ', ...
    'artifacts=%d'], iStatusOf(s,'arm_energy'), iSeverityOf(s,'arm_energy'), ...
    s.n_warn_blocking, s.contract_status, s.handoff_ready, okFiles);
end


function c = iCaseModelProbeFailed(projectRoot)
% Clean contract but the model probe RAN and FAILED: model tier WARN, so the
% package is NOT handoff-ready. The model tier is required, not optional.
ev = iBaseEvidence();
ev.case_name = 'd2_probe_failed';
outDir = fullfile(projectRoot, 'build', 'reports', 'd2_mmc_hvdc', ev.case_name);
s = summarize_mmc_hvdc_support(ev, 'ModelProbe', iFailingProbe(), 'OutputDir', outDir);

okContract = strcmp(s.contract_status, 'PASS');
okModel    = strcmp(s.model_validation_status, 'WARN');
okNotReady = ~s.handoff_ready;
okFiles    = iArtifactsExist(outDir);

c.name = 'Case F: clean contract + failed probe -> NOT handoff-ready';
c.passed = okContract && okModel && okNotReady && okFiles;
c.detail = sprintf('contract=%s model=%s ready=%d (want 0) artifacts=%d', ...
    s.contract_status, s.model_validation_status, s.handoff_ready, okFiles);
end


function c = iCaseMissingRequired(projectRoot)
ev = iBaseEvidence();
ev.case_name = 'd2_missing_required';
ev = rmfield(ev, 'submodule_type');          % topology required field absent
ev = rmfield(ev, 'related_time_domain_run'); % time-domain link absent
outDir = fullfile(projectRoot, 'build', 'reports', 'd2_mmc_hvdc', ev.case_name);
s = summarize_mmc_hvdc_support(ev, 'OutputDir', outDir);

okTopoMissing = strcmp(iStatusOf(s, 'topology'), 'MISSING');
okLinkMissing = strcmp(iStatusOf(s, 'time_domain_link'), 'MISSING');
okContract    = strcmp(s.contract_status, 'MISSING');
okNotReady    = ~s.handoff_ready && s.provisional && s.n_missing >= 2;
okFiles       = iArtifactsExist(outDir);

c.name = 'Case G: missing required fields -> contract MISSING, NOT ready';
c.passed = okTopoMissing && okLinkMissing && okContract && okNotReady && okFiles;
c.detail = sprintf(['topology=%s link=%s contract=%s ready=%d n_missing=%d ', ...
    'artifacts=%d'], iStatusOf(s,'topology'), iStatusOf(s,'time_domain_link'), ...
    s.contract_status, s.handoff_ready, s.n_missing, okFiles);
end


function c = iCaseFullBridgeDcBlockPass(projectRoot)
ev = iBaseEvidence();
ev.case_name = 'd2_fullbridge_dcblock';
ev.submodule_type = 'full_bridge';
ev.dc_fault_handling = 'converter_blocking';   % valid for full-bridge
outDir = fullfile(projectRoot, 'build', 'reports', 'd2_mmc_hvdc', ev.case_name);
s = summarize_mmc_hvdc_support(ev, 'ModelProbe', iPassingProbe(), 'OutputDir', outDir);

okPass     = strcmp(iStatusOf(s, 'dc_fault'), 'PASS');
okContract = strcmp(s.contract_status, 'PASS');
okReady    = s.handoff_ready;
okFiles    = iArtifactsExist(outDir);

c.name = 'Case H: full-bridge converter_blocking -> dc_fault PASS, ready';
c.passed = okPass && okContract && okReady && okFiles;
c.detail = sprintf('dc_fault=%s contract=%s ready=%d submodule=%s artifacts=%d', ...
    iStatusOf(s,'dc_fault'), s.contract_status, s.handoff_ready, ...
    ev.submodule_type, okFiles);
end


function tf = iArtifactsExist(outDir)
tf = isfile(fullfile(outDir, 'mmc_hvdc_support.md')) && ...
     isfile(fullfile(outDir, 'mmc_hvdc_support.json'));
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
