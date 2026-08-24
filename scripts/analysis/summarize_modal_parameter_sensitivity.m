function summary = summarize_modal_parameter_sensitivity(A, dAdp, parameterNames, varargin)
%SUMMARIZE_MODAL_PARAMETER_SENSITIVITY Rank control parameters by modal effect.
% dAdp is an N-by-N-by-P array or a P-element cell array. Each slice is the
% derivative of the continuous-time state matrix with respect to one parameter.

arguments
    A double {mustBeSquare}
    dAdp
    parameterNames
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
n = size(A, 1);
names = string(parameterNames);
names = reshape(names, 1, []);
dA = iNormalizeDerivatives(dAdp, n, numel(names));
p = numel(names);
values = iNumericRow(opts.ParameterValues, p, 0, "ParameterValues");
scales = iNumericRow(opts.ParameterScales, p, NaN, "ParameterScales");
missingScale = ~isfinite(scales) | scales <= 0;
scales(missingScale) = max(abs(values(missingScale)), 1);
lower = iNumericRow(opts.LowerBounds, p, -Inf, "LowerBounds");
upper = iNumericRow(opts.UpperBounds, p, Inf, "UpperBounds");
stateNames = iStateNames(opts.StateNames, n);

[V, D, W] = eig(A);
lambda = diag(D);
physicalPole = iPhysicalPole(lambda, opts);
representative = find(imag(physicalPole) > opts.ModeImagTolerance);
if isempty(representative)
    representative = (1:n).';
end
zeta = iDamping(physicalPole);
[~, order] = sortrows([zeta(representative), real(physicalPole(representative))], [1 -2]);
representative = representative(order);
representative = representative(1:min(opts.MaxModes, numel(representative)));
m = numel(representative);

dLambdaReal = NaN(m, p);
dLambdaImag = NaN(m, p);
dDamping = NaN(m, p);
dFrequency = NaN(m, p);
mode = repmat(iEmptyMode(), 1, m);
warnings = strings(0, 1);

for row = 1:m
    idx = representative(row);
    den = W(:,idx)' * V(:,idx);
    if abs(den) <= opts.BiorthogonalityTolerance
        warnings(end+1) = "mode_" + idx + "_ill_conditioned_left_right_pair"; %#ok<AGROW>
    end
    mode(row) = iBuildMode(idx, physicalPole(idx), V(:,idx), W(:,idx), ...
        stateNames, opts.DampingThreshold, den);
    for col = 1:p
        if abs(den) <= opts.BiorthogonalityTolerance
            continue
        end
        derivative = (W(:,idx)' * dA(:,:,col) * V(:,idx)) / den;
        if opts.MatrixDomain == "discrete"
            if abs(lambda(idx)) <= opts.DiscretePoleTolerance
                derivative = NaN;
            else
                derivative = derivative / (opts.SampleTime * lambda(idx));
            end
        end
        dLambdaReal(row,col) = real(derivative);
        dLambdaImag(row,col) = imag(derivative);
        [dDamping(row,col), dFrequency(row,col)] = ...
            iDerivedMetricSensitivity(physicalPole(idx), derivative);
    end
end

normalizedDamping = dDamping .* scales;
recommendation = iRecommendStep(mode, normalizedDamping, names, values, scales, ...
    lower, upper, opts.TargetDampingRatio, opts.MaxRelativeStep);

summary = struct();
summary.case_name = char(opts.CaseName);
summary.status = char(iStatus(recommendation, warnings));
summary.generated_at = char(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss"));
summary.matrix_source = char(opts.MatrixSource);
summary.matrix_domain = char(opts.MatrixDomain);
summary.sample_time = opts.SampleTime;
summary.operating_point = char(opts.OperatingPoint);
summary.n_states = n;
summary.parameter_names = cellstr(names);
summary.parameter_values = values;
summary.parameter_scales = scales;
summary.modes = mode;
summary.d_lambda_real_dp = dLambdaReal;
summary.d_lambda_imag_dp = dLambdaImag;
summary.d_damping_dp = dDamping;
summary.d_frequency_hz_dp = dFrequency;
summary.d_damping_per_relative_change = normalizedDamping;
summary.recommendation = recommendation;
summary.warnings = cellstr(warnings);
summary.authority = "advisory_direction_requires_model_backed_validation";

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, summary);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("CaseName", "modal_parameter_sensitivity", @(x) ischar(x) || isstring(x));
p.addParameter("StateNames", strings(1,0), @(x) iscellstr(x) || isstring(x));
p.addParameter("ParameterValues", [], @isnumeric);
p.addParameter("ParameterScales", [], @isnumeric);
p.addParameter("LowerBounds", [], @isnumeric);
p.addParameter("UpperBounds", [], @isnumeric);
p.addParameter("DampingThreshold", 0.05, @(x) isnumeric(x) && isscalar(x));
p.addParameter("TargetDampingRatio", 0.08, @(x) isnumeric(x) && isscalar(x));
p.addParameter("MaxRelativeStep", 0.1, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("MaxModes", 12, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.addParameter("ModeImagTolerance", 1e-8, @(x) isnumeric(x) && isscalar(x));
p.addParameter("BiorthogonalityTolerance", 1e-10, @(x) isnumeric(x) && isscalar(x));
p.addParameter("MatrixSource", "", @(x) ischar(x) || isstring(x));
p.addParameter("MatrixDomain", "continuous", ...
    @(x) any(strcmpi(string(x), ["continuous" "discrete"])));
p.addParameter("SampleTime", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("DiscretePoleTolerance", 1e-9, ...
    @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("OperatingPoint", "", @(x) ischar(x) || isstring(x));
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.CaseName = string(opts.CaseName);
opts.StateNames = string(opts.StateNames);
opts.MatrixSource = string(opts.MatrixSource);
opts.MatrixDomain = lower(string(opts.MatrixDomain));
opts.OperatingPoint = string(opts.OperatingPoint);
opts.OutputDir = string(opts.OutputDir);
if opts.MatrixDomain == "discrete" && ~(isfinite(opts.SampleTime) && opts.SampleTime > 0)
    error("ModalSensitivity:SampleTime", ...
        "A positive SampleTime is required for a discrete state matrix.");
end
end


function dA = iNormalizeDerivatives(input, n, p)
if iscell(input)
    if numel(input) ~= p
        error("ModalSensitivity:DerivativeCount", ...
            "dAdp must contain one derivative matrix per parameter.");
    end
    dA = zeros(n, n, p);
    for k = 1:p
        dA(:,:,k) = input{k};
    end
else
    dA = input;
end
validSize = size(dA,1) == n && size(dA,2) == n && size(dA,3) == p && ndims(dA) <= 3;
if ~isnumeric(dA) || ~validSize || any(~isfinite(dA), "all")
    error("ModalSensitivity:InvalidDerivatives", ...
        "dAdp must be finite N-by-N-by-P numeric data.");
end
end


function row = iNumericRow(input, n, defaultValue, fieldName)
if isempty(input)
    row = repmat(defaultValue, 1, n);
    return
end
row = reshape(double(input), 1, []);
if numel(row) ~= n
    error("ModalSensitivity:InvalidOptionSize", ...
        "%s must have one value per parameter.", fieldName);
end
end


function names = iStateNames(input, n)
names = string(input);
if isempty(names)
    names = "x" + (1:n);
    return
end
names = reshape(names, 1, []);
if numel(names) ~= n
    error("ModalSensitivity:StateNameCount", ...
        "StateNames must have one entry per state.");
end
end


function zeta = iDamping(lambda)
mag = abs(lambda);
zeta = NaN(size(lambda));
valid = mag > eps;
zeta(valid) = -real(lambda(valid)) ./ mag(valid);
end


function pole = iPhysicalPole(lambda, opts)
if opts.MatrixDomain == "discrete"
    pole = NaN(size(lambda));
    keep = abs(lambda) > opts.DiscretePoleTolerance;
    pole(keep) = log(lambda(keep)) / opts.SampleTime;
else
    pole = lambda;
end
end


function [dZeta, dFreq] = iDerivedMetricSensitivity(lambda, dLambda)
a = real(lambda);
b = imag(lambda);
da = real(dLambda);
db = imag(dLambda);
r = abs(lambda);
if r <= eps
    dZeta = NaN;
else
    dZeta = -da / r + a * (a * da + b * db) / r^3;
end
if abs(b) <= eps
    dFreq = 0;
else
    dFreq = sign(b) * db / (2*pi);
end
end


function mode = iBuildMode(index, lambda, rightVec, leftVec, stateNames, threshold, den)
zeta = iDamping(lambda);
participation = abs(rightVec .* conj(leftVec));
if sum(participation) > 0
    participation = participation ./ sum(participation);
end
[~, order] = sort(participation, "descend");
order = order(1:min(5, numel(order)));
topStates = cell(1, numel(order));
for k = 1:numel(order)
    topStates{k} = sprintf("%s (%.3g)", stateNames(order(k)), participation(order(k)));
end
label = "stable";
if real(lambda) > 0
    label = "unstable";
elseif abs(imag(lambda)) > 0 && zeta < threshold
    label = "low_damping";
end
mode = struct("source_index", index, "real", real(lambda), ...
    "imag", imag(lambda), "frequency_hz", abs(imag(lambda))/(2*pi), ...
    "damping_ratio", zeta, "label", char(label), ...
    "biorthogonality", abs(den), "top_participating_states", {topStates});
end


function mode = iEmptyMode()
mode = struct("source_index", 0, "real", 0, "imag", 0, ...
    "frequency_hz", 0, "damping_ratio", 0, "label", "", ...
    "biorthogonality", 0, "top_participating_states", {{}});
end


function rec = iRecommendStep(modes, S, names, values, scales, lower, upper, target, maxStep)
zeta = [modes.damping_ratio].';
critical = isfinite(zeta) & (zeta < target | [modes.real].' > 0);
usable = critical & all(isfinite(S), 2);
rec = struct("status", "not_needed", "target_damping_ratio", target, ...
    "critical_mode_rows", find(critical).', "relative_step", zeros(1, size(S,2)), ...
    "parameter_delta", zeros(1, size(S,2)), "candidate_values", values, ...
    "predicted_damping_ratio", zeta.', "ranked_parameters", {{}});
if any(critical)
    scores = max(abs(S(critical,:)), [], 1, "omitnan");
    scores(~isfinite(scores)) = -Inf;
    [~, rank] = sort(scores, "descend");
    rank = rank(scores(rank) >= 0);
    ranked = cell(1, numel(rank));
    for k = 1:numel(rank)
        ranked{k} = struct("parameter", char(names(rank(k))), ...
            "max_abs_normalized_damping_sensitivity", scores(rank(k)));
    end
    rec.ranked_parameters = ranked;
end
if ~any(critical)
    return
end
if ~any(usable) || all(abs(S(usable,:)) < eps, "all")
    rec.status = "insufficient_sensitivity";
    return
end
deficit = max(target - zeta(usable), 0);
relativeStep = pinv(S(usable,:)) * deficit;
relativeStep = max(min(relativeStep, maxStep), -maxStep);
delta = relativeStep.' .* scales;
candidate = min(max(values + delta, lower), upper);
delta = candidate - values;
relativeStep = delta ./ scales;
rec.status = "candidate_requires_validation";
rec.relative_step = relativeStep;
rec.parameter_delta = delta;
rec.candidate_values = candidate;
rec.predicted_damping_ratio = (zeta + S * relativeStep.').';
end


function status = iStatus(recommendation, warnings)
if ~isempty(warnings)
    status = "provisional";
elseif recommendation.status == "insufficient_sensitivity"
    status = "insufficient_sensitivity";
else
    status = "ok";
end
end


function iWriteOutputs(outDir, summary)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "modal_parameter_sensitivity.json"), summary);
iWriteCsv(fullfile(outDir, "modal_parameter_sensitivity.csv"), summary);
iWriteMarkdown(fullfile(outDir, "modal_parameter_sensitivity.md"), summary);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("ModalSensitivity:CannotWrite", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteCsv(path, summary)
[modeRow, parameterCol] = ndgrid(1:numel(summary.modes), 1:numel(summary.parameter_names));
ModeRow = modeRow(:);
Parameter = string(summary.parameter_names(parameterCol(:))).';
Parameter = Parameter(:);
DLambdaReal = summary.d_lambda_real_dp(:);
DLambdaImag = summary.d_lambda_imag_dp(:);
DDamping = summary.d_damping_dp(:);
DFrequencyHz = summary.d_frequency_hz_dp(:);
NormalizedDDamping = summary.d_damping_per_relative_change(:);
writetable(table(ModeRow, Parameter, DLambdaReal, DLambdaImag, DDamping, ...
    DFrequencyHz, NormalizedDDamping), path);
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("ModalSensitivity:CannotWrite", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Modal Parameter Sensitivity\n\n");
fprintf(fid, "Case: `%s`  \n", summary.case_name);
fprintf(fid, "Status: `%s`  \n", summary.status);
fprintf(fid, "Matrix source: `%s`  \n", summary.matrix_source);
fprintf(fid, "Operating point: `%s`\n\n", summary.operating_point);
fprintf(fid, "| Parameter | Current | Candidate | Relative step |\n");
fprintf(fid, "|---|---:|---:|---:|\n");
for k = 1:numel(summary.parameter_names)
    fprintf(fid, "| %s | %.6g | %.6g | %.6g |\n", summary.parameter_names{k}, ...
        summary.parameter_values(k), summary.recommendation.candidate_values(k), ...
        summary.recommendation.relative_step(k));
end
fprintf(fid, "\nDirection status: `%s`. This is advisory until model-backed validation.\n", ...
    summary.recommendation.status);
end


function mustBeSquare(A)
if ~ismatrix(A) || size(A,1) ~= size(A,2) || any(~isfinite(A), "all")
    error("ModalSensitivity:MatrixNotSquare", "A must be a finite square matrix.");
end
end
