function audit = ai_in_loop_audit_snapshot(projectRoot, modelName, snapshotDir, reportPath)
%AI_IN_LOOP_AUDIT_SNAPSHOT  Verify a copied AI-in-loop snapshot package.
%   This is a filesystem-only check. It does not open or simulate the model.

if nargin < 1 || strlength(string(projectRoot)) == 0
    projectRoot = default_project_root();
end
if nargin < 2 || strlength(string(modelName)) == 0
    error('AIInLoop:SnapshotAuditMissingModel', 'modelName is required.');
end
if nargin < 3 || strlength(string(snapshotDir)) == 0
    snapshotDir = fullfile(getenv('USERPROFILE'), 'Desktop', ...
        'AI summary of simulation models', char(modelName));
end
if nargin < 4 || strlength(string(reportPath)) == 0
    reportPath = fullfile(char(projectRoot), 'build', 'reports', 'snapshots', ...
        [char(modelName) '_snapshot_audit.md']);
end

projectRoot = char(projectRoot);
modelName = char(modelName);
snapshotDir = char(snapshotDir);
reportPath = char(reportPath);

audit = struct('name','S10B_SNAPSHOT_AUDIT','status','FAIL','passed',false, ...
    'model',modelName,'snapshot_dir',snapshotDir,'report_path',reportPath, ...
    'missing',{{}},'empty',{{}},'gaps',{{}},'checked',{{}});

if ~isfolder(snapshotDir)
    audit.missing{end+1} = sprintf('snapshot directory: %s', snapshotDir);
    write_snapshot_audit_report(audit);
    return
end

manifestPath = fullfile(snapshotDir, 'snapshot_manifest.json');
statusPath = fullfile(snapshotDir, 'latest_loop_status.json');
readmePath = fullfile(snapshotDir, 'README.md');
modelPath = fullfile(snapshotDir, [modelName '.slx']);
specPath = fullfile(snapshotDir, ['case_' modelName '.yaml']);
buildPath = fullfile(snapshotDir, ['build_' modelName '.m']);

require_file(modelPath, true);
require_file(specPath, true);
require_file(buildPath, true);
require_file(manifestPath, true);
require_file(statusPath, true);
require_file(readmePath, true);

if ~has_any_file(snapshotDir, {[modelName '_report.md'], [modelName '_loop_report.md']})
    audit.missing{end+1} = 'human-readable loop or project report';
else
    audit.checked{end+1} = 'human-readable loop or project report';
end

manifest = read_json_if_possible(manifestPath, 'snapshot manifest');
if isstruct(manifest)
    if ~isfield(manifest, 'model') || ~strcmp(char(manifest.model), modelName)
        audit.missing{end+1} = 'manifest model name matching copied model';
    end
    if ~isfield(manifest, 'project_root') || ~strcmp(char(manifest.project_root), projectRoot)
        audit.gaps{end+1} = 'manifest project_root does not match current projectRoot argument';
    end
end

status = read_json_if_possible(statusPath, 'latest loop status');
if isstruct(status)
    if isfield(status, 'passed') && islogical(status.passed) && status.passed
        if ~has_any_file(snapshotDir, {[modelName '_report.md'], [modelName '_loop_report.md']})
            audit.missing{end+1} = 'PASS snapshot report evidence';
        end
    end
    require_conditional_stage_file(status, 'S6', 'latest_tuning_report.md');
    require_conditional_stage_file(status, 'S7', 'latest_sltest_summary.md');
    require_conditional_stage_file(status, 'S7', 'latest_model_verification_summary.md');
    require_conditional_stage_file(status, 'S7B', 'latest_model_advisor_summary.md');
end

if isempty(audit.missing) && isempty(audit.empty)
    audit.status = 'PASS';
    audit.passed = true;
end
write_snapshot_audit_report(audit);

    function require_file(path, failIfMissing)
        if isfile(path)
            info = dir(path);
            if isempty(info) || info.bytes == 0
                audit.empty{end+1} = path;
            else
                audit.checked{end+1} = path;
            end
        elseif failIfMissing
            audit.missing{end+1} = path;
        else
            audit.gaps{end+1} = path;
        end
    end

    function value = read_json_if_possible(path, label)
        if ~isfile(path)
            value = [];
            return
        end
        try
            value = jsondecode(fileread(path));
        catch ME
            audit.missing{end+1} = sprintf('parseable %s (%s)', label, ME.message);
            value = [];
        end
    end

    function require_conditional_stage_file(statusStruct, stageName, fileName)
        if ~isfield(statusStruct, 'stages') || ~isfield(statusStruct.stages, stageName)
            return
        end
        stage = statusStruct.stages.(stageName);
        if isfield(stage, 'status') && strcmp(char(stage.status), 'SKIPPED')
            audit.gaps{end+1} = sprintf('%s skipped; %s not required', stageName, fileName);
            return
        end
        require_file(fullfile(snapshotDir, fileName), true);
    end
end

function tf = has_any_file(folder, names)
tf = false;
for k = 1:numel(names)
    path = fullfile(folder, names{k});
    info = dir(path);
    if isfile(path) && ~isempty(info) && info.bytes > 0
        tf = true;
        return
    end
end
end

function write_snapshot_audit_report(audit)
reportDir = fileparts(audit.report_path);
if ~isempty(reportDir) && ~isfolder(reportDir)
    mkdir(reportDir);
end
fid = fopen(audit.report_path, 'w');
if fid < 0
    warning('AIInLoop:SnapshotAuditReportFailed', 'Cannot write %s', audit.report_path);
    return
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Snapshot Audit\n\n');
fprintf(fid, '- model: `%s`\n', audit.model);
fprintf(fid, '- snapshot_dir: `%s`\n', audit.snapshot_dir);
fprintf(fid, '- status: `%s`\n', audit.status);
fprintf(fid, '- passed: `%s`\n\n', mat2str(audit.passed));

write_list(fid, 'Checked Files', audit.checked);
write_list(fid, 'Missing Required Evidence', audit.missing);
write_list(fid, 'Empty Required Evidence', audit.empty);
write_list(fid, 'Recorded Gaps', audit.gaps);
end

function write_list(fid, title, values)
fprintf(fid, '## %s\n\n', title);
if isempty(values)
    fprintf(fid, '- none\n\n');
    return
end
for k = 1:numel(values)
    fprintf(fid, '- `%s`\n', values{k});
end
fprintf(fid, '\n');
end

function root = default_project_root()
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
end
