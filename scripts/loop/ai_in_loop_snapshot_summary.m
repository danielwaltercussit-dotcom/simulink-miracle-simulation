function s = ai_in_loop_snapshot_summary(projectRoot, modelName, specPath, buildFcn, iterDir, snapshotRoot)
%AI_IN_LOOP_SNAPSHOT_SUMMARY  Copy a passed model package to AI summary.
%   The summary folder is an external, user-facing backup; it does not replace
%   project-local generated models or reports.

s = struct('name','S10_SNAPSHOT','status','PASS','model',char(modelName), ...
    'snapshot_dir','', 'copied', {{}});

if nargin < 6 || strlength(string(snapshotRoot)) == 0
    snapshotRoot = fullfile(getenv('USERPROFILE'), 'Desktop', 'AI summary of simulation models');
end
snapshotRoot = char(snapshotRoot);
if ~isfolder(snapshotRoot)
    mkdir(snapshotRoot);
end

modelName = char(modelName);
dstDir = fullfile(snapshotRoot, modelName);
if ~isfolder(dstDir)
    mkdir(dstDir);
end
s.snapshot_dir = dstDir;

copy_if_exists(fullfile(projectRoot,'build','generated_models',[modelName '.slx']), ...
    fullfile(dstDir,[modelName '.slx']));
copy_if_exists(fullfile(projectRoot,'build','generated_models',[modelName '.slxc']), ...
    fullfile(dstDir,[modelName '.slxc']));
copy_if_exists(fullfile(projectRoot,char(specPath)), ...
    fullfile(dstDir, ['case_' modelName '.yaml']));
copy_if_exists(fullfile(projectRoot,'scripts',[char(buildFcn) '.m']), ...
    fullfile(dstDir, ['build_' modelName '.m']));

projectReport = fullfile(projectRoot, 'build', 'reports', [modelName '_report.md']);
if isfile(projectReport)
    copy_if_exists(projectReport, fullfile(dstDir, [modelName '_report.md']));
else
    copy_if_exists(fullfile(iterDir, 'report.md'), fullfile(dstDir, [modelName '_loop_report.md']));
end

pngs = dir(fullfile(projectRoot, 'build', 'reports', [modelName '*.png']));
for k = 1:numel(pngs)
    copy_if_exists(fullfile(pngs(k).folder, pngs(k).name), fullfile(dstDir, pngs(k).name));
end

copy_if_exists(fullfile(iterDir, 'status.json'), fullfile(dstDir, 'latest_loop_status.json'));
copy_if_exists(fullfile(iterDir, 'model_verification_summary.md'), fullfile(dstDir, 'latest_model_verification_summary.md'));
copiedSpecValidation = copy_latest_spec_validation(projectRoot, specPath, dstDir);
append_copied(copiedSpecValidation);
copiedAdapterContract = copy_latest_adapter_contract(projectRoot, modelName, dstDir);
append_copied(copiedAdapterContract);
copiedLayoutQuality = copy_latest_layout_quality(projectRoot, modelName, dstDir);
append_copied(copiedLayoutQuality);
copy_if_exists(fullfile(iterDir, 'tuning_report.md'), fullfile(dstDir, 'latest_tuning_report.md'));
copy_if_exists(fullfile(iterDir, 'sltest_summary.md'), fullfile(dstDir, 'latest_sltest_summary.md'));
copy_if_exists(fullfile(iterDir, 'top.png'), fullfile(dstDir, [modelName '_latest_top.png']));

manifest = struct();
manifest.model = modelName;
manifest.project_root = projectRoot;
manifest.spec_path = char(specPath);
manifest.build_fcn = char(buildFcn);
manifest.iteration_dir = char(iterDir);
manifest.snapshot_at = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
manifest.files = list_files(dstDir);
fid = fopen(fullfile(dstDir, 'snapshot_manifest.json'), 'w');
if fid < 0
    error('AIInLoop:SnapshotManifestFailed', 'Cannot write snapshot manifest in %s', dstDir);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(manifest));

write_model_readme(fullfile(dstDir, 'README.md'), manifest);

    function copy_if_exists(src, dst)
        if isfile(src)
            copyfile(src, dst);
            s.copied{end+1} = dst;
        end
    end

    function append_copied(path)
        if ~isempty(path)
            s.copied{end+1} = path;
        end
    end
end

function copiedPath = copy_latest_spec_validation(projectRoot, specPath, dstDir)
copiedPath = '';
[~, specName] = fileparts(char(specPath));
src = fullfile(projectRoot, 'build', 'reports', 'spec_validation', [specName '.md']);
dst = fullfile(dstDir, 'latest_spec_validation.md');
if isfile(src)
    copyfile(src, dst);
    copiedPath = dst;
end
end

function copiedPath = copy_latest_adapter_contract(projectRoot, modelName, dstDir)
copiedPath = '';
src = fullfile(projectRoot, 'build', 'reports', 'adapters', [char(modelName) '.md']);
dst = fullfile(dstDir, 'latest_adapter_contract.md');
if isfile(src)
    copyfile(src, dst);
    copiedPath = dst;
end
end

function copiedPath = copy_latest_layout_quality(projectRoot, modelName, dstDir)
copiedPath = '';
src = fullfile(projectRoot, 'build', 'reports', 'layout', [char(modelName) '.md']);
dst = fullfile(dstDir, 'latest_layout_quality.md');
if isfile(src)
    copyfile(src, dst);
    copiedPath = dst;
end
end

function files = list_files(folder)
d = dir(folder);
names = {};
for k = 1:numel(d)
    if ~d(k).isdir
        names{end+1} = d(k).name; %#ok<AGROW>
    end
end
files = names;
end

function write_model_readme(path, manifest)
fid = fopen(path, 'w');
if fid < 0
    warning('AIInLoop:SnapshotReadmeFailed', 'Cannot write %s', path);
    return
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# %s\n\n', manifest.model);
fprintf(fid, 'AI-in-loop snapshot copied from `%s`.\n\n', manifest.project_root);
fprintf(fid, '- spec: `%s`\n', manifest.spec_path);
fprintf(fid, '- build function: `%s`\n', manifest.build_fcn);
fprintf(fid, '- source iteration: `%s`\n', manifest.iteration_dir);
fprintf(fid, '- snapshot_at: %s\n\n', manifest.snapshot_at);
fprintf(fid, '## Files\n\n');
for k = 1:numel(manifest.files)
    fprintf(fid, '- `%s`\n', manifest.files{k});
end
end
