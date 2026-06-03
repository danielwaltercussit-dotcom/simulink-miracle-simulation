function s = ai_in_loop_stage_build(projectRoot, buildFcn, modelName, forceRebuild, specAbs)
%AI_IN_LOOP_STAGE_BUILD  Run the project build script for the target model.
s = struct('name','S2_BUILD','status','PASS','model',char(modelName));
modelPath = fullfile(projectRoot,'build','generated_models', strcat(char(modelName), ".slx"));
buildPath = fullfile(projectRoot,'scripts', strcat(char(buildFcn), ".m"));

if nargin < 5
    specAbs = '';
end

needsRebuild = forceRebuild || ~isfile(modelPath);
if isfile(modelPath) && ~needsRebuild
    modelInfo = dir(modelPath);
    newestInput = 0;
    if isfile(buildPath)
        bi = dir(buildPath);
        newestInput = max(newestInput, bi.datenum);
    end
    if ~isempty(specAbs) && isfile(specAbs)
        si = dir(specAbs);
        newestInput = max(newestInput, si.datenum);
    end
    if modelInfo.datenum < newestInput
        needsRebuild = true;
    end
end

if isfile(modelPath) && ~needsRebuild
    if ~bdIsLoaded(char(modelName))
        load_system(modelPath);
    end
    [adapter, adapterReportPath] = run_adapter_contract(projectRoot, modelName);
    s.adapter_report_path = adapterReportPath;
    s.adapter_checks = adapter.checks;
    s.note = 'reused existing model; model is newer than build script and spec';
    return
end
addpath(fullfile(projectRoot,'scripts'));
fh = str2func(char(buildFcn));
try
    fh('Force', true);
catch ME
    if contains(ME.message, 'Too many input') || contains(ME.message, 'TooManyInputs') || ...
            strcmp(ME.identifier, 'MATLAB:TooManyInputs')
        if isfile(modelPath)
            delete(modelPath);
        end
        fh();
    else
        rethrow(ME);
    end
end
if ~isfile(modelPath)
    error('AIInLoop:BuildArtifactMissing','Build did not produce %s', modelPath);
end
if ~bdIsLoaded(char(modelName))
    load_system(modelPath);
end
[adapter, adapterReportPath] = run_adapter_contract(projectRoot, modelName);
s.adapter_report_path = adapterReportPath;
s.adapter_checks = adapter.checks;
s.note = 'rebuilt model from build script';
end

function [adapter, adapterReportPath] = run_adapter_contract(projectRoot, modelName)
adapterReportPath = fullfile(projectRoot, 'build', 'reports', 'adapters', [char(modelName) '.md']);
addpath(fullfile(projectRoot, 'scripts', 'adapters'));
adapter = inspect_device_adapter_contract(char(modelName), ...
    'ProjectRoot', projectRoot, ...
    'ReportPath', adapterReportPath);
if ~adapter.passed
    error('AIInLoop:AdapterContractFail', 'Adapter contract failed: %s', adapter.message);
end
end
