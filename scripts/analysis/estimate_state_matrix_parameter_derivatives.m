function result = estimate_state_matrix_parameter_derivatives(parameterValues, matrixFcn, varargin)
%ESTIMATE_STATE_MATRIX_PARAMETER_DERIVATIVES Actively estimate dA/dp.
% matrixFcn(parameterVector) returns A or struct('A',A,'operating_point',xop).

arguments
    parameterValues double
    matrixFcn (1,1) function_handle
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
values = reshape(parameterValues, 1, []);
if isempty(values) || any(~isfinite(values))
    error("MatrixDerivative:ParameterValues", ...
        "ParameterValues must be finite and non-empty.");
end
p = numel(values);
names = iNames(opts.ParameterNames, p);
lower = iRow(opts.LowerBounds, p, -Inf, "LowerBounds");
upper = iRow(opts.UpperBounds, p, Inf, "UpperBounds");
relativeStep = iRow(opts.RelativeStep, p, 1e-3, "RelativeStep");
absoluteStep = iRow(opts.AbsoluteStep, p, 1e-6, "AbsoluteStep");
if any(relativeStep <= 0) || any(absoluteStep <= 0)
    error("MatrixDerivative:PerturbationStep", ...
        "RelativeStep and AbsoluteStep must be positive.");
end
if any(lower > values) || any(upper < values) || any(lower > upper)
    error("MatrixDerivative:Bounds", ...
        "Parameter values must lie inside ordered bounds.");
end

[A0, op0] = iEvaluate(matrixFcn, values);
n = size(A0,1);
dAdp = zeros(n,n,p);
stepUsed = zeros(1,p);
method = strings(1,p);
maxOperatingPointDrift = zeros(1,p);
warnings = strings(0,1);
if isempty(op0)
    warnings(end+1) = "operating_point_not_reported";
end

for k = 1:p
    step = max(abs(values(k)) * relativeStep(k), absoluteStep(k));
    plusAllowed = values(k) + step <= upper(k);
    minusAllowed = values(k) - step >= lower(k);
    if ~plusAllowed && ~minusAllowed
        error("MatrixDerivative:NoPerturbationRoom", ...
            "Parameter %s cannot move inside its bounds.", names(k));
    end
    if plusAllowed
        plus = values;
        plus(k) = plus(k) + step;
        [Aplus, opPlus] = iEvaluate(matrixFcn, plus);
        iRequireSameSize(Aplus, A0);
    end
    if minusAllowed
        minus = values;
        minus(k) = minus(k) - step;
        [Aminus, opMinus] = iEvaluate(matrixFcn, minus);
        iRequireSameSize(Aminus, A0);
    end
    if plusAllowed && minusAllowed
        dAdp(:,:,k) = (Aplus - Aminus) / (2*step);
        method(k) = "central";
        maxOperatingPointDrift(k) = max(iDrift(op0, opPlus), iDrift(op0, opMinus));
    elseif plusAllowed
        dAdp(:,:,k) = (Aplus - A0) / step;
        method(k) = "forward";
        maxOperatingPointDrift(k) = iDrift(op0, opPlus);
        warnings(end+1) = names(k) + "_used_forward_difference"; %#ok<AGROW>
    else
        dAdp(:,:,k) = (A0 - Aminus) / step;
        method(k) = "backward";
        maxOperatingPointDrift(k) = iDrift(op0, opMinus);
        warnings(end+1) = names(k) + "_used_backward_difference"; %#ok<AGROW>
    end
    stepUsed(k) = step;
    if maxOperatingPointDrift(k) > opts.OperatingPointTolerance
        warnings(end+1) = names(k) + "_operating_point_drift"; %#ok<AGROW>
    end
end

result = struct();
result.status = char(iStatus(warnings));
result.parameter_names = cellstr(names);
result.parameter_values = values;
result.step_used = stepUsed;
result.difference_method = cellstr(method);
result.max_operating_point_relative_drift = maxOperatingPointDrift;
result.operating_point_tolerance = opts.OperatingPointTolerance;
result.A = A0;
result.dAdp = dAdp;
result.warnings = cellstr(warnings);
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("ParameterNames", strings(1,0), @(x) iscellstr(x) || isstring(x));
p.addParameter("LowerBounds", [], @isnumeric);
p.addParameter("UpperBounds", [], @isnumeric);
p.addParameter("RelativeStep", 1e-3, @isnumeric);
p.addParameter("AbsoluteStep", 1e-6, @isnumeric);
p.addParameter("OperatingPointTolerance", 1e-3, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.parse(varargin{:});
opts = p.Results;
opts.ParameterNames = string(opts.ParameterNames);
end


function names = iNames(input, n)
names = string(input);
if isempty(names)
    names = "p" + (1:n);
else
    names = reshape(names, 1, []);
end
if numel(names) ~= n
    error("MatrixDerivative:NameCount", ...
        "ParameterNames must have one entry per parameter.");
end
end


function row = iRow(input, n, defaultValue, fieldName)
if isempty(input)
    row = repmat(defaultValue, 1, n);
elseif isscalar(input)
    row = repmat(double(input), 1, n);
else
    row = reshape(double(input), 1, []);
end
if numel(row) ~= n
    error("MatrixDerivative:OptionSize", ...
        "%s must be scalar or have one value per parameter.", fieldName);
end
end


function [A, operatingPoint] = iEvaluate(matrixFcn, values)
raw = matrixFcn(values);
operatingPoint = [];
if isstruct(raw)
    if ~isfield(raw, "A")
        error("MatrixDerivative:CallbackContract", ...
            "A struct callback result must contain field A.");
    end
    A = double(raw.A);
    if isfield(raw, "operating_point")
        operatingPoint = double(raw.operating_point(:));
    end
else
    A = double(raw);
end
if ~ismatrix(A) || size(A,1) ~= size(A,2) || any(~isfinite(A), "all")
    error("MatrixDerivative:InvalidMatrix", ...
        "The matrix callback must return a finite square A matrix.");
end
end


function drift = iDrift(reference, candidate)
if isempty(reference) || isempty(candidate) || numel(reference) ~= numel(candidate)
    drift = NaN;
    return
end
scale = max(norm(reference), 1);
drift = norm(candidate - reference) / scale;
end


function iRequireSameSize(candidate, reference)
if ~isequal(size(candidate), size(reference))
    error("MatrixDerivative:MatrixSizeChanged", ...
        "The linearized A-matrix size changed during parameter perturbation.");
end
end


function status = iStatus(warnings)
if isempty(warnings)
    status = "ok";
else
    status = "provisional";
end
end
