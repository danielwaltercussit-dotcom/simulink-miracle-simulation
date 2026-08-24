function result = mathematical_analysis_closure_test()
%MATHEMATICAL_ANALYSIS_CLOSURE_TEST Synthetic modal, sweep, and MIMO checks.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(fullfile(projectRoot, "scripts", "analysis"));
addpath(fullfile(projectRoot, "scripts", "tuning"));
outRoot = fullfile(projectRoot, "build", "reports", ...
    "mathematical_analysis_closure_test");
cleanup = onCleanup(@() iCleanup(outRoot));

checks = repmat(struct("name", "", "passed", false), 1, 0);
checks(end+1) = iModalSensitivity(outRoot);
checks(end+1) = iModalCandidateVerification();
checks(end+1) = iSisoSweep(outRoot);
checks(end+1) = iMimoSweep(outRoot);
checks(end+1) = iCandidateSelection();

result = struct("passed", all([checks.passed]), "checks", checks);
for k = 1:numel(checks)
    fprintf("[%s] %s\n", iTag(checks(k).passed), checks(k).name);
end
fprintf("Overall: %s\n", iTag(result.passed));
end


function check = iModalSensitivity(outRoot)
values = [0.2 4.0]; % damping coefficient, stiffness
derivative = estimate_state_matrix_parameter_derivatives(values, @iOscillator, ...
    "ParameterNames", ["damping" "stiffness"], ...
    "LowerBounds", [0.01 1], "UpperBounds", [2 10]);
outDir = fullfile(outRoot, "modal");
summary = summarize_modal_parameter_sensitivity(derivative.A, derivative.dAdp, ...
    derivative.parameter_names, "ParameterValues", values, ...
    "ParameterScales", values, "LowerBounds", [0.01 1], ...
    "UpperBounds", [2 10], "TargetDampingRatio", 0.12, ...
    "StateNames", ["angle" "speed"], "MatrixSource", "synthetic_callback", ...
    "OperatingPoint", "constant synthetic equilibrium", "OutputDir", outDir);
expectedDC = [0 0; 0 -1];
expectedDK = [0 0; -1 0];
derivativeError = max(abs(derivative.dAdp(:,:,1) - expectedDC), [], "all") + ...
    max(abs(derivative.dAdp(:,:,2) - expectedDK), [], "all");
candidateInsideBounds = all(summary.recommendation.candidate_values >= [0.01 1]) && ...
    all(summary.recommendation.candidate_values <= [2 10]);
ok = strcmp(derivative.status, "ok") && derivativeError < 1e-9 && ...
    summary.d_damping_dp(1,1) > 0 && ...
    summary.recommendation.parameter_delta(1) > 0 && ...
    candidateInsideBounds && ...
    isfile(fullfile(outDir, "modal_parameter_sensitivity.json"));

Ts = 0.01;
discreteDerivative = estimate_state_matrix_parameter_derivatives(values, ...
    @(p) iDiscreteOscillator(p,Ts), 'ParameterNames', ["damping" "stiffness"], ...
    'LowerBounds', [0.01 1], 'UpperBounds', [2 10]);
discreteSummary = summarize_modal_parameter_sensitivity(discreteDerivative.A, ...
    discreteDerivative.dAdp, discreteDerivative.parameter_names, ...
    'ParameterValues', values, 'ParameterScales', values, ...
    'MatrixDomain', 'discrete', 'SampleTime', Ts, ...
    'TargetDampingRatio', 0.12);
ok = ok && discreteSummary.d_damping_dp(1,1) > 0;
check = struct("name", "modal dA/dp and damping-direction recommendation", ...
    "passed", ok);
end


function raw = iDiscreteOscillator(values,Ts)
continuous = iOscillator(values);
raw = struct('A',expm(continuous.A*Ts),'operating_point',continuous.operating_point);
end


function check = iModalCandidateVerification()
Ts = 0.01;
Apre = [0 1; -4 -0.2];
pre = summarize_modal_parameter_sensitivity(expm(Apre*Ts),{zeros(2)}, ...
    {'synthetic'},'MatrixDomain','discrete','SampleTime',Ts, ...
    'TargetDampingRatio',0.12);
analysis = struct('sensitivity',pre);
improved = verify_modal_candidate('',analysis,Ts,'Tolerance',1e-5, ...
    'LinearizeFcn',@() expm([0 1; -4 -0.3]*Ts));
degraded = verify_modal_candidate('',analysis,Ts,'Tolerance',1e-5, ...
    'LinearizeFcn',@() expm([0 1; -4 -0.1]*Ts));
belowTolerance = verify_modal_candidate('',analysis,Ts,'Tolerance',1e-5, ...
    'LinearizeFcn',@() expm([0 1; -4 -0.200001]*Ts));
jsonSafe = jsonencode(improved);
ok = improved.confirmed && strcmp(improved.status,'PASS') && ...
    ~degraded.confirmed && ~belowTolerance.confirmed && ...
    contains(jsonSafe,'post_pole_real');
check = struct('name','post-write re-linearization confirms or rejects modal movement', ...
    'passed',ok);
end


function raw = iOscillator(values)
c = values(1);
k = values(2);
raw = struct("A", [0 1; -k -c], "operating_point", [1; 0]);
end


function check = iSisoSweep(outRoot)
outDir = fullfile(outRoot, "siso");
summary = run_frequency_injection_sweep([0.5 1 2 4], @iSisoTrial, ...
    "InputNames", "command", "OutputNames", "response", ...
    "OutputDir", outDir);
expected = 2 ./ (1 + 1i * summary.frequency_hz / 2);
actual = reshape(summary.response_complex(1,1,:), 1, []);
relativeError = max(abs(actual - expected) ./ abs(expected));
ok = relativeError < 1e-6 && strcmp(summary.status, "ok") && ...
    isfile(fullfile(outDir, "frequency_sweep_summary.json"));
check = struct("name", "active SISO sweep reconstructs complex response", ...
    "passed", ok);
end


function trial = iSisoTrial(frequency, ~, amplitude, settleCycles, measureCycles)
t = iTime(frequency, settleCycles, measureCycles);
u = amplitude * sin(2*pi*frequency*t);
H = 2 / (1 + 1i*frequency/2);
y = amplitude * abs(H) * sin(2*pi*frequency*t + angle(H));
trial = struct("time", t, "input", u, "output", y);
end


function check = iMimoSweep(outRoot)
outDir = fullfile(outRoot, "mimo");
summary = run_frequency_injection_sweep([1 3], @iMimoTrial, ...
    "InputCount", 2, "InputNames", ["d" "q"], ...
    "OutputNames", ["id" "iq"], "OutputDir", outDir);
ok = all(isfinite(summary.mimo.condition_number)) && ...
    any(abs(summary.mimo.rga_real(1,2,:)) > 0.01, "all") && ...
    min(summary.fit_r2, [], "all") > 0.99;
check = struct("name", "active MIMO sweep emits RGA and singular-value evidence", ...
    "passed", ok);
end


function check = iCandidateSelection()
template = struct('id','','block_path','synthetic','mask_param','gain', ...
    'priority',1,'parameter_class','','control_only',true,'rollback_value',1, ...
    'fs_targets',{{'FS-014'}});
reg = repmat(template,1,2);
reg(1).id = 'pll';
reg(1).parameter_class = 'pll';
reg(2).id = 'current';
reg(2).parameter_class = 'current_pi';
sensitivity = struct('parameter_names',{{'pll','current'}}, ...
    'recommendation',struct('relative_step',[0.05 -0.05]), ...
    'd_damping_per_relative_change',[0.2 -0.1]);
neural = struct('candidate_parameter_classes',{{'current_pi'}}, ...
    'status','advisory_needs_gate', ...
    'forbidden_actions',{{'do_not_authorize_s6_tuning'}});
mathFirst = select_tuning_candidate(reg,'FS-014',sensitivity,neural);
sensitivity.d_damping_per_relative_change = [0.1 -0.1];
tieBreak = select_tuning_candidate(reg,'FS-014',sensitivity,neural);
neuralOnly = select_tuning_candidate(reg,'FS-014',struct(),neural);
explicitFallback = select_tuning_candidate(reg,'FS-014',struct(),neural, ...
    'AllowRuleFallback',true);
ok = strcmp(mathFirst.id,'pll') && ~mathFirst.neural_supported && ...
    strcmp(tieBreak.id,'current') && tieBreak.neural_supported && ...
    strcmp(tieBreak.source,'mathematical_sensitivity') && ...
    strcmp(neuralOnly.status,'NO_CANDIDATE') && ...
    strcmp(explicitFallback.status,'FALLBACK');
check = struct('name','mathematics ranks first and neural advice only breaks ties', ...
    'passed',ok);
end


function trial = iMimoTrial(frequency, inputIndex, amplitude, settleCycles, measureCycles)
t = iTime(frequency, settleCycles, measureCycles);
u = zeros(numel(t), 2);
u(:,inputIndex) = amplitude * sin(2*pi*frequency*t);
G = [1/(1+1i*frequency/3), 0.3/(1+1i*frequency/2); ...
     0.2/(1+1i*frequency/4), 1.2/(1+1i*frequency/3)];
y = zeros(numel(t), 2);
for out = 1:2
    H = G(out,inputIndex);
    y(:,out) = amplitude * abs(H) * sin(2*pi*frequency*t + angle(H));
end
trial = struct("time", t, "input", u, "output", y);
end


function t = iTime(frequency, settleCycles, measureCycles)
samplesPerCycle = 100;
t = (0:1/(frequency*samplesPerCycle):(settleCycles+measureCycles)/frequency).';
end


function iCleanup(path)
if isfolder(path)
    rmdir(path, "s");
end
end


function tag = iTag(passed)
if passed
    tag = "PASS";
else
    tag = "FAIL";
end
end
