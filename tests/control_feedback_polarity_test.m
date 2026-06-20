function result = control_feedback_polarity_test()
%CONTROL_FEEDBACK_POLARITY_TEST Regression tests for feedback sign contracts.
%   Builds small disposable models under build/generated_models and proves that
%   a positive-feedback wiring error is caught only when a feedback-polarity
%   contract is supplied. Also validates per-contract classification codes,
%   missing-block handling, non-Sum-block handling, and bad contracts.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'verification'));
addpath(fullfile(projectRoot, 'scripts', 'loop'));

modelDir = fullfile(projectRoot, 'build', 'generated_models');
reportDir = fullfile(projectRoot, 'build', 'reports', 'control_feedback_polarity_test');
if ~isfolder(modelDir); mkdir(modelDir); end
if ~isfolder(reportDir); mkdir(reportDir); end

% Do NOT addpath(modelDir) — it causes model-shadowing warnings when
% new_system creates a model whose .slx already exists on path.
% The verification helpers find models via ProjectRoot/build/generated_models/.

negModel = 'cfp_negative_feedback';
posModel = 'cfp_positive_feedback';
fixModel = 'cfp_positive_feedback_autofix';
gainModel = 'cfp_gain_block';

build_feedback_model(negModel, '+-', modelDir);
build_feedback_model(posModel, '++', modelDir);
build_feedback_model(fixModel, '++', modelDir);
build_gain_model(gainModel, modelDir);

contract = struct('block_path', 'Sum', ...
    'expected_inputs', '+-', ...
    'description', 'reference minus measured feedback');

checks = struct([]);
checks = add_check(checks, case_existing_gate_stays_backward_compatible(projectRoot, posModel, reportDir));
checks = add_check(checks, case_negative_feedback_passes(projectRoot, negModel, contract, reportDir));
checks = add_check(checks, case_positive_feedback_mismatch(projectRoot, posModel, contract, reportDir));
checks = add_check(checks, case_positive_feedback_autofix_fixed(projectRoot, fixModel, contract, reportDir));
checks = add_check(checks, case_missing_block_contract(projectRoot, negModel, reportDir));
checks = add_check(checks, case_non_sum_block_contract(projectRoot, gainModel, reportDir));
checks = add_check(checks, case_bad_contract_empty_fields(projectRoot, negModel, reportDir));
checks = add_check(checks, case_bad_contract_missing_expected(projectRoot, negModel, reportDir));
checks = add_check(checks, case_json_report_generated(projectRoot, negModel, contract, reportDir));
checks = add_check(checks, case_integration_aggregates_via_model_gate(projectRoot, posModel, reportDir));

allPass = all([checks.passed]);
fprintf('\n=== control_feedback_polarity_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', tag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s\n', tag(allPass));

result = struct('passed', allPass, 'checks', checks);
assert(allPass, 'ControlFeedbackPolarity:TestFailed', ...
    'One or more feedback polarity checks failed.');
end

%% Test cases

function c = case_existing_gate_stays_backward_compatible(projectRoot, modelName, reportDir)
r = verify_power_system_model(modelName, ...
    'ProjectRoot', projectRoot, ...
    'StopTime', 0.5, ...
    'ReportPath', fullfile(reportDir, [modelName '_generic.md']), ...
    'RequiredSignals', {'y'}, ...
    'RequireOutputs', true);

c.name = 'Generic verification remains backward compatible without contracts';
c.passed = r.passed && r.checks.control_feedback_polarity;
c.detail = sprintf('status=%s control_feedback_polarity=%d', ...
    r.status, r.checks.control_feedback_polarity);
end

function c = case_negative_feedback_passes(projectRoot, modelName, contract, reportDir)
r = verify_power_system_model(modelName, ...
    'ProjectRoot', projectRoot, ...
    'StopTime', 0.5, ...
    'ReportPath', fullfile(reportDir, [modelName '_contract.md']), ...
    'RequiredSignals', {'y'}, ...
    'RequireOutputs', true, ...
    'ControlFeedbackContracts', contract);

c.name = 'Declared negative feedback passes the contract gate';
c.passed = r.passed && r.checks.control_feedback_polarity ...
    && r.metrics.control_feedback_mismatch_count == 0;
c.detail = sprintf('status=%s mismatches=%d', ...
    r.status, r.metrics.control_feedback_mismatch_count);
end

function c = case_positive_feedback_mismatch(projectRoot, modelName, contract, reportDir)
% Validates MISMATCH classification explicitly, plus failed_count and
% classification_counts aggregates.
reportPath = fullfile(reportDir, [modelName '_mismatch.md']);
r = verify_control_feedback_polarity(modelName, contract, ...
    'ProjectRoot', projectRoot, ...
    'ReportPath', reportPath);

c.name = 'Positive feedback wiring classified as MISMATCH (with aggregates)';
c.passed = ~r.passed ...
    && r.mismatch_count == 1 ...
    && r.failed_count == 1 ...
    && r.classification_counts.MISMATCH == 1 ...
    && r.classification_counts.PASS == 0 ...
    && strcmp(r.contracts(1).classification, 'MISMATCH');
c.detail = sprintf('classification=%s mismatch=%d failed=%d cc.MISMATCH=%d', ...
    r.contracts(1).classification, r.mismatch_count, r.failed_count, ...
    r.classification_counts.MISMATCH);
end

function c = case_positive_feedback_autofix_fixed(projectRoot, modelName, contract, reportDir)
% Validates that AutoFix produces FIXED classification
reportPath = fullfile(reportDir, [modelName '_autofix.md']);
r = verify_control_feedback_polarity(modelName, contract, ...
    'ProjectRoot', projectRoot, ...
    'ReportPath', reportPath, ...
    'AutoFix', true, ...
    'SaveOnFix', true);

load_system(modelName);
inputsAfterFix = char(get_param([modelName '/Sum'], 'Inputs'));
close_system(modelName, 0);

c.name = 'AutoFix rewrites positive feedback and classifies as FIXED';
c.passed = r.passed ...
    && r.fixed_count == 1 ...
    && strcmp(r.contracts(1).classification, 'FIXED') ...
    && strcmp(inputsAfterFix, '+-');
c.detail = sprintf('classification=%s fixed_count=%d inputs_after=%s', ...
    r.contracts(1).classification, r.fixed_count, inputsAfterFix);
end

function c = case_missing_block_contract(projectRoot, modelName, reportDir)
% Contract references a block that does not exist in the model
missingContract = struct('block_path', 'NonexistentBlock/Sum', ...
    'expected_inputs', '+-', ...
    'description', 'references a block that does not exist');

reportPath = fullfile(reportDir, [modelName '_missing_block.md']);
r = verify_control_feedback_polarity(modelName, missingContract, ...
    'ProjectRoot', projectRoot, ...
    'ReportPath', reportPath);

c.name = 'Missing block contract classified as MISSING_BLOCK';
c.passed = ~r.passed ...
    && strcmp(r.contracts(1).classification, 'MISSING_BLOCK');
c.detail = sprintf('classification=%s message=%s', ...
    r.contracts(1).classification, r.contracts(1).message);
end

function c = case_non_sum_block_contract(projectRoot, modelName, reportDir)
% Contract references a block that exists but is not a Sum block
nonSumContract = struct('block_path', 'K_gain', ...
    'expected_inputs', '+-', ...
    'description', 'references a Gain block, not Sum');

reportPath = fullfile(reportDir, [modelName '_not_sum.md']);
r = verify_control_feedback_polarity(modelName, nonSumContract, ...
    'ProjectRoot', projectRoot, ...
    'ReportPath', reportPath);

c.name = 'Non-Sum block contract classified as NOT_SUM_BLOCK';
c.passed = ~r.passed ...
    && strcmp(r.contracts(1).classification, 'NOT_SUM_BLOCK');
c.detail = sprintf('classification=%s message=%s', ...
    r.contracts(1).classification, r.contracts(1).message);
end

function c = case_bad_contract_empty_fields(projectRoot, modelName, reportDir)
% Contract with empty block_path
badContract = struct('block_path', '', ...
    'expected_inputs', '+-', ...
    'description', 'empty block_path');

reportPath = fullfile(reportDir, [modelName '_bad_contract_empty.md']);
r = verify_control_feedback_polarity(modelName, badContract, ...
    'ProjectRoot', projectRoot, ...
    'ReportPath', reportPath);

c.name = 'Empty block_path contract classified as BAD_CONTRACT';
c.passed = ~r.passed ...
    && strcmp(r.contracts(1).classification, 'BAD_CONTRACT');
c.detail = sprintf('classification=%s', r.contracts(1).classification);
end

function c = case_bad_contract_missing_expected(projectRoot, modelName, reportDir)
% Contract with empty expected_inputs
badContract = struct('block_path', 'Sum', ...
    'expected_inputs', '', ...
    'description', 'empty expected_inputs');

reportPath = fullfile(reportDir, [modelName '_bad_contract_noexpected.md']);
r = verify_control_feedback_polarity(modelName, badContract, ...
    'ProjectRoot', projectRoot, ...
    'ReportPath', reportPath);

c.name = 'Empty expected_inputs contract classified as BAD_CONTRACT';
c.passed = ~r.passed ...
    && strcmp(r.contracts(1).classification, 'BAD_CONTRACT');
c.detail = sprintf('classification=%s', r.contracts(1).classification);
end

function c = case_json_report_generated(projectRoot, modelName, contract, reportDir)
% Verify JSON report is generated alongside Markdown
mdPath = fullfile(reportDir, [modelName '_json_test.md']);
jsonPath = fullfile(reportDir, [modelName '_json_test.json']);
if isfile(jsonPath); delete(jsonPath); end

r = verify_control_feedback_polarity(modelName, contract, ...
    'ProjectRoot', projectRoot, ...
    'ReportPath', mdPath);

jsonExists = isfile(jsonPath);
jsonValid = false;
if jsonExists
    try
        txt = fileread(jsonPath);
        data = jsondecode(txt);
        jsonValid = isfield(data, 'status') && isfield(data, 'contracts') ...
            && isfield(data.contracts, 'classification') ...
            && isfield(data, 'failed_count') ...
            && isfield(data, 'classification_counts');
    catch
        jsonValid = false;
    end
end

c.name = 'JSON report generated alongside Markdown with correct schema';
c.passed = jsonExists && jsonValid && r.passed;
c.detail = sprintf('json_exists=%d json_valid=%d json_path=%s', ...
    jsonExists, jsonValid, jsonPath);
end

function c = case_integration_aggregates_via_model_gate(projectRoot, modelName, reportDir)
% Verify that verify_power_system_model exposes top-level aggregate fields
% (failed_count, classification_counts, json_report) when a bad contract
% is supplied through ControlFeedbackContracts. Also assert the rendered
% Markdown report includes the feedback JSON path, not "(omitted)".
badContract = struct('block_path', 'NonexistentBlock/Sum', ...
    'expected_inputs', '+-', ...
    'description', 'integration test missing block');

jsonPath = fullfile(reportDir, [modelName '_integration_feedback.json']);
mdPath = fullfile(reportDir, [modelName '_integration.md']);
r = verify_power_system_model(modelName, ...
    'ProjectRoot', projectRoot, ...
    'StopTime', 0.5, ...
    'ReportPath', mdPath, ...
    'RequiredSignals', {'y'}, ...
    'RequireOutputs', true, ...
    'ControlFeedbackContracts', badContract, ...
    'ControlFeedbackJsonPath', jsonPath);

hasFailedCount = isfield(r.metrics, 'control_feedback_failed_count') ...
    && r.metrics.control_feedback_failed_count == 1;
hasCounts = isfield(r.metrics, 'control_feedback_classification_counts') ...
    && isstruct(r.metrics.control_feedback_classification_counts) ...
    && r.metrics.control_feedback_classification_counts.MISSING_BLOCK == 1;
hasJson = isfield(r.metrics, 'control_feedback_json_report') ...
    && isfile(r.metrics.control_feedback_json_report);
overallFailed = ~r.passed && ~r.checks.control_feedback_polarity;

% The Markdown report must include the JSON path, not "(omitted)".
mdTxt = '';
if isfile(mdPath)
    mdTxt = fileread(mdPath);
end
jsonPathStr = char(r.metrics.control_feedback_json_report);
mdHasJsonPath = ~isempty(mdTxt) && contains(mdTxt, jsonPathStr);
mdDoesNotOmitJson = ~isempty(mdTxt) && ~contains(mdTxt, 'control_feedback_json_report: (omitted)');

c.name = 'verify_power_system_model exposes feedback aggregates and renders JSON path';
c.passed = hasFailedCount && hasCounts && hasJson && overallFailed ...
    && mdHasJsonPath && mdDoesNotOmitJson;
c.detail = sprintf('failed_count=%d cc.MISSING_BLOCK=%d json_exists=%d md_has_path=%d md_no_omit=%d', ...
    r.metrics.control_feedback_failed_count, ...
    r.metrics.control_feedback_classification_counts.MISSING_BLOCK, ...
    hasJson, mdHasJsonPath, mdDoesNotOmitJson);
end

%% Model builders

function build_feedback_model(modelName, sumInputs, modelDir)
if bdIsLoaded(modelName); close_system(modelName, 0); end
new_system(modelName);
set_param(modelName, 'StopTime', '3', 'Solver', 'ode45');

add_block('simulink/Sources/Constant', [modelName '/r'], ...
    'Value', '1', 'Position', [40 70 70 100]);
add_block('simulink/Math Operations/Sum', [modelName '/Sum'], ...
    'Inputs', sumInputs, 'Position', [120 65 145 105]);
add_block('simulink/Continuous/Transfer Fcn', [modelName '/Plant'], ...
    'Numerator', '[1]', 'Denominator', '[1 1]', 'Position', [200 65 280 105]);
add_block('simulink/Math Operations/Gain', [modelName '/K_feedback'], ...
    'Gain', '2', 'Position', [205 155 275 185]);
add_block('simulink/Sinks/To Workspace', [modelName '/ToWorkspace_y'], ...
    'VariableName', 'y', 'SaveFormat', 'Timeseries', 'Position', [345 68 430 102]);

add_line(modelName, 'r/1', 'Sum/1', 'autorouting', 'on');
add_line(modelName, 'Sum/1', 'Plant/1', 'autorouting', 'on');
add_line(modelName, 'Plant/1', 'ToWorkspace_y/1', 'autorouting', 'on');
add_line(modelName, 'Plant/1', 'K_feedback/1', 'autorouting', 'on');
add_line(modelName, 'K_feedback/1', 'Sum/2', 'autorouting', 'on');

save_system(modelName, fullfile(modelDir, [modelName '.slx']));
close_system(modelName, 0);
end

function build_gain_model(modelName, modelDir)
% Minimal model with a Gain block named K_gain for NOT_SUM_BLOCK test
if bdIsLoaded(modelName); close_system(modelName, 0); end
new_system(modelName);
set_param(modelName, 'StopTime', '1', 'Solver', 'ode45');

add_block('simulink/Sources/Constant', [modelName '/r'], ...
    'Value', '1', 'Position', [40 70 70 100]);
add_block('simulink/Math Operations/Gain', [modelName '/K_gain'], ...
    'Gain', '2', 'Position', [120 65 180 105]);
add_block('simulink/Sinks/To Workspace', [modelName '/ToWorkspace_y'], ...
    'VariableName', 'y', 'SaveFormat', 'Timeseries', 'Position', [240 68 325 102]);

add_line(modelName, 'r/1', 'K_gain/1', 'autorouting', 'on');
add_line(modelName, 'K_gain/1', 'ToWorkspace_y/1', 'autorouting', 'on');

save_system(modelName, fullfile(modelDir, [modelName '.slx']));
close_system(modelName, 0);
end

%% Utility

function checks = add_check(checks, c)
if isempty(checks)
    checks = c;
else
    checks(end+1) = c;
end
end

function t = tag(passed)
if passed; t = 'PASS'; else; t = 'FAIL'; end
end
