function result = audit_model_quality_layout(modelName, varargin)
%AUDIT_MODEL_QUALITY_LAYOUT Audit derived Simulink model layout quality.
%   Lightweight S3 gate for root overlap, Goto/From policy, logging surface,
%   encapsulation metrics, and oracle/reference hygiene.

p = inputParser;
p.addParameter('ProjectRoot', default_project_root(), @(x) ischar(x) || isstring(x));
p.addParameter('ReportPath', '', @(x) ischar(x) || isstring(x));
p.addParameter('LabReferenceRoot', default_lab_reference_root(), @(x) ischar(x) || isstring(x));
p.addParameter('MaxRootBlocks', 80, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('MinSubsystemRatio', 0.20, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.parse(varargin{:});
opt = p.Results;
opt.ProjectRoot = char(opt.ProjectRoot);
opt.ReportPath = char(opt.ReportPath);
opt.LabReferenceRoot = char(opt.LabReferenceRoot);

modelName = char(modelName);
result = struct('name','MODEL_QUALITY_LAYOUT_AUDIT', ...
    'model', modelName, 'status','FAIL', 'passed', false, ...
    'checks', struct(), 'metrics', struct(), ...
    'warnings', {{}}, 'violations', repmat(empty_violation(), 1, 0), ...
    'message','', 'report_path', opt.ReportPath);

try
    load_model_if_needed(opt.ProjectRoot, modelName);

    rootBlocks = find_system(modelName, 'SearchDepth', 1, ...
        'LookUnderMasks', 'none', 'FollowLinks', 'off', 'Type', 'Block');
    allBlocks = find_system(modelName, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'off', 'Type', 'Block');

    result.metrics.root_block_count = numel(rootBlocks);
    result.metrics.total_block_count = numel(allBlocks);
    result.metrics.root_subsystem_count = count_block_type(rootBlocks, 'SubSystem');
    result.metrics.root_goto_count = count_block_type(rootBlocks, 'Goto');
    result.metrics.root_from_count = count_block_type(rootBlocks, 'From');
    result.metrics.to_workspace_count = count_block_type(allBlocks, 'ToWorkspace');
    result.metrics.root_outport_count = count_block_type(rootBlocks, 'Outport');
    result.metrics.max_hierarchy_depth = max_hierarchy_depth(allBlocks, modelName);
    result.metrics.subsystem_ratio = ratio(result.metrics.root_subsystem_count, ...
        max(result.metrics.root_block_count, 1));

    overlap = run_overlap_scan(modelName);
    result.metrics.root_overlap = overlap.nOverlaps;
    result.checks.root_overlap_free = overlap.ok;

    [policyOk, violations] = audit_goto_from_policy(allBlocks);
    result.checks.goto_from_signal_only = policyOk;
    result.violations = violations;

    result.checks.measurement_logging_present = ...
        (result.metrics.to_workspace_count + result.metrics.root_outport_count) > 0;
    result.checks.oracle_files_present = oracle_files_present(opt.ProjectRoot);

    result.metrics.lab_reference_root = 'Desktop lab model archive';
    result.metrics.lab_reference_available = isfolder(opt.LabReferenceRoot);

    if ~result.metrics.lab_reference_available
        result.warnings{end+1} = sprintf('Lab reference archive not found: %s', opt.LabReferenceRoot);
    end
    if result.metrics.root_block_count > opt.MaxRootBlocks && ...
            result.metrics.subsystem_ratio < opt.MinSubsystemRatio
        result.warnings{end+1} = sprintf( ...
            'High root block count (%d) with low subsystem ratio (%.3g)', ...
            result.metrics.root_block_count, result.metrics.subsystem_ratio);
    end

    result.passed = result.checks.root_overlap_free ...
        && result.checks.goto_from_signal_only ...
        && result.checks.measurement_logging_present ...
        && result.checks.oracle_files_present;

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

if strlength(string(opt.ReportPath)) > 0
    write_quality_report(opt.ReportPath, result);
end
end

function root = default_project_root()
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
end

function root = default_lab_reference_root()
root = fullfile(getenv('USERPROFILE'), 'Desktop', '实验室仿真模型汇总');
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

function n = count_block_type(blocks, blockType)
n = 0;
for k = 1:numel(blocks)
    try
        if strcmp(get_param(blocks{k}, 'BlockType'), blockType)
            n = n + 1;
        end
    catch
    end
end
end

function d = max_hierarchy_depth(blocks, modelName)
d = 0;
prefix = [char(modelName) '/'];
for k = 1:numel(blocks)
    p = char(blocks{k});
    if startsWith(p, prefix)
        d = max(d, numel(strfind(p, '/')));
    end
end
end

function r = ratio(a, b)
if b == 0
    r = 0;
else
    r = a / b;
end
end

function overlap = run_overlap_scan(modelName)
if exist('scan_block_overlap', 'file') == 2
    overlap = scan_block_overlap(modelName, 'Recursive', false);
else
    rootBlocks = find_system(modelName, 'SearchDepth', 1, ...
        'LookUnderMasks', 'none', 'FollowLinks', 'off', 'Type', 'Block');
    overlap = struct('nOverlaps', local_count_overlap(rootBlocks), ...
        'ok', true, 'pairs', []);
    overlap.ok = overlap.nOverlaps == 0;
end
end

function n = local_count_overlap(blocks)
n = 0;
positions = zeros(numel(blocks), 4);
keep = false(numel(blocks), 1);
for k = 1:numel(blocks)
    try
        pos = get_param(blocks{k}, 'Position');
        if numel(pos) == 4 && ~isequal(pos, [0 0 0 0])
            positions(k, :) = pos;
            keep(k) = true;
        end
    catch
    end
end
positions = positions(keep, :);
for i = 1:size(positions, 1)-1
    for j = i+1:size(positions, 1)
        if positions(i, 1) < positions(j, 3) && positions(i, 3) > positions(j, 1) && ...
                positions(i, 2) < positions(j, 4) && positions(i, 4) > positions(j, 2)
            n = n + 1;
        end
    end
end
end

function [ok, violations] = audit_goto_from_policy(blocks)
violations = repmat(empty_violation(), 1, 0);
for k = 1:numel(blocks)
    try
        bt = get_param(blocks{k}, 'BlockType');
        if ~strcmp(bt, 'Goto') && ~strcmp(bt, 'From')
            continue
        end
        tag = get_param(blocks{k}, 'GotoTag');
        if is_physical_suspect_tag(tag)
            violations(end+1) = struct('block_path', char(blocks{k}), ...
                'block_type', bt, 'tag', char(tag), ...
                'reason', 'Goto/From tag looks like a physical SPS terminal'); %#ok<AGROW>
        end
    catch
    end
end
ok = isempty(violations);
end

function tf = is_physical_suspect_tag(tag)
tag = lower(strtrim(char(tag)));
allowed = {'utabc','itabc','inetabc','unetabc','vabc','iabc','windspeed', ...
    'pref','qref','vref','pe','wr','wpll','trip','theta','theta_pll'};
if any(strcmp(tag, allowed))
    tf = false;
    return
end
physicalPatterns = {'^a$', '^b$', '^c$', '^phase[_ -]?[abc]$', ...
    '^terminal[_ -]?[abc]$', 'rconn', 'lconn', 'physical', 'sps'};
tf = false;
for k = 1:numel(physicalPatterns)
    if ~isempty(regexp(tag, physicalPatterns{k}, 'once'))
        tf = true;
        return
    end
end
end

function tf = oracle_files_present(projectRoot)
oracles = {'NEBUS39V2.slx', 'NE39bus_dataV2.m', ...
    'power_wind_dfig_avg.slx', 'power_KundurTwoAreaSystem.slx'};
tf = true;
for k = 1:numel(oracles)
    tf = tf && isfile(fullfile(projectRoot, oracles{k}));
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
if isempty(failed)
    msg = 'Layout quality audit failed without a false scalar check.';
else
    msg = ['Failed checks: ' strjoin(failed, ', ')];
end
end

function v = empty_violation()
v = struct('block_path','', 'block_type','', 'tag','', 'reason','');
end

function write_quality_report(path, result)
reportDir = fileparts(path);
if ~isempty(reportDir) && ~isfolder(reportDir)
    mkdir(reportDir);
end
fid = fopen(path, 'w');
if fid < 0
    warning('AuditModelQualityLayout:CannotWriteReport', 'Cannot write %s', path);
    return
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Model Quality Layout Audit\n\n');
fprintf(fid, '- model: `%s`\n', result.model);
fprintf(fid, '- status: `%s`\n', result.status);
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
    elseif islogical(value) && isscalar(value)
        fprintf(fid, '- %s: `%s`\n', metricNames{k}, mat2str(value));
    elseif ischar(value)
        fprintf(fid, '- %s: `%s`\n', metricNames{k}, value);
    else
        fprintf(fid, '- %s: (omitted)\n', metricNames{k});
    end
end

if ~isempty(result.warnings)
    fprintf(fid, '\n## Warnings\n\n');
    for k = 1:numel(result.warnings)
        fprintf(fid, '- %s\n', result.warnings{k});
    end
end

if ~isempty(result.violations)
    fprintf(fid, '\n## Goto/From Violations\n\n');
    for k = 1:numel(result.violations)
        v = result.violations(k);
        fprintf(fid, '- `%s` tag `%s`: %s\n', v.block_path, v.tag, v.reason);
    end
end

fprintf(fid, '\n## Reference Layout Sources\n\n');
fprintf(fid, '- M01-02_4M2A_DFIG: symmetric two-area spacing and grouping\n');
fprintf(fid, '- M07_SGbyhjq_NEBUS39: compact single-machine template\n');
fprintf(fid, '- M08_VSCbyhjq: legal Goto/From for signal-only tags\n');
end
