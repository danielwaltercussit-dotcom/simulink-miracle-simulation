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
%   The leg is INITIALISABLE (InitialCurrent seeds the load current) and
%   actually exercises switching-level non-idealities so their evidence is
%   MODEL-BACKED, not asserted:
%     - DeadTimeS: a dead-time, quantised to whole fixed steps, during which
%       both controlled devices are off and the freewheeling diodes clamp the
%       pole to the rail set by the load-current direction (real dead-time
%       distortion, current-polarity dependent);
%     - Ron, Vf: a non-ideal conduction drop v = Ron*|i| + Vf opposing current,
%       with instantaneous conduction loss p = Ron*i^2 + Vf*|i| logged so the
%       mean loss comes from the simulation. With Ron=Vf=0 the leg is ideal and
%       the loss is identically zero (caller must report it as N/A, not 0 W).
%
%   Returns a struct with fields:
%     t, x               time and leg-current vectors (model output)
%     p_cond, v_pole     conduction-loss power and pole-voltage waveforms
%     conduction_loss_w  mean conduction loss over whole periods (model-backed)
%     device_loss_mode   ideal | on-resistance | Vf | on-resistance+Vf
%     params             carrier_hz, sample_time_s, dead_time_steps, Ron, Vf...
%     provenance         source_type/simulated/synthetic/model_name for intake
%     model_name         the (temporary) model name that was simulated
%
%   Requires Simulink (and a MATLAB Function block, i.e. the discrete leg
%   recurrence runs as generated code). Pure Simulink, no Simscape.

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

[t, x, pCond, vPole] = iExtractSignals(simOut);

out.t = t;
out.x = x;
out.p_cond = pCond;
out.v_pole = vPole;
out.model_name = modelName;
% Mean conduction loss over a whole number of fundamental periods (drop the
% first period so the initial transient does not bias the average).
out.conduction_loss_w = iMeanLoss(t, pCond, opts.FundamentalHz);
out.params = struct( ...
    "fundamental_hz", opts.FundamentalHz, ...
    "carrier_hz", opts.CarrierHz, ...
    "sample_time_s", opts.SampleTimeS, ...
    "vdc", opts.Vdc, "r_load", opts.RLoad, "l_load", opts.LLoad, ...
    "modulation_index", opts.ModulationIndex, ...
    "initial_current_a", opts.InitialCurrent, ...
    "dead_time_s", opts.DeadtimeSteps * opts.SampleTimeS, ...
    "dead_time_steps", opts.DeadtimeSteps, ...
    "ron_ohm", opts.Ron, "vf_v", opts.Vf, "is_ideal", opts.IsIdeal);
out.device_loss_mode = iLossModeLabel(opts);
out.provenance = struct( ...
    "source_type", "simulation_output", ...
    "source_id", modelName, ...
    "model_name", modelName, ...
    "simulated", true, ...
    "synthetic", false, ...
    "notes", "tiny generic half-bridge SPWM leg, dead-time + non-ideal drop, RL load, fixed-step discrete");

if strlength(opts.OutputDir) > 0
    if ~isfolder(opts.OutputDir); mkdir(opts.OutputDir); end
    waveform = struct("t", t, "x", x, "p_cond", pCond, "v_pole", vPole);
    provenance = out.provenance;
    params = out.params;
    save(fullfile(opts.OutputDir, "tiny_switching_run.mat"), ...
        "waveform", "provenance", "params");
end
end


function lbl = iLossModeLabel(opts)
if opts.IsIdeal
    lbl = "ideal";
elseif opts.Vf > 0 && opts.Ron > 0
    lbl = "on-resistance+Vf";
elseif opts.Ron > 0
    lbl = "on-resistance";
else
    lbl = "Vf";
end
lbl = char(lbl);
end


function p = iMeanLoss(t, pCond, fundHz)
if isempty(pCond) || numel(pCond) < 4
    p = NaN;
    return
end
period = 1 / fundHz;
% Average over an integer number of periods after the first, when possible.
tEnd = t(end);
if tEnd > 2*period
    sel = t >= period & t <= (tEnd - mod(tEnd - period, period));
else
    sel = true(size(t));
end
if nnz(sel) < 2
    sel = true(size(t));
end
p = mean(pCond(sel));
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
% Initialisable + non-ideal device parameters (Phase 2a).
p.addParameter("InitialCurrent", 0, @(x) isnumeric(x) && isscalar(x));
p.addParameter("DeadTimeS", 2e-6, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter("Ron", 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter("Vf", 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.ModelName = string(opts.ModelName);
opts.OutputDir = string(opts.OutputDir);
% Dead-time is quantised to whole fixed steps (a sub-step dead-time is not
% representable on a discrete grid). DeadtimeSteps is reported so the caller
% can see whether the requested dead-time was resolvable.
opts.DeadtimeSteps = floor(opts.DeadTimeS / opts.SampleTimeS + 1e-9);
opts.IsIdeal = (opts.Ron == 0) && (opts.Vf == 0);
end


function iCloseQuietly(modelName)
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end


function iBuildModel(modelName, opts)
% Assemble the leg model programmatically. A single MATLAB Function block holds
% the discrete leg recurrence (SPWM + dead-time freewheeling + non-ideal device
% drop + RL update + conduction-loss logging) with persistent state, so there
% is no algebraic loop and the dead-time / loss effects are produced BY THE
% SIMULATION, not asserted. Fixed-step discrete solver at SampleTimeS.
new_system(modelName);
ts = opts.SampleTimeS;

set_param(modelName, "Solver", "FixedStepDiscrete", ...
    "FixedStep", num2str(ts), "StopTime", num2str(opts.StopTime), ...
    "SolverType", "Fixed-step");

% Reference and triangular carrier feed the leg function.
add_block("simulink/Sources/Sine Wave", [modelName '/ref'], ...
    "Amplitude", num2str(opts.ModulationIndex), ...
    "Frequency", num2str(2*pi*opts.FundamentalHz), ...
    "SampleTime", num2str(ts), "Position", [30 60 70 100]);
Tc = 1/opts.CarrierHz;
add_block("simulink/Sources/Repeating Sequence", [modelName '/carrier'], ...
    "rep_seq_t", sprintf('[0 %g %g]', Tc/2, Tc), ...
    "rep_seq_y", '[-1 1 -1]', "Position", [30 140 70 180]);

add_block("simulink/User-Defined Functions/MATLAB Function", ...
    [modelName '/leg'], "Position", [150 70 320 180]);
iSetLegScript(modelName, opts);

% Three logged outputs: load current, conduction-loss power, pole voltage.
add_block("simulink/Sinks/Out1", [modelName '/i_load'], "Position", [380 80 410 100]);
add_block("simulink/Sinks/Out1", [modelName '/p_cond'], "Position", [380 120 410 140], "Port", "2");
add_block("simulink/Sinks/Out1", [modelName '/v_pole'], "Position", [380 160 410 180], "Port", "3");
set_param(modelName, "SaveOutput", "on", "OutputSaveName", "yout", ...
    "SaveFormat", "Dataset", "SignalLogging", "on");

add_line(modelName, "ref/1", "leg/1", "autorouting", "on");
add_line(modelName, "carrier/1", "leg/2", "autorouting", "on");
add_line(modelName, "leg/1", "i_load/1", "autorouting", "on");
add_line(modelName, "leg/2", "p_cond/1", "autorouting", "on");
add_line(modelName, "leg/3", "v_pole/1", "autorouting", "on");
end


function iSetLegScript(modelName, opts)
% Inject the discrete leg recurrence into the MATLAB Function block via the
% Stateflow API. Parameters are baked in as literals so the block needs no
% workspace variables (keeps the tiny model self-contained).
script = iLegScriptText(opts);
rt = sfroot;
chart = rt.find('-isa', 'Stateflow.EMChart', 'Path', [modelName '/leg']);
if isempty(chart)
    error("TinySwitching:NoChart", "Could not locate the MATLAB Function block chart.");
end
chart(1).Script = script;
end


function s = iLegScriptText(opts)
% Build the leg function source. Half-bridge pole with:
%   - naturally-sampled SPWM (ref >= carrier -> upper device intended ON);
%   - dead-time of nDt whole steps: during the gap NEITHER device is gated and
%     the pole is clamped by the freewheeling diode set by current sign;
%   - non-ideal conduction drop v_drop = Ron*|i| + Vf (subtracted with the sign
%     of current), and logged power p = Ron*i^2 + Vf*|i|;
%   - backward-Euler RL update i[k] = (L*i[k-1] + Ts*v_applied)/(L + R*Ts).
% State is persistent; initial current is opts.InitialCurrent.
nDt = opts.DeadtimeSteps;
lines = {
'function [i_load, p_cond, v_pole] = leg(ref, carrier)'
'%#codegen'
sprintf('Vdc = %.10g; R = %.10g; L = %.10g; Ts = %.10g;', opts.Vdc, opts.RLoad, opts.LLoad, opts.SampleTimeS)
sprintf('Ron = %.10g; Vf = %.10g; nDt = %d;', opts.Ron, opts.Vf, nDt)
'persistent i_prev gprev cnt'
'if isempty(i_prev)'
sprintf('    i_prev = %.10g;', opts.InitialCurrent)
'    gprev = (ref >= carrier);'
'    cnt = nDt;'  % allow gates to be active at t=0 after initial settle
'end'
'g = (ref >= carrier);'      % intended upper-on command
'if g ~= gprev'              % a commutation just occurred -> start dead-time
'    cnt = 0;'
'end'
'inDead = (cnt < nDt);'      % within the dead-time blanking window
'cnt = cnt + 1;'
'isgn = sign(i_prev);'
'if inDead'
'    % Both controlled devices off: freewheeling diodes clamp the pole to the'
'    % rail set by the load-current direction (current must keep flowing in L).'
'    if isgn >= 0'
'        v_pole = -Vdc/2;'
'    else'
'        v_pole = Vdc/2;'
'    end'
'else'
'    if g'
'        v_pole = Vdc/2;'
'    else'
'        v_pole = -Vdc/2;'
'    end'
'end'
'% Non-ideal device conduction drop opposes current flow.'
'v_drop = Ron*abs(i_prev) + Vf;'
'v_applied = v_pole - isgn*v_drop;'
'% Backward-Euler RL update (implicit, stable for any Ts).'
'i_load = (L*i_prev + Ts*v_applied)/(L + R*Ts);'
'% Instantaneous conduction loss in the conducting device.'
'p_cond = Ron*i_prev^2 + Vf*abs(i_prev);'
'i_prev = i_load;'
'gprev = g;'
'end'
};
s = strjoin(lines, newline);
end


function [t, x, pCond, vPole] = iExtractSignals(simOut)
% Pull the three logged outputs (i_load, p_cond, v_pole) from the
% SimulationOutput Dataset, by Out1 port order, with a tout time base.
y = simOut.get("yout");
if ~isa(y, "Simulink.SimulationData.Dataset")
    error("TinySwitching:NoOutput", "Expected a Dataset in yout.");
end
if y.numElements < 3
    error("TinySwitching:MissingOutputs", ...
        "Expected 3 logged outputs, found %d.", y.numElements);
end
v1 = y.getElement(1).Values;
t = double(v1.Time(:));
x = iFirstCol(v1.Data);
pCond = iFirstCol(y.getElement(2).Values.Data);
vPole = iFirstCol(y.getElement(3).Values.Data);
end


function x = iFirstCol(x)
if ~isvector(x)
    x = x(:, 1);
end
x = x(:);
end
