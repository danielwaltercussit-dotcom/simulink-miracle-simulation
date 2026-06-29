function modelPath = build_mmc_dc_link_fixture(varargin)
%BUILD_MMC_DC_LINK_FIXTURE Programmatically build a tiny, non-private MMC DC-link
%   energy-balance fixture model for model-backed D2 evidence.
%
%   modelPath = build_mmc_dc_link_fixture("OutDir", dir, "ModelName", name)
%
%   The model is a first-order DC-link / arm-capacitor charging circuit built
%   from base Simulink blocks (no Simscape, no toolbox-specific blocks, so it
%   loads on a base Simulink install). It represents the lumped arm-capacitor
%   energy store of an MMC DC bus charging through the equivalent arm/charging
%   resistance:
%
%       C dVdc/dt = (Vsrc - Vdc) / R      ->   Vdc(t) = Vsrc (1 - e^{-t/RC})
%
%   This is NOT a full MMC. It is the smallest runnable model whose closed-form
%   response lets a probe CHECK a simulated result against analytic physics, so
%   the D2 package can carry genuine model-backed evidence (separate from
%   metadata consistency) without any private/lab model.
%
%   The model is generated under a gitignored build dir and is NOT committed;
%   only this builder script is version-controlled. Returns the .slx path.

p = inputParser;
p.addParameter("OutDir", fullfile(pwd, "build", "reports", "d2_mmc_hvdc", "_fixture"), ...
    @(x) ischar(x) || isstring(x));
p.addParameter("ModelName", "mmc_dc_link_fixture", @(x) ischar(x) || isstring(x));
p.addParameter("R", 5, @(x) isnumeric(x) && isscalar(x) && x > 0);   % ohm (equiv)
p.addParameter("C", 0.02, @(x) isnumeric(x) && isscalar(x) && x > 0); % F (lumped arm)
p.addParameter("Vsrc", 1.0, @(x) isnumeric(x) && isscalar(x));        % pu DC source
p.parse(varargin{:});
opts = p.Results;
outDir = char(opts.OutDir);
modelName = char(opts.ModelName);

if ~isfolder(outDir)
    mkdir(outDir);
end
modelPath = fullfile(outDir, [modelName '.slx']);

% Start from a clean slate so repeated runs are deterministic.
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if isfile(modelPath)
    delete(modelPath);
end

new_system(modelName);
cleanupModel = onCleanup(@() iCloseIfLoaded(modelName));

% RC time constant is stored in the model workspace so the probe can read it.
RC = opts.R * opts.C;
iAddBlocks(modelName, opts, RC);
iWireBlocks(modelName);
iConfigureSolver(modelName, RC);

save_system(modelName, modelPath);
clear cleanupModel;   % keep model loaded for the caller/probe
end


function iAddBlocks(modelName, opts, RC)
% First-order plant Vdc/Vsrc = 1/(RC s + 1) as a Transfer Fcn, driven by a
% Step from 0 to Vsrc, logged through an Outport.
add_block("simulink/Sources/Step", [modelName '/Vsrc'], ...
    "Time", "0", "Before", "0", "After", num2str(opts.Vsrc));
add_block("simulink/Continuous/Transfer Fcn", [modelName '/DClink'], ...
    "Numerator", "[1]", "Denominator", ['[' num2str(RC) ' 1]']);
add_block("simulink/Sinks/Out1", [modelName '/Vdc']);
add_block("simulink/Sinks/Scope", [modelName '/VdcScope']);
end


function iWireBlocks(modelName)
add_line(modelName, "Vsrc/1", "DClink/1", "autorouting", "on");
add_line(modelName, "DClink/1", "Vdc/1", "autorouting", "on");
add_line(modelName, "DClink/1", "VdcScope/1", "autorouting", "on");
end


function iConfigureSolver(modelName, RC)
% Simulate ~5 time constants so the cap reaches >99% of Vsrc; fixed-step so the
% probe comparison is deterministic across machines.
stopTime = 5 * RC;
step = RC / 200;
set_param(modelName, ...
    "Solver", "ode4", ...
    "SolverType", "Fixed-step", ...
    "FixedStep", num2str(step), ...
    "StopTime", num2str(stopTime), ...
    "SaveOutput", "on", ...
    "OutputSaveName", "yout", ...
    "SaveTime", "on", ...
    "TimeSaveName", "tout", ...
    "SaveFormat", "Array");
end


function iCloseIfLoaded(modelName)
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end
