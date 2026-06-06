function summary = compose_vsc_gfl_gfm_evidence(descriptor, currentIterationDir, varargin)
%COMPOSE_VSC_GFL_GFM_EVIDENCE Same-iteration VSC evidence composer.
%
%   summary = compose_vsc_gfl_gfm_evidence(descriptor, currentIterationDir, ...
%       "WeakGridScrPath",p1, "ModalPath",p2, "ImpedancePath",p3, ...
%       "TimeDomainPath",p4, "OutputDir",dir)
%
%   This composer takes a VSC case descriptor plus the paths of evidence
%   artifacts produced ELSEWHERE (weak-grid SCR/ESCR matrix, modal summary,
%   impedance summary, and time-domain EMT/RMS run) and assembles a single VSC
%   support summary, but it accepts an artifact ONLY when that artifact lives
%   under the current iteration directory. A file from a previous/other
%   iteration is rejected as STALE so a prior run's evidence cannot silently
%   back the current case.
%
%   Staleness rule (mirrors the P4-A same-iteration defense):
%     an artifact path is same-iteration iff its canonical absolute path is
%     equal to, or a child of, the canonical current iteration directory. The
%     child test uses a trailing separator so a sibling like `iter2` does not
%     false-match `iter`.
%
%   Per artifact the composer assigns:
%     used     file exists AND is same-iteration            -> feeds the helper
%     stale    file exists but lives under another iteration -> rejected
%     missing  a path was supplied but the file is absent    -> rejected
%     not_set  no path supplied                              -> N/A downstream
%
%   It then calls summarize_vsc_gfl_gfm_support with ONLY the used artifacts,
%   so the underlying PASS/WARN/MISSING/N/A + provisional + consistency logic
%   is reused unchanged. Rejected artifacts never reach the helper, so a stale
%   file cannot produce a PASS.
%
%   This composer runs NO Simulink model. A used artifact is same-study
%   bookkeeping, not a model-backed or hardware-backed proof of the artifact's
%   own claim.
%
%   See .agents/skills/device-pack-vsc-gfl-gfm/references/vsc-support-contract.md

arguments
    descriptor struct
    currentIterationDir {mustBeTextScalar}
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
canonIter = iCanonical(currentIterationDir);

artifactSpecs = { ...
    "weak_grid_scr",          opts.WeakGridScrPath,  "grid_strength_evidence"; ...
    "modal_evidence",         opts.ModalPath,        "modal_evidence"; ...
    "impedance_evidence",     opts.ImpedancePath,    "impedance_evidence"; ...
    "time_domain_validation", opts.TimeDomainPath,   "time_domain_validation"};

intake = iEmptyIntakeArray();
d = descriptor;
for k = 1:size(artifactSpecs, 1)
    name = artifactSpecs{k, 1};
    pathValue = artifactSpecs{k, 2};
    descField = artifactSpecs{k, 3};
    rec = iClassifyArtifact(name, pathValue, canonIter);
    intake(end+1) = rec; %#ok<AGROW>
    if rec.status == "used"
        d = iAttachArtifact(d, descField, rec.path);
    end
end

% The composed descriptor only carries same-iteration artifacts. Everything
% else is left as the caller declared it (assumptions, required flags).
support = summarize_vsc_gfl_gfm_support(d);

summary = struct();
summary.case_name = support.case_name;
summary.current_iteration_dir = char(canonIter);
summary.generated_at = support.generated_at;
summary.intake = intake;
summary.n_used = nnz([intake.status] == "used");
summary.n_stale = nnz([intake.status] == "stale");
summary.n_missing = nnz([intake.status] == "missing");
summary.support = support;
summary.handoff_ready = support.handoff_ready;
summary.has_stale_rejected = summary.n_stale > 0;

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, summary);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("WeakGridScrPath", "", @(x) ischar(x) || isstring(x));
p.addParameter("ModalPath", "", @(x) ischar(x) || isstring(x));
p.addParameter("ImpedancePath", "", @(x) ischar(x) || isstring(x));
p.addParameter("TimeDomainPath", "", @(x) ischar(x) || isstring(x));
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.WeakGridScrPath = string(opts.WeakGridScrPath);
opts.ModalPath = string(opts.ModalPath);
opts.ImpedancePath = string(opts.ImpedancePath);
opts.TimeDomainPath = string(opts.TimeDomainPath);
opts.OutputDir = string(opts.OutputDir);
end


function rec = iClassifyArtifact(name, pathValue, canonIter)
% Classify a single artifact path against the current iteration directory.
rec = iEmptyIntake();
rec.name = char(name);
pathValue = string(pathValue);

if strlength(strtrim(pathValue)) == 0
    rec.status = "not_set";
    rec.detail = "no path supplied";
    return
end

rec.path = char(pathValue);
if ~isfile(pathValue)
    rec.status = "missing";
    rec.detail = char("path supplied but file absent: " + pathValue);
    return
end

canonArtifact = iCanonical(pathValue);
if iIsSameIteration(canonArtifact, canonIter)
    rec.status = "used";
    rec.detail = char("same-iteration artifact accepted: " + canonArtifact);
else
    rec.status = "stale";
    rec.detail = char("rejected: artifact is outside the current iteration dir (" ...
        + canonArtifact + ")");
end
end


function tf = iIsSameIteration(canonArtifact, canonIter)
% Same-iteration iff the artifact equals the iteration dir or is a child of
% it. The child test appends a separator so a sibling like `iter2` does not
% false-match `iter` (a naive startsWith prefix test would).
if strcmp(canonArtifact, canonIter)
    tf = true;
    return
end
prefix = [canonIter iSep()];
tf = startsWith(canonArtifact, prefix);
end


function c = iCanonical(p)
% Canonical absolute path: collapses '.', '..', and normalizes separators and
% (on Windows) case. Falls back to the raw text if Java is unavailable.
p = char(string(p));
try
    c = char(java.io.File(p).getCanonicalPath());
catch
    c = p;
end
end


function s = iSep()
if ispc
    s = '\';
else
    s = '/';
end
end


function d = iAttachArtifact(d, descField, artifactPath)
% Attach a same-iteration artifact path to the descriptor field consumed by
% summarize_vsc_gfl_gfm_support, preserving any caller-set required/case/note.
if isfield(d, descField) && isstruct(d.(descField))
    sub = d.(descField);
else
    sub = struct();
end
sub.artifact = char(artifactPath);
d.(descField) = sub;
end


function rec = iEmptyIntake()
rec = struct("name", "", "status", "", "path", "", "detail", "");
end


function arr = iEmptyIntakeArray()
arr = iEmptyIntake();
arr = arr([]);
end


function iWriteOutputs(outDir, summary)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "vsc_evidence_composition.json"), summary);
iWriteMarkdown(fullfile(outDir, "vsc_evidence_composition.md"), summary);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("VscCompose:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("VscCompose:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "# VSC / GFL-GFM Same-Iteration Evidence Composition\n\n");
fprintf(fid, "Case: `%s`\n", summary.case_name);
fprintf(fid, "Current iteration dir: `%s`\n", summary.current_iteration_dir);
fprintf(fid, "Generated: %s\n\n", summary.generated_at);
fprintf(fid, "Intake: used=%d stale_rejected=%d missing=%d | handoff_ready=%d\n\n", ...
    summary.n_used, summary.n_stale, summary.n_missing, summary.handoff_ready);

if summary.has_stale_rejected
    fprintf(fid, "> **STALE EVIDENCE REJECTED** - one or more artifacts live ");
    fprintf(fid, "outside the current iteration dir and were NOT used.\n\n");
end

fprintf(fid, "## Artifact intake\n\n");
fprintf(fid, "| Artifact | Status | Detail |\n");
fprintf(fid, "|---|---|---|\n");
for k = 1:numel(summary.intake)
    r = summary.intake(k);
    fprintf(fid, "| %s | %s | %s |\n", r.name, r.status, r.detail);
end
fprintf(fid, "\n");

fprintf(fid, "## Composed support dimensions\n\n");
fprintf(fid, "| Dimension | Status | Detail |\n");
fprintf(fid, "|---|---|---|\n");
for k = 1:numel(summary.support.dimensions)
    dim = summary.support.dimensions(k);
    fprintf(fid, "| %s | %s | %s |\n", dim.name, dim.status, dim.detail);
end
fprintf(fid, "\n");

fprintf(fid, "## Note\n\n");
fprintf(fid, ['Same-iteration acceptance is bookkeeping that an artifact belongs ' ...
    'to this study iteration; it is not a model-backed or hardware-backed proof ' ...
    'of the artifact''s own claim. Stale and missing artifacts are rejected ' ...
    'before reaching the support helper, so they cannot produce a PASS.\n']);
end
