function summary = summarize_modal_eigs(A, varargin)
%SUMMARIZE_MODAL_EIGS Summarize eigenvalues, damping, and participation.
%
% summary = summarize_modal_eigs(A, "CaseName","case1", "StateNames",names)

arguments
    A double {mustBeSquare}
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
n = size(A,1);
stateNames = iNormalizeStateNames(opts.StateNames, n);

[rightVec, eigMat, leftVec] = eig(A);
lambda = diag(eigMat);
[~, order] = sortrows([real(lambda) -abs(imag(lambda))], [-1 -2]);
lambda = lambda(order);
rightVec = rightVec(:, order);
leftVec = leftVec(:, order);

mode = repmat(iEmptyMode(), 1, n);
for k = 1:n
    mode(k) = iBuildMode(k, lambda(k), rightVec(:,k), leftVec(:,k), ...
        stateNames, opts.DampingThreshold);
end

summary = struct();
summary.case_name = char(opts.CaseName);
summary.n_states = n;
summary.damping_threshold = opts.DampingThreshold;
summary.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));
summary.modes = mode;

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, summary, opts.MaxModes);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("CaseName", "modal_case", @(x) ischar(x) || isstring(x));
p.addParameter("StateNames", strings(1,0), @(x) iscellstr(x) || isstring(x));
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("DampingThreshold", 0.05, @(x) isnumeric(x) && isscalar(x));
p.addParameter("MaxModes", 20, @(x) isnumeric(x) && isscalar(x));
p.parse(varargin{:});
opts = p.Results;
opts.CaseName = string(opts.CaseName);
opts.StateNames = string(opts.StateNames);
opts.OutputDir = string(opts.OutputDir);
end


function names = iNormalizeStateNames(inputNames, n)
names = strings(1, n);
if isempty(inputNames)
    for k = 1:n
        names(k) = "x" + k;
    end
    return
end
inputNames = string(inputNames);
names(:) = "unlabeled";
limit = min(n, numel(inputNames));
names(1:limit) = inputNames(1:limit);
end


function mode = iEmptyMode()
mode = struct("index",0, "real",0, "imag",0, "damped_frequency_hz",0, ...
    "natural_frequency_hz",0, "damping_ratio",0, "label","", ...
    "top_participating_states",{{}});
end


function mode = iBuildMode(index, lambda, rightVec, leftVec, stateNames, dampingThreshold)
mag = abs(lambda);
if mag == 0
    dampingRatio = NaN;
else
    dampingRatio = -real(lambda) / mag;
end

mode = iEmptyMode();
mode.index = index;
mode.real = real(lambda);
mode.imag = imag(lambda);
mode.damped_frequency_hz = abs(imag(lambda)) / (2*pi);
mode.natural_frequency_hz = mag / (2*pi);
mode.damping_ratio = dampingRatio;
mode.label = iModeLabel(lambda, dampingRatio, dampingThreshold);
mode.top_participating_states = iTopParticipation(rightVec, leftVec, stateNames);
end


function label = iModeLabel(lambda, dampingRatio, dampingThreshold)
if abs(lambda) < 1e-9
    label = "integrator_or_zero";
elseif real(lambda) > 1e-9
    label = "unstable";
elseif ~isnan(dampingRatio) && dampingRatio < dampingThreshold && abs(imag(lambda)) > 1e-9
    label = "low_damping";
else
    label = "stable";
end
label = char(label);
end


function topStates = iTopParticipation(rightVec, leftVec, stateNames)
part = abs(rightVec .* conj(leftVec));
if all(~isfinite(part)) || sum(part) == 0
    topStates = cellstr(stateNames(1:min(3, numel(stateNames))));
    return
end
part = part ./ sum(part);
[~, idx] = sort(part, "descend");
idx = idx(1:min(5, numel(idx)));
topStates = cell(1, numel(idx));
for k = 1:numel(idx)
    topStates{k} = sprintf("%s (%.3g)", stateNames(idx(k)), part(idx(k)));
end
end


function iWriteOutputs(outDir, summary, maxModes)
if ~isfolder(outDir)
    mkdir(outDir);
end
jsonPath = fullfile(outDir, "modal_summary.json");
mdPath = fullfile(outDir, "modal_summary.md");
csvPath = fullfile(outDir, "eigenvalues.csv");
iWriteJson(jsonPath, summary);
iWriteMarkdown(mdPath, summary, maxModes);
iWriteCsv(csvPath, summary);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("ModalSummary:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteMarkdown(path, summary, maxModes)
fid = fopen(path, "w");
if fid < 0
    error("ModalSummary:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Modal Summary\n\n");
fprintf(fid, "Case: `%s`\n", summary.case_name);
fprintf(fid, "States: %d\n", summary.n_states);
fprintf(fid, "Damping threshold: %.4g\n", summary.damping_threshold);
fprintf(fid, "Generated: %s\n\n", summary.generated_at);
fprintf(fid, "| Mode | Real | Imag | Fd Hz | Damping | Label | Top states |\n");
fprintf(fid, "|---:|---:|---:|---:|---:|---|---|\n");
count = min(maxModes, numel(summary.modes));
for k = 1:count
    m = summary.modes(k);
    states = strjoin(string(m.top_participating_states), "; ");
    fprintf(fid, "| %d | %.6g | %.6g | %.6g | %.6g | %s | %s |\n", ...
        m.index, m.real, m.imag, m.damped_frequency_hz, ...
        m.damping_ratio, m.label, states);
end
end


function iWriteCsv(path, summary)
n = numel(summary.modes);
Index = zeros(n,1);
RealPart = zeros(n,1);
ImagPart = zeros(n,1);
DampedFrequencyHz = zeros(n,1);
NaturalFrequencyHz = zeros(n,1);
DampingRatio = zeros(n,1);
Label = strings(n,1);
TopStates = strings(n,1);
for k = 1:n
    m = summary.modes(k);
    Index(k) = m.index;
    RealPart(k) = m.real;
    ImagPart(k) = m.imag;
    DampedFrequencyHz(k) = m.damped_frequency_hz;
    NaturalFrequencyHz(k) = m.natural_frequency_hz;
    DampingRatio(k) = m.damping_ratio;
    Label(k) = string(m.label);
    TopStates(k) = strjoin(string(m.top_participating_states), "; ");
end
T = table(Index, RealPart, ImagPart, DampedFrequencyHz, NaturalFrequencyHz, ...
    DampingRatio, Label, TopStates);
writetable(T, path);
end


function mustBeSquare(A)
if ~ismatrix(A) || size(A,1) ~= size(A,2)
    error("ModalSummary:MatrixNotSquare", "Matrix must be square.");
end
end
