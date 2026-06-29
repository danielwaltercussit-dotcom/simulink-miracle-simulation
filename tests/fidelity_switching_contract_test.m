function result = fidelity_switching_contract_test()
%FIDELITY_SWITCHING_CONTRACT_TEST Smoke/contract test for the E2 helper.
%   Exercises summarize_fidelity_switch_evidence and asserts that the
%   equivalence-evidence contract is enforced:
%     A) a fully documented coarsen switch -> status 'pass', provisional=0;
%     B) each individually missing required field -> status 'provisional'
%        with that field named in missing_required;
%     C) an unrecognized fidelity label -> provisional with a warning;
%     D) a time-step ratio inconsistent with the switch direction ->
%        provisional with a warning;
%     E) artifacts (md + json) are written for a case.
%
%   Pure base-MATLAB; no Simulink/toolbox dependency. Returns a struct and
%   prints PASS/FAIL per check. Scratch artifacts are auto-cleaned.
%
%   Artifacts (transient) under build/reports/e2_fidelity_switching/_contract_scratch/.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

scratch = fullfile(projectRoot, 'build', 'reports', 'e2_fidelity_switching', ...
    '_contract_scratch');
cleanup = onCleanup(@() iCleanup(scratch));

checks = struct([]);
checks = iAddCheck(checks, iCaseComplete(scratch));
checks = iAddCheck(checks, iCaseMissingFields(scratch));
checks = iAddCheck(checks, iCaseUnknownFidelity(scratch));
checks = iAddCheck(checks, iCaseInconsistentStep(scratch));
checks = iAddCheck(checks, iCaseArtifacts(scratch));
checks = iAddCheck(checks, iCaseDocumentedOnly(scratch));
checks = iAddCheck(checks, iCaseMeasuredPass(scratch));
checks = iAddCheck(checks, iCaseMeasuredFail(scratch));
checks = iAddCheck(checks, iCaseTextTargetNotMeasured(scratch));
checks = iAddCheck(checks, iCaseArtifactAbsent(scratch));
checks = iAddCheck(checks, iCaseCrossStudyRejected(scratch));

allPass = all([checks.passed]);
fprintf('\n=== fidelity_switching_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), sum([checks.passed]), numel(checks));

result = struct('passed', allPass, 'checks', checks);
end


function args = iCompleteArgs(caseName, outDir)
% A fully documented coarsen switch (switching_emt -> averaged_emt, ratio>=1).
args = { ...
    'CaseName', caseName, ...
    'StudyObjective', 'PLL transient after coarsening', ...
    'FromFidelity', 'switching_emt', ...
    'ToFidelity', 'averaged_emt', ...
    'OperatingPoint', 'P=0.8pu Q=0 Vg=1.0pu SCR=2.5', ...
    'BaseValues', 'Sb=2MVA Vb=690V fb=50Hz', ...
    'BandwidthRetainedHz', 2000, ...
    'Losses', 'switching losses neglected; conduction lumped', ...
    'InitializationMapping', 'trim averaged model to switching steady state', ...
    'ErrorMetric', 'peak |Vpcc| error < 2% over 0-200ms', ...
    'TimeStepRatio', 20, ...
    'OutputDir', fullfile(outDir, caseName)};
end


function c = iCaseComplete(scratch)
args = iCompleteArgs('complete_pass', scratch);
s = summarize_fidelity_switch_evidence(args{:});
okStatus = strcmp(s.status, 'pass');             % legacy alias preserved
okDoc = strcmp(s.documented_status, 'pass');
okProv = ~s.provisional;
okEmpty = isempty(s.missing_required);
okDir = strcmp(s.direction, 'coarsen');
okMeas = strcmp(s.measured_status, 'not_provided');
okOverall = strcmp(s.overall_status, 'documented_pass');
c.name = 'Case A: documented coarsen switch -> documented_pass, no measured';
c.passed = okStatus && okDoc && okProv && okEmpty && okDir && okMeas && okOverall;
c.detail = sprintf(['status=%s documented=%s provisional=%d missing=%d ', ...
    'direction=%s measured=%s overall=%s'], ...
    s.status, s.documented_status, s.provisional, numel(s.missing_required), ...
    s.direction, s.measured_status, s.overall_status);
end


function c = iCaseMissingFields(scratch)
% Drop each required field one at a time; each must go provisional and name it.
required = { ...
    'OperatingPoint', 'operating_point'; ...
    'BaseValues', 'base_values'; ...
    'BandwidthRetainedHz', 'bandwidth_retained_hz'; ...
    'Losses', 'losses'; ...
    'InitializationMapping', 'initialization_mapping'; ...
    'ErrorMetric', 'error_metric'; ...
    'TimeStepRatio', 'time_step_ratio'};
allOk = true;
firstBad = '';
for k = 1:size(required, 1)
    paramName = required{k, 1};
    fieldName = required{k, 2};
    args = iDropArg(iCompleteArgs(sprintf('missing_%s', fieldName), scratch), paramName);
    s = summarize_fidelity_switch_evidence(args{:});
    isProv = s.provisional && strcmp(s.status, 'provisional');
    named = any(strcmp(fieldName, s.missing_required));
    if ~(isProv && named)
        allOk = false;
        if isempty(firstBad)
            firstBad = sprintf('%s (prov=%d named=%d)', fieldName, isProv, named);
        end
    end
end
c.name = 'Case B: each missing required field -> provisional + named';
c.passed = allOk;
if allOk
    c.detail = sprintf('all %d required fields enforced', size(required, 1));
else
    c.detail = sprintf('first failure: %s', firstBad);
end
end


function c = iCaseUnknownFidelity(scratch)
args = iCompleteArgs('unknown_fidelity', scratch);
args = iSetArg(args, 'ToFidelity', 'magic_model');
s = summarize_fidelity_switch_evidence(args{:});
okProv = s.provisional && strcmp(s.status, 'provisional');
okWarn = any(contains(s.warnings, 'unknown to_fidelity'));
okDir = strcmp(s.direction, 'unknown');
c.name = 'Case C: unrecognized fidelity label -> provisional + warning';
c.passed = okProv && okWarn && okDir;
c.detail = sprintf('provisional=%d warnings=%d direction=%s', ...
    s.provisional, numel(s.warnings), s.direction);
end


function c = iCaseInconsistentStep(scratch)
% Coarsen but ratio<1 (target_dt smaller than source_dt) is inconsistent.
args = iCompleteArgs('inconsistent_step', scratch);
args = iSetArg(args, 'TimeStepRatio', 0.05);
s = summarize_fidelity_switch_evidence(args{:});
okProv = s.provisional && strcmp(s.status, 'provisional');
okFlag = ~s.time_step_consistent;
okWarn = any(contains(s.warnings, 'time_step_ratio'));
c.name = 'Case D: time-step ratio vs direction inconsistent -> provisional';
c.passed = okProv && okFlag && okWarn;
c.detail = sprintf('provisional=%d consistent=%d warnings=%d', ...
    s.provisional, s.time_step_consistent, numel(s.warnings));
end


function c = iCaseArtifacts(scratch)
caseName = 'artifacts_case';
args = iCompleteArgs(caseName, scratch);
s = summarize_fidelity_switch_evidence(args{:});
outDir = fullfile(scratch, caseName);
okMd = isfile(fullfile(outDir, 'fidelity_switch_summary.md'));
okJson = isfile(fullfile(outDir, 'fidelity_switch_summary.json'));
okPaths = isfile(s.report_path) && isfile(s.json_path);
c.name = 'Case E: md + json artifacts written';
c.passed = okMd && okJson && okPaths;
c.detail = sprintf('md=%d json=%d struct_paths=%d', okMd, okJson, okPaths);
end


function c = iCaseDocumentedOnly(scratch)
% Documented contract complete, no measured inputs -> measured not_provided,
% overall documented_pass (must NOT claim measured equivalence).
args = iCompleteArgs('documented_only', scratch);
s = summarize_fidelity_switch_evidence(args{:});
okMeas = strcmp(s.measured_status, 'not_provided');
okOverall = strcmp(s.overall_status, 'documented_pass');
okNotMeasPass = ~strcmp(s.overall_status, 'measured_pass');
c.name = 'Case F: documented-only -> not_provided, never measured_pass';
c.passed = okMeas && okOverall && okNotMeasPass;
c.detail = sprintf('measured=%s overall=%s', s.measured_status, s.overall_status);
end


function c = iCaseMeasuredPass(scratch)
% Real numeric error <= bound + existing same-study artifacts -> measured_pass.
caseName = 'measured_pass';
[paths, root] = iMakeArtifacts(scratch, caseName, 2);
args = iCompleteArgs(caseName, scratch);
args = iAddMeasured(args, 0.013, 0.02, paths, root);
s = summarize_fidelity_switch_evidence(args{:});
okMeas = strcmp(s.measured_status, 'pass');
okOverall = strcmp(s.overall_status, 'measured_pass');
okWithin = s.measured_equivalence.within_bound;
c.name = 'Case G: numeric error<=bound + same-study artifacts -> measured_pass';
c.passed = okMeas && okOverall && okWithin;
c.detail = sprintf('measured=%s overall=%s within_bound=%d', ...
    s.measured_status, s.overall_status, okWithin);
end


function c = iCaseMeasuredFail(scratch)
% Real numeric error > bound (artifacts fine) -> measured_fail.
caseName = 'measured_fail';
[paths, root] = iMakeArtifacts(scratch, caseName, 2);
args = iCompleteArgs(caseName, scratch);
args = iAddMeasured(args, 0.05, 0.02, paths, root);
s = summarize_fidelity_switch_evidence(args{:});
okMeas = strcmp(s.measured_status, 'fail');
okOverall = strcmp(s.overall_status, 'measured_fail');
okNotWithin = ~s.measured_equivalence.within_bound;
c.name = 'Case H: numeric error>bound -> measured_fail';
c.passed = okMeas && okOverall && okNotWithin;
c.detail = sprintf('measured=%s overall=%s within_bound=%d', ...
    s.measured_status, s.overall_status, s.measured_equivalence.within_bound);
end


function c = iCaseTextTargetNotMeasured(scratch)
% A documented text error target but NO numeric measured value must never be
% a measured pass: error_metric (text) is set, MeasuredErrorValue is not.
caseName = 'text_target_only';
[paths, root] = iMakeArtifacts(scratch, caseName, 1);
args = iCompleteArgs(caseName, scratch);   % ErrorMetric (text target) present
% Supply everything measured EXCEPT the numeric value.
args = iSetArg(args, 'MeasuredErrorBound', 0.02);
args = iSetArg(args, 'ErrorMetricDefinition', 'max abs error');
args = iSetArg(args, 'ComparedFromRunId', 'run_a');
args = iSetArg(args, 'ComparedToRunId', 'run_b');
args = iSetArg(args, 'SameStudyArtifactPaths', paths);
args = iSetArg(args, 'SameStudyRoot', root);
s = summarize_fidelity_switch_evidence(args{:});
notMeasPass = ~strcmp(s.measured_status, 'pass') && ...
    ~strcmp(s.overall_status, 'measured_pass');
isProv = strcmp(s.measured_status, 'provisional');
named = any(strcmp('measured_error_value', s.measured_equivalence.missing));
c.name = 'Case I: text target w/o numeric value -> never measured_pass';
c.passed = notMeasPass && isProv && named;
c.detail = sprintf('measured=%s overall=%s value_missing_named=%d', ...
    s.measured_status, s.overall_status, named);
end


function c = iCaseArtifactAbsent(scratch)
% Measured fields present but an artifact path does not exist on disk.
caseName = 'artifact_absent';
root = char(fullfile(scratch, caseName));
if ~isfolder(root); mkdir(root); end
bogus = {char(fullfile(root, 'does_not_exist.csv'))};
args = iCompleteArgs(caseName, scratch);
args = iAddMeasured(args, 0.01, 0.02, bogus, root);
s = summarize_fidelity_switch_evidence(args{:});
isProv = strcmp(s.measured_status, 'provisional');
notMeasPass = ~strcmp(s.overall_status, 'measured_pass');
named = any(strcmp('artifact_files_present', s.measured_equivalence.missing));
c.name = 'Case J: artifact path absent on disk -> measured provisional';
c.passed = isProv && notMeasPass && named;
c.detail = sprintf('measured=%s overall=%s absent_named=%d', ...
    s.measured_status, s.overall_status, named);
end


function c = iCaseCrossStudyRejected(scratch)
% Artifact exists but lives OUTSIDE the declared same-study root -> rejected.
caseName = 'cross_study';
[paths, ~] = iMakeArtifacts(scratch, caseName, 1);   % real file under cross_study
otherRoot = char(fullfile(scratch, 'a_different_study'));
if ~isfolder(otherRoot); mkdir(otherRoot); end
args = iCompleteArgs(caseName, scratch);
args = iAddMeasured(args, 0.01, 0.02, paths, otherRoot);   % wrong root
s = summarize_fidelity_switch_evidence(args{:});
isProv = strcmp(s.measured_status, 'provisional');
notMeasPass = ~strcmp(s.overall_status, 'measured_pass');
named = any(strcmp('artifacts_same_study', s.measured_equivalence.missing));
c.name = 'Case K: artifact outside same-study root -> rejected';
c.passed = isProv && notMeasPass && named;
c.detail = sprintf('measured=%s overall=%s cross_study_flagged=%d', ...
    s.measured_status, s.overall_status, named);
end


function args = iAddMeasured(args, errVal, errBound, paths, root)
args = iSetArg(args, 'MeasuredErrorValue', errVal);
args = iSetArg(args, 'MeasuredErrorBound', errBound);
args = iSetArg(args, 'ErrorMetricDefinition', 'max abs error / base, 0-200ms');
args = iSetArg(args, 'ComparedFromRunId', 'run_switch_001');
args = iSetArg(args, 'ComparedToRunId', 'run_avg_001');
args = iSetArg(args, 'SameStudyArtifactPaths', paths);
args = iSetArg(args, 'SameStudyRoot', root);
end


function [paths, root] = iMakeArtifacts(scratch, caseName, n)
% Create n real placeholder artifact files under <scratch>/<caseName>/study.
root = char(fullfile(scratch, caseName, 'study'));
if ~isfolder(root); mkdir(root); end
paths = cell(1, n);
for k = 1:n
    p = fullfile(root, sprintf('artifact_%d.csv', k));
    fid = fopen(p, 'w');
    if fid >= 0
        fprintf(fid, 't,err\n0,0\n');
        fclose(fid);
    end
    paths{k} = char(p);
end
end


function args = iDropArg(args, paramName)
idx = find(strcmp(args, paramName), 1);
if ~isempty(idx)
    args(idx:idx+1) = [];
end
end


function args = iSetArg(args, paramName, value)
idx = find(strcmp(args, paramName), 1);
if isempty(idx)
    args = [args, {paramName, value}];
else
    args{idx+1} = value;
end
end


function iCleanup(scratch)
if isfolder(scratch)
    rmdir(scratch, 's');
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
