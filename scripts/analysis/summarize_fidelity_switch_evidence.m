function summary = summarize_fidelity_switch_evidence(varargin)
%SUMMARIZE_FIDELITY_SWITCH_EVIDENCE Summarize fidelity-switch equivalence evidence.
%   summary = summarize_fidelity_switch_evidence("CaseName","c1", ...
%       "FromFidelity","switching_emt","ToFidelity","averaged_emt", ...)
%
%   Records the equivalence evidence required before trusting a switch between
%   detailed-switching, averaged, dynamic-phasor, RMS, and phasor abstractions:
%   operating point, base values, retained bandwidth, loss treatment,
%   initialization mapping, acceptable error metric, and allowed time-step
%   ratio. Incomplete equivalence metadata is flagged provisional (never PASS)
%   so a fidelity switch cannot silently overclaim equivalence.
%
%   Two independent equivalence axes are reported and never conflated:
%     - documented_equivalence: is the equivalence CONTRACT fully and
%       self-consistently documented (operating point, base values, retained
%       bandwidth, losses, init mapping, error-metric TARGET, time-step ratio)?
%     - measured_equivalence: is there a REAL baseline-regression comparison -
%       an actual numeric error value vs a numeric bound, with compared run ids
%       and same-study artifact files that exist on disk?
%   A documented error-metric target alone is NOT measured equivalence and can
%   never yield a measured pass. Incomplete documentation is flagged provisional
%   so a fidelity switch can never silently overclaim equivalence.
%
%   This is a contract/evidence summarizer only: it does NOT build or run a
%   dynamic-phasor engine and does NOT itself simulate. It records and checks
%   the evidence of equivalence. Pure base-MATLAB; no Simulink/toolbox needed.
%
%   Artifacts:
%     build/reports/e2_fidelity_switching/<case>/fidelity_switch_summary.{md,json}

arguments (Repeating)
    varargin
end

opts = iParse(varargin{:});
outDir = char(opts.OutputDir);
if ~isfolder(outDir)
    mkdir(outDir);
end

summary = struct();
summary.case_name = char(opts.CaseName);
summary.study_objective = char(opts.StudyObjective);
summary.from_fidelity = char(opts.FromFidelity);
summary.to_fidelity = char(opts.ToFidelity);

[fromRank, fromKnown] = iFidelityRank(summary.from_fidelity);
[toRank, toKnown] = iFidelityRank(summary.to_fidelity);
summary.from_rank = fromRank;
summary.to_rank = toRank;
summary.direction = iDirection(fromRank, toRank);

% Equivalence-evidence fields (the contract).
summary.operating_point = char(opts.OperatingPoint);
summary.base_values = char(opts.BaseValues);
summary.bandwidth_retained_hz = double(opts.BandwidthRetainedHz);
summary.losses = char(opts.Losses);
summary.initialization_mapping = char(opts.InitializationMapping);
summary.error_metric = char(opts.ErrorMetric);
summary.time_step_ratio = double(opts.TimeStepRatio);

% Completeness check against the equivalence contract.
missing = {};
if ~iHasText(summary.operating_point);        missing{end+1} = 'operating_point'; end
if ~iHasText(summary.base_values);            missing{end+1} = 'base_values'; end
if ~iHasNum(summary.bandwidth_retained_hz);   missing{end+1} = 'bandwidth_retained_hz'; end
if ~iHasText(summary.losses);                 missing{end+1} = 'losses'; end
if ~iHasText(summary.initialization_mapping); missing{end+1} = 'initialization_mapping'; end
if ~iHasText(summary.error_metric);           missing{end+1} = 'error_metric'; end
if ~iHasNum(summary.time_step_ratio);         missing{end+1} = 'time_step_ratio'; end
summary.missing_required = missing;

warns = {};
if ~fromKnown
    warns{end+1} = sprintf('unknown from_fidelity "%s"', summary.from_fidelity);
end
if ~toKnown
    warns{end+1} = sprintf('unknown to_fidelity "%s"', summary.to_fidelity);
end

% Time-step-ratio direction consistency, checked only when the ratio is
% documented and both fidelities are recognized. ratio = target_dt/source_dt:
% coarsening (to lower fidelity) expects ratio>=1; refining expects ratio<=1.
summary.time_step_consistent = true;
if iHasNum(summary.time_step_ratio) && fromKnown && toKnown
    summary.time_step_consistent = ...
        iTimeStepConsistent(summary.direction, summary.time_step_ratio);
    if ~summary.time_step_consistent
        warns{end+1} = sprintf( ...
            'time_step_ratio=%.4g inconsistent with %s direction', ...
            summary.time_step_ratio, summary.direction);
    end
end
summary.warnings = warns;

% ---- Axis 1: documented equivalence (contract completeness) -------------
summary.documented_provisional = ~isempty(missing) || ~fromKnown || ~toKnown || ...
    ~summary.time_step_consistent;
if summary.documented_provisional
    summary.documented_status = 'provisional';
else
    summary.documented_status = 'pass';
end
% Back-compat aliases (the original contract names; unchanged semantics).
summary.provisional = summary.documented_provisional;
summary.status = summary.documented_status;

% ---- Axis 2: measured equivalence (real baseline-regression comparison) --
summary.measured_equivalence = iMeasuredEquivalence(opts);
summary.measured_status = summary.measured_equivalence.measured_status;

% ---- Combined overall status (never overclaims) -------------------------
summary.overall_status = iOverallStatus(summary.documented_status, summary.measured_status);

summary.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));

jsonPath = fullfile(outDir, "fidelity_switch_summary.json");
mdPath = fullfile(outDir, "fidelity_switch_summary.md");
iWriteJson(jsonPath, summary);
iWriteMarkdown(mdPath, summary);

summary.json_path = char(jsonPath);
summary.report_path = char(mdPath);
end

function opts = iParse(varargin)
p = inputParser;
isText = @(x) ischar(x) || isstring(x);
isScalarNum = @(x) isnumeric(x) && isscalar(x);
p.addParameter("CaseName", "fidelity_switch_case", isText);
p.addParameter("StudyObjective", "not specified", isText);
p.addParameter("FromFidelity", "unspecified", isText);
p.addParameter("ToFidelity", "unspecified", isText);
p.addParameter("OperatingPoint", "", isText);
p.addParameter("BaseValues", "", isText);
p.addParameter("BandwidthRetainedHz", NaN, isScalarNum);
p.addParameter("Losses", "", isText);
p.addParameter("InitializationMapping", "", isText);
p.addParameter("ErrorMetric", "", isText);
p.addParameter("TimeStepRatio", NaN, isScalarNum);
% --- Measured-equivalence (real baseline-regression) parameters ----------
p.addParameter("MeasuredErrorValue", NaN, isScalarNum);
p.addParameter("MeasuredErrorBound", NaN, isScalarNum);
p.addParameter("ErrorMetricDefinition", "", isText);
p.addParameter("ComparedFromRunId", "", isText);
p.addParameter("ComparedToRunId", "", isText);
p.addParameter("SameStudyArtifactPaths", strings(1,0), @(x) iscellstr(x) || isstring(x));
p.addParameter("SameStudyRoot", "", isText);
p.addParameter("OutputDir", fullfile("build","reports","e2_fidelity_switching","case"), isText);
p.parse(varargin{:});
opts = p.Results;
end


function tf = iHasText(s)
tf = ~isempty(strtrim(char(s)));
end


function tf = iHasNum(x)
tf = isnumeric(x) && isscalar(x) && ~isnan(x);
end


function [rank, known] = iFidelityRank(name)
% Higher rank = finer detail / faster dynamics retained.
key = lower(strtrim(char(name)));
switch key
    case {'switching_emt','switching','detailed','detailed_switching'}
        rank = 5; known = true;
    case {'averaged_emt','averaged','average','avg'}
        rank = 4; known = true;
    case {'dynamic_phasor','dynphasor','dynamic-phasor'}
        rank = 3; known = true;
    case {'rms','positive_sequence','positive-sequence'}
        rank = 2; known = true;
    case {'phasor','load_flow','loadflow'}
        rank = 1; known = true;
    otherwise
        rank = NaN; known = false;
end
end

function d = iDirection(fromRank, toRank)
if isnan(fromRank) || isnan(toRank)
    d = 'unknown';
elseif toRank < fromRank
    d = 'coarsen';   % toward lower fidelity (larger step expected)
elseif toRank > fromRank
    d = 'refine';    % toward higher fidelity (smaller step expected)
else
    d = 'same';
end
end


function tf = iTimeStepConsistent(direction, ratio)
% ratio = target_dt / source_dt.
if ~(isnumeric(ratio) && isscalar(ratio)) || ~(ratio > 0)
    tf = false;
    return
end
switch direction
    case 'coarsen'
        tf = ratio >= 1;
    case 'refine'
        tf = ratio <= 1;
    otherwise
        tf = true;   % 'same' or 'unknown': no direction constraint to enforce
end
end


function m = iMeasuredEquivalence(opts)
% Ingest a REAL baseline-regression comparison. A measured pass requires an
% actual numeric error <= numeric bound, a metric definition, both compared run
% ids, and same-study artifact files that exist on disk under the study root.
% A text error target alone can never reach 'pass' here.
m = struct();
m.error_value = double(opts.MeasuredErrorValue);
m.error_bound = double(opts.MeasuredErrorBound);
m.error_metric_definition = char(opts.ErrorMetricDefinition);
m.compared_from_run_id = char(opts.ComparedFromRunId);
m.compared_to_run_id = char(opts.ComparedToRunId);

paths = cellstr(string(opts.SameStudyArtifactPaths));
paths = paths(~cellfun(@(s) isempty(strtrim(s)), paths));
m.same_study_artifact_paths = paths;
m.same_study_root = char(opts.SameStudyRoot);

hasValue = iHasNum(m.error_value);
hasBound = iHasNum(m.error_bound);
hasDef = iHasText(m.error_metric_definition);
hasRuns = iHasText(m.compared_from_run_id) && iHasText(m.compared_to_run_id);
hasPaths = ~isempty(paths);

% Any measured-intent input at all? If none, this axis is simply absent.
anyInput = hasValue || hasBound || hasDef || hasRuns || hasPaths || ...
    iHasText(m.same_study_root);
if ~anyInput
    m.measured_status = 'not_provided';
    m.missing = {};
    m.artifacts_present = logical([]);
    m.artifacts_same_study = logical([]);
    m.within_bound = false;
    m.reason = 'no measured-equivalence inputs supplied';
    return
end

% Verify artifact files exist on disk and belong to the same study root.
[present, sameStudy] = iCheckArtifacts(paths, m.same_study_root);
m.artifacts_present = present;
m.artifacts_same_study = sameStudy;
allPresent = ~isempty(present) && all(present);
allSameStudy = ~isempty(sameStudy) && all(sameStudy);

missing = {};
if ~hasValue; missing{end+1} = 'measured_error_value'; end
if ~hasBound; missing{end+1} = 'measured_error_bound'; end
if ~hasDef;   missing{end+1} = 'error_metric_definition'; end
if ~hasRuns;  missing{end+1} = 'compared_run_ids'; end
if ~hasPaths; missing{end+1} = 'same_study_artifact_paths'; end
if hasPaths && ~allPresent;   missing{end+1} = 'artifact_files_present'; end
if hasPaths && ~allSameStudy; missing{end+1} = 'artifacts_same_study'; end
m.missing = missing;

m.within_bound = hasValue && hasBound && (m.error_value <= m.error_bound);

if ~isempty(missing)
    % Measured comparison was attempted but cannot be trusted/verified.
    m.measured_status = 'provisional';
    m.reason = sprintf('measured comparison incomplete/unverifiable: %s', ...
        strjoin(missing, ', '));
elseif m.within_bound
    m.measured_status = 'pass';
    m.reason = sprintf('measured error %.6g <= bound %.6g on verified same-study artifacts', ...
        m.error_value, m.error_bound);
else
    m.measured_status = 'fail';
    m.reason = sprintf('measured error %.6g > bound %.6g', ...
        m.error_value, m.error_bound);
end
end


function [present, sameStudy] = iCheckArtifacts(paths, studyRoot)
n = numel(paths);
present = false(1, n);
sameStudy = false(1, n);
rootCanon = iCanon(studyRoot);
for k = 1:n
    p = paths{k};
    present(k) = isfile(p) || isfolder(p);
    if isempty(rootCanon)
        % No study root given: cannot assert same-study membership.
        sameStudy(k) = false;
    else
        pc = iCanon(p);
        sameStudy(k) = ~isempty(pc) && startsWith(pc, rootCanon);
    end
end
end


function c = iCanon(p)
% Canonicalize a path for prefix comparison: lower-case, forward slashes,
% no trailing slash. Pure string-level (no disk dependency) so it works for
% not-yet-existing paths too.
s = strtrim(char(p));
if isempty(s)
    c = '';
    return
end
s = strrep(s, '\', '/');
s = regexprep(s, '/+$', '');
c = lower(s);
end


function s = iOverallStatus(documentedStatus, measuredStatus)
% Combine the two axes WITHOUT overclaiming. Measured pass is the only state
% that asserts model-backed equivalence, and it requires documented pass too.
switch measuredStatus
    case 'pass'
        if strcmp(documentedStatus, 'pass')
            s = 'measured_pass';
        else
            % Numbers agree but the contract is not fully documented.
            s = 'provisional';
        end
    case 'fail'
        s = 'measured_fail';
    case 'provisional'
        s = 'provisional';
    otherwise   % 'not_provided'
        if strcmp(documentedStatus, 'pass')
            s = 'documented_pass';
        else
            s = 'provisional';
        end
end
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("FidelitySwitch:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("FidelitySwitch:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Fidelity Switch Equivalence Evidence\n\n");
fprintf(fid, "Case: `%s`\n", summary.case_name);
fprintf(fid, "Study objective: %s\n", summary.study_objective);
fprintf(fid, "Switch: `%s` -> `%s` (%s)\n", ...
    summary.from_fidelity, summary.to_fidelity, summary.direction);
fprintf(fid, "Overall status: **%s**\n", upper(summary.overall_status));
fprintf(fid, "- documented_equivalence: **%s**\n", upper(summary.documented_status));
fprintf(fid, "- measured_equivalence: **%s**\n", upper(summary.measured_status));
fprintf(fid, "Generated: %s\n\n", summary.generated_at);

if summary.documented_provisional
    fprintf(fid, "> PROVISIONAL (documented): equivalence is not fully documented. ");
    fprintf(fid, "Do not treat the two fidelities as interchangeable yet.\n\n");
end
if ~strcmp(summary.measured_status, 'measured_pass') && ...
        ~strcmp(summary.overall_status, 'measured_pass')
    fprintf(fid, "> NOTE: this is NOT model-backed numerical equivalence. ");
    fprintf(fid, "A documented error target is not a measured comparison.\n\n");
end

fprintf(fid, "## Equivalence Evidence\n\n");
fprintf(fid, "| Field | Value |\n|---|---|\n");
fprintf(fid, "| operating_point | %s |\n", iCell(summary.operating_point));
fprintf(fid, "| base_values | %s |\n", iCell(summary.base_values));
fprintf(fid, "| bandwidth_retained_hz | %s |\n", iNumCell(summary.bandwidth_retained_hz));
fprintf(fid, "| losses | %s |\n", iCell(summary.losses));
fprintf(fid, "| initialization_mapping | %s |\n", iCell(summary.initialization_mapping));
fprintf(fid, "| error_metric | %s |\n", iCell(summary.error_metric));
fprintf(fid, "| time_step_ratio | %s |\n\n", iNumCell(summary.time_step_ratio));

iWriteMeasured(fid, summary.measured_equivalence);

iWriteList(fid, "Missing Required (documented)", summary.missing_required);
iWriteList(fid, "Warnings", summary.warnings);
end


function iWriteMeasured(fid, m)
fprintf(fid, "## Measured Equivalence (baseline-regression)\n\n");
fprintf(fid, "Status: **%s**\n\n", upper(m.measured_status));
if strcmp(m.measured_status, 'not_provided')
    fprintf(fid, "- no measured comparison supplied (documented target only)\n\n");
    return
end
fprintf(fid, "| Field | Value |\n|---|---|\n");
fprintf(fid, "| measured_error_value | %s |\n", iNumCell(m.error_value));
fprintf(fid, "| measured_error_bound | %s |\n", iNumCell(m.error_bound));
fprintf(fid, "| within_bound | %d |\n", m.within_bound);
fprintf(fid, "| error_metric_definition | %s |\n", iCell(m.error_metric_definition));
fprintf(fid, "| compared_from_run_id | %s |\n", iCell(m.compared_from_run_id));
fprintf(fid, "| compared_to_run_id | %s |\n", iCell(m.compared_to_run_id));
fprintf(fid, "| same_study_root | %s |\n", iCell(m.same_study_root));
fprintf(fid, "| artifacts (present/same-study) | %d/%d of %d |\n\n", ...
    sum(m.artifacts_present), sum(m.artifacts_same_study), numel(m.artifacts_present));
if ~isempty(m.same_study_artifact_paths)
    fprintf(fid, "Same-study artifacts:\n\n");
    for k = 1:numel(m.same_study_artifact_paths)
        fprintf(fid, "- %s\n", m.same_study_artifact_paths{k});
    end
    fprintf(fid, "\n");
end
if ~isempty(m.missing)
    iWriteList(fid, "Missing Required (measured)", m.missing);
end
fprintf(fid, "Reason: %s\n\n", m.reason);
end


function iWriteList(fid, titleText, values)
fprintf(fid, "## %s\n\n", titleText);
if isempty(values)
    fprintf(fid, "- none\n\n");
    return
end
for k = 1:numel(values)
    fprintf(fid, "- %s\n", values{k});
end
fprintf(fid, "\n");
end


function s = iCell(value)
v = strtrim(char(value));
if isempty(v)
    s = '(undocumented)';
else
    s = v;
end
end


function s = iNumCell(value)
if isnumeric(value) && isscalar(value) && ~isnan(value)
    s = sprintf('%g', value);
else
    s = '(undocumented)';
end
end

