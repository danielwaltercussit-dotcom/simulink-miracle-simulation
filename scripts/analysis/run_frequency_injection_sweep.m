function summary = run_frequency_injection_sweep(frequencyHz, trialFcn, varargin)
%RUN_FREQUENCY_INJECTION_SWEEP Execute sine-injection trials and estimate G(jw).
% trialFcn(frequencyHz, inputIndex, amplitude, settleCycles, measureCycles)
% must return a struct with time, input, and output numeric arrays.

arguments
    frequencyHz double
    trialFcn (1,1) function_handle
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
frequencyHz = reshape(frequencyHz, 1, []);
if isempty(frequencyHz) || any(~isfinite(frequencyHz)) || any(frequencyHz <= 0) || ...
        any(diff(frequencyHz) <= 0)
    error("FrequencySweep:InvalidGrid", ...
        "FrequencyHz must be finite, positive, and strictly increasing.");
end

nF = numel(frequencyHz);
nU = opts.InputCount;
firstTrial = trialFcn(frequencyHz(1), 1, opts.Amplitude, ...
    opts.SettleCycles, opts.MeasureCycles);
[~, ~, firstOutput] = iValidateTrial(firstTrial, 1);
nY = size(firstOutput,2);
G = complex(NaN(nY, nU, nF));
fitR2 = NaN(nY, nU, nF);
inputMagnitude = zeros(nU, nF);
outputNames = iNames(opts.OutputNames, nY, "y");

for k = 1:nF
    for j = 1:nU
        if k == 1 && j == 1
            trial = firstTrial;
        else
            trial = trialFcn(frequencyHz(k), j, opts.Amplitude, ...
                opts.SettleCycles, opts.MeasureCycles);
        end
        [t, u, y] = iValidateTrial(trial, j);
        if size(y,2) ~= nY
            error("FrequencySweep:OutputCountChanged", ...
                "Trial output count changed at %.6g Hz input %d.", frequencyHz(k), j);
        end
        [uPhasor, ~] = iPhasor(t, u(:,min(j,size(u,2))), frequencyHz(k), opts.MeasureCycles);
        inputMagnitude(j,k) = abs(uPhasor);
        if abs(uPhasor) <= opts.MinimumInputPhasor
            error("FrequencySweep:WeakInjection", ...
                "Input phasor is too small at %.6g Hz input %d.", frequencyHz(k), j);
        end
        for out = 1:size(y,2)
            [yPhasor, fitR2(out,j,k)] = iPhasor(t, y(:,out), ...
                frequencyHz(k), opts.MeasureCycles);
            G(out,j,k) = yPhasor / uPhasor;
        end
    end
end

inputNames = iNames(opts.InputNames, nU, "u");
mimo = iMimoMetrics(G);
summary = struct();
summary.case_name = char(opts.CaseName);
summary.status = char(iStatus(fitR2, opts.MinimumFitR2));
summary.generated_at = char(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss"));
summary.evidence_source = "active_sine_injection";
summary.response_kind = char(opts.ResponseKind);
summary.frequency_hz = frequencyHz;
summary.input_names = cellstr(inputNames);
summary.output_names = cellstr(outputNames);
summary.amplitude = opts.Amplitude;
summary.settle_cycles = opts.SettleCycles;
summary.measure_cycles = opts.MeasureCycles;
summary.input_phasor_magnitude = inputMagnitude;
summary.fit_r2 = fitR2;
summary.response_real = real(G);
summary.response_imag = imag(G);
summary.mimo = mimo;
summary.authority = "measured_frequency_response_requires_modal_or_time_domain_confirmation";
summary.response_complex = G;

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, summary);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("CaseName", "active_frequency_sweep", @(x) ischar(x) || isstring(x));
p.addParameter("ResponseKind", "response", @(x) ischar(x) || isstring(x));
p.addParameter("InputCount", 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.addParameter("InputNames", strings(1,0), @(x) iscellstr(x) || isstring(x));
p.addParameter("OutputNames", strings(1,0), @(x) iscellstr(x) || isstring(x));
p.addParameter("Amplitude", 0.01, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("SettleCycles", 5, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter("MeasureCycles", 5, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("MinimumInputPhasor", 1e-9, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("MinimumFitR2", 0.9, @(x) isnumeric(x) && isscalar(x));
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.CaseName = string(opts.CaseName);
opts.ResponseKind = string(opts.ResponseKind);
opts.InputNames = string(opts.InputNames);
opts.OutputNames = string(opts.OutputNames);
opts.OutputDir = string(opts.OutputDir);
end


function [t, u, y] = iValidateTrial(trial, inputIndex)
required = ["time", "input", "output"];
if ~isstruct(trial) || ~all(isfield(trial, required))
    error("FrequencySweep:TrialContract", ...
        "Trial %d must return time, input, and output fields.", inputIndex);
end
t = double(trial.time(:));
u = double(trial.input);
y = double(trial.output);
if isvector(u); u = u(:); end
if isvector(y); y = y(:); end
if size(u,1) ~= numel(t) || size(y,1) ~= numel(t) || numel(t) < 8
    error("FrequencySweep:TrialSize", ...
        "Trial time, input, and output rows must match and contain at least 8 samples.");
end
if any(~isfinite(t)) || any(~isfinite(u), "all") || any(~isfinite(y), "all") || ...
        any(diff(t) <= 0)
    error("FrequencySweep:TrialData", ...
        "Trial data must be finite and time must be strictly increasing.");
end
end


function [phasor, fitR2] = iPhasor(t, signal, frequency, measureCycles)
windowStart = t(end) - measureCycles / frequency;
keep = t >= windowStart;
if nnz(keep) < 8
    error("FrequencySweep:ShortWindow", ...
        "Fewer than 8 samples are available in the measurement window.");
end
tw = t(keep);
x = signal(keep);
omega = 2*pi*frequency;
basis = [cos(omega*tw), sin(omega*tw), ones(size(tw))];
coef = basis \ x;
fitted = basis * coef;
phasor = coef(1) - 1i*coef(2);
den = sum((x - mean(x)).^2);
if den <= eps
    fitR2 = NaN;
else
    fitR2 = 1 - sum((x - fitted).^2) / den;
end
end


function names = iNames(input, n, prefix)
names = string(input);
if isempty(names)
    names = string(prefix) + (1:n);
else
    names = reshape(names, 1, []);
end
if numel(names) ~= n
    error("FrequencySweep:NameCount", ...
        "Signal-name count must match the measured channel count.");
end
end


function metrics = iMimoMetrics(G)
[nY, nU, nF] = size(G);
sigmaMax = NaN(1, nF);
sigmaMin = NaN(1, nF);
conditionNumber = NaN(1, nF);
rgaReal = NaN(nY, nU, nF);
rgaImag = NaN(nY, nU, nF);
for k = 1:nF
    Gk = G(:,:,k);
    singular = svd(Gk);
    if ~isempty(singular)
        sigmaMax(k) = max(singular);
        sigmaMin(k) = min(singular);
        conditionNumber(k) = sigmaMax(k) / max(sigmaMin(k), eps);
    end
    if nY == nU
        rga = Gk .* pinv(Gk).';
        rgaReal(:,:,k) = real(rga);
        rgaImag(:,:,k) = imag(rga);
    end
end
metrics = struct("sigma_max", sigmaMax, "sigma_min", sigmaMin, ...
    "condition_number", conditionNumber, "rga_real", rgaReal, ...
    "rga_imag", rgaImag);
end


function status = iStatus(fitR2, minimumFit)
finiteFit = fitR2(isfinite(fitR2));
if isempty(finiteFit)
    status = "provisional_no_fit_metric";
elseif any(finiteFit < minimumFit)
    status = "provisional_low_fit";
else
    status = "ok";
end
end


function iWriteOutputs(outDir, summary)
if ~isfolder(outDir)
    mkdir(outDir);
end
diskSummary = rmfield(summary, "response_complex");
iWriteJson(fullfile(outDir, "frequency_sweep_summary.json"), diskSummary);
iWriteCsv(fullfile(outDir, "frequency_sweep_response.csv"), summary);
iWriteMarkdown(fullfile(outDir, "frequency_sweep_summary.md"), summary);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("FrequencySweep:CannotWrite", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteCsv(path, summary)
[nY, nU, nF] = size(summary.response_complex);
rows = nY * nU * nF;
FrequencyHz = zeros(rows,1);
Input = strings(rows,1);
Output = strings(rows,1);
RealPart = zeros(rows,1);
ImagPart = zeros(rows,1);
Magnitude = zeros(rows,1);
PhaseDeg = zeros(rows,1);
FitR2 = zeros(rows,1);
row = 0;
for k = 1:nF
    for j = 1:nU
        for out = 1:nY
            row = row + 1;
            value = summary.response_complex(out,j,k);
            FrequencyHz(row) = summary.frequency_hz(k);
            Input(row) = summary.input_names{j};
            Output(row) = summary.output_names{out};
            RealPart(row) = real(value);
            ImagPart(row) = imag(value);
            Magnitude(row) = abs(value);
            PhaseDeg(row) = angle(value) * 180/pi;
            FitR2(row) = summary.fit_r2(out,j,k);
        end
    end
end
writetable(table(FrequencyHz, Input, Output, RealPart, ImagPart, Magnitude, ...
    PhaseDeg, FitR2), path);
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("FrequencySweep:CannotWrite", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Active Frequency Sweep\n\n");
fprintf(fid, "Case: `%s`  \n", summary.case_name);
fprintf(fid, "Status: `%s`  \n", summary.status);
fprintf(fid, "Response kind: `%s`  \n", summary.response_kind);
fprintf(fid, "Inputs: %d; outputs: %d; frequencies: %d\n\n", ...
    numel(summary.input_names), numel(summary.output_names), numel(summary.frequency_hz));
fprintf(fid, "| Frequency Hz | Sigma max | Sigma min | Condition |\n");
fprintf(fid, "|---:|---:|---:|---:|\n");
for k = 1:numel(summary.frequency_hz)
    fprintf(fid, "| %.6g | %.6g | %.6g | %.6g |\n", summary.frequency_hz(k), ...
        summary.mimo.sigma_max(k), summary.mimo.sigma_min(k), ...
        summary.mimo.condition_number(k));
end
end
