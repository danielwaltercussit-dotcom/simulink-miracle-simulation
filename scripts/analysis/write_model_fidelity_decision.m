function decision = write_model_fidelity_decision(varargin)
%WRITE_MODEL_FIDELITY_DECISION Write a model-fidelity decision report.
%
% decision = write_model_fidelity_decision("CaseName","case1", ...)

arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
outDir = char(opts.OutputDir);
if ~isfolder(outDir)
    mkdir(outDir);
end

decision = struct();
decision.case_name = char(opts.CaseName);
decision.study_objective = char(opts.StudyObjective);
decision.fidelity = char(opts.Fidelity);
decision.decisive_dynamics = cellstr(opts.DecisiveDynamics);
decision.included_dynamics = cellstr(opts.IncludedDynamics);
decision.excluded_dynamics = cellstr(opts.ExcludedDynamics);
decision.required_observables = cellstr(opts.RequiredObservables);
decision.validation_route = cellstr(opts.ValidationRoute);
decision.source_models = cellstr(opts.SourceModels);
decision.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));

jsonPath = fullfile(outDir, sprintf("%s_fidelity_decision.json", opts.CaseName));
mdPath = fullfile(outDir, sprintf("%s_fidelity_decision.md", opts.CaseName));

iWriteJson(jsonPath, decision);
iWriteMarkdown(mdPath, decision);

decision.json_path = jsonPath;
decision.report_path = mdPath;
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("CaseName", "fidelity_case", @(x) ischar(x) || isstring(x));
p.addParameter("StudyObjective", "not specified", @(x) ischar(x) || isstring(x));
p.addParameter("Fidelity", "undecided", @(x) ischar(x) || isstring(x));
p.addParameter("DecisiveDynamics", strings(1,0), @(x) iscellstr(x) || isstring(x));
p.addParameter("IncludedDynamics", strings(1,0), @(x) iscellstr(x) || isstring(x));
p.addParameter("ExcludedDynamics", strings(1,0), @(x) iscellstr(x) || isstring(x));
p.addParameter("RequiredObservables", strings(1,0), @(x) iscellstr(x) || isstring(x));
p.addParameter("ValidationRoute", strings(1,0), @(x) iscellstr(x) || isstring(x));
p.addParameter("SourceModels", strings(1,0), @(x) iscellstr(x) || isstring(x));
p.addParameter("OutputDir", fullfile("build","reports","fidelity"), @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.CaseName = string(opts.CaseName);
opts.OutputDir = string(opts.OutputDir);
opts.DecisiveDynamics = string(opts.DecisiveDynamics);
opts.IncludedDynamics = string(opts.IncludedDynamics);
opts.ExcludedDynamics = string(opts.ExcludedDynamics);
opts.RequiredObservables = string(opts.RequiredObservables);
opts.ValidationRoute = string(opts.ValidationRoute);
opts.SourceModels = string(opts.SourceModels);
end


function iWriteJson(path, decision)
fid = fopen(path, "w");
if fid < 0
    error("FidelityDecision:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(decision, "PrettyPrint", true));
end


function iWriteMarkdown(path, decision)
fid = fopen(path, "w");
if fid < 0
    error("FidelityDecision:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Model Fidelity Decision\n\n");
fprintf(fid, "Case: `%s`\n", decision.case_name);
fprintf(fid, "Study objective: %s\n", decision.study_objective);
fprintf(fid, "Selected fidelity: `%s`\n", decision.fidelity);
fprintf(fid, "Generated: %s\n\n", decision.generated_at);
iWriteList(fid, "Decisive Dynamics", decision.decisive_dynamics);
iWriteList(fid, "Included Dynamics", decision.included_dynamics);
iWriteList(fid, "Excluded Dynamics", decision.excluded_dynamics);
iWriteList(fid, "Required Observables", decision.required_observables);
iWriteList(fid, "Validation Route", decision.validation_route);
iWriteList(fid, "Source Models", decision.source_models);
end


function iWriteList(fid, titleText, values)
fprintf(fid, "## %s\n\n", titleText);
if isempty(values)
    fprintf(fid, "- not specified\n\n");
    return
end
for k = 1:numel(values)
    fprintf(fid, "- %s\n", values{k});
end
fprintf(fid, "\n");
end

