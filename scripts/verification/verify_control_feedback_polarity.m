function result = verify_control_feedback_polarity(modelName, contracts, varargin)
%VERIFY_CONTROL_FEEDBACK_POLARITY Verify declared feedback signs on Sum blocks.
%   result = verify_control_feedback_polarity(modelName, contracts) checks each
%   contract against the model. Contracts are structs with:
%     block_path      full model path or path relative to the model root
%     expected_inputs expected Sum block Inputs string, e.g. '+-'
%     description     optional human-readable context
%
%   Per-contract classification codes:
%     PASS          - block exists, is Sum, Inputs match expected
%     MISMATCH      - block exists, is Sum, Inputs differ from expected
%     FIXED         - was MISMATCH, AutoFix corrected it successfully
%     BAD_CONTRACT  - contract missing required fields (block_path or expected_inputs)
%     MISSING_BLOCK - block_path does not resolve to a block in the model
%     NOT_SUM_BLOCK - block exists but is not a Sum block
%     ERROR         - unexpected error during check (see error_id/message)
%
%   The helper is intentionally contract-driven. It cannot infer every control
%   loop's intended sign, but it can reliably catch registered sign regressions.

p = inputParser;
p.addParameter('ProjectRoot', default_project_root(), @(x) ischar(x) || isstring(x));
p.addParameter('ReportPath', '', @(x) ischar(x) || isstring(x));
p.addParameter('ReportJsonPath', '', @(x) ischar(x) || isstring(x));
p.addParameter('AutoFix', false, @(x) islogical(x) || isnumeric(x));
p.addParameter('SaveOnFix', true, @(x) islogical(x) || isnumeric(x));
p.parse(varargin{:});
opt = p.Results;
opt.ProjectRoot = char(opt.ProjectRoot);
opt.ReportPath = char(opt.ReportPath);
opt.ReportJsonPath = char(opt.ReportJsonPath);
opt.AutoFix = logical(opt.AutoFix);
opt.SaveOnFix = logical(opt.SaveOnFix);

modelName = char(modelName);
contracts = normalize_contracts(contracts);

result = struct();
result.name = 'CONTROL_FEEDBACK_POLARITY';
result.model = modelName;
result.status = 'FAIL';
result.passed = false;
result.contract_count = numel(contracts);
result.mismatch_count = 0;
result.fixed_count = 0;
result.failed_count = 0;
result.classification_counts = empty_classification_counts();
result.message = '';
result.checks = struct('contracts_declared', numel(contracts) > 0, ...
    'all_feedback_polarity_ok', false);
result.contracts = repmat(empty_contract_result(), 1, numel(contracts));
result.report_path = opt.ReportPath;
result.report_json_path = opt.ReportJsonPath;

try
    load_model_if_needed(opt.ProjectRoot, modelName);

    for k = 1:numel(contracts)
        result.contracts(k) = check_one_contract(modelName, contracts(k), opt.AutoFix);
        cls = result.contracts(k).classification;
        if isfield(result.classification_counts, cls)
            result.classification_counts.(cls) = result.classification_counts.(cls) + 1;
        end
        if strcmp(cls, 'MISMATCH')
            result.mismatch_count = result.mismatch_count + 1;
        end
        if strcmp(cls, 'FIXED')
            result.fixed_count = result.fixed_count + 1;
        end
        if ~result.contracts(k).passed
            result.failed_count = result.failed_count + 1;
        end
    end

    if opt.AutoFix && opt.SaveOnFix && result.fixed_count > 0
        save_system(modelName);
    end

    result.checks.all_feedback_polarity_ok = all([result.contracts.passed]);
    result.passed = result.checks.contracts_declared ...
        && result.checks.all_feedback_polarity_ok;

    if result.passed
        result.status = 'PASS';
        if result.fixed_count > 0
            result.message = sprintf('PASS after fixing %d feedback sign contract(s).', result.fixed_count);
        else
            result.message = 'PASS';
        end
    else
        result.message = sprintf('Failed feedback sign contracts: %d of %d (%s).', ...
            result.failed_count, result.contract_count, ...
            format_classification_counts(result.classification_counts));
    end
catch ME
    result.message = ME.message;
    result.error_id = ME.identifier;
end

if strlength(string(opt.ReportPath)) > 0
    write_feedback_report(opt.ReportPath, result);
end

% Derive JSON path from ReportPath if not explicitly given
jsonPath = opt.ReportJsonPath;
if isempty(jsonPath) && strlength(string(opt.ReportPath)) > 0
    [rDir, rBase] = fileparts(opt.ReportPath);
    jsonPath = fullfile(rDir, [rBase '.json']);
end
if strlength(string(jsonPath)) > 0
    write_feedback_json(jsonPath, result);
    result.report_json_path = jsonPath;
end
end

function contracts = normalize_contracts(contracts)
if isempty(contracts)
    contracts = struct('block_path', {}, 'expected_inputs', {}, 'description', {});
    return
end
if isstruct(contracts)
    return
end
error('FeedbackPolarity:BadContracts', 'Contracts must be a struct array.');
end

function r = check_one_contract(modelName, contract, autoFix)
r = empty_contract_result();
r.block_path = resolve_block_path(modelName, get_contract_field(contract, 'block_path', ''));
r.expected_inputs = char(get_contract_field(contract, 'expected_inputs', ''));
r.description = char(get_contract_field(contract, 'description', ''));

% BAD_CONTRACT: missing required fields
if isempty(r.block_path) || isempty(r.expected_inputs)
    r.classification = 'BAD_CONTRACT';
    r.message = 'Contract must include block_path and expected_inputs.';
    return
end

try
    % MISSING_BLOCK: block does not exist
    try
        blockType = get_param(r.block_path, 'BlockType');
    catch blockME
        % Catch block-not-found errors regardless of locale.
        % Common identifiers: Simulink:Commands:InvSimulinkObjHandle,
        % Simulink:Commands:ParamUnknown, Simulink:Engine:InvParamSetting
        r.classification = 'MISSING_BLOCK';
        r.message = sprintf('Block not found: %s', r.block_path);
        r.error_id = blockME.identifier;
        return
    end

    % NOT_SUM_BLOCK: block exists but wrong type
    if ~strcmp(blockType, 'Sum')
        r.classification = 'NOT_SUM_BLOCK';
        r.message = sprintf('Block is %s, expected Sum.', blockType);
        return
    end

    r.actual_inputs = char(get_param(r.block_path, 'Inputs'));
    r.passed = strcmp(r.actual_inputs, r.expected_inputs);
    if r.passed
        r.classification = 'PASS';
        r.message = 'PASS';
        return
    end

    % MISMATCH or FIXED
    r.message = sprintf('Inputs are %s, expected %s.', r.actual_inputs, r.expected_inputs);
    r.classification = 'MISMATCH';
    if autoFix
        set_param(r.block_path, 'Inputs', r.expected_inputs);
        r.actual_inputs_after_fix = char(get_param(r.block_path, 'Inputs'));
        r.fixed = strcmp(r.actual_inputs_after_fix, r.expected_inputs);
        r.passed = r.fixed;
        if r.fixed
            r.classification = 'FIXED';
            r.message = sprintf('Fixed Inputs from %s to %s.', ...
                r.actual_inputs, r.actual_inputs_after_fix);
        end
    end
catch ME
    r.classification = 'ERROR';
    r.message = ME.message;
    r.error_id = ME.identifier;
end
end

function value = get_contract_field(contract, fieldName, defaultValue)
if isfield(contract, fieldName)
    value = contract.(fieldName);
else
    value = defaultValue;
end
end

function blockPath = resolve_block_path(modelName, blockPath)
blockPath = char(blockPath);
if isempty(blockPath)
    return
end
prefix = [char(modelName) '/'];
if strcmp(blockPath, modelName) || startsWith(blockPath, prefix)
    return
end
blockPath = [char(modelName) '/' blockPath];
end

function r = empty_contract_result()
r = struct('block_path', '', ...
    'description', '', ...
    'expected_inputs', '', ...
    'actual_inputs', '', ...
    'actual_inputs_after_fix', '', ...
    'passed', false, ...
    'fixed', false, ...
    'classification', '', ...
    'message', '', ...
    'error_id', '');
end

function counts = empty_classification_counts()
counts = struct( ...
    'PASS', 0, ...
    'MISMATCH', 0, ...
    'FIXED', 0, ...
    'BAD_CONTRACT', 0, ...
    'MISSING_BLOCK', 0, ...
    'NOT_SUM_BLOCK', 0, ...
    'ERROR', 0);
end

function s = format_classification_counts(counts)
% Compact summary, only including non-zero entries.
keys = fieldnames(counts);
parts = {};
for k = 1:numel(keys)
    v = counts.(keys{k});
    if v > 0
        parts{end+1} = sprintf('%s=%d', keys{k}, v); %#ok<AGROW>
    end
end
if isempty(parts)
    s = 'no classifications';
else
    s = strjoin(parts, ', ');
end
end

function root = default_project_root()
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
end

function load_model_if_needed(projectRoot, modelName)
if bdIsLoaded(modelName)
    return
end
candidate = fullfile(projectRoot, 'build', 'generated_models', [modelName '.slx']);
if isfile(candidate)
    load_system(candidate);
else
    load_system(modelName);
end
end

function write_feedback_report(path, result)
reportDir = fileparts(path);
if ~isempty(reportDir) && ~isfolder(reportDir)
    mkdir(reportDir);
end
fid = fopen(path, 'w');
if fid < 0
    warning('FeedbackPolarity:CannotWriteReport', 'Cannot write %s', path);
    return
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# Control Feedback Polarity Summary\n\n');
fprintf(fid, '- model: `%s`\n', result.model);
fprintf(fid, '- status: `%s`\n', result.status);
fprintf(fid, '- message: %s\n', result.message);
fprintf(fid, '- contract_count: %d\n', result.contract_count);
fprintf(fid, '- failed_count: %d\n', result.failed_count);
fprintf(fid, '- mismatch_count: %d\n', result.mismatch_count);
fprintf(fid, '- fixed_count: %d\n', result.fixed_count);
fprintf(fid, '- classification_counts: %s\n\n', ...
    format_classification_counts(result.classification_counts));

fprintf(fid, '| block | expected | actual | after fix | classification | message | description |\n');
fprintf(fid, '|---|---|---|---|---|---|---|\n');
for k = 1:numel(result.contracts)
    c = result.contracts(k);
    fprintf(fid, '| `%s` | `%s` | `%s` | `%s` | %s | %s | %s |\n', ...
        c.block_path, c.expected_inputs, c.actual_inputs, ...
        c.actual_inputs_after_fix, c.classification, c.message, c.description);
end
end

function write_feedback_json(jsonPath, result)
reportDir = fileparts(jsonPath);
if ~isempty(reportDir) && ~isfolder(reportDir)
    mkdir(reportDir);
end
fid = fopen(jsonPath, 'w');
if fid < 0
    warning('FeedbackPolarity:CannotWriteJson', 'Cannot write %s', jsonPath);
    return
end
cleanup = onCleanup(@() fclose(fid));

% Build JSON manually for MATLAB compatibility (no jsonencode in older releases)
fprintf(fid, '{\n');
fprintf(fid, '  "name": "%s",\n', result.name);
fprintf(fid, '  "model": "%s",\n', json_escape(result.model));
fprintf(fid, '  "status": "%s",\n', result.status);
fprintf(fid, '  "passed": %s,\n', bool_str(result.passed));
fprintf(fid, '  "message": "%s",\n', json_escape(result.message));
fprintf(fid, '  "contract_count": %d,\n', result.contract_count);
fprintf(fid, '  "failed_count": %d,\n', result.failed_count);
fprintf(fid, '  "mismatch_count": %d,\n', result.mismatch_count);
fprintf(fid, '  "fixed_count": %d,\n', result.fixed_count);
fprintf(fid, '  "classification_counts": {\n');
ccKeys = fieldnames(result.classification_counts);
for kk = 1:numel(ccKeys)
    sep = ',';
    if kk == numel(ccKeys); sep = ''; end
    fprintf(fid, '    "%s": %d%s\n', ccKeys{kk}, ...
        result.classification_counts.(ccKeys{kk}), sep);
end
fprintf(fid, '  },\n');
fprintf(fid, '  "contracts": [\n');
for k = 1:numel(result.contracts)
    c = result.contracts(k);
    fprintf(fid, '    {\n');
    fprintf(fid, '      "block_path": "%s",\n', json_escape(c.block_path));
    fprintf(fid, '      "expected_inputs": "%s",\n', json_escape(c.expected_inputs));
    fprintf(fid, '      "actual_inputs": "%s",\n', json_escape(c.actual_inputs));
    fprintf(fid, '      "actual_inputs_after_fix": "%s",\n', json_escape(c.actual_inputs_after_fix));
    fprintf(fid, '      "passed": %s,\n', bool_str(c.passed));
    fprintf(fid, '      "fixed": %s,\n', bool_str(c.fixed));
    fprintf(fid, '      "classification": "%s",\n', json_escape(c.classification));
    fprintf(fid, '      "message": "%s",\n', json_escape(c.message));
    fprintf(fid, '      "description": "%s"\n', json_escape(c.description));
    if k < numel(result.contracts)
        fprintf(fid, '    },\n');
    else
        fprintf(fid, '    }\n');
    end
end
fprintf(fid, '  ]\n');
fprintf(fid, '}\n');
end

function s = json_escape(str)
s = strrep(char(str), '\', '\\');
s = strrep(s, '"', '\"');
s = strrep(s, newline, '\n');
s = strrep(s, char(13), '');
end

function s = bool_str(tf)
if tf; s = 'true'; else; s = 'false'; end
end
