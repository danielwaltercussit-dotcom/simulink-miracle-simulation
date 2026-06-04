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
p.addParameter("OutputDir", fullfile("build","reports","validation","ibr_case"), ...
    @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.CaseName = string(opts.CaseName);
opts.ModelPath = string(opts.ModelPath);
opts.IntendedUse = string(opts.IntendedUse);
opts.FidelityDecision = string(opts.FidelityDecision);
opts.SnapshotPath = string(opts.SnapshotPath);
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
    sections(1).status = "WARN";
    sections(1).note = char(opts.ModelPath);
end
if strlength(opts.FidelityDecision) > 0
    sections(5).status = "WARN";
    sections(5).note = char(opts.FidelityDecision);
end
if strlength(opts.SnapshotPath) > 0
    sections(11).status = "WARN";
    sections(11).note = char(opts.SnapshotPath);
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
