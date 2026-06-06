function summary = summarize_multirate_solver_plan(plan, varargin)
%SUMMARIZE_MULTIRATE_SOLVER_PLAN Check a hybrid/multirate solver plan.
%
%   summary = summarize_multirate_solver_plan(plan, "OutputDir",dir)
%
%   PLAN is a struct describing a cross-time-scale solver plan:
%     .case_name              char/string, optional
%     .stop_time_s            simulation stop time (s), > 0
%     .fastest_event_hz       fastest event to resolve (Hz), > 0  [anchor]
%     .slowest_mode_hz        slowest mode to capture (Hz), > 0    [anchor]
%     .strategy               "multi_solver" | "single_fixed_step" |
%                             "single_variable_step"
%     .verified_against_model logical CLAIM only. Model verification is driven
%                             by the "ModelProbe" evidence struct, NOT by this
%                             flag. A true claim with no probe is downgraded to
%                             a warning and model_validation_status stays
%                             "not_attempted".
%     .partitions             struct array, one per time-scale partition:
%         .name          char/string
%         .solver        e.g. "ode23tb","ode15s","ode45","discrete"
%         .step_kind     "fixed" | "variable"
%         .step_s        fixed sample time (s) for a fixed partition
%         .max_step_s    max step (s) for a variable partition
%         .algebraic_loop "none"|"solved"|"unit_delay"|"memory"|"solver_iterated"
%
%   Name-value options:
%     "OutputDir"   write md/json/csv evidence here
%     "ModelProbe"  struct of real load/update/simulate evidence (see
%                   .agents/skills/hybrid-solver-multirate-simulation/probe/).
%                   Required fields when supplied: .ran (logical),
%                   .sim_success (logical), .model (char). Optional: .solver,
%                   .stop_time_s, .max_abs_state, .notes.
%
%   This helper reports THREE orthogonal status axes; never collapse them:
%     summary.contract_status         pass|provisional|fail  (plan admissibility)
%     summary.model_validation_status not_attempted|pass|fail (real model run)
%     summary.handoff_ready           logical gate (contract pass + model pass +
%                                     no warnings)
%   A documented, admissible plan with no model run is contract_status="pass"
%   but model_validation_status="not_attempted" and handoff_ready=false, so a
%   plan can never masquerade as solver-readiness without a real run.
%
%   A missing anchor (fastest event or slowest mode) makes the plan provisional.
%
%   See .agents/skills/hybrid-solver-multirate-simulation/references/multirate-solver-contract.md

arguments
    plan struct
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
[p, planIssues, planProvisional, missingRequired] = iNormalizePlan(plan);
[parts, partIssues, partProvisional] = iCheckPartitions(p);

issues = [planIssues, partIssues];
provisional = planProvisional || partProvisional;

nFail = 0;
nWarn = 0;
for k = 1:numel(issues)
    switch issues(k).severity
        case "failure"
            nFail = nFail + 1;
        case "warning"
            nWarn = nWarn + 1;
    end
end

contractStatus = iContractStatus(nFail, provisional);

% Model-backed verification is a SEPARATE axis from contract admissibility.
% It is driven only by attached probe evidence, never by a bare boolean claim.
[modelStatus, modelProbe, claimIssue] = iModelValidation(opts.ModelProbe, p.verified_against_model);
if ~isempty(claimIssue.severity)
    issues = iAppendIssue(issues, claimIssue);
    if claimIssue.severity == "warning"
        nWarn = nWarn + 1;
    end
end

summary = struct();
summary.case_name = char(p.case_name);
summary.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));
summary.strategy = char(p.strategy);
summary.stop_time_s = p.stop_time_s;
summary.fastest_event_hz = p.fastest_event_hz;
summary.slowest_mode_hz = p.slowest_mode_hz;
summary.stiffness_ratio = iStiffnessRatio(p);
summary.n_partitions = numel(parts);
summary.partitions = parts;
summary.issues = issues;
summary.n_failures = nFail;
summary.n_warnings = nWarn;
summary.provisional = provisional;
summary.missing_required = missingRequired;
% Three orthogonal status axes. Do NOT collapse them into one headline:
%   contract_status        - is the plan self-consistent and admissible?
%   model_validation_status- did a real load/update/simulate back it?
%   handoff_ready          - the gate combining both (+ no warnings).
summary.contract_status = contractStatus;
summary.model_validation_status = modelStatus;
% verified_against_model is now DERIVED from evidence, not a free claim.
summary.verified_against_model = strcmp(modelStatus, "pass");
summary.model_probe = modelProbe;
summary.handoff_ready = iHandoffReady(contractStatus, modelStatus, nWarn);
% Back-compat alias; equals contract_status. Prefer the explicit fields above.
summary.status = contractStatus;
summary.limitations = char(opts.LimitationsNote);

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, summary);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("ModelProbe", struct([]), @(x) isstruct(x));
p.addParameter("LimitationsNote", ...
    "Plan-level admissibility check of supplied step/solver choices; not a model run and not a convergence proof. Confirm with a real load/update/simulate and solver diagnostics.", ...
    @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.OutputDir = string(opts.OutputDir);
opts.LimitationsNote = string(opts.LimitationsNote);
end


function [p, issues, provisional, missingRequired] = iNormalizePlan(plan)
issues = iEmptyIssueArray();
provisional = false;
missingRequired = {};

p = struct();
p.case_name = iGetField(plan, "case_name", "multirate_case");
p.strategy = lower(string(iGetField(plan, "strategy", "multi_solver")));
p.verified_against_model = logical(iGetField(plan, "verified_against_model", false));

p.stop_time_s = iGetNumeric(plan, "stop_time_s", NaN);
if ~(isfinite(p.stop_time_s) && p.stop_time_s > 0)
    issues = iAddIssue(issues, "failure", "plan", ...
        "stop_time_s must be a finite value > 0");
end

p.fastest_event_hz = iGetNumeric(plan, "fastest_event_hz", NaN);
if ~(isfinite(p.fastest_event_hz) && p.fastest_event_hz > 0)
    provisional = true;
    missingRequired{end+1} = 'fastest_event_hz';
    issues = iAddIssue(issues, "warning", "plan", ...
        "fastest_event_hz undocumented: micro-step resolution unchecked; plan is provisional");
end

p.slowest_mode_hz = iGetNumeric(plan, "slowest_mode_hz", NaN);
if ~(isfinite(p.slowest_mode_hz) && p.slowest_mode_hz > 0)
    provisional = true;
    missingRequired{end+1} = 'slowest_mode_hz';
    issues = iAddIssue(issues, "warning", "plan", ...
        "slowest_mode_hz undocumented: macro-step over-sampling unchecked; plan is provisional");
end

validStrategies = ["multi_solver","single_fixed_step","single_variable_step"];
if ~any(p.strategy == validStrategies)
    issues = iAddIssue(issues, "warning", "plan", ...
        sprintf("strategy '%s' not one of multi_solver/single_fixed_step/single_variable_step", p.strategy));
end

p.partitions = iNormalizePartitions(iGetField(plan, "partitions", struct([])));
if isempty(p.partitions)
    provisional = true;
    missingRequired{end+1} = 'partitions';
    issues = iAddIssue(issues, "warning", "plan", ...
        "no partitions supplied: nothing to step; plan is provisional");
end
end


function parts = iNormalizePartitions(raw)
parts = iEmptyPartitionInputArray();
if isempty(raw)
    return
end
for k = 1:numel(raw)
    q = raw(k);
    e = iEmptyPartitionInput();
    e.name = char(iGetField(q, "name", sprintf("partition_%d", k)));
    e.solver = char(iGetField(q, "solver", ""));
    e.step_kind = lower(char(iGetField(q, "step_kind", "")));
    e.step_s = iGetNumeric(q, "step_s", NaN);
    e.max_step_s = iGetNumeric(q, "max_step_s", NaN);
    e.algebraic_loop = lower(char(iGetField(q, "algebraic_loop", "none")));
    parts(k) = e;
end
end


function [parts, issues, provisional] = iCheckPartitions(p)
issues = iEmptyIssueArray();
provisional = false;
in = p.partitions;
parts = repmat(iEmptyPartition(), 1, numel(in));
fixedSteps = [];

for k = 1:numel(in)
    q = in(k);
    c = iEmptyPartition();
    c.name = q.name;
    c.solver = q.solver;
    c.step_kind = q.step_kind;
    c.step_s = q.step_s;
    c.max_step_s = q.max_step_s;
    c.algebraic_loop = q.algebraic_loop;

    if isempty(q.solver)
        provisional = true;
        issues = iAddIssue(issues, "warning", q.name, "solver undocumented; partition provisional");
    end

    isFixed = q.step_kind == "fixed";
    isVar = q.step_kind == "variable";
    if ~isFixed && ~isVar
        provisional = true;
        issues = iAddIssue(issues, "warning", q.name, ...
            "step_kind must be 'fixed' or 'variable'; partition provisional");
    end

    effStep = NaN;
    if isFixed
        effStep = q.step_s;
        if ~(isfinite(q.step_s) && q.step_s > 0)
            issues = iAddIssue(issues, "failure", q.name, "fixed partition needs step_s > 0");
        else
            if isfinite(p.stop_time_s) && q.step_s >= p.stop_time_s
                issues = iAddIssue(issues, "failure", q.name, ...
                    sprintf("step_s %.4g s >= stop_time %.4g s (impossible)", q.step_s, p.stop_time_s));
            end
            fixedSteps(end+1) = q.step_s; %#ok<AGROW>
        end
    elseif isVar
        effStep = q.max_step_s;
        if ~(isfinite(q.max_step_s) && q.max_step_s > 0)
            issues = iAddIssue(issues, "warning", q.name, ...
                "variable partition has no positive max_step_s; step bound unchecked");
        elseif isfinite(p.stop_time_s) && q.max_step_s >= p.stop_time_s
            issues = iAddIssue(issues, "failure", q.name, ...
                sprintf("max_step_s %.4g s >= stop_time %.4g s (impossible)", q.max_step_s, p.stop_time_s));
        end
    end

    [c.samples_per_fastest] = iSamplesPerPeriod(p.fastest_event_hz, effStep);
    [c.samples_per_slowest] = iSamplesPerPeriod(p.slowest_mode_hz, effStep);

    issues = iCheckAlgebraicLoop(issues, q);
    issues = iCheckStiffSolver(issues, p, q, isVar);

    c.effective_step_s = effStep;
    parts(k) = c;
end

issues = iCheckRateRatios(issues, fixedSteps);
issues = iCheckGlobalAnchors(issues, p, parts);
end


function spp = iSamplesPerPeriod(freqHz, effStep)
% Diagnostic samples-per-period for this partition's own step. Reporting only;
% the pass/fail anchors are enforced globally in iCheckGlobalAnchors.
if ~(isfinite(freqHz) && freqHz > 0) || ~(isfinite(effStep) && effStep > 0)
    spp = NaN;
    return
end
spp = 1 / (freqHz * effStep);
end


function issues = iCheckGlobalAnchors(issues, p, parts)
% Multirate intent: only the FINEST partition must resolve the fastest event,
% and the SLOWEST/coarsest step must still over-sample the slowest mode. Slow
% partitions taking coarse steps is the point of multirate, not an error.
steps = [parts.effective_step_s];
steps = steps(isfinite(steps) & steps > 0);
if isempty(steps)
    return
end
finest = min(steps);
coarsest = max(steps);

if isfinite(p.fastest_event_hz) && p.fastest_event_hz > 0
    spf = 1 / (p.fastest_event_hz * finest);
    if spf < 10
        issues = iAddIssue(issues, "failure", "global", sprintf( ...
            "finest step %.4g s gives %.2f samples per fastest period (%.4g Hz); need >= 10 to resolve the fastest event", ...
            finest, spf, p.fastest_event_hz));
    end
end

if isfinite(p.slowest_mode_hz) && p.slowest_mode_hz > 0
    sps = 1 / (p.slowest_mode_hz * coarsest);
    if sps < 20
        issues = iAddIssue(issues, "warning", "global", sprintf( ...
            "coarsest step %.4g s gives %.2f samples per slowest period (%.4g Hz); < 20 under-samples the slow mode", ...
            coarsest, sps, p.slowest_mode_hz));
    end
end
end


function issues = iCheckAlgebraicLoop(issues, q)
loop = string(q.algebraic_loop);
valid = ["none","solved","unit_delay","memory","solver_iterated"];
if ~any(loop == valid)
    issues = iAddIssue(issues, "warning", q.name, ...
        sprintf("algebraic_loop '%s' unrecognized; expected none/solved/unit_delay/memory/solver_iterated", q.algebraic_loop));
    return
end
if loop == "solver_iterated" && q.step_kind == "fixed"
    issues = iAddIssue(issues, "failure", q.name, ...
        "solver_iterated algebraic loop on a fixed/discrete partition is not well defined across sample times; break it with a unit delay or Memory block");
end
end


function issues = iCheckStiffSolver(issues, p, q, isVar)
ratio = iStiffnessRatio(p);
if ~isfinite(ratio) || ratio <= 1e4
    return
end
stiffSolvers = ["ode15s","ode23tb","ode23t","ode23s"];
isContinuous = isVar || ~any(string(q.solver) == ["discrete","fixedstepdiscrete"]);
if isContinuous && ~any(lower(string(q.solver)) == stiffSolvers)
    issues = iAddIssue(issues, "warning", q.name, sprintf( ...
        "stiffness ratio ~%.3g exceeds 1e4 but solver '%s' is non-stiff; consider a stiff solver (ode15s/ode23tb) or split the partition", ...
        ratio, q.solver));
end
end


function issues = iCheckRateRatios(issues, fixedSteps)
fixedSteps = sort(unique(fixedSteps(fixedSteps > 0)));
if numel(fixedSteps) < 2
    return
end
for k = 1:numel(fixedSteps)-1
    ratio = fixedSteps(k+1) / fixedSteps(k);
    nearest = round(ratio);
    if nearest < 1 || abs(ratio - nearest) > 1e-6 * max(1, ratio)
        issues = iAddIssue(issues, "warning", "rate_transition", sprintf( ...
            "step ratio %.4g (%.4g s / %.4g s) is non-integer; rate transition needs interpolation", ...
            ratio, fixedSteps(k+1), fixedSteps(k)));
    end
end
end


function ratio = iStiffnessRatio(p)
if isfinite(p.fastest_event_hz) && isfinite(p.slowest_mode_hz) && p.slowest_mode_hz > 0
    ratio = p.fastest_event_hz / p.slowest_mode_hz;
else
    ratio = NaN;
end
end


function s = iContractStatus(nFail, provisional)
% Plan-admissibility axis only. Says nothing about a real model run.
if nFail > 0
    s = "fail";
elseif provisional
    s = "provisional";
else
    s = "pass";
end
s = char(s);
end


function [status, probeOut, issue] = iModelValidation(probe, claimed)
% Model verification is driven ONLY by attached probe evidence. A bare
% verified_against_model=true claim with no probe is NOT accepted; it is
% downgraded to "not_attempted" and surfaced as a warning so a self-asserted
% flag can never read as solver readiness.
issue = iEmptyIssue();
probeOut = iEmptyProbe();
status = "not_attempted";

hasProbe = isstruct(probe) && ~isempty(probe) && isfield(probe, "ran");
if ~hasProbe
    if claimed
        issue = iMakeIssue("warning", "model", ...
            "verified_against_model=true was claimed but no ModelProbe evidence was attached; model_validation_status stays not_attempted");
    end
    status = char(status);
    return
end

probeOut.ran = logical(iGetField(probe, "ran", false));
probeOut.sim_success = logical(iGetField(probe, "sim_success", false));
probeOut.model = char(iGetField(probe, "model", ""));
probeOut.solver = char(iGetField(probe, "solver", ""));
probeOut.stop_time_s = iGetNumeric(probe, "stop_time_s", NaN);
probeOut.max_abs_state = iGetNumeric(probe, "max_abs_state", NaN);
probeOut.notes = char(iGetField(probe, "notes", ""));

if ~probeOut.ran
    issue = iMakeIssue("warning", "model", ...
        "ModelProbe supplied but .ran=false; model_validation_status stays not_attempted");
    status = char(status);
    return
end

if probeOut.sim_success && isfinite(probeOut.max_abs_state)
    status = "pass";
else
    status = "fail";
    issue = iMakeIssue("failure", "model", ...
        "ModelProbe ran but simulation did not succeed (sim_success=false or non-finite state); model_validation_status=fail");
end
status = char(status);
end


function tf = iHandoffReady(contractStatus, modelStatus, nWarn)
% The gate: only a contract-admissible, model-verified, warning-free plan is
% handoff-ready. Warnings (under-sampled slow mode, non-integer ratio, stiff
% solver, unbacked claim) all block handoff readiness even if model passed.
tf = strcmp(contractStatus, "pass") && strcmp(modelStatus, "pass") && nWarn == 0;
end


function v = iGetField(s, name, default)
name = char(name);
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = default;
end
end


function v = iGetNumeric(s, name, default)
raw = iGetField(s, name, default);
if isnumeric(raw) && isscalar(raw)
    v = double(raw);
else
    v = default;
end
end


function issues = iAddIssue(issues, severity, partition, message)
issues = iAppendIssue(issues, iMakeIssue(severity, partition, message));
end


function issues = iAppendIssue(issues, issue)
if isempty(issues)
    issues = issue;
else
    issues(end+1) = issue;
end
end


function issue = iMakeIssue(severity, partition, message)
issue = struct("severity", char(severity), "partition", char(partition), ...
    "message", char(message));
end


function issue = iEmptyIssue()
issue = struct("severity", "", "partition", "", "message", "");
end


function arr = iEmptyIssueArray()
arr = iEmptyIssue();
arr = arr([]);
end


function e = iEmptyPartitionInput()
e = struct("name", "", "solver", "", "step_kind", "", "step_s", NaN, ...
    "max_step_s", NaN, "algebraic_loop", "none");
end


function arr = iEmptyPartitionInputArray()
arr = iEmptyPartitionInput();
arr = arr([]);
end


function c = iEmptyPartition()
c = struct("name", "", "solver", "", "step_kind", "", "step_s", NaN, ...
    "max_step_s", NaN, "effective_step_s", NaN, "algebraic_loop", "none", ...
    "samples_per_fastest", NaN, "samples_per_slowest", NaN);
end


function pr = iEmptyProbe()
pr = struct("ran", false, "sim_success", false, "model", "", "solver", "", ...
    "stop_time_s", NaN, "max_abs_state", NaN, "notes", "");
end


function iWriteOutputs(outDir, summary)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "multirate_solver_plan.json"), summary);
iWriteMarkdown(fullfile(outDir, "multirate_solver_plan.md"), summary);
iWriteCsv(fullfile(outDir, "partition_step_table.csv"), summary);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("MultirateSolver:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("MultirateSolver:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Hybrid Solver / Multirate Plan\n\n");
fprintf(fid, "Case: `%s`\n", summary.case_name);
fprintf(fid, "Contract status: **%s** | failures: %d | warnings: %d\n", ...
    upper(summary.contract_status), summary.n_failures, summary.n_warnings);
fprintf(fid, "Model validation: **%s** | handoff ready: **%s**\n", ...
    upper(summary.model_validation_status), iYesNo(summary.handoff_ready));
if ~summary.handoff_ready
    fprintf(fid, "\n> NOT HANDOFF-READY: a documented, admissible plan is not solver-validated until a real model run passes with no warnings. ");
    fprintf(fid, "contract_status and model_validation_status are independent; do not read contract pass as solver readiness.\n");
end
if summary.provisional
    fprintf(fid, "\n> PROVISIONAL: required anchors/fields undocumented");
    if ~isempty(summary.missing_required)
        fprintf(fid, " (missing: %s)", strjoin(summary.missing_required, ", "));
    end
    fprintf(fid, ". Not a validated cross-time-scale result.\n");
end
fprintf(fid, "\nStrategy: %s | verified_against_model: %d\n", ...
    summary.strategy, summary.verified_against_model);
mp = summary.model_probe;
if ~isempty(mp.model) || mp.ran
    fprintf(fid, "Model probe: model=`%s` solver=%s ran=%d sim_success=%d max|state|=%.4g\n", ...
        mp.model, mp.solver, mp.ran, mp.sim_success, mp.max_abs_state);
end
fprintf(fid, "Stop time: %.4g s | fastest event: %.4g Hz | slowest mode: %.4g Hz", ...
    summary.stop_time_s, summary.fastest_event_hz, summary.slowest_mode_hz);
if isfinite(summary.stiffness_ratio)
    fprintf(fid, " | stiffness ratio: %.3g", summary.stiffness_ratio);
end
fprintf(fid, "\nGenerated: %s\n\n", summary.generated_at);

fprintf(fid, "## Partitions\n\n");
fprintf(fid, "| Partition | Solver | Kind | Step s | Eff step s | Samp/fast | Samp/slow | Alg loop |\n");
fprintf(fid, "|---|---|---|---:|---:|---:|---:|---|\n");
for k = 1:numel(summary.partitions)
    q = summary.partitions(k);
    fprintf(fid, "| %s | %s | %s | %s | %s | %s | %s | %s |\n", ...
        q.name, q.solver, q.step_kind, iNum(q.step_s), iNum(q.effective_step_s), ...
        iNum(q.samples_per_fastest), iNum(q.samples_per_slowest), q.algebraic_loop);
end
fprintf(fid, "\n");

fprintf(fid, "## Issues\n\n");
if isempty(summary.issues)
    fprintf(fid, "_No failures or warnings._\n\n");
else
    fprintf(fid, "| Severity | Partition | Message |\n|---|---|---|\n");
    for k = 1:numel(summary.issues)
        it = summary.issues(k);
        fprintf(fid, "| %s | %s | %s |\n", upper(it.severity), it.partition, it.message);
    end
    fprintf(fid, "\n");
end

fprintf(fid, "## Limitations\n\n%s\n", summary.limitations);
end


function iWriteCsv(path, summary)
n = numel(summary.partitions);
Name = strings(n,1); Solver = strings(n,1); StepKind = strings(n,1);
StepS = zeros(n,1); EffStepS = zeros(n,1);
SamplesPerFastest = zeros(n,1); SamplesPerSlowest = zeros(n,1);
AlgebraicLoop = strings(n,1);
for k = 1:n
    q = summary.partitions(k);
    Name(k) = string(q.name); Solver(k) = string(q.solver);
    StepKind(k) = string(q.step_kind); StepS(k) = q.step_s;
    EffStepS(k) = q.effective_step_s;
    SamplesPerFastest(k) = q.samples_per_fastest;
    SamplesPerSlowest(k) = q.samples_per_slowest;
    AlgebraicLoop(k) = string(q.algebraic_loop);
end
T = table(Name, Solver, StepKind, StepS, EffStepS, ...
    SamplesPerFastest, SamplesPerSlowest, AlgebraicLoop);
writetable(T, path);
end


function s = iNum(x)
if isnan(x)
    s = "NaN";
else
    s = sprintf("%.4g", x);
end
end


function s = iYesNo(tf)
if tf
    s = "YES";
else
    s = "NO";
end
end
