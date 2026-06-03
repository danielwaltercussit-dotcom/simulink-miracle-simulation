function s = ai_in_loop_stage_sltest(projectRoot, modelName, iterDir, tSmoke)
%AI_IN_LOOP_STAGE_SLTEST  Run persistent model tests.
%   Prefer Simulink Test artifacts when present; otherwise use the project's
%   persistent functional fallback (simulation + finite-output assertions).
s = struct('name','S7_SLTEST','status','PASS','model',char(modelName), ...
    'backend','functional_fallback','report_path','');
testDir = fullfile(projectRoot,'tests');
if ~isfolder(testDir)
    mkdir(testDir);
end

if nargin < 4 || isempty(tSmoke)
    tSmoke = 0.005;
end

fallbackPath = fullfile(testDir, 'ai_in_loop_functional_model_test.m');
if ~isfile(fallbackPath)
    write_functional_test(fallbackPath);
end

testFiles = dir(fullfile(testDir,'*.mldatx'));
s.sltest_files = {testFiles.name};
if ~isempty(testFiles)
    s.backend = 'sltest_testmanager_plus_functional_fallback';
    s.testmanager = run_sltest_artifacts(testFiles);
    if strcmp(s.testmanager.status, 'FAIL')
        result = struct('passed', false, 'message', s.testmanager.message, ...
            'sim_time', tSmoke, 'checks', struct('sltest_testmanager', false));
        s.status = 'FAIL';
        s.report_path = fullfile(iterDir, 'sltest_summary.md');
        write_sltest_summary(s.report_path, s, result);
        error('AIInLoop:SltestHarnessFail', 'Simulink Test harness failed: %s', s.testmanager.message);
    end
    s.note = s.testmanager.message;
else
    s.note = 'No .mldatx artifacts found; ran functional fallback per testing-simulink-models guidance for unavailable Simulink Test.';
end

addpath(testDir);
addpath(fullfile(projectRoot, 'scripts', 'verification'));
s.verification_report_path = fullfile(iterDir, 'model_verification_summary.md');
result = ai_in_loop_functional_model_test(char(modelName), tSmoke, s.verification_report_path);
s.checks = result.checks;
if isfield(result, 'stop_time')
    s.sim_time = result.stop_time;
else
    s.sim_time = tSmoke;
end
result.sim_time = s.sim_time;
s.report_path = fullfile(iterDir, 'sltest_summary.md');
if ~result.passed
    s.status = 'FAIL';
    s.note = result.message;
    write_sltest_summary(s.report_path, s, result);
    error('AIInLoop:FunctionalTestFail', 'Functional model test failed: %s', result.message);
end
write_sltest_summary(s.report_path, s, result);
end

function summary = run_sltest_artifacts(testFiles)
summary = struct('status','SKIPPED','passed',true,'total',0,'failed',0, ...
    'files',{{testFiles.name}}, 'message','');
if exist('sltest.testmanager.load', 'file') ~= 2 || exist('sltest.testmanager.run', 'file') ~= 2
    summary.message = 'Simulink Test Manager API unavailable; functional fallback remains the hard gate.';
    return
end

summary.status = 'PASS';
summary.message = 'Simulink Test artifacts ran successfully; functional fallback also runs as the hard gate.';
for k = 1:numel(testFiles)
    filePath = fullfile(testFiles(k).folder, testFiles(k).name);
    try
        sltest.testmanager.clear;
        sltest.testmanager.load(filePath);
        resultSet = sltest.testmanager.run;
        outcome = extract_sltest_outcome(resultSet);
        summary.total = summary.total + 1;
        if is_sltest_failure(outcome)
            summary.failed = summary.failed + 1;
            summary.status = 'FAIL';
            summary.passed = false;
            summary.message = sprintf('Failing Simulink Test artifact: %s (%s)', testFiles(k).name, outcome);
            return
        end
    catch ME
        summary.failed = summary.failed + 1;
        summary.status = 'FAIL';
        summary.passed = false;
        summary.message = sprintf('Could not run Simulink Test artifact %s: %s', testFiles(k).name, ME.message);
        return
    end
end
end

function outcome = extract_sltest_outcome(resultSet)
try
    outcome = char(resultSet.Outcome);
catch
    try
        outcome = char(getOutcome(resultSet));
    catch
        try
            outcome = strtrim(evalc('disp(resultSet)'));
        catch
            outcome = 'unknown';
        end
    end
end
if isempty(outcome)
    outcome = 'unknown';
end
end

function tf = is_sltest_failure(outcome)
txt = lower(string(outcome));
tf = contains(txt, 'fail') || contains(txt, 'error') || contains(txt, 'incomplete');
end

function write_functional_test(path)
fid = fopen(path, 'w');
if fid < 0
    error('AIInLoop:CannotWriteTest', 'Cannot write %s', path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'function result = ai_in_loop_functional_model_test(modelName, tStop, reportPath)\n');
fprintf(fid, '%%AI_IN_LOOP_FUNCTIONAL_MODEL_TEST Persistent fallback tests for AI-in-loop models.\n');
fprintf(fid, 'try\n');
fprintf(fid, '    if nargin < 3; reportPath = ''''; end\n');
fprintf(fid, '    projectRoot = fileparts(fileparts(mfilename(''fullpath'')));\n');
fprintf(fid, '    addpath(fullfile(projectRoot, ''scripts'', ''verification''));\n');
fprintf(fid, '    addpath(fullfile(projectRoot, ''scripts'', ''loop''));\n');
fprintf(fid, '    result = verify_power_system_model(modelName, ''ProjectRoot'', projectRoot, ''StopTime'', tStop, ''ReportPath'', reportPath, ''RequireOutputs'', true);\n');
fprintf(fid, 'catch ME\n');
fprintf(fid, '    result = struct(''passed'', false, ''message'', '''', ''sim_time'', tStop, ''checks'', struct());\n');
fprintf(fid, '    result.message = ME.message;\n');
fprintf(fid, 'end\n');
fprintf(fid, 'end\n');
end

function write_sltest_summary(path, s, result)
fid = fopen(path, 'w');
if fid < 0
    warning('AIInLoop:CannotWriteSltestSummary', 'Cannot write %s', path);
    return
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# S7 Test Summary\n\n');
fprintf(fid, '- stage: `%s`\n', s.name);
fprintf(fid, '- model: `%s`\n', s.model);
fprintf(fid, '- backend: `%s`\n', s.backend);
fprintf(fid, '- status: `%s`\n', ternary(result.passed, 'PASS', 'FAIL'));
fprintf(fid, '- sim_time: %.6g\n', result.sim_time);
fprintf(fid, '- message: %s\n\n', result.message);
if isfield(s, 'testmanager')
    fprintf(fid, '## Simulink Test Manager\n\n');
    fprintf(fid, '- status: `%s`\n', s.testmanager.status);
    fprintf(fid, '- total_artifacts: %d\n', s.testmanager.total);
    fprintf(fid, '- failed_artifacts: %d\n', s.testmanager.failed);
    fprintf(fid, '- message: %s\n\n', s.testmanager.message);
end
if isfield(s, 'sltest_files') && ~isempty(s.sltest_files)
    fprintf(fid, '## Test Artifacts\n\n');
    for k = 1:numel(s.sltest_files)
        fprintf(fid, '- `%s`\n', s.sltest_files{k});
    end
    fprintf(fid, '\n');
end
fprintf(fid, '## Checks\n\n');
names = fieldnames(result.checks);
for k = 1:numel(names)
    fprintf(fid, '- %s: `%s`\n', names{k}, mat2str(result.checks.(names{k})));
end
if isfield(s, 'verification_report_path') && ~isempty(s.verification_report_path)
    fprintf(fid, '\nVerification report: `%s`\n', s.verification_report_path);
end
end

function v = ternary(cond, yesVal, noVal)
if cond; v = yesVal; else; v = noVal; end
end
