function result = multirate_solver_contract_test()
%MULTIRATE_SOLVER_CONTRACT_TEST Contract + model-backed test for the M1 helper.
%   Exercises summarize_multirate_solver_plan across three status axes that must
%   stay independent:
%     contract_status         pass|provisional|fail (plan admissibility)
%     model_validation_status not_attempted|pass|fail (a real model run)
%     handoff_ready           gate = contract pass + model pass + no warnings
%
%   Cases:
%     A) documented well-sized plan, NO model run -> contract=pass but
%        model_validation_status=not_attempted and handoff_ready=FALSE
%        (a contract-admissible plan must never look like solver readiness)
%     B) finest step too coarse for the fastest event -> contract=fail
%     C) a fixed step >= stop time (impossible)        -> contract=fail
%     D) undocumented anchors (no fastest/slowest)     -> contract=provisional
%     E) solver_iterated algebraic loop on a fixed     -> contract=fail
%        partition
%     F) non-integer rate ratio + under-sampled slow   -> contract=pass with
%        mode (admissible-but-risky)                      warnings, NOT ready
%     G) MODEL-BACKED: a real tiny multirate model is built and
%        load/update/simulated; a successful probe -> model_validation_status=
%        pass and handoff_ready=TRUE
%     H) bare verified_against_model=true with NO probe evidence -> claim is
%        downgraded to a warning, model stays not_attempted, derived
%        verified_against_model=false, handoff_ready=FALSE
%     I) WARN-bearing plan WITH a passing probe -> model passes but warnings
%        still block handoff_ready=FALSE
%     J) a probe that ran but whose sim failed -> model_validation_status=fail,
%        handoff_ready=FALSE (contract_status unaffected)
%
%   Cases A-F and H-J use pure synthetic plans/probe structs (no Simulink).
%   Case G performs a REAL Simulink load/update/simulate through the tiny,
%   non-private probe under .agents/skills/.../probe/. If Simulink is
%   unavailable, Case G is reported as a skipped/known-gap check, not a pass.
%
%   Artifacts written under build/reports/m1_multirate_solver/<case>/.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));
addpath(fullfile(projectRoot, '.agents', 'skills', ...
    'hybrid-solver-multirate-simulation', 'probe'));

% Run the tiny model-backed probe ONCE (a real load/update/simulate) and reuse
% its evidence for the positive (G) and warn-blocks-handoff (I) cases.
probe = iRunModelProbe(projectRoot);

checks = struct([]);
checks = iAddCheck(checks, iCaseContractPassUnverified(projectRoot));
checks = iAddCheck(checks, iCaseFastestTooCoarse(projectRoot));
checks = iAddCheck(checks, iCaseStepExceedsStopTime(projectRoot));
checks = iAddCheck(checks, iCaseProvisional(projectRoot));
checks = iAddCheck(checks, iCaseAlgebraicLoopFail(projectRoot));
checks = iAddCheck(checks, iCaseWarningsOnly(projectRoot));
checks = iAddCheck(checks, iCaseModelBacked(projectRoot, probe));
checks = iAddCheck(checks, iCaseBareClaimNoProbe(projectRoot));
checks = iAddCheck(checks, iCaseWarnBlocksHandoff(projectRoot, probe));
checks = iAddCheck(checks, iCaseFailedProbe(projectRoot));

allPass = all([checks.passed]);
fprintf('\n=== multirate_solver_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), sum([checks.passed]), numel(checks));

result = struct('passed', allPass, 'checks', checks);
end


function c = iCaseContractPassUnverified(projectRoot)
% Three-rate hybrid: finest 2us resolves 10kHz (50 samp); coarsest 1ms
% over-samples a 1.2Hz mode (833 samp); integer rate ratio; loops broken.
% With NO model probe, this is contract-admissible but NOT solver-validated.
plan = iBasePlan();
outDir = fullfile(projectRoot, 'build', 'reports', 'm1_multirate_solver', 'synthetic_pass');
s = summarize_multirate_solver_plan(plan, 'OutputDir', outDir);

okContract = strcmp(s.contract_status, 'pass');
okNoFail = s.n_failures == 0;
okNoWarn = s.n_warnings == 0;
okNotAttempted = strcmp(s.model_validation_status, 'not_attempted');
okNotReady = s.handoff_ready == false;
okVerifFalse = s.verified_against_model == false;
okFiles = iArtifactsExist(outDir);

c.name = 'Case A: documented plan, no run -> contract pass but NOT handoff-ready';
c.passed = okContract && okNoFail && okNoWarn && okNotAttempted && ...
    okNotReady && okVerifFalse && okFiles;
c.detail = sprintf(['contract=%s (want pass) model=%s (want not_attempted) ', ...
    'handoff=%d (want 0) verified=%d (want 0) warn=%d artifacts=%d'], ...
    s.contract_status, s.model_validation_status, s.handoff_ready, ...
    s.verified_against_model, s.n_warnings, okFiles);
end


function c = iCaseFastestTooCoarse(projectRoot)
% Drop the fine EMT partition: finest step is now 5e-5 s, which gives only
% 2 samples per 10 kHz period -> fastest event unresolved -> failure.
plan = iBasePlan();
plan.partitions = plan.partitions(2:3);   % remove switching_emt
outDir = fullfile(projectRoot, 'build', 'reports', 'm1_multirate_solver', 'synthetic_fast_unresolved');
s = summarize_multirate_solver_plan(plan, 'OutputDir', outDir);

okStatus = strcmp(s.contract_status, 'fail');
okHasFail = s.n_failures >= 1;
okGlobal = iAnyIssue(s, 'failure', 'fastest event');

c.name = 'Case B: finest step too coarse for fastest event -> contract fail';
c.passed = okStatus && okHasFail && okGlobal;
c.detail = sprintf('contract=%s (want fail) fail=%d global_fast_fail=%d', ...
    s.contract_status, s.n_failures, okGlobal);
end


function c = iCaseStepExceedsStopTime(projectRoot)
% A fixed partition step >= stop time is impossible.
plan = iBasePlan();
plan.stop_time_s = 1e-3;            % shorter than the 1 ms macro step boundary
plan.partitions(3).step_s = 2e-3;  % 2 ms >= 1 ms stop time
outDir = fullfile(projectRoot, 'build', 'reports', 'm1_multirate_solver', 'synthetic_step_gt_stop');
s = summarize_multirate_solver_plan(plan, 'OutputDir', outDir);

okStatus = strcmp(s.contract_status, 'fail');
okImpossible = iAnyIssue(s, 'failure', '>= stop_time');

c.name = 'Case C: fixed step >= stop time (impossible) -> contract fail';
c.passed = okStatus && okImpossible;
c.detail = sprintf('contract=%s (want fail) impossible_flag=%d', s.contract_status, okImpossible);
end


function c = iCaseProvisional(projectRoot)
% Anchors undocumented: cannot validate cross-time-scale, but no impossible
% step either -> provisional, not pass and not fail.
plan = iBasePlan();
plan = rmfield(plan, 'fastest_event_hz');
plan = rmfield(plan, 'slowest_mode_hz');
outDir = fullfile(projectRoot, 'build', 'reports', 'm1_multirate_solver', 'synthetic_provisional');
s = summarize_multirate_solver_plan(plan, 'OutputDir', outDir);

okStatus = strcmp(s.contract_status, 'provisional');
okNoFail = s.n_failures == 0;
okMissing = any(strcmp(s.missing_required, 'fastest_event_hz')) && ...
            any(strcmp(s.missing_required, 'slowest_mode_hz'));
okFlag = s.provisional == true;

c.name = 'Case D: undocumented anchors -> contract provisional';
c.passed = okStatus && okNoFail && okMissing && okFlag;
c.detail = sprintf('contract=%s (want provisional) fail=%d missing=%d provisional=%d', ...
    s.contract_status, s.n_failures, okMissing, okFlag);
end


function c = iCaseAlgebraicLoopFail(projectRoot)
% A solver-iterated algebraic loop on a fixed/discrete partition is not well
% defined across sample times -> failure.
plan = iBasePlan();
plan.partitions(2).algebraic_loop = 'solver_iterated';   % control_avg is fixed
outDir = fullfile(projectRoot, 'build', 'reports', 'm1_multirate_solver', 'synthetic_algloop');
s = summarize_multirate_solver_plan(plan, 'OutputDir', outDir);

okStatus = strcmp(s.contract_status, 'fail');
okLoop = iAnyIssue(s, 'failure', 'algebraic loop');

c.name = 'Case E: solver_iterated loop on fixed partition -> contract fail';
c.passed = okStatus && okLoop;
c.detail = sprintf('contract=%s (want fail) algloop_flag=%d', s.contract_status, okLoop);
end


function c = iCaseWarningsOnly(projectRoot)
% Non-integer rate ratio + a coarsest step that under-samples a fast slow-mode.
% These are admissible-but-risky -> pass status with warnings, not a failure.
plan = iBasePlan();
plan.slowest_mode_hz = 40;            % 40 Hz "slow" mode vs ~1.3 ms coarsest step
plan.partitions(3).step_s = 1.33e-3;  % 1.33 ms / 5e-5 = 26.6x -> non-integer ratio
outDir = fullfile(projectRoot, 'build', 'reports', 'm1_multirate_solver', 'synthetic_warn');
s = summarize_multirate_solver_plan(plan, 'OutputDir', outDir);

okStatus = strcmp(s.contract_status, 'pass');     % warnings do not fail the plan
okNoFail = s.n_failures == 0;
okWarn = s.n_warnings >= 1;
okRatio = iAnyIssue(s, 'warning', 'non-integer');
okSlow = iAnyIssue(s, 'warning', 'under-samples the slow mode');
okNotReady = s.handoff_ready == false;   % warnings block handoff readiness

c.name = 'Case F: non-integer ratio + under-sampled slow mode -> contract pass w/ warnings, NOT ready';
c.passed = okStatus && okNoFail && okWarn && okRatio && okSlow && okNotReady;
c.detail = sprintf('contract=%s (want pass) fail=%d warn=%d ratio_w=%d slow_w=%d handoff=%d (want 0)', ...
    s.contract_status, s.n_failures, s.n_warnings, okRatio, okSlow, s.handoff_ready);
end


function plan = iBasePlan()
% Canonical documented three-rate hybrid plan used as the baseline for cases.
plan = struct( ...
    'case_name', 'synthetic_hybrid', ...
    'stop_time_s', 2.0, ...
    'fastest_event_hz', 10e3, ...      % 10 kHz PWM carrier
    'slowest_mode_hz', 1.2, ...        % ~1.2 Hz electromechanical swing
    'strategy', 'multi_solver', ...
    'verified_against_model', false, ...
    'partitions', struct( ...
        'name', {'switching_emt', 'control_avg', 'electromech'}, ...
        'solver', {'ode23tb', 'discrete', 'discrete'}, ...
        'step_kind', {'variable', 'fixed', 'fixed'}, ...
        'step_s', {NaN, 5e-5, 1e-3}, ...
        'max_step_s', {2e-6, NaN, NaN}, ...
        'algebraic_loop', {'none', 'unit_delay', 'none'}));
end


function probe = iRunModelProbe(projectRoot)
% Run the tiny non-private model probe once: a REAL load/update/simulate.
% Returns [] if Simulink is unavailable so Case G can report a known gap
% rather than a false pass.
probe = [];
if exist('build_and_run_tiny_multirate_probe', 'file') ~= 2
    return
end
if isempty(ver('simulink'))
    return
end
outDir = fullfile(projectRoot, 'build', 'reports', 'm1_multirate_solver', 'model_probe');
try
    probe = build_and_run_tiny_multirate_probe('OutputDir', outDir, 'StopTime', 0.05);
catch
    probe = [];
end
end


function c = iCaseModelBacked(projectRoot, probe)
% A REAL tiny multirate model was built and load/update/simulated. A
% successful probe must drive model_validation_status=pass and, with a clean
% contract and no warnings, handoff_ready=TRUE.
c.name = 'Case G: model-backed probe (real load/update/simulate) -> model pass + handoff-ready';
if isempty(probe)
    c.passed = false;
    c.detail = 'SKIPPED/KNOWN-GAP: Simulink unavailable or probe errored; no model-backed evidence (not a pass)';
    return
end
if ~probe.sim_success
    c.passed = false;
    c.detail = sprintf('probe ran but sim_success=0 (%s); investigate before claiming readiness', probe.notes);
    return
end

% Build a plan whose anchors match the model's ACTUAL rates so the evidence
% and the plan describe the same system.
plan = iModelMatchedPlan(probe);
outDir = fullfile(projectRoot, 'build', 'reports', 'm1_multirate_solver', 'model_backed');
s = summarize_multirate_solver_plan(plan, 'ModelProbe', probe, 'OutputDir', outDir);

okContract = strcmp(s.contract_status, 'pass');
okModel = strcmp(s.model_validation_status, 'pass');
okVerif = s.verified_against_model == true;
okReady = s.handoff_ready == true;
okProbeCopied = ~isempty(s.model_probe.model) && s.model_probe.sim_success;
okFiles = iArtifactsExist(outDir);

c.passed = okContract && okModel && okVerif && okReady && okProbeCopied && okFiles;
c.detail = sprintf(['contract=%s model=%s (want pass) verified=%d (want 1) ', ...
    'handoff=%d (want 1) model=`%s` max|y|=%.4g artifacts=%d'], ...
    s.contract_status, s.model_validation_status, s.verified_against_model, ...
    s.handoff_ready, s.model_probe.model, s.model_probe.max_abs_state, okFiles);
end


function c = iCaseBareClaimNoProbe(projectRoot)
% verified_against_model=true asserted with NO probe evidence. The claim must
% be downgraded to a warning, model stays not_attempted, derived
% verified_against_model=false, and the plan is NOT handoff-ready.
plan = iBasePlan();
plan.verified_against_model = true;     % unbacked claim
outDir = fullfile(projectRoot, 'build', 'reports', 'm1_multirate_solver', 'bare_claim');
s = summarize_multirate_solver_plan(plan, 'OutputDir', outDir);

okContract = strcmp(s.contract_status, 'pass');
okNotAttempted = strcmp(s.model_validation_status, 'not_attempted');
okVerifFalse = s.verified_against_model == false;   % claim NOT trusted
okWarned = iAnyIssue(s, 'warning', 'no ModelProbe evidence was attached');
okNotReady = s.handoff_ready == false;

c.name = 'Case H: bare verified-claim, no probe -> downgraded, NOT handoff-ready';
c.passed = okContract && okNotAttempted && okVerifFalse && okWarned && okNotReady;
c.detail = sprintf(['contract=%s model=%s (want not_attempted) verified=%d (want 0) ', ...
    'claim_warned=%d handoff=%d (want 0)'], ...
    s.contract_status, s.model_validation_status, s.verified_against_model, ...
    okWarned, s.handoff_ready);
end


function c = iCaseWarnBlocksHandoff(projectRoot, probe)
% Even with a PASSING model probe, an admissible-but-risky plan (warnings)
% must NOT be handoff-ready: model pass does not erase contract warnings.
c.name = 'Case I: passing probe + warnings -> model pass but NOT handoff-ready';
if isempty(probe) || ~probe.sim_success
    c.passed = false;
    c.detail = 'SKIPPED/KNOWN-GAP: no successful model probe to pair with warnings (not a pass)';
    return
end
plan = iModelMatchedPlan(probe);
% Inject a warning: make the coarsest discrete step under-sample the slow mode
% by declaring a fast slowest_mode_hz relative to the model's slow rate.
plan.slowest_mode_hz = 80;             % 80 Hz vs the model's ~5 ms coarsest step
outDir = fullfile(projectRoot, 'build', 'reports', 'm1_multirate_solver', 'warn_with_probe');
s = summarize_multirate_solver_plan(plan, 'ModelProbe', probe, 'OutputDir', outDir);

okModel = strcmp(s.model_validation_status, 'pass');
okWarn = s.n_warnings >= 1;
okNotReady = s.handoff_ready == false;

c.passed = okModel && okWarn && okNotReady;
c.detail = sprintf('model=%s (want pass) warn=%d (>=1) handoff=%d (want 0)', ...
    s.model_validation_status, s.n_warnings, s.handoff_ready);
end


function c = iCaseFailedProbe(projectRoot)
% A probe that ran but whose sim failed -> model_validation_status=fail and
% NOT handoff-ready; contract_status is unaffected (the plan is still
% admissible). Uses a synthetic failed-probe struct (no Simulink needed).
plan = iBasePlan();
failedProbe = struct('ran', true, 'sim_success', false, 'model', 'tiny_failed', ...
    'solver', 'ode23tb', 'stop_time_s', 0.05, 'max_abs_state', NaN, ...
    'notes', 'synthetic: simulation diverged');
outDir = fullfile(projectRoot, 'build', 'reports', 'm1_multirate_solver', 'failed_probe');
s = summarize_multirate_solver_plan(plan, 'ModelProbe', failedProbe, 'OutputDir', outDir);

okContract = strcmp(s.contract_status, 'pass');     % plan still admissible
okModelFail = strcmp(s.model_validation_status, 'fail');
okVerifFalse = s.verified_against_model == false;
okModelIssue = iAnyIssue(s, 'failure', 'did not succeed');
okNotReady = s.handoff_ready == false;

c.name = 'Case J: probe ran but sim failed -> model fail, NOT handoff-ready';
c.passed = okContract && okModelFail && okVerifFalse && okModelIssue && okNotReady;
c.detail = sprintf(['contract=%s (want pass) model=%s (want fail) verified=%d (want 0) ', ...
    'model_issue=%d handoff=%d (want 0)'], ...
    s.contract_status, s.model_validation_status, s.verified_against_model, ...
    okModelIssue, s.handoff_ready);
end


function plan = iModelMatchedPlan(probe)
% A documented, admissible plan whose anchors match the tiny model's actual
% rates: continuous + fast (1 ms) + slow (5 ms) discrete partitions.
fastHz = probe.fastest_event_hz;       % 1/1ms  = 1000 Hz
slowHz = probe.slowest_mode_hz / 25;   % keep coarsest step well over-sampled
if ~(isfinite(slowHz) && slowHz > 0); slowHz = 20; end
plan = struct( ...
    'case_name', 'model_matched_hybrid', ...
    'stop_time_s', probe.stop_time_s, ...
    'fastest_event_hz', fastHz, ...
    'slowest_mode_hz', slowHz, ...
    'strategy', 'multi_solver', ...
    'verified_against_model', false, ...
    'partitions', struct( ...
        'name', {'continuous_plant', 'fast_discrete', 'slow_discrete'}, ...
        'solver', {'ode23tb', 'discrete', 'discrete'}, ...
        'step_kind', {'variable', 'fixed', 'fixed'}, ...
        'step_s', {NaN, 1e-3, 5e-3}, ...
        'max_step_s', {1e-4, NaN, NaN}, ...
        'algebraic_loop', {'none', 'unit_delay', 'none'}));
end


function tf = iAnyIssue(s, severity, needle)
tf = false;
for k = 1:numel(s.issues)
    if strcmp(s.issues(k).severity, severity) && ...
            contains(s.issues(k).message, needle)
        tf = true;
        return
    end
end
end


function tf = iArtifactsExist(outDir)
tf = isfile(fullfile(outDir, 'multirate_solver_plan.md')) && ...
     isfile(fullfile(outDir, 'multirate_solver_plan.json')) && ...
     isfile(fullfile(outDir, 'partition_step_table.csv'));
end


function checks = iAddCheck(checks, c)
if isempty(checks)
    checks = c;
else
    checks(end+1) = c;
end
end


function t = iTag(passed)
if passed; t = 'PASS'; else; t = 'FAIL'; end
end
