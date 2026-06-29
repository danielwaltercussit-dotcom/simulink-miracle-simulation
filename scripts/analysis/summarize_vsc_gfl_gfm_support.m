function summary = summarize_vsc_gfl_gfm_support(descriptor, varargin)
%SUMMARIZE_VSC_GFL_GFM_SUPPORT Summarize VSC (GFL/GFM) device support evidence.
%
%   summary = summarize_vsc_gfl_gfm_support(descriptor, "OutputDir", dir)
%
%   This helper is CONTRACT-ONLY. It intakes a VSC case descriptor (a struct of
%   declared assumptions and evidence-artifact pointers) and produces a
%   structured support summary that records, per evidence dimension, a status
%   of PASS / WARN / MISSING / N/A, plus a GFL/GFM control-mode consistency
%   screen. It does NOT run a Simulink model and does NOT claim hardware-level
%   validation. Its PASS only means the requested assumption is documented or
%   the named evidence artifact pointer is present and same-study; it never
%   proves a physical result by itself.
%
%   Descriptor fields (all optional; missing -> treated as undocumented):
%     case_name        char/string. Case label.
%     control_mode     "GFL" | "GFM" | "grid_support". Converter sync paradigm.
%     evidence_source  "measured" | "simulated" | "analytic" | "synthetic" |
%                      "planned". Provenance of the evidence behind the case.
%     operating_point  char/string. Dispatch / load level the case is taken at.
%     base_values      struct: .s_base_mva .v_base_kv .f_base_hz (any subset).
%     grid_strength    struct: .scr .escr .method (e.g. "thevenin_L").
%     synchronization  struct: .type ("pll"|"vsg"|"droop"|"voc"|"vsm") .note
%     active_power_control   struct: .mode (e.g. "p_setpoint"|"f_droop") .note
%     reactive_power_control struct: .mode (e.g. "q_setpoint"|"v_droop"|
%                            "pf"|"v_forming") .note
%     fault_ride_through     struct: .case ("none"|"three_phase"|"slg"|...)
%                            .artifact (path) .note
%     modal_evidence         struct: .artifact (path) .required (logical)
%     impedance_evidence     struct: .artifact (path) .required (logical)
%     time_domain_validation struct: .artifact (path) .required (logical)
%
%   Status rules (see references/vsc-support-contract.md):
%     assumption dimensions (mode/grid/sync/P/Q): PASS if documented, MISSING if
%       required and undocumented, N/A if not required for the mode.
%     artifact dimensions (FRT/modal/impedance/time-domain): PASS if a pointer
%       is present (and, when a path is given, the file exists), WARN if present
%       but provisional/indirect, MISSING if required and absent, N/A otherwise.
%     provisional: true when control_mode, grid_strength, base_values, or
%       operating_point is undocumented. While provisional, every artifact PASS
%       is downgraded to WARN so a draft case cannot overclaim validation.
%
%   See .agents/skills/device-pack-vsc-gfl-gfm/references/vsc-support-contract.md

arguments
    descriptor struct
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
d = iNormalizeDescriptor(descriptor);

prov = iProvisional(d);

dims = iEvaluateDimensions(d, prov.provisional);
consistency = iConsistencyScreen(d);

summary = struct();
summary.case_name = char(d.case_name);
summary.control_mode = char(d.control_mode);
summary.evidence_source = char(d.evidence_source);
summary.operating_point = char(d.operating_point);
summary.base_values = d.base_values;
summary.generated_at = char(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss"));
summary.provisional = prov.provisional;
summary.missing_documentation = prov.missing;
summary.dimensions = dims;
summary.consistency = consistency;
summary.status_counts = iCountStatuses(dims);
summary.handoff_ready = iHandoffReady(dims, consistency, prov.provisional);
summary.limitations = char(opts.LimitationsNote);
summary.excluded_claims = iExcludedClaims();

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, summary);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("LimitationsNote", ...
    ['Contract-level support summary from declared assumptions and evidence ' ...
     'pointers; not a Simulink run and not hardware-validated. PASS means the ' ...
     'assumption is documented or the artifact pointer is present and ' ...
     'same-study, not that a physical result is proven.'], ...
    @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.OutputDir = string(opts.OutputDir);
opts.LimitationsNote = string(opts.LimitationsNote);
end


function d = iNormalizeDescriptor(descriptor)
d = descriptor;
d.case_name = iCharField(descriptor, "case_name", "vsc_case");
d.control_mode = iModeField(descriptor);
d.evidence_source = lower(iCharField(descriptor, "evidence_source", "synthetic"));
d.operating_point = iCharField(descriptor, "operating_point", "");
if ~isfield(d, "base_values") || ~isstruct(d.base_values)
    d.base_values = struct();
end
d.grid_strength = iSubStruct(descriptor, "grid_strength");
d.synchronization = iSubStruct(descriptor, "synchronization");
d.active_power_control = iSubStruct(descriptor, "active_power_control");
d.reactive_power_control = iSubStruct(descriptor, "reactive_power_control");
d.fault_ride_through = iSubStruct(descriptor, "fault_ride_through");
d.modal_evidence = iSubStruct(descriptor, "modal_evidence");
d.impedance_evidence = iSubStruct(descriptor, "impedance_evidence");
d.time_domain_validation = iSubStruct(descriptor, "time_domain_validation");
end


function v = iCharField(s, name, defaultVal)
if isfield(s, name) && (ischar(s.(name)) || isstring(s.(name))) && ...
        strlength(string(s.(name))) > 0
    v = char(string(s.(name)));
else
    v = char(defaultVal);
end
end


function m = iModeField(s)
m = "";
if isfield(s, "control_mode") && (ischar(s.control_mode) || isstring(s.control_mode))
    m = upper(strtrim(string(s.control_mode)));
end
switch m
    case {"GFL", "GFM", "GRID_SUPPORT"}
        m = char(m);
    otherwise
        m = "";  % undocumented / unrecognized
end
m = char(m);
end


function sub = iSubStruct(s, name)
if isfield(s, name) && isstruct(s.(name))
    sub = s.(name);
else
    sub = struct();
end
end


function prov = iProvisional(d)
% A case is provisional until its identity is pinned: control mode,
% operating point, grid strength, and at least one base value.
missing = strings(1, 0);
if isempty(d.control_mode)
    missing(end+1) = "control_mode";
end
if isempty(strtrim(d.operating_point))
    missing(end+1) = "operating_point";
end
if ~iHasGridStrength(d.grid_strength)
    missing(end+1) = "grid_strength";
end
if ~iHasAnyBaseValue(d.base_values)
    missing(end+1) = "base_values";
end
prov = struct();
prov.missing = cellstr(missing);
prov.provisional = ~isempty(missing);
end


function tf = iHasGridStrength(gs)
tf = (isfield(gs, "scr") && isnumeric(gs.scr) && isscalar(gs.scr) && isfinite(gs.scr)) ...
    || (isfield(gs, "escr") && isnumeric(gs.escr) && isscalar(gs.escr) && isfinite(gs.escr));
end


function tf = iHasAnyBaseValue(bv)
tf = false;
if ~isstruct(bv)
    return
end
fn = fieldnames(bv);
for k = 1:numel(fn)
    v = bv.(fn{k});
    if isnumeric(v) && isscalar(v) && isfinite(v) && v > 0
        tf = true;
        return
    end
end
end


function dims = iEvaluateDimensions(d, provisional)
dims = struct([]);
dims = iAppendDim(dims, iDimControlMode(d));
dims = iAppendDim(dims, iDimGridStrength(d));
dims = iAppendDim(dims, iDimSynchronization(d));
dims = iAppendDim(dims, iDimActivePower(d));
dims = iAppendDim(dims, iDimReactivePower(d));
dims = iAppendDim(dims, iDimArtifact(d, "fault_ride_through", "fault_ride_through", true));
dims = iAppendDim(dims, iDimArtifact(d, "modal_evidence", "modal_evidence", false));
dims = iAppendDim(dims, iDimArtifact(d, "impedance_evidence", "impedance_evidence", false));
dims = iAppendDim(dims, iDimArtifact(d, "time_domain_validation", "time_domain_validation", true));
if provisional
    dims = iDowngradeArtifactPass(dims);
end
end


function dims = iAppendDim(dims, dim)
if isempty(dims)
    dims = dim;
else
    dims(end+1) = dim;
end
end


function dim = iMakeDim(name, status, detail)
dim = struct("name", char(name), "status", char(status), "detail", char(detail), ...
    "is_artifact", false, "required", false);
end


function dim = iDimControlMode(d)
if isempty(d.control_mode)
    dim = iMakeDim("control_mode", "MISSING", ...
        "control_mode undocumented; declare GFL, GFM, or grid_support");
else
    dim = iMakeDim("control_mode", "PASS", ...
        sprintf("control_mode = %s", d.control_mode));
end
end


function dim = iDimGridStrength(d)
gs = d.grid_strength;
if iHasGridStrength(gs)
    method = iCharField(gs, "method", "unspecified_method");
    parts = strings(1, 0);
    if isfield(gs, "scr") && isnumeric(gs.scr) && isscalar(gs.scr)
        parts(end+1) = sprintf("SCR=%.3g", gs.scr);
    end
    if isfield(gs, "escr") && isnumeric(gs.escr) && isscalar(gs.escr)
        parts(end+1) = sprintf("ESCR=%.3g", gs.escr);
    end
    dim = iMakeDim("grid_strength", "PASS", ...
        sprintf("%s (%s)", strjoin(cellstr(parts), ", "), method));
else
    dim = iMakeDim("grid_strength", "MISSING", ...
        "no SCR/ESCR documented; weak-grid claims need a strength value");
end
end


function dim = iDimSynchronization(d)
sy = d.synchronization;
typ = lower(iCharField(sy, "type", ""));
if isempty(typ)
    dim = iMakeDim("synchronization", "MISSING", ...
        "synchronization type undocumented (pll/vsg/droop/voc/vsm)");
    return
end
dim = iMakeDim("synchronization", "PASS", sprintf("sync = %s", typ));
end


function dim = iDimActivePower(d)
ap = d.active_power_control;
mode = iCharField(ap, "mode", "");
if isempty(mode)
    dim = iMakeDim("active_power_control", "MISSING", ...
        "active-power control mode undocumented");
else
    dim = iMakeDim("active_power_control", "PASS", sprintf("P-control = %s", mode));
end
end


function dim = iDimReactivePower(d)
rp = d.reactive_power_control;
mode = iCharField(rp, "mode", "");
if isempty(mode)
    dim = iMakeDim("reactive_power_control", "MISSING", ...
        "reactive-power control mode undocumented");
else
    dim = iMakeDim("reactive_power_control", "PASS", sprintf("Q-control = %s", mode));
end
end


function dim = iDimArtifact(d, field, displayName, requiredDefault)
% Artifact dimensions point at an evidence file. PASS when a pointer is
% present and (if a path is given) the file exists; WARN when present but
% flagged provisional/indirect; MISSING when required and absent; N/A when
% not required for this case.
art = d.(field);
required = requiredDefault;
if isfield(art, "required") && islogical(art.required) && isscalar(art.required)
    required = art.required;
end
artifactPath = iCharField(art, "artifact", "");
note = iCharField(art, "note", "");
hasPointer = ~isempty(artifactPath) || (isfield(art, "case") && ...
    ~isempty(iCharField(art, "case", "")) && ~strcmpi(iCharField(art, "case", ""), "none"));

dim = iMakeDim(displayName, "N/A", "not required for this case");
dim.is_artifact = true;
dim.required = required;

if ~hasPointer
    if required
        dim.status = "MISSING";
        dim.detail = "required evidence artifact absent";
    else
        dim.status = "N/A";
        dim.detail = "no artifact requested";
    end
    return
end

% Pointer present. If a file path was supplied, it must exist on disk.
if ~isempty(artifactPath) && ~isfile(artifactPath)
    dim.status = "MISSING";
    dim.detail = sprintf("artifact path supplied but file absent: %s", artifactPath);
    return
end

indirect = (isfield(art, "provisional") && islogical(art.provisional) && art.provisional) ...
    || (isfield(art, "indirect") && islogical(art.indirect) && art.indirect);
hasFile = ~isempty(artifactPath);  % path supplied and (checked above) exists on disk

if indirect
    dim.status = "WARN";
    dim.detail = iJoinDetail("artifact present but flagged provisional/indirect", note);
elseif hasFile
    dim.status = "PASS";
    dim.detail = iJoinDetail(iArtifactDesc(art, artifactPath), note);
else
    % Only a label/intent (e.g. a fault case name) with no artifact file: the
    % intent is declared but not yet evidenced. WARN, not PASS -- a label is
    % not evidence, so this pack must not present it as validation-grade.
    dim.status = "WARN";
    dim.detail = iJoinDetail(sprintf("%s; intent declared, artifact file pending", ...
        iArtifactDesc(art, artifactPath)), note);
end
end


function s = iArtifactDesc(art, artifactPath)
if ~isempty(artifactPath)
    s = sprintf("artifact: %s", artifactPath);
elseif isfield(art, "case")
    s = sprintf("case: %s", iCharField(art, "case", ""));
else
    s = "artifact pointer present";
end
end


function s = iJoinDetail(base, note)
if isempty(note)
    s = base;
else
    s = sprintf("%s (%s)", base, note);
end
end


function dims = iDowngradeArtifactPass(dims)
% While the case is provisional, no artifact dimension may read PASS: a draft
% case must not present validation-grade evidence. PASS -> WARN.
for k = 1:numel(dims)
    if dims(k).is_artifact && strcmp(dims(k).status, "PASS")
        dims(k).status = "WARN";
        dims(k).detail = sprintf("%s [downgraded: case provisional]", dims(k).detail);
    end
end
end


function consistency = iConsistencyScreen(d)
% Catch declared control assumptions that contradict the stated mode. These
% are not hard errors (a study may intentionally explore a hybrid), but a
% contradiction must be surfaced rather than silently accepted.
issues = strings(1, 0);
mode = d.control_mode;
syncType = iCharField(d.synchronization, "type", "");

if strcmp(mode, "GFL") && any(strcmpi(syncType, ["vsg", "droop", "voc", "vsm"]))
    issues(end+1) = sprintf(...
        "mode=GFL but synchronization=%s is a grid-forming paradigm", syncType);
end
if strcmp(mode, "GFM") && strcmpi(syncType, "pll")
    issues(end+1) = ...
        "mode=GFM but synchronization=pll; grid-forming usually self-synchronizes";
end

qMode = iCharField(d.reactive_power_control, "mode", "");
if strcmp(mode, "GFM") && strcmpi(qMode, "q_setpoint")
    issues(end+1) = ...
        "mode=GFM with fixed q_setpoint; grid-forming typically regulates voltage";
end

consistency = struct();
consistency.consistent = isempty(issues);
consistency.issues = cellstr(issues);
end


function counts = iCountStatuses(dims)
counts = struct("PASS", 0, "WARN", 0, "MISSING", 0, "NA", 0);
for k = 1:numel(dims)
    switch dims(k).status
        case "PASS";    counts.PASS = counts.PASS + 1;
        case "WARN";    counts.WARN = counts.WARN + 1;
        case "MISSING"; counts.MISSING = counts.MISSING + 1;
        otherwise;      counts.NA = counts.NA + 1;
    end
end
end


function tf = iHandoffReady(dims, consistency, provisional)
% Handoff-ready requires: not provisional, no MISSING dimension, and no
% unresolved control-mode consistency issue.
if provisional || ~consistency.consistent
    tf = false;
    return
end
tf = true;
for k = 1:numel(dims)
    if strcmp(dims(k).status, "MISSING")
        tf = false;
        return
    end
    % A required artifact that is only WARN (intent-only, indirect, or
    % provisionally downgraded) is not validation-grade evidence, so it
    % cannot clear the handoff bar even though it is not MISSING.
    if dims(k).is_artifact && dims(k).required && ~strcmp(dims(k).status, "PASS")
        tf = false;
        return
    end
end
end


function claims = iExcludedClaims()
claims = { ...
    'No Simulink/Simscape model was executed by this helper.'; ...
    'No hardware-in-the-loop or real-time validation is implied.'; ...
    'A PASS records documentation/pointer presence, not a proven physical result.'; ...
    ['Stability, fault-ride-through, and weak-grid claims still need the named ' ...
     'time-domain (EMT/RMS) and, where applicable, modal/impedance evidence.']};
end


function iWriteOutputs(outDir, summary)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "vsc_gfl_gfm_support.json"), summary);
iWriteMarkdown(fullfile(outDir, "vsc_gfl_gfm_support.md"), summary);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("VscSupport:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("VscSupport:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "# VSC / GFL-GFM Support Summary\n\n");
if summary.provisional
    fprintf(fid, "> **PROVISIONAL** - case identity is undocumented; ");
    fprintf(fid, "artifact PASS is downgraded to WARN. Missing: %s\n\n", ...
        iJoinCell(summary.missing_documentation));
end
fprintf(fid, "Case: `%s`\n", summary.case_name);
fprintf(fid, "Control mode: %s | Evidence source: %s\n", ...
    iDisp(summary.control_mode), summary.evidence_source);
fprintf(fid, "Operating point: %s\n", iDisp(summary.operating_point));
fprintf(fid, "Generated: %s\n\n", summary.generated_at);

c = summary.status_counts;
fprintf(fid, "Status counts: PASS=%d WARN=%d MISSING=%d N/A=%d | handoff_ready=%d\n\n", ...
    c.PASS, c.WARN, c.MISSING, c.NA, summary.handoff_ready);

fprintf(fid, "## Evidence dimensions\n\n");
fprintf(fid, "| Dimension | Status | Detail |\n");
fprintf(fid, "|---|---|---|\n");
for k = 1:numel(summary.dimensions)
    dim = summary.dimensions(k);
    fprintf(fid, "| %s | %s | %s |\n", dim.name, dim.status, dim.detail);
end
fprintf(fid, "\n");

fprintf(fid, "## Control-mode consistency\n\n");
if summary.consistency.consistent
    fprintf(fid, "- consistent: declared control assumptions match the stated mode\n\n");
else
    for k = 1:numel(summary.consistency.issues)
        fprintf(fid, "- WARN: %s\n", summary.consistency.issues{k});
    end
    fprintf(fid, "\n");
end

fprintf(fid, "## Excluded claims\n\n");
for k = 1:numel(summary.excluded_claims)
    fprintf(fid, "- %s\n", summary.excluded_claims{k});
end
fprintf(fid, "\n## Limitations\n\n%s\n", summary.limitations);
end


function s = iDisp(v)
if isempty(v) || (ischar(v) && isempty(strtrim(v)))
    s = "_(undocumented)_";
else
    s = v;
end
end


function s = iJoinCell(c)
if isempty(c)
    s = "(none)";
else
    s = strjoin(c, ", ");
end
end
