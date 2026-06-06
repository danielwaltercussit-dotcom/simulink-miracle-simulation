function result = mmc_hvdc_model_backed_smoke()
%MMC_HVDC_MODEL_BACKED_SMOKE Real model-backed smoke test for the D2 package.
%   Unlike mmc_hvdc_support_contract_test (which uses synthetic ModelProbe
%   structs to exercise the readiness policy without Simulink), this test
%   ACTUALLY builds, loads, updates, and simulates the non-private MMC DC-link
%   fixture and feeds the real probe into summarize_mmc_hvdc_support.
%
%   It is the package's proof that model_validation_status = PASS is reachable
%   only through a genuine simulation. Requires Simulink. Artifacts under
%   build/reports/d2_mmc_hvdc/_fixture and .../model_backed_smoke.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));
addpath(fullfile(projectRoot, '.agents', 'skills', 'device-pack-mmc-hvdc', 'assets'));

checks = struct([]);
checks = iAddCheck(checks, iCaseRealProbeRuns(projectRoot));
checks = iAddCheck(checks, iCaseRealProbeGatesHandoff(projectRoot));

allPass = all([checks.passed]);
fprintf('\n=== mmc_hvdc_model_backed_smoke ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), nnz([checks.passed]), numel(checks));
result = struct('passed', allPass, 'checks', checks);
end


function c = iCaseRealProbeRuns(projectRoot)
% The real probe must build/load/update/simulate and match analytic physics.
outDir = fullfile(projectRoot, 'build', 'reports', 'd2_mmc_hvdc', '_fixture');
probe = run_mmc_dc_link_probe('OutDir', outDir);

okRan    = probe.ran;
okStage  = strcmp(probe.stage, 'simulate');
okPassed = probe.passed;
okErr    = isfield(probe.metrics, 'rel_rms_error') && probe.metrics.rel_rms_error <= 0.02;

c.name = 'Real probe builds+simulates fixture, matches analytic';
c.passed = okRan && okStage && okPassed && okErr;
c.detail = sprintf('ran=%d stage=%s passed=%d rel_rms=%.3g', ...
    probe.ran, probe.stage, probe.passed, probe.metrics.rel_rms_error);
end


function c = iCaseRealProbeGatesHandoff(projectRoot)
% A clean contract + the REAL passing probe -> model_validation PASS + ready.
outDir = fullfile(projectRoot, 'build', 'reports', 'd2_mmc_hvdc', '_fixture');
probe = run_mmc_dc_link_probe('OutDir', outDir);
ev = iCleanFullBridge();
caseDir = fullfile(projectRoot, 'build', 'reports', 'd2_mmc_hvdc', 'model_backed_smoke');
s = summarize_mmc_hvdc_support(ev, 'ModelProbe', probe, 'OutputDir', caseDir);

okModel = strcmp(s.model_validation_status, 'PASS');
okReady = s.handoff_ready;
okFiles = isfile(fullfile(caseDir, 'mmc_hvdc_support.md'));

c.name = 'Real probe drives model_validation=PASS and handoff_ready';
c.passed = okModel && okReady && okFiles;
c.detail = sprintf('model=%s ready=%d artifacts=%d', ...
    s.model_validation_status, s.handoff_ready, okFiles);
end


function ev = iCleanFullBridge()
ev = struct( ...
    'case_name', 'd2_model_backed_smoke', ...
    'source_model_or_script', 'assets/build_mmc_dc_link_fixture.m', ...
    'station_topology', 'symmetric_monopole', ...
    'submodule_type', 'full_bridge', ...
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
    'dc_link_dynamics', 'first_order_RC_fixture', ...
    'ac_fault_handling', 'current_limit_ride_through', ...
    'dc_fault_handling', 'converter_blocking', ...
    'related_time_domain_run', 'build/reports/d2_mmc_hvdc/_fixture');
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
