function s = ai_in_loop_stage_tune(~, modelName, tFull, varargin)
%AI_IN_LOOP_STAGE_TUNE  S6 — closed-loop tuning stage.
%
%   s = ai_in_loop_stage_tune(projectRoot, modelName, tFull, ...
%           'MaxRounds', 5, ...
%           'FaultStart', 0.5, 'FaultEnd', 0.7, ...
%           'VnomLL', 13.8e3)
%
%   What this stage does (rule-driven inner loop):
%     1. sim(modelName, StopTime=tFull) → out
%     2. extract_tuning_metrics(out) → m
%     3. if m.stable: PASS, return
%        else: tuning_registry(modelName) → reg
%              choose knob whose fs_targets contains m.fs_signature
%              new_val = scale_fcn(current, signDirFromFS)
%              set_param(blk, mask, new_val); save_system
%              re-sim; repeat up to MaxRounds
%     4. if not converged in MaxRounds: status=FAIL with FS code so the outer
%        ai_in_loop_run can decide whether to break out or retry.
%
%   Result struct:
%     s.status            'PASS' | 'FAIL' | 'SKIPPED'
%     s.rounds            number of inner sim rounds run
%     s.history           struct array {round, params, metrics}
%     s.final_metrics     last m from extract_tuning_metrics

p = inputParser;
p.addParameter('MaxRounds',  5, @(x) isnumeric(x)&&x>=1);
p.addParameter('FaultStart', 0.5, @isnumeric);
p.addParameter('FaultEnd',   0.7, @isnumeric);
p.addParameter('VnomLL',     13.8e3, @isnumeric);
p.addParameter('ReportPath', '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opt = p.Results;

s = struct('name','S6_TUNE','status','PASS','model',char(modelName), ...
    't_full', tFull, 'rounds', 0, 'history', struct([]), ...
    'final_metrics', struct(), 'tuning_hook', '');

if ~bdIsLoaded(modelName); load_system(char(modelName)); end

% Round 0 — sim with current parameters
[out, simOk, errMsg] = safe_sim(modelName, tFull);
if ~simOk
    s.status = 'FAIL';
    s.error  = errMsg;
    write_tuning_report(opt.ReportPath, s);
    return
end
m = extract_tuning_metrics(out, ...
    'fault_t_start', opt.FaultStart, 'fault_t_end', opt.FaultEnd, ...
    'V_nom_LL', opt.VnomLL);
s.history(end+1).round   = 0;
s.history(end).params    = capture_registry(modelName);
s.history(end).metrics   = m;
s.rounds = 1;

if m.stable
    s.status = 'PASS';
    s.final_metrics = m;
    write_tuning_report(opt.ReportPath, s);
    return
end

% Inner tuning loop with multi-knob scheduling
reg = tuning_registry(modelName);
if isempty(reg)
    s.status = 'FAIL';
    s.note   = sprintf('Model is unstable (FS=%s) but no tunable knobs are registered', m.fs_signature);
    s.final_metrics = m;
    write_tuning_report(opt.ReportPath, s);
    return
end

% Per-knob state. flip_count tracks how many times we've reversed direction
% on this knob; if both directions failed to improve, mark exhausted so the
% scheduler moves on to the next registered knob.
knob_state = repmat(struct('id','','last_dir',0,'no_improve',0,'flip_count',0,'exhausted',false), 1, numel(reg));
for k = 1:numel(reg); knob_state(k).id = reg(k).id; end

% Track best growth seen so we can detect "no improvement".
% Also snapshot the parameter set that achieved best_growth so we can roll
% back to it if tuning never converges — otherwise the last (possibly worse
% than initial) attempt would be left written to disk.
best_growth = m.I_osc_growth;
if isnan(best_growth); best_growth = Inf; end
best_snapshot = capture_registry(modelName);

for round = 1:opt.MaxRounds
    targetSig = m.fs_signature;
    if isempty(targetSig); break; end

    % Pick a knob: first reg entry that (a) targets this FS and (b) is not exhausted
    knob = []; knobIdx = 0;
    for k = 1:numel(reg)
        if any(strcmp(reg(k).fs_targets, targetSig)) && ~knob_state(k).exhausted
            knob = reg(k); knobIdx = k;
            break
        end
    end
    if isempty(knob)
        s.status = 'FAIL';
        s.note   = sprintf('All knobs targeting FS=%s are exhausted', targetSig);
        s.final_metrics = m;
        write_tuning_report(opt.ReportPath, s);
        return
    end

    % Direction policy
    if isfield(m,'I_osc_growth') && ~isnan(m.I_osc_growth) && m.I_osc_growth > 1.05
        signDir = +1;
    else
        signDir = -1;
    end
    % If this knob has tried the same direction 2 times without improvement,
    % flip direction. If we've already flipped once before and still didn't
    % improve, the knob is exhausted — let the scheduler move on.
    if knob_state(knobIdx).last_dir == signDir && knob_state(knobIdx).no_improve >= 2
        if knob_state(knobIdx).flip_count >= 1
            knob_state(knobIdx).exhausted = true;
            s.history(end+1).round   = round;
            s.history(end).params    = capture_registry(modelName);
            s.history(end).metrics   = m;
            s.history(end).action    = sprintf('%s exhausted (both directions failed)', knob.id);
            continue
        end
        signDir = -signDir;
        knob_state(knobIdx).no_improve = 0;
        knob_state(knobIdx).flip_count = knob_state(knobIdx).flip_count + 1;
    end

    oldVal = eval(get_param(knob.block_path, knob.mask_param));
    newVal = knob.scale_fcn(oldVal, signDir);
    newVal = clamp_to_bounds(newVal, knob.min, knob.max);

    % If clamped to bound and equals old, this knob is exhausted — skip
    if all(abs(newVal - oldVal) < 1e-9)
        knob_state(knobIdx).exhausted = true;
        s.history(end+1).round = round;
        s.history(end).params  = capture_registry(modelName);
        s.history(end).metrics = m;
        s.history(end).action  = sprintf('%s exhausted at bound %s', knob.id, mat2str(oldVal));
        continue
    end

    set_param(knob.block_path, knob.mask_param, mat2str(newVal));
    save_system(modelName);

    [out, simOk, errMsg] = safe_sim(modelName, tFull);
    if ~simOk
        s.status = 'FAIL';
        s.error  = errMsg;
        s.final_metrics = m;
        write_tuning_report(opt.ReportPath, s);
        return
    end
    m_new = extract_tuning_metrics(out, ...
        'fault_t_start', opt.FaultStart, 'fault_t_end', opt.FaultEnd, ...
        'V_nom_LL', opt.VnomLL);

    % Improvement check on growth metric. Mark exhausted only after 3 same-direction
    % moves with no measurable improvement.
    new_growth = m_new.I_osc_growth;
    if isnan(new_growth); new_growth = Inf; end
    if new_growth < best_growth - 0.02
        best_growth = new_growth;
        best_snapshot = capture_registry(modelName);
        knob_state(knobIdx).no_improve = 0;
    else
        knob_state(knobIdx).no_improve = knob_state(knobIdx).no_improve + 1;
        if knob_state(knobIdx).no_improve >= 3
            knob_state(knobIdx).exhausted = true;
        end
    end
    knob_state(knobIdx).last_dir = signDir;

    s.history(end+1).round   = round;
    s.history(end).params    = capture_registry(modelName);
    s.history(end).metrics   = m_new;
    s.history(end).action    = sprintf('%s.%s: %s -> %s (FS=%s dir=%+d)', ...
        knob.id, knob.mask_param, mat2str(oldVal), mat2str(newVal), targetSig, signDir);
    s.rounds = round + 1;

    m = m_new;
    if m.stable
        s.status = 'PASS';
        s.final_metrics = m;
        write_tuning_report(opt.ReportPath, s);
        return
    end
end

s.status = 'FAIL';
s.note   = sprintf('Tuning did not converge in %d rounds (last FS=%s)', opt.MaxRounds, m.fs_signature);
s.final_metrics = m;
% Roll back to the best parameter set we found, so a non-converged run does
% not leave the model worse than where it started. The model is saved with
% the best-so-far knobs; final_metrics still reflects the last (worse) sim.
restored = restore_registry(modelName, best_snapshot);
if restored
    save_system(modelName);
    s.rolled_back_to_best = true;
    s.best_I_osc_growth   = best_growth;
end
write_tuning_report(opt.ReportPath, s);
end

% ---------------------------------------------------------------
function [out, ok, msg] = safe_sim(modelName, t)
ok = true; msg = '';
try
    out = sim(char(modelName),'StopTime',num2str(t),'ReturnWorkspaceOutputs','on');
catch ME
    ok = false; out = []; msg = ME.message;
end
end

function v = clamp_to_bounds(v, lo, hi)
v = max(lo, min(hi, v));
end

function ok = restore_registry(modelName, snapshot)
% Write a captured {id -> value} snapshot back onto the model's knobs.
% Used to roll a non-converged tuning run back to its best-so-far params.
ok = false;
if isempty(snapshot) || ~isstruct(snapshot); return; end
reg = tuning_registry(modelName);
for k = 1:numel(reg)
    if ~isfield(snapshot, reg(k).id); continue; end
    val = snapshot.(reg(k).id);
    if isempty(val) || any(isnan(val(:))); continue; end
    try
        set_param(reg(k).block_path, reg(k).mask_param, mat2str(val));
        ok = true;
    catch
        % skip knobs that can no longer be written; best-effort restore
    end
end
end

function snap = capture_registry(modelName)
% Return struct of {id -> current value} for logging.
reg = tuning_registry(modelName);
snap = struct();
for k = 1:numel(reg)
    try
        snap.(reg(k).id) = eval(get_param(reg(k).block_path, reg(k).mask_param));
    catch
        snap.(reg(k).id) = NaN;
    end
end
end

function write_tuning_report(reportPath, s)
if strlength(string(reportPath)) == 0
    return
end
reportDir = fileparts(char(reportPath));
if ~isempty(reportDir) && ~isfolder(reportDir)
    mkdir(reportDir);
end
fid = fopen(char(reportPath), 'w');
if fid < 0
    warning('AIInLoop:TuningReportWriteFailed', 'Cannot write %s', char(reportPath));
    return
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Tuning Report\n\n');
fprintf(fid, '- stage: `%s`\n', s.name);
fprintf(fid, '- model: `%s`\n', s.model);
fprintf(fid, '- status: `%s`\n', s.status);
fprintf(fid, '- rounds: %d\n', s.rounds);
if isfield(s, 'note') && ~isempty(s.note)
    fprintf(fid, '- note: %s\n', s.note);
end
if isfield(s, 'error') && ~isempty(s.error)
    fprintf(fid, '- error: %s\n', s.error);
end
fprintf(fid, '\n## History\n\n');
if isempty(s.history)
    fprintf(fid, '_No tuning rounds recorded._\n');
else
    for k = 1:numel(s.history)
        h = s.history(k);
        fprintf(fid, '### Round %d\n\n', h.round);
        if isfield(h, 'action') && ~isempty(h.action)
            fprintf(fid, '- action: `%s`\n', h.action);
        end
        if isfield(h, 'metrics')
            fprintf(fid, '- stable: `%s`\n', mat2str(h.metrics.stable));
            fprintf(fid, '- fs_signature: `%s`\n', h.metrics.fs_signature);
            fprintf(fid, '- steady_V_pu: %.6g\n', h.metrics.steady_V_pu);
            fprintf(fid, '- fault_recovery_ms: %.6g\n', h.metrics.fault_recovery_ms);
            fprintf(fid, '- I_dom_freq_hz: %.6g\n', h.metrics.I_dom_freq_hz);
            fprintf(fid, '- I_osc_growth: %.6g\n', h.metrics.I_osc_growth);
            fprintf(fid, '- damping_ratio: %.6g\n', h.metrics.damping_ratio);
        end
        fprintf(fid, '\n');
    end
end
end
