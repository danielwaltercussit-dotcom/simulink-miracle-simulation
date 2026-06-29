function summary = summarize_vsc_weakgrid_delay_benchmark(gflCase, gfmCase, conditions, varargin)
%SUMMARIZE_VSC_WEAKGRID_DELAY_BENCHMARK Weak-grid GFL/GFM delay + asymmetric-fault benchmark.
%
%   summary = summarize_vsc_weakgrid_delay_benchmark(gflCase, gfmCase, ...
%       conditions, "DelayCases",dc, "AsymmetricFaults",af, ...
%       "F2EvidencePath",p, "F3EvidencePath",p, "M1EvidencePath",p, ...
%       "OutputDir",dir)
%
%   Benchmarks a grid-following (gflCase) against a grid-forming (gfmCase) VSC
%   under a SHARED weak-grid condition set, so a fair delay-sensitivity and
%   asymmetric-fault comparison can be assembled. This helper is CONTRACT-LEVEL:
%   it scores documentation and same-study evidence pointers and classifies the
%   reported outcome. It runs NO Simulink model; `contract_status` and
%   `model_validation_status` are reported SEPARATELY and a model-backed verdict
%   requires a same-study time-domain artifact on both sides.
%
%   gflCase, gfmCase: VSC case descriptors (summarize_vsc_gfl_gfm_support shape).
%   conditions: shared benchmark condition struct with fields (all recommended):
%     operating_point  char/string  dispatch/load level both cases share
%     scr / escr       scalar       grid strength both cases share
%     disturbance      char/string  shared disturbance definition
%     solver           struct: .type .fixed_step_s (or .max_step_s) .as_declared
%     declared_delays  struct/array: named delay sources held constant
%   The PARITY GATE rejects the benchmark when operating_point, scr/escr,
%   solver, or declared-delay metadata differ between the two cases (or against
%   `conditions`) UNLESS the differing axis is named in conditions
%   .justified_differences. A documented-but-unjustified mismatch blocks the
%   comparison rather than silently averaging incomparable runs.
%
%   "DelayCases": array of delay-sensitivity points, each a struct with
%     .label, .total_delay_s (or .samples + .step_s), and optional
%     .outcome ("stable"|"marginal"|"unstable"). A delay-sensitivity claim is
%     only `model_backed` when F2 phase-margin/delay evidence (F2EvidencePath)
%     and M1 solver/delay evidence (M1EvidencePath) are supplied same-study.
%
%   "AsymmetricFaults": array of asymmetric-fault / voltage-unbalance records,
%     each a struct with .type ("slg"|"ll"|"llg"|"voltage_unbalance"),
%     .negative_sequence_handled (logical), .unbalance_factor_pct (scalar), and
%     optional .artifact (path). At least one record is REQUIRED.
%
%   Outcome classification (physical_instability | numerical_pseudo_instability
%   | mixed | insufficient_evidence) is derived from which evidence chains agree
%   (F3 boundary attribution + M1 pseudo-instability + asymmetric-fault). With
%   no F3/M1 evidence the outcome is `insufficient_evidence`, never a verdict.
%
%   See .agents/skills/device-pack-vsc-gfl-gfm/references/vsc-support-contract.md

arguments
    gflCase struct
    gfmCase struct
    conditions struct
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});

sGfl = summarize_vsc_gfl_gfm_support(gflCase);
sGfm = summarize_vsc_gfl_gfm_support(gfmCase);

modePair = iCheckModePair(sGfl, sGfm);
parity = iParityGate(gflCase, gfmCase, conditions);
delay = iDelaySensitivity(opts.DelayCases, opts.F2EvidencePath, opts.M1EvidencePath);
asym = iAsymmetricFaults(opts.AsymmetricFaults);
[outcome, classification] = iClassifyOutcome(opts.F3EvidencePath, opts.M1EvidencePath, asym);

contractStatus = iContractStatus(modePair, parity, delay, asym);
modelStatus = iModelValidationStatus(sGfl, sGfm, delay, opts.F3EvidencePath);

summary = struct();
summary.benchmark = "vsc_weakgrid_delay_benchmark";
summary.gfl_case = sGfl.case_name;
summary.gfm_case = sGfm.case_name;
summary.generated_at = sGfl.generated_at;
summary.conditions = iEchoConditions(conditions);
summary.mode_pair = modePair;
summary.parity = parity;
summary.delay_sensitivity = delay;
summary.asymmetric_faults = asym;
summary.outcome_classification = char(classification);
summary.outcome_detail = outcome;
summary.contract_status = char(contractStatus);
summary.model_validation_status = char(modelStatus);
summary.evidence_level = iEvidenceLevel(contractStatus, modelStatus);
summary.excluded_claims = iExcludedClaims();

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, summary);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("DelayCases", struct([]), @(x) isstruct(x) || isempty(x));
p.addParameter("AsymmetricFaults", struct([]), @(x) isstruct(x) || isempty(x));
p.addParameter("F2EvidencePath", "", @(x) ischar(x) || isstring(x));
p.addParameter("F3EvidencePath", "", @(x) ischar(x) || isstring(x));
p.addParameter("M1EvidencePath", "", @(x) ischar(x) || isstring(x));
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.F2EvidencePath = string(opts.F2EvidencePath);
opts.F3EvidencePath = string(opts.F3EvidencePath);
opts.M1EvidencePath = string(opts.M1EvidencePath);
opts.OutputDir = string(opts.OutputDir);
end


function mp = iCheckModePair(sGfl, sGfm)
% The benchmark only makes sense for one GFL vs one GFM device.
modes = sort(string({sGfl.control_mode, sGfm.control_mode}));
mp = struct();
mp.ok = isequal(modes, ["GFL", "GFM"]);
mp.gfl_mode = sGfl.control_mode;
mp.gfm_mode = sGfm.control_mode;
if mp.ok
    mp.detail = "pair is one GFL and one GFM device";
else
    mp.detail = char("benchmark needs one GFL + one GFM; got [" + ...
        string(sGfl.control_mode) + ", " + string(sGfm.control_mode) + "]");
end
end


function parity = iParityGate(gflCase, gfmCase, conditions)
% Reject the comparison when operating-point, grid-strength, solver, or
% declared-delay metadata differ between the two cases without an explicit
% rationale. A comparison across mismatched conditions is not a fair benchmark.
justified = iJustified(conditions);
checks = iEmptyParityArray();

checks(end+1) = iParityAxis("operating_point", ...
    iOpPoint(gflCase), iOpPoint(gfmCase), justified);
checks(end+1) = iParityAxis("grid_strength", ...
    iGridKey(gflCase), iGridKey(gfmCase), justified);
checks(end+1) = iParityAxis("solver", ...
    iSolverKey(gflCase, conditions), iSolverKey(gfmCase, conditions), justified);
checks(end+1) = iParityAxis("declared_delays", ...
    iDelayKey(gflCase, conditions), iDelayKey(gfmCase, conditions), justified);

parity = struct();
parity.checks = checks;
parity.justified_differences = cellstr(justified);
% The gate passes only when every axis matches or is explicitly justified.
parity.matched = all([checks.matched] | [checks.justified]);
parity.n_unjustified_mismatch = nnz(~[checks.matched] & ~[checks.justified]);
end


function c = iParityAxis(name, valA, valB, justified)
c = struct("axis", char(name), "value_gfl", char(valA), "value_gfm", char(valB), ...
    "matched", false, "justified", false, "detail", "");
c.matched = strcmp(valA, valB);
c.justified = any(strcmpi(name, justified));
if c.matched
    c.detail = char(string(name) + " shared (" + string(valA) + ")");
elseif c.justified
    c.detail = char(string(name) + " differs but justified (GFL=" + ...
        string(valA) + ", GFM=" + string(valB) + ")");
else
    c.detail = char(string(name) + " MISMATCH without rationale (GFL=" + ...
        string(valA) + ", GFM=" + string(valB) + ")");
end
end


function v = iOpPoint(c)
v = iCharField(c, "operating_point", "<unset>");
end


function v = iGridKey(c)
gs = iSubStruct(c, "grid_strength");
parts = strings(1, 0);
if isfield(gs, "scr") && isnumeric(gs.scr) && isscalar(gs.scr)
    parts(end+1) = sprintf("scr=%.4g", gs.scr);
end
if isfield(gs, "escr") && isnumeric(gs.escr) && isscalar(gs.escr)
    parts(end+1) = sprintf("escr=%.4g", gs.escr);
end
if isempty(parts)
    v = "<unset>";
else
    v = strjoin(parts, ",");
end
v = char(v);
end


function v = iSolverKey(c, conditions)
% Prefer the case's own solver block; fall back to the shared conditions one.
s = iSubStruct(c, "solver");
if ~iHasAnyField(s)
    s = iSubStruct(conditions, "solver");
end
typ = iCharField(s, "type", "<unset>");
step = "<unset>";
if isfield(s, "fixed_step_s") && isnumeric(s.fixed_step_s) && isscalar(s.fixed_step_s)
    step = sprintf("%.6g", s.fixed_step_s);
elseif isfield(s, "max_step_s") && isnumeric(s.max_step_s) && isscalar(s.max_step_s)
    step = sprintf("max%.6g", s.max_step_s);
end
v = char(string(typ) + "@" + string(step));
end


function v = iDelayKey(c, conditions)
% Canonical, order-independent signature of the declared delay sources.
dd = c;
if ~isfield(dd, "declared_delays")
    dd = conditions;
end
if isfield(dd, "declared_delays")
    v = iDelaySignature(dd.declared_delays);
else
    v = "<unset>";
end
v = char(v);
end


function sig = iDelaySignature(declared)
% Build a sorted "name=value" signature so order does not affect equality.
parts = strings(1, 0);
if isstruct(declared)
    fn = fieldnames(declared);
    if numel(declared) > 1 || (isscalar(declared) && isfield(declared, "label"))
        % array of {label,total_delay_s}
        parts = strings(1, numel(declared));
        for k = 1:numel(declared)
            d = declared(k);
            lbl = iCharField(d, "label", sprintf("d%d", k));
            val = iNumField(d, "total_delay_s", NaN);
            parts(k) = sprintf("%s=%.6g", lbl, val);
        end
    else
        parts = strings(1, numel(fn));
        nKept = 0;
        for k = 1:numel(fn)
            val = declared.(fn{k});
            if isnumeric(val) && isscalar(val)
                nKept = nKept + 1;
                parts(nKept) = sprintf("%s=%.6g", fn{k}, val);
            end
        end
        parts = parts(1:nKept);
    end
end
if isempty(parts)
    sig = "<unset>";
else
    sig = strjoin(sort(parts), ";");
end
end


function out = iEchoConditions(conditions)
out = struct();
out.operating_point = iCharField(conditions, "operating_point", "");
out.disturbance = iCharField(conditions, "disturbance", "");
s = iSubStruct(conditions, "solver");
out.solver_type = iCharField(s, "type", "");
out.justified_differences = cellstr(iJustified(conditions));
end


function delay = iDelaySensitivity(delayCases, f2Path, m1Path)
% A delay-sensitivity sweep needs >= 2 distinct total-delay points to be a
% sweep at all. A delay-sensitivity CLAIM is only model_backed when both F2
% (phase-margin/delay) and M1 (solver/delay) evidence files are supplied.
delay = struct();
delay.n_points = numel(delayCases);
pts = iEmptyDelayPtArray();
for k = 1:numel(delayCases)
    pts(end+1) = iDelayPoint(delayCases(k), k); %#ok<AGROW>
end
delay.points = pts;
delay.distinct_delays = iCountDistinctDelays(pts);
delay.is_sweep = delay.distinct_delays >= 2;
delay.f2_evidence = iEvidencePresence(f2Path);
delay.m1_evidence = iEvidencePresence(m1Path);
delay.model_backed = delay.is_sweep && delay.f2_evidence.present && ...
    delay.m1_evidence.present;
if ~delay.is_sweep
    delay.status = "insufficient";
    delay.detail = "fewer than 2 distinct delay points; not a sweep";
elseif delay.model_backed
    delay.status = "model_backed";
    delay.detail = "delay sweep backed by F2 margin/delay and M1 solver/delay evidence";
else
    delay.status = "contract_only";
    delay.detail = "delay sweep declared but missing F2 and/or M1 backing evidence";
end
end


function pt = iDelayPoint(d, idx)
pt = struct("label", "", "total_delay_s", NaN, "outcome", "");
pt.label = iCharField(d, "label", sprintf("delay_%d", idx));
if isfield(d, "total_delay_s") && isnumeric(d.total_delay_s) && isscalar(d.total_delay_s)
    pt.total_delay_s = d.total_delay_s;
elseif isfield(d, "samples") && isfield(d, "step_s")
    pt.total_delay_s = double(d.samples) * double(d.step_s);
end
pt.outcome = lower(iCharField(d, "outcome", "unknown"));
end


function n = iCountDistinctDelays(pts)
if isempty(pts)
    n = 0;
    return
end
vals = [pts.total_delay_s];
vals = vals(~isnan(vals));
n = numel(unique(round(vals, 12)));
end


function asym = iAsymmetricFaults(faults)
% At least one asymmetric-fault / voltage-unbalance record is required. Each
% record should declare negative-sequence handling and an unbalance factor; a
% record with an artifact file is stronger than a declaration alone.
asym = struct();
asym.n_records = numel(faults);
recs = iEmptyAsymArray();
for k = 1:numel(faults)
    recs(end+1) = iAsymRecord(faults(k)); %#ok<AGROW>
end
asym.records = recs;
asym.present = asym.n_records >= 1;
asym.any_negative_sequence = asym.present && any([recs.negative_sequence_handled]);
asym.any_artifact = asym.present && any([recs.has_artifact]);
if ~asym.present
    asym.status = "MISSING";
    asym.detail = "no asymmetric-fault or voltage-unbalance record (>=1 required)";
elseif asym.any_artifact
    asym.status = "PASS";
    asym.detail = "asymmetric-fault record(s) with same-study artifact present";
else
    asym.status = "WARN";
    asym.detail = "asymmetric-fault declared but no artifact file (intent, not evidence)";
end
end


function r = iAsymRecord(f)
r = struct("type", "", "negative_sequence_handled", false, ...
    "unbalance_factor_pct", NaN, "has_artifact", false, "detail", "");
r.type = lower(iCharField(f, "type", "unspecified"));
if isfield(f, "negative_sequence_handled") && islogical(f.negative_sequence_handled) ...
        && isscalar(f.negative_sequence_handled)
    r.negative_sequence_handled = f.negative_sequence_handled;
end
r.unbalance_factor_pct = iNumField(f, "unbalance_factor_pct", NaN);
artifactPath = iCharField(f, "artifact", "");
r.has_artifact = ~isempty(artifactPath) && isfile(artifactPath);
r.detail = char("type=" + string(r.type) + ", neg_seq=" + ...
    string(r.negative_sequence_handled) + ", artifact=" + string(r.has_artifact));
end


function [outcome, classification] = iClassifyOutcome(f3Path, m1Path, asym)
% Classify the reported outcome by which independent evidence chains agree:
%   F3 boundary attribution  -> grid-strength / control / delay driven
%   M1 pseudo-instability    -> numerical (solver/delay) driven
%   asymmetric-fault evidence-> physical disturbance response
% With neither F3 nor M1 evidence the result is insufficient, never a verdict.
f3 = iEvidencePresence(f3Path);
m1 = iEvidencePresence(m1Path);
outcome = struct();
outcome.f3_boundary_evidence = f3.present;
outcome.m1_pseudo_evidence = m1.present;
outcome.asymmetric_evidence = asym.present && ~strcmp(asym.status, "MISSING");

if ~f3.present && ~m1.present
    classification = "insufficient_evidence";
    outcome.detail = "no F3 boundary or M1 pseudo-instability evidence supplied";
elseif f3.present && m1.present
    classification = "mixed";
    outcome.detail = ["both grid/control-boundary (F3) and numerical (M1) " ...
        "evidence present; attribute jointly before a single-cause verdict"];
elseif m1.present
    classification = "numerical_pseudo_instability";
    outcome.detail = "only M1 solver/delay evidence present; treat as numerical until physical confirmed";
else
    classification = "physical_instability";
    outcome.detail = "F3 grid/control-boundary evidence present without numerical-cause evidence";
end
end


function status = iContractStatus(modePair, parity, delay, asym)
% Contract-level readiness: modes valid, parity gate satisfied, a delay sweep
% present, and the required asymmetric-fault record present. This is NOT a
% model-backed claim.
if ~modePair.ok || ~parity.matched || strcmp(asym.status, "MISSING")
    status = "blocked";
elseif ~delay.is_sweep || strcmp(asym.status, "WARN")
    status = "incomplete";
else
    status = "contract_complete";
end
end


function status = iModelValidationStatus(sGfl, sGfm, delay, f3Path)
% Model-backed only when BOTH device cases carry a same-study time-domain
% artifact (PASS, not WARN/MISSING) AND the delay sweep is model-backed.
tdGfl = iDimStatus(sGfl, "time_domain_validation");
tdGfm = iDimStatus(sGfm, "time_domain_validation");
bothTd = strcmp(tdGfl, "PASS") && strcmp(tdGfm, "PASS");
if bothTd && delay.model_backed && iEvidencePresence(f3Path).present
    status = "model_backed";
elseif bothTd
    status = "partial_model_backed";
else
    status = "not_model_backed";
end
end


function lvl = iEvidenceLevel(contractStatus, modelStatus)
if strcmp(modelStatus, "model_backed")
    lvl = "model_backed";
elseif strcmp(modelStatus, "partial_model_backed")
    lvl = "partial_model_backed";
elseif strcmp(contractStatus, "contract_complete")
    lvl = "contract_only";
else
    lvl = "incomplete";
end
lvl = char(lvl);
end


function pres = iEvidencePresence(pathValue)
pres = struct("present", false, "path", "", "note", "");
pathValue = string(pathValue);
if strlength(strtrim(pathValue)) == 0
    pres.note = "not supplied";
    return
end
pres.path = char(pathValue);
if isfile(pathValue)
    pres.present = true;
    pres.note = "file present";
else
    pres.note = "path supplied but file absent";
end
end


function claims = iExcludedClaims()
claims = { ...
    'No Simulink/Simscape model was executed by this helper.'; ...
    'contract_status and model_validation_status are separate; a complete contract is not a model-backed result.'; ...
    'No hardware-in-the-loop or real-time validation is implied.'; ...
    ['An outcome classification reflects which evidence chains were supplied, ' ...
     'not a proven physical or numerical root cause.']};
end


% ---- shared field / struct utilities ------------------------------------

function v = iCharField(s, name, defaultVal)
if isfield(s, name) && (ischar(s.(name)) || isstring(s.(name))) && ...
        strlength(string(s.(name))) > 0
    v = char(string(s.(name)));
else
    v = char(defaultVal);
end
end


function v = iNumField(s, name, defaultVal)
if isfield(s, name) && isnumeric(s.(name)) && isscalar(s.(name))
    v = s.(name);
else
    v = defaultVal;
end
end


function sub = iSubStruct(s, name)
if isfield(s, name) && isstruct(s.(name))
    sub = s.(name);
else
    sub = struct();
end
end


function tf = iHasAnyField(s)
tf = isstruct(s) && ~isempty(fieldnames(s));
end


function j = iJustified(c)
j = strings(1, 0);
if isfield(c, "justified_differences")
    v = c.justified_differences;
    if iscellstr(v) || isstring(v)
        j = string(v(:)');
    end
end
end


function st = iDimStatus(s, name)
st = "ABSENT";
for k = 1:numel(s.dimensions)
    if strcmp(s.dimensions(k).name, name)
        st = char(s.dimensions(k).status);
        return
    end
end
end


function arr = iEmptyParityArray()
arr = struct("axis", "", "value_gfl", "", "value_gfm", "", ...
    "matched", false, "justified", false, "detail", "");
arr = arr([]);
end


function arr = iEmptyDelayPtArray()
arr = struct("label", "", "total_delay_s", NaN, "outcome", "");
arr = arr([]);
end


function arr = iEmptyAsymArray()
arr = struct("type", "", "negative_sequence_handled", false, ...
    "unbalance_factor_pct", NaN, "has_artifact", false, "detail", "");
arr = arr([]);
end


% ---- output writers -----------------------------------------------------

function iWriteOutputs(outDir, summary)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "vsc_weakgrid_delay_benchmark.json"), summary);
iWriteMarkdown(fullfile(outDir, "vsc_weakgrid_delay_benchmark.md"), summary);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("VscBenchmark:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("VscBenchmark:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "# VSC Weak-Grid GFL/GFM Delay + Asymmetric-Fault Benchmark\n\n");
fprintf(fid, "GFL case: `%s` | GFM case: `%s`\n", summary.gfl_case, summary.gfm_case);
fprintf(fid, "Generated: %s\n\n", summary.generated_at);
fprintf(fid, "evidence_level: **%s**\n", summary.evidence_level);
fprintf(fid, "contract_status=%s | model_validation_status=%s\n", ...
    summary.contract_status, summary.model_validation_status);
fprintf(fid, "outcome_classification: **%s**\n\n", summary.outcome_classification);

fprintf(fid, "## Parity gate\n\n");
fprintf(fid, "matched=%d | unjustified_mismatches=%d\n\n", ...
    summary.parity.matched, summary.parity.n_unjustified_mismatch);
fprintf(fid, "| Axis | GFL | GFM | Matched | Justified |\n");
fprintf(fid, "|---|---|---|---|---|\n");
for k = 1:numel(summary.parity.checks)
    c = summary.parity.checks(k);
    fprintf(fid, "| %s | %s | %s | %d | %d |\n", ...
        c.axis, c.value_gfl, c.value_gfm, c.matched, c.justified);
end
fprintf(fid, "\n");

d = summary.delay_sensitivity;
fprintf(fid, "## Delay sensitivity\n\n");
fprintf(fid, "status=%s | points=%d distinct=%d is_sweep=%d model_backed=%d\n", ...
    d.status, d.n_points, d.distinct_delays, d.is_sweep, d.model_backed);
fprintf(fid, "- F2 evidence: %s | M1 evidence: %s\n\n", ...
    d.f2_evidence.note, d.m1_evidence.note);

a = summary.asymmetric_faults;
fprintf(fid, "## Asymmetric-fault contract\n\n");
fprintf(fid, "status=%s | records=%d neg_seq=%d artifact=%d\n", ...
    a.status, a.n_records, a.any_negative_sequence, a.any_artifact);
fprintf(fid, "- %s\n\n", a.detail);

fprintf(fid, "## Outcome classification\n\n");
fprintf(fid, "- **%s**: %s\n\n", summary.outcome_classification, ...
    iJoinText(summary.outcome_detail.detail));

fprintf(fid, "## Excluded claims\n\n");
for k = 1:numel(summary.excluded_claims)
    fprintf(fid, "- %s\n", summary.excluded_claims{k});
end
end


function s = iJoinText(t)
if iscell(t)
    s = strjoin(t, "");
elseif isstring(t) && ~isscalar(t)
    s = char(strjoin(t, ""));
else
    s = char(string(t));
end
end
