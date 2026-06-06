function summary = summarize_storage_bms_support(descriptor, varargin)
%SUMMARIZE_STORAGE_BMS_SUPPORT Summarize storage/battery/BMS device support.
%
%   summary = summarize_storage_bms_support(descriptor, "OutputDir", dir)
%
%   This helper is CONTRACT-ONLY. It intakes a battery-storage case descriptor
%   (declared assumptions and evidence-artifact pointers) and produces a
%   structured support summary that records, per evidence dimension, a status of
%   PASS / WARN / MISSING / N/A, plus a battery-vs-DC-link separation screen. It
%   does NOT run a Simulink model and does NOT claim hardware-level validation.
%   A PASS means the assumption is documented or the named artifact pointer is
%   present and same-study; it never proves SOC accuracy, thermal safety, or a
%   physical result by itself.
%
%   Defining discipline: battery/BMS evidence is kept separate from generic
%   DC-link converter evidence. A constant-DC-source converter run is a DC-link
%   study, not a battery study; if battery_evidence is required and absent it
%   reads MISSING even when DC-link evidence is present.
%
%   Descriptor fields (all optional; missing -> treated as undocumented):
%     case_name          char/string. Case label.
%     battery_model      char/string. Cell/pack model type, e.g.
%                        "equivalent_circuit_2RC". "constant_dc_source" or
%                        "none" is treated as undocumented battery identity.
%     evidence_source    "measured"|"simulated"|"analytic"|"synthetic"|
%                        "planned". Provenance of the evidence.
%     grid_support_mode  "peak_shaving"|"frequency_response"|"pcs_volt_var"|
%                        "black_start"|"arbitrage"|"none".
%     rated_energy_kwh   numeric scalar. Rated energy.
%     rated_power_kw     numeric scalar. Rated power.
%     soc_soh            struct: .soc_window ([min max]) .soh (scalar).
%     thermal            struct: .limit_c (scalar) .model (char).
%     protection         struct: .ov .uv .oc .ot .ut .soc_cutoff (logical-ish).
%     battery_evidence   struct: .artifact (path) .required (logical)
%                        .provisional/.indirect (logical).
%     dc_link            struct: .artifact (path) .required (logical) ...
%     modal_evidence     struct: .artifact (path) .required (logical) ...
%     impedance_evidence struct: .artifact (path) .required (logical) ...
%     time_domain_validation struct: .artifact (path) .required (logical) ...
%
%   See .agents/skills/device-pack-storage-bms/references/
%       storage-bms-support-contract.md

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
separation = iSeparationScreen(d);
batteryProven = iBatteryLayerProven(d, dims, prov.provisional);

summary = struct();
summary.case_name = char(d.case_name);
summary.battery_model = char(d.battery_model);
summary.evidence_source = char(d.evidence_source);
summary.grid_support_mode = char(d.grid_support_mode);
summary.rated_energy_kwh = d.rated_energy_kwh;
summary.rated_power_kw = d.rated_power_kw;
summary.generated_at = char(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss"));
summary.provisional = prov.provisional;
summary.missing_documentation = prov.missing;
summary.dimensions = dims;
summary.separation = separation;
summary.battery_layer_proven = batteryProven;
summary.status_counts = iCountStatuses(dims);
summary.handoff_ready = iHandoffReady(dims, separation, batteryProven, ...
    prov.provisional);
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
     'same-study, not that a physical result is proven. Battery/BMS evidence ' ...
     'is kept separate from generic DC-link converter evidence.'], ...
    @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.OutputDir = string(opts.OutputDir);
opts.LimitationsNote = string(opts.LimitationsNote);
end


function d = iNormalizeDescriptor(descriptor)
d = descriptor;
d.case_name = iCharField(descriptor, "case_name", "storage_case");
d.battery_model = iBatteryModelField(descriptor);
d.evidence_source = lower(iCharField(descriptor, "evidence_source", "synthetic"));
d.grid_support_mode = iModeField(descriptor);
d.rated_energy_kwh = iNumField(descriptor, "rated_energy_kwh");
d.rated_power_kw = iNumField(descriptor, "rated_power_kw");
d.study_root = iCharField(descriptor, "study_root", "");
d.soc_soh = iSubStruct(descriptor, "soc_soh");
d.thermal = iSubStruct(descriptor, "thermal");
d.protection = iSubStruct(descriptor, "protection");
d.battery_evidence = iSubStruct(descriptor, "battery_evidence");
d.dc_link = iSubStruct(descriptor, "dc_link");
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


function v = iNumField(s, name)
if isfield(s, name) && isnumeric(s.(name)) && isscalar(s.(name)) && ...
        isfinite(s.(name))
    v = double(s.(name));
else
    v = NaN;
end
end


function m = iBatteryModelField(s)
% Cleaned battery model string. A constant DC source or "none" is NOT a battery
% model: return "" so it is treated as undocumented battery identity.
m = "";
if isfield(s, "battery_model") && (ischar(s.battery_model) || ...
        isstring(s.battery_model))
    m = lower(strtrim(string(s.battery_model)));
end
if any(strcmp(m, ["", "none", "constant_dc_source", "constant_dc", "stiff_dc"]))
    m = "";
end
m = char(m);
end


function m = iModeField(s)
m = "none";
if isfield(s, "grid_support_mode") && (ischar(s.grid_support_mode) || ...
        isstring(s.grid_support_mode))
    raw = lower(strtrim(string(s.grid_support_mode)));
    known = ["peak_shaving", "frequency_response", "pcs_volt_var", ...
        "black_start", "arbitrage", "none"];
    if any(strcmp(raw, known))
        m = raw;
    else
        m = "none";  % unrecognized -> undocumented
    end
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
% A case is provisional until its identity is pinned: a documented battery
% model (not a constant DC source), a documented grid-support mode, and at
% least one of rated energy / rated power.
missing = strings(1, 0);
if isempty(d.battery_model)
    missing(end+1) = "battery_model";
end
if strcmp(d.grid_support_mode, "none")
    missing(end+1) = "grid_support_mode";
end
if ~isfinite(d.rated_energy_kwh) && ~isfinite(d.rated_power_kw)
    missing(end+1) = "rated_energy_or_power";
end
prov = struct();
prov.missing = cellstr(missing);
prov.provisional = ~isempty(missing);
end


function dims = iEvaluateDimensions(d, provisional)
dims = struct([]);
dims = iAppendDim(dims, iDimBatteryModel(d));
dims = iAppendDim(dims, iDimSocWindow(d));
dims = iAppendDim(dims, iDimSoh(d));
dims = iAppendDim(dims, iDimThermal(d));
dims = iAppendDim(dims, iDimProtection(d));
dims = iAppendDim(dims, iDimGridSupportMode(d));
dims = iAppendDim(dims, iDimArtifact(d, "battery_evidence", "battery_evidence", true));
dims = iAppendDim(dims, iDimArtifact(d, "dc_link", "dc_link", true));
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
    "is_artifact", false);
end


function dim = iDimBatteryModel(d)
if isempty(d.battery_model)
    dim = iMakeDim("battery_model", "MISSING", ...
        "battery model undocumented (constant_dc_source is not a battery model)");
else
    dim = iMakeDim("battery_model", "PASS", ...
        sprintf("battery_model = %s", d.battery_model));
end
end


function dim = iDimSocWindow(d)
ss = d.soc_soh;
if isfield(ss, "soc_window") && isnumeric(ss.soc_window) && ...
        numel(ss.soc_window) == 2 && all(isfinite(ss.soc_window))
    w = sort(double(ss.soc_window(:)'));
    dim = iMakeDim("soc_window", "PASS", ...
        sprintf("SOC window = [%.3g %.3g]", w(1), w(2)));
else
    dim = iMakeDim("soc_window", "MISSING", ...
        "usable SOC window undocumented");
end
end


function dim = iDimSoh(d)
ss = d.soc_soh;
if isfield(ss, "soh") && isnumeric(ss.soh) && isscalar(ss.soh) && isfinite(ss.soh)
    dim = iMakeDim("soh", "PASS", sprintf("SOH = %.3g", double(ss.soh)));
else
    dim = iMakeDim("soh", "MISSING", "state of health undocumented");
end
end


function dim = iDimThermal(d)
th = d.thermal;
hasLimit = isfield(th, "limit_c") && isnumeric(th.limit_c) && ...
    isscalar(th.limit_c) && isfinite(th.limit_c);
model = iCharField(th, "model", "");
if hasLimit && ~isempty(model)
    dim = iMakeDim("thermal_limits", "PASS", ...
        sprintf("limit=%.3g C, model=%s", double(th.limit_c), model));
elseif hasLimit
    dim = iMakeDim("thermal_limits", "WARN", ...
        sprintf("limit=%.3g C but thermal model undocumented", double(th.limit_c)));
else
    dim = iMakeDim("thermal_limits", "MISSING", ...
        "thermal limit and model undocumented");
end
end


function dim = iDimProtection(d)
pr = d.protection;
flags = ["ov", "uv", "oc", "ot", "ut", "soc_cutoff"];
present = strings(1, 0);
for k = 1:numel(flags)
    f = flags(k);
    if isfield(pr, f) && iIsTrueish(pr.(f))
        present(end+1) = f; %#ok<AGROW>
    end
end
if isempty(present)
    dim = iMakeDim("protection", "MISSING", ...
        "no BMS protection logic declared (ov/uv/oc/ot/ut/soc_cutoff)");
else
    dim = iMakeDim("protection", "PASS", ...
        sprintf("protection: %s", strjoin(cellstr(present), ", ")));
end
end


function tf = iIsTrueish(v)
tf = (islogical(v) && isscalar(v) && v) || ...
     (isnumeric(v) && isscalar(v) && isfinite(v) && v ~= 0) || ...
     ((ischar(v) || isstring(v)) && strlength(string(v)) > 0 && ...
       ~any(strcmpi(string(v), ["0", "false", "no", "off", "none"])));
end


function dim = iDimGridSupportMode(d)
if strcmp(d.grid_support_mode, "none")
    dim = iMakeDim("grid_support_mode", "MISSING", ...
        "grid-support mode undocumented");
else
    dim = iMakeDim("grid_support_mode", "PASS", ...
        sprintf("grid_support_mode = %s", d.grid_support_mode));
end
end


function dim = iDimArtifact(d, field, displayName, requiredDefault)
% Artifact dimensions point at an evidence file. PASS when a pointer is present
% and (if a path is given) the file exists; WARN when present but flagged
% provisional/indirect; MISSING when required and absent; N/A when not required.
art = d.(field);
required = requiredDefault;
if isfield(art, "required") && islogical(art.required) && isscalar(art.required)
    required = art.required;
end
artifactPath = iCharField(art, "artifact", "");
note = iCharField(art, "note", "");
hasPointer = ~isempty(artifactPath);

dim = iMakeDim(displayName, "N/A", "not required for this case");
dim.is_artifact = true;

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

if ~isfile(artifactPath)
    dim.status = "MISSING";
    dim.detail = sprintf("artifact path supplied but file absent: %s", artifactPath);
    return
end

indirect = (isfield(art, "provisional") && islogical(art.provisional) && art.provisional) ...
    || (isfield(art, "indirect") && islogical(art.indirect) && art.indirect);
if indirect
    dim.status = "WARN";
    dim.detail = iJoinDetail("artifact present but flagged provisional/indirect", note);
else
    dim.status = "PASS";
    dim.detail = iJoinDetail(sprintf("artifact: %s", artifactPath), note);
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


function separation = iSeparationScreen(d)
% The defining check: battery/BMS evidence must be distinct from generic
% DC-link converter evidence. A single shared artifact cannot prove both
% layers. separated = true only when the two pointers are distinct (or one is
% explicitly absent). Reusing one path for both => WARN, separated = false.
%
% Same-study check: distinct paths are necessary but not sufficient. If a
% study_root is declared, every present evidence artifact must resolve under
% that root, so a battery run from one study cannot be stapled to a DC-link run
% from a different study and called a validated BESS. same_study is N/A (empty)
% when no study_root is declared; it never substitutes for the battery-layer
% gate, which stays independent.
battPath = iCharField(d.battery_evidence, "artifact", "");
dcPath = iCharField(d.dc_link, "artifact", "");

issues = strings(1, 0);
if ~isempty(battPath) && ~isempty(dcPath) && strcmpi(battPath, dcPath)
    separated = false;
    issues(end+1) = ...
        "battery_evidence and dc_link reuse one artifact; a single converter " + ...
        "artifact cannot prove both the battery and the DC-link layer";
else
    separated = true;
end

[sameStudy, studyIssues] = iSameStudyScreen(d);
issues = [issues, studyIssues];

separation = struct();
separation.separated = separated;
separation.study_root = char(d.study_root);
separation.same_study = sameStudy;       % true | false | [] (not requested)
separation.battery_artifact = char(battPath);
separation.dc_link_artifact = char(dcPath);
separation.issues = cellstr(issues);
end


function [sameStudy, issues] = iSameStudyScreen(d)
% When study_root is declared, every present artifact path must canonicalize
% under it. Returns sameStudy = [] when no study_root is declared (the check is
% not requested), true when all present artifacts are under the root, and false
% otherwise (with a per-artifact issue listed).
issues = strings(1, 0);
root = strtrim(d.study_root);
if isempty(root)
    sameStudy = [];   % not requested
    return
end

rootCanon = iCanonPath(root);
fields = ["battery_evidence", "dc_link", "modal_evidence", ...
    "impedance_evidence", "time_domain_validation"];
sameStudy = true;
for k = 1:numel(fields)
    p = iCharField(d.(fields(k)), "artifact", "");
    if isempty(p)
        continue
    end
    if ~iIsUnderRoot(iCanonPath(p), rootCanon)
        sameStudy = false;
        issues(end+1) = sprintf(...
            "%s artifact is outside study_root; cross-study evidence cannot " + ...
            "be combined into one validated case", fields(k)); %#ok<AGROW>
    end
end
end


function c = iCanonPath(p)
% Normalize a path for prefix comparison: backslashes to forward slashes, lower
% case (Windows is case-insensitive), strip a trailing slash. Pure string work;
% does not require the file to exist.
c = lower(strrep(char(p), '\', '/'));
if numel(c) > 1 && endsWith(c, '/')
    c = c(1:end-1);
end
end


function tf = iIsUnderRoot(childCanon, rootCanon)
% True when childCanon == rootCanon or sits beneath it on a path boundary, so
% ".../study10" does not match ".../study1".
if strcmp(childCanon, rootCanon)
    tf = true;
    return
end
prefix = [rootCanon, '/'];
tf = startsWith(childCanon, prefix);
end


function tf = iBatteryLayerProven(d, dims, provisional)
% The battery layer is proven only when the battery model is documented (not a
% constant DC source) AND the battery_evidence dimension is PASS. Generic
% DC-link evidence never sets this true. Provisional cases cannot prove it.
tf = false;
if provisional || isempty(d.battery_model)
    return
end
for k = 1:numel(dims)
    if strcmp(dims(k).name, "battery_evidence")
        tf = strcmp(dims(k).status, "PASS");
        return
    end
end
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


function tf = iHandoffReady(dims, separation, batteryProven, provisional)
% Handoff-ready requires: not provisional, no MISSING dimension, battery and
% DC-link evidence separated, the battery layer proven, and (when a study_root
% was declared) all evidence same-study. same_study = [] means the check was
% not requested and does not block; same_study = false blocks.
if provisional || ~separation.separated || ~batteryProven
    tf = false;
    return
end
if islogical(separation.same_study) && isscalar(separation.same_study) && ...
        ~separation.same_study
    tf = false;
    return
end
tf = true;
for k = 1:numel(dims)
    if strcmp(dims(k).status, "MISSING")
        tf = false;
        return
    end
end
end


function claims = iExcludedClaims()
% Each cell row must be a single 1xN char vector. Multi-line strings are wrapped
% in [ ] so the continuation concatenates horizontally; without the brackets the
% space-separated literals would become extra cell columns and the rows would
% have inconsistent width (a vertical-concatenation error).
claims = { ...
    'No Simulink/Simscape model was executed by this helper.'; ...
    'No hardware-in-the-loop or real-time validation is implied.'; ...
    'A PASS records documentation/pointer presence, not a proven physical result.'; ...
    ['SOC/SOH and thermal numbers are declared assumptions unless a battery ' ...
     'evidence artifact backs them.']; ...
    ['A constant-DC-source converter run is a DC-link study, not battery ' ...
     'validation; generic DC-link evidence never proves the battery layer.']};
end


function iWriteOutputs(outDir, summary)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "storage_bms_support.json"), summary);
iWriteMarkdown(fullfile(outDir, "storage_bms_support.md"), summary);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("StorageBmsSupport:CannotWriteJson", "Cannot write %s", path);
end
closer = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("StorageBmsSupport:CannotWriteMarkdown", "Cannot write %s", path);
end
closer = onCleanup(@() fclose(fid));

fprintf(fid, "# Storage / Battery / BMS Support Summary\n\n");
if summary.provisional
    fprintf(fid, "> **PROVISIONAL** - case identity is undocumented; ");
    fprintf(fid, "artifact PASS is downgraded to WARN. Missing: %s\n\n", ...
        iJoinCell(summary.missing_documentation));
end
fprintf(fid, "Case: `%s`\n", summary.case_name);
fprintf(fid, "Battery model: %s | Evidence source: %s\n", ...
    iDisp(summary.battery_model), summary.evidence_source);
fprintf(fid, "Grid-support mode: %s\n", iDisp(summary.grid_support_mode));
fprintf(fid, "Rated energy: %s kWh | Rated power: %s kW\n", ...
    iDispNum(summary.rated_energy_kwh), iDispNum(summary.rated_power_kw));
fprintf(fid, "Generated: %s\n\n", summary.generated_at);

c = summary.status_counts;
fprintf(fid, ['Status counts: PASS=%d WARN=%d MISSING=%d N/A=%d | ' ...
    'battery_layer_proven=%d | handoff_ready=%d\n\n'], ...
    c.PASS, c.WARN, c.MISSING, c.NA, summary.battery_layer_proven, ...
    summary.handoff_ready);

fprintf(fid, "## Evidence dimensions\n\n");
fprintf(fid, "| Dimension | Status | Detail |\n");
fprintf(fid, "|---|---|---|\n");
for k = 1:numel(summary.dimensions)
    dim = summary.dimensions(k);
    fprintf(fid, "| %s | %s | %s |\n", dim.name, dim.status, dim.detail);
end
fprintf(fid, "\n");

fprintf(fid, "## Battery vs DC-link separation\n\n");
sep = summary.separation;
if sep.separated
    fprintf(fid, "- separated: battery/BMS evidence is distinct from DC-link ");
    fprintf(fid, "converter evidence\n");
end
if isempty(sep.same_study)
    fprintf(fid, "- same_study: N/A (no study_root declared)\n");
elseif sep.same_study
    fprintf(fid, "- same_study: all evidence resolves under study_root `%s`\n", ...
        sep.study_root);
else
    fprintf(fid, "- same_study: FALSE - cross-study evidence under study_root `%s`\n", ...
        sep.study_root);
end
for k = 1:numel(sep.issues)
    fprintf(fid, "- WARN: %s\n", sep.issues{k});
end
fprintf(fid, "- battery_artifact: %s\n", iDisp(sep.battery_artifact));
fprintf(fid, "- dc_link_artifact: %s\n\n", iDisp(sep.dc_link_artifact));

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


function s = iDispNum(v)
if isnan(v)
    s = "_(undocumented)_";
else
    s = sprintf("%.4g", v);
end
end


function s = iJoinCell(c)
if isempty(c)
    s = "(none)";
else
    s = strjoin(c, ", ");
end
end


