function proto = run_fidelity_switch_prototype(varargin)
%RUN_FIDELITY_SWITCH_PROTOTYPE Build + simulate a minimal averaged-vs-switching model.
%   proto = run_fidelity_switch_prototype("CaseName","c1","Vdc",100,"Duty",0.4, ...)
%
%   Minimal, non-private demonstrator of average<->switching equivalence: a
%   single-phase half-bridge driving an RL load, built in memory and ACTUALLY
%   simulated in Simulink.
%     - switching branch: Pulse Generator (Vdc, 1/fc, duty) -> 1/(L s + R)
%     - averaged branch:  Constant (Vdc*duty)              -> 1/(L s + R)
%   In steady state mean(i_sw) ~= i_avg = Vdc*duty/R. The measured error is the
%   relative difference of their steady-state means; the dynamic-phasor /
%   averaged reference current is Vdc*duty/R.
%
%   This function RUNS a model. If Simulink is unavailable or the build/sim
%   fails, it returns ran=false with the error text and never fabricates a
%   measured pass. The model is built in memory and closed without writing any
%   .slx to the repository.
%
%   On success the returned struct can be fed straight into
%   summarize_fidelity_switch_evidence as the measured comparison
%   (MeasuredErrorValue = proto.rel_error, ...).

arguments (Repeating)
    varargin
end
opts = iParse(varargin{:});

proto = struct();
proto.case_name = char(opts.CaseName);
proto.vdc_v = double(opts.Vdc);
proto.duty = double(opts.Duty);
proto.r_ohm = double(opts.R);
proto.l_h = double(opts.L);
proto.carrier_freq_hz = double(opts.CarrierFreqHz);
proto.n_carrier_cycles = double(opts.NCarrierCycles);
proto.samples_per_cycle = double(opts.SamplesPerCycle);
proto.theory_mean_a = proto.vdc_v * proto.duty / proto.r_ohm;
proto.ran = false;
proto.error_text = '';
proto.mean_i_switching_a = NaN;
proto.mean_i_averaged_a = NaN;
proto.abs_error = NaN;
proto.rel_error = NaN;
proto.n_steps = 0;
proto.model_validation_status = 'not_run';

mdl = sprintf('e2_proto_%s', iSafe(proto.case_name));
try
    if exist('new_system', 'file') ~= 2 && exist('new_system', 'builtin') ~= 5
        error('FidelityProto:NoSimulink', 'Simulink new_system is unavailable');
    end
    [meanSw, meanAv, nSteps] = iBuildAndSim(mdl, proto);
    proto.mean_i_switching_a = meanSw;
    proto.mean_i_averaged_a = meanAv;
    proto.abs_error = abs(meanSw - meanAv);
    if meanAv ~= 0
        proto.rel_error = proto.abs_error / abs(meanAv);
    end
    proto.n_steps = nSteps;
    proto.ran = true;
    proto.model_validation_status = 'ran';
catch ME
    proto.error_text = char(ME.message);
    proto.model_validation_status = 'failed';
end

% Best-effort cleanup of the in-memory model.
try
    if bdIsLoaded(mdl)
        close_system(mdl, 0);
    end
catch
    % ignore cleanup errors
end

outDir = char(opts.OutputDir);
if ~isfolder(outDir)
    mkdir(outDir);
end
jsonPath = fullfile(outDir, "prototype_sim.json");
iWriteJson(jsonPath, proto);
proto.json_path = char(jsonPath);
end

function opts = iParse(varargin)
p = inputParser;
isText = @(x) ischar(x) || isstring(x);
isNum = @(x) isnumeric(x) && isscalar(x);
p.addParameter("CaseName", "proto", isText);
p.addParameter("Vdc", 100, isNum);
p.addParameter("Duty", 0.4, isNum);
p.addParameter("R", 2, isNum);
p.addParameter("L", 1e-3, isNum);
p.addParameter("CarrierFreqHz", 2000, isNum);
p.addParameter("NCarrierCycles", 20, isNum);
p.addParameter("SamplesPerCycle", 40, isNum);
p.addParameter("OutputDir", fullfile("build","reports","e2_fidelity_switching","prototype"), isText);
p.parse(varargin{:});
opts = p.Results;
end


function [meanSw, meanAv, nSteps] = iBuildAndSim(mdl, proto)
% Build the averaged-vs-switching RL model in memory and simulate it with a
% fixed-step solver sized to resolve the carrier (~SamplesPerCycle pts/cycle).
fc = proto.carrier_freq_hz;
Tstop = proto.n_carrier_cycles / fc;
fixedStep = 1 / (fc * proto.samples_per_cycle);
den = sprintf('[%g %g]', proto.l_h, proto.r_ohm);

if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
new_system(mdl);
cleanup = onCleanup(@() iClose(mdl));
add_block('simulink/Sources/Pulse Generator', [mdl '/PWM'], ...
    'Amplitude', num2str(proto.vdc_v), 'Period', num2str(1/fc), ...
    'PulseWidth', num2str(proto.duty*100), 'PhaseDelay', '0');
add_block('simulink/Continuous/Transfer Fcn', [mdl '/LoadSw'], ...
    'Numerator', '[1]', 'Denominator', den);
add_block('simulink/Sources/Constant', [mdl '/Davg'], ...
    'Value', num2str(proto.vdc_v * proto.duty));
add_block('simulink/Continuous/Transfer Fcn', [mdl '/LoadAvg'], ...
    'Numerator', '[1]', 'Denominator', den);
add_block('simulink/Sinks/To Workspace', [mdl '/i_sw'], ...
    'VariableName', 'i_sw', 'SaveFormat', 'Structure With Time');
add_block('simulink/Sinks/To Workspace', [mdl '/i_avg'], ...
    'VariableName', 'i_avg', 'SaveFormat', 'Structure With Time');
add_line(mdl, 'PWM/1', 'LoadSw/1');
add_line(mdl, 'LoadSw/1', 'i_sw/1');
add_line(mdl, 'Davg/1', 'LoadAvg/1');
add_line(mdl, 'LoadAvg/1', 'i_avg/1');
set_param(mdl, 'Solver', 'ode4', 'FixedStep', num2str(fixedStep), ...
    'StopTime', num2str(Tstop));

simOut = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
isw = simOut.get('i_sw');
iav = simOut.get('i_avg');
t = isw.time;
ysw = isw.signals.values;
yav = iav.signals.values;
% Steady-state window: last third of the run.
mask = t >= (2/3) * Tstop;
meanSw = mean(ysw(mask));
meanAv = mean(yav(mask));
nSteps = numel(t);
end


function iClose(mdl)
if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
end


function s = iSafe(name)
s = regexprep(char(name), '[^A-Za-z0-9_]', '_');
if isempty(s)
    s = 'proto';
end
if ~isletter(s(1))
    s = ['m_' s];
end
end


function iWriteJson(path, s)
fid = fopen(path, "w");
if fid < 0
    error("FidelityProto:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(s, "PrettyPrint", true));
end
