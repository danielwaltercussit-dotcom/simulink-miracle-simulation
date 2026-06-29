function report = compare_vsc_gfl_gfm_completeness(caseA, caseB, varargin)
%COMPARE_VSC_GFL_GFM_COMPLETENESS Check a GFL/GFM pair is a complete, fair comparison.
%
%   report = compare_vsc_gfl_gfm_completeness(caseA, caseB, ...
%       "SharedAxes", ["network","dispatch","disturbance","observables"], ...
%       "OutputDir", dir)
%
%   A GFL-vs-GFM comparison is only trustworthy when (1) the two cases really
%   are one GFL and one GFM device, (2) each case is individually complete
%   (documented identity, control-mode consistent, no MISSING required
%   evidence), and (3) the cases share the fairness axes that must be held
%   constant: same network, dispatch, disturbance, and observable list, unless
%   a difference is explicitly justified. This checker reports completeness; it
%   does NOT run either model and does NOT decide which control wins.
%
%   caseA, caseB: VSC case descriptors (same shape consumed by
%   summarize_vsc_gfl_gfm_support). Each may carry a `comparison_axes` struct
%   with fields network / dispatch / disturbance / observables and an optional
%   `justified_differences` cellstr naming axes allowed to differ.
%
%   The report records, per requirement, a PASS/MISSING-style check and an
%   overall `comparison_complete` flag. A complete comparison is the
%   precondition for routing to gfl-gfm-control-comparison; it is not itself a
%   performance verdict.
%
%   See .agents/skills/device-pack-vsc-gfl-gfm/references/vsc-support-contract.md

arguments
    caseA struct
    caseB struct
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});

sA = summarize_vsc_gfl_gfm_support(caseA);
sB = summarize_vsc_gfl_gfm_support(caseB);

checks = iEmptyCheckArray();
[checks, modeOk] = iCheckModeCoverage(checks, sA, sB);
checks = iCheckCaseComplete(checks, "A", sA);
checks = iCheckCaseComplete(checks, "B", sB);
[checks, axesOk] = iCheckSharedAxes(checks, caseA, caseB, opts.SharedAxes);

complete = all([checks.passed]);

report = struct();
report.case_a = sA.case_name;
report.case_b = sB.case_name;
report.mode_a = sA.control_mode;
report.mode_b = sB.control_mode;
report.generated_at = sA.generated_at;
report.shared_axes = cellstr(opts.SharedAxes(:)');
report.checks = checks;
report.mode_coverage_ok = modeOk;
report.shared_axes_ok = axesOk;
report.case_a_handoff_ready = sA.handoff_ready;
report.case_b_handoff_ready = sB.handoff_ready;
report.comparison_complete = complete;
report.support_a = sA;
report.support_b = sB;

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, report);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("SharedAxes", ["network", "dispatch", "disturbance", "observables"], ...
    @(x) ischar(x) || isstring(x) || iscellstr(x));
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.SharedAxes = string(opts.SharedAxes);
opts.OutputDir = string(opts.OutputDir);
end


function [checks, ok] = iCheckModeCoverage(checks, sA, sB)
% The pair must be exactly one GFL and one GFM (grid_support does not make a
% GFL-vs-GFM comparison).
modes = sort(string({sA.control_mode, sB.control_mode}));
ok = isequal(modes, ["GFL", "GFM"]);
if ok
    detail = "pair covers one GFL and one GFM device";
else
    detail = char("pair must be one GFL + one GFM; got [" + ...
        string(sA.control_mode) + ", " + string(sB.control_mode) + "]");
end
checks = iAddCheck(checks, "mode_coverage", ok, detail);
end


function checks = iCheckCaseComplete(checks, label, s)
% Each case must be individually handoff-ready: documented identity,
% control-mode consistent, and no MISSING required dimension. Reuse the
% support helper's own handoff_ready verdict so the policy stays in one place.
ok = s.handoff_ready;
if ok
    detail = char("case " + label + " (" + string(s.case_name) + ") is complete");
else
    reasons = strings(1, 0);
    if s.provisional; reasons(end+1) = "provisional"; end
    if ~s.consistency.consistent; reasons(end+1) = "mode-inconsistent"; end
    if s.status_counts.MISSING > 0
        reasons(end+1) = sprintf("%d MISSING", s.status_counts.MISSING);
    end
    if isempty(reasons); reasons = "required artifact not PASS"; end
    detail = char("case " + label + " incomplete: " + strjoin(reasons, ", "));
end
checks = iAddCheck(checks, char("case_" + lower(string(label)) + "_complete"), ok, detail);
end


function [checks, ok] = iCheckSharedAxes(checks, caseA, caseB, sharedAxes)
% Each named fairness axis must be present and equal across the two cases,
% unless BOTH cases explicitly list that axis in justified_differences.
axA = iAxes(caseA);
axB = iAxes(caseB);
justified = intersect(iJustified(caseA), iJustified(caseB));
ok = true;
for k = 1:numel(sharedAxes)
    axis = sharedAxes(k);
    if any(strcmpi(axis, justified))
        checks = iAddCheck(checks, char("axis_" + axis), true, ...
            char(axis + ": difference explicitly justified in both cases"));
        continue
    end
    [present, equal, va, vb] = iAxisMatch(axA, axB, axis);
    pass = present && equal;
    ok = ok && pass;
    if ~present
        detail = char(axis + ": missing in one or both cases");
    elseif ~equal
        detail = char(axis + ": differs (A=" + va + " vs B=" + vb + ...
            ") without justification");
    else
        detail = char(axis + ": shared (" + va + ")");
    end
    checks = iAddCheck(checks, char("axis_" + axis), pass, detail);
end
end


function ax = iAxes(c)
if isfield(c, "comparison_axes") && isstruct(c.comparison_axes)
    ax = c.comparison_axes;
else
    ax = struct();
end
end


function j = iJustified(c)
j = strings(1, 0);
if isfield(c, "justified_differences")
    v = c.justified_differences;
    if iscellstr(v) || isstring(v)
        j = string(v(:)');
    end
end
end


function [present, equal, va, vb] = iAxisMatch(axA, axB, axis)
axis = char(axis);
hasA = isfield(axA, axis) && iNonEmpty(axA.(axis));
hasB = isfield(axB, axis) && iNonEmpty(axB.(axis));
present = hasA && hasB;
va = "<unset>"; vb = "<unset>";
if hasA; va = iScalarText(axA.(axis)); end
if hasB; vb = iScalarText(axB.(axis)); end
equal = present && strcmp(va, vb);
end


function tf = iNonEmpty(v)
if ischar(v) || isstring(v)
    tf = strlength(strtrim(string(v))) > 0;
else
    tf = ~isempty(v);
end
end


function s = iScalarText(v)
if ischar(v) || isstring(v)
    s = string(v);
    s = strjoin(s(:)', "|");
elseif isnumeric(v) || islogical(v)
    s = strjoin(string(v(:)'), ",");
else
    s = "<complex>";
end
end


function checks = iAddCheck(checks, name, passed, detail)
c = struct("name", char(name), "passed", logical(passed), "detail", char(detail));
if isempty(checks)
    checks = c;
else
    checks(end+1) = c;
end
end


function arr = iEmptyCheckArray()
arr = struct("name", "", "passed", false, "detail", "");
arr = arr([]);
end


function iWriteOutputs(outDir, report)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "vsc_gfl_gfm_comparison_completeness.json"), report);
iWriteMarkdown(fullfile(outDir, "vsc_gfl_gfm_comparison_completeness.md"), report);
end


function iWriteJson(path, report)
fid = fopen(path, "w");
if fid < 0
    error("VscCompare:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(report, "PrettyPrint", true));
end


function iWriteMarkdown(path, report)
fid = fopen(path, "w");
if fid < 0
    error("VscCompare:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "# VSC GFL/GFM Comparison Completeness\n\n");
fprintf(fid, "Case A: `%s` (%s) | Case B: `%s` (%s)\n", ...
    report.case_a, report.mode_a, report.case_b, report.mode_b);
fprintf(fid, "Generated: %s\n\n", report.generated_at);
fprintf(fid, "comparison_complete: **%d** | mode_coverage_ok=%d shared_axes_ok=%d\n", ...
    report.comparison_complete, report.mode_coverage_ok, report.shared_axes_ok);
fprintf(fid, "case_a_handoff_ready=%d case_b_handoff_ready=%d\n\n", ...
    report.case_a_handoff_ready, report.case_b_handoff_ready);

fprintf(fid, "## Completeness checks\n\n");
fprintf(fid, "| Check | Pass | Detail |\n");
fprintf(fid, "|---|---|---|\n");
for k = 1:numel(report.checks)
    c = report.checks(k);
    fprintf(fid, "| %s | %d | %s |\n", c.name, c.passed, c.detail);
end
fprintf(fid, "\n");

fprintf(fid, "## Note\n\n");
fprintf(fid, ['Completeness is the precondition for a fair GFL-vs-GFM study, ' ...
    'not a performance verdict. A complete pair may be routed to ' ...
    'gfl-gfm-control-comparison; this checker runs no model and does not decide ' ...
    'which control performs better.\n']);
end
