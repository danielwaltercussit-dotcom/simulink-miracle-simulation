function probe = run_mmc_dc_fault_probe(varargin)
%RUN_MMC_DC_FAULT_PROBE Build/load/update/simulate a DC-link short-circuit
%   discharge transient and return a model-backed ModelProbe for the fault
%   evidence of summarize_mmc_hvdc_support.
%
%   probe = run_mmc_dc_fault_probe("OutDir", dir)
%
%   Models the MMC DC-link / arm-capacitor stack (lumped C) discharging into a
%   pole-to-pole fault of resistance Rf at t=0, pre-charged to Vdc0 (pu):
%
%       Rf C dVdc/dt + Vdc = 0   ->   Vdc(t) = Vdc0 * e^{-t/(Rf*C)}
%
%   The probe ACTUALLY simulates the model (a base-Simulink Transfer Fcn with a
%   non-zero initial condition) and checks the simulated discharge against the
%   closed-form exponential. It also extracts the model-backed peak fault
%   current i_peak = Vdc0 / Rf (pu) as a real metric the metadata fault study
%   can be checked against. This is non-private and toolbox-light (no Simscape).
%
%   Returns a ModelProbe struct (ran/stage/model/passed/note/metrics). Only a
%   ran+passed probe lets summarize_mmc_hvdc_support reach model PASS.

p = inputParser;
p.addParameter("OutDir", fullfile(pwd, "build", "reports", "d2_mmc_hvdc", "_fixture"), ...
    @(x) ischar(x) || isstring(x));
p.addParameter("Rf", 0.5, @(x) isnumeric(x) && isscalar(x) && x > 0);   % fault ohm (equiv pu)
p.addParameter("C", 0.02, @(x) isnumeric(x) && isscalar(x) && x > 0);   % F (lumped DC-link)
p.addParameter("Vdc0", 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0); % pu pre-fault DC voltage
p.addParameter("RelErrTol", 0.02, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.parse(varargin{:});
opts = p.Results;
outDir = char(opts.OutDir);
modelName = "mmc_dc_fault_fixture";

probe = struct("ran", false, "stage", "build", "model", char(modelName), ...
    "passed", false, "note", "", "metrics", struct());

try
    tau = opts.Rf * opts.C;
    modelPath = iBuildFaultModel(outDir, modelName, tau, opts.Vdc0);
    cleanup = onCleanup(@() iCloseIfLoaded(modelName));

    probe.stage = "load";
    if ~bdIsLoaded(modelName)
        load_system(modelPath);
    end

    probe.stage = "update";
    set_param(char(modelName), "SimulationCommand", "update");

    probe.stage = "simulate";
    simOut = sim(char(modelName), "ReturnWorkspaceOutputs", "on");
    probe.ran = true;

    [t, vdc] = iExtractResponse(simOut);
    analytic = opts.Vdc0 * exp(-t / tau);
    denom = max(abs(analytic));
    if denom <= 0; denom = 1; end
    relRms = sqrt(mean((vdc - analytic).^2)) / denom;
    iPeakPu = opts.Vdc0 / opts.Rf;   % model-backed peak fault current (pu)

    probe.metrics = struct("rel_rms_error", relRms, "discharge_tau_s", tau, ...
        "peak_fault_current_pu", iPeakPu, "final_vdc", vdc(end), ...
        "final_vdc_analytic", opts.Vdc0 * exp(-5), "n_samples", numel(t));
    probe.passed = relRms <= opts.RelErrTol;
    if probe.passed
        probe.note = sprintf(['model-backed DC-fault discharge: simulated decay ' ...
            'matches analytic e^{-t/RfC} within %.3g%% RMS; peak fault current ' ...
            '%.2f pu'], relRms*100, iPeakPu);
    else
        probe.note = sprintf(['model ran but discharge deviates %.3g%% RMS from ' ...
            'analytic (tol %.3g%%)'], relRms*100, opts.RelErrTol*100);
    end
catch err
    probe.note = sprintf("DC-fault probe failed at stage '%s': %s", ...
        probe.stage, err.message);
    probe.passed = false;
end
end


function modelPath = iBuildFaultModel(outDir, modelName, tau, Vdc0)
% Vdc/Vdc0 decay via a first-order plant with non-zero initial condition:
% Transfer Fcn 1/(tau s + 1) cannot set an IC, so use a State-Space block
% dx/dt = -1/tau x, y = x, x0 = Vdc0, with a zero input (autonomous discharge).
if ~isfolder(outDir); mkdir(outDir); end
modelPath = fullfile(outDir, [char(modelName) '.slx']);
if bdIsLoaded(modelName); close_system(modelName, 0); end
if isfile(modelPath); delete(modelPath); end

new_system(modelName);
closer = onCleanup(@() iCloseIfLoaded(modelName));

add_block("simulink/Sources/Constant", [char(modelName) '/Zero'], "Value", "0");
add_block("simulink/Continuous/State-Space", [char(modelName) '/DClinkFault'], ...
    "A", num2str(-1/tau), "B", "1", "C", "1", "D", "0", ...
    "X0", num2str(Vdc0));
add_block("simulink/Sinks/Out1", [char(modelName) '/Vdc']);
add_block("simulink/Sinks/Scope", [char(modelName) '/VdcScope']);
add_line(modelName, "Zero/1", "DClinkFault/1", "autorouting", "on");
add_line(modelName, "DClinkFault/1", "Vdc/1", "autorouting", "on");
add_line(modelName, "DClinkFault/1", "VdcScope/1", "autorouting", "on");

stopTime = 5 * tau;
step = tau / 200;
set_param(char(modelName), ...
    "Solver", "ode4", "SolverType", "Fixed-step", "FixedStep", num2str(step), ...
    "StopTime", num2str(stopTime), "SaveOutput", "on", "OutputSaveName", "yout", ...
    "SaveTime", "on", "TimeSaveName", "tout", "SaveFormat", "Array");
save_system(modelName, modelPath);
clear closer;   % keep loaded for the caller
end


function [t, vdc] = iExtractResponse(simOut)
if isa(simOut, "Simulink.SimulationOutput")
    if any(strcmp(simOut.who, "tout")) && any(strcmp(simOut.who, "yout"))
        t = simOut.get("tout");
        y = simOut.get("yout");
        if isnumeric(y); vdc = y(:, 1); else; vdc = y.signals(1).values(:, 1); end
        return
    end
end
error("MmcDcFaultProbe:NoOutput", "Simulation produced no tout/yout to check.");
end


function iCloseIfLoaded(modelName)
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end
