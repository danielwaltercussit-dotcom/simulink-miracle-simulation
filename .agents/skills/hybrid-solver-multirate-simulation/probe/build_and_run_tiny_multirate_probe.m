function probe = build_and_run_tiny_multirate_probe(varargin)
%BUILD_AND_RUN_TINY_MULTIRATE_PROBE Build + simulate a tiny multirate model.
%
%   probe = build_and_run_tiny_multirate_probe("OutputDir",dir, ...
%       "StopTime",0.05, "Solver","ode23tb")
%
%   Builds a TINY, NON-PRIVATE Simulink model entirely from scratch (no lab or
%   private model is opened or copied), then runs a real load/update/simulate
%   cycle so the M1 package can attach genuine model-backed solver evidence
%   instead of a self-asserted flag.
%
%   The model is genuinely multirate:
%     - a continuous first-order plant integrated by a variable-step solver
%       (the fastest/continuous partition),
%     - a fast discrete rate (e.g. 1 ms) sampling the plant,
%     - a slow discrete rate (e.g. 5 ms) downstream,
%     - Rate Transition blocks at the discrete rate boundary,
%   so update/compile actually exercises sample-time propagation and rate
%   transitions, and simulate actually integrates across the continuous +
%   discrete mix.
%
%   Returns a struct consumable by summarize_multirate_solver_plan's ModelProbe:
%     .ran           logical, true if build+update+sim were attempted
%     .sim_success   logical, true if sim completed with finite states
%     .model         char, model name
%     .solver        char, solver used
%     .stop_time_s   double, simulated stop time
%     .max_abs_state double, max abs output observed (finite => stable run)
%     .notes         char, human-readable outcome
%     .fastest_event_hz / .slowest_mode_hz  doubles, the model's actual rates
%     .mdl_path      char, path to the saved .slx under the (gitignored) OutputDir
%
%   The model is created under a gitignored build/ directory by default and is
%   NOT a tracked artifact. Nothing private is referenced.

opts = iParseProbeArgs(varargin{:});
probe = iEmptyProbeResult();
probe.solver = char(opts.Solver);
probe.stop_time_s = opts.StopTime;
probe.fastest_event_hz = 1 / opts.FastStep;
probe.slowest_mode_hz = 1 / opts.SlowStep;

modelName = opts.ModelName;
mdlPath = "";
cleanupModel = onCleanup(@() iCloseModel(modelName));

try
    iBuildModel(modelName, opts);
    probe.model = char(modelName);

    if strlength(opts.OutputDir) > 0
        if ~isfolder(opts.OutputDir)
            mkdir(opts.OutputDir);
        end
        mdlPath = fullfile(char(opts.OutputDir), char(modelName) + ".slx");
        save_system(modelName, mdlPath);
    end
    probe.mdl_path = char(mdlPath);

    % UPDATE (compile): exercises sample-time propagation + rate transitions.
    set_param(modelName, "SimulationCommand", "update");

    % SIMULATE: a real integration across the continuous + discrete partitions.
    simOut = sim(modelName, ...
        "StopTime", num2str(opts.StopTime), ...
        "SaveOutput", "on", ...
        "ReturnWorkspaceOutputs", "on");

    probe.ran = true;
    [ok, maxAbs, note] = iEvaluateSim(simOut);
    probe.sim_success = ok;
    probe.max_abs_state = maxAbs;
    probe.notes = note;
catch err
    probe.ran = true;
    probe.sim_success = false;
    probe.max_abs_state = NaN;
    probe.notes = char("build/update/sim error: " + string(err.message));
end
end


function opts = iParseProbeArgs(varargin)
p = inputParser;
p.addParameter("ModelName", "m1_tiny_multirate_probe", @(x) ischar(x) || isstring(x));
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("StopTime", 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("Solver", "ode23tb", @(x) ischar(x) || isstring(x));
p.addParameter("FastStep", 1e-3, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("SlowStep", 5e-3, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.parse(varargin{:});
opts = p.Results;
opts.ModelName = string(opts.ModelName);
opts.OutputDir = string(opts.OutputDir);
opts.Solver = string(opts.Solver);
end


function iBuildModel(modelName, opts)
% Build a tiny hybrid/multirate model from scratch. No private model touched.
iCloseModel(modelName);
new_system(modelName);

set_param(modelName, "Solver", char(opts.Solver));
set_param(modelName, "SolverType", "Variable-step");
set_param(modelName, "StopTime", num2str(opts.StopTime));

% Continuous partition: first-order plant 1/(s+1) driven by a step.
add_block("simulink/Sources/Step", modelName + "/Step", ...
    "Time", "0", "Before", "0", "After", "1");
add_block("simulink/Continuous/Transfer Fcn", modelName + "/Plant", ...
    "Numerator", "[1]", "Denominator", "[1 1]");

% Fast discrete partition (1 ms): a unit-delay sampling the plant output.
add_block("simulink/Discrete/Unit Delay", modelName + "/FastDelay", ...
    "SampleTime", num2str(opts.FastStep));

% Rate transition from fast (1 ms) to slow (5 ms) discrete rate.
add_block("simulink/Signal Attributes/Rate Transition", modelName + "/RT_fast_to_slow", ...
    "OutPortSampleTime", num2str(opts.SlowStep));

% Slow discrete partition (5 ms): a gain on the slow rate.
add_block("simulink/Math Operations/Gain", modelName + "/SlowGain", ...
    "Gain", "0.5", "SampleTime", num2str(opts.SlowStep));

add_block("simulink/Sinks/Out1", modelName + "/Out");

add_line(modelName, "Step/1", "Plant/1", "autorouting", "on");
add_line(modelName, "Plant/1", "FastDelay/1", "autorouting", "on");
add_line(modelName, "FastDelay/1", "RT_fast_to_slow/1", "autorouting", "on");
add_line(modelName, "RT_fast_to_slow/1", "SlowGain/1", "autorouting", "on");
add_line(modelName, "SlowGain/1", "Out/1", "autorouting", "on");
end


function [ok, maxAbs, note] = iEvaluateSim(simOut)
% A run is successful if it produced finite output of nonzero length.
ok = false;
maxAbs = NaN;
try
    y = simOut.get("yout");
    data = iExtractSignal(y);
    if isempty(data)
        note = "simulation produced no output samples";
        return
    end
    maxAbs = max(abs(data(:)));
    if all(isfinite(data(:)))
        ok = true;
        note = sprintf("sim ok: %d samples, max|y|=%.4g", numel(data), maxAbs);
    else
        note = "simulation output contained non-finite values";
    end
catch err
    note = char("could not read sim output: " + string(err.message));
end
end


function data = iExtractSignal(y)
% Tolerate the different shapes sim() can return for yout.
data = [];
if isempty(y)
    return
end
if isa(y, "Simulink.SimulationData.Dataset")
    if y.numElements >= 1
        el = y.getElement(1);
        data = el.Values.Data;
    end
elseif isnumeric(y)
    data = y;
elseif isstruct(y) && isfield(y, "signals")
    data = y.signals(1).values;
end
end


function iCloseModel(modelName)
name = char(modelName);
if bdIsLoaded(name)
    close_system(name, 0);
end
end


function probe = iEmptyProbeResult()
probe = struct("ran", false, "sim_success", false, "model", "", ...
    "solver", "", "stop_time_s", NaN, "max_abs_state", NaN, "notes", "", ...
    "fastest_event_hz", NaN, "slowest_mode_hz", NaN, "mdl_path", "");
end
