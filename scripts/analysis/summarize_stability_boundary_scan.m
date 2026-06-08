function summary = summarize_stability_boundary_scan(samples, metric, varargin)
%SUMMARIZE_STABILITY_BOUNDARY_SCAN Summarize a parameter-sweep / Monte-Carlo
%   stability boundary scan into contract-compliant evidence.
%
%   summary = summarize_stability_boundary_scan(samples, metric, ...
%       "CaseName","case1", "ScanType","grid", ...
%       "ParameterNames",["scr","kp"], "ParameterRanges",[1 5; 0.1 2], ...
%       "MetricName","damping_ratio", "PassThreshold",0.03, ...
%       "PassDirection","above", "BoundaryInterpMethod","linear", ...
%       "RandomSeed",42, "OutputDir",dir)
%
%   Inputs
%     samples  N-by-D real matrix. Row i is one scan sample; column j is the
%              j-th varied parameter. N samples, D varied parameters.
%     metric   N-by-1 real vector. The scalar stability metric per sample
%              (e.g. damping ratio, gain margin dB, max real eigenvalue).
%
%   A sample PASSES when, for PassDirection:
%     "above"  metric >= PassThreshold   (e.g. damping ratio >= 0.03)
%     "below"  metric <= PassThreshold   (e.g. max real eigenvalue <= 0)
%
%   This helper turns ALREADY-COMPUTED scan results into a stability-boundary
%   summary. It does NOT run a Simulink sweep, does NOT compute the metric, and
%   does NOT claim hardware-level validation. A boundary estimated here is a
%   linear/nearest interpolation of the supplied pass/fail samples on each
%   parameter axis; confirm critical boundaries with a refined sweep and
%   time-domain (EMT/RMS) validation.
%
%   See .agents/skills/perturbation-stability-boundary-scan/references/stability-boundary-contract.md

arguments
    samples double {mustBeNonempty}
    metric double {mustBeVector}
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
[X, m, paramNames] = iNormalizeInputs(samples, metric, opts);

D = size(X, 2);
g = iPassIndicator(m, opts.PassThreshold, opts.PassDirection);
isPass = g >= 0;

summary = struct();
summary.case_name = char(opts.CaseName);
summary.scan_type = char(opts.ScanType);
summary.metric_name = char(opts.MetricName);
summary.pass_threshold = opts.PassThreshold;
summary.pass_direction = char(opts.PassDirection);
summary.boundary_interp_method = char(opts.BoundaryInterpMethod);
summary.evidence_source = char(opts.EvidenceSource);
summary.operating_point = char(opts.OperatingPoint);
summary.units = char(opts.Units);
summary.related_time_domain_run = char(opts.RelatedTimeDomainRun);
summary.random_seed = opts.RandomSeed;
summary.n_samples = size(X, 1);
summary.n_parameters = D;
summary.declared_sample_count = opts.DeclaredSampleCount;
summary.n_pass = nnz(isPass);
summary.n_fail = nnz(~isPass);
summary.pass_fraction = nnz(isPass) / numel(isPass);
summary.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));
summary.parameters = iParameterSummary(X, paramNames, opts);
summary.boundary = iBoundaryEstimate(X, g, paramNames, opts.BoundaryInterpMethod);
summary.joint_boundary = iJointBoundary(X, g, paramNames, opts);
[summary.provisional, summary.missing_required, summary.warnings] = ...
    iProvisionalScreen(summary, opts);
summary.limitations = char(opts.LimitationsNote);
summary.artifact_manifest = {};

if strlength(opts.OutputDir) > 0
    summary.artifact_manifest = iWriteOutputs(opts.OutputDir, summary, X, m, isPass, paramNames);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("CaseName", "boundary_scan_case", @(x) ischar(x) || isstring(x));
p.addParameter("ScanType", "grid", @(x) ischar(x) || isstring(x));
p.addParameter("ParameterNames", strings(1,0), @(x) ischar(x) || isstring(x) || iscellstr(x));
p.addParameter("ParameterRanges", [], @(x) isnumeric(x));
p.addParameter("MetricName", "", @(x) ischar(x) || isstring(x));
p.addParameter("PassThreshold", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("PassDirection", "above", @(x) ischar(x) || isstring(x));
p.addParameter("BoundaryInterpMethod", "linear", @(x) ischar(x) || isstring(x));
p.addParameter("RandomSeed", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("DeclaredSampleCount", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("EvidenceSource", "synthetic", @(x) ischar(x) || isstring(x));
p.addParameter("JointPrimaryAxis", "", @(x) ischar(x) || isstring(x));
p.addParameter("JointConditioningAxis", "", @(x) ischar(x) || isstring(x));
p.addParameter("OperatingPoint", "", @(x) ischar(x) || isstring(x));
p.addParameter("Units", "", @(x) ischar(x) || isstring(x));
p.addParameter("RelatedTimeDomainRun", "", @(x) ischar(x) || isstring(x));
p.addParameter("LimitationsNote", ...
    "Boundary interpolated from supplied pass/fail samples; not hardware-validated. Refine the grid near a boundary and confirm with time-domain evidence.", ...
    @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.CaseName = string(opts.CaseName);
opts.ScanType = lower(string(opts.ScanType));
opts.ParameterNames = string(opts.ParameterNames);
opts.MetricName = string(opts.MetricName);
opts.PassDirection = lower(string(opts.PassDirection));
opts.BoundaryInterpMethod = lower(string(opts.BoundaryInterpMethod));
opts.OutputDir = string(opts.OutputDir);
opts.EvidenceSource = string(opts.EvidenceSource);
opts.JointPrimaryAxis = string(opts.JointPrimaryAxis);
opts.JointConditioningAxis = string(opts.JointConditioningAxis);
opts.OperatingPoint = string(opts.OperatingPoint);
opts.Units = string(opts.Units);
opts.RelatedTimeDomainRun = string(opts.RelatedTimeDomainRun);
opts.LimitationsNote = string(opts.LimitationsNote);
if ~ismember(opts.ScanType, ["grid","montecarlo"])
    error("BoundaryScan:BadScanType", ...
        "ScanType must be 'grid' or 'montecarlo'; got '%s'.", opts.ScanType);
end
if ~ismember(opts.PassDirection, ["above","below"])
    error("BoundaryScan:BadPassDirection", ...
        "PassDirection must be 'above' or 'below'; got '%s'.", opts.PassDirection);
end
if ~ismember(opts.BoundaryInterpMethod, ["linear","nearest","none"])
    error("BoundaryScan:BadInterpMethod", ...
        "BoundaryInterpMethod must be 'linear', 'nearest', or 'none'; got '%s'.", ...
        opts.BoundaryInterpMethod);
end
end


function [X, m, paramNames] = iNormalizeInputs(samples, metric, opts)
X = double(samples);
if isvector(X)
    X = X(:);   % a single varied parameter supplied as a row/col vector
end
m = double(metric(:));
N = size(X, 1);
D = size(X, 2);
if numel(m) ~= N
    error("BoundaryScan:LengthMismatch", ...
        "metric (%d) must have one value per sample row (%d).", numel(m), N);
end
if N < 2
    error("BoundaryScan:TooFewSamples", ...
        "Need at least 2 scan samples to estimate a boundary; got %d.", N);
end
if isnan(opts.PassThreshold)
    error("BoundaryScan:MissingThreshold", ...
        "PassThreshold is required to classify pass/fail samples.");
end
paramNames = iResolveParamNames(opts.ParameterNames, D);
end


function names = iResolveParamNames(provided, D)
provided = string(provided);
provided = provided(:)';
if numel(provided) == D && all(strlength(provided) > 0)
    names = provided;
    return
end
% Placeholder names: this also drives the provisional screen downstream.
names = strings(1, D);
for j = 1:D
    names(j) = sprintf("param_%d", j);
end
end


function g = iPassIndicator(m, threshold, direction)
% g >= 0 means pass; g is signed distance to the boundary in metric units.
if direction == "above"
    g = m - threshold;
else
    g = threshold - m;
end
end
function params = iParameterSummary(X, paramNames, opts)
D = size(X, 2);
params = repmat(iEmptyParam(), 1, D);
haveRanges = ~isempty(opts.ParameterRanges) && size(opts.ParameterRanges, 1) == D;
for j = 1:D
    col = X(:, j);
    params(j).name = char(paramNames(j));
    params(j).observed_min = min(col);
    params(j).observed_max = max(col);
    params(j).n_unique = numel(unique(col));
    if haveRanges
        params(j).declared_min = opts.ParameterRanges(j, 1);
        params(j).declared_max = opts.ParameterRanges(j, 2);
        params(j).range_documented = true;
    else
        params(j).declared_min = NaN;
        params(j).declared_max = NaN;
        params(j).range_documented = false;
    end
end
end


function boundary = iBoundaryEstimate(X, g, paramNames, method)
% Per-axis stability boundary: the parameter value where the pass indicator g
% crosses zero. For a grid scan this is a marginal (per-axis) estimate; for a
% Monte-Carlo cloud it is a 1-D projection and is reported as approximate.
D = size(X, 2);
boundary = struct();
boundary.method = char(method);
boundary.note = ['per-axis marginal boundary (other parameters not held ' ...
    'fixed); refine near the crossing for a multi-D boundary'];
boundary.axes = repmat(iEmptyBoundaryAxis(), 1, D);
for j = 1:D
    boundary.axes(j) = iAxisBoundary(X(:, j), g, char(paramNames(j)), method);
end
end


function ax = iAxisBoundary(x, g, name, method)
ax = iEmptyBoundaryAxis();
ax.parameter = name;
ax.has_boundary = false;
ax.boundary_value = NaN;
ax.crossing_count = 0;

if method == "none"
    ax.note = 'boundary interpolation disabled (method=none)';
    return
end

[xs, order] = sort(x);
gs = g(order);
% Collapse duplicate x (grid axis): use the min pass-indicator at each x so a
% single failing sample at that level marks the level as failing.
[xu, ~, ic] = unique(xs);
gu = accumarray(ic, gs, [], @min);
if numel(xu) < 2
    ax.note = 'only one distinct level on this axis; cannot bracket a crossing';
    return
end

crossings = iAllCrossings(xu, gu, method);

ax.crossing_count = numel(crossings);
if ~isempty(crossings)
    ax.has_boundary = true;
    ax.boundary_value = crossings(1);   % first (lowest-parameter) crossing
    if numel(crossings) > 1
        ax.note = sprintf('%d sign changes on this axis; reporting the first', ...
            numel(crossings));
    else
        ax.note = 'single pass/fail crossing on this axis';
    end
else
    if all(gu >= 0)
        ax.note = 'all levels pass on this axis (no boundary in range)';
    else
        ax.note = 'all levels fail on this axis (no boundary in range)';
    end
end
end


function crossings = iAllCrossings(xu, gu, method)
% Zero-crossings of the pass indicator gu over sorted unique levels xu.
% Shared by per-axis and joint-boundary extraction.
crossings = [];
for k = 1:numel(xu)-1
    if sign(gu(k)) ~= sign(gu(k+1)) && ~(gu(k) == 0 && gu(k+1) == 0)
        if method == "linear" && (gu(k+1) ~= gu(k))
            t = gu(k) / (gu(k) - gu(k+1));
            xc = xu(k) + t * (xu(k+1) - xu(k));
        else
            if abs(gu(k)) <= abs(gu(k+1))
                xc = xu(k);
            else
                xc = xu(k+1);
            end
        end
        crossings(end+1) = xc; %#ok<AGROW>
    end
end
end


function jb = iJointBoundary(X, g, paramNames, opts)
% Opt-in joint boundary CURVE: critical value of a primary axis as a function
% of a conditioning axis, on a factorial grid. For each distinct level of the
% conditioning axis, hold it fixed, sort the primary-axis samples in that
% slice, and find the first pass/fail crossing of the primary axis. The locus
% of (conditioning level, critical primary value) is the joint boundary curve.
jb = struct("requested", false, "available", false, ...
    "primary_axis", "", "conditioning_axis", "", "method", "", ...
    "points", iEmptyJointPoint(), "trend", "n/a", "n_points", 0, "note", "");

pName = opts.JointPrimaryAxis;
cName = opts.JointConditioningAxis;
if strlength(pName) == 0 && strlength(cName) == 0
    jb.note = 'joint boundary not requested';
    return
end
jb.requested = true;
jb.primary_axis = char(pName);
jb.conditioning_axis = char(cName);
jb.method = char(opts.BoundaryInterpMethod);

pIdx = find(paramNames == pName, 1);
cIdx = find(paramNames == cName, 1);
if isempty(pIdx) || isempty(cIdx) || pIdx == cIdx
    jb.note = 'joint axes must be two distinct scanned parameter names';
    return
end
if opts.ScanType ~= "grid"
    jb.note = 'joint boundary curve requires a deterministic grid scan';
    return
end

cLevels = unique(X(:, cIdx));
pts = iEmptyJointPoint();
np = 0;
for k = 1:numel(cLevels)
    inSlice = X(:, cIdx) == cLevels(k);
    xp = X(inSlice, pIdx);
    gp = g(inSlice);
    [xu, ~, ic] = unique(xp);
    if numel(xu) < 2
        continue
    end
    gu = accumarray(ic, gp, [], @min);
    crossings = iAllCrossings(xu, gu, opts.BoundaryInterpMethod);
    np = np + 1;
    pt = iScalarJointPoint();
    pt.conditioning_value = cLevels(k);
    pt.n_levels = numel(xu);
    if ~isempty(crossings)
        pt.has_boundary = true;
        pt.critical_value = crossings(1);
    else
        pt.has_boundary = false;
        pt.critical_value = NaN;
        if all(gu >= 0)
            pt.note = 'all primary levels pass in this slice';
        else
            pt.note = 'all primary levels fail in this slice';
        end
    end
    pts(np) = pt;
end

if np == 0
    jb.note = 'no conditioning slice had >=2 primary levels to bracket';
    return
end
jb.available = true;
jb.points = pts;
jb.n_points = np;
jb.trend = iClassifyTrend([pts.conditioning_value], [pts.critical_value]);
jb.note = sprintf(['critical %s vs %s across %d slices; trend=%s ' ...
    '(curve interpolated from grid, not a proven margin)'], ...
    jb.primary_axis, jb.conditioning_axis, np, jb.trend);
end


function trend = iClassifyTrend(condVals, critVals)
% Monotone trend of critical primary value vs conditioning value, using only
% slices that actually produced a finite boundary.
ok = isfinite(condVals) & isfinite(critVals);
c = condVals(ok);
v = critVals(ok);
if numel(v) < 2
    trend = 'insufficient';
    return
end
[~, order] = sort(c);
dv = diff(v(order));
tol = 1e-9 * max(1, max(abs(v)));
if all(dv <= tol)
    trend = 'decreasing';
elseif all(dv >= -tol)
    trend = 'increasing';
else
    trend = 'non-monotone';
end
end


function p = iEmptyJointPoint()
p = iScalarJointPoint();
p = p([]);
end


function p = iScalarJointPoint()
p = struct("conditioning_value",0, "critical_value",0, ...
    "has_boundary",false, "n_levels",0, "note","");
end


function [provisional, missing, warnings] = iProvisionalScreen(summary, opts)
missing = {};
warnings = {};
if strlength(opts.OperatingPoint) == 0
    missing{end+1} = 'operating_point';
end
if strlength(opts.Units) == 0
    missing{end+1} = 'units';
end
if strlength(opts.MetricName) == 0
    missing{end+1} = 'metric_name';
end
if isnan(opts.RandomSeed) && summary.scan_type == "montecarlo"
    missing{end+1} = 'random_seed';
end
hasDocumentedRange = any([summary.parameters.range_documented]);
if ~hasDocumentedRange
    missing{end+1} = 'parameter_ranges';
end
anyPlaceholder = any(startsWith({summary.parameters.name}, 'param_'));
if anyPlaceholder
    warnings{end+1} = 'one or more parameters use placeholder names; pass ParameterNames';
end
if ~isnan(opts.DeclaredSampleCount) && opts.DeclaredSampleCount ~= summary.n_samples
    warnings{end+1} = sprintf( ...
        'declared sample count (%g) != supplied samples (%d)', ...
        opts.DeclaredSampleCount, summary.n_samples);
end
if summary.n_pass == 0
    warnings{end+1} = 'no passing samples: boundary is outside the scanned region';
elseif summary.n_fail == 0
    warnings{end+1} = 'no failing samples: boundary is outside the scanned region';
end
provisional = ~isempty(missing);
end


function p = iEmptyParam()
p = struct("name","", "observed_min",0, "observed_max",0, "n_unique",0, ...
    "declared_min",0, "declared_max",0, "range_documented",false);
end


function ax = iEmptyBoundaryAxis()
ax = struct("parameter","", "has_boundary",false, "boundary_value",0, ...
    "crossing_count",0, "note","");
end


function manifest = iWriteOutputs(outDir, summary, X, m, isPass, paramNames)
if ~isfolder(outDir)
    mkdir(outDir);
end
jsonPath = fullfile(outDir, "stability_boundary_summary.json");
mdPath   = fullfile(outDir, "stability_boundary_summary.md");
csvPath  = fullfile(outDir, "scan_samples.csv");
iWriteJson(jsonPath, summary);
iWriteMarkdown(mdPath, summary);
iWriteCsv(csvPath, X, m, isPass, paramNames);
manifest = {char(jsonPath), char(mdPath), char(csvPath)};
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("BoundaryScan:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteCsv(path, X, m, isPass, paramNames)
T = array2table(X, "VariableNames", cellstr(matlab.lang.makeValidName(paramNames)));
T.metric = m;
T.pass = double(isPass(:));
writetable(T, path);
end
function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("BoundaryScan:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "# Stability Boundary Scan Summary\n\n");
if summary.provisional
    fprintf(fid, "> **PROVISIONAL** - missing required metadata: %s\n\n", ...
        strjoin(summary.missing_required, ", "));
end
fprintf(fid, "Case: `%s`\n", summary.case_name);
fprintf(fid, "Scan type: %s | Evidence source: %s\n", ...
    summary.scan_type, summary.evidence_source);
fprintf(fid, "Metric: `%s` %s %.4g", summary.metric_name, ...
    iDirSymbol(summary.pass_direction), summary.pass_threshold);
if strlength(summary.units) > 0
    fprintf(fid, " [%s]", summary.units);
end
fprintf(fid, " -> PASS\n");
fprintf(fid, "Samples: %d (%d pass / %d fail, pass fraction %.3g)\n", ...
    summary.n_samples, summary.n_pass, summary.n_fail, summary.pass_fraction);
fprintf(fid, "Parameters: %d | Boundary interp: %s", ...
    summary.n_parameters, summary.boundary_interp_method);
if ~isnan(summary.random_seed)
    fprintf(fid, " | seed: %g", summary.random_seed);
end
fprintf(fid, "\nGenerated: %s\n\n", summary.generated_at);

fprintf(fid, "## Metadata\n\n");
fprintf(fid, "| Field | Value |\n|---|---|\n");
fprintf(fid, "| operating_point | %s |\n", iOrDash(summary.operating_point));
fprintf(fid, "| units | %s |\n", iOrDash(summary.units));
fprintf(fid, "| related_time_domain_run | %s |\n", iOrDash(summary.related_time_domain_run));
fprintf(fid, "| declared_sample_count | %s |\n", iNumOrDash(summary.declared_sample_count));
fprintf(fid, "\n");

fprintf(fid, "## Parameters scanned\n\n");
fprintf(fid, "| Parameter | Observed min | Observed max | N unique | Declared range |\n");
fprintf(fid, "|---|---:|---:|---:|---|\n");
for j = 1:numel(summary.parameters)
    pr = summary.parameters(j);
    if pr.range_documented
        rng = sprintf("[%.4g, %.4g]", pr.declared_min, pr.declared_max);
    else
        rng = "(undocumented)";
    end
    fprintf(fid, "| %s | %.4g | %.4g | %d | %s |\n", ...
        pr.name, pr.observed_min, pr.observed_max, pr.n_unique, rng);
end
fprintf(fid, "\n");

fprintf(fid, "## Stability boundary (per-axis)\n\n");
fprintf(fid, "_%s_\n\n", summary.boundary.note);
fprintf(fid, "| Parameter | Boundary? | Boundary value | Crossings | Note |\n");
fprintf(fid, "|---|:--:|---:|---:|---|\n");
for j = 1:numel(summary.boundary.axes)
    ax = summary.boundary.axes(j);
    if ax.has_boundary
        bv = sprintf("%.5g", ax.boundary_value);
    else
        bv = "-";
    end
    fprintf(fid, "| %s | %s | %s | %d | %s |\n", ...
        ax.parameter, iYesNo(ax.has_boundary), bv, ax.crossing_count, ax.note);
end
fprintf(fid, "\n");

jb = summary.joint_boundary;
if jb.requested
    fprintf(fid, "## Joint boundary curve\n\n");
    if jb.available
        fprintf(fid, "Critical `%s` vs `%s` (trend: **%s**)\n\n", ...
            jb.primary_axis, jb.conditioning_axis, jb.trend);
        fprintf(fid, "| %s | Critical %s | Boundary? | Levels | Note |\n", ...
            jb.conditioning_axis, jb.primary_axis);
        fprintf(fid, "|---:|---:|:--:|---:|---|\n");
        for k = 1:numel(jb.points)
            pt = jb.points(k);
            if pt.has_boundary
                cv = sprintf("%.5g", pt.critical_value);
            else
                cv = "-";
            end
            fprintf(fid, "| %.5g | %s | %s | %d | %s |\n", ...
                pt.conditioning_value, cv, iYesNo(pt.has_boundary), ...
                pt.n_levels, pt.note);
        end
        fprintf(fid, "\n_%s_\n\n", jb.note);
    else
        fprintf(fid, "_Requested but unavailable: %s_\n\n", jb.note);
    end
end

if ~isempty(summary.warnings)
    fprintf(fid, "## Warnings\n\n");
    for k = 1:numel(summary.warnings)
        fprintf(fid, "- %s\n", summary.warnings{k});
    end
    fprintf(fid, "\n");
end

fprintf(fid, "## Limitations\n\n%s\n", summary.limitations);
end


function s = iDirSymbol(direction)
if string(direction) == "above"; s = ">="; else; s = "<="; end
end


function s = iYesNo(tf)
if tf; s = "yes"; else; s = "no"; end
end


function s = iOrDash(str)
if strlength(string(str)) == 0; s = "(undocumented)"; else; s = char(str); end
end


function s = iNumOrDash(x)
if isnan(x); s = "(undocumented)"; else; s = sprintf("%g", x); end
end
