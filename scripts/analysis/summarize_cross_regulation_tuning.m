function summary = summarize_cross_regulation_tuning(tuning, varargin)
%SUMMARIZE_CROSS_REGULATION_TUNING Summarize coupled control-loop tuning evidence.
%
%   summary = summarize_cross_regulation_tuning(tuning, ...
%       "CaseName","dfig_dq_current", "OutputDir",dir)
%
%   Input
%     tuning  struct describing a multivariable / cross-regulation tuning case:
%       .loops              struct array, one entry per control loop, fields:
%           name            char/string, loop id (e.g. "id_current")
%           type            "PI" | "PID" | other (default "PI")
%           kp_before/.._after, ki_before/.._after, kd_before/.._after (numeric)
%           sample_time_s   control sample time (s), >0
%           bandwidth_target_hz   target closed-loop / crossover bandwidth (Hz)
%           bandwidth_achieved_hz (optional) achieved bandwidth (Hz)
%           output_min/output_max saturation limits (use unsaturated=true if none)
%           anti_windup     logical/char, anti-windup scheme
%           phase_margin_deg / gain_margin_db / damping_ratio  margin evidence
%           disturbance_channels  string array (what this loop rejects)
%           rationale       char/string, WHY this loop was (re)tuned
%       .cross_coupling     NxN numeric coupling matrix (0..1 relative) over the
%                           loops in .loops order, OR omit if undocumented
%       .gain_matrix        NxN steady-state (or at-frequency) gain matrix G
%                           mapping loop inputs to loop outputs, used for the
%                           RGA and singular-value interaction metric. Optional;
%                           omit if no model/identification gain is available.
%       .time_domain        optional struct linking a measured disturbance run:
%           artifact_path   path to a time-domain run artifact (md/json/csv/mat)
%           source          "simulation" | "measurement" | "synthetic"
%           disturbance     char/string, the disturbance applied
%           settling_time_s / overshoot_pct / peak_coupling  measured metrics
%       .operating_point    char/string (load, SCR/ESCR, control mode)
%       .control_frame      "dq" | "sequence" | "abc" | other
%       .model_path         char/string
%
%   Per loop, optional before/after MARGIN fields enable an improvement check:
%       phase_margin_before_deg / phase_margin_after_deg
%       gain_margin_before_db   / gain_margin_after_db
%       damping_before          / damping_after
%   (phase_margin_deg / gain_margin_db / damping_ratio are read as the "after"
%   value when the explicit *_after field is absent.)
%
%   An IMPROVEMENT is only reported as supported when before AND after margins
%   are present, the after margin is better, AND a model-backed (or measured)
%   time-domain artifact is linked. A documented gain change with no measured
%   before/after evidence is reported as an unverified claim, never an
%   improvement. Evidence is tiered: contract_consistency < model_backed <
%   hardware_backed.
%
%   This helper produces a TUNING-EVIDENCE CONTRACT summary. It distinguishes a
%   DOCUMENTED tuning result (gains + sampling + saturation + bandwidth target +
%   a stability/damping margin + a retune rationale, taken at a stated operating
%   point with a documented cross-coupling structure) from an UNDOCUMENTED GAIN
%   TWEAK (a gain change with no rationale, margin, or bandwidth target). It does
%   NOT run a Simulink tuning loop and does NOT prove closed-loop stability;
%   linear margins are small-signal screens that must be confirmed in the
%   time domain.
%
%   See .agents/skills/multivariable-control-cross-regulation/references/
%       cross-regulation-contract.md

arguments
    tuning struct
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
loops = iNormalizeLoops(tuning);
loops = iAssessLoops(loops, opts);
coupling = iAssessCoupling(tuning, loops, opts);
interaction = iAssessInteraction(tuning, loops, opts);
timeDomain = iAssessTimeDomain(tuning, opts);
improvement = iAssessImprovement(loops, timeDomain);
[caseMissing, loopMissing] = iCollectMissing(tuning, loops, coupling);
missing = [caseMissing, loopMissing];

summary = struct();
summary.case_name = char(opts.CaseName);
summary.model_path = iGetStr(tuning, "model_path", "");
summary.operating_point = iGetStr(tuning, "operating_point", "");
summary.control_frame = iGetStr(tuning, "control_frame", "");
summary.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));
summary.n_loops = numel(loops);
summary.loops = loops;
summary.coupling = coupling;
summary.interaction = interaction;
summary.disturbance_channels = iCollectDisturbances(loops);
summary.margin_assessment = iMarginAssessment(loops, opts);
summary.margin_comparison = iMarginComparison(loops);
summary.time_domain = timeDomain;
summary.improvement = improvement;
summary.evidence_tier = iEvidenceTier(timeDomain);
summary.n_documented = nnz(string({loops.status}) == "documented");
summary.n_provisional = nnz(string({loops.status}) == "provisional");
summary.n_gain_changes = nnz([loops.gain_changed]);
summary.missing_required = missing;
summary.provisional = ~isempty(missing);
summary.classification = iClassify(summary, loops);
summary.limitations = char(opts.LimitationsNote);

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, summary);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("CaseName", "cross_regulation_case", @(x) ischar(x) || isstring(x));
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("PhaseMarginGoodDeg", 45, @(x) isnumeric(x) && isscalar(x));
p.addParameter("PhaseMarginWeakDeg", 30, @(x) isnumeric(x) && isscalar(x));
p.addParameter("GainMarginGoodDb", 6, @(x) isnumeric(x) && isscalar(x));
p.addParameter("GainMarginWeakDb", 3, @(x) isnumeric(x) && isscalar(x));
p.addParameter("DampingGood", 0.10, @(x) isnumeric(x) && isscalar(x));
p.addParameter("DampingWeak", 0.03, @(x) isnumeric(x) && isscalar(x));
p.addParameter("StrongCouplingThreshold", 0.30, @(x) isnumeric(x) && isscalar(x));
p.addParameter("RgaPairingTolerance", 0.30, @(x) isnumeric(x) && isscalar(x));
p.addParameter("CurrentIterationDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("LimitationsNote", ...
    "Tuning-evidence contract from supplied metadata; not a Simulink tuning run. Linear margins are small-signal screens; confirm closed-loop stability and cross-regulation in the time domain.", ...
    @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.CaseName = string(opts.CaseName);
opts.OutputDir = string(opts.OutputDir);
opts.CurrentIterationDir = string(opts.CurrentIterationDir);
opts.LimitationsNote = string(opts.LimitationsNote);
end


function loops = iNormalizeLoops(tuning)
if ~isfield(tuning, "loops") || isempty(tuning.loops)
    loops = iEmptyLoopArray();
    return
end
src = tuning.loops;
loops = repmat(iEmptyLoop(), 1, numel(src));
for k = 1:numel(src)
    s = src(k);
    L = iEmptyLoop();
    L.name = iGetStr(s, "name", sprintf("loop_%d", k));
    L.type = iGetStr(s, "type", "PI");
    L.kp_before = iGetNum(s, "kp_before");
    L.kp_after = iGetNum(s, "kp_after");
    L.ki_before = iGetNum(s, "ki_before");
    L.ki_after = iGetNum(s, "ki_after");
    L.kd_before = iGetNum(s, "kd_before");
    L.kd_after = iGetNum(s, "kd_after");
    L.sample_time_s = iGetNum(s, "sample_time_s");
    L.bandwidth_target_hz = iGetNum(s, "bandwidth_target_hz");
    L.bandwidth_achieved_hz = iGetNum(s, "bandwidth_achieved_hz");
    L.output_min = iGetNum(s, "output_min");
    L.output_max = iGetNum(s, "output_max");
    L.unsaturated = iGetLogical(s, "unsaturated", false);
    L.anti_windup = iGetStr(s, "anti_windup", "");
    L.phase_margin_deg = iGetNum(s, "phase_margin_deg");
    L.gain_margin_db = iGetNum(s, "gain_margin_db");
    L.damping_ratio = iGetNum(s, "damping_ratio");
    % Before/after margins for the improvement check. The "after" value falls
    % back to the plain margin field when an explicit *_after is not supplied.
    L.phase_margin_before_deg = iGetNum(s, "phase_margin_before_deg");
    L.phase_margin_after_deg = iCoalesce(iGetNum(s, "phase_margin_after_deg"), L.phase_margin_deg);
    L.gain_margin_before_db = iGetNum(s, "gain_margin_before_db");
    L.gain_margin_after_db = iCoalesce(iGetNum(s, "gain_margin_after_db"), L.gain_margin_db);
    L.damping_before = iGetNum(s, "damping_before");
    L.damping_after = iCoalesce(iGetNum(s, "damping_after"), L.damping_ratio);
    L.disturbance_channels = iGetStrArray(s, "disturbance_channels");
    L.rationale = iGetStr(s, "rationale", "");
    loops(k) = L;
end
end
function loops = iAssessLoops(loops, opts)
% Per-loop documentation status and derived sampling/bandwidth checks. A loop is
% "documented" only when it carries the evidence that separates a real tuning
% result from a blind gain tweak: a retune rationale, a stability/damping
% margin, a bandwidth target, a sample time, and saturation handling.
for k = 1:numel(loops)
    L = loops(k);
    L.gain_changed = iGainChanged(L);

    % Sampling adequacy: a fast loop sampled too slowly cannot hit its target.
    % Rule of thumb fs >= 10 * bandwidth_target. Reported, not pass/fail-fatal.
    L.fs_hz = iSafeInv(L.sample_time_s);
    if ~isnan(L.fs_hz) && ~isnan(L.bandwidth_target_hz) && L.bandwidth_target_hz > 0
        L.fs_to_bw_ratio = L.fs_hz / L.bandwidth_target_hz;
        L.sampling_adequate = L.fs_to_bw_ratio >= 10;
    else
        L.fs_to_bw_ratio = NaN;
        L.sampling_adequate = false;
    end

    % Bandwidth realized vs target (when achieved is supplied).
    if ~isnan(L.bandwidth_achieved_hz) && ~isnan(L.bandwidth_target_hz) ...
            && L.bandwidth_target_hz > 0
        L.bandwidth_error_pct = ...
            100 * (L.bandwidth_achieved_hz - L.bandwidth_target_hz) / L.bandwidth_target_hz;
    else
        L.bandwidth_error_pct = NaN;
    end

    L.margin_class = iMarginClass(L, opts);
    L.saturation_documented = L.unsaturated || ...
        (~isnan(L.output_min) && ~isnan(L.output_max));
    % A margin counts whether supplied as a plain value or as an after-value
    % from the before/after improvement path.
    L.has_margin = ~isnan(L.phase_margin_deg) || ~isnan(L.gain_margin_db) ...
        || ~isnan(L.damping_ratio) || ~isnan(L.phase_margin_after_deg) ...
        || ~isnan(L.gain_margin_after_db) || ~isnan(L.damping_after);
    L.has_rationale = strlength(string(L.rationale)) > 0;

    miss = iLoopMissingFields(L);
    L.loop_missing = miss;
    if isempty(miss)
        L.status = "documented";
    else
        L.status = "provisional";
    end
    loops(k) = L;
end
end


function tf = iGainChanged(L)
pairs = [L.kp_before L.kp_after; L.ki_before L.ki_after; L.kd_before L.kd_after];
tf = false;
for r = 1:size(pairs,1)
    b = pairs(r,1); a = pairs(r,2);
    if ~isnan(a) && (isnan(b) || a ~= b)
        tf = true; return
    end
end
end


function miss = iLoopMissingFields(L)
% Fields that must be present for a loop to count as DOCUMENTED tuning evidence
% rather than an undocumented gain tweak.
miss = strings(1,0);
if isnan(L.sample_time_s) || L.sample_time_s <= 0
    miss(end+1) = "sample_time_s";
end
if isnan(L.bandwidth_target_hz) || L.bandwidth_target_hz <= 0
    miss(end+1) = "bandwidth_target_hz";
end
if ~L.saturation_documented
    miss(end+1) = "saturation_limits";
end
if ~L.has_margin
    miss(end+1) = "stability_margin";
end
if ~L.has_rationale
    miss(end+1) = "rationale";
end
end


function cls = iMarginClass(L, opts)
% Worst-case classification across whichever margin metrics are present. Each
% metric falls back to its after-value when the plain field is absent, so a
% loop tuned through the before/after path is still classified.
cls = "unknown";
ranks = [];  % 3 good, 2 weak, 1 unstable
pm = iCoalesce(L.phase_margin_deg, L.phase_margin_after_deg);
gm = iCoalesce(L.gain_margin_db, L.gain_margin_after_db);
zeta = iCoalesce(L.damping_ratio, L.damping_after);
if ~isnan(pm)
    ranks(end+1) = iRank(pm, opts.PhaseMarginGoodDeg, opts.PhaseMarginWeakDeg, 0);
end
if ~isnan(gm)
    ranks(end+1) = iRank(gm, opts.GainMarginGoodDb, opts.GainMarginWeakDb, 0);
end
if ~isnan(zeta)
    ranks(end+1) = iRank(zeta, opts.DampingGood, opts.DampingWeak, 0);
end
if isempty(ranks); return; end
switch min(ranks)
    case 3; cls = "good";
    case 2; cls = "weak";
    otherwise; cls = "at_risk";
end
end


function r = iRank(val, goodTh, weakTh, hardFloor)
if val <= hardFloor
    r = 1;          % non-positive margin/damping: unstable screen
elseif val >= goodTh
    r = 3;
elseif val >= weakTh
    r = 2;
else
    r = 1;
end
end


function coupling = iAssessCoupling(tuning, loops, opts)
coupling = struct("documented", false, "n", numel(loops), "matrix", [], ...
    "max_off_diagonal", NaN, "strong_pairs", {{}}, ...
    "strongly_coupled", false, "note", "");
if ~isfield(tuning, "cross_coupling") || isempty(tuning.cross_coupling)
    coupling.note = 'cross-coupling matrix undocumented; cross-regulation risk unscreened';
    return
end
M = double(tuning.cross_coupling);
n = numel(loops);
if size(M,1) ~= size(M,2)
    coupling.note = 'cross_coupling must be square; ignored';
    return
end
if n > 0 && size(M,1) ~= n
    coupling.note = sprintf('cross_coupling is %dx%d but %d loops; ignored', ...
        size(M,1), size(M,2), n);
    return
end
coupling.documented = true;
coupling.matrix = M;
offMask = ~eye(size(M)) > 0;
offVals = abs(M(offMask));
if isempty(offVals)
    coupling.max_off_diagonal = 0;
else
    coupling.max_off_diagonal = max(offVals);
end
th = opts.StrongCouplingThreshold;
strong = {};
for i = 1:size(M,1)
    for j = 1:size(M,2)
        if i ~= j && abs(M(i,j)) >= th
            ni = iLoopName(loops, i); nj = iLoopName(loops, j);
            strong{end+1} = sprintf("%s->%s=%.2f", ni, nj, M(i,j)); %#ok<AGROW>
        end
    end
end
coupling.strong_pairs = strong;
coupling.strongly_coupled = ~isempty(strong);
if coupling.strongly_coupled
    coupling.note = sprintf(['strong cross-regulation (|c|>=%.2f) on %d pair(s): ' ...
        'tune as a coupled MIMO system, not independent SISO loops'], th, numel(strong));
else
    coupling.note = sprintf('off-diagonal coupling below %.2f; near-decoupled SISO tuning acceptable', th);
end
end


function interaction = iAssessInteraction(tuning, loops, opts)
% Reproducible multivariable interaction metric from a supplied steady-state
% gain matrix G: the Relative Gain Array RGA = G .* inv(G).' (Bristol), plus a
% singular-value screen (sigma_max, sigma_min, condition number). RGA diagonal
% elements near 1 favour the diagonal input-output pairing; a large condition
% number signals an ill-conditioned, strongly interactive plant. Pure
% base-MATLAB (inv/svd/pinv); the caller supplies G from a model or
% identification, so this is contract-consistent evidence, not a model run.
interaction = struct("documented", false, "n", numel(loops), ...
    "gain_matrix", [], "rga", [], "rga_diagonal", [], ...
    "pairing", "undocumented", "pairing_ok", false, ...
    "max_off_diagonal_rga", NaN, "sigma_max", NaN, "sigma_min", NaN, ...
    "condition_number", NaN, "ill_conditioned", false, "note", "");
if ~isfield(tuning, "gain_matrix") || isempty(tuning.gain_matrix)
    interaction.note = 'gain_matrix undocumented; RGA / singular-value interaction metric not computed';
    return
end
G = double(tuning.gain_matrix);
if size(G,1) ~= size(G,2)
    interaction.note = 'gain_matrix must be square; interaction metric skipped';
    return
end
n = numel(loops);
if n > 0 && size(G,1) ~= n
    interaction.note = sprintf('gain_matrix is %dx%d but %d loops; interaction metric skipped', ...
        size(G,1), size(G,2), n);
    return
end

% Singular values: always defined.
sv = svd(G);
interaction.sigma_max = sv(1);
interaction.sigma_min = sv(end);
if sv(end) > 0
    interaction.condition_number = sv(1) / sv(end);
else
    interaction.condition_number = Inf;
end
interaction.ill_conditioned = interaction.condition_number >= 10;

% RGA needs an invertible G. Use pinv for a singular/near-singular plant and
% flag it rather than erroring.
if rcond(G) < eps || ~all(isfinite(G(:)))
    interaction.documented = true;
    interaction.gain_matrix = G;
    interaction.note = sprintf(['gain matrix singular/ill-posed (cond=%.4g); ' ...
        'RGA not reliable, reporting singular values only'], interaction.condition_number);
    return
end
RGA = G .* (inv(G)).';
interaction.documented = true;
interaction.gain_matrix = G;
interaction.rga = RGA;
interaction.rga_diagonal = diag(RGA).';

offMask = ~eye(size(RGA)) > 0;
offRGA = RGA(offMask);
if isempty(offRGA)
    interaction.max_off_diagonal_rga = 0;
else
    interaction.max_off_diagonal_rga = max(abs(offRGA));
end

% Diagonal pairing is recommended when every diagonal RGA element is within
% tolerance of 1 (and none is negative, which would warn against the pairing).
tol = opts.RgaPairingTolerance;
d = interaction.rga_diagonal;
nearOne = all(abs(d - 1) <= tol);
anyNeg = any(d < 0);
if anyNeg
    interaction.pairing = "avoid_diagonal_negative_rga";
    interaction.pairing_ok = false;
elseif nearOne
    interaction.pairing = "diagonal_recommended";
    interaction.pairing_ok = true;
else
    interaction.pairing = "strong_interaction_review_pairing";
    interaction.pairing_ok = false;
end
interaction.note = sprintf('RGA diag=[%s]; pairing=%s; cond(G)=%.4g (%s)', ...
    iJoinNums(d), interaction.pairing, interaction.condition_number, ...
    iIllText(interaction.ill_conditioned));
end


function s = iJoinNums(v)
parts = strings(1, numel(v));
for k = 1:numel(v)
    parts(k) = sprintf("%.3g", v(k));
end
s = strjoin(parts, ", ");
end


function t = iIllText(tf)
if tf; t = "ill-conditioned"; else; t = "well-conditioned"; end
end


function td = iAssessTimeDomain(tuning, opts)
% Link to a measured/simulated time-domain disturbance run. The artifact's
% existence on disk and its source decide the evidence tier; a same-iteration
% check (when CurrentIterationDir is given) prevents a stale prior-run artifact
% from backing a new tuning claim.
td = struct("documented", false, "artifact_path", "", "source", "", ...
    "disturbance", "", "settling_time_s", NaN, "overshoot_pct", NaN, ...
    "peak_coupling", NaN, "artifact_exists", false, "same_iteration", true, ...
    "model_backed", false, "note", "");
if ~isfield(tuning, "time_domain") || isempty(tuning.time_domain)
    td.note = 'no linked time-domain disturbance run';
    return
end
s = tuning.time_domain;
td.documented = true;
td.artifact_path = iGetStr(s, "artifact_path", "");
td.source = lower(iGetStr(s, "source", ""));
td.disturbance = iGetStr(s, "disturbance", "");
td.settling_time_s = iGetNum(s, "settling_time_s");
td.overshoot_pct = iGetNum(s, "overshoot_pct");
td.peak_coupling = iGetNum(s, "peak_coupling");

if strlength(string(td.artifact_path)) > 0
    td.artifact_exists = isfile(td.artifact_path);
end
% Same-iteration defence: if a current iteration dir is supplied, the artifact
% must live under it (canonical prefix match) to back a same-iteration claim.
if strlength(opts.CurrentIterationDir) > 0 && td.artifact_exists
    td.same_iteration = iUnderDir(td.artifact_path, opts.CurrentIterationDir);
end
% Model-backed means a real simulation/measurement artifact that exists and is
% same-iteration. A "synthetic" source is contract-consistent, not model-backed.
td.model_backed = td.artifact_exists && td.same_iteration && ...
    any(strcmp(td.source, {'simulation','measurement'}));
if ~td.artifact_exists && strlength(string(td.artifact_path)) > 0
    td.note = 'time-domain artifact path supplied but file is absent';
elseif ~td.same_iteration
    td.note = 'time-domain artifact is not under the current iteration dir (stale)';
elseif td.model_backed
    td.note = sprintf('model-backed time-domain run (%s)', td.source);
else
    td.note = sprintf('time-domain link present but not model-backed (source=%s)', td.source);
end
end


function mc = iMarginComparison(loops)
% Per-loop before/after margin deltas. "improved" requires BOTH endpoints on at
% least one metric and a net non-worsening with at least one strict gain.
mc = struct("documented", false, "n_with_before_after", 0, ...
    "n_improved", 0, "n_worsened", 0, "loops", iEmptyMarginCmpArray(), "note", "");
if isempty(loops); mc.note = 'no loops'; return; end
items = iEmptyMarginCmpArray();
cnt = 0;
for k = 1:numel(loops)
    L = loops(k);
    c = iEmptyMarginCmp();
    c.name = L.name;
    [c.phase_before, c.phase_after, c.phase_delta, hasP] = ...
        iDelta(L.phase_margin_before_deg, L.phase_margin_after_deg);
    [c.gain_before, c.gain_after, c.gain_delta, hasG] = ...
        iDelta(L.gain_margin_before_db, L.gain_margin_after_db);
    [c.damping_before, c.damping_after, c.damping_delta, hasD] = ...
        iDelta(L.damping_before, L.damping_after);
    c.has_before_after = hasP || hasG || hasD;
    deltas = [c.phase_delta, c.gain_delta, c.damping_delta];
    present = [hasP, hasG, hasD];
    dPresent = deltas(present);
    if c.has_before_after
        if any(dPresent > 0) && all(dPresent >= 0)
            c.verdict = "improved";
        elseif any(dPresent < 0)
            c.verdict = "worsened";
        else
            c.verdict = "unchanged";
        end
    else
        c.verdict = "no_before_after";
    end
    cnt = cnt + 1;
    items(cnt) = c;
end
mc.loops = items;
mc.documented = any([items.has_before_after]);
mc.n_with_before_after = nnz([items.has_before_after]);
mc.n_improved = nnz(string({items.verdict}) == "improved");
mc.n_worsened = nnz(string({items.verdict}) == "worsened");
if mc.documented
    mc.note = sprintf('%d/%d loops have before/after margins; %d improved, %d worsened', ...
        mc.n_with_before_after, numel(loops), mc.n_improved, mc.n_worsened);
else
    mc.note = 'no before/after margins supplied; improvement cannot be measured';
end
end


function imp = iAssessImprovement(loops, timeDomain)
% The improvement GATE. A retune is a SUPPORTED improvement only when measured
% before/after margins improve AND a model-backed time-domain artifact backs it.
% A documented gain change without that evidence is "claimed_unverified" - it is
% never silently reported as an improvement.
mc = iMarginComparison(loops);
imp = struct("status", "no_change", "margin_improved", false, ...
    "time_domain_backed", false, "n_improved", mc.n_improved, ...
    "n_worsened", mc.n_worsened, "note", "");
anyGainChange = any([loops.gain_changed]);
imp.margin_improved = mc.n_improved > 0 && mc.n_worsened == 0;
imp.time_domain_backed = timeDomain.model_backed;

if mc.n_worsened > 0
    imp.status = "regression";
    imp.note = 'at least one loop margin worsened; not an improvement';
elseif imp.margin_improved && imp.time_domain_backed
    imp.status = "supported";
    imp.note = 'before/after margins improved and a model-backed disturbance run is linked';
elseif imp.margin_improved && ~imp.time_domain_backed
    imp.status = "margin_only_unverified";
    imp.note = 'margins improved on paper but no model-backed time-domain run; not a validated improvement';
elseif anyGainChange && ~mc.documented
    imp.status = "claimed_unverified";
    imp.note = 'gains changed but no before/after margin evidence; cannot claim improvement';
else
    imp.status = "no_change";
    imp.note = 'no measured margin improvement to report';
end
end


function tier = iEvidenceTier(timeDomain)
% Evidence tier ladder. hardware_backed only on an explicit measurement
% artifact; model_backed on a same-iteration simulation artifact; everything
% else is contract_consistency (metadata only).
if timeDomain.artifact_exists && timeDomain.same_iteration && ...
        strcmp(timeDomain.source, 'measurement')
    tier = "hardware_backed";
elseif timeDomain.model_backed
    tier = "model_backed";
else
    tier = "contract_consistency";
end
end


function [b, a, d, has] = iDelta(before, after)
b = before; a = after;
if ~isnan(before) && ~isnan(after)
    d = after - before;
    has = true;
else
    d = NaN;
    has = false;
end
end


function tf = iUnderDir(path, dir)
% Canonical prefix match: is path inside dir?
fp = iCanon(path);
dp = iCanon(dir);
if strlength(dp) == 0
    tf = true; return
end
tf = startsWith(fp, dp);
end


function c = iCanon(p)
c = string(p);
c = replace(c, "\", "/");
c = lower(c);
c = regexprep(c, "/+$", "");
end


function v = iCoalesce(primary, fallback)
if isnan(primary)
    v = fallback;
else
    v = primary;
end
end


function [caseMissing, loopMissing] = iCollectMissing(tuning, loops, coupling)
% Case-level required metadata: a coupled-tuning result is only trustworthy at a
% stated operating point and control frame, with a documented coupling
% structure. Loop-level required fields are namespaced by loop name.
caseMissing = strings(1,0);
if strlength(iGetStr(tuning, "operating_point", "")) == 0
    caseMissing(end+1) = "operating_point";
end
if strlength(iGetStr(tuning, "control_frame", "")) == 0
    caseMissing(end+1) = "control_frame";
end
if numel(loops) >= 2 && ~coupling.documented
    caseMissing(end+1) = "cross_coupling";
end
if numel(loops) == 0
    caseMissing(end+1) = "loops";
end
loopMissing = strings(1,0);
for k = 1:numel(loops)
    for m = 1:numel(loops(k).loop_missing)
        loopMissing(end+1) = sprintf("%s.%s", loops(k).name, loops(k).loop_missing(m)); %#ok<AGROW>
    end
end
end


function d = iCollectDisturbances(loops)
d = strings(1,0);
for k = 1:numel(loops)
    dc = loops(k).disturbance_channels;
    for j = 1:numel(dc)
        if ~any(strcmp(d, dc(j)))
            d(end+1) = dc(j); %#ok<AGROW>
        end
    end
end
end


function ma = iMarginAssessment(loops, ~)
ma = struct("n_with_margin", 0, "n_good", 0, "n_weak", 0, "n_at_risk", 0, ...
    "worst_class", "unknown", "note", "");
if isempty(loops); ma.note = 'no loops supplied'; return; end
classes = string({loops.margin_class});
ma.n_with_margin = nnz([loops.has_margin]);
ma.n_good = nnz(classes == "good");
ma.n_weak = nnz(classes == "weak");
ma.n_at_risk = nnz(classes == "at_risk");
if ma.n_at_risk > 0
    ma.worst_class = "at_risk";
elseif ma.n_weak > 0
    ma.worst_class = "weak";
elseif ma.n_good > 0
    ma.worst_class = "good";
end
ma.note = sprintf('%d/%d loops carry a margin metric', ma.n_with_margin, numel(loops));
end


function cls = iClassify(summary, loops)
% Top-level verdict the contract test keys on.
if isempty(loops)
    cls = "incomplete_no_loops";
    return
end
if summary.provisional
    if summary.n_gain_changes > 0 && summary.n_documented == 0
        cls = "undocumented_gain_tweak";
    else
        cls = "provisional";
    end
    return
end
if summary.margin_assessment.worst_class == "at_risk"
    cls = "documented_at_risk";
elseif summary.margin_assessment.worst_class == "weak"
    cls = "documented_marginal";
else
    cls = "documented_tuning";
end
end


function name = iLoopName(loops, idx)
if idx >= 1 && idx <= numel(loops)
    name = string(loops(idx).name);
else
    name = sprintf("loop_%d", idx);
end
end


function v = iSafeInv(x)
if isnan(x) || x <= 0
    v = NaN;
else
    v = 1 / x;
end
end
function s = iGetStr(strct, field, default)
if isfield(strct, field) && ~isempty(strct.(field)) && ...
        (ischar(strct.(field)) || isstring(strct.(field)))
    s = char(string(strct.(field)));
else
    s = char(default);
end
end


function v = iGetNum(strct, field)
if isfield(strct, field) && ~isempty(strct.(field)) && isnumeric(strct.(field))
    v = double(strct.(field)(1));
else
    v = NaN;
end
end


function tf = iGetLogical(strct, field, default)
if isfield(strct, field) && ~isempty(strct.(field))
    tf = logical(strct.(field)(1));
else
    tf = default;
end
end


function a = iGetStrArray(strct, field)
if isfield(strct, field) && ~isempty(strct.(field))
    a = string(strct.(field));
    a = a(:)';
else
    a = strings(1,0);
end
end


function L = iEmptyLoop()
L = struct( ...
    "name","", "type","PI", ...
    "kp_before",NaN, "kp_after",NaN, "ki_before",NaN, "ki_after",NaN, ...
    "kd_before",NaN, "kd_after",NaN, ...
    "sample_time_s",NaN, "fs_hz",NaN, ...
    "bandwidth_target_hz",NaN, "bandwidth_achieved_hz",NaN, ...
    "bandwidth_error_pct",NaN, "fs_to_bw_ratio",NaN, "sampling_adequate",false, ...
    "output_min",NaN, "output_max",NaN, "unsaturated",false, ...
    "saturation_documented",false, "anti_windup","", ...
    "phase_margin_deg",NaN, "gain_margin_db",NaN, "damping_ratio",NaN, ...
    "phase_margin_before_deg",NaN, "phase_margin_after_deg",NaN, ...
    "gain_margin_before_db",NaN, "gain_margin_after_db",NaN, ...
    "damping_before",NaN, "damping_after",NaN, ...
    "margin_class","unknown", "has_margin",false, ...
    "disturbance_channels",strings(1,0), "rationale","", "has_rationale",false, ...
    "gain_changed",false, "loop_missing",strings(1,0), "status","provisional");
end


function c = iEmptyMarginCmp()
c = struct("name","", ...
    "phase_before",NaN, "phase_after",NaN, "phase_delta",NaN, ...
    "gain_before",NaN, "gain_after",NaN, "gain_delta",NaN, ...
    "damping_before",NaN, "damping_after",NaN, "damping_delta",NaN, ...
    "has_before_after",false, "verdict","no_before_after");
end


function arr = iEmptyMarginCmpArray()
arr = iEmptyMarginCmp();
arr = arr([]);
end


function arr = iEmptyLoopArray()
arr = iEmptyLoop();
arr = arr([]);
end
function iWriteOutputs(outDir, summary)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "cross_regulation_summary.json"), summary);
iWriteMarkdown(fullfile(outDir, "cross_regulation_summary.md"), summary);
iWriteCsv(fullfile(outDir, "loop_tuning.csv"), summary);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("CrossRegTuning:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("CrossRegTuning:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Multivariable / Cross-Regulation Tuning Summary\n\n");
fprintf(fid, "Case: `%s`\n", summary.case_name);
if summary.provisional
    fprintf(fid, "\n> **PROVISIONAL / %s** - missing: %s\n\n", ...
        upper(strrep(summary.classification, "_", " ")), ...
        strjoin(cellstr(summary.missing_required), ", "));
else
    fprintf(fid, "\nClassification: **%s**\n\n", ...
        upper(strrep(summary.classification, "_", " ")));
end
fprintf(fid, "Operating point: %s | Control frame: %s\n", ...
    iDash(summary.operating_point), iDash(summary.control_frame));
fprintf(fid, "Model: %s\n", iDash(summary.model_path));
fprintf(fid, "Loops: %d (documented %d, provisional %d, gain changes %d)\n", ...
    summary.n_loops, summary.n_documented, summary.n_provisional, summary.n_gain_changes);
fprintf(fid, "Evidence tier: **%s** | Improvement: **%s**\n", ...
    upper(strrep(summary.evidence_tier, "_", " ")), ...
    upper(strrep(summary.improvement.status, "_", " ")));
fprintf(fid, "Generated: %s\n\n", summary.generated_at);

fprintf(fid, "## Loops\n\n");
if summary.n_loops == 0
    fprintf(fid, "_No loops supplied._\n\n");
else
    fprintf(fid, "| Loop | Type | Kp b->a | Ki b->a | Ts s | BW tgt Hz | fs/BW | Margin | Status |\n");
    fprintf(fid, "|---|---|---|---|---:|---:|---:|---|---|\n");
    for k = 1:numel(summary.loops)
        L = summary.loops(k);
        fprintf(fid, "| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", ...
            L.name, L.type, iBA(L.kp_before, L.kp_after), iBA(L.ki_before, L.ki_after), ...
            iNum(L.sample_time_s), iNum(L.bandwidth_target_hz), iNum(L.fs_to_bw_ratio), ...
            L.margin_class, L.status);
    end
    fprintf(fid, "\n");
    for k = 1:numel(summary.loops)
        L = summary.loops(k);
        if ~isempty(L.loop_missing)
            fprintf(fid, "- `%s` missing: %s\n", L.name, ...
                strjoin(cellstr(L.loop_missing), ", "));
        end
        if L.has_rationale
            fprintf(fid, "- `%s` rationale: %s\n", L.name, L.rationale);
        end
    end
    fprintf(fid, "\n");
end

c = summary.coupling;
fprintf(fid, "## Cross-coupling\n\n");
fprintf(fid, "- documented: %d | strongly coupled: %d", c.documented, c.strongly_coupled);
if ~isnan(c.max_off_diagonal)
    fprintf(fid, " | max off-diagonal: %.3g", c.max_off_diagonal);
end
fprintf(fid, "\n");
if ~isempty(c.strong_pairs)
    fprintf(fid, "- strong pairs: %s\n", strjoin(cellstr(string(c.strong_pairs)), ", "));
end
fprintf(fid, "- %s\n\n", c.note);

ma = summary.margin_assessment;
fprintf(fid, "## Stability margins\n\n");
fprintf(fid, "- worst class: %s | good %d, weak %d, at_risk %d\n", ...
    ma.worst_class, ma.n_good, ma.n_weak, ma.n_at_risk);
fprintf(fid, "- %s\n\n", ma.note);

it = summary.interaction;
fprintf(fid, "## Multivariable interaction (RGA / singular values)\n\n");
if ~it.documented
    fprintf(fid, "- %s\n\n", it.note);
else
    if ~isempty(it.rga_diagonal)
        fprintf(fid, "- RGA diagonal: [%s]\n", iJoinNums(it.rga_diagonal));
        fprintf(fid, "- max |off-diagonal RGA|: %.3g\n", it.max_off_diagonal_rga);
        fprintf(fid, "- pairing: %s (ok: %d)\n", it.pairing, it.pairing_ok);
    end
    fprintf(fid, "- sigma_max: %.4g | sigma_min: %.4g | cond(G): %.4g (%s)\n", ...
        it.sigma_max, it.sigma_min, it.condition_number, iIllText(it.ill_conditioned));
    fprintf(fid, "- %s\n\n", it.note);
end

mcmp = summary.margin_comparison;
fprintf(fid, "## Before/after margin comparison\n\n");
if ~mcmp.documented
    fprintf(fid, "- %s\n\n", mcmp.note);
else
    fprintf(fid, "| Loop | PM b->a | dPM | GM b->a | dGM | zeta b->a | dzeta | Verdict |\n");
    fprintf(fid, "|---|---|---:|---|---:|---|---:|---|\n");
    for k = 1:numel(mcmp.loops)
        c = mcmp.loops(k);
        fprintf(fid, "| %s | %s | %s | %s | %s | %s | %s | %s |\n", ...
            c.name, iBA(c.phase_before, c.phase_after), iNum(c.phase_delta), ...
            iBA(c.gain_before, c.gain_after), iNum(c.gain_delta), ...
            iBA(c.damping_before, c.damping_after), iNum(c.damping_delta), c.verdict);
    end
    fprintf(fid, "\n- %s\n\n", mcmp.note);
end

td = summary.time_domain;
fprintf(fid, "## Linked time-domain disturbance run\n\n");
if ~td.documented
    fprintf(fid, "- %s\n\n", td.note);
else
    fprintf(fid, "- artifact: %s (exists: %d, same-iteration: %d)\n", ...
        iDash(td.artifact_path), td.artifact_exists, td.same_iteration);
    fprintf(fid, "- source: %s | disturbance: %s | model-backed: %d\n", ...
        iDash(td.source), iDash(td.disturbance), td.model_backed);
    fprintf(fid, "- settling_time_s: %s | overshoot_pct: %s | peak_coupling: %s\n", ...
        iNum(td.settling_time_s), iNum(td.overshoot_pct), iNum(td.peak_coupling));
    fprintf(fid, "- %s\n\n", td.note);
end

imp = summary.improvement;
fprintf(fid, "## Improvement verdict\n\n");
fprintf(fid, "- status: **%s**\n", upper(strrep(imp.status, "_", " ")));
fprintf(fid, "- margin improved: %d | time-domain backed: %d | evidence tier: %s\n", ...
    imp.margin_improved, imp.time_domain_backed, summary.evidence_tier);
fprintf(fid, "- %s\n\n", imp.note);

fprintf(fid, "## Disturbance channels\n\n");
if isempty(summary.disturbance_channels)
    fprintf(fid, "_None documented._\n\n");
else
    fprintf(fid, "%s\n\n", strjoin(cellstr(summary.disturbance_channels), ", "));
end

fprintf(fid, "## Limitations\n\n%s\n", summary.limitations);
end


function iWriteCsv(path, summary)
n = summary.n_loops;
if n == 0
    Name = strings(0,1); Type = strings(0,1);
    KpBefore = nan(0,1); KpAfter = nan(0,1); KiBefore = nan(0,1); KiAfter = nan(0,1);
    SampleTimeS = nan(0,1); BandwidthTargetHz = nan(0,1); FsToBwRatio = nan(0,1);
    MarginClass = strings(0,1); Status = strings(0,1);
else
    Name = strings(n,1); Type = strings(n,1);
    KpBefore = nan(n,1); KpAfter = nan(n,1); KiBefore = nan(n,1); KiAfter = nan(n,1);
    SampleTimeS = nan(n,1); BandwidthTargetHz = nan(n,1); FsToBwRatio = nan(n,1);
    MarginClass = strings(n,1); Status = strings(n,1);
    for k = 1:n
        L = summary.loops(k);
        Name(k) = string(L.name); Type(k) = string(L.type);
        KpBefore(k) = L.kp_before; KpAfter(k) = L.kp_after;
        KiBefore(k) = L.ki_before; KiAfter(k) = L.ki_after;
        SampleTimeS(k) = L.sample_time_s; BandwidthTargetHz(k) = L.bandwidth_target_hz;
        FsToBwRatio(k) = L.fs_to_bw_ratio;
        MarginClass(k) = string(L.margin_class); Status(k) = string(L.status);
    end
end
T = table(Name, Type, KpBefore, KpAfter, KiBefore, KiAfter, SampleTimeS, ...
    BandwidthTargetHz, FsToBwRatio, MarginClass, Status);
writetable(T, path);
end


function s = iBA(b, a)
s = sprintf("%s->%s", iNum(b), iNum(a));
end


function s = iNum(x)
if isnan(x)
    s = "-";
else
    s = sprintf("%.4g", x);
end
end


function s = iDash(x)
if isempty(char(x))
    s = "-";
else
    s = char(x);
end
end
