function probe = build_and_run_tiny_decoupled_interface_probe(varargin)
%BUILD_AND_RUN_TINY_DECOUPLED_INTERFACE_PROBE Build + simulate a tiny decoupled-interface chain.
%
%   probe = build_and_run_tiny_decoupled_interface_probe("OutputDir",dir)
%   probe = build_and_run_tiny_decoupled_interface_probe("OutputDir",dir,"StopTime",0.02)
%
%   Builds a TINY, NON-PRIVATE Simulink model entirely from scratch (no lab or
%   private model is opened or copied, no oracle is referenced), then runs a
%   real load/update/simulate cycle so that summarize_decoupled_interface_plan
%   can attach genuine model-backed evidence instead of a self-asserted flag.
%
%   The model exercises a toy decoupled-interface boundary:
%     - a discrete source signal representing a Thevenin equivalent voltage
%       proxy (sine + offset at the source sample rate),
%     - a Gain block representing equivalent impedance (Z_eq),
%     - a Unit Delay as the algebraic-loop breaker at the boundary,
%     - a Zero-Order Hold as the explicit hold/sample boundary between domains,
%     - a Sum block computing boundary current proxy: I = (V_src - V_feedback) / Z,
%     - an Outport for the boundary current output (logged, max_abs_state),
%   so update/compile exercises sample-time propagation and the loop breaker,
%   and simulate actually integrates the decoupled interface chain.
%
%   This is a TOY/EVIDENCE probe only. It does NOT claim to validate a real
%   Thevenin/Norton or EMT/averaged interface. It only proves the
%   build/update/sim path works and generates a non-empty result.
%
%   Returns a struct consumable by summarize_decoupled_interface_plan's
%   ModelProbe parameter:
%     .ran           logical, true if build+update+sim were attempted
%     .sim_success   logical, true if sim completed with finite output
%     .model         char, model name
%     .stop_time_s   double, simulated stop time
%     .max_abs_state double, max abs output observed (finite => stable run)
%     .notes         char, human-readable outcome
%     .mdl_path      char, path to the saved .slx under the (gitignored) OutputDir
%
%   No Simulink (not installed or unlicensed) => the probe returns ran=false
%   with an explanatory note; the caller must treat that as SKIPPED /
%   KNOWN-GAP, never as a pass.

opts = iParseProbeArgs(varargin{:});
probe = iEmptyProbeResult();
probe.stop_time_s = opts.StopTime;

% Refuse to run if Simulink is not available; do not fake a pass.
if ~iSimulinkAvailable()
    probe.ran = false;
    probe.sim_success = false;
    probe.notes = 'Simulink not available; tiny decoupled-interface probe skipped (KNOWN-GAP, not a pass)';
    return
end

modelName = char(opts.ModelName);
cleanupModel = onCleanup(@() iCloseModel(modelName)); %#ok<NASGU>

try
    iBuildModel(modelName, opts);
    probe.model = modelName;
    % Probe-owned actual configuration: what the model was built with.
    probe.interface_kind = 'thevenin';
    probe.probe_type = 'topology';
    probe.equivalent_impedance_ohm = opts.Z_eq_ohm;
    probe.source_sample_time_s = opts.SourceStep;
    probe.target_sample_time_s = opts.TargetStep;

    if strlength(opts.OutputDir) > 0
        if ~isfolder(opts.OutputDir)
            mkdir(opts.OutputDir);
        end
        mdlPath = fullfile(char(opts.OutputDir), [modelName '.slx']);
        save_system(modelName, mdlPath);
        probe.mdl_path = mdlPath;
    end

    % UPDATE (compile): exercises sample-time propagation + loop breaker.
    set_param(modelName, "SimulationCommand", "update");

    % SIMULATE: a real integration across the decoupled interface chain.
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
p.addParameter("ModelName", "tiny_decoupled_iface_probe", @(x) ischar(x) || isstring(x));
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("StopTime", 0.02, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 0.05);
p.addParameter("SourceStep", 1e-4, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("TargetStep", 1e-3, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("Z_eq_ohm", 0.5, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.parse(varargin{:});
opts = p.Results;
opts.ModelName = string(opts.ModelName);
opts.OutputDir = string(opts.OutputDir);
end


function tf = iSimulinkAvailable()
% Lightweight pre-screen: is Simulink installed and licensed?
% Do NOT use exist('new_system','file')==2 here -- on some installs that
% returns 0 even when Simulink is fully available.
tf = ~isempty(ver('simulink')) && license('test', 'Simulink');
end


function iBuildModel(modelName, opts)
% Build a tiny decoupled-interface chain from scratch. No private model touched.
%
% Hardened topology (DIF-2.1):
%   V_thevenin ---->(+)BoundarySum(-)<--- FeedbackGain <--- LoopBreaker <-+
%                    |                                                      |
%                    v                                                      |
%                 Z_eq_inv --> LoopBreaker --> ZOH_boundary --> I_boundary  |
%                                                 |                        |
%                                                 +------------------------+
%
% The Sum block computes: error = V_src - V_fb. The Z_eq_inv converts voltage
% error to current. The Unit Delay breaks the algebraic loop. The ZOH is the
% discrete sample boundary between source and target domain. FeedbackGain
% represents the measurement/boundary voltage proxy (gain < 1 for stability).
% I_boundary is the logged Outport for max_abs_state.

iCloseModel(modelName);
new_system(modelName);

srcStep = num2str(opts.SourceStep);
tgtStep = num2str(opts.TargetStep);

set_param(modelName, "Solver", "FixedStepDiscrete");
set_param(modelName, "FixedStep", srcStep);
set_param(modelName, "StopTime", num2str(opts.StopTime));

% Source: Thevenin equivalent voltage proxy (discrete sine at source rate).
add_block("simulink/Sources/Sine Wave", modelName + "/V_thevenin", ...
    "Amplitude", "1", "Frequency", "2*pi*500", "Bias", "0.5", ...
    "SampleTime", srcStep);

% Boundary Sum: error = V_src(+) - V_feedback(-).
add_block("simulink/Math Operations/Sum", modelName + "/BoundarySum", ...
    "Inputs", "+-");

% Equivalent impedance gain: I = V_error / Z_eq.
add_block("simulink/Math Operations/Gain", modelName + "/Z_eq_inv", ...
    "Gain", num2str(1/opts.Z_eq_ohm));

% Unit Delay as the algebraic-loop breaker (source rate).
add_block("simulink/Discrete/Unit Delay", modelName + "/LoopBreaker", ...
    "SampleTime", srcStep, "InitialCondition", "0");

% Zero-Order Hold as the sample boundary between source domain and target domain.
add_block("simulink/Discrete/Zero-Order Hold", modelName + "/ZOH_boundary", ...
    "SampleTime", tgtStep);

% Feedback/measurement proxy: a gain < 1 representing the measurement of
% boundary voltage fed back to the Sum negative input.
add_block("simulink/Math Operations/Gain", modelName + "/FeedbackGain", ...
    "Gain", "0.3");

% Output (boundary current proxy).
add_block("simulink/Sinks/Out1", modelName + "/I_boundary");

% Wiring (forward path):
%   V_thevenin -> BoundarySum(+) -> Z_eq_inv -> LoopBreaker -> ZOH_boundary -> I_boundary
add_line(modelName, "V_thevenin/1", "BoundarySum/1", "autorouting", "on");
add_line(modelName, "BoundarySum/1", "Z_eq_inv/1", "autorouting", "on");
add_line(modelName, "Z_eq_inv/1", "LoopBreaker/1", "autorouting", "on");
add_line(modelName, "LoopBreaker/1", "ZOH_boundary/1", "autorouting", "on");
add_line(modelName, "ZOH_boundary/1", "I_boundary/1", "autorouting", "on");

% Wiring (feedback path):
%   ZOH_boundary -> FeedbackGain -> BoundarySum(-) (port 2)
add_line(modelName, "ZOH_boundary/1", "FeedbackGain/1", "autorouting", "on");
add_line(modelName, "FeedbackGain/1", "BoundarySum/2", "autorouting", "on");
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
try
    if bdIsLoaded(name)
        close_system(name, 0);
    end
catch
    % bdIsLoaded unavailable or model not loaded: nothing to close.
end
end


function probe = iEmptyProbeResult()
probe = struct("ran", false, "sim_success", false, "model", "", ...
    "stop_time_s", NaN, "max_abs_state", NaN, "notes", "", "mdl_path", "", ...
    "interface_kind", '', "probe_type", '', ...
    "source_sample_time_s", NaN, "target_sample_time_s", NaN, ...
    "equivalent_impedance_ohm", NaN);
end
