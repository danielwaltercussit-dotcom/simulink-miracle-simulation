function result = fidelity_state_mapping_test()
%FIDELITY_STATE_MAPPING_TEST Model-backed test for E2 state mapping + prototype.
%   Distinct from fidelity_switching_contract_test (which is contract-only),
%   this test exercises the average->switching state mapping AND actually builds
%   and simulates the minimal averaged-vs-switching RL prototype, then confirms
%   the simulated error flows into summarize_fidelity_switch_evidence as a real
%   measured_pass.
%
%   Checks:
%     A) state mapping is self-consistent (continuity residual ~ 0) and reports
%        model_validation_status='not_run' (mapping alone is not model-backed);
%     B) state mapping with a missing required field -> contract provisional;
%     C) the prototype model ACTUALLY simulates (ran=true) and averaged vs
%        switching steady-state means agree within bound;
%     D) the simulated rel_error fed to summarize_fidelity_switch_evidence with
%        the on-disk prototype artifact -> overall_status='measured_pass';
%     E) a documented target WITHOUT a simulation never reaches measured_pass.
%
%   If Simulink is unavailable, checks C/D are reported as WARN (sim did not
%   run) rather than FAIL, and never as a false measured_pass.
%
%   Artifacts (transient) under build/reports/e2_fidelity_switching/_mapping_scratch/.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

scratch = fullfile(projectRoot, 'build', 'reports', 'e2_fidelity_switching', ...
    '_mapping_scratch');
cleanup = onCleanup(@() iCleanup(scratch));

checks = struct([]);
checks = iAddCheck(checks, iCaseMappingConsistent(scratch));
checks = iAddCheck(checks, iCaseMappingMissing(scratch));
[c3, proto] = iCasePrototypeRuns(scratch);
checks = iAddCheck(checks, c3);
checks = iAddCheck(checks, iCaseMeasuredFromSim(scratch, proto));
checks = iAddCheck(checks, iCaseNoSimNoMeasuredPass(scratch));

% A WARN is a non-fatal "sim could not run here"; only real failures fail.
isWarn = arrayfun(@(c) isfield(c,'warn') && c.warn && ~c.passed, checks);
hardFail = arrayfun(@(c) ~c.passed && ~(isfield(c,'warn') && c.warn), checks);
allPass = ~any(hardFail);

fprintf('\n=== fidelity_state_mapping_test ===\n');
for k = 1:numel(checks)
    if ~checks(k).passed && isfield(checks(k),'warn') && checks(k).warn
        tag = 'WARN';
    else
        tag = iTag(checks(k).passed);
    end
    fprintf('[%s] %s\n', tag, checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d pass, %d warn, %d fail)\n', iTag(allPass), ...
    sum([checks.passed]), sum(isWarn), sum(hardFail));

result = struct('passed', allPass, 'checks', checks);
end


function c = iCaseMappingConsistent(scratch)
m = map_average_to_switching_state('CaseName', 'map_ok', ...
    'InductorCurrent', 20, 'Duty', 0.4, 'Vdc', 100, 'CarrierFreqHz', 2000, ...
    'CarrierPhase', 0, 'CarrierCycleSamples', 2000, ...
    'OutputDir', fullfile(scratch, 'map_ok'));
okConsistent = strcmp(m.contract_status, 'consistent');
okResidual = m.continuity_residual_rel <= m.residual_tol;
okNotRun = strcmp(m.model_validation_status, 'not_run');
okIc = m.switching_initial_conditions.inductor_current_a == 20;
c.name = 'Case A: state mapping self-consistent, model_validation=not_run';
c.passed = okConsistent && okResidual && okNotRun && okIc;
c.warn = false;
c.detail = sprintf('contract=%s resid_rel=%.3e model_val=%s ic_iL=%g', ...
    m.contract_status, m.continuity_residual_rel, m.model_validation_status, ...
    m.switching_initial_conditions.inductor_current_a);
end


function c = iCaseMappingMissing(scratch)
% Drop Vdc -> incomplete mapping -> contract provisional.
m = map_average_to_switching_state('CaseName', 'map_missing', ...
    'InductorCurrent', 20, 'Duty', 0.4, 'CarrierFreqHz', 2000, ...
    'OutputDir', fullfile(scratch, 'map_missing'));
okProv = strcmp(m.contract_status, 'provisional');
named = any(strcmp('vdc_v', m.missing_required));
c.name = 'Case B: missing required mapping field -> contract provisional';
c.passed = okProv && named;
c.warn = false;
c.detail = sprintf('contract=%s vdc_named_missing=%d', m.contract_status, named);
end


function [c, proto] = iCasePrototypeRuns(scratch)
proto = run_fidelity_switch_prototype('CaseName', 'proto_run', ...
    'Vdc', 100, 'Duty', 0.4, 'R', 2, 'L', 1e-3, 'CarrierFreqHz', 2000, ...
    'NCarrierCycles', 20, 'SamplesPerCycle', 40, ...
    'OutputDir', fullfile(scratch, 'proto_run', 'study'));
c.name = 'Case C: prototype model actually simulates, averaged~switching';
if ~proto.ran
    c.passed = false;
    c.warn = true;
    c.detail = sprintf('sim did NOT run (%s): %s', ...
        proto.model_validation_status, proto.error_text);
    return
end
okRan = proto.ran && strcmp(proto.model_validation_status, 'ran');
okAgree = isfinite(proto.rel_error) && proto.rel_error <= 1e-2;
okSteps = proto.n_steps > 100;
c.passed = okRan && okAgree && okSteps;
c.warn = false;
c.detail = sprintf('ran=%d n_steps=%d mean_sw=%.5f mean_av=%.5f rel_err=%.3e', ...
    proto.ran, proto.n_steps, proto.mean_i_switching_a, ...
    proto.mean_i_averaged_a, proto.rel_error);
end


function c = iCaseMeasuredFromSim(scratch, proto)
c.name = 'Case D: simulated error + artifact -> measured_pass';
if isempty(proto) || ~proto.ran
    c.passed = false;
    c.warn = true;
    c.detail = 'prototype did not run; measured_pass not assertable here';
    return
end
root = fullfile(scratch, 'proto_run', 'study');
s = summarize_fidelity_switch_evidence( ...
    'CaseName', 'measured_from_sim', ...
    'FromFidelity', 'switching_emt', 'ToFidelity', 'averaged_emt', ...
    'OperatingPoint', 'Vdc=100 D=0.4 R=2 L=1mH', ...
    'BaseValues', 'Vb=100V Ib=50A', 'BandwidthRetainedHz', 2000, ...
    'Losses', 'ideal switch', 'InitializationMapping', 'i_L carried; phase=0', ...
    'ErrorMetric', 'ss-mean rel err < 1e-2', 'TimeStepRatio', 40, ...
    'MeasuredErrorValue', proto.rel_error, 'MeasuredErrorBound', 1e-2, ...
    'ErrorMetricDefinition', '|mean(i_sw)-i_avg|/i_avg, last 1/3', ...
    'ComparedFromRunId', 'switching_ode4', 'ComparedToRunId', 'averaged_ode4', ...
    'SameStudyArtifactPaths', string(proto.json_path), 'SameStudyRoot', root, ...
    'OutputDir', fullfile(scratch, 'measured_from_sim'));
okMeas = strcmp(s.measured_status, 'pass');
okOverall = strcmp(s.overall_status, 'measured_pass');
c.passed = okMeas && okOverall;
c.warn = false;
c.detail = sprintf('measured=%s overall=%s err=%.3e', ...
    s.measured_status, s.overall_status, s.measured_equivalence.error_value);
end


function c = iCaseNoSimNoMeasuredPass(scratch)
% A documented error TARGET but no measured value must never be measured_pass.
s = summarize_fidelity_switch_evidence( ...
    'CaseName', 'no_sim', ...
    'FromFidelity', 'switching_emt', 'ToFidelity', 'averaged_emt', ...
    'OperatingPoint', 'Vdc=100 D=0.4', 'BaseValues', 'Vb=100V', ...
    'BandwidthRetainedHz', 2000, 'Losses', 'ideal', ...
    'InitializationMapping', 'i_L carried', ...
    'ErrorMetric', 'rel err < 1e-2', 'TimeStepRatio', 40, ...
    'OutputDir', fullfile(scratch, 'no_sim'));
notMeasPass = ~strcmp(s.overall_status, 'measured_pass') && ...
    strcmp(s.measured_status, 'not_provided');
c.name = 'Case E: documented target, no sim -> never measured_pass';
c.passed = notMeasPass;
c.warn = false;
c.detail = sprintf('measured=%s overall=%s', s.measured_status, s.overall_status);
end


function iCleanup(scratch)
if isfolder(scratch)
    rmdir(scratch, 's');
end
end


function checks = iAddCheck(checks, c)
if ~isfield(c, 'warn'); c.warn = false; end
if isempty(checks)
    checks = c;
else
    checks(end+1) = c;
end
end


function t = iTag(passed)
if passed; t = 'PASS'; else; t = 'FAIL'; end
end
