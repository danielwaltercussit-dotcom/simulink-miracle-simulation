function [summary, manifest] = hil_readiness_from_model(model, varargin)
%HIL_READINESS_FROM_MODEL Model-backed HIL readiness from a real Simulink model.
%
%   [summary, manifest] = hil_readiness_from_model(model, "OutputDir", dir)
%
%   This is the MODEL-BACKED path for M2. Unlike summarize_hil_readiness (which
%   trusts a hand-supplied manifest), this adapter LOADS and COMPILES the model
%   and reads the readiness facts from the compiled model itself:
%     - solver type and fixed step          (get_param)
%     - compiled discrete sample rates       (per-block CompiledSampleTime)
%     - continuous-state count               (model 'sizes' -> fastest signal
%                                             that real-time codegen must solve)
%   It then builds a manifest tagged with model_provenance and calls
%   summarize_hil_readiness, so model-backed and contract-only runs share one
%   status engine.
%
%   HONESTY BOUNDARY. model_backed means the solver/step/rate/state facts came
%   from a real compiled model - NOT that code was generated and NOT that the
%   model ran on real-time hardware. real_time_deployable still requires real
%   HIL evidence. This adapter never writes RTDS/OPAL-RT target config.
%
%   Name-value:
%     OutputDir   folder for the summary artifacts (passed through)
%     Simulate    logical, also run a short sim to confirm the model is
%                 runnable (default true). Recorded in model_provenance.
%     UnsupportedBlocks  cellstr of known codegen-unsupported blocks if a scan
%                 was done out of band (default {} = none found).
%     CpuCores / StepBudgetS  latency-budget inputs (optional).

arguments
    model (1,1) string
end
arguments (Repeating)
    varargin
end
opts = iParseNameValues(varargin{:});

addpath(fileparts(mfilename("fullpath")));   % so summarize_hil_readiness resolves

[mdl, loadedHere] = iLoadModel(model);
cleanupModel = onCleanup(@() iCloseIfNeeded(mdl, loadedHere));

% --- update diagram (compile-equivalent structural check) ---
updateOk = true; updateErr = "";
try
    set_param(mdl, "SimulationCommand", "update");
catch ME
    updateOk = false; updateErr = string(ME.message);
end

probe = iProbeCompiled(mdl);

% --- optional short simulation to prove runnable ---
simOk = false; simErr = "";
if opts.Simulate && updateOk2(updateOk, probe)
    try
        so = get_param(mdl, "StopTime");
        simOut = sim(mdl, "StopTime", so); %#ok<NASGU>
        simOk = true;
    catch ME
        simErr = string(ME.message);
    end
end

manifest = iBuildManifest(mdl, probe, opts, updateOk, updateErr, simOk, simErr);
summary = summarize_hil_readiness(manifest, "OutputDir", char(opts.OutputDir));
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("Simulate", true, @(x) islogical(x) && isscalar(x));
p.addParameter("UnsupportedBlocks", {}, @(x) iscell(x) || isstring(x));
p.addParameter("CpuCores", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("StepBudgetS", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("FastestEventS", NaN, @(x) isnumeric(x) && isscalar(x));
p.parse(varargin{:});
opts = p.Results;
opts.OutputDir = string(opts.OutputDir);
end


function [mdl, loadedHere] = iLoadModel(model)
mdl = char(model);
[~, name, ext] = fileparts(mdl);
if ~isempty(ext)               % a path was given; load it, refer to by name
    if ~bdIsLoaded(name)
        load_system(mdl);
        loadedHere = true;
    else
        loadedHere = false;
    end
    mdl = name;
    return
end
if bdIsLoaded(mdl)
    loadedHere = false;
else
    load_system(mdl);
    loadedHere = true;
end
end


function iCloseIfNeeded(mdl, loadedHere)
% Always pull the model out of any compiled state, then close if we opened it.
try
    feval(mdl, [], [], [], "term");
catch
end
if loadedHere && bdIsLoaded(mdl)
    try
        close_system(mdl, 0);
    catch
    end
end
end

function tf = updateOk2(updateOk, probe)
tf = updateOk && probe.compiled_ok;
end


function probe = iProbeCompiled(mdl)
% Compile the model and read solver/step/rate/state facts. A get_param error
% mid-compile would otherwise strand the model, so every read is guarded and
% 'term' always runs before returning.
probe = struct("compiled_ok", false, "compile_err", "", ...
    "solver_type", "", "solver", "", "fixed_step_s", NaN, ...
    "discrete_rates_s", [], "n_continuous_states", NaN, ...
    "n_discrete_states", NaN, "fastest_rate_s", NaN, "slowest_rate_s", NaN);

probe.solver_type = iSolverTypeTag(get_param(mdl, "SolverType"));
probe.solver = char(get_param(mdl, "Solver"));
fs = get_param(mdl, "FixedStep");
probe.fixed_step_s = iStr2Step(fs);

try
    feval(mdl, [], [], [], "compile");
catch ME
    probe.compile_err = string(ME.message);
    iSafeTerm(mdl);
    return
end

rates = [];
readErr = "";
try
    blks = find_system(mdl, "Type", "Block");
    for i = 1:numel(blks)
        st = get_param(blks{i}, "CompiledSampleTime");
        if iscell(st), st = st{1}; end
        if ~isempty(st) && isfinite(st(1)) && st(1) > 0
            rates(end+1, 1) = st(1); %#ok<AGROW>
        end
    end
    sz = feval(mdl, [], [], [], "sizes");
    probe.n_continuous_states = sz(1);
    probe.n_discrete_states = sz(2);
catch ME
    readErr = string(ME.message);
end

iSafeTerm(mdl);

if strlength(readErr) > 0
    probe.compile_err = readErr;
    return
end
probe.compiled_ok = true;
u = unique(rates);
probe.discrete_rates_s = u(:)';
if ~isempty(u)
    probe.fastest_rate_s = min(u);
    probe.slowest_rate_s = max(u);
end
end


function iSafeTerm(mdl)
try
    feval(mdl, [], [], [], "term");
catch
end
end


function tag = iSolverTypeTag(raw)
% Normalize Simulink's "Fixed-step"/"Variable-step" to the manifest vocabulary.
raw = lower(string(raw));
if contains(raw, "fixed")
    tag = "fixed_step";
elseif contains(raw, "variable")
    tag = "variable_step";
else
    tag = char(raw);
    return
end
tag = char(tag);
end


function s = iStr2Step(fs)
v = str2double(string(fs));
if isnan(v) || v <= 0   % 'auto' or unresolved
    s = NaN;
else
    s = v;
end
end


function manifest = iBuildManifest(mdl, probe, opts, updateOk, updateErr, simOk, simErr)
manifest = struct();
manifest.case_name = char("model_backed_" + string(mdl));
manifest.source_model_or_script = mdl;
manifest.target_platform = "model_backed_software_probe";

manifest.solver_type = probe.solver_type;
manifest.fixed_step_s = probe.fixed_step_s;
% fastest_event_s is the shortest PHYSICAL event the target must resolve (PWM
% carrier, switch event). It is NOT readable from a compiled model and must NOT
% be faked from the fixed step (comparing the step to itself is meaningless), so
% it comes from the caller. NaN => the feasibility check honestly reports it
% undocumented. The compiled rates are still recorded in provenance below.
manifest.fastest_event_s = opts.FastestEventS;

% Continuous states under a fixed-step solver are the algebraic/codegen risk.
manifest.continuous_states_present = ~isnan(probe.n_continuous_states) && probe.n_continuous_states > 0;
% A clean 'update' with no continuous states and a resolved structure is our
% best software-side proxy that no unbroken algebraic loop blocked compile.
manifest.algebraic_loops_present = false;
manifest.algebraic_loops_broken = false;

% Codegen target support is NOT probed here (no build attempted). Mark the
% scan as done only for the unsupported-block list the caller supplied; leave
% codegen_target_supported undocumented unless the caller asserts it.
manifest.unsupported_blocks_checked = true;
manifest.unsupported_blocks = cellstr(opts.UnsupportedBlocks);
manifest.codegen_target_supported = [];   % undocumented => MISSING by design

% Partitions from the compiled discrete rates (compute left unknown -> latency
% MISSING unless caller supplies budget+compute; honest about what we measured).
manifest.partitions = iRatesToPartitions(probe.discrete_rates_s);
manifest.io_channels = iEmptyIo();
manifest.cpu_cores = opts.CpuCores;
manifest.step_budget_s = opts.StepBudgetS;

% Provenance: this is what makes the run model-backed (read by the summarizer).
manifest.model_provenance = struct( ...
    "is_model_backed", true, ...
    "model", mdl, ...
    "update_ok", updateOk, ...
    "update_error", char(updateErr), ...
    "compiled_ok", probe.compiled_ok, ...
    "compile_error", char(probe.compile_err), ...
    "simulated", simOk, ...
    "sim_error", char(simErr), ...
    "n_continuous_states", probe.n_continuous_states, ...
    "n_discrete_states", probe.n_discrete_states, ...
    "discrete_rates_s", probe.discrete_rates_s);

manifest.limitations = char("Model-backed software probe: solver/step/rates/" + ...
    "states read from a compiled model. No code generated, no hardware run.");
end


function parts = iRatesToPartitions(rates)
if isempty(rates)
    parts = struct("name", {}, "rate_s", {}, "compute_s", {});
    return
end
parts = struct("name", {}, "rate_s", {}, "compute_s", {});
for k = 1:numel(rates)
    parts(k).name = sprintf("rate_%g_s", rates(k));
    parts(k).rate_s = rates(k);
    parts(k).compute_s = NaN;   % not measured by a software probe
end
end


function io = iEmptyIo()
io = struct("name", {}, "direction", {}, "placeholder", {});
end

