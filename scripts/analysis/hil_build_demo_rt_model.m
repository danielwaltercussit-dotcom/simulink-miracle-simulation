function info = hil_build_demo_rt_model(variant, outDir)
%HIL_BUILD_DEMO_RT_MODEL Build a tiny synthetic model for M2 model-backed tests.
%
%   info = hil_build_demo_rt_model(variant, outDir)
%
%   Builds a small, fully synthetic Simulink model programmatically so the M2
%   model-backed adapter has a real model to load/update/simulate. NOTHING is
%   copied from NEBUS39V2.slx or the lab archive; every block is added by name
%   from the base Simulink library. The model is saved under outDir (which must
%   be inside the gitignored build/ tree) so no .slx ever enters the repo.
%
%   variant:
%     "rt"    fixed-step discrete, two rates (20us / 100us), 0 continuous
%             states -> a real-time-friendly model.
%     "nonrt" variable-step solver with a continuous Integrator -> deliberately
%             NOT real-time deployable, for the negative test case.
%
%   info fields: model (name), path (.slx), variant.

arguments
    variant (1,1) string {mustBeMember(variant, ["rt","nonrt"])} = "rt"
    outDir (1,1) string = ""
end

if strlength(outDir) == 0
    outDir = fullfile("build","reports","m2_hil_readiness","models");
end
if ~isfolder(outDir)
    mkdir(outDir);
end

mdl = char("hil_demo_" + variant);
if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
new_system(mdl);
load_system(mdl);

if variant == "rt"
    iBuildRt(mdl);
else
    iBuildNonRt(mdl);
end

modelPath = char(fullfile(outDir, mdl + ".slx"));
save_system(mdl, modelPath);
close_system(mdl, 0);

info = struct("model", mdl, "path", modelPath, "variant", char(variant));
end


function iBuildRt(mdl)
% Fixed-step discrete, two sample rates, no continuous states.
set_param(mdl, "SolverType", "Fixed-step", "Solver", "FixedStepDiscrete", ...
    "FixedStep", "20e-6", "StopTime", "1e-3", "SaveOutput", "off");
add_block("built-in/Sin",       [mdl '/Src'], "SampleTime", "20e-6");
add_block("built-in/UnitDelay", [mdl '/Ctrl'], "SampleTime", "100e-6");
add_block("built-in/Gain",      [mdl '/K'], "Gain", "0.5");
add_block("built-in/Outport",   [mdl '/y']);
add_line(mdl, "Src/1", "Ctrl/1");
add_line(mdl, "Ctrl/1", "K/1");
add_line(mdl, "K/1", "y/1");
end


function iBuildNonRt(mdl)
% Variable-step solver + a continuous Integrator: not RT-deployable as-is.
set_param(mdl, "SolverType", "Variable-step", "Solver", "ode45", ...
    "StopTime", "1e-3", "SaveOutput", "off");
add_block("built-in/Sin",        [mdl '/Src']);
add_block("built-in/Integrator", [mdl '/Int']);
add_block("built-in/Outport",    [mdl '/y']);
add_line(mdl, "Src/1", "Int/1");
add_line(mdl, "Int/1", "y/1");
end
