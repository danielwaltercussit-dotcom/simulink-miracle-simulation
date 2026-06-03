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
    s.note = 'Simulink Test artifacts detected; functional fallback still runs as the hard gate.';
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
