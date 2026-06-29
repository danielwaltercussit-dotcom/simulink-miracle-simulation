function result = vsc_weakgrid_delay_benchmark_contract_test()
%VSC_WEAKGRID_DELAY_BENCHMARK_CONTRACT_TEST Tests for the D1 weak-grid GFL/GFM
%   delay-sensitivity + asymmetric-fault benchmark
%   (summarize_vsc_weakgrid_delay_benchmark).
%
%   Cases:
%     1) full parity-matched pair with delay sweep, asym fault, and F2/F3/M1
%        evidence -> parity matched, contract_complete, model_backed;
%     2) operating-point + grid-strength mismatch WITHOUT rationale -> parity
%        gate blocks the comparison (contract_status=blocked);
%     3) same mismatch WITH justified_differences -> parity passes;
%     4) solver mismatch without rationale -> parity blocks;
%     5) asymmetric-fault record MISSING -> contract blocked (required);
%     6) asym declared as label only (no artifact) -> WARN, contract incomplete;
%     7) single delay point -> not a sweep -> delay insufficient;
%     8) no F3/M1 evidence -> outcome insufficient_evidence, not model_backed;
%     9) only M1 evidence -> numerical_pseudo_instability;
%    10) only F3 evidence -> physical_instability;
%    11) both F3 and M1 -> mixed;
%    12) contract_status vs model_validation_status are independent: a complete
%        contract with no same-study time-domain artifacts is not model_backed.
%
%   No Simulink, no toolbox dependency. Scratch under
%   build/reports/d1_vsc_gfl_gfm/benchmark_scratch/, removed at end.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

scratch = fullfile(projectRoot, 'build', 'reports', 'd1_vsc_gfl_gfm', 'benchmark_scratch');
iResetDir(scratch);
cleanup = onCleanup(@() iRemoveDir(scratch));

% Shared same-study evidence files used by the positive cases.
ev = struct();
ev.td  = iTouch(fullfile(scratch, 'iter', 'emt', 'run.json'));
ev.f2  = iTouch(fullfile(scratch, 'iter', 'f2', 'margin_delay.json'));
ev.f3  = iTouch(fullfile(scratch, 'iter', 'f3', 'boundary.json'));
ev.m1  = iTouch(fullfile(scratch, 'iter', 'm1', 'solver_delay.json'));
ev.af  = iTouch(fullfile(scratch, 'iter', 'asym', 'slg.json'));

checks = struct([]);
checks = iAddCheck(checks, iCaseFullModelBacked(ev));
checks = iAddCheck(checks, iCaseParityOpMismatch(ev));
checks = iAddCheck(checks, iCaseParityJustified(ev));
checks = iAddCheck(checks, iCaseParitySolverMismatch(ev));
checks = iAddCheck(checks, iCaseAsymMissing(ev));
checks = iAddCheck(checks, iCaseAsymLabelOnly(ev));
checks = iAddCheck(checks, iCaseSingleDelayPoint(ev));
checks = iAddCheck(checks, iCaseInsufficientEvidence(ev));
checks = iAddCheck(checks, iCaseOnlyM1(ev));
checks = iAddCheck(checks, iCaseOnlyF3(ev));
checks = iAddCheck(checks, iCaseMixed(ev));
checks = iAddCheck(checks, iCaseStatusIndependence(ev));

allPass = all([checks.passed]);
fprintf('\n=== vsc_weakgrid_delay_benchmark_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), sum([checks.passed]), numel(checks));

result = struct('passed', allPass, 'checks', checks);
end


% ---- shared builders -----------------------------------------------------

function d = iCase(name, mode, sync, qmode, op, scr, step, ev)
d = struct();
d.case_name = name;
d.control_mode = mode;
d.evidence_source = 'simulated';
d.operating_point = op;
d.base_values = struct('s_base_mva', 100);
d.grid_strength = struct('scr', scr, 'method', 'thevenin_L');
d.synchronization = struct('type', sync);
d.active_power_control = struct('mode', 'p_setpoint');
d.reactive_power_control = struct('mode', qmode);
d.fault_ride_through = struct('artifact', ev.af, 'required', true);
d.time_domain_validation = struct('artifact', ev.td, 'required', true);
d.solver = struct('type', 'ode23tb', 'fixed_step_s', step);
d.declared_delays = struct('ctrl_comp_s', 1e-4, 'pwm_s', 5e-5);
end


function g = iGfl(ev), g = iCase('gfl', 'GFL', 'pll', 'q_setpoint', '0.8pu SCR=2', 2.0, 5e-5, ev); end
function g = iGfm(ev), g = iCase('gfm', 'GFM', 'vsg', 'v_droop', '0.8pu SCR=2', 2.0, 5e-5, ev); end


function cnd = iConditions()
cnd = struct('operating_point', '0.8pu SCR=2', 'disturbance', '3ph@1s', ...
    'solver', struct('type', 'ode23tb', 'fixed_step_s', 5e-5));
end


function dc = iDelaySweep()
dc = struct('label', {'d0', 'd1', 'd2'}, 'total_delay_s', {1e-4, 2e-4, 3e-4}, ...
    'outcome', {'stable', 'marginal', 'unstable'});
end


function af = iAsymRecord(ev)
af = struct('type', 'slg', 'negative_sequence_handled', true, ...
    'unbalance_factor_pct', 30, 'artifact', ev.af);
end


% ---- cases ---------------------------------------------------------------

function c = iCaseFullModelBacked(ev)
b = summarize_vsc_weakgrid_delay_benchmark(iGfl(ev), iGfm(ev), iConditions(), ...
    'DelayCases', iDelaySweep(), 'AsymmetricFaults', iAsymRecord(ev), ...
    'F2EvidencePath', ev.f2, 'F3EvidencePath', ev.f3, 'M1EvidencePath', ev.m1, ...
    'OutputDir', fullfile(fileparts(ev.td), 'bench'));
okParity = b.parity.matched && b.parity.n_unjustified_mismatch == 0;
okContract = strcmp(b.contract_status, 'contract_complete');
okModel = strcmp(b.model_validation_status, 'model_backed');
okFiles = isfile(fullfile(fileparts(ev.td), 'bench', 'vsc_weakgrid_delay_benchmark.md'));
c.name = 'Case 1: full parity-matched pair -> contract_complete + model_backed';
c.passed = okParity && okContract && okModel && okFiles;
c.detail = sprintf('parity=%d contract=%s model=%s files=%d', ...
    b.parity.matched, b.contract_status, b.model_validation_status, okFiles);
end


function c = iCaseParityOpMismatch(ev)
gfm = iGfm(ev);
gfm.operating_point = '1.0pu SCR=5';
gfm.grid_strength = struct('scr', 5.0, 'method', 'thevenin_L');
b = summarize_vsc_weakgrid_delay_benchmark(iGfl(ev), gfm, iConditions(), ...
    'DelayCases', iDelaySweep(), 'AsymmetricFaults', iAsymRecord(ev));
okBlocked = ~b.parity.matched && strcmp(b.contract_status, 'blocked');
okCount = b.parity.n_unjustified_mismatch == 2;   % op_point + grid_strength
c.name = 'Case 2: op-point + grid mismatch, no rationale -> parity blocks';
c.passed = okBlocked && okCount;
c.detail = sprintf('parity=%d n_unjust=%d(want2) contract=%s', ...
    b.parity.matched, b.parity.n_unjustified_mismatch, b.contract_status);
end


function c = iCaseParityJustified(ev)
gfm = iGfm(ev);
gfm.operating_point = '1.0pu SCR=5';
gfm.grid_strength = struct('scr', 5.0, 'method', 'thevenin_L');
cnd = iConditions();
cnd.justified_differences = {'operating_point', 'grid_strength'};
b = summarize_vsc_weakgrid_delay_benchmark(iGfl(ev), gfm, cnd, ...
    'DelayCases', iDelaySweep(), 'AsymmetricFaults', iAsymRecord(ev));
okMatched = b.parity.matched && b.parity.n_unjustified_mismatch == 0;
c.name = 'Case 3: same mismatch but justified in conditions -> parity passes';
c.passed = okMatched && strcmp(b.contract_status, 'contract_complete');
c.detail = sprintf('parity=%d n_unjust=%d contract=%s', ...
    b.parity.matched, b.parity.n_unjustified_mismatch, b.contract_status);
end


function c = iCaseParitySolverMismatch(ev)
gfm = iGfm(ev);
gfm.solver = struct('type', 'ode23tb', 'fixed_step_s', 2e-4);  % different step
b = summarize_vsc_weakgrid_delay_benchmark(iGfl(ev), gfm, iConditions(), ...
    'DelayCases', iDelaySweep(), 'AsymmetricFaults', iAsymRecord(ev));
solverAxis = b.parity.checks(arrayfun(@(x) strcmp(x.axis, 'solver'), b.parity.checks));
okSolverFail = ~solverAxis.matched && ~solverAxis.justified;
c.name = 'Case 4: solver step mismatch, no rationale -> parity blocks';
c.passed = okSolverFail && ~b.parity.matched && strcmp(b.contract_status, 'blocked');
c.detail = sprintf('solver_matched=%d parity=%d contract=%s', ...
    solverAxis.matched, b.parity.matched, b.contract_status);
end


function c = iCaseAsymMissing(ev)
b = summarize_vsc_weakgrid_delay_benchmark(iGfl(ev), iGfm(ev), iConditions(), ...
    'DelayCases', iDelaySweep());   % no AsymmetricFaults
okMissing = strcmp(b.asymmetric_faults.status, 'MISSING');
okBlocked = strcmp(b.contract_status, 'blocked');
c.name = 'Case 5: asymmetric-fault record absent -> required, contract blocked';
c.passed = okMissing && okBlocked;
c.detail = sprintf('asym=%s(want MISSING) contract=%s(want blocked)', ...
    b.asymmetric_faults.status, b.contract_status);
end


function c = iCaseAsymLabelOnly(ev)
af = struct('type', 'voltage_unbalance', 'negative_sequence_handled', true, ...
    'unbalance_factor_pct', 20);   % no artifact file
b = summarize_vsc_weakgrid_delay_benchmark(iGfl(ev), iGfm(ev), iConditions(), ...
    'DelayCases', iDelaySweep(), 'AsymmetricFaults', af);
okWarn = strcmp(b.asymmetric_faults.status, 'WARN');
okIncomplete = strcmp(b.contract_status, 'incomplete');
c.name = 'Case 6: asym declared without artifact -> WARN, contract incomplete';
c.passed = okWarn && okIncomplete;
c.detail = sprintf('asym=%s(want WARN) contract=%s(want incomplete)', ...
    b.asymmetric_faults.status, b.contract_status);
end


function c = iCaseSingleDelayPoint(ev)
dc = struct('label', 'only', 'total_delay_s', 1e-4);   % single point, not a sweep
b = summarize_vsc_weakgrid_delay_benchmark(iGfl(ev), iGfm(ev), iConditions(), ...
    'DelayCases', dc, 'AsymmetricFaults', iAsymRecord(ev), ...
    'F2EvidencePath', ev.f2, 'M1EvidencePath', ev.m1);
okInsuff = strcmp(b.delay_sensitivity.status, 'insufficient') && ~b.delay_sensitivity.is_sweep;
okNotModel = ~strcmp(b.model_validation_status, 'model_backed');
c.name = 'Case 7: single delay point -> not a sweep -> delay insufficient';
c.passed = okInsuff && okNotModel;
c.detail = sprintf('delay=%s is_sweep=%d model=%s', ...
    b.delay_sensitivity.status, b.delay_sensitivity.is_sweep, b.model_validation_status);
end


function c = iCaseInsufficientEvidence(ev)
b = summarize_vsc_weakgrid_delay_benchmark(iGfl(ev), iGfm(ev), iConditions(), ...
    'DelayCases', iDelaySweep(), 'AsymmetricFaults', iAsymRecord(ev));  % no F3/M1
okClass = strcmp(b.outcome_classification, 'insufficient_evidence');
okNotModel = ~strcmp(b.model_validation_status, 'model_backed');
c.name = 'Case 8: no F3/M1 evidence -> insufficient_evidence, not model_backed';
c.passed = okClass && okNotModel;
c.detail = sprintf('class=%s(want insufficient_evidence) model=%s', ...
    b.outcome_classification, b.model_validation_status);
end


function c = iCaseOnlyM1(ev)
b = summarize_vsc_weakgrid_delay_benchmark(iGfl(ev), iGfm(ev), iConditions(), ...
    'DelayCases', iDelaySweep(), 'AsymmetricFaults', iAsymRecord(ev), ...
    'M1EvidencePath', ev.m1);   % M1 only
c.name = 'Case 9: only M1 evidence -> numerical_pseudo_instability';
c.passed = strcmp(b.outcome_classification, 'numerical_pseudo_instability');
c.detail = sprintf('class=%s(want numerical_pseudo_instability)', b.outcome_classification);
end


function c = iCaseOnlyF3(ev)
b = summarize_vsc_weakgrid_delay_benchmark(iGfl(ev), iGfm(ev), iConditions(), ...
    'DelayCases', iDelaySweep(), 'AsymmetricFaults', iAsymRecord(ev), ...
    'F3EvidencePath', ev.f3);   % F3 only
c.name = 'Case 10: only F3 evidence -> physical_instability';
c.passed = strcmp(b.outcome_classification, 'physical_instability');
c.detail = sprintf('class=%s(want physical_instability)', b.outcome_classification);
end


function c = iCaseMixed(ev)
b = summarize_vsc_weakgrid_delay_benchmark(iGfl(ev), iGfm(ev), iConditions(), ...
    'DelayCases', iDelaySweep(), 'AsymmetricFaults', iAsymRecord(ev), ...
    'F3EvidencePath', ev.f3, 'M1EvidencePath', ev.m1);   % both
c.name = 'Case 11: both F3 and M1 evidence -> mixed';
c.passed = strcmp(b.outcome_classification, 'mixed');
c.detail = sprintf('class=%s(want mixed)', b.outcome_classification);
end


function c = iCaseStatusIndependence(ev)
% A complete contract whose cases have NO same-study time-domain artifact must
% not read model_backed: contract_status and model_validation_status are
% independent axes.
gfl = iGfl(ev); gfm = iGfm(ev);
gfl.time_domain_validation = struct('required', true);   % drop artifact -> WARN
gfm.time_domain_validation = struct('required', true);
b = summarize_vsc_weakgrid_delay_benchmark(gfl, gfm, iConditions(), ...
    'DelayCases', iDelaySweep(), 'AsymmetricFaults', iAsymRecord(ev), ...
    'F2EvidencePath', ev.f2, 'F3EvidencePath', ev.f3, 'M1EvidencePath', ev.m1);
okNotModel = strcmp(b.model_validation_status, 'not_model_backed');
% Contract can still be complete (modes ok, parity ok, sweep ok, asym PASS).
okContract = strcmp(b.contract_status, 'contract_complete');
c.name = 'Case 12: complete contract without same-study TD -> not model_backed';
c.passed = okNotModel && okContract;
c.detail = sprintf('contract=%s model=%s(want not_model_backed)', ...
    b.contract_status, b.model_validation_status);
end


% ---- utilities -----------------------------------------------------------

function p = iTouch(p)
parent = fileparts(p);
if ~isempty(parent) && ~isfolder(parent)
    mkdir(parent);
end
fid = fopen(p, 'w');
if fid >= 0
    fprintf(fid, '{"synthetic":true}\n');
    fclose(fid);
end
end


function iResetDir(d)
if isfolder(d)
    rmdir(d, 's');
end
mkdir(d);
end


function iRemoveDir(d)
if isfolder(d)
    rmdir(d, 's');
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
