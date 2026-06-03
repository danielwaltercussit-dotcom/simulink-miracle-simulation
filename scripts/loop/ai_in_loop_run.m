function status = ai_in_loop_run(varargin)
%AI_IN_LOOP_RUN  Drive the project AI-in-loop closed-loop pipeline.
%
%   status = ai_in_loop_run('goal','smoke','max_iter',5,'spec_path',spec, ...
%                           't_smoke',0.05,'t_full',1.0)
%
%   Goals (ordered, additive):
%     'smoke'  - build + compile + smoke sim
%     'tune'   - + load-flow / init / 1 s sim convergence checks
%     'sltest' - + run/create minimal sltest harness
%     'full'   - + screenshots + traceability refresh
%
%   This function sequences project skills; it does not replace them.
%   See docs/AI_IN_LOOP_WORKFLOW.md and .agents/skills/ai-in-loop/SKILL.md.
%
%   Artifacts: build/reports/loop/iter_<NN>/ + build/reports/loop/status.json

p = inputParser;
p.addParameter('goal','smoke',@(x)any(strcmp(x,{'smoke','tune','sltest','full'})));
p.addParameter('max_iter',5,@(x)isnumeric(x)&&x>0);
p.addParameter('spec_path','specs/case_ieee39_sg5_dfig5_v0.yaml',@(x)ischar(x)||isstring(x));
p.addParameter('t_smoke',0.05,@isnumeric);
p.addParameter('t_full',1.0,@isnumeric);
p.addParameter('model_name','ieee39_10m39bus_sg5_dfig5_nebus_layout',@(x)ischar(x)||isstring(x));
p.addParameter('build_fcn','build_ieee39_10m39bus_sg5_dfig5_nebus_layout',@(x)ischar(x)||isstring(x));
% Fast mode: skip layout reapplication and force-reuse existing model file
% on iter 0 even if its mtime is older than the build script. Intended for
% rapid debug cycles where the model file is known good and only spec or
% tuning is being iterated. Do NOT use after a build script change.
p.addParameter('fast',false,@(x)islogical(x)||isnumeric(x));
p.addParameter('snapshot',true,@(x)islogical(x)||isnumeric(x));
p.addParameter('snapshot_root',fullfile(getenv('USERPROFILE'),'Desktop','AI summary of simulation models'),@(x)ischar(x)||isstring(x));
p.parse(varargin{:});
opt = p.Results;
opt.fast = logical(opt.fast);
opt.snapshot = logical(opt.snapshot);

projectRoot = ai_in_loop_project_root();
loopRoot    = fullfile(projectRoot,'build','reports','loop');
if ~isfolder(loopRoot); mkdir(loopRoot); end

% Verify oracles (FS-008).
oracles = {fullfile(projectRoot,'NEBUS39V2.slx'), ...
           fullfile(projectRoot,'NE39bus_dataV2.m'), ...
           fullfile(projectRoot,'power_wind_dfig_avg.slx'), ...
           fullfile(projectRoot,'power_KundurTwoAreaSystem.slx')};
for k = 1:numel(oracles)
    if ~isfile(oracles{k})
        error('AIInLoop:MissingOracle','Missing oracle: %s', oracles{k});
    end
end

% Verify spec exists; downstream stages will validate content.
specAbs = fullfile(projectRoot, opt.spec_path);
if ~isfile(specAbs)
    error('AIInLoop:MissingSpec','Spec not found: %s', specAbs);
end

% Iteration loop.
prevSig = '';
prevFix = '';
for iter = 0:(opt.max_iter-1)
    iterDir = fullfile(loopRoot, sprintf('iter_%02d', iter));
    if ~isfolder(iterDir); mkdir(iterDir); end

    state = struct();
    state.iteration       = iter;
    state.goal            = opt.goal;
    state.spec_path       = char(opt.spec_path);
    state.model_name      = char(opt.model_name);
    state.t_smoke         = opt.t_smoke;
    state.t_full          = opt.t_full;
    state.evidence        = 'opened';
    state.failure_sig     = '';
    state.proposed_fix    = '';
    state.passed          = false;
    state.stages          = struct();
    state.started_at      = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));

    try
        % S1 SPEC
        state.stages.S1 = ai_in_loop_stage_spec(specAbs);
        ai_in_loop_require_stage_pass(state.stages.S1, false);

        % S2 BUILD - we do not regenerate model on iter 0 if it already
        % exists and goal is smoke/tune (avoid redundant rebuilds). Force
        % rebuild on iter > 0 because we just changed something.
        % In fast mode, never force rebuild on iter 0 even if the build
        % script is newer than the .slx (caller asserts the .slx is good).
        forceRebuild = iter > 0;
        if opt.fast && iter == 0
            forceRebuild = false;
        end
        state.stages.S2 = ai_in_loop_stage_build(projectRoot, opt.build_fcn, opt.model_name, forceRebuild, specAbs);
        ai_in_loop_require_stage_pass(state.stages.S2, false);

        % S3 LAYOUT - report only; layout is baked in build for this case.
        % In fast mode, skip the layout audit on iter 0 to save 5-10 s.
        if opt.fast && iter == 0
            state.stages.S3 = struct('name','S3_LAYOUT','status','SKIPPED', ...
                'note','fast mode: layout audit skipped on iter 0');
        else
            state.stages.S3 = ai_in_loop_stage_layout(projectRoot, opt.model_name);
        end
        ai_in_loop_require_stage_pass(state.stages.S3, opt.fast && iter == 0);

        % S4 COMPILE
        state.stages.S4 = ai_in_loop_stage_compile(opt.model_name);
        ai_in_loop_require_stage_pass(state.stages.S4, false);
        state.evidence  = 'compiled';

        % S5 SMOKE
        state.stages.S5 = ai_in_loop_stage_smoke(opt.model_name, opt.t_smoke);
        ai_in_loop_require_stage_pass(state.stages.S5, false);
        state.evidence  = 'simulated';

        % S6 TUNE
        if any(strcmp(opt.goal, {'tune','sltest','full'}))
            tuningReport = fullfile(iterDir, 'tuning_report.md');
            state.stages.S6 = ai_in_loop_stage_tune(projectRoot, opt.model_name, opt.t_full, ...
                'ReportPath', tuningReport);
            ai_in_loop_require_stage_pass(state.stages.S6, false);
            state.evidence  = 'measured';
        end

        % S7 SLTEST
        if any(strcmp(opt.goal, {'sltest','full'}))
            state.stages.S7 = ai_in_loop_stage_sltest(projectRoot, opt.model_name, iterDir, opt.t_smoke);
            ai_in_loop_require_stage_pass(state.stages.S7, false);
        end

        % S7B MODEL ADVISOR — independent gate. Soft-skips if license/product
        % unavailable; raises AIInLoop:ModelAdvisorFail (FS-016) on fail.
        if any(strcmp(opt.goal, {'sltest','full'}))
            state.stages.S7B = ai_in_loop_stage_modeladvisor(projectRoot, opt.model_name, iterDir);
            ai_in_loop_require_stage_pass(state.stages.S7B, true);
        end

        % S9 REPORT (success path)
        state.passed = true;
        state.update = strcmp(state.stages.S4.status, 'PASS');
        state.smoke  = strcmp(state.stages.S5.status, 'PASS');
        if isfield(state.stages, 'S6')
            state.tune = strcmp(state.stages.S6.status, 'PASS');
        end
        state.stages.S9 = struct('name','S9_REPORT','status','PENDING');
        ai_in_loop_write_report(iterDir, state);
        state.stages.S9 = ai_in_loop_stage_report_verify(projectRoot, iterDir, state);
        ai_in_loop_require_stage_pass(state.stages.S9, false);
        if opt.snapshot
            state.stages.S10 = ai_in_loop_snapshot_summary(projectRoot, opt.model_name, ...
                opt.spec_path, opt.build_fcn, iterDir, opt.snapshot_root);
            ai_in_loop_require_stage_pass(state.stages.S10, false);
        end
        ai_in_loop_write_report(iterDir, state);
        ai_in_loop_update_top_status(loopRoot, iterDir, state);
        status = state;
        fprintf('[ai-in-loop] iter %02d PASS goal=%s\n', iter, opt.goal);
        return
    catch ME
        % S8 DIAGNOSE
        [sig, fix] = ai_in_loop_diagnose(ME);
        state.failure_sig  = sig;
        state.proposed_fix = fix;
        state.error_msg    = ME.message;
        state.error_id     = ME.identifier;
        ai_in_loop_write_report(iterDir, state);
        ai_in_loop_update_top_status(loopRoot, iterDir, state);

        % FS-007: same sig + same fix twice in a row → stop.
        if iter > 0 && strcmp(sig, prevSig) && strcmp(fix, prevFix)
            warning('AIInLoop:StuckSignature', ...
                'Same failure signature and fix repeated. Stopping. See %s', iterDir);
            status = state;
            return
        end
        prevSig = sig; prevFix = fix;
        fprintf('[ai-in-loop] iter %02d FAIL sig=%s fix=%s\n', iter, sig, fix);
    end
end

warning('AIInLoop:MaxIterReached', ...
    'Reached max_iter=%d without success. Latest report under %s', opt.max_iter, loopRoot);
status = state;
end

function root = ai_in_loop_project_root()
% Resolve the project root in a path-independent way.
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));   % scripts/loop -> scripts -> project
end

function ai_in_loop_require_stage_pass(stage, allowSkipped)
%AI_IN_LOOP_REQUIRE_STAGE_PASS  Convert soft stage structs into hard gates.
if ~isfield(stage, 'status')
    error('AIInLoop:StageStatusMissing', 'Stage %s did not return a status field.', stage.name);
end
status = char(stage.status);
if strcmp(status, 'PASS')
    return
end
if allowSkipped && strcmp(status, 'SKIPPED')
    return
end
note = '';
if isfield(stage, 'note'); note = char(stage.note); end
if isfield(stage, 'error'); note = char(stage.error); end
error('AIInLoop:StageFailed', 'Stage %s did not pass: status=%s. %s', ...
    char(stage.name), status, note);
end
