function result = cleanup_dangling_lines(modelName, varargin)
%CLEANUP_DANGLING_LINES Remove lines Simulink explicitly marks disconnected.
%   The default scope is the model root. This intentionally uses the line
%   Connected property instead of SrcPortHandle/DstPortHandle because SPS
%   physical connections can have -1 destination handles while still being
%   valid connected lines.

p = inputParser;
p.addParameter('ModelPath', '', @(x) ischar(x) || isstring(x));
p.addParameter('Recursive', false, @(x) islogical(x) || isnumeric(x));
p.addParameter('Apply', true, @(x) islogical(x) || isnumeric(x));
p.addParameter('SaveModel', true, @(x) islogical(x) || isnumeric(x));
p.addParameter('ReportPath', '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opt = p.Results;
opt.ModelPath = char(opt.ModelPath);
opt.Recursive = logical(opt.Recursive);
opt.Apply = logical(opt.Apply);
opt.SaveModel = logical(opt.SaveModel);
opt.ReportPath = char(opt.ReportPath);

modelName = char(modelName);
result = struct('name', 'DANGLING_LINE_CLEANUP', ...
    'model', modelName, 'status', 'FAIL', 'passed', false, ...
    'applied', opt.Apply, 'recursive', opt.Recursive, ...
    'before_count', 0, 'removed_count', 0, 'after_count', 0, ...
    'lines', repmat(empty_line_record(), 1, 0), ...
    'warnings', {{}}, 'message', '', 'report_path', opt.ReportPath);

try
    load_model_if_needed(modelName, opt.ModelPath);
    [handles, records] = find_dangling_lines(modelName, opt.Recursive);
    result.before_count = numel(handles);
    result.lines = records;

    if opt.Apply
        for k = 1:numel(handles)
            try
                delete_line(handles(k));
                result.removed_count = result.removed_count + 1;
            catch ME
                result.warnings{end+1} = sprintf( ...
                    'Could not delete line %s: %s', records(k).handle, ME.message);
            end
        end
        if opt.SaveModel && result.removed_count > 0
            save_system(modelName);
        end
    end

    [remaining, ~] = find_dangling_lines(modelName, opt.Recursive);
    result.after_count = numel(remaining);
    result.passed = result.after_count == 0;
    if result.passed
        result.status = 'PASS';
        result.message = sprintf('Removed %d disconnected line(s).', result.removed_count);
    elseif ~opt.Apply
        result.message = sprintf('Found %d disconnected line(s); cleanup not applied.', ...
            result.after_count);
    else
        result.message = sprintf('Cleanup incomplete: %d disconnected line(s) remain.', ...
            result.after_count);
    end
catch ME
    result.message = ME.message;
    result.error_id = ME.identifier;
end

if strlength(string(opt.ReportPath)) > 0
    write_cleanup_report(opt.ReportPath, result);
end
end

function load_model_if_needed(modelName, modelPath)
if bdIsLoaded(modelName)
    return
end
if ~isempty(modelPath)
    load_system(modelPath);
else
    load_system(modelName);
end
end

function [handles, records] = find_dangling_lines(modelName, recursive)
scopes = {modelName};
if recursive
    subsystems = find_system(modelName, 'LookUnderMasks', 'none', ...
        'FollowLinks', 'off', 'BlockType', 'SubSystem');
    scopes = unique([{modelName}; subsystems(:)], 'stable');
end

handles = zeros(0, 1);
records = repmat(empty_line_record(), 1, 0);
for s = 1:numel(scopes)
    lines = find_system(scopes{s}, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'line');
    for k = 1:numel(lines)
        try
            if ~strcmp(get_param(lines(k), 'Connected'), 'off')
                continue
            end
            handles(end+1, 1) = lines(k); %#ok<AGROW>
            records(end+1) = line_record(lines(k)); %#ok<AGROW>
        catch
        end
    end
end

if ~isempty(handles)
    [handles, keep] = unique(handles, 'stable');
    records = records(keep);
end
end

function record = line_record(handle)
record = empty_line_record();
record.handle = sprintf('%.15g', handle);
record.parent = safe_line_param(handle, 'Parent');
record.name = safe_line_param(handle, 'Name');
try
    record.points = mat2str(get_param(handle, 'Points'));
catch
end
end

function value = safe_line_param(handle, name)
value = '';
try
    value = char(get_param(handle, name));
catch
end
end

function record = empty_line_record()
record = struct('handle', '', 'parent', '', 'name', '', 'points', '');
end

function write_cleanup_report(path, result)
reportDir = fileparts(path);
if ~isempty(reportDir) && ~isfolder(reportDir)
    mkdir(reportDir);
end
fid = fopen(path, 'w');
if fid < 0
    warning('CleanupDanglingLines:CannotWriteReport', 'Cannot write %s', path);
    return
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Dangling Line Cleanup\n\n');
fprintf(fid, '- model: `%s`\n', result.model);
fprintf(fid, '- status: `%s`\n', result.status);
fprintf(fid, '- applied: `%s`\n', mat2str(result.applied));
fprintf(fid, '- recursive: `%s`\n', mat2str(result.recursive));
fprintf(fid, '- before_count: %d\n', result.before_count);
fprintf(fid, '- removed_count: %d\n', result.removed_count);
fprintf(fid, '- after_count: %d\n', result.after_count);
fprintf(fid, '- message: %s\n', result.message);
if ~isempty(result.lines)
    fprintf(fid, '\n## Detected Lines\n\n');
    for k = 1:numel(result.lines)
        line = result.lines(k);
        fprintf(fid, '- `%s` in `%s`, points `%s`\n', ...
            line.handle, line.parent, line.points);
    end
end
if ~isempty(result.warnings)
    fprintf(fid, '\n## Warnings\n\n');
    for k = 1:numel(result.warnings)
        fprintf(fid, '- %s\n', result.warnings{k});
    end
end
end
