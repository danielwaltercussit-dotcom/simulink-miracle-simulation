function summary = summarize_device_loss_thermal_evidence(varargin)
%SUMMARIZE_DEVICE_LOSS_THERMAL_EVIDENCE Device-loss + thermal evidence summary.
%
%   summary = summarize_device_loss_thermal_evidence( ...
%       "CaseName","leg1", "DeviceLossMode","on-resistance+Vf", ...
%       "ConductionLossW",Pc, "ConductionLossSource","model", ...
%       "SwitchingEnergyJ",[Eon Eoff], "SwitchingEventsPerS",N, ...
%       "ThermalRthCtoA",Rth, "ThermalCth",Cth, "AmbientC",Ta, ...
%       "OutputDir",dir)
%
%   Summarizes converter device-loss and thermal-rise evidence with a SEPARATE
%   evidence level per metric, so a number's trust is explicit:
%     contract_only  the value is a declared/synthetic placeholder;
%     model_backed   the value came from an actual model run (e.g. conduction
%                    loss integrated from a simulated waveform);
%     hardware_backed reserved for measured loss/temperature; NEVER inferred
%                    from a simulation here.
%
%   Loss/thermal numbers from an IDEAL device model are reported N/A, not 0 W:
%   an ideal switch cannot substantiate a loss or temperature claim. Thermal
%   rise is a first-order Rth/Cth estimate from the supplied network and the
%   (model-backed) loss; it is a modelling estimate, never a hardware result.
%
%   See .agents/skills/emt-switching-level-converter/references/switching-evidence-contract.md

opts = iParseOpts(varargin{:});

summary = struct();
summary.case_name = char(opts.CaseName);
summary.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));
summary.device_loss_mode = char(opts.DeviceLossMode);
summary.is_ideal = iIsIdeal(opts.DeviceLossMode);

summary.conduction = iConduction(opts, summary.is_ideal);
summary.switching = iSwitching(opts, summary.is_ideal);
summary.total_loss = iTotalLoss(summary.conduction, summary.switching);
summary.thermal = iThermal(opts, summary.total_loss);
summary.status = char(iStatus(summary));
summary.limitations = char(opts.LimitationsNote);

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, summary);
end
end


function opts = iParseOpts(varargin)
p = inputParser;
p.addParameter("CaseName", "device_loss_case", @(x) ischar(x) || isstring(x));
p.addParameter("DeviceLossMode", "ideal", @(x) ischar(x) || isstring(x));
p.addParameter("ConductionLossW", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("ConductionLossSource", "contract", @(x) ischar(x) || isstring(x));
p.addParameter("SwitchingEnergyJ", [], @(x) isnumeric(x) && (isempty(x) || numel(x) <= 2));
p.addParameter("SwitchingEventsPerS", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("SwitchingLossSource", "contract", @(x) ischar(x) || isstring(x));
p.addParameter("ThermalRthCtoA", NaN, @(x) isnumeric(x) && isscalar(x) && (isnan(x) || x > 0));
p.addParameter("ThermalCth", NaN, @(x) isnumeric(x) && isscalar(x) && (isnan(x) || x > 0));
p.addParameter("AmbientC", 40, @(x) isnumeric(x) && isscalar(x));
p.addParameter("ThermalSource", "contract", @(x) ischar(x) || isstring(x));
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("LimitationsNote", ...
    "Loss/thermal are modelling estimates from the supplied device model and network; not hardware-measured. Confirm with measured loss/temperature before any deployment claim.", ...
    @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.CaseName = string(opts.CaseName);
opts.DeviceLossMode = lower(string(opts.DeviceLossMode));
opts.ConductionLossSource = lower(string(opts.ConductionLossSource));
opts.SwitchingLossSource = lower(string(opts.SwitchingLossSource));
opts.ThermalSource = lower(string(opts.ThermalSource));
opts.OutputDir = string(opts.OutputDir);
opts.LimitationsNote = string(opts.LimitationsNote);
end


function tf = iIsIdeal(mode)
tf = any(strcmp(char(lower(string(mode))), {'ideal', ''}));
end


function level = iEvidenceLevel(source)
% Map a declared source string to one of the three evidence levels. Only an
% explicit model/simulation source reaches model_backed; only measured/hardware
% reaches hardware_backed; everything else is contract_only.
src = char(lower(string(source)));
switch src
    case {'model', 'simulation', 'simulation_output', 'measured_from_model'}
        level = 'model_backed';
    case {'hardware', 'measured', 'datasheet_measured', 'hil'}
        level = 'hardware_backed';
    otherwise
        level = 'contract_only';
end
end


function c = iConduction(opts, isIdeal)
% Conduction loss. Ideal device -> N/A (cannot substantiate a loss claim). A
% model source downgrades to contract_only if no actual value was supplied.
c = struct("applicable", true, "value_w", NaN, "evidence_level", "contract_only", ...
    "note", "");
if isIdeal
    c.applicable = false;
    c.evidence_level = "not_applicable";
    c.note = 'ideal device: conduction loss N/A (not 0 W)';
    return
end
if isnan(opts.ConductionLossW)
    c.note = 'no conduction-loss value supplied';
    return
end
c.value_w = opts.ConductionLossW;
lvl = iEvidenceLevel(opts.ConductionLossSource);
if strcmp(lvl, 'model_backed') && ~(opts.ConductionLossW >= 0)
    % A model source that produced a non-physical (negative/NaN) loss cannot
    % be trusted as model-backed.
    lvl = 'contract_only';
    c.note = 'non-physical model loss; downgraded to contract_only';
end
c.evidence_level = lvl;
end


function s = iSwitching(opts, isIdeal)
% Switching loss estimate = (Eon+Eoff) * events_per_second. Only computed when
% both the per-event energy and the event rate are supplied. When inputs are
% absent the metric is "not_assessed" (it does not drag the overall status to
% WARN the way an unsubstantiated contract_only value would).
s = struct("applicable", true, "value_w", NaN, "evidence_level", "not_assessed", ...
    "energy_j", NaN, "events_per_s", opts.SwitchingEventsPerS, "note", "");
if isIdeal
    s.applicable = false;
    s.evidence_level = "not_applicable";
    s.note = 'ideal device: switching loss N/A';
    return
end
e = opts.SwitchingEnergyJ;
if isempty(e) || isnan(opts.SwitchingEventsPerS)
    s.note = 'switching energy or event rate not supplied; estimate skipped';
    return
end
s.energy_j = sum(e(:));
s.value_w = s.energy_j * opts.SwitchingEventsPerS;
s.evidence_level = iEvidenceLevel(opts.SwitchingLossSource);
if strcmp(s.evidence_level, 'model_backed')
    % A switching-loss number built from datasheet energies and a counted event
    % rate is at best model_referenced, not a full model_backed measurement.
    s.evidence_level = "model_referenced";
    s.note = 'estimate from per-event energy x event rate';
end
end


function tl = iTotalLoss(c, s)
tl = struct("value_w", NaN, "evidence_level", "not_applicable", "note", "");
parts = [];
levels = {};
if c.applicable && ~isnan(c.value_w)
    parts(end+1) = c.value_w;
    levels{end+1} = char(c.evidence_level);
end
if s.applicable && ~isnan(s.value_w)
    parts(end+1) = s.value_w;
    levels{end+1} = char(s.evidence_level);
end
if isempty(parts)
    tl.note = 'no applicable loss components';
    return
end
tl.value_w = sum(parts);
tl.evidence_level = iWeakestLevel(levels);
end


function lvl = iWeakestLevel(levels)
% The combined evidence is only as strong as its weakest component.
order = ["hardware_backed", "model_backed", "model_referenced", "contract_only"];
worst = "hardware_backed";
for k = 1:numel(levels)
    li = string(levels{k});
    if iRank(li, order) > iRank(worst, order)
        worst = li;
    end
end
lvl = char(worst);
end


function r = iRank(level, order)
r = find(order == level, 1);
if isempty(r); r = numel(order); end
end


function th = iThermal(opts, totalLoss)
% First-order steady-state thermal rise dT = P * Rth, junction temp Tj = Ta+dT.
% Only meaningful when a model/applicable total loss and an Rth are supplied.
% Thermal evidence is capped at model_backed: hardware temperature needs
% measured data, never inferred here.
th = struct("applicable", false, "rth_c_per_w", opts.ThermalRthCtoA, ...
    "cth_j_per_c", opts.ThermalCth, "ambient_c", opts.AmbientC, ...
    "delta_t_c", NaN, "junction_c", NaN, "tau_s", NaN, ...
    "evidence_level", "not_applicable", "note", "");
if isnan(opts.ThermalRthCtoA)
    th.note = 'no Rth supplied; thermal estimate skipped';
    return
end
if isnan(totalLoss.value_w) || strcmp(totalLoss.evidence_level, "not_applicable")
    th.note = 'no applicable loss to drive the thermal network';
    return
end
th.applicable = true;
th.delta_t_c = totalLoss.value_w * opts.ThermalRthCtoA;
th.junction_c = opts.AmbientC + th.delta_t_c;
if ~isnan(opts.ThermalCth)
    th.tau_s = opts.ThermalRthCtoA * opts.ThermalCth;
end
% Thermal estimate inherits the loss evidence level but can never be hardware.
lvl = totalLoss.evidence_level;
if strcmp(lvl, "hardware_backed")
    lvl = "model_backed";
end
th.evidence_level = char(lvl);
declared = iEvidenceLevel(opts.ThermalSource);
if strcmp(declared, 'contract_only')
    th.note = 'first-order Rth estimate; network parameters undocumented as measured';
else
    th.note = 'first-order Rth/Cth estimate from model-backed loss';
end
end


function st = iStatus(summary)
% Overall status considers only ASSESSED metrics (a metric with a value and a
% real evidence level). not_assessed / not_applicable metrics are ignored.
%   PASS  at least one assessed metric is model-grade and none is contract_only;
%   WARN  an assessed metric is only contract_only (unsubstantiated);
%   N/A   nothing was assessed (e.g. ideal device, no loss inputs).
assessed = {};
assessed = iCollectAssessed(assessed, summary.conduction);
assessed = iCollectAssessed(assessed, summary.switching);
if isempty(assessed)
    st = "N/A";
    return
end
anyModel = any(ismember(assessed, {'model_backed', 'model_referenced', 'hardware_backed'}));
anyContract = any(strcmp(assessed, 'contract_only'));
if anyModel && ~anyContract
    st = "PASS";
else
    st = "WARN";
end
end


function assessed = iCollectAssessed(assessed, metric)
if metric.applicable && ~isnan(metric.value_w)
    lvl = char(metric.evidence_level);
    if ~any(strcmp(lvl, {'not_assessed', 'not_applicable'}))
        assessed{end+1} = lvl;
    end
end
end


function iWriteOutputs(outDir, summary)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "device_loss_thermal_summary.json"), summary);
iWriteMarkdown(fullfile(outDir, "device_loss_thermal_summary.md"), summary);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("DeviceLossThermal:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("DeviceLossThermal:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Device-Loss / Thermal Evidence Summary\n\n");
fprintf(fid, "Case: `%s`\n", summary.case_name);
fprintf(fid, "Device loss mode: %s | Status: **%s**\n", ...
    summary.device_loss_mode, summary.status);
fprintf(fid, "Generated: %s\n\n", summary.generated_at);

c = summary.conduction;
s = summary.switching;
tl = summary.total_loss;
th = summary.thermal;

fprintf(fid, "## Loss components\n\n");
fprintf(fid, "| Component | Value W | Evidence level | Note |\n");
fprintf(fid, "|---|---:|---|---|\n");
fprintf(fid, "| conduction | %s | %s | %s |\n", ...
    iNumOrNA(c.value_w, c.applicable), c.evidence_level, iOrDash(c.note));
fprintf(fid, "| switching | %s | %s | %s |\n", ...
    iNumOrNA(s.value_w, s.applicable), s.evidence_level, iOrDash(s.note));
fprintf(fid, "| total | %s | %s | %s |\n\n", ...
    iNumOrNA(tl.value_w, ~strcmp(tl.evidence_level,'not_applicable')), ...
    tl.evidence_level, iOrDash(tl.note));

fprintf(fid, "## Thermal\n\n");
if th.applicable
    fprintf(fid, "- Rth = %.4g C/W", th.rth_c_per_w);
    if ~isnan(th.cth_j_per_c)
        fprintf(fid, ", Cth = %.4g J/C, tau = %.4g s", th.cth_j_per_c, th.tau_s);
    end
    fprintf(fid, "\n- ambient = %.4g C | dT = %.4g C | junction = %.4g C\n", ...
        th.ambient_c, th.delta_t_c, th.junction_c);
    fprintf(fid, "- evidence level: **%s** (modelling estimate; not a measured temperature)\n", ...
        th.evidence_level);
else
    fprintf(fid, "- not computed: %s\n", iOrDash(th.note));
end
fprintf(fid, "\n");

fprintf(fid, "## Evidence-level legend\n\n");
fprintf(fid, "- contract_only: declared/synthetic placeholder, not a model result.\n");
fprintf(fid, "- model_referenced: estimate from documented coefficients (e.g. datasheet energy x event rate).\n");
fprintf(fid, "- model_backed: integrated from an actual model run.\n");
fprintf(fid, "- hardware_backed: measured; NEVER inferred from a simulation here.\n\n");

fprintf(fid, "## Limitations\n\n%s\n", summary.limitations);
end


function s = iNumOrNA(v, applicable)
if ~applicable
    s = "N/A";
elseif isnan(v)
    s = "-";
else
    s = sprintf("%.5g", v);
end
end


function s = iOrDash(v)
if isempty(char(v)); s = "-"; else; s = char(v); end
end