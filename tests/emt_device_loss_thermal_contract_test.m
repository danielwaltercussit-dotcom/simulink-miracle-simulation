function result = emt_device_loss_thermal_contract_test()
%EMT_DEVICE_LOSS_THERMAL_CONTRACT_TEST Contract test for E1 loss/thermal evidence.
%   Exercises summarize_device_loss_thermal_evidence across its evidence-level
%   states using synthetic loss inputs (no Simulink), so it runs on a base
%   install. The model-backed coupling to a real run is covered separately by
%   emt_switching_model_backed_test.
%
%   Cases:
%     A) ideal device                         -> N/A, conduction not applicable,
%        loss reported N/A (NOT 0 W);
%     B) model-sourced conduction loss + Rth   -> PASS, conduction model_backed,
%        thermal model_backed, dT = P*Rth, Tj = Ta+dT;
%     C) contract-sourced conduction loss      -> WARN (unsubstantiated);
%     D) model conduction + datasheet switching-> total downgraded to the
%        weakest level (model_referenced);
%     E) thermal never hardware-backed: even a hardware-sourced loss yields a
%        thermal level capped at model_backed.
%
%   Package: E1 EMT/switching-level converter modeling.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));
outDir = fullfile(projectRoot, 'build', 'reports', 'e1_emt_switching', 'device_loss_thermal');

checks = struct([]);
checks = iAddCheck(checks, iCaseIdeal(outDir));
checks = iAddCheck(checks, iCaseModelBacked(outDir));
checks = iAddCheck(checks, iCaseContract(outDir));
checks = iAddCheck(checks, iCaseSwitchingDowngrade(outDir));
checks = iAddCheck(checks, iCaseThermalNeverHardware(outDir));

allPass = all([checks.passed]);
fprintf('\n=== emt_device_loss_thermal_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), nnz([checks.passed]), numel(checks));

result = struct('passed', allPass, 'checks', checks);
end


function c = iCaseIdeal(outDir)
s = summarize_device_loss_thermal_evidence('CaseName','dlt_ideal', ...
    'DeviceLossMode','ideal', 'ConductionLossW',0, 'ConductionLossSource','model', ...
    'ThermalRthCtoA',0.5, 'OutputDir',outDir);
okStatus = strcmp(s.status, 'N/A');
okCond   = ~s.conduction.applicable && strcmp(s.conduction.evidence_level,'not_applicable');
okTherm  = ~s.thermal.applicable;
okFiles  = iArtifactsExist(outDir);
c.name = 'Case A: ideal device -> loss N/A (not 0 W)';
c.passed = okStatus && okCond && okTherm && okFiles;
c.detail = sprintf('status=%s cond.applicable=%d cond.level=%s thermal.applicable=%d files=%d', ...
    s.status, s.conduction.applicable, s.conduction.evidence_level, s.thermal.applicable, okFiles);
end


function c = iCaseModelBacked(outDir)
P = 396.6; Rth = 0.5; Ta = 40;
s = summarize_device_loss_thermal_evidence('CaseName','dlt_model', ...
    'DeviceLossMode','on-resistance+Vf', 'ConductionLossW',P, 'ConductionLossSource','model', ...
    'ThermalRthCtoA',Rth, 'ThermalCth',2.0, 'AmbientC',Ta, 'OutputDir',outDir);
okStatus = strcmp(s.status, 'PASS');
okCond   = strcmp(s.conduction.evidence_level,'model_backed') && abs(s.conduction.value_w - P) < 1e-6;
okDt     = abs(s.thermal.delta_t_c - P*Rth) < 1e-6;
okTj     = abs(s.thermal.junction_c - (Ta + P*Rth)) < 1e-6;
okTau    = abs(s.thermal.tau_s - Rth*2.0) < 1e-6;
okLvl    = strcmp(s.thermal.evidence_level,'model_backed');
c.name = 'Case B: model conduction loss + Rth -> PASS, model_backed thermal';
c.passed = okStatus && okCond && okDt && okTj && okTau && okLvl;
c.detail = sprintf('status=%s cond=%.5g(%s) dT=%.5g Tj=%.5g tau=%.5g level=%s', ...
    s.status, s.conduction.value_w, s.conduction.evidence_level, ...
    s.thermal.delta_t_c, s.thermal.junction_c, s.thermal.tau_s, s.thermal.evidence_level);
end


function c = iCaseContract(outDir)
s = summarize_device_loss_thermal_evidence('CaseName','dlt_contract', ...
    'DeviceLossMode','on-resistance', 'ConductionLossW',100, 'ConductionLossSource','contract', ...
    'OutputDir',outDir);
okStatus = strcmp(s.status, 'WARN');
okCond   = strcmp(s.conduction.evidence_level,'contract_only');
c.name = 'Case C: contract-sourced loss -> WARN (unsubstantiated)';
c.passed = okStatus && okCond;
c.detail = sprintf('status=%s cond.level=%s', s.status, s.conduction.evidence_level);
end


function c = iCaseSwitchingDowngrade(outDir)
s = summarize_device_loss_thermal_evidence('CaseName','dlt_switching', ...
    'DeviceLossMode','on-resistance+Vf', 'ConductionLossW',396.6, 'ConductionLossSource','model', ...
    'SwitchingEnergyJ',[1e-3 1.2e-3], 'SwitchingEventsPerS',2000, 'SwitchingLossSource','model', ...
    'ThermalRthCtoA',0.5, 'OutputDir',outDir);
okSw     = abs(s.switching.value_w - 2.2e-3*2000) < 1e-9 && strcmp(s.switching.evidence_level,'model_referenced');
okTotal  = strcmp(s.total_loss.evidence_level,'model_referenced');   % weakest of {model_backed, model_referenced}
okStatus = strcmp(s.status, 'PASS');
c.name = 'Case D: switching estimate -> total weakest-link model_referenced';
c.passed = okSw && okTotal && okStatus;
c.detail = sprintf('sw=%.5g W sw_level=%s total=%.5g total_level=%s status=%s', ...
    s.switching.value_w, s.switching.evidence_level, s.total_loss.value_w, ...
    s.total_loss.evidence_level, s.status);
end


function c = iCaseThermalNeverHardware(outDir)
% Even a hardware-sourced loss must not yield a hardware-backed TEMPERATURE:
% a junction temperature inferred from a thermal network is a model estimate.
s = summarize_device_loss_thermal_evidence('CaseName','dlt_hw_loss', ...
    'DeviceLossMode','on-resistance+Vf', 'ConductionLossW',200, 'ConductionLossSource','hardware', ...
    'ThermalRthCtoA',0.5, 'ThermalSource','hardware', 'OutputDir',outDir);
okCondHw = strcmp(s.conduction.evidence_level,'hardware_backed');
okThermCap = strcmp(s.thermal.evidence_level,'model_backed');   % capped, never hardware
c.name = 'Case E: thermal estimate never hardware-backed';
c.passed = okCondHw && okThermCap;
c.detail = sprintf('cond.level=%s thermal.level=%s (capped at model_backed)', ...
    s.conduction.evidence_level, s.thermal.evidence_level);
end


function tf = iArtifactsExist(outDir)
tf = isfile(fullfile(outDir, 'device_loss_thermal_summary.md')) && ...
     isfile(fullfile(outDir, 'device_loss_thermal_summary.json'));
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
