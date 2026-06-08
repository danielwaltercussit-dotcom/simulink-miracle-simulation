function result = hil_readiness_model_backed_test()
%HIL_READINESS_MODEL_BACKED_TEST Model-backed validation for the M2 adapter.
%   Builds tiny SYNTHETIC models (nothing copied from any private model),
%   actually loads/updates/simulates them through hil_readiness_from_model, and
%   asserts the model-backed status semantics.
%
%   This test produces MODEL-BACKED evidence (a real model is compiled and
%   simulated). It still does NOT prove real-time execution on hardware:
%   real_time_deployable stays false because no HIL evidence is attached.
%
%   Cases:
%     A) RT-friendly demo: fixed-step, two discrete rates, 0 continuous states.
%        -> model_validation_status=model_backed, provenance.simulated=true,
%           fastest_event read from the compiled 20us rate,
%           real_time_deployable=false (no hardware evidence).
%     B) Non-RT demo: variable-step + continuous Integrator.
%        -> model_backed, but fixed_step_feasibility WARN and a continuous
%           state present, so handoff_ready=false.
%     C) Contract-only manifest (no model) still reports not_model_backed,
%        proving the new field defaults honestly.
%
%   Artifacts under build/reports/m2_hil_readiness/model_backed/<case>/.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

checks = struct([]);
checks = iAddCheck(checks, iCaseRt(projectRoot));
checks = iAddCheck(checks, iCaseNonRt(projectRoot));
checks = iAddCheck(checks, iCaseContractOnlyDefault(projectRoot));

allPass = all([checks.passed]);
fprintf('\n=== hil_readiness_model_backed_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), nnz([checks.passed]), numel(checks));
result = struct('passed', allPass, 'checks', checks);
end


function c = iCaseRt(projectRoot)
modelsDir = fullfile(projectRoot, 'build', 'reports', 'm2_hil_readiness', 'models');
outDir = fullfile(projectRoot, 'build', 'reports', 'm2_hil_readiness', 'model_backed', 'rt');
info = hil_build_demo_rt_model("rt", modelsDir);
clean = onCleanup(@() iCloseModel(info.model));

% Supply the physical fastest event (100us) the target must resolve; the 20us
% compiled step resolves it 5x. compute_s is not measurable by a software probe
% so latency stays MISSING (non-blocking) - we assert the step check, not latency.
s = hil_readiness_from_model(info.path, 'OutputDir', outDir, ...
    'Simulate', true, 'FastestEventS', 100e-6, 'CpuCores', 2, ...
    'UnsupportedBlocks', {});

mp = s.model_provenance;
okBacked  = strcmp(s.model_validation_status, 'model_backed');
okCompile = mp.compiled_ok == true;
okSim     = mp.simulated == true;
okRates   = isequal(sort(mp.discrete_rates_s(:)), [20e-6; 100e-6]);
okStep    = iCheckStatus(s, 'fixed_step_feasibility', 'PASS');
okNotDeploy = s.real_time_deployable == false;   % no hardware evidence
okFiles   = iArtifactsExist(outDir);

c.name = 'Case A: RT demo -> model_backed, simulated, not hardware-deployable';
c.passed = okBacked && okCompile && okSim && okRates && okStep && okNotDeploy && okFiles;
c.detail = sprintf(['status=%s(backed:%d) compiled=%d simulated=%d rates=%s ', ...
    'stepPASS=%d deployable=%d(want0) files=%d'], s.model_validation_status, ...
    okBacked, mp.compiled_ok, mp.simulated, mat2str(mp.discrete_rates_s), ...
    okStep, s.real_time_deployable, okFiles);
end


function c = iCaseNonRt(projectRoot)
modelsDir = fullfile(projectRoot, 'build', 'reports', 'm2_hil_readiness', 'models');
outDir = fullfile(projectRoot, 'build', 'reports', 'm2_hil_readiness', 'model_backed', 'nonrt');
info = hil_build_demo_rt_model("nonrt", modelsDir);
clean = onCleanup(@() iCloseModel(info.model));

s = hil_readiness_from_model(info.path, 'OutputDir', outDir, 'Simulate', true);

mp = s.model_provenance;
okBacked   = strcmp(s.model_validation_status, 'model_backed');
okCompile  = mp.compiled_ok == true;
okCont     = mp.n_continuous_states >= 1;        % Integrator -> continuous state
okStepWarn = iCheckStatus(s, 'fixed_step_feasibility', 'WARN');  % variable-step
okHandoff  = s.handoff_ready == false;

c.name = 'Case B: non-RT demo -> model_backed but blocked (var-step + cont state)';
c.passed = okBacked && okCompile && okCont && okStepWarn && okHandoff;
c.detail = sprintf('status=%s nCont=%d stepWARN=%d handoff=%d(want0)', ...
    s.model_validation_status, mp.n_continuous_states, okStepWarn, s.handoff_ready);
end


function c = iCaseContractOnlyDefault(projectRoot)
% A hand-supplied manifest (no model) must report not_model_backed. Fields are
% only enough to make the point; contract_status is asserted loosely (it must
% NOT be model_backed regardless of how complete the metadata is).
outDir = fullfile(projectRoot, 'build', 'reports', 'm2_hil_readiness', 'model_backed', 'contract_only');
m = struct('case_name', 'contract_only_default', ...
    'solver_type', 'fixed_step', 'fixed_step_s', 20e-6, 'fastest_event_s', 100e-6, ...
    'algebraic_loops_present', false, 'unsupported_blocks_checked', true, ...
    'unsupported_blocks', {{}}, 'codegen_target_supported', true, ...
    'continuous_states_present', false);
s = summarize_hil_readiness(m, 'OutputDir', outDir);

okNotBacked = strcmp(s.model_validation_status, 'not_model_backed');
okHasField  = isfield(s, 'model_validation_status');

c.name = 'Case C: contract-only manifest -> not_model_backed (honest default)';
c.passed = okNotBacked && okHasField;
c.detail = sprintf('model_validation_status=%s(want not_model_backed) contract=%s', ...
    s.model_validation_status, s.contract_status);
end


function tf = iCheckStatus(summary, checkName, wantStatus)
tf = false;
for k = 1:numel(summary.checks)
    if strcmp(summary.checks(k).name, checkName)
        tf = strcmp(summary.checks(k).status, wantStatus);
        return
    end
end
end


function tf = iArtifactsExist(outDir)
tf = isfile(fullfile(outDir, 'hil_readiness_summary.md')) && ...
     isfile(fullfile(outDir, 'hil_readiness_summary.json'));
end


function iCloseModel(mdl)
try
    if bdIsLoaded(mdl)
        close_system(mdl, 0);
    end
catch
end
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
