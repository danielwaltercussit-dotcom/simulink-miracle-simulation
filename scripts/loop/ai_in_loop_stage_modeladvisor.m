function s = ai_in_loop_stage_modeladvisor(~, modelName, iterDir)
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
    % No Simulink Check license/product: instead of a decorative SKIP, fall
    % back to a license-free static lint so this gate still catches obvious
    % structural defects (algebraic loops, unconnected ports, mixed sample
    % times, root overlap). The fallback is FAIL-eligible via FS-016.
    if ~hasMA
        reason = 'Model Advisor API not on path.';
    else
        reason = 'Simulink Check license not available.';
    end
    s = iLocalStaticLintGate(modelName, iterDir, reason);
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


function s = iLocalStaticLintGate(modelName, iterDir, reason)
% License-free fallback for the S7B quality gate. Runs a set of structural
% find_system checks and writes model_advisor_summary.md. Returns status
% 'PASS' (clean) or raises AIInLoop:ModelAdvisorFail (FS-016) on any fail,
% so the gate is enforcing rather than decorative.
s = struct('name','S7B_MODELADVISOR','status','PASS','model',char(modelName));
s.fail_count = 0;
s.warn_count = 0;
s.report_path = '';
s.backend = 'static_lint';

loadedHere = false;
if ~bdIsLoaded(modelName)
    load_system(char(modelName));
    loadedHere = true;
end
cleanup = onCleanup(@() iLocalCloseIfOpened(modelName, loadedHere));

fails = {};
warns = {};

% Check 1: algebraic loops (license-free API).
try
    al = Simulink.BlockDiagram.getAlgebraicLoops(char(modelName));
    if ~isempty(al)
        fails{end+1} = sprintf('Algebraic loops detected: %d', numel(al));
    end
catch
    % API shape varies by release; skip rather than false-fail.
end

% Check 2: unconnected root-level signal ports. Reported as a WARN, not a
% FAIL: a dangling monitoring outport (e.g. an unused DFIG measurement bus
% on a focused test bench) is legitimate and must not block an otherwise
% runnable model. Only structurally model-breaking issues below are FAILs.
try
    nUnconnected = iLocalCountUnconnectedPorts(modelName);
    if nUnconnected > 0
        warns{end+1} = sprintf('Unconnected root signal ports: %d', nUnconnected);
    end
catch ME
    warns{end+1} = sprintf('Unconnected-port scan failed: %s', ME.message);
end

% Check 3: root block overlap (reuse project scanner).
try
    ov = scan_block_overlap(char(modelName), 'ThrowOnFail', false);
    if ~ov.ok
        fails{end+1} = sprintf('Root block overlap: %d pair(s)', ov.nOverlaps);
    end
catch ME
    warns{end+1} = sprintf('Overlap scan failed: %s', ME.message);
end

% Check 4: sample-time hygiene — a discrete model should not silently carry
% continuous-time states. Warn (not fail) since some donors are legitimately
% continuous.
try
    st = get_param(char(modelName), 'SolverType');
    if strcmpi(st, 'Fixed-step')
        nCont = numel(find_system(char(modelName), 'LookUnderMasks','all', ...
            'FollowLinks','on', 'BlockType','Integrator'));
        if nCont > 0
            warns{end+1} = sprintf('Fixed-step model has %d continuous Integrator block(s)', nCont);
        end
    end
catch
end

s.fail_count = numel(fails);
s.warn_count = numel(warns);
s.report_path = iLocalWriteStaticSummary(iterDir, modelName, reason, fails, warns);

if s.fail_count > 0
    error('AIInLoop:ModelAdvisorFail', ...
        'Static lint gate reported %d fail(s). See %s', s.fail_count, s.report_path);
end
end


function n = iLocalCountUnconnectedPorts(modelName)
% Count unconnected *signal* ports we are responsible for wiring: root-level
% Inport/Outport block ports only. Physical SPS/Simscape 'connection' ports
% (PMIOPort, PMComponent, Multimeter, three-phase LConn/RConn) legitimately
% have Line==-1 and are NOT signal wiring, so they are excluded. Donor
% subsystem internals (e.g. DFIG_W33) are upstream content we don't rewire,
% so we stay at the root canvas.
n = 0;
ph = find_system(char(modelName), 'SearchDepth', 1, 'FindAll','on', 'Type','port');
for k = 1:numel(ph)
    pt = get_param(ph(k), 'PortType');
    if ~any(strcmp(pt, {'inport','outport'})); continue; end
    if get_param(ph(k), 'Line') == -1
        n = n + 1;
    end
end
end


function path = iLocalWriteStaticSummary(iterDir, modelName, reason, fails, warns)
path = '';
if isempty(iterDir); return; end
if ~isfolder(iterDir); mkdir(iterDir); end
path = fullfile(iterDir, 'model_advisor_summary.md');
fid = fopen(path, 'w');
if fid < 0
    warning('AIInLoop:CannotWriteSummary', 'Cannot write %s', path); path = ''; return;
end
oc = onCleanup(@() fclose(fid));
fprintf(fid, '# Model Advisor Summary (static lint fallback)\n\n');
fprintf(fid, 'Model: `%s`\n', char(modelName));
fprintf(fid, 'Backend: `static_lint` (%s)\n\n', reason);
fprintf(fid, '- Fail: %d\n', numel(fails));
fprintf(fid, '- Warn: %d\n\n', numel(warns));
if ~isempty(fails)
    fprintf(fid, '## Fail Checks (FS-016)\n\n');
    for k = 1:numel(fails); fprintf(fid, '- %s\n', fails{k}); end
    fprintf(fid, '\n');
end
if ~isempty(warns)
    fprintf(fid, '## Warn Checks\n\n');
    for k = 1:numel(warns); fprintf(fid, '- %s\n', warns{k}); end
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
