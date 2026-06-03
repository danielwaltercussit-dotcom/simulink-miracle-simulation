function result = verify_power_system_model(modelName, varargin)
%VERIFY_POWER_SYSTEM_MODEL Reusable verification gate for derived SPS models.
%   Runs compile, smoke simulation, logged-output finite checks, light layout
%   checks, and self-containment checks. It intentionally avoids editing the
%   model. Use ai_in_loop_run for repair/tuning loops.

p = inputParser;
p.addParameter('ProjectRoot', default_project_root(), @(x) ischar(x) || isstring(x));
p.addParameter('StopTime', 0.005, @isnumeric);
p.addParameter('ReportPath', '', @(x) ischar(x) || isstring(x));
p.addParameter('RequireOutputs', true, @(x) islogical(x) || isnumeric(x));
p.addParameter('RequiredSignals', {}, @(x) iscell(x) || isstring(x));
p.addParameter('CheckRootOverlap', true, @(x) islogical(x) || isnumeric(x));
p.parse(varargin{:});
opt = p.Results;
opt.ProjectRoot = char(opt.ProjectRoot);
opt.RequireOutputs = logical(opt.RequireOutputs);
opt.CheckRootOverlap = logical(opt.CheckRootOverlap);
if isstring(opt.RequiredSignals)
    opt.RequiredSignals = cellstr(opt.RequiredSignals);
end

modelName = char(modelName);
result = struct();
result.name = 'POWER_SYSTEM_MODEL_VERIFICATION';
result.model = modelName;
result.status = 'FAIL';
result.passed = false;
result.stop_time = opt.StopTime;
result.checks = struct();
result.metrics = struct();
result.message = '';
result.report_path = char(opt.ReportPath);

try
    load_model_if_needed(opt.ProjectRoot, modelName);

    set_param(modelName, 'SimulationCommand', 'update');
    result.checks.update = true;

    result.checks.self_contained_init = has_self_contained_init(modelName);

    if opt.CheckRootOverlap && exist('ai_in_loop_count_overlap', 'file') == 2
        rootBlocks = find_system(modelName, 'SearchDepth', 1, ...
            'LookUnderMasks', 'none', 'FollowLinks', 'off', 'Type', 'Block');
        result.metrics.root_block_count = numel(rootBlocks);
        result.metrics.root_overlap = ai_in_loop_count_overlap(rootBlocks);
        result.checks.root_overlap_free = result.metrics.root_overlap == 0;
    else
        result.checks.root_overlap_free = true;
    end

    out = sim(modelName, 'StopTime', num2str(opt.StopTime), ...
        'ReturnWorkspaceOutputs', 'on');
    result.checks.sim_completed = true;

    names = out.who;
    result.metrics.output_names = names;
    result.checks.has_outputs = ~isempty(names);
    result.checks.required_signals_present = all(ismember(opt.RequiredSignals, names));
    result.checks.finite_outputs = true;
    result.metrics.nan_count = 0;
    result.metrics.inf_count = 0;

    for k = 1:numel(names)
        v = out.(names{k});
        vals = extract_signal_values(v);
        if ~isempty(vals) && isnumeric(vals)
            result.metrics.nan_count = result.metrics.nan_count + sum(isnan(vals), 'all');
            result.metrics.inf_count = result.metrics.inf_count + sum(isinf(vals), 'all');
            if any(~isfinite(vals), 'all')
                result.checks.finite_outputs = false;
            end
        end
    end

    result.passed = result.checks.update ...
        && result.checks.sim_completed ...
        && (~opt.RequireOutputs || result.checks.has_outputs) ...
        && result.checks.required_signals_present ...
        && result.checks.finite_outputs ...
        && result.checks.root_overlap_free;

    if result.passed
        result.status = 'PASS';
        result.message = 'PASS';
    else
        result.message = build_failure_message(result);
    end
catch ME
    result.message = ME.message;
    result.error_id = ME.identifier;
end

if strlength(string(opt.ReportPath)) > 0
    write_verification_report(char(opt.ReportPath), result);
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

function tf = has_self_contained_init(modelName)
initFcn = get_param(modelName, 'InitFcn');
tf = contains(initFcn, 'Ts') || contains(initFcn, 'Tsample') || ~isempty(strtrim(initFcn));
end

function vals = extract_signal_values(v)
vals = [];
if isnumeric(v)
    vals = v;
elseif isa(v, 'timeseries')
    vals = v.Data;
elseif isstruct(v) && isfield(v, 'signals') && isfield(v.signals, 'values')
    vals = v.signals.values;
end
end

function msg = build_failure_message(result)
failed = {};
names = fieldnames(result.checks);
for k = 1:numel(names)
    value = result.checks.(names{k});
    if islogical(value) && isscalar(value) && ~value
        failed{end+1} = names{k}; %#ok<AGROW>
    end
end
if isempty(failed)
    msg = 'Verification failed without a false scalar check; inspect metrics.';
else
    msg = ['Failed checks: ' strjoin(failed, ', ')];
end
end

function write_verification_report(path, result)
reportDir = fileparts(path);
if ~isempty(reportDir) && ~isfolder(reportDir)
    mkdir(reportDir);
end
fid = fopen(path, 'w');
if fid < 0
    warning('VerifyPowerSystemModel:CannotWriteReport', 'Cannot write %s', path);
    return
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Model Verification Summary\n\n');
fprintf(fid, '- model: `%s`\n', result.model);
fprintf(fid, '- status: `%s`\n', result.status);
fprintf(fid, '- stop_time: %.6g\n', result.stop_time);
fprintf(fid, '- message: %s\n\n', result.message);

fprintf(fid, '## Checks\n\n');
names = fieldnames(result.checks);
for k = 1:numel(names)
    fprintf(fid, '- %s: `%s`\n', names{k}, mat2str(result.checks.(names{k})));
end

fprintf(fid, '\n## Metrics\n\n');
metricNames = fieldnames(result.metrics);
for k = 1:numel(metricNames)
    value = result.metrics.(metricNames{k});
    if isnumeric(value) && isscalar(value)
        fprintf(fid, '- %s: %.6g\n', metricNames{k}, value);
    elseif iscell(value)
        fprintf(fid, '- %s: `%s`\n', metricNames{k}, strjoin(value, ', '));
    else
        fprintf(fid, '- %s: (omitted)\n', metricNames{k});
    end
end
end
