function result = ai_in_loop_functional_model_test(modelName, tStop, reportPath)
%AI_IN_LOOP_FUNCTIONAL_MODEL_TEST Persistent fallback tests for AI-in-loop models.
%   Used when Simulink Test .mldatx harnesses are unavailable. This keeps S7
%   as a real pass/fail gate by checking compile, smoke simulation, and finite
%   logged outputs.

try
    if nargin < 3
        reportPath = '';
    end
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(projectRoot, 'scripts', 'verification'));
    addpath(fullfile(projectRoot, 'scripts', 'loop'));
    result = verify_power_system_model(modelName, ...
        'ProjectRoot', projectRoot, ...
        'StopTime', tStop, ...
        'ReportPath', reportPath, ...
        'RequireOutputs', true);
catch ME
    result = struct('passed', false, 'message', '', 'sim_time', tStop, 'checks', struct());
    result.message = ME.message;
end
end
