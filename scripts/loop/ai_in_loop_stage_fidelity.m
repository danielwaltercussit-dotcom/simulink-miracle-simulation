function s = ai_in_loop_stage_fidelity(projectRoot, modelName, specPath, iterDir, opt)
%AI_IN_LOOP_STAGE_FIDELITY  S0.25 model-fidelity decision artifact.
%   Writes fidelity_decision.md/json into the iteration directory and mirrors
%   the canonical report under build/reports/fidelity/.

s = struct('name','S0_25_FIDELITY','status','PASS', ...
    'model',char(modelName), 'report_path','', 'json_path','', ...
    'global_report_path','', 'global_json_path','');

analysisDir = fullfile(projectRoot, 'scripts', 'analysis');
if exist('write_model_fidelity_decision', 'file') ~= 2
    addpath(analysisDir);
end

modelName = char(modelName);
specPath = char(specPath);
studyObjective = char(opt.study_objective);
fidelity = char(opt.fidelity);
if strcmpi(fidelity, 'auto')
    fidelity = iInferFidelity(modelName, studyObjective);
end

[decisiveDynamics, includedDynamics, excludedDynamics, observables, route] = ...
    iInferDecisionContent(modelName, studyObjective, fidelity);

globalDir = fullfile(projectRoot, 'build', 'reports', 'fidelity');
decision = write_model_fidelity_decision( ...
    'CaseName', modelName, ...
    'StudyObjective', studyObjective, ...
    'Fidelity', fidelity, ...
    'DecisiveDynamics', decisiveDynamics, ...
    'IncludedDynamics', includedDynamics, ...
    'ExcludedDynamics', excludedDynamics, ...
    'RequiredObservables', observables, ...
    'ValidationRoute', route, ...
    'SourceModels', {specPath}, ...
    'OutputDir', globalDir);

s.global_report_path = decision.report_path;
s.global_json_path = decision.json_path;

s.report_path = fullfile(iterDir, 'fidelity_decision.md');
s.json_path = fullfile(iterDir, 'fidelity_decision.json');
copyfile(decision.report_path, s.report_path);
copyfile(decision.json_path, s.json_path);

s.fidelity = fidelity;
s.study_objective = studyObjective;
s.validation_route = route;
end


function fidelity = iInferFidelity(modelName, studyObjective)
txt = lower(string(modelName) + " " + string(studyObjective));
if any(contains(txt, ["protection","harmonic","switching","modulation"]))
    fidelity = 'switching_emt';
elseif any(contains(txt, ["modal","eigen","small-signal","small signal","damping"]))
    fidelity = 'small_signal_plus_time_domain';
elseif any(contains(txt, ["weak","scr","escr","pll","gfm","gfl","vsg","dfig","dc-link","fault"]))
    fidelity = 'averaged_emt_plus_modal';
elseif any(contains(txt, ["large system","screening","electromechanical","rms"]))
    fidelity = 'rms_positive_sequence_with_emt_spot_check';
else
    fidelity = 'averaged_emt';
end
end


function [decisiveDynamics, includedDynamics, excludedDynamics, observables, route] = ...
    iInferDecisionContent(modelName, studyObjective, fidelity)
txt = lower(string(modelName) + " " + string(studyObjective) + " " + string(fidelity));

decisiveDynamics = {'converter control dynamics', 'network voltage recovery'};
includedDynamics = {'averaged converter controls', 'network electrical dynamics'};
excludedDynamics = {'semiconductor switching details'};
observables = {'terminal voltage RMS', 'active power', 'reactive power', 'frequency'};
route = {'simulating-simulink-models', 'simulink-model-verification'};

if contains(txt, "dfig")
    decisiveDynamics = [decisiveDynamics, {'DFIG rotor speed', 'DC-link voltage'}];
    includedDynamics = [includedDynamics, {'DFIG current loops', 'rotor mechanical dynamics'}];
    observables = [observables, {'DC-link voltage', 'rotor speed'}];
end
if any(contains(txt, ["weak","scr","escr"]))
    decisiveDynamics = [decisiveDynamics, {'system strength sensitivity'}];
    route = [route, {'weak-grid-scr-scenario'}];
end
if any(contains(txt, ["pll","gfl","gfm","vsg"]))
    decisiveDynamics = [decisiveDynamics, {'PLL or grid-forming angle dynamics'}];
    includedDynamics = [includedDynamics, {'PLL/VSG outer-loop dynamics'}];
    route = [route, {'gfl-gfm-control-comparison'}];
end
if any(contains(txt, ["modal","damping","small_signal","small-signal"]))
    route = [route, {'small-signal-modal-analysis'}];
end
if contains(txt, "switching")
    excludedDynamics = {'none for switching-level waveform study'};
    includedDynamics = [includedDynamics, {'switching and modulation dynamics'}];
end

decisiveDynamics = unique(decisiveDynamics, 'stable');
includedDynamics = unique(includedDynamics, 'stable');
excludedDynamics = unique(excludedDynamics, 'stable');
observables = unique(observables, 'stable');
route = unique(route, 'stable');
end
