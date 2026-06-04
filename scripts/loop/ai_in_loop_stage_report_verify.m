function s = ai_in_loop_stage_report_verify(projectRoot, iterDir, state)
%AI_IN_LOOP_STAGE_REPORT_VERIFY  S9 completion contract.
%   Re-read status.json, ensure required artifacts exist, and export/copy the
%   root-layout PNG if needed before the loop is allowed to declare PASS.

s = struct('name','S9_REPORT','status','PASS','report_dir',char(iterDir), ...
    'checked_artifacts', {{}}, 'top_png', '');

topPath = fullfile(iterDir, 'top.png');
topInfo = dir(topPath);
if ~isfile(topPath) || isempty(topInfo) || topInfo.bytes == 0
    export_top_png(projectRoot, state.model_name, topPath);
end
s.top_png = topPath;

required = {fullfile(iterDir,'report.md'), fullfile(iterDir,'status.json'), topPath};
if isfield(state.stages, 'S0_25')
    required{end+1} = fullfile(iterDir, 'fidelity_decision.md');
    required{end+1} = fullfile(iterDir, 'fidelity_decision.json');
end
if isfield(state.stages, 'S6')
    required{end+1} = fullfile(iterDir, 'tuning_report.md');
end
if isfield(state.stages, 'S7')
    required{end+1} = fullfile(iterDir, 'sltest_summary.md');
    required{end+1} = fullfile(iterDir, 'model_verification_summary.md');
end

for k = 1:numel(required)
    path = required{k};
    if ~isfile(path)
        s.status = 'FAIL';
        s.note = sprintf('Missing required artifact: %s', path);
        error('AIInLoop:ReportArtifactMissing', s.note);
    end
    info = dir(path);
    if isempty(info) || info.bytes == 0
        s.status = 'FAIL';
        s.note = sprintf('Empty required artifact: %s', path);
        error('AIInLoop:ReportArtifactEmpty', s.note);
    end
    s.checked_artifacts{end+1} = path;
end

statusPath = fullfile(iterDir, 'status.json');
txt = fileread(statusPath);
decoded = jsondecode(txt);
if ~isfield(decoded, 'passed') || ~islogical(decoded.passed) || ~decoded.passed
    error('AIInLoop:ReportStatusMismatch', 'status.json does not contain passed=true.');
end
if ~isfield(decoded, 'update') || ~islogical(decoded.update) || ~decoded.update
    error('AIInLoop:ReportStatusMismatch', 'status.json does not contain update=true.');
end
if ~isfield(decoded, 'smoke') || ~islogical(decoded.smoke) || ~decoded.smoke
    error('AIInLoop:ReportStatusMismatch', 'status.json does not contain smoke=true.');
end
if isfield(state.stages, 'S6')
    if ~isfield(decoded, 'tune') || ~islogical(decoded.tune) || ~decoded.tune
        error('AIInLoop:ReportStatusMismatch', 'status.json does not contain tune=true.');
    end
end
if isfield(state.stages, 'S7')
    if ~isfield(decoded, 'sltest') || ~islogical(decoded.sltest) || ~decoded.sltest
        error('AIInLoop:ReportStatusMismatch', 'status.json does not contain sltest=true.');
    end
end

s.verified_at = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
end

function export_top_png(projectRoot, modelName, topPath)
modelName = char(modelName);
reportSrc = fullfile(projectRoot, 'build', 'reports', [modelName '_top.png']);
if isfile(reportSrc)
    copyfile(reportSrc, topPath);
    return
end

modelPath = fullfile(projectRoot, 'build', 'generated_models', [modelName '.slx']);
if ~bdIsLoaded(modelName)
    load_system(modelPath);
end
try
    open_system(modelName);
    print(['-s' modelName], '-dpng', topPath);
catch ME
    error('AIInLoop:TopPngExportFailed', ...
        'Could not export root layout PNG for %s: %s', modelName, ME.message);
end
end
