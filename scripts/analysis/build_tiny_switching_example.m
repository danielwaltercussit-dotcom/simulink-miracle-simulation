function out = build_tiny_switching_example(varargin)
%BUILD_TINY_SWITCHING_EXAMPLE Build/run a tiny non-private switching converter.
%
%   out = build_tiny_switching_example("OutputDir",dir, "StopTime",0.06)
%
%   Builds a SMALL, GENERIC, NON-PRIVATE half-bridge converter leg switching a
%   series-RL load with naturally-sampled SPWM, programmatically (no saved .slx
%   shipped, no lab/private model touched). It actually compiles and simulates
%   the model with a fixed-step discrete solver, then returns the logged leg
%   current as a real Simulink.SimulationOutput-derived waveform plus a
%   provenance struct suitable for ingest_switching_waveform_evidence.
%
%   This is a textbook averaged-switch-free EMT leg: the half-bridge output node
%   is +Vdc/2 or -Vdc/2 according to a PWM comparison of a sine reference with a
%   triangular carrier; the RL load integrates that pole voltage. It exists only
%   to produce a genuine model-backed switching waveform for the E1 evidence
%   path; it is not a power-system study model.
%
%   Returns a struct with fields:
%     t, x            time and leg-current vectors (model output)
%     provenance      source_type/simulated/synthetic/model_name for ingestion
%     params          carrier_hz, sample_time_s, fundamental_hz, etc.
%     model_name      the (temporary) model name that was simulated
%
%   Requires Simulink. Pure-Simulink (no Simscape), so it compiles quickly on a
%   base Simulink install.

opts = iParseOpts(varargin{:});
modelName = char(opts.ModelName);

% Clean any stale model of this name so a prior run cannot leak in.
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

out = struct();
cleanup = onCleanup(@() iCloseQuietly(modelName));
iBuildModel(modelName, opts);

simOut = sim(modelName, ...
    "StopTime", num2str(opts.StopTime), ...
    "SaveOutput", "on", ...
    "ReturnWorkspaceOutputs", "on");

[t, x] = iExtractLegCurrent(simOut);

out.t = t;
out.x = x;
out.model_name = modelName;
out.params = struct( ...
    "fundamental_hz", opts.FundamentalHz, ...
    "carrier_hz", opts.CarrierHz, ...
    "sample_time_s", opts.SampleTimeS, ...
    "vdc", opts.Vdc, "r_load", opts.RLoad, "l_load", opts.LLoad, ...
    "modulation_index", opts.ModulationIndex);
out.provenance = struct( ...
    "source_type", "simulation_output", ...
    "source_id", modelName, ...
    "model_name", modelName, ...
    "simulated", true, ...
    "synthetic", false, ...
    "notes", "tiny generic half-bridge SPWM leg, RL load, fixed-step discrete");

if strlength(opts.OutputDir) > 0
    if ~isfolder(opts.OutputDir); mkdir(opts.OutputDir); end
    waveform = struct("t", t, "x", x);
    provenance = out.provenance;
    params = out.params;
    save(fullfile(opts.OutputDir, "tiny_switching_run.mat"), ...
        "waveform", "provenance", "params");
end
end


function opts = iParseOpts(varargin)
p = inputParser;
p.addParameter("ModelName", "e1_tiny_switching_leg", @(x) ischar(x) || isstring(x));
p.addParameter("FundamentalHz", 50, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("CarrierHz", 2000, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("SampleTimeS", 5e-6, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("StopTime", 0.06, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("Vdc", 700, @(x) isnumeric(x) && isscalar(x));
p.addParameter("RLoad", 2, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("LLoad", 5e-3, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("ModulationIndex", 0.9, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.ModelName = string(opts.ModelName);
opts.OutputDir = string(opts.OutputDir);
end


function iCloseQuietly(modelName)
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end


function iBuildModel(modelName, opts)
% Assemble the leg model programmatically. Pure Simulink blocks; fixed-step
% discrete solver at SampleTimeS. The pole voltage is +Vdc/2 / -Vdc/2 selected
% by a naturally-sampled SPWM comparison, and an RL load integrates it.
new_system(modelName);
ts = opts.SampleTimeS;

set_param(modelName, "Solver", "FixedStepDiscrete", ...
    "FixedStep", num2str(ts), "StopTime", num2str(opts.StopTime), ...
    "SolverType", "Fixed-step");

add_block("simulink/Sources/Sine Wave", [modelName '/ref'], ...
    "Amplitude", num2str(opts.ModulationIndex), ...
    "Frequency", num2str(2*pi*opts.FundamentalHz), ...
    "SampleTime", num2str(ts), "Position", [30 40 70 80]);

% Triangular carrier in [-1,1] via a Repeating Sequence Stair-free triangle:
% use a Repeating Sequence (interpolated) over one carrier period.
Tc = 1/opts.CarrierHz;
add_block("simulink/Sources/Repeating Sequence", [modelName '/carrier'], ...
    "rep_seq_t", sprintf('[0 %g %g]', Tc/2, Tc), ...
    "rep_seq_y", '[-1 1 -1]', "Position", [30 140 70 180]);

add_block("simulink/Logic and Bit Operations/Relational Operator", ...
    [modelName '/cmp'], "Operator", ">=", "Position", [130 80 170 120]);

% PWM -> +Vdc/2 when ref>=carrier else -Vdc/2, via Switch on a 0.5 threshold.
add_block("simulink/Signal Routing/Switch", [modelName '/leg'], ...
    "Threshold", "0.5", "Position", [230 70 270 130]);
add_block("simulink/Sources/Constant", [modelName '/vhi'], ...
    "Value", num2str(opts.Vdc/2), "SampleTime", num2str(ts), ...
    "Position", [130 30 170 60]);
add_block("simulink/Sources/Constant", [modelName '/vlo'], ...
    "Value", num2str(-opts.Vdc/2), "SampleTime", num2str(ts), ...
    "Position", [130 140 170 170]);

% Discrete RL load: I(z)/V(z) = Ts / (L + R*Ts) ... use a Discrete Transfer Fcn
% approximating 1/(L s + R) by backward Euler: H(z) = Ts / ((L+R*Ts) - L z^-1).
a0 = opts.LLoad + opts.RLoad*ts;
add_block("simulink/Discrete/Discrete Transfer Fcn", [modelName '/rl'], ...
    "Numerator", sprintf('[%g]', ts), ...
    "Denominator", sprintf('[%g %g]', a0, -opts.LLoad), ...
    "SampleTime", num2str(ts), "Position", [330 80 390 120]);

add_block("simulink/Sinks/Out1", [modelName '/i_load'], "Position", [440 90 470 110]);
% Name the signal feeding Out1 so the logged Dataset element is identifiable.
set_param(modelName, "SaveOutput", "on", "OutputSaveName", "yout", ...
    "SaveFormat", "Dataset", "SignalLogging", "on");

% Wiring.
add_line(modelName, "ref/1", "cmp/1", "autorouting", "on");
add_line(modelName, "carrier/1", "cmp/2", "autorouting", "on");
add_line(modelName, "cmp/1", "leg/2", "autorouting", "on");
add_line(modelName, "vhi/1", "leg/1", "autorouting", "on");
add_line(modelName, "vlo/1", "leg/3", "autorouting", "on");
add_line(modelName, "leg/1", "rl/1", "autorouting", "on");
add_line(modelName, "rl/1", "i_load/1", "autorouting", "on");
end


function [t, x] = iExtractLegCurrent(simOut)
% Pull the logged leg current from the SimulationOutput. The Out1 logs into the
% 'yout' Dataset (one timeseries element); fall back to tout for the time base.
y = simOut.get("yout");
if isa(y, "Simulink.SimulationData.Dataset")
    if y.numElements < 1
        error("TinySwitching:NoOutput", "yout Dataset is empty.");
    end
    vals = y.getElement(1).Values;     % a timeseries
    t = vals.Time;
    x = vals.Data;
elseif isa(y, "timeseries")
    t = y.Time;
    x = y.Data;
elseif isstruct(y) && isfield(y, "signals")
    t = y.time;
    x = y.signals(1).values;
else
    % last resort: tout + yout-as-matrix
    t = simOut.get("tout");
    x = y;
end
t = double(t(:));
x = iFirstCol(x);
end


function x = iFirstCol(x)
if ~isvector(x)
    x = x(:, 1);
end
x = x(:);
end
