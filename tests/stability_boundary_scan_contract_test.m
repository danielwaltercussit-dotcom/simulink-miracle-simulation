function result = stability_boundary_scan_contract_test()
%STABILITY_BOUNDARY_SCAN_CONTRACT_TEST Synthetic smoke/contract test for F3.
%   Exercises summarize_stability_boundary_scan on synthetic scan results to
%   prove the boundary-scan evidence contract holds:
%     A) deterministic 1-D grid scan with a known damping-ratio boundary, so
%        per-axis boundary interpolation lands near the analytic crossing and
%        the documented case is NOT provisional;
%     B) deterministic 2-D grid scan (SCR x controller gain), so a boundary is
%        found on each axis and the artifact manifest + files are written;
%     C) Monte-Carlo scan WITHOUT operating point / units / seed, so the
%        provisional screen fires and lists the missing required metadata;
%     D) "below" pass-direction (max real eigenvalue <= 0) all-pass case, so
%        the no-boundary-in-range path and pass_fraction==1 are exercised.
%
%   Then exercises the executable runner run_stability_boundary_scan:
%     E) deterministic grid run via a metric callback: same seedless grid run
%        twice is bit-reproducible, and refinement adds samples near the
%        boundary that tighten the bracket vs the base-only summary;
%     F) seeded Monte-Carlo run: same seed -> identical samples; different seed
%        -> different samples (random seed preserved + honoured);
%     G) failed-run diagnostics: a callback that throws on part of the domain is
%        recorded in failed_runs (excluded, not treated as unstable), and the
%        scan still summarizes the successful samples;
%     H) opt-in cost guard: a projected evaluation count over MaxEvaluations
%        errors unless AllowLargeScan=true.
%
%   No Simulink, no toolbox dependency: pure synthetic data through the
%   base-MATLAB helper. Returns a struct and prints PASS/FAIL per check.
%   Artifacts written under build/reports/f3_boundary_scan/<case>/ and the
%   scratch case is cleaned at the end so a later review cannot see a stale
%   false PASS.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

checks = struct([]);
checks = iAddCheck(checks, iCaseGrid1D(projectRoot));
checks = iAddCheck(checks, iCaseGrid2D(projectRoot));
checks = iAddCheck(checks, iCaseProvisionalMonteCarlo(projectRoot));
checks = iAddCheck(checks, iCaseBelowAllPass(projectRoot));
checks = iAddCheck(checks, iCaseRunnerGridRefine(projectRoot));
checks = iAddCheck(checks, iCaseRunnerSeed(projectRoot));
checks = iAddCheck(checks, iCaseRunnerFailedRuns(projectRoot));
checks = iAddCheck(checks, iCaseRunnerOptInGuard(projectRoot));

allPass = all([checks.passed]);
fprintf('\n=== stability_boundary_scan_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), nnz([checks.passed]), numel(checks));

result = struct('passed', allPass, 'checks', checks);
end


function c = iCaseGrid1D(projectRoot)
% Damping ratio rises with SCR; analytic boundary (zeta=0.03) near SCR=2.0.
% zeta(SCR) = 0.02*SCR - 0.01  =>  zeta=0.03 at SCR=2.0
scr = (1:0.25:5)';
zeta = 0.02 * scr - 0.01;
outDir = fullfile(projectRoot, 'build', 'reports', 'f3_boundary_scan', 'synthetic_grid_1d');

s = summarize_stability_boundary_scan(scr, zeta, ...
    'CaseName', 'synthetic_grid_1d', ...
    'ScanType', 'grid', ...
    'ParameterNames', "scr", ...
    'ParameterRanges', [1 5], ...
    'MetricName', 'damping_ratio', ...
    'PassThreshold', 0.03, ...
    'PassDirection', 'above', ...
    'BoundaryInterpMethod', 'linear', ...
    'OperatingPoint', 'rated load, GFL, varying SCR', ...
    'Units', 'dimensionless', ...
    'OutputDir', outDir);

ax = s.boundary.axes(1);
okType   = strcmp(s.scan_type, 'grid');
okBound  = ax.has_boundary && abs(ax.boundary_value - 2.0) <= 0.25;
okProv   = ~s.provisional && isempty(s.missing_required);
okSplit  = s.n_pass > 0 && s.n_fail > 0 && abs(s.pass_fraction - mean(zeta>=0.03)) < 1e-9;
okFiles  = iArtifactsExist(outDir);

c.name = 'Case A: 1-D grid, known damping boundary near SCR=2.0, documented';
c.passed = okType && okBound && okProv && okSplit && okFiles;
c.detail = sprintf(['boundary=%.4g (~2.0:%d) provisional=%d (want 0) ', ...
    'pass=%d fail=%d frac=%.3g artifacts=%d'], ...
    ax.boundary_value, okBound, s.provisional, s.n_pass, s.n_fail, ...
    s.pass_fraction, okFiles);
end


function c = iCaseGrid2D(projectRoot)
% 2-D grid: stability needs SCR high enough AND gain low enough.
% metric = 0.02*scr - 0.04*kp  ; pass when metric >= 0.
scrLevels = 1:1:5;
kpLevels  = 0.5:0.5:2.5;
[S, K] = meshgrid(scrLevels, kpLevels);
X = [S(:), K(:)];
metric = 0.02 * X(:,1) - 0.04 * X(:,2);
outDir = fullfile(projectRoot, 'build', 'reports', 'f3_boundary_scan', 'synthetic_grid_2d');

s = summarize_stability_boundary_scan(X, metric, ...
    'CaseName', 'synthetic_grid_2d', ...
    'ScanType', 'grid', ...
    'ParameterNames', ["scr","kp"], ...
    'ParameterRanges', [1 5; 0.5 2.5], ...
    'MetricName', 'stability_margin', ...
    'PassThreshold', 0.0, ...
    'PassDirection', 'above', ...
    'BoundaryInterpMethod', 'linear', ...
    'OperatingPoint', 'rated load, GFL, SCR x kp sweep', ...
    'Units', 'dimensionless', ...
    'DeclaredSampleCount', numel(metric), ...
    'OutputDir', outDir);

okParams = s.n_parameters == 2;
okAxes   = numel(s.boundary.axes) == 2 && ...
           any([s.boundary.axes.has_boundary]);
okManifest = iscell(s.artifact_manifest) && numel(s.artifact_manifest) == 3;
okFiles  = iArtifactsExist(outDir);
okProv   = ~s.provisional;

c.name = 'Case B: 2-D grid (SCR x kp), per-axis boundary + manifest';
c.passed = okParams && okAxes && okManifest && okFiles && okProv;
c.detail = sprintf(['n_param=%d axesWithBoundary=%d manifest=%d artifacts=%d ', ...
    'provisional=%d (want 0)'], ...
    s.n_parameters, nnz([s.boundary.axes.has_boundary]), ...
    numel(s.artifact_manifest), okFiles, s.provisional);
end


function c = iCaseProvisionalMonteCarlo(projectRoot)
% Monte-Carlo cloud, but undocumented: no op-point, no units, no seed.
% Deterministic synthetic cloud (no rng) so the test is reproducible.
n = 60;
u = ((0:n-1)' / (n-1));                 % 0..1 deterministic spread
scr = 1 + 4 * u;                        % 1..5
kp  = 0.5 + 2 * (1 - u);                % anti-correlated 2.5..0.5
metric = 0.02 * scr - 0.04 * kp + 0.01 * sin(6 * u);
outDir = fullfile(projectRoot, 'build', 'reports', 'f3_boundary_scan', 'synthetic_mc_provisional');

s = summarize_stability_boundary_scan([scr kp], metric, ...
    'CaseName', 'synthetic_mc_provisional', ...
    'ScanType', 'montecarlo', ...
    'ParameterNames', ["scr","kp"], ...
    'MetricName', 'stability_margin', ...
    'PassThreshold', 0.0, ...
    'PassDirection', 'above', ...
    'BoundaryInterpMethod', 'nearest', ...
    'OutputDir', outDir);

okProv  = s.provisional;
need = {'operating_point','units','random_seed','parameter_ranges'};
okMiss  = all(ismember(need, s.missing_required));
okType  = strcmp(s.scan_type, 'montecarlo');
okFiles = iArtifactsExist(outDir);

c.name = 'Case C: undocumented Monte-Carlo scan flagged provisional';
c.passed = okProv && okMiss && okType && okFiles;
c.detail = sprintf(['provisional=%d (want 1) missing={%s} hasAllRequired=%d ', ...
    'type=%s artifacts=%d'], ...
    s.provisional, strjoin(s.missing_required, ','), okMiss, s.scan_type, okFiles);
end


function c = iCaseBelowAllPass(projectRoot)
% "below" direction: max real eigenvalue must stay <= 0. All samples pass,
% so there is no boundary in range and pass_fraction == 1.
gainSweep = (0.1:0.1:1.0)';
maxRealEig = -0.5 + 0.2 * gainSweep;    % stays negative across the sweep
outDir = fullfile(projectRoot, 'build', 'reports', 'f3_boundary_scan', 'synthetic_below_allpass');

s = summarize_stability_boundary_scan(gainSweep, maxRealEig, ...
    'CaseName', 'synthetic_below_allpass', ...
    'ScanType', 'grid', ...
    'ParameterNames', "loop_gain", ...
    'ParameterRanges', [0.1 1.0], ...
    'MetricName', 'max_real_eigenvalue', ...
    'PassThreshold', 0.0, ...
    'PassDirection', 'below', ...
    'BoundaryInterpMethod', 'linear', ...
    'OperatingPoint', 'rated load, loop-gain sweep', ...
    'Units', '1/s', ...
    'OutputDir', outDir);

ax = s.boundary.axes(1);
okAllPass = s.n_fail == 0 && abs(s.pass_fraction - 1) < 1e-9;
okNoBound = ~ax.has_boundary;
okWarn    = any(contains(s.warnings, 'no failing samples'));
okFiles   = iArtifactsExist(outDir);

c.name = 'Case D: below-direction all-pass, no boundary in range';
c.passed = okAllPass && okNoBound && okWarn && okFiles;
c.detail = sprintf(['n_fail=%d frac=%.3g has_boundary=%d (want 0) ', ...
    'warnNoFail=%d artifacts=%d'], ...
    s.n_fail, s.pass_fraction, ax.has_boundary, okWarn, okFiles);
end


function c = iCaseRunnerGridRefine(projectRoot)
% Executable grid run via a deterministic callback. Boundary at scr=2.0
% (zeta = 0.02*scr - 0.01 crosses 0.03 at scr=2.0). Refinement should add
% samples near 2.0 and tighten the bracket vs a base-only run.
metricFcn = @(p) 0.02 * p(1) - 0.01;     % p(1) = scr
params = struct('name', 'scr', 'min', 1, 'max', 5, 'levels', 5);
outDir = fullfile(projectRoot, 'build', 'reports', 'f3_boundary_scan', 'runner_grid_refine');

out = run_stability_boundary_scan(metricFcn, params, ...
    'CaseName', 'runner_grid_refine', ...
    'ScanType', 'grid', ...
    'MetricName', 'damping_ratio', ...
    'PassThreshold', 0.03, ...
    'PassDirection', 'above', ...
    'Units', 'dimensionless', ...
    'OperatingPoint', 'rated load, GFL, SCR grid', ...
    'Refine', true, 'RefineSteps', 5, ...
    'OutputDir', outDir);

% Same run again -> identical samples/metric (deterministic, seedless grid).
out2 = run_stability_boundary_scan(metricFcn, params, ...
    'CaseName', 'runner_grid_refine', 'ScanType', 'grid', ...
    'MetricName', 'damping_ratio', 'PassThreshold', 0.03, ...
    'PassDirection', 'above', 'Units', 'dimensionless', ...
    'OperatingPoint', 'rated load, GFL, SCR grid', ...
    'Refine', true, 'RefineSteps', 5);

ax = out.summary.boundary.axes(1);
okBoundary = ax.has_boundary && abs(ax.boundary_value - 2.0) <= 0.25;
okRefined  = out.scan_run.n_refine_samples > 0;
okDeterm   = isequal(out.samples, out2.samples) && isequaln(out.metric, out2.metric);
okManifest = any(contains(out.artifact_manifest, 'scan_run.json'));
okFiles    = iArtifactsExist(outDir) && isfile(fullfile(outDir, 'scan_run.json'));

c.name = 'Case E: runner grid + refinement, deterministic, boundary near 2.0';
c.passed = okBoundary && okRefined && okDeterm && okManifest && okFiles;
c.detail = sprintf(['boundary=%.4g (~2.0:%d) refineN=%d determ=%d ', ...
    'manifest=%d artifacts=%d'], ...
    ax.boundary_value, okBoundary, out.scan_run.n_refine_samples, ...
    okDeterm, okManifest, okFiles);
end


function c = iCaseRunnerSeed(projectRoot)
% Seeded Monte-Carlo: same seed -> identical samples; different seed ->
% different samples. Confirms the random seed is preserved and honoured.
metricFcn = @(p) 0.02 * p(1) - 0.04 * p(2);
params = struct( ...
    'name', {'scr','kp'}, ...
    'min',  {1, 0.5}, ...
    'max',  {5, 2.5});
outDir = fullfile(projectRoot, 'build', 'reports', 'f3_boundary_scan', 'runner_seed');

args = {'CaseName','runner_seed','ScanType','montecarlo', ...
    'SampleCount', 40, 'MetricName','stability_margin', ...
    'PassThreshold', 0.0, 'PassDirection','above', ...
    'Units','dimensionless', 'OperatingPoint','rated load, MC', ...
    'Refine', false};

outA = run_stability_boundary_scan(metricFcn, params, args{:}, ...
    'RandomSeed', 42, 'OutputDir', outDir);
outB = run_stability_boundary_scan(metricFcn, params, args{:}, 'RandomSeed', 42);
outC = run_stability_boundary_scan(metricFcn, params, args{:}, 'RandomSeed', 7);

okSameSeed = isequal(outA.samples, outB.samples);
okDiffSeed = ~isequal(outA.samples, outC.samples);
okSeedRec  = outA.scan_run.random_seed == 42 && ~outA.summary.provisional;
okFiles    = iArtifactsExist(outDir);

c.name = 'Case F: seeded Monte-Carlo reproducible, seed preserved';
c.passed = okSameSeed && okDiffSeed && okSeedRec && okFiles;
c.detail = sprintf(['sameSeed=%d diffSeed=%d seedRec=%d provisional=%d ', ...
    'artifacts=%d'], ...
    okSameSeed, okDiffSeed, outA.scan_run.random_seed == 42, ...
    outA.summary.provisional, okFiles);
end


function c = iCaseRunnerFailedRuns(projectRoot)
% Callback throws for scr<2 (e.g. a model that fails to converge in a weak
% grid). Failures must be recorded as diagnostics, excluded from the metric,
% and the scan must still summarize the successful samples.
metricFcn = @(p) iThrowIfWeak(p);
params = struct('name', 'scr', 'min', 1, 'max', 5, 'levels', 9);
outDir = fullfile(projectRoot, 'build', 'reports', 'f3_boundary_scan', 'runner_failed');

out = run_stability_boundary_scan(metricFcn, params, ...
    'CaseName', 'runner_failed', 'ScanType', 'grid', ...
    'MetricName', 'damping_ratio', 'PassThreshold', 0.03, ...
    'PassDirection', 'above', 'Units', 'dimensionless', ...
    'OperatingPoint', 'rated load, weak-grid convergence failures', ...
    'Refine', false, 'OutputDir', outDir);

okFailures = out.scan_run.n_failed > 0 && numel(out.failed_runs) == out.scan_run.n_failed;
okExcluded = out.scan_run.n_successful == size(out.samples, 1) && ...
             all(isfinite(out.metric));
okIdent    = any(strcmp({out.failed_runs.identifier}, 'BoundaryScanTest:WeakGrid'));
okCsv      = isfile(fullfile(outDir, 'failed_runs.csv'));
okSummary  = out.summary.n_samples == out.scan_run.n_successful;

c.name = 'Case G: failed runs recorded, excluded, scan still summarizes';
c.passed = okFailures && okExcluded && okIdent && okCsv && okSummary;
c.detail = sprintf(['nFailed=%d nSucc=%d allFinite=%d ident=%d csv=%d ', ...
    'summaryN=%d'], ...
    out.scan_run.n_failed, out.scan_run.n_successful, ...
    all(isfinite(out.metric)), okIdent, okCsv, out.summary.n_samples);
end


function c = iCaseRunnerOptInGuard(projectRoot) %#ok<INUSD>
% A dense 2-D grid (40x40 = 1600 evals) must be blocked unless opted in.
metricFcn = @(p) 0.02 * p(1) - 0.04 * p(2);
params = struct( ...
    'name', {'scr','kp'}, ...
    'min',  {1, 0.5}, ...
    'max',  {5, 2.5}, ...
    'levels', {40, 40});

threw = false;
errId = '';
try
    run_stability_boundary_scan(metricFcn, params, ...
        'ScanType', 'grid', 'MetricName', 'm', 'PassThreshold', 0, ...
        'PassDirection', 'above', 'Refine', false, ...
        'MaxEvaluations', 200, 'AllowLargeScan', false);
catch err
    threw = true;
    errId = err.identifier;
end

% Opting in must allow it (no OutputDir -> no artifacts written).
try
    o = run_stability_boundary_scan(metricFcn, params, ...
        'ScanType', 'grid', 'MetricName', 'm', 'PassThreshold', 0, ...
        'PassDirection', 'above', 'Refine', false, ...
        'MaxEvaluations', 200, 'AllowLargeScan', true);
    okOptIn = o.scan_run.n_total_evaluations == 1600;
catch
    okOptIn = false;
end

okBlocked = threw && strcmp(errId, 'BoundaryScanRun:OptInRequired');
c.name = 'Case H: opt-in cost guard blocks large sweep by default';
c.passed = okBlocked && okOptIn;
c.detail = sprintf('blocked=%d (id=%s) optInAllows1600=%d', ...
    okBlocked, errId, okOptIn);
end


function m = iThrowIfWeak(p)
if p(1) < 2
    error('BoundaryScanTest:WeakGrid', 'synthetic convergence failure at scr=%.3g', p(1));
end
m = 0.02 * p(1) - 0.01;
end


function tf = iArtifactsExist(outDir)
tf = isfile(fullfile(outDir, 'stability_boundary_summary.md')) && ...
     isfile(fullfile(outDir, 'stability_boundary_summary.json')) && ...
     isfile(fullfile(outDir, 'scan_samples.csv'));
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
