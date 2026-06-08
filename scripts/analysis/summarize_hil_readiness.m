function summary = summarize_hil_readiness(manifest, varargin)
%SUMMARIZE_HIL_READINESS Summarize software-side HIL / real-time readiness.
%
%   summary = summarize_hil_readiness(manifest, "OutputDir", dir)
%
%   Consumes a real-time readiness MANIFEST (a struct of metadata the caller
%   already has) and produces a software-readiness assessment for future
%   RTDS / OPAL-RT / Speedgoat-style deployment. It performs SEVEN checks:
%     1. fixed_step_feasibility  fixed-step solver + step resolves fastest event
%     2. algebraic_loop_risk     algebraic loops absent or explicitly broken
%     3. unsupported_blocks      no codegen-unsupported blocks remain
%     4. codegen_constraints     fixed-step, no undiscretized continuous states
%     5. partitioning            subsystem partitions with rate + compute
%     6. io_mapping              I/O channels declared (placeholders allowed)
%     7. latency_budget          per-core compute fits the step budget
%
%   IMPORTANT - this helper is software-only. It reads metadata; it never
%   creates, opens, or simulates a Simulink model, and it never writes RTDS /
%   OPAL-RT target configuration. It does NOT claim hardware-in-the-loop
%   validation. Results are labeled `software_readiness_only` unless the
%   manifest supplies real HIL hardware evidence (hardware_evidence.supplied
%   = true with an artifact). See
%   .agents/skills/hil-readiness-real-time-prep/references/hil-readiness-contract.md
%
%   The headline deliberately separates three ideas so a complete contract is
%   never mistaken for a deployable model:
%     contract_status      PASS | WARN | MISSING  (manifest completeness/consistency)
%     readiness_class      software_readiness_only | hardware_backed
%     handoff_ready        true only if contract PASS and no blocking finding
%     real_time_deployable true only if handoff_ready AND hardware_backed
%
%   Inputs
%     manifest  struct describing the model's real-time readiness metadata.
%               See the contract reference for the full field list.
%
%   Name-value
%     OutputDir  folder for hil_readiness_summary.{md,json} (default: none)
%     CaseName   overrides manifest.case_name when provided

arguments
    manifest (1,1) struct
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
m = iNormalizeManifest(manifest, opts);

checks = struct([]);
checks = iAddCheck(checks, iCheckFixedStep(m));
checks = iAddCheck(checks, iCheckAlgebraicLoops(m));
checks = iAddCheck(checks, iCheckUnsupportedBlocks(m));
checks = iAddCheck(checks, iCheckCodegen(m));
checks = iAddCheck(checks, iCheckPartitioning(m));
checks = iAddCheck(checks, iCheckIoMapping(m));
checks = iAddCheck(checks, iCheckLatencyBudget(m));

% --- contract status: metadata completeness + internal consistency ---
states = string({checks.status});
nMissing = nnz(states == "MISSING");
nWarn = nnz(states == "WARN");
if nMissing > 0
    contractStatus = "MISSING";
elseif nWarn > 0
    contractStatus = "WARN";
else
    contractStatus = "PASS";
end

% --- blocking findings: the WARN/MISSING states that veto handoff ---
blocking = {};
for k = 1:numel(checks)
    if checks(k).blocking && checks(k).status ~= "PASS" && checks(k).status ~= "N/A"
        blocking{end+1} = sprintf('%s:%s', checks(k).name, checks(k).status); %#ok<AGROW>
    end
end

% --- readiness class: hardware only when real evidence is supplied ---
hw = m.hardware_evidence;
hardwareBacked = hw.supplied && strlength(string(hw.artifact_path)) > 0 && ~hw.overruns;
if hardwareBacked
    readinessClass = "hardware_backed";
else
    readinessClass = "software_readiness_only";
end

% --- model validation status: independent of contract and hardware ---
% model_backed means solver/step/rate/state facts were read from a real
% compiled model (provenance present AND the model compiled). It is NOT a
% codegen or hardware claim - those remain separate. Default not_model_backed
% so a hand-supplied (contract-only) manifest is never mislabeled.
mp = m.model_provenance;
modelBacked = isstruct(mp) && isfield(mp, "is_model_backed") && mp.is_model_backed && ...
    isfield(mp, "compiled_ok") && mp.compiled_ok;
if modelBacked
    modelValidationStatus = "model_backed";
else
    modelValidationStatus = "not_model_backed";
end

% handoff_ready: safe to carry to hardware bring-up. The `blocking` set already
% captures every veto: blocking WARNs (wrong solver, unbroken algebraic loop,
% unsupported blocks, failed codegen target, an actual latency overrun) AND
% blocking MISSING metadata (undocumented solver/loops/codegen). Non-blocking
% findings are allowed to carry forward: I/O placeholders, single-rate
% (no-partition) assumption, or not-yet-computed latency. This is the D2 policy
% lesson - WARN alone does not grant handoff; only non-blocking WARN does.
handoffReady = isempty(blocking);
realTimeDeployable = handoffReady && readinessClass == "hardware_backed";

summary = struct();
summary.case_name = char(m.case_name);
summary.source_model_or_script = char(m.source_model_or_script);
summary.target_platform = char(m.target_platform);
summary.generated_at = char(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss"));
summary.checks = checks;
summary.contract_status = char(contractStatus);
summary.readiness_class = char(readinessClass);
summary.model_validation_status = char(modelValidationStatus);
summary.model_provenance = mp;
summary.handoff_ready = handoffReady;
summary.real_time_deployable = realTimeDeployable;
summary.blocking_findings = blocking;
summary.n_missing = nMissing;
summary.n_warn = nWarn;
summary.hardware_evidence_supplied = hw.supplied;
summary.limitations = char(m.limitations);

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, summary);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("CaseName", "", @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.OutputDir = string(opts.OutputDir);
opts.CaseName = string(opts.CaseName);
end


function c = iAddCheck(checks, c1)
if isempty(checks)
    checks = c1;
else
    checks(end+1) = c1;
end
c = checks;
end


function c = iMakeCheck(name, status, blocking, detail)
% status: "PASS" | "WARN" | "MISSING" | "N/A"
c = struct("name", char(name), "status", char(status), ...
    "blocking", logical(blocking), "detail", char(detail));
end

function m = iNormalizeManifest(manifest, opts)
% Fill defaults so a sparse manifest yields MISSING checks instead of errors.
m = manifest;
m = iDefault(m, "case_name", "hil_readiness_case");
if strlength(opts.CaseName) > 0
    m.case_name = char(opts.CaseName);
end
m = iDefault(m, "source_model_or_script", "");
m = iDefault(m, "target_platform", "");
m = iDefault(m, "limitations", ...
    "Software-side readiness from supplied metadata; not hardware-validated.");

% solver / fixed step
m = iDefault(m, "solver_type", "");          % "fixed_step" | "variable_step"
m = iDefault(m, "fixed_step_s", NaN);
m = iDefault(m, "fastest_event_s", NaN);     % e.g. PWM carrier period or switch event

% algebraic loops
m = iDefault(m, "algebraic_loops_present", []);   % [] = undocumented
m = iDefault(m, "algebraic_loops_broken", false);

% unsupported blocks
m = iDefault(m, "unsupported_blocks_checked", false);
m = iDefault(m, "unsupported_blocks", {});        % cellstr of remaining offenders

% codegen
m = iDefault(m, "continuous_states_present", []);  % [] = undocumented
m = iDefault(m, "codegen_target_supported", []);   % [] = undocumented

% partitioning
m = iDefault(m, "partitions", iEmptyPartitions());

% I/O mapping
m = iDefault(m, "io_channels", iEmptyIo());

% latency budget
m = iDefault(m, "cpu_cores", NaN);
m = iDefault(m, "step_budget_s", NaN);    % time available per step (often = fixed_step_s)

% hardware evidence
hw = struct("supplied", false, "artifact_path", "", "overruns", false, "note", "");
if isfield(m, "hardware_evidence") && isstruct(m.hardware_evidence)
    src = m.hardware_evidence;
    fn = fieldnames(src);
    for k = 1:numel(fn)
        hw.(fn{k}) = src.(fn{k});
    end
end
m.hardware_evidence = hw;

% model provenance: present only on model-backed runs (the adapter sets it).
% Default to a not-model-backed marker so contract-only manifests are honest.
if ~isfield(m, "model_provenance") || ~isstruct(m.model_provenance)
    m.model_provenance = struct("is_model_backed", false);
end
end


function s = iDefault(s, field, value)
% Set a default when the field is missing, or present but "empty-ish" in a way
% that means unset. Logicals are never empty; an empty cell {} is a valid value
% (e.g. "no unsupported blocks") so it is left as-is.
if ~isfield(s, field)
    s.(field) = value;
    return
end
cur = s.(field);
if isempty(cur) && ~islogical(cur) && ~iscell(cur)
    s.(field) = value;
end
end


function p = iEmptyPartitions()
p = struct("name", {}, "rate_s", {}, "compute_s", {});
end


function io = iEmptyIo()
io = struct("name", {}, "direction", {}, "placeholder", {});
end


% ---------------------------------------------------------------- check 1
function c = iCheckFixedStep(m)
name = "fixed_step_feasibility";
% Precedence matters: a variable-step model legitimately has NO fixed step, so
% "wrong solver type" must be judged before "fixed_step_s is NaN". Only a model
% that claims fixed-step yet omits the step value is MISSING.
if strlength(string(m.solver_type)) == 0
    c = iMakeCheck(name, "MISSING", true, ...
        "solver_type undocumented; required for real-time feasibility");
    return
end
if string(m.solver_type) ~= "fixed_step"
    c = iMakeCheck(name, "WARN", true, sprintf( ...
        "solver_type=%s; real-time targets need a fixed-step solver", ...
        string(m.solver_type)));
    return
end
if isnan(m.fixed_step_s)
    c = iMakeCheck(name, "MISSING", true, ...
        "fixed-step solver but fixed_step_s undocumented");
    return
end
if m.fixed_step_s <= 0
    c = iMakeCheck(name, "WARN", true, "fixed_step_s must be > 0");
    return
end
if isnan(m.fastest_event_s)
    c = iMakeCheck(name, "WARN", true, ...
        "fastest_event_s undocumented; cannot confirm the step resolves it");
    return
end
% Need at least ~2 steps per fastest event (Nyquist-style minimum).
ratio = m.fastest_event_s / m.fixed_step_s;
if ratio < 2
    c = iMakeCheck(name, "WARN", true, sprintf( ...
        "fixed_step_s=%.3g s only %.2gx the fastest event %.3g s (<2x: under-resolved)", ...
        m.fixed_step_s, ratio, m.fastest_event_s));
    return
end
c = iMakeCheck(name, "PASS", true, sprintf( ...
    "fixed_step_s=%.3g s resolves fastest event %.3g s (%.2gx)", ...
    m.fixed_step_s, m.fastest_event_s, ratio));
end


% ---------------------------------------------------------------- check 2
function c = iCheckAlgebraicLoops(m)
name = "algebraic_loop_risk";
if isempty(m.algebraic_loops_present)
    c = iMakeCheck(name, "MISSING", true, ...
        "algebraic_loops_present undocumented; real-time codegen cannot solve loops at runtime");
    return
end
if ~m.algebraic_loops_present
    c = iMakeCheck(name, "PASS", true, "no algebraic loops reported");
    return
end
if m.algebraic_loops_broken
    c = iMakeCheck(name, "WARN", false, ...
        "algebraic loops present but explicitly broken (delay/Solver); confirm numerics on target");
    return
end
c = iMakeCheck(name, "WARN", true, ...
    "unbroken algebraic loops present; not real-time deployable until broken");
end


% ---------------------------------------------------------------- check 3
function c = iCheckUnsupportedBlocks(m)
name = "unsupported_blocks";
if ~m.unsupported_blocks_checked
    c = iMakeCheck(name, "MISSING", true, ...
        "unsupported_blocks_checked=false; run a codegen support scan first");
    return
end
offenders = cellstr(m.unsupported_blocks);
offenders = offenders(~cellfun(@isempty, offenders));
if isempty(offenders)
    c = iMakeCheck(name, "PASS", true, "no codegen-unsupported blocks remain");
    return
end
c = iMakeCheck(name, "WARN", true, sprintf( ...
    "%d unsupported block(s) remain: %s", numel(offenders), strjoin(offenders, ", ")));
end

% ---------------------------------------------------------------- check 4
function c = iCheckCodegen(m)
name = "codegen_constraints";
if isempty(m.codegen_target_supported)
    c = iMakeCheck(name, "MISSING", true, ...
        "codegen_target_supported undocumented; confirm the model builds for the RT target");
    return
end
if ~m.codegen_target_supported
    c = iMakeCheck(name, "WARN", true, ...
        "codegen_target_supported=false; model cannot generate code for the target yet");
    return
end
% Continuous states under a fixed-step solver must be discretized for codegen.
if ~isempty(m.continuous_states_present) && m.continuous_states_present ...
        && string(m.solver_type) == "fixed_step"
    c = iMakeCheck(name, "WARN", false, ...
        "continuous states present under fixed-step; confirm discretization/local solver");
    return
end
c = iMakeCheck(name, "PASS", true, "codegen target supported; no undiscretized-state flag");
end


% ---------------------------------------------------------------- check 5
function c = iCheckPartitioning(m)
name = "partitioning";
parts = m.partitions;
if isempty(parts) || numel(parts) == 0
    c = iMakeCheck(name, "MISSING", false, ...
        "no subsystem partitions declared; single-rate assumption only");
    return
end
incomplete = 0;
for k = 1:numel(parts)
    if ~isfield(parts(k), "rate_s") || isempty(parts(k).rate_s) || isnan(parts(k).rate_s)
        incomplete = incomplete + 1;
    end
end
if incomplete > 0
    c = iMakeCheck(name, "WARN", false, sprintf( ...
        "%d of %d partition(s) missing rate_s", incomplete, numel(parts)));
    return
end
c = iMakeCheck(name, "PASS", false, sprintf( ...
    "%d partition(s) declared with rates", numel(parts)));
end


% ---------------------------------------------------------------- check 6
function c = iCheckIoMapping(m)
name = "io_mapping";
io = m.io_channels;
if isempty(io) || numel(io) == 0
    c = iMakeCheck(name, "MISSING", false, ...
        "no I/O channels declared; add placeholders for analog/digital boundary signals");
    return
end
nPlaceholder = 0;
for k = 1:numel(io)
    if isfield(io(k), "placeholder") && ~isempty(io(k).placeholder) && io(k).placeholder
        nPlaceholder = nPlaceholder + 1;
    end
end
if nPlaceholder > 0
    c = iMakeCheck(name, "WARN", false, sprintf( ...
        "%d of %d I/O channel(s) are placeholders; bind to real target channels before HIL", ...
        nPlaceholder, numel(io)));
    return
end
c = iMakeCheck(name, "PASS", false, sprintf( ...
    "%d I/O channel(s) declared, none placeholder", numel(io)));
end


% ---------------------------------------------------------------- check 7
function c = iCheckLatencyBudget(m)
name = "latency_budget";
if isnan(m.step_budget_s)
    budget = m.fixed_step_s;   % fall back to the fixed step if no explicit budget
else
    budget = m.step_budget_s;
end
parts = m.partitions;
haveCompute = ~isempty(parts) && numel(parts) > 0 && ...
    all(arrayfun(@(p) isfield(p, "compute_s") && ~isempty(p.compute_s) && ~isnan(p.compute_s), parts));
if isnan(budget) || ~haveCompute
    c = iMakeCheck(name, "MISSING", false, ...
        "need step_budget_s (or fixed_step_s) and per-partition compute_s for a latency check");
    return
end
cores = m.cpu_cores;
totalCompute = sum(arrayfun(@(p) p.compute_s, parts));
if isnan(cores) || cores < 1
    % Single-core worst case: everything serializes into one step.
    worst = totalCompute;
    coreNote = "single-core (cpu_cores undocumented)";
else
    % Optimistic: even split across cores. Real mapping may be worse.
    worst = totalCompute / cores;
    coreNote = sprintf("%g core(s), even-split estimate", cores);
end
margin = (budget - worst) / budget;
if worst > budget
    c = iMakeCheck(name, "WARN", true, sprintf( ...
        "compute %.3g s exceeds step budget %.3g s [%s]; overrun risk", ...
        worst, budget, coreNote));
    return
end
c = iMakeCheck(name, "PASS", true, sprintf( ...
    "compute %.3g s within budget %.3g s (%.0f%% margin) [%s]", ...
    worst, budget, 100*margin, coreNote));
end

function iWriteOutputs(outDir, summary)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "hil_readiness_summary.json"), summary);
iWriteMarkdown(fullfile(outDir, "hil_readiness_summary.md"), summary);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("HilReadiness:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("HilReadiness:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# HIL / Real-Time Readiness Summary\n\n");
fprintf(fid, "Case: `%s`\n", summary.case_name);
fprintf(fid, "Source: %s\n", iOrNone(summary.source_model_or_script));
fprintf(fid, "Target platform: %s\n", iOrNone(summary.target_platform));
fprintf(fid, "Generated: %s\n\n", summary.generated_at);

% Headline banner: never let a complete contract read as a deployable model.
fprintf(fid, "## Readiness headline\n\n");
fprintf(fid, "- contract_status: **%s**\n", summary.contract_status);
fprintf(fid, "- readiness_class: **%s**\n", summary.readiness_class);
fprintf(fid, "- model_validation_status: **%s**\n", summary.model_validation_status);
fprintf(fid, "- handoff_ready: **%d**\n", summary.handoff_ready);
fprintf(fid, "- real_time_deployable: **%d**\n", summary.real_time_deployable);
if strcmp(summary.readiness_class, "software_readiness_only")
    fprintf(fid, "\n> SOFTWARE READINESS ONLY. No hardware-in-the-loop evidence was\n");
    fprintf(fid, "> supplied, so this is not proof of real-time deployability.\n");
end
if ~isempty(summary.blocking_findings)
    fprintf(fid, "\n> BLOCKING findings veto handoff: %s\n", ...
        strjoin(summary.blocking_findings, ", "));
end
fprintf(fid, "\n");

fprintf(fid, "## Checks\n\n");
fprintf(fid, "| Check | Status | Blocking | Detail |\n");
fprintf(fid, "|---|---|---:|---|\n");
for k = 1:numel(summary.checks)
    c = summary.checks(k);
    fprintf(fid, "| %s | %s | %d | %s |\n", c.name, c.status, c.blocking, c.detail);
end
fprintf(fid, "\n");

fprintf(fid, "## Limitations\n\n%s\n", summary.limitations);
end


function s = iOrNone(value)
if isempty(value) || (ischar(value) && strlength(string(value)) == 0)
    s = "(none)";
else
    s = value;
end
end
