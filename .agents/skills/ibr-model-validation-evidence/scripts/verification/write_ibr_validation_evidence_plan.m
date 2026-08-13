function evidence = write_ibr_validation_evidence_plan(varargin)
%WRITE_IBR_VALIDATION_EVIDENCE_PLAN Write an IBR validation evidence checklist.

arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
sections = iBuildSections(opts);

evidence = struct();
evidence.case_name = char(opts.CaseName);
evidence.model_path = char(opts.ModelPath);
evidence.intended_use = char(opts.IntendedUse);
evidence.fidelity_decision = char(opts.FidelityDecision);
evidence.snapshot_path = char(opts.SnapshotPath);
evidence.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));
evidence.sections = sections;

outDir = char(opts.OutputDir);
if ~isfolder(outDir)
    mkdir(outDir);
end
jsonPath = fullfile(outDir, "ibr_validation_evidence.json");
mdPath = fullfile(outDir, "ibr_validation_evidence.md");
iWriteJson(jsonPath, evidence);
iWriteMarkdown(mdPath, evidence);
evidence.json_path = jsonPath;
evidence.report_path = mdPath;
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("CaseName", "ibr_case", @(x) ischar(x) || isstring(x));
p.addParameter("ModelPath", "", @(x) ischar(x) || isstring(x));
p.addParameter("IntendedUse", "study handoff", @(x) ischar(x) || isstring(x));
p.addParameter("FidelityDecision", "", @(x) ischar(x) || isstring(x));
p.addParameter("SnapshotPath", "", @(x) ischar(x) || isstring(x));
p.addParameter("SpecPath", "", @(x) ischar(x) || isstring(x));
p.addParameter("BuildScriptPath", "", @(x) ischar(x) || isstring(x));
p.addParameter("StatusPath", "", @(x) ischar(x) || isstring(x));
p.addParameter("SnapshotAuditPath", "", @(x) ischar(x) || isstring(x));
p.addParameter("AdapterContractPath", "", @(x) ischar(x) || isstring(x));
p.addParameter("ModelVerificationPath", "", @(x) ischar(x) || isstring(x));
p.addParameter("TuningReportPath", "", @(x) ischar(x) || isstring(x));
p.addParameter("SltestReportPath", "", @(x) ischar(x) || isstring(x));
p.addParameter("WeakGridEvidencePath", "", @(x) ischar(x) || isstring(x));
p.addParameter("RegressionEvidencePath", "", @(x) ischar(x) || isstring(x));
p.addParameter("Goal", "smoke", @(x) ischar(x) || isstring(x));
p.addParameter("StudyObjective", "", @(x) ischar(x) || isstring(x));
p.addParameter("LimitationsNote", "", @(x) ischar(x) || isstring(x));
p.addParameter("OutputDir", fullfile("build","reports","validation","ibr_case"), ...
    @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.CaseName = string(opts.CaseName);
opts.ModelPath = string(opts.ModelPath);
opts.IntendedUse = string(opts.IntendedUse);
opts.FidelityDecision = string(opts.FidelityDecision);
opts.SnapshotPath = string(opts.SnapshotPath);
opts.SpecPath = string(opts.SpecPath);
opts.BuildScriptPath = string(opts.BuildScriptPath);
opts.StatusPath = string(opts.StatusPath);
opts.SnapshotAuditPath = string(opts.SnapshotAuditPath);
opts.AdapterContractPath = string(opts.AdapterContractPath);
opts.ModelVerificationPath = string(opts.ModelVerificationPath);
opts.TuningReportPath = string(opts.TuningReportPath);
opts.SltestReportPath = string(opts.SltestReportPath);
opts.WeakGridEvidencePath = string(opts.WeakGridEvidencePath);
opts.RegressionEvidencePath = string(opts.RegressionEvidencePath);
opts.Goal = string(opts.Goal);
opts.StudyObjective = string(opts.StudyObjective);
opts.LimitationsNote = string(opts.LimitationsNote);
opts.OutputDir = string(opts.OutputDir);
end


function sections = iBuildSections(opts)
names = ["model identity and intended use", ...
    "source model and spec provenance", ...
    "parameter provenance", ...
    "controller mode and setting provenance", ...
    "fidelity decision", ...
    "initialization evidence", ...
    "small disturbance evidence", ...
    "large disturbance or fault recovery evidence", ...
    "weak-grid evidence if applicable", ...
    "regression or cross-fidelity comparison", ...
    "snapshot audit status", ...
    "limitations and excluded claims"];
sections = repmat(struct("name","","status","MISSING","note",""), 1, numel(names));
for k = 1:numel(names)
    sections(k).name = char(names(k));
    sections(k).note = "fill evidence path or mark N/A with reason";
end
if strlength(opts.ModelPath) > 0
    sections(1) = iEvidenceFromPath(sections(1), opts.ModelPath, "model file");
end
if strlength(opts.SpecPath) > 0
    sections(2) = iEvidenceFromPath(sections(2), opts.SpecPath, "spec file");
end
if strlength(opts.BuildScriptPath) > 0
    sections(3) = iEvidenceFromPath(sections(3), opts.BuildScriptPath, "build script and parameter source");
end
if strlength(opts.AdapterContractPath) > 0
    sections(4) = iEvidenceFromPath(sections(4), opts.AdapterContractPath, "adapter/controller contract");
end
if strlength(opts.FidelityDecision) > 0
    sections(5) = iEvidenceFromPath(sections(5), opts.FidelityDecision, "fidelity decision");
end
if strlength(opts.StatusPath) > 0 && isfile(opts.StatusPath)
    sections(6).status = "WARN";
    sections(6).note = char("compile/smoke status available: " + opts.StatusPath);
    try
        decoded = jsondecode(fileread(opts.StatusPath));
        if isfield(decoded, "update") && decoded.update && isfield(decoded, "smoke") && decoded.smoke
            sections(6).status = "PASS";
            sections(6).note = char("compile and smoke passed in " + opts.StatusPath);
            sections(7).status = "PASS";
            sections(7).note = char("smoke simulation passed in " + opts.StatusPath);
        end
    catch
        sections(6).status = "WARN";
        sections(6).note = char("status file exists but could not be parsed: " + opts.StatusPath);
    end
end
if any(strcmpi(opts.Goal, ["smoke","sltest"])) && strlength(opts.ModelVerificationPath) == 0
    sections(8).status = "N/A";
    sections(8).note = "not claimed by this smoke-level evidence package";
else
    sections(8) = iEvidenceFromPath(sections(8), opts.ModelVerificationPath, "large disturbance or verification report");
end
if strlength(opts.WeakGridEvidencePath) > 0
    sections(9) = iEvidenceFromPath(sections(9), opts.WeakGridEvidencePath, "weak-grid scenario evidence");
elseif contains(lower(opts.StudyObjective), "weak")
    sections(9).status = "WARN";
    sections(9).note = "weak-grid study objective named, but SCR/ESCR matrix evidence is not yet attached";
else
    sections(9).status = "N/A";
    sections(9).note = "weak-grid claim not requested for this evidence package";
end
if strlength(opts.RegressionEvidencePath) > 0
    sections(10) = iEvidenceFromPath(sections(10), opts.RegressionEvidencePath, "regression evidence");
else
    sections(10).status = "N/A";
    sections(10).note = "baseline or cross-fidelity comparison not requested for this smoke package";
end
if strlength(opts.SnapshotPath) > 0
    sections(11) = iEvidenceFromPath(sections(11), opts.SnapshotAuditPath, "snapshot audit");
    if strcmp(sections(11).status, "MISSING") && isfolder(opts.SnapshotPath)
        sections(11).status = "WARN";
        sections(11).note = char("snapshot folder exists but audit report is missing: " + opts.SnapshotPath);
    end
end
if strlength(opts.LimitationsNote) > 0
    sections(12).status = "PASS";
    sections(12).note = char(opts.LimitationsNote);
end
end


function section = iEvidenceFromPath(section, pathValue, notePrefix)
if strlength(pathValue) == 0
    return
end
if isfile(pathValue) || isfolder(pathValue)
    section.status = "PASS";
    section.note = char(notePrefix + ": " + pathValue);
else
    section.status = "MISSING";
    section.note = char("expected " + notePrefix + " not found: " + pathValue);
end
end


function iWriteJson(path, evidence)
fid = fopen(path, "w");
if fid < 0
    error("IBREvidence:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(evidence, "PrettyPrint", true));
end


function iWriteMarkdown(path, evidence)
fid = fopen(path, "w");
if fid < 0
    error("IBREvidence:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# IBR Model Validation Evidence\n\n");
fprintf(fid, "Case: `%s`\n", evidence.case_name);
fprintf(fid, "Model: `%s`\n", evidence.model_path);
fprintf(fid, "Intended use: %s\n", evidence.intended_use);
fprintf(fid, "Generated: %s\n\n", evidence.generated_at);
fprintf(fid, "| Section | Status | Note |\n");
fprintf(fid, "|---|---|---|\n");
for k = 1:numel(evidence.sections)
    s = evidence.sections(k);
    fprintf(fid, "| %s | %s | %s |\n", s.name, s.status, s.note);
end
end
