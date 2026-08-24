function result = mathematical_analysis_closure_test()
%MATHEMATICAL_ANALYSIS_CLOSURE_TEST Synthetic modal, sweep, and MIMO checks.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(fullfile(projectRoot, "scripts", "analysis"));
outRoot = fullfile(projectRoot, "build", "reports", ...
    "mathematical_analysis_closure_test");
cleanup = onCleanup(@() iCleanup(outRoot));

checks = struct([]);
checks(end+1) = iModalSensitivity(outRoot);
checks(end+1) = iSisoSweep(outRoot);
checks(end+1) = iMimoSweep(outRoot);

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
check = struct("name", "modal dA/dp and damping-direction recommendation", ...
    "passed", ok);
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
