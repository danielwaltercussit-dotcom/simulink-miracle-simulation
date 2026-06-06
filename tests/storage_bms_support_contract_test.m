function result = storage_bms_support_contract_test()
%STORAGE_BMS_SUPPORT_CONTRACT_TEST Contract test for the D3 storage helper.
%   Exercises summarize_storage_bms_support on synthetic descriptors. The
%   defining assertion is the battery/BMS-vs-generic-DC-link separation: a
%   constant-DC-source converter run must NOT count as battery validation.
%
%   Cases:
%     A) Fully documented BESS, distinct battery + DC-link artifacts ->
%        battery_layer_proven, separated, handoff_ready, no MISSING.
%     B) DC-link only (constant_dc_source, battery_evidence required+absent) ->
%        battery_model MISSING, battery_evidence MISSING,
%        battery_layer_proven=false: generic DC-link evidence does not prove
%        the battery layer.
%     C) Shared artifact reused for battery and dc_link -> separated=false, a
%        separation WARN is raised.
%     D) Provisional case (no rated energy/power, no mode) -> artifact PASS is
%        downgraded to WARN; not handoff_ready.
%     E) Documented battery model but battery_evidence MISSING ->
%        battery_layer_proven=false even though the model is named.
%     F) study_root declared, battery + DC-link artifacts both under it ->
%        same_study=true, handoff_ready (distinct AND same-study).
%     G) study_root declared, DC-link artifact from a DIFFERENT study ->
%        same_study=false, handoff_ready=false even though paths are distinct
%        and the battery layer is otherwise proven: cross-study evidence cannot
%        be combined into one validated case.
%     H) battery + DC-link + EMT declare a matching operating_point under one
%        study_root -> same_operating_condition=true, handoff_ready.
%     I) DC-link declares a mismatched operating_point (hot, high-SOC, higher
%        power) -> same_operating_condition=false, handoff_ready=false even
%        though same_study=true and battery_layer_proven stays true: the screen
%        is orthogonal to the battery-layer gate.
%
%   No Simulink, no toolbox dependency: synthetic descriptors plus tiny real
%   scratch files through the base-MATLAB helper. Scratch dir is removed at the
%   end of the run so no stale artifact can produce a false PASS later.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

scratch = fullfile(projectRoot, 'build', 'reports', 'd3_storage_bms', ...
    'contract_test_scratch');
iResetDir(scratch);
closer = onCleanup(@() iRemoveDir(scratch));

% Real artifact files the descriptors point at.
battFile = iTouch(fullfile(scratch, 'battery_evidence.json'));
dcFile   = iTouch(fullfile(scratch, 'dc_link_evidence.json'));
emtFile  = iTouch(fullfile(scratch, 'emt_run.json'));

% Study-scoped fixtures for the same-study check: studyA holds a self-consistent
% battery+DC-link+EMT set; studyB holds a foreign DC-link run from another study.
studyA = fullfile(scratch, 'studyA');
studyB = fullfile(scratch, 'studyB');
battA  = iTouch(fullfile(studyA, 'battery.json'));
dcA    = iTouch(fullfile(studyA, 'dc_link.json'));
emtA   = iTouch(fullfile(studyA, 'emt.json'));
dcB    = iTouch(fullfile(studyB, 'dc_link.json'));

checks = struct([]);
checks = iAddCheck(checks, iCaseDocumented(scratch, battFile, dcFile, emtFile));
checks = iAddCheck(checks, iCaseDcLinkOnly(scratch, dcFile, emtFile));
checks = iAddCheck(checks, iCaseSharedArtifact(scratch, dcFile, emtFile));
checks = iAddCheck(checks, iCaseProvisional(scratch, battFile, dcFile));
checks = iAddCheck(checks, iCaseModelButNoBatteryEvidence(scratch, dcFile, emtFile));
checks = iAddCheck(checks, iCaseSameStudy(scratch, studyA, battA, dcA, emtA));
checks = iAddCheck(checks, iCaseCrossStudy(scratch, studyA, battA, dcB, emtA));
checks = iAddCheck(checks, iCaseSameOpCondition(scratch, studyA, battA, dcA, emtA));
checks = iAddCheck(checks, iCaseMismatchedOpCondition(scratch, studyA, battA, dcA, emtA));

allPass = all([checks.passed]);
fprintf('\n=== storage_bms_support_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), sum([checks.passed]), numel(checks));

result = struct('passed', allPass, 'checks', checks);
end


function c = iCaseDocumented(scratch, battFile, dcFile, emtFile)
% Fully documented BESS with distinct battery + DC-link artifacts.
d = struct( ...
    'case_name', 'bess_documented', ...
    'battery_model', 'equivalent_circuit_2RC', ...
    'evidence_source', 'simulated', ...
    'grid_support_mode', 'frequency_response', ...
    'rated_energy_kwh', 500, ...
    'rated_power_kw', 250, ...
    'soc_soh', struct('soc_window', [0.2 0.9], 'soh', 0.95), ...
    'thermal', struct('limit_c', 45, 'model', 'lumped_RC'), ...
    'protection', struct('ov', true, 'uv', true, 'oc', true, 'ot', true), ...
    'battery_evidence', struct('artifact', battFile, 'required', true), ...
    'dc_link', struct('artifact', dcFile, 'required', true), ...
    'time_domain_validation', struct('artifact', emtFile, 'required', true));
s = summarize_storage_bms_support(d, 'OutputDir', ...
    fullfile(scratch, 'bess_documented'));

okProven   = s.battery_layer_proven;
okSep      = s.separation.separated;
okHandoff  = s.handoff_ready;
okNoMiss   = s.status_counts.MISSING == 0;
okBattDim  = strcmp(iDimStatus(s, 'battery_evidence'), 'PASS');
okFiles    = iArtifactsExist(fullfile(scratch, 'bess_documented'));

c.name = 'Case A: documented BESS, distinct artifacts -> proven + handoff_ready';
c.passed = okProven && okSep && okHandoff && okNoMiss && okBattDim && okFiles;
c.detail = sprintf(['battery_proven=%d separated=%d handoff=%d MISSING=%d ', ...
    'battery_dim=%s files=%d'], okProven, okSep, okHandoff, ...
    s.status_counts.MISSING, iDimStatus(s, 'battery_evidence'), okFiles);
end


function c = iCaseDcLinkOnly(scratch, dcFile, emtFile)
% Constant DC source, battery evidence required but absent: the defining check.
% Generic DC-link evidence must NOT prove the battery layer.
d = struct( ...
    'case_name', 'dc_link_only', ...
    'battery_model', 'constant_dc_source', ...
    'evidence_source', 'simulated', ...
    'grid_support_mode', 'pcs_volt_var', ...
    'rated_power_kw', 250, ...
    'battery_evidence', struct('required', true), ...
    'dc_link', struct('artifact', dcFile, 'required', true), ...
    'time_domain_validation', struct('artifact', emtFile, 'required', true));
s = summarize_storage_bms_support(d, 'OutputDir', ...
    fullfile(scratch, 'dc_link_only'));

okModelMiss = strcmp(iDimStatus(s, 'battery_model'), 'MISSING');
okBattMiss  = strcmp(iDimStatus(s, 'battery_evidence'), 'MISSING');
okDcOk      = any(strcmp(iDimStatus(s, 'dc_link'), {'PASS', 'WARN'}));
okNotProven = ~s.battery_layer_proven;
okNotHand   = ~s.handoff_ready;

c.name = 'Case B: DC-link only -> battery MISSING, layer NOT proven';
c.passed = okModelMiss && okBattMiss && okDcOk && okNotProven && okNotHand;
c.detail = sprintf(['battery_model=%s battery_evidence=%s dc_link=%s ', ...
    'proven=%d handoff=%d'], iDimStatus(s, 'battery_model'), ...
    iDimStatus(s, 'battery_evidence'), iDimStatus(s, 'dc_link'), ...
    s.battery_layer_proven, s.handoff_ready);
end


function c = iCaseSharedArtifact(scratch, dcFile, emtFile)
% Same artifact reused for battery and DC-link: separation must fail with WARN.
d = struct( ...
    'case_name', 'shared_artifact', ...
    'battery_model', 'shepherd', ...
    'evidence_source', 'simulated', ...
    'grid_support_mode', 'peak_shaving', ...
    'rated_energy_kwh', 100, ...
    'battery_evidence', struct('artifact', dcFile, 'required', true), ...
    'dc_link', struct('artifact', dcFile, 'required', true), ...
    'time_domain_validation', struct('artifact', emtFile, 'required', true));
s = summarize_storage_bms_support(d, 'OutputDir', ...
    fullfile(scratch, 'shared_artifact'));

okNotSep   = ~s.separation.separated;
okIssue    = ~isempty(s.separation.issues);
okNotHand  = ~s.handoff_ready;

c.name = 'Case C: shared artifact -> separated=false + WARN';
c.passed = okNotSep && okIssue && okNotHand;
c.detail = sprintf('separated=%d n_issues=%d handoff=%d', ...
    s.separation.separated, numel(s.separation.issues), s.handoff_ready);
end


function c = iCaseProvisional(scratch, battFile, dcFile)
% No rated energy/power and no grid-support mode -> provisional; artifact PASS
% downgraded to WARN.
d = struct( ...
    'case_name', 'provisional_case', ...
    'battery_model', 'equivalent_circuit_2RC', ...
    'evidence_source', 'planned', ...
    'battery_evidence', struct('artifact', battFile, 'required', true), ...
    'dc_link', struct('artifact', dcFile, 'required', true));
s = summarize_storage_bms_support(d, 'OutputDir', ...
    fullfile(scratch, 'provisional_case'));

okProv     = s.provisional;
okBattWarn = strcmp(iDimStatus(s, 'battery_evidence'), 'WARN');
okNotProven = ~s.battery_layer_proven;
okNotHand  = ~s.handoff_ready;
okMissList = any(strcmp(s.missing_documentation, 'rated_energy_or_power')) && ...
    any(strcmp(s.missing_documentation, 'grid_support_mode'));

c.name = 'Case D: provisional -> artifact PASS downgraded to WARN';
c.passed = okProv && okBattWarn && okNotProven && okNotHand && okMissList;
c.detail = sprintf(['provisional=%d battery_evidence=%s proven=%d handoff=%d ', ...
    'missing={%s}'], s.provisional, iDimStatus(s, 'battery_evidence'), ...
    s.battery_layer_proven, s.handoff_ready, strjoin(s.missing_documentation, ','));
end


function c = iCaseModelButNoBatteryEvidence(scratch, dcFile, emtFile)
% Battery model named, but battery_evidence missing: model alone does not prove
% the battery layer.
d = struct( ...
    'case_name', 'model_no_evidence', ...
    'battery_model', 'electrochemical', ...
    'evidence_source', 'analytic', ...
    'grid_support_mode', 'arbitrage', ...
    'rated_energy_kwh', 200, ...
    'battery_evidence', struct('required', true), ...
    'dc_link', struct('artifact', dcFile, 'required', true), ...
    'time_domain_validation', struct('artifact', emtFile, 'required', true));
s = summarize_storage_bms_support(d, 'OutputDir', ...
    fullfile(scratch, 'model_no_evidence'));

okModelPass = strcmp(iDimStatus(s, 'battery_model'), 'PASS');
okBattMiss  = strcmp(iDimStatus(s, 'battery_evidence'), 'MISSING');
okNotProven = ~s.battery_layer_proven;

c.name = 'Case E: model named but no battery evidence -> NOT proven';
c.passed = okModelPass && okBattMiss && okNotProven;
c.detail = sprintf('battery_model=%s battery_evidence=%s proven=%d', ...
    iDimStatus(s, 'battery_model'), iDimStatus(s, 'battery_evidence'), ...
    s.battery_layer_proven);
end


function c = iCaseSameStudy(scratch, studyA, battA, dcA, emtA)
% study_root declared; battery + DC-link + EMT all live under studyA.
% Distinct AND same-study -> same_study=true, handoff_ready.
d = struct( ...
    'case_name', 'same_study', ...
    'battery_model', 'equivalent_circuit_2RC', ...
    'evidence_source', 'simulated', ...
    'grid_support_mode', 'frequency_response', ...
    'rated_energy_kwh', 500, ...
    'study_root', studyA, ...
    'soc_soh', struct('soc_window', [0.2 0.9], 'soh', 0.95), ...
    'thermal', struct('limit_c', 45, 'model', 'lumped_RC'), ...
    'protection', struct('ov', true, 'uv', true, 'oc', true, 'ot', true), ...
    'battery_evidence', struct('artifact', battA, 'required', true), ...
    'dc_link', struct('artifact', dcA, 'required', true), ...
    'time_domain_validation', struct('artifact', emtA, 'required', true));
s = summarize_storage_bms_support(d, 'OutputDir', fullfile(scratch, 'same_study'));

okSame    = islogical(s.separation.same_study) && s.separation.same_study;
okSep     = s.separation.separated;
okProven  = s.battery_layer_proven;
okHandoff = s.handoff_ready;

c.name = 'Case F: study_root, all evidence same-study -> handoff_ready';
c.passed = okSame && okSep && okProven && okHandoff;
c.detail = sprintf('same_study=%d separated=%d proven=%d handoff=%d', ...
    okSame, okSep, okProven, okHandoff);
end


function c = iCaseCrossStudy(scratch, studyA, battA, dcB, emtA)
% study_root = studyA, but the DC-link artifact comes from studyB. Paths are
% distinct (separated stays true) and the battery layer is otherwise proven,
% yet cross-study evidence must NOT be combined: same_study=false blocks
% handoff_ready.
d = struct( ...
    'case_name', 'cross_study', ...
    'battery_model', 'equivalent_circuit_2RC', ...
    'evidence_source', 'simulated', ...
    'grid_support_mode', 'frequency_response', ...
    'rated_energy_kwh', 500, ...
    'study_root', studyA, ...
    'soc_soh', struct('soc_window', [0.2 0.9], 'soh', 0.95), ...
    'thermal', struct('limit_c', 45, 'model', 'lumped_RC'), ...
    'protection', struct('ov', true, 'uv', true, 'oc', true, 'ot', true), ...
    'battery_evidence', struct('artifact', battA, 'required', true), ...
    'dc_link', struct('artifact', dcB, 'required', true), ...
    'time_domain_validation', struct('artifact', emtA, 'required', true));
s = summarize_storage_bms_support(d, 'OutputDir', fullfile(scratch, 'cross_study'));

okNotSame  = islogical(s.separation.same_study) && ~s.separation.same_study;
okSepTrue  = s.separation.separated;          % distinct paths -> still separated
okProven   = s.battery_layer_proven;          % battery layer otherwise proven
okNotHand  = ~s.handoff_ready;                % but cross-study blocks handoff
okIssue    = ~isempty(s.separation.issues);

c.name = 'Case G: cross-study DC-link -> same_study=false blocks handoff';
c.passed = okNotSame && okSepTrue && okProven && okNotHand && okIssue;
c.detail = sprintf(['same_study=%d separated=%d proven=%d handoff=%d ', ...
    'n_issues=%d'], s.separation.same_study, okSepTrue, okProven, ...
    s.handoff_ready, numel(s.separation.issues));
end


function c = iCaseSameOpCondition(scratch, studyA, battA, dcA, emtA)
% Battery + DC-link + EMT all declare a matching operating point (same SOC,
% temperature, power) under one study_root -> same_operating_condition=true and
% handoff_ready. Distinct from same-study: this checks the operating point, not
% the path.
op = struct('soc', 0.5, 'temperature_c', 25, 'p_kw', 200);
d = struct( ...
    'case_name', 'same_op_condition', ...
    'battery_model', 'equivalent_circuit_2RC', ...
    'evidence_source', 'simulated', ...
    'grid_support_mode', 'frequency_response', ...
    'rated_energy_kwh', 500, ...
    'study_root', studyA, ...
    'soc_soh', struct('soc_window', [0.2 0.9], 'soh', 0.95), ...
    'thermal', struct('limit_c', 45, 'model', 'lumped_RC'), ...
    'protection', struct('ov', true, 'uv', true, 'oc', true, 'ot', true), ...
    'battery_evidence', struct('artifact', battA, 'required', true, 'operating_point', op), ...
    'dc_link', struct('artifact', dcA, 'required', true, 'operating_point', op), ...
    'time_domain_validation', struct('artifact', emtA, 'required', true, 'operating_point', op));
s = summarize_storage_bms_support(d, 'OutputDir', fullfile(scratch, 'same_op'));

oc = s.operating_condition;
okSameOp  = islogical(oc.same_operating_condition) && oc.same_operating_condition;
okAnchor  = strcmp(oc.anchor_field, 'battery_evidence');
okProven  = s.battery_layer_proven;
okHandoff = s.handoff_ready;
okNoIssue = isempty(oc.issues);

c.name = 'Case H: matching operating points -> same_operating_condition + handoff';
c.passed = okSameOp && okAnchor && okProven && okHandoff && okNoIssue;
c.detail = sprintf('same_op=%d anchor=%s proven=%d handoff=%d n_issues=%d', ...
    okSameOp, oc.anchor_field, okProven, okHandoff, numel(oc.issues));
end


function c = iCaseMismatchedOpCondition(scratch, studyA, battA, dcA, emtA)
% Same study_root (same_study stays true) and battery layer proven, but the
% DC-link run is at a different operating point (hot, high-SOC, higher power)
% than the battery anchor. same_operating_condition=false must block handoff,
% while battery_layer_proven stays true (the screen is orthogonal).
battOp = struct('soc', 0.5, 'temperature_c', 25, 'p_kw', 200);
dcOp   = struct('soc', 0.9, 'temperature_c', 45, 'p_kw', 250);
d = struct( ...
    'case_name', 'mismatched_op_condition', ...
    'battery_model', 'equivalent_circuit_2RC', ...
    'evidence_source', 'simulated', ...
    'grid_support_mode', 'frequency_response', ...
    'rated_energy_kwh', 500, ...
    'study_root', studyA, ...
    'soc_soh', struct('soc_window', [0.2 0.9], 'soh', 0.95), ...
    'thermal', struct('limit_c', 45, 'model', 'lumped_RC'), ...
    'protection', struct('ov', true, 'uv', true, 'oc', true, 'ot', true), ...
    'battery_evidence', struct('artifact', battA, 'required', true, 'operating_point', battOp), ...
    'dc_link', struct('artifact', dcA, 'required', true, 'operating_point', dcOp), ...
    'time_domain_validation', struct('artifact', emtA, 'required', true, 'operating_point', battOp));
s = summarize_storage_bms_support(d, 'OutputDir', fullfile(scratch, 'mismatch_op'));

oc = s.operating_condition;
okNotSameOp = islogical(oc.same_operating_condition) && ~oc.same_operating_condition;
okSameStudy = islogical(s.separation.same_study) && s.separation.same_study;
okProven    = s.battery_layer_proven;   % orthogonal: battery layer stays proven
okNotHand   = ~s.handoff_ready;          % but mismatched op condition blocks
okIssue     = ~isempty(oc.issues);

c.name = 'Case I: mismatched operating point -> same_operating_condition=false blocks handoff';
c.passed = okNotSameOp && okSameStudy && okProven && okNotHand && okIssue;
c.detail = sprintf('same_op=%d same_study=%d proven=%d handoff=%d n_issues=%d', ...
    s.operating_condition.same_operating_condition, s.separation.same_study, ...
    okProven, s.handoff_ready, numel(oc.issues));
end


function status = iDimStatus(summary, name)
status = '';
for k = 1:numel(summary.dimensions)
    if strcmp(summary.dimensions(k).name, name)
        status = summary.dimensions(k).status;
        return
    end
end
end


function tf = iArtifactsExist(outDir)
tf = isfile(fullfile(outDir, 'storage_bms_support.md')) && ...
     isfile(fullfile(outDir, 'storage_bms_support.json'));
end


function path = iTouch(path)
parent = fileparts(path);
if ~isempty(parent) && ~isfolder(parent)
    mkdir(parent);
end
fid = fopen(path, 'w');
if fid < 0
    error('StorageBmsTest:CannotTouch', 'Cannot create %s', path);
end
fprintf(fid, '{"synthetic":true}\n');
fclose(fid);
end


function iResetDir(d)
iRemoveDir(d);
mkdir(d);
end


function iRemoveDir(d)
if isfolder(d)
    rmdir(d, 's');
end
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
