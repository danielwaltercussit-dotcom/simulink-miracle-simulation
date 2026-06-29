function out = run_stability_boundary_scan(metricFcn, parameters, varargin)
%RUN_STABILITY_BOUNDARY_SCAN Executable driver for a stability boundary scan.
%
%   out = run_stability_boundary_scan(metricFcn, parameters, ...
%       "ScanType","grid", "GridLevels",9, ...
%       "MetricName","damping_ratio", "PassThreshold",0.03, ...
%       "PassDirection","above", "Units","dimensionless", ...
%       "OperatingPoint","rated load, GFL", "Refine",true, ...
%       "OutputDir",dir)
%
%   This driver GENERATES scan samples, EVALUATES a user metric callback on
%   each sample, optionally REFINES samples near a detected boundary, and then
%   delegates the boundary summary to summarize_stability_boundary_scan. It
%   preserves the random seed (Monte-Carlo), records failed-run diagnostics, and
%   emits an artifact manifest.
%
%   Inputs
%     metricFcn   function handle @(p) -> scalar metric, where p is a 1-by-D row
%                 vector of parameter values. MUST be deterministic for a given
%                 p (same p -> same metric) so grid scans and seeded Monte-Carlo
%                 scans are reproducible. Throwing is allowed; a throw is
%                 recorded as a failed run, not as an unstable sample.
%     parameters  1-by-D struct array with fields:
%                   .name  (char/string) parameter name
%                   .min   (scalar) lower bound
%                   .max   (scalar) upper bound
%                   .levels (optional scalar) grid levels for this axis
%
%   The driver does NOT run a Simulink model itself; the metric callback is the
%   integration point where a caller may evaluate a model, a modal/impedance
%   helper, or an analytic expression. A boundary reported here is still an
%   interpolation of evaluated pass/fail samples, not a proven physical margin.
%
%   Opt-in cost guard: the projected evaluation count (base grid/Monte-Carlo
%   plus the refinement budget) must not exceed "MaxEvaluations" (default 200)
%   unless "AllowLargeScan" is true. This keeps expensive project-wide sweeps
%   from running by accident.
%
%   See .agents/skills/perturbation-stability-boundary-scan/references/stability-boundary-contract.md

arguments
    metricFcn (1,1) function_handle
    parameters struct {mustBeNonempty}
end
arguments (Repeating)
    varargin
end

opts = iParseRunnerOpts(varargin{:});
[names, lo, hi, levels] = iValidateParameters(parameters, opts);
D = numel(names);

% --- Build base samples -------------------------------------------------
switch opts.ScanType
    case "grid"
        Xbase = iBuildGridSamples(lo, hi, levels);
    case "montecarlo"
        if isnan(opts.RandomSeed)
            error("BoundaryScanRun:SeedRequired", ...
                "RandomSeed is required for a reproducible Monte-Carlo scan.");
        end
        Xbase = iBuildMonteCarloSamples(lo, hi, opts.SampleCount, opts.RandomSeed);
end

% --- Opt-in cost guard --------------------------------------------------
projected = size(Xbase, 1);
if opts.Refine
    projected = projected + opts.RefineSteps * D;   % worst-case refine budget
end
if projected > opts.MaxEvaluations && ~opts.AllowLargeScan
    error("BoundaryScanRun:OptInRequired", ...
        ['Projected evaluations (%d) exceed MaxEvaluations (%d). ' ...
         'Set AllowLargeScan=true to opt in to an expensive sweep, or ' ...
         'reduce GridLevels/SampleCount/RefineSteps.'], ...
        projected, opts.MaxEvaluations);
end

% --- Evaluate base samples ---------------------------------------------
[mBase, failBase] = iEvaluate(metricFcn, Xbase, "base");

% --- Summarize base to locate a boundary (in-memory, no artifacts yet) --
[Xok, mok] = iFiniteOnly(Xbase, mBase);
if size(Xok, 1) < 2
    error("BoundaryScanRun:TooFewSuccess", ...
        "Only %d successful evaluations; need >=2 to summarize a boundary.", ...
        size(Xok, 1));
end
baseSummary = iSummaryNoWrite(Xok, mok, names, lo, hi, opts);

% --- Optional refinement near the detected boundary ---------------------
Xref = zeros(0, D);
failRef = iEmptyFailure();
if opts.Refine
    Xref = iRefineAroundBoundary(baseSummary, names, lo, hi, Xok, opts.RefineSteps);
    if ~isempty(Xref)
        [mRef, failRef] = iEvaluate(metricFcn, Xref, "refine");
        [Xref, mRef] = iFiniteOnly(Xref, mRef);
    else
        mRef = zeros(0, 1);
    end
else
    mRef = zeros(0, 1);
end

% --- Final combined summary (writes artifacts) --------------------------
Xall = [Xok; Xref];
mall = [mok; mRef];
finalSummary = iSummaryWithDir(Xall, mall, names, lo, hi, opts);

% --- Assemble run record + diagnostics ---------------------------------
failed = iConcatFailures(failBase, failRef);
out = struct();
out.summary = finalSummary;
out.base_summary = baseSummary;
out.samples = Xall;
out.metric = mall;
out.failed_runs = failed;
out.scan_run = iScanRunRecord(opts, Xbase, Xref, Xall, failed);
out.artifact_manifest = finalSummary.artifact_manifest;

% --- Extra run artifacts (scan_run.json, failed_runs.csv) ---------------
if strlength(opts.OutputDir) > 0
    extra = iWriteRunArtifacts(opts.OutputDir, out.scan_run, failed, names);
    out.artifact_manifest = [out.artifact_manifest, extra];
end
end
function opts = iParseRunnerOpts(varargin)
p = inputParser;
p.addParameter("CaseName", "boundary_scan_run", @(x) ischar(x) || isstring(x));
p.addParameter("ScanType", "grid", @(x) ischar(x) || isstring(x));
p.addParameter("GridLevels", 9, @(x) isnumeric(x) && isscalar(x) && x >= 2);
p.addParameter("SampleCount", 50, @(x) isnumeric(x) && isscalar(x) && x >= 2);
p.addParameter("RandomSeed", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("MetricName", "", @(x) ischar(x) || isstring(x));
p.addParameter("PassThreshold", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("PassDirection", "above", @(x) ischar(x) || isstring(x));
p.addParameter("BoundaryInterpMethod", "linear", @(x) ischar(x) || isstring(x));
p.addParameter("JointPrimaryAxis", "", @(x) ischar(x) || isstring(x));
p.addParameter("JointConditioningAxis", "", @(x) ischar(x) || isstring(x));
p.addParameter("Units", "", @(x) ischar(x) || isstring(x));
p.addParameter("OperatingPoint", "", @(x) ischar(x) || isstring(x));
p.addParameter("RelatedTimeDomainRun", "", @(x) ischar(x) || isstring(x));
p.addParameter("EvidenceSource", "simulated", @(x) ischar(x) || isstring(x));
p.addParameter("Refine", true, @(x) islogical(x) && isscalar(x));
p.addParameter("RefineSteps", 5, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter("MaxEvaluations", 200, @(x) isnumeric(x) && isscalar(x) && x >= 2);
p.addParameter("AllowLargeScan", false, @(x) islogical(x) && isscalar(x));
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.CaseName = string(opts.CaseName);
opts.ScanType = lower(string(opts.ScanType));
opts.MetricName = string(opts.MetricName);
opts.PassDirection = lower(string(opts.PassDirection));
opts.BoundaryInterpMethod = lower(string(opts.BoundaryInterpMethod));
opts.JointPrimaryAxis = string(opts.JointPrimaryAxis);
opts.JointConditioningAxis = string(opts.JointConditioningAxis);
opts.Units = string(opts.Units);
opts.OperatingPoint = string(opts.OperatingPoint);
opts.RelatedTimeDomainRun = string(opts.RelatedTimeDomainRun);
opts.EvidenceSource = string(opts.EvidenceSource);
opts.OutputDir = string(opts.OutputDir);
opts.RefineSteps = round(opts.RefineSteps);
if ~ismember(opts.ScanType, ["grid","montecarlo"])
    error("BoundaryScanRun:BadScanType", ...
        "ScanType must be 'grid' or 'montecarlo'; got '%s'.", opts.ScanType);
end
if isnan(opts.PassThreshold)
    error("BoundaryScanRun:MissingThreshold", "PassThreshold is required.");
end
end


function [names, lo, hi, levels] = iValidateParameters(parameters, opts)
parameters = parameters(:)';
D = numel(parameters);
required = ["name","min","max"];
for r = required
    if ~isfield(parameters, r)
        error("BoundaryScanRun:BadParamStruct", ...
            "parameters struct must have field '%s'.", r);
    end
end
names = strings(1, D);
lo = zeros(1, D);
hi = zeros(1, D);
levels = zeros(1, D);
for j = 1:D
    names(j) = string(parameters(j).name);
    lo(j) = double(parameters(j).min);
    hi(j) = double(parameters(j).max);
    if ~(isfinite(lo(j)) && isfinite(hi(j))) || hi(j) <= lo(j)
        error("BoundaryScanRun:BadRange", ...
            "Parameter '%s' needs finite min < max.", names(j));
    end
    if isfield(parameters, "levels") && ~isempty(parameters(j).levels)
        levels(j) = max(2, round(double(parameters(j).levels)));
    else
        levels(j) = opts.GridLevels;
    end
end
if numel(unique(names)) ~= D
    error("BoundaryScanRun:DuplicateNames", "Parameter names must be unique.");
end
end


function X = iBuildGridSamples(lo, hi, levels)
D = numel(lo);
axes = cell(1, D);
for j = 1:D
    axes{j} = linspace(lo(j), hi(j), levels(j));
end
if D == 1
    X = axes{1}(:);
    return
end
grids = cell(1, D);
[grids{:}] = ndgrid(axes{:});
X = zeros(numel(grids{1}), D);
for j = 1:D
    X(:, j) = grids{j}(:);
end
end


function X = iBuildMonteCarloSamples(lo, hi, n, seed)
% Local RandStream so the global stream is never disturbed (preserves seed
% determinism without side effects on the caller's session).
rs = RandStream("twister", "Seed", seed);
D = numel(lo);
U = rand(rs, n, D);
X = lo + U .* (hi - lo);
end


function [m, failures] = iEvaluate(metricFcn, X, stage)
n = size(X, 1);
m = nan(n, 1);
failures = iEmptyFailure();
nf = 0;
for i = 1:n
    try
        v = metricFcn(X(i, :));
        if ~(isscalar(v) && isnumeric(v) && isfinite(v))
            error("BoundaryScanRun:BadMetric", ...
                "metricFcn must return a finite numeric scalar.");
        end
        m(i) = double(v);
    catch err
        nf = nf + 1;
        failures(nf) = iBuildFailure(stage, i, X(i, :), err);
        m(i) = NaN;   % failed run is excluded, not treated as unstable
    end
end
end


function f = iBuildFailure(stage, idx, params, err)
f = iEmptyFailureScalar();
f.stage = char(stage);
f.sample_index = idx;
f.params = params;
f.identifier = char(err.identifier);
f.message = char(err.message);
end


function f = iEmptyFailure()
f = iEmptyFailureScalar();
f = f([]);
end


function f = iEmptyFailureScalar()
f = struct("stage","", "sample_index",0, "params",[], ...
    "identifier","", "message","");
end


function failed = iConcatFailures(a, b)
if isempty(a) && isempty(b)
    failed = iEmptyFailure();
elseif isempty(a)
    failed = b;
elseif isempty(b)
    failed = a;
else
    failed = [a, b];
end
end


function [Xok, mok] = iFiniteOnly(X, m)
keep = isfinite(m);
Xok = X(keep, :);
mok = m(keep);
end
function s = iSummaryNoWrite(X, m, names, lo, hi, opts)
s = iCallSummary(X, m, names, lo, hi, opts, "");
end


function s = iSummaryWithDir(X, m, names, lo, hi, opts)
s = iCallSummary(X, m, names, lo, hi, opts, opts.OutputDir);
end


function s = iCallSummary(X, m, names, lo, hi, opts, outDir)
ranges = [lo(:), hi(:)];
args = { ...
    "CaseName", opts.CaseName, ...
    "ScanType", opts.ScanType, ...
    "ParameterNames", names, ...
    "ParameterRanges", ranges, ...
    "MetricName", opts.MetricName, ...
    "PassThreshold", opts.PassThreshold, ...
    "PassDirection", opts.PassDirection, ...
    "BoundaryInterpMethod", opts.BoundaryInterpMethod, ...
    "JointPrimaryAxis", opts.JointPrimaryAxis, ...
    "JointConditioningAxis", opts.JointConditioningAxis, ...
    "Units", opts.Units, ...
    "OperatingPoint", opts.OperatingPoint, ...
    "RelatedTimeDomainRun", opts.RelatedTimeDomainRun, ...
    "EvidenceSource", opts.EvidenceSource, ...
    "DeclaredSampleCount", size(X, 1), ...
    "OutputDir", outDir };
if ~isnan(opts.RandomSeed)
    args = [args, {"RandomSeed", opts.RandomSeed}];
end
s = summarize_stability_boundary_scan(X, m, args{:});
end


function Xref = iRefineAroundBoundary(summary, names, lo, hi, Xexisting, steps)
% For each axis with a detected boundary, add samples in the bracketing
% interval around the boundary value, holding the other parameters at the
% median of the successfully-evaluated samples. This narrows the bracket the
% next summary can interpolate, without a full re-sweep.
D = numel(names);
Xref = zeros(0, D);
if steps < 1
    return
end
if D == 1
    centre = [];
else
    centre = median(Xexisting, 1);
end
axesList = summary.boundary.axes;
for j = 1:numel(axesList)
    ax = axesList(j);
    if ~ax.has_boundary || ~isfinite(ax.boundary_value)
        continue
    end
    % Local bracket: a fraction of the axis span centred on the boundary.
    span = (hi(j) - lo(j)) / max(4, steps);
    bcentre = ax.boundary_value;
    loB = max(lo(j), bcentre - span);
    hiB = min(hi(j), bcentre + span);
    if hiB <= loB
        continue
    end
    levelsRef = linspace(loB, hiB, steps + 2);
    levelsRef = levelsRef(2:end-1);   % drop the endpoints (already bracketed)
    for v = levelsRef
        if D == 1
            row = v;
        else
            row = centre;
            row(j) = v;
        end
        Xref(end+1, :) = row; %#ok<AGROW>
    end
end
Xref = iUniqueRows(Xref);
end


function U = iUniqueRows(X)
if isempty(X)
    U = X;
    return
end
[~, ia] = unique(round(X, 12), "rows", "stable");
U = X(ia, :);
end


function rec = iScanRunRecord(opts, Xbase, Xref, Xall, failed)
rec = struct();
rec.case_name = char(opts.CaseName);
rec.scan_type = char(opts.ScanType);
rec.metric_name = char(opts.MetricName);
rec.pass_threshold = opts.PassThreshold;
rec.pass_direction = char(opts.PassDirection);
rec.random_seed = opts.RandomSeed;
rec.refine = opts.Refine;
rec.refine_steps = opts.RefineSteps;
rec.max_evaluations = opts.MaxEvaluations;
rec.allow_large_scan = opts.AllowLargeScan;
rec.n_base_samples = size(Xbase, 1);
rec.n_refine_samples = size(Xref, 1);
rec.n_total_evaluations = size(Xbase, 1) + size(Xref, 1);
rec.n_successful = size(Xall, 1);
rec.n_failed = numel(failed);
rec.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));
end


function manifest = iWriteRunArtifacts(outDir, scanRun, failed, names)
if ~isfolder(outDir)
    mkdir(outDir);
end
jsonPath = fullfile(outDir, "scan_run.json");
fid = fopen(jsonPath, "w");
if fid < 0
    error("BoundaryScanRun:CannotWriteJson", "Cannot write %s", jsonPath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(scanRun, "PrettyPrint", true));
clear cleanup;

manifest = {char(jsonPath)};
csvPath = fullfile(outDir, "failed_runs.csv");
iWriteFailedRunsCsv(csvPath, failed, names);
manifest = [manifest, {char(csvPath)}];
end


function iWriteFailedRunsCsv(path, failed, names)
nf = numel(failed);
D = numel(names);
paramCols = cellstr(matlab.lang.makeValidName(names));
% Build by column assignment (unambiguous; avoids table() name-value parsing).
T = table();
if nf == 0
    T.stage = strings(0, 1);
    T.sample_index = zeros(0, 1);
    for j = 1:D
        T.(paramCols{j}) = zeros(0, 1);
    end
    T.message = strings(0, 1);
    writetable(T, path);
    return
end
stage = strings(nf, 1);
idx = zeros(nf, 1);
P = zeros(nf, D);
msg = strings(nf, 1);
for i = 1:nf
    stage(i) = string(failed(i).stage);
    idx(i) = failed(i).sample_index;
    P(i, :) = failed(i).params;
    msg(i) = string(failed(i).message);
end
T.stage = stage;
T.sample_index = idx;
for j = 1:D
    T.(paramCols{j}) = P(:, j);
end
T.message = msg;
writetable(T, path);
end
