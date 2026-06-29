function probe = run_mmc_dc_link_probe(varargin)
%RUN_MMC_DC_LINK_PROBE Build, load, update, and simulate the MMC DC-link fixture
%   and return a model-backed ModelProbe struct for summarize_mmc_hvdc_support.
%
%   probe = run_mmc_dc_link_probe("OutDir", dir)
%
%   This is the model-backed evidence path for the D2 package. It actually runs
%   a Simulink model (compile/update + simulate) and validates the simulated
%   DC-link charging response against the closed-form first-order solution
%   Vdc(t) = Vsrc (1 - e^{-t/RC}). The relative RMS error becomes the probe's
%   acceptance metric. The returned struct is consumed verbatim by
%   summarize_mmc_hvdc_support's "ModelProbe" option; only a ran+passed probe
%   sets model_validation_status = PASS.
%
%   Distinct from metadata consistency: this confirms the MODEL behaves as
%   physics predicts, not that the evidence struct is internally consistent.

p = inputParser;
p.addParameter("OutDir", fullfile(pwd, "build", "reports", "d2_mmc_hvdc", "_fixture"), ...
    @(x) ischar(x) || isstring(x));
p.addParameter("R", 5, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("C", 0.02, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("Vsrc", 1.0, @(x) isnumeric(x) && isscalar(x));
p.addParameter("RelErrTol", 0.02, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.parse(varargin{:});
opts = p.Results;
outDir = char(opts.OutDir);
modelName = "mmc_dc_link_fixture";

probe = struct("ran", false, "stage", "build", "model", char(modelName), ...
    "passed", false, "note", "", "metrics", struct());

try
    thisDir = fileparts(mfilename("fullpath"));
    addpath(thisDir);   % so build_mmc_dc_link_fixture is on path
    modelPath = build_mmc_dc_link_fixture("OutDir", outDir, "ModelName", modelName, ...
        "R", opts.R, "C", opts.C, "Vsrc", opts.Vsrc);
    cleanup = onCleanup(@() iCloseIfLoaded(modelName));

    % Stage 1: load.
    probe.stage = "load";
    if ~bdIsLoaded(modelName)
        load_system(modelPath);
    end

    % Stage 2: update (compile-time consistency).
    probe.stage = "update";
    set_param(char(modelName), "SimulationCommand", "update");

    % Stage 3: simulate.
    probe.stage = "simulate";
    simOut = sim(char(modelName), "ReturnWorkspaceOutputs", "on");
    probe.ran = true;

    [t, vdc] = iExtractResponse(simOut);
    RC = opts.R * opts.C;
    analytic = opts.Vsrc * (1 - exp(-t / RC));
    denom = max(abs(analytic));
    if denom <= 0; denom = 1; end
    relRms = sqrt(mean((vdc - analytic).^2)) / denom;
    finalVal = vdc(end);
    finalAnalytic = opts.Vsrc * (1 - exp(-5));   % at 5 tau

    probe.metrics = struct("rel_rms_error", relRms, ...
        "rc_time_constant_s", RC, "final_vdc", finalVal, ...
        "final_vdc_analytic", finalAnalytic, "n_samples", numel(t));
    probe.passed = relRms <= opts.RelErrTol;
    if probe.passed
        probe.note = sprintf(['model-backed DC-link probe: simulated response ' ...
            'matches analytic 1st-order within %.3g%% RMS (tol %.3g%%)'], ...
            relRms*100, opts.RelErrTol*100);
    else
        probe.note = sprintf(['model ran but simulated response deviates %.3g%% ' ...
            'RMS from analytic (tol %.3g%%)'], relRms*100, opts.RelErrTol*100);
    end
catch err
    probe.note = sprintf("model probe failed at stage '%s': %s", ...
        probe.stage, err.message);
    probe.passed = false;
end
end


function [t, vdc] = iExtractResponse(simOut)
% Robustly pull (time, Vdc) from the sim output regardless of logging format.
if isa(simOut, "Simulink.SimulationOutput")
    if any(strcmp(simOut.who, "tout")) && any(strcmp(simOut.who, "yout"))
        t = simOut.get("tout");
        y = simOut.get("yout");
        vdc = iFirstColumn(y);
        return
    end
end
error("MmcDcLinkProbe:NoOutput", "Simulation produced no tout/yout to check.");
end


function col = iFirstColumn(y)
if isnumeric(y)
    col = y(:, 1);
elseif isstruct(y) && isfield(y, "signals")
    col = y.signals(1).values(:, 1);
else
    error("MmcDcLinkProbe:BadOutputFormat", "Unrecognized yout format.");
end
end


function iCloseIfLoaded(modelName)
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end
