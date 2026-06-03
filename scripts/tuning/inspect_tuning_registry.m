function result = inspect_tuning_registry(modelName, varargin)
%INSPECT_TUNING_REGISTRY Validate and report ai-in-loop tuning knobs.

p = inputParser;
p.addParameter('ProjectRoot', default_project_root(), @(x) ischar(x) || isstring(x));
p.addParameter('ReportPath', '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opt = p.Results;

modelName = char(modelName);
projectRoot = char(opt.ProjectRoot);
result = struct('name','TUNING_REGISTRY_INSPECTION', 'model', modelName, ...
    'status','FAIL', 'passed', false, 'knob_count', 0, 'checks', struct(), ...
    'knobs', repmat(empty_knob(), 1, 0), 'message', '', 'report_path', char(opt.ReportPath));

try
    addpath(fullfile(projectRoot, 'scripts', 'loop'));
    load_model_if_needed(projectRoot, modelName);
    reg = tuning_registry(modelName);
    result.knob_count = numel(reg);
    result.checks.has_knobs = ~isempty(reg);
    result.checks.ids_unique = numel(unique({reg.id})) == numel(reg);
    result.checks.paths_exist = true;
    result.checks.bounds_valid = true;
    result.checks.fs_targets_present = true;
    if ~isempty(reg)
        result.knobs = repmat(empty_knob(), 1, numel(reg));
    end

    for k = 1:numel(reg)
        knob = struct();
        knob.id = reg(k).id;
        knob.block_path = reg(k).block_path;
        knob.mask_param = reg(k).mask_param;
        knob.current = reg(k).current;
        knob.min = reg(k).min;
        knob.max = reg(k).max;
        knob.units = reg(k).units;
        knob.fs_targets = reg(k).fs_targets;
        knob.path_exists = getSimulinkBlockHandle(reg(k).block_path) ~= -1;
        knob.bounds_valid = isnumeric(reg(k).min) && isnumeric(reg(k).max) ...
            && isequal(size(reg(k).min), size(reg(k).max)) ...
            && all(reg(k).min < reg(k).max);
        knob.fs_targets_present = iscell(reg(k).fs_targets) && ~isempty(reg(k).fs_targets);
        result.knobs(k) = knob;
        result.checks.paths_exist = result.checks.paths_exist && knob.path_exists;
        result.checks.bounds_valid = result.checks.bounds_valid && knob.bounds_valid;
        result.checks.fs_targets_present = result.checks.fs_targets_present && knob.fs_targets_present;
    end

    result.passed = all_boolean_checks(result.checks);
    if result.passed
        result.status = 'PASS';
        result.message = 'PASS';
    else
        result.message = build_failure_message(result.checks);
    end
catch ME
    result.message = ME.message;
    result.error_id = ME.identifier;
end

function knob = empty_knob()
knob = struct('id','', 'block_path','', 'mask_param','', 'current', NaN, ...
    'min', [], 'max', [], 'units','', 'fs_targets', {{}}, ...
    'path_exists', false, 'bounds_valid', false, 'fs_targets_present', false);
end

if strlength(string(opt.ReportPath)) > 0
    write_registry_report(char(opt.ReportPath), result);
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

function tf = all_boolean_checks(checks)
tf = true;
names = fieldnames(checks);
for k = 1:numel(names)
    value = checks.(names{k});
    if islogical(value) && isscalar(value)
        tf = tf && value;
    end
end
end

function msg = build_failure_message(checks)
failed = {};
names = fieldnames(checks);
for k = 1:numel(names)
    value = checks.(names{k});
    if islogical(value) && isscalar(value) && ~value
        failed{end+1} = names{k}; %#ok<AGROW>
    end
end
msg = ['Failed checks: ' strjoin(failed, ', ')];
end

function write_registry_report(path, result)
reportDir = fileparts(path);
if ~isempty(reportDir) && ~isfolder(reportDir)
    mkdir(reportDir);
end
fid = fopen(path, 'w');
if fid < 0
    warning('InspectTuningRegistry:CannotWriteReport', 'Cannot write %s', path);
    return
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Tuning Registry Inspection\n\n');
fprintf(fid, '- model: `%s`\n', result.model);
fprintf(fid, '- status: `%s`\n', result.status);
fprintf(fid, '- knobs: %d\n', result.knob_count);
fprintf(fid, '- message: %s\n\n', result.message);

fprintf(fid, '## Checks\n\n');
names = fieldnames(result.checks);
for k = 1:numel(names)
    fprintf(fid, '- %s: `%s`\n', names{k}, mat2str(result.checks.(names{k})));
end

fprintf(fid, '\n## Knobs\n\n');
for k = 1:numel(result.knobs)
    knob = result.knobs(k);
    fprintf(fid, '### %s\n\n', knob.id);
    fprintf(fid, '- block: `%s`\n', knob.block_path);
    fprintf(fid, '- mask_param: `%s`\n', knob.mask_param);
    fprintf(fid, '- units: `%s`\n', knob.units);
    fprintf(fid, '- fs_targets: `%s`\n', strjoin(knob.fs_targets, ', '));
    fprintf(fid, '- path_exists: `%s`\n', mat2str(knob.path_exists));
    fprintf(fid, '- bounds_valid: `%s`\n\n', mat2str(knob.bounds_valid));
end
end
