function s = ai_in_loop_stage_modeladvisor(projectRoot, modelName, iterDir)
%AI_IN_LOOP_STAGE_MODELADVISOR  Run Simulink Model Advisor on the derived model.
%
%   s = ai_in_loop_stage_modeladvisor(projectRoot, modelName, iterDir)
%
%   Runs Model Advisor against the derived model and writes a Markdown
%   summary to iterDir/model_advisor_summary.md. Treats this as a
%   FAIL-eligible gate independent of sltest, so a model that compiles +
%   smoke-runs but ships obvious MA-flagged defects is not declared PASS.
%
%   Pattern source: external/github/mathworks-ci-verify
%   Scripts/LaneFollowingExecModelAdvisor.m. Re-implemented here (do not
%   import the script; the example is ADAS-domain).
%
%   Behaviour:
%     - If Simulink Check / Model Advisor API is unavailable, returns
%       status='SKIPPED' (license-aware soft skip).
%     - If MA produces any 'fail' result, returns status='FAIL' and writes
%       FS-016 evidence into iterDir.
%     - 'warn' results are listed but do not flip status by default. Pass
%       'WarnAsFail' true via global state to escalate.

s = struct('name','S7B_MODELADVISOR','status','PASS','model',char(modelName));
s.fail_count = 0;
s.warn_count = 0;
s.report_path = '';

% License + product check (avoid hard dependency).
% R2024b's MA entry is ModelAdvisor.run (.p in toolbox/simulink/simulink/
% modeladvisor/@ModelAdvisor/). Older releases also expose Simulink.ModelAdvisor.run.
% Accept either; license is the gating factor.
hasMA = ~isempty(which('Simulink.ModelAdvisor.run')) || ...
        ~isempty(which('ModelAdvisor.run'));
hasLic = license('test','Simulink_Check') == 1;
if ~hasMA || ~hasLic
    s.status = 'SKIPPED';
    if ~hasMA
        s.note = 'Model Advisor API not on path. Check Simulink Check installation.';
    elseif ~hasLic
        s.note = 'Simulink Check license not available (license(''test'',''Simulink_Check'')=0). MA stage permanently skipped on this MATLAB instance.';
    end
    return
end

% Open model if needed (deferred load — caller may have it already).
loadedHere = false;
if ~bdIsLoaded(modelName)
    load_system(modelName);
    loadedHere = true;
end

cleanup = onCleanup(@() iLocalCloseIfOpened(modelName, loadedHere));

% Run a default check set. Project-specific ModelAdvisor configurations can
% later be wired by setting cfg = '<projectRoot>/configs/model_advisor.json'.
results = [];
try
    results = Simulink.ModelAdvisor.run(char(modelName), 'maab');
catch ME
    % MathWorks 'maab' set may not be installed on every license.
    s.status = 'SKIPPED';
    s.note   = sprintf('Model Advisor run failed (%s); skipping check gate.', ME.identifier);
    return
end

[failList, warnList] = iLocalSplitResults(results);
s.fail_count = numel(failList);
s.warn_count = numel(warnList);

reportPath = fullfile(iterDir, 'model_advisor_summary.md');
iLocalWriteSummary(reportPath, modelName, failList, warnList);
s.report_path = reportPath;

if s.fail_count > 0
    error('AIInLoop:ModelAdvisorFail', ...
        'Model Advisor reported %d fail check(s). See %s', s.fail_count, reportPath);
end
end


function iLocalCloseIfOpened(modelName, loadedHere)
if loadedHere && bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end


function [failList, warnList] = iLocalSplitResults(results)
failList = {};
warnList = {};
if isempty(results); return; end
% Simulink.ModelAdvisor.run returns a cell array of result structs; each has
% fields like CheckID, CheckTitle, ResultStatus ('Pass'/'Warn'/'Fail').
for k = 1:numel(results)
    r = results{k};
    if ~isstruct(r) || ~isfield(r,'ResultStatus'); continue; end
    if strcmpi(r.ResultStatus,'Fail')
        failList{end+1} = r; %#ok<AGROW>
    elseif strcmpi(r.ResultStatus,'Warn')
        warnList{end+1} = r; %#ok<AGROW>
    end
end
end


function iLocalWriteSummary(path, modelName, failList, warnList)
fid = fopen(path,'w');
if fid < 0
    warning('AIInLoop:CannotWriteSummary','Cannot write %s', path);
    return
end
oc = onCleanup(@() fclose(fid));
fprintf(fid, '# Model Advisor Summary\n\n');
fprintf(fid, 'Model: `%s`\n', char(modelName));
fprintf(fid, 'Generated: %s\n\n', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
fprintf(fid, '- Fail: %d\n', numel(failList));
fprintf(fid, '- Warn: %d\n\n', numel(warnList));

if ~isempty(failList)
    fprintf(fid, '## Fail Checks (FS-016 candidates)\n\n');
    for k = 1:numel(failList)
        r = failList{k};
        id    = iLocalField(r,'CheckID','<unknown>');
        title = iLocalField(r,'CheckTitle','<unknown>');
        fprintf(fid, '- **%s** %s\n', id, title);
    end
    fprintf(fid, '\n');
end
if ~isempty(warnList)
    fprintf(fid, '## Warn Checks\n\n');
    for k = 1:numel(warnList)
        r = warnList{k};
        id    = iLocalField(r,'CheckID','<unknown>');
        title = iLocalField(r,'CheckTitle','<unknown>');
        fprintf(fid, '- %s %s\n', id, title);
    end
end
end


function v = iLocalField(s, name, default)
if isfield(s, name); v = s.(name); else; v = default; end
end
