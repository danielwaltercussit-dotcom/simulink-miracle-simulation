function probe = build_and_run_tiny_decoupled_wrapper_probe(varargin)
%BUILD_AND_RUN_TINY_DECOUPLED_WRAPPER_PROBE  Smoke-test the Level-2 MATLAB S-Function wrapper.
%
%   probe = build_and_run_tiny_decoupled_wrapper_probe("OutputDir", dir)
%
%   Builds a TINY, NON-PRIVATE Simulink model from scratch that uses the
%   Level-2 MATLAB S-Function wrapper `decoupled_interface_sfun` as a block.
%   Runs a real update/simulate cycle to prove the wrapper scaffold is callable
%   inside Simulink.
%
%   Model topology:
%     3 x Constant (V_source, feedback, z_eq_ohm) -> S-Function block
%     -> 3 x Outport (i_boundary, v_error, status_ok)
%
%   This is a TOY SMOKE TEST ONLY. It does NOT validate a real Thevenin/Norton
%   or EMT/averaged interface.
%
%   Returns probe struct: ran, sim_success, model, stop_time_s, max_abs_state,
%   notes, mdl_path, i_boundary, v_error, status_ok.

opts = iParseArgs(varargin{:});
probe = iEmptyResult();
probe.stop_time_s = opts.StopTime;

if ~iSimulinkAvailable()
    probe.ran = false;
    probe.sim_success = false;
    probe.notes = 'Simulink not available; wrapper smoke probe skipped (KNOWN-GAP, not a pass)';
    return
end

modelName = char(opts.ModelName);
cleanupModel = onCleanup(@() iCloseModel(modelName)); %#ok<NASGU>

try
    iBuildModel(modelName, opts);
    probe.model = modelName;

    if strlength(opts.OutputDir) > 0
        if ~isfolder(opts.OutputDir)
            mkdir(opts.OutputDir);
        end
        mdlPath = fullfile(char(opts.OutputDir), [modelName '.slx']);
        save_system(modelName, mdlPath);
        probe.mdl_path = mdlPath;
    end

    % UPDATE (compile): exercises sample-time propagation for the S-Function.
    set_param(modelName, "SimulationCommand", "update");

    % SIMULATE.
    simOut = sim(modelName, ...
        "StopTime", num2str(opts.StopTime), ...
        "SaveOutput", "on", ...
        "ReturnWorkspaceOutputs", "on");

    probe.ran = true;
    [ok, maxAbs, note, vals] = iEvaluateSim(simOut);
    probe.sim_success = ok;
    probe.max_abs_state = maxAbs;
    probe.notes = note;
    if ~isempty(vals)
        probe.i_boundary = vals.i_boundary;
        probe.v_error = vals.v_error;
        probe.status_ok = vals.status_ok;
    end
    % Probe-owned actual configuration: what the saved model actually used.
    % These reflect the constants the probe wired into the saved .slx, NOT
    % any later claims from the stage or plan.
    probe.interface_kind = 'thevenin';
    probe.probe_type = 'wrapper';
    probe.equivalent_impedance_ohm = opts.Z_eq;
    probe.v_source = opts.V_source;
    probe.feedback = opts.Feedback;
catch err
    probe.ran = true;
    probe.sim_success = false;
    probe.max_abs_state = NaN;
    probe.notes = char("build/update/sim error: " + string(err.message));
end
end


function opts = iParseArgs(varargin)
p = inputParser;
p.addParameter("ModelName", "tiny_wrapper_smoke_probe", @(x) ischar(x) || isstring(x));
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("StopTime", 0.01, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 0.05);
p.addParameter("V_source", 1.0, @(x) isnumeric(x) && isscalar(x));
p.addParameter("Feedback", 0.3, @(x) isnumeric(x) && isscalar(x));
p.addParameter("Z_eq", 0.5, @(x) isnumeric(x) && isscalar(x));
p.parse(varargin{:});
opts = p.Results;
opts.ModelName = string(opts.ModelName);
opts.OutputDir = string(opts.OutputDir);
end


function tf = iSimulinkAvailable()
tf = ~isempty(ver('simulink')) && license('test', 'Simulink');
end


function iBuildModel(modelName, opts)
iCloseModel(modelName);
new_system(modelName);

set_param(modelName, "Solver", "FixedStepDiscrete");
set_param(modelName, "FixedStep", "0.001");
set_param(modelName, "StopTime", num2str(opts.StopTime));

% Inputs: 3 Constants.
add_block("simulink/Sources/Constant", modelName + "/V_source", ...
    "Value", num2str(opts.V_source));
add_block("simulink/Sources/Constant", modelName + "/Feedback", ...
    "Value", num2str(opts.Feedback));
add_block("simulink/Sources/Constant", modelName + "/Z_eq_ohm", ...
    "Value", num2str(opts.Z_eq));

% S-Function block using the Level-2 MATLAB S-Function wrapper.
add_block("simulink/User-Defined Functions/Level-2 MATLAB S-Function", ...
    modelName + "/InterfaceWrapper", ...
    "FunctionName", "decoupled_interface_sfun");

% Outputs: 3 Outports.
add_block("simulink/Sinks/Out1", modelName + "/Out_i_boundary");
add_block("simulink/Sinks/Out1", modelName + "/Out_v_error");
add_block("simulink/Sinks/Out1", modelName + "/Out_status_ok");

% Wiring: inputs -> S-Function.
add_line(modelName, "V_source/1", "InterfaceWrapper/1", "autorouting", "on");
add_line(modelName, "Feedback/1", "InterfaceWrapper/2", "autorouting", "on");
add_line(modelName, "Z_eq_ohm/1", "InterfaceWrapper/3", "autorouting", "on");

% Wiring: S-Function -> outputs.
add_line(modelName, "InterfaceWrapper/1", "Out_i_boundary/1", "autorouting", "on");
add_line(modelName, "InterfaceWrapper/2", "Out_v_error/1", "autorouting", "on");
add_line(modelName, "InterfaceWrapper/3", "Out_status_ok/1", "autorouting", "on");
end


function [ok, maxAbs, note, vals] = iEvaluateSim(simOut)
ok = false;
maxAbs = NaN;
vals = struct('i_boundary', NaN, 'v_error', NaN, 'status_ok', NaN);
try
    y = simOut.get("yout");
    data = iExtractSignals(y);
    if isempty(data)
        note = "simulation produced no output";
        return
    end
    vals.i_boundary = data(end, 1);
    vals.v_error    = data(end, 2);
    vals.status_ok  = data(end, 3);
    maxAbs = max(abs(data(:)));
    if all(isfinite(data(:))) && vals.status_ok == 1
        ok = true;
        note = sprintf("sim ok: i=%.4g v_err=%.4g status_ok=%g max|y|=%.4g", ...
            vals.i_boundary, vals.v_error, vals.status_ok, maxAbs);
    else
        note = sprintf("sim output not healthy: status_ok=%g finite=%d", ...
            vals.status_ok, all(isfinite(data(:))));
    end
catch err
    note = char("could not read sim output: " + string(err.message));
end
end


function data = iExtractSignals(y)
% Return Nx3 matrix (i_boundary, v_error, status_ok) from yout.
data = [];
if isempty(y); return; end
if isa(y, "Simulink.SimulationData.Dataset")
    nEl = y.numElements;
    if nEl >= 3
        d1 = y.getElement(1).Values.Data;
        d2 = y.getElement(2).Values.Data;
        d3 = y.getElement(3).Values.Data;
        n = min([numel(d1), numel(d2), numel(d3)]);
        data = [d1(1:n), d2(1:n), d3(1:n)];
    end
elseif isnumeric(y) && size(y, 2) >= 3
    data = y(:, 1:3);
elseif isstruct(y) && isfield(y, "signals") && numel(y.signals) >= 3
    n = min(cellfun(@(s) numel(s.values), num2cell(y.signals(1:3))));
    data = [y.signals(1).values(1:n), y.signals(2).values(1:n), y.signals(3).values(1:n)];
end
end


function iCloseModel(modelName)
name = char(modelName);
try
    if bdIsLoaded(name)
        close_system(name, 0);
    end
catch
end
end


function probe = iEmptyResult()
probe = struct("ran", false, "sim_success", false, "model", "", ...
    "stop_time_s", NaN, "max_abs_state", NaN, "notes", "", "mdl_path", "", ...
    "i_boundary", NaN, "v_error", NaN, "status_ok", NaN, ...
    "interface_kind", '', "probe_type", '', "equivalent_impedance_ohm", NaN, ...
    "v_source", NaN, "feedback", NaN);
end
