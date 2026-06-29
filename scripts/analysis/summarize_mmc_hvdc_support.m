function summary = summarize_mmc_hvdc_support(evidence, varargin)
%SUMMARIZE_MMC_HVDC_SUPPORT Summarize and cross-check MMC/HVDC station evidence.
%
%   summary = summarize_mmc_hvdc_support(evidence, "OutputDir", dir)
%
%   evidence is a struct of MMC/HVDC converter-station metadata. The helper
%   validates the required fields, runs the device cross-checks (DC-fault vs
%   submodule type, averaged-vs-switching fidelity, circulating-current
%   applicability, modulation/balancing consistency, and a stored-energy-per-MVA
%   plausibility screen), and emits a per-section PASS/WARN/MISSING/N/A summary.
%
%   This helper describes the SUPPLIED METADATA and its internal consistency. It
%   does NOT run a Simulink simulation and does NOT claim hardware/HIL-level
%   validation. A runnable model must be loaded/updated/simulated separately and
%   linked through related_time_domain_run.
%
%   See .agents/skills/device-pack-mmc-hvdc/references/mmc-hvdc-contract.md

arguments
    evidence struct
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
ev = iNormalizeEvidence(evidence);

sections = struct([]);
sections = iAdd(sections, iCheckTopology(ev));
sections = iAdd(sections, iCheckFidelity(ev));
sections = iAdd(sections, iCheckControlMode(ev));
sections = iAdd(sections, iCheckModulationBalancing(ev));
sections = iAdd(sections, iCheckCirculatingCurrent(ev));
sections = iAdd(sections, iCheckDcLink(ev));
sections = iAdd(sections, iCheckAcFault(ev));
sections = iAdd(sections, iCheckDcFault(ev));
sections = iAdd(sections, iCheckArmEnergy(ev));
sections = iAdd(sections, iCheckFaultEvidence(ev));
sections = iAdd(sections, iCheckLossAccounting(ev));
sections = iAdd(sections, iCheckLineDecoupling(ev));
sections = iAdd(sections, iCheckTimeDomainLink(ev));

statuses = string({sections.status});
severities = string({sections.severity});
nBlocking = nnz(statuses == "WARN" & severities == "blocking");
nAdvisory = nnz(statuses == "WARN" & severities == "advisory");

summary = struct();
summary.case_name = ev.case_name;
summary.source_model_or_script = ev.source_model_or_script;
summary.submodule_type = ev.submodule_type;
summary.model_fidelity = ev.model_fidelity;
summary.control_mode = ev.control_mode;
summary.generated_at = char(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss"));
summary.sections = sections;
summary.n_pass = nnz(statuses == "PASS");
summary.n_warn = nnz(statuses == "WARN");
summary.n_warn_blocking = nBlocking;
summary.n_warn_advisory = nAdvisory;
summary.n_missing = nnz(statuses == "MISSING");
summary.n_na = nnz(statuses == "N/A");

% --- Three evidence tiers, kept deliberately separate -------------------
% contract_status: is the SUPPLIED METADATA complete and internally consistent?
%   MISSING  a required field is absent
%   BLOCKED  a blocking-severity WARN: the evidence asserts something
%            physically impossible or self-contradictory (e.g. half-bridge
%            claiming DC-fault converter blocking)
%   WARN     only advisory WARNs (conformant but flagged for review)
%   PASS     complete and consistent
if summary.n_missing > 0
    summary.contract_status = 'MISSING';
elseif nBlocking > 0
    summary.contract_status = 'BLOCKED';
elseif nAdvisory > 0
    summary.contract_status = 'WARN';
else
    summary.contract_status = 'PASS';
end

% model_validation_status: did an ACTUAL model probe back this evidence?
% Metadata consistency alone can NEVER set this to PASS.
summary.model_validation = iModelValidation(opts.ModelProbe);
summary.model_validation_status = summary.model_validation.status;

% hardware_validation_status: software scope only; never claimed here.
summary.hardware_validation_status = 'N/A';

% provisional: contract not clean, OR no model probe yet.
summary.provisional = ~strcmp(summary.contract_status, 'PASS') || ...
    ~strcmp(summary.model_validation_status, 'PASS');

% handoff_ready requires a clean-enough contract (no MISSING, no blocking
% WARN) AND a passing model-backed probe. Advisory WARNs are allowed through
% (they are flagged for review but are not correctness defects); blocking
% WARNs, MISSING fields, and an absent/failed model probe all block.
contractClean = summary.n_missing == 0 && nBlocking == 0;
summary.handoff_ready = contractClean && ...
    strcmp(summary.model_validation_status, 'PASS');

summary.energy_per_mva_kJ = iEnergyValue(sections);
summary.limitations = ['Contract tier = metadata consistency only. Model tier ' ...
    'requires an actual load/update/simulate probe (ModelProbe); it is never ' ...
    'satisfied by metadata. Hardware/HIL tier is out of software scope (N/A).'];

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, summary);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("ModelProbe", struct(), @(x) isstruct(x));
p.parse(varargin{:});
opts = p.Results;
opts.OutputDir = string(opts.OutputDir);
end


function ev = iNormalizeEvidence(evidence)
% Lower-case string for categoricals; keep numerics; absent -> "" / NaN.
strFields = ["case_name" "source_model_or_script" "station_topology" ...
    "submodule_type" "model_fidelity" "control_mode" "modulation" ...
    "capacitor_voltage_balancing" "circulating_current_control" ...
    "dc_link_dynamics" "ac_fault_handling" "dc_fault_handling" ...
    "related_time_domain_run" ...
    "fault_type" "fault_location" "fault_protection_action" ...
    "loss_model" "decoupling_method" "dc_line_model"];
numFields = ["n_submodules_per_arm" "submodule_capacitance_F" ...
    "arm_inductance_H" "rated_power_MW" "dc_voltage_kV" "ac_voltage_kV" ...
    "fault_clearing_time_ms" "fault_peak_current_pu" ...
    "converter_efficiency_pct" "total_loss_MW" "coupling_residual_pct"];
ev = struct();
for k = 1:numel(strFields)
    name = strFields(k);
    if isfield(evidence, name) && ~isempty(evidence.(name))
        ev.(name) = char(lower(string(evidence.(name))));
    else
        ev.(name) = '';
    end
end
% Identity strings keep original case for readability.
for name = ["case_name" "source_model_or_script" "dc_link_dynamics" ...
        "related_time_domain_run" "fault_location"]
    if isfield(evidence, name) && ~isempty(evidence.(name))
        ev.(name) = char(string(evidence.(name)));
    end
end
for k = 1:numel(numFields)
    name = numFields(k);
    if isfield(evidence, name) && ~isempty(evidence.(name)) && ...
            isnumeric(evidence.(name)) && isscalar(evidence.(name))
        ev.(name) = double(evidence.(name));
    else
        ev.(name) = NaN;
    end
end
% Logical fields: NaN means "absent", true/false when supplied.
if isfield(evidence, "fault_survived") && ~isempty(evidence.fault_survived) && ...
        (islogical(evidence.fault_survived) || isnumeric(evidence.fault_survived)) && ...
        isscalar(evidence.fault_survived)
    ev.fault_survived = logical(evidence.fault_survived);
    ev.has_fault_survived = true;
else
    ev.fault_survived = false;
    ev.has_fault_survived = false;
end
end


function s = iSection(name, status, note, detail)
if nargin < 4; detail = struct(); end
s = struct("name", char(name), "status", char(status), ...
    "note", char(note), "severity", "none", "detail", detail);
end


function s = iWarn(name, severity, note, detail)
% A WARN with an explicit severity:
%   "blocking" - the evidence asserts something physically impossible or
%                self-contradictory (e.g. half-bridge claiming DC-fault
%                converter blocking, or an averaged model claiming
%                switching-level evidence). Blocks handoff readiness.
%   "advisory" - conformant but flagged for human attention (e.g. a
%                plausibility-band miss, an unrecognized enum). Does not
%                block handoff readiness on its own.
if nargin < 4; detail = struct(); end
s = struct("name", char(name), "status", "WARN", ...
    "note", char(note), "severity", char(severity), "detail", detail);
end


function sections = iAdd(sections, s)
if isempty(sections); sections = s; else; sections(end+1) = s; end
end


function tf = iHas(ev, name)
v = ev.(name);
if ischar(v); tf = ~isempty(v); else; tf = ~isnan(v); end
end


function [ok, missing] = iAllPresent(ev, names)
missing = {};
for k = 1:numel(names)
    if ~iHas(ev, names(k)); missing{end+1} = char(names(k)); end %#ok<AGROW>
end
ok = isempty(missing);
end


function tf = iIsAveraged(ev)
tf = any(strcmp(ev.model_fidelity, {'arm_averaged','energy_averaged','rms'}));
end


function tf = iInSet(value, allowed)
tf = ~isempty(value) && any(strcmp(value, allowed));
end


function s = iCheckTopology(ev)
required = ["station_topology" "submodule_type" "n_submodules_per_arm" ...
    "rated_power_MW" "dc_voltage_kV" "ac_voltage_kV"];
[ok, missing] = iAllPresent(ev, required);
if ~ok
    s = iSection("topology", "MISSING", ...
        sprintf("missing required field(s): %s", strjoin(missing, ", ")), ...
        struct("missing_required", {missing}));
    return
end
topoOk = iInSet(ev.station_topology, ...
    {'symmetric_monopole','asymmetric_monopole','bipole','back_to_back'});
smOk = iInSet(ev.submodule_type, {'half_bridge','full_bridge','clamp_double'});
nOk = ev.n_submodules_per_arm >= 1 && ...
    ev.n_submodules_per_arm == round(ev.n_submodules_per_arm);
if topoOk && smOk && nOk
    s = iSection("topology", "PASS", ...
        sprintf("%s, %s, N=%d/arm, %.0f MW, %.0f kV DC", ...
        ev.station_topology, ev.submodule_type, ev.n_submodules_per_arm, ...
        ev.rated_power_MW, ev.dc_voltage_kV), struct());
else
    s = iWarn("topology", "blocking", ...
        "topology/submodule_type enum unrecognized or N not a positive integer; downstream physics checks cannot be trusted", ...
        struct("topology_ok", topoOk, "submodule_ok", smOk, "n_ok", nOk));
end
end


function s = iCheckFidelity(ev)
if ~iHas(ev, "model_fidelity")
    s = iSection("fidelity", "MISSING", "model_fidelity is required", struct());
    return
end
if iInSet(ev.model_fidelity, {'switching','arm_averaged','energy_averaged','rms'})
    s = iSection("fidelity", "PASS", ...
        sprintf("model_fidelity = %s", ev.model_fidelity), struct());
else
    s = iWarn("fidelity", "blocking", ...
        sprintf("unrecognized model_fidelity '%s'; fidelity-gated checks cannot be trusted", ev.model_fidelity), struct());
end
end


function s = iCheckControlMode(ev)
if ~iHas(ev, "control_mode")
    s = iSection("control_mode", "MISSING", "control_mode is required", struct());
    return
end
if iInSet(ev.control_mode, {'pq','vdc_q','droop','gfm','islanded'})
    s = iSection("control_mode", "PASS", ...
        sprintf("control_mode = %s", ev.control_mode), struct());
else
    s = iWarn("control_mode", "advisory", ...
        sprintf("unrecognized control_mode '%s'", ev.control_mode), struct());
end
end


function s = iCheckModulationBalancing(ev)
% Switching-level metadata is N/A for averaged models (cross-check 2), and
% modulation/balancing must be jointly averaged or jointly switching
% (cross-check 4).
averaged = iIsAveraged(ev);
mod = ev.modulation; bal = ev.capacitor_voltage_balancing;
if averaged
    nonNa = (iHas(ev,"modulation") && ~strcmp(mod,'averaged_na')) || ...
        (iHas(ev,"capacitor_voltage_balancing") && ~strcmp(bal,'averaged_na'));
    if nonNa
        s = iWarn("modulation_balancing", "blocking", ...
            "averaged-fidelity model carries switching-level modulation/balancing metadata", ...
            struct("model_fidelity", ev.model_fidelity, "modulation", mod, ...
            "capacitor_voltage_balancing", bal));
    else
        s = iSection("modulation_balancing", "N/A", ...
            "switching-level modulation/balancing not meaningful for averaged fidelity", ...
            struct());
    end
    return
end
[ok, missing] = iAllPresent(ev, ["modulation" "capacitor_voltage_balancing"]);
if ~ok
    s = iSection("modulation_balancing", "MISSING", ...
        sprintf("switching model requires: %s", strjoin(missing, ", ")), ...
        struct("missing_required", {missing}));
    return
end
modAvg = strcmp(mod,'averaged_na');
balAvg = strcmp(bal,'averaged_na');
if modAvg ~= balAvg
    s = iWarn("modulation_balancing", "blocking", ...
        "mixed averaged/switching metadata: one of modulation/balancing is averaged_na, the other is not", ...
        struct("modulation", mod, "capacitor_voltage_balancing", bal));
elseif modAvg && balAvg
    s = iWarn("modulation_balancing", "blocking", ...
        "switching fidelity but both modulation and balancing are averaged_na", ...
        struct("modulation", mod, "capacitor_voltage_balancing", bal));
else
    s = iSection("modulation_balancing", "PASS", ...
        sprintf("modulation=%s, balancing=%s", mod, bal), struct());
end
end


function s = iCheckCirculatingCurrent(ev)
% CCSC is meaningful for switching/arm_averaged; N/A for rms (cross-check 3).
if strcmp(ev.model_fidelity, 'rms')
    s = iSection("circulating_current", "N/A", ...
        "circulating-current control not represented in an RMS model", struct());
    return
end
if ~iHas(ev, "circulating_current_control")
    s = iSection("circulating_current", "MISSING", ...
        "circulating_current_control is required for switching/arm-averaged fidelity", struct());
    return
end
cc = ev.circulating_current_control;
if iInSet(cc, {'ccsc','second_harmonic_suppression','none','averaged_na'})
    if strcmp(cc, 'none')
        s = iWarn("circulating_current", "advisory", ...
            "no circulating-current suppression declared; expect 2nd-harmonic arm-current ripple", struct());
    else
        s = iSection("circulating_current", "PASS", ...
            sprintf("circulating_current_control = %s", cc), struct());
    end
else
    s = iWarn("circulating_current", "advisory", ...
        sprintf("unrecognized circulating_current_control '%s'", cc), struct());
end
end


function s = iCheckDcLink(ev)
if iHas(ev, "dc_link_dynamics")
    s = iSection("dc_link_dynamics", "PASS", ev.dc_link_dynamics, struct());
else
    s = iSection("dc_link_dynamics", "MISSING", ...
        "dc_link_dynamics description is required", struct());
end
end


function s = iCheckAcFault(ev)
if ~iHas(ev, "ac_fault_handling")
    s = iSection("ac_fault", "MISSING", "ac_fault_handling is required", struct());
    return
end
if iInSet(ev.ac_fault_handling, {'current_limit_ride_through','block_and_restart','trip','none'})
    s = iSection("ac_fault", "PASS", ...
        sprintf("ac_fault_handling = %s", ev.ac_fault_handling), struct());
else
    s = iWarn("ac_fault", "advisory", ...
        sprintf("unrecognized ac_fault_handling '%s'", ev.ac_fault_handling), struct());
end
end


function s = iCheckDcFault(ev)
% Headline cross-check 1: half-bridge cannot block DC-side fault current.
if ~iHas(ev, "dc_fault_handling")
    s = iSection("dc_fault", "MISSING", "dc_fault_handling is required", struct());
    return
end
dcf = ev.dc_fault_handling;
if ~iInSet(dcf, {'converter_blocking','dc_breaker','ac_breaker_clearing','ride_through','none'})
    s = iWarn("dc_fault", "advisory", ...
        sprintf("unrecognized dc_fault_handling '%s'", dcf), struct());
    return
end
if strcmp(dcf, 'converter_blocking') && strcmp(ev.submodule_type, 'half_bridge')
    s = iWarn("dc_fault", "blocking", ...
        ['half-bridge submodules cannot interrupt DC fault current; converter ' ...
        'blocking needs full_bridge/clamp_double, a dc_breaker, or ac_breaker_clearing'], ...
        struct("submodule_type", ev.submodule_type, "dc_fault_handling", dcf));
else
    s = iSection("dc_fault", "PASS", ...
        sprintf("dc_fault_handling = %s (consistent with %s)", dcf, ev.submodule_type), ...
        struct());
end
end


function s = iCheckArmEnergy(ev)
% Cross-check 5: stored-energy-per-MVA plausibility (~10..80 kJ/MVA).
needed = ["n_submodules_per_arm" "submodule_capacitance_F" "dc_voltage_kV" "rated_power_MW"];
[ok, missing] = iAllPresent(ev, needed);
if ~ok
    s = iSection("arm_energy", "MISSING", ...
        sprintf("energy screen needs: %s", strjoin(missing, ", ")), ...
        struct("missing_required", {missing}));
    return
end
N = ev.n_submodules_per_arm;
C = ev.submodule_capacitance_F;
VdcV = ev.dc_voltage_kV * 1e3;
Vc = VdcV / N;                       % per-submodule capacitor voltage
E_J = 6 * N * 0.5 * C * Vc^2;        % 6 arms, N submodules each
ePerMva_kJ = (E_J / 1e3) / ev.rated_power_MW;
detail = struct("energy_per_mva_kJ", ePerMva_kJ, "total_stored_energy_MJ", E_J/1e6, ...
    "per_submodule_voltage_kV", Vc/1e3);
if ePerMva_kJ >= 10 && ePerMva_kJ <= 80
    s = iSection("arm_energy", "PASS", ...
        sprintf("stored energy %.1f kJ/MVA (in 10-80 plausibility band)", ePerMva_kJ), detail);
else
    s = iWarn("arm_energy", "advisory", ...
        sprintf("stored energy %.1f kJ/MVA outside 10-80 band; re-check N, C, Vdc", ePerMva_kJ), detail);
end
end


function s = iCheckTimeDomainLink(ev)
if iHas(ev, "related_time_domain_run")
    s = iSection("time_domain_link", "PASS", ev.related_time_domain_run, struct());
else
    s = iSection("time_domain_link", "MISSING", ...
        "related_time_domain_run absent; package is provisional until a model run is linked", struct());
end
end


function tf = iFaultStudyPresent(ev)
% A fault study is "supplied" if any fault_* field is present.
tf = iHas(ev,"fault_type") || iHas(ev,"fault_location") || ...
    iHas(ev,"fault_protection_action") || iHas(ev,"fault_clearing_time_ms") || ...
    iHas(ev,"fault_peak_current_pu") || ev.has_fault_survived;
end


function s = iCheckFaultEvidence(ev)
% Cross-check 6: fault evidence vs submodule type, survival, and plausibility.
if ~iFaultStudyPresent(ev)
    s = iSection("fault_evidence", "N/A", ...
        "no fault study supplied (fault_* fields absent)", struct());
    return
end
required = ["fault_type" "fault_location" "fault_protection_action" ...
    "fault_clearing_time_ms" "fault_peak_current_pu"];
[ok, missing] = iAllPresent(ev, required);
if ~ok || ~ev.has_fault_survived
    if ~ev.has_fault_survived; missing{end+1} = 'fault_survived'; end
    s = iSection("fault_evidence", "MISSING", ...
        sprintf("fault study supplied but incomplete: %s", strjoin(missing, ", ")), ...
        struct("missing_required", {missing}));
    return
end
ft = ev.fault_type; pa = ev.fault_protection_action;
ftOk = iInSet(ft, {'ac_3ph','ac_slg','dc_pole_pole','dc_pole_ground'});
isDcFault = iInSet(ft, {'dc_pole_pole','dc_pole_ground'});
detail = struct("fault_type", ft, "protection_action", pa, ...
    "clearing_time_ms", ev.fault_clearing_time_ms, ...
    "peak_current_pu", ev.fault_peak_current_pu, "survived", ev.fault_survived);
if ~ftOk
    s = iWarn("fault_evidence", "advisory", ...
        sprintf("unrecognized fault_type '%s'", ft), detail);
elseif isDcFault && ev.fault_survived && strcmp(pa, 'converter_blocking') && ...
        strcmp(ev.submodule_type, 'half_bridge')
    s = iWarn("fault_evidence", "blocking", ...
        ['DC fault reported survived via converter_blocking on a half_bridge ' ...
        'station; half-bridge cannot interrupt DC fault current (see dc_fault)'], detail);
elseif ev.fault_peak_current_pu > 15
    s = iWarn("fault_evidence", "advisory", ...
        sprintf("peak fault current %.1f pu is implausibly high without a model-backed transient", ...
        ev.fault_peak_current_pu), detail);
elseif ev.fault_clearing_time_ms > 200 && ev.fault_survived
    s = iWarn("fault_evidence", "advisory", ...
        sprintf("clearing %.0f ms with survived=true is slow; confirm with a transient run", ...
        ev.fault_clearing_time_ms), detail);
else
    s = iSection("fault_evidence", "PASS", ...
        sprintf("%s @ %s, %s, clear %.0f ms, peak %.1f pu, survived=%d", ...
        ft, ev.fault_location, pa, ev.fault_clearing_time_ms, ...
        ev.fault_peak_current_pu, ev.fault_survived), detail);
end
end


function s = iCheckLossAccounting(ev)
% Cross-check 7: loss model vs fidelity, and efficiency/loss energy balance.
if ~iHas(ev, "loss_model")
    s = iSection("loss_accounting", "N/A", ...
        "no loss_model supplied", struct());
    return
end
lm = ev.loss_model;
if ~iInSet(lm, {'none','conduction_only','conduction_switching','datasheet_curve','averaged_na'})
    s = iWarn("loss_accounting", "advisory", ...
        sprintf("unrecognized loss_model '%s'", lm), struct());
    return
end
averaged = iIsAveraged(ev);
detail = struct("loss_model", lm, "converter_efficiency_pct", ev.converter_efficiency_pct, ...
    "total_loss_MW", ev.total_loss_MW);
% Fidelity contradiction: switching-level loss detail on an averaged/RMS model.
if averaged && iInSet(lm, {'conduction_switching','datasheet_curve'})
    s = iWarn("loss_accounting", "blocking", ...
        sprintf("%s loss detail claimed on %s model; switching-loss detail needs switching/arm fidelity", ...
        lm, ev.model_fidelity), detail);
    return
end
% Energy-balance and efficiency-band advisory checks (only if values given).
notes = strings(0);
sev = "";
if iHas(ev, "converter_efficiency_pct")
    eff = ev.converter_efficiency_pct;
    if eff < 95 || eff > 99.9
        sev = "advisory";
        notes(end+1) = sprintf("efficiency %.2f%% outside typical HVDC MMC [95,99.9]", eff);
    end
    if iHas(ev, "total_loss_MW") && iHas(ev, "rated_power_MW") && ev.rated_power_MW > 0
        expected = (1 - eff/100) * ev.rated_power_MW;
        if expected > 0
            relMis = abs(ev.total_loss_MW - expected) / expected;
            detail.expected_loss_MW = expected;
            detail.loss_rel_mismatch = relMis;
            if relMis > 0.25
                sev = "advisory";
                notes(end+1) = sprintf("total_loss_MW %.3g vs expected %.3g (%.0f%% mismatch)", ...
                    ev.total_loss_MW, expected, relMis*100);
            end
        end
    end
end
if sev == "advisory"
    s = iWarn("loss_accounting", "advisory", char(strjoin(notes, "; ")), detail);
else
    s = iSection("loss_accounting", "PASS", ...
        sprintf("loss_model=%s, efficiency=%.4g%%", lm, ev.converter_efficiency_pct), detail);
end
end


function s = iCheckLineDecoupling(ev)
% Cross-check 8: line/arm decoupling vs DC-line model and residual.
if ~iHas(ev, "decoupling_method")
    s = iSection("line_decoupling", "N/A", ...
        "no decoupling_method supplied", struct());
    return
end
dm = ev.decoupling_method;
if ~iInSet(dm, {'arm_averaged_decoupled','dq_decoupled','sequence_decoupled','none'})
    s = iWarn("line_decoupling", "advisory", ...
        sprintf("unrecognized decoupling_method '%s'", dm), struct());
    return
end
detail = struct("decoupling_method", dm, "dc_line_model", ev.dc_line_model, ...
    "coupling_residual_pct", ev.coupling_residual_pct);
notes = strings(0);
flag = false;
if strcmp(dm, 'none')
    flag = true;
    notes(end+1) = "no decoupling declared (decoupling_method=none)";
end
if iHas(ev, "dc_line_model") && strcmp(ev.dc_line_model, 'stiff_source') && ...
        iFaultStudyPresent(ev) && iInSet(ev.fault_type, {'dc_pole_pole','dc_pole_ground'})
    flag = true;
    notes(end+1) = "stiff_source DC line cannot carry DC-line fault/cable transient evidence";
end
if iHas(ev, "coupling_residual_pct") && ev.coupling_residual_pct > 10 && ~strcmp(dm, 'none')
    flag = true;
    notes(end+1) = sprintf("coupling residual %.1f%% > 10%% despite %s", ...
        ev.coupling_residual_pct, dm);
end
if flag
    s = iWarn("line_decoupling", "advisory", char(strjoin(notes, "; ")), detail);
else
    s = iSection("line_decoupling", "PASS", ...
        sprintf("%s, dc_line=%s, residual=%.3g%%", dm, ev.dc_line_model, ...
        ev.coupling_residual_pct), detail);
end
end


function v = iEnergyValue(sections)
v = NaN;
for k = 1:numel(sections)
    if strcmp(sections(k).name, "arm_energy") && isfield(sections(k).detail, "energy_per_mva_kJ")
        v = sections(k).detail.energy_per_mva_kJ;
        return
    end
end
end


function mv = iModelValidation(probe)
% Interpret an optional model-backed probe. This is the ONLY path to a
% model_validation_status of PASS; metadata consistency can never set it.
%
% probe fields (all optional):
%   ran          logical, true if a model was actually loaded/updated/simulated
%   stage        char, e.g. 'load','update','compile','simulate'
%   model        char, model name/path that was exercised
%   passed       logical, true if the probe met its acceptance check
%   note         char, free-text detail
%   metrics      struct, any numeric probe outputs
%
% Status:
%   MISSING  no probe supplied, or probe.ran is false  -> not model-backed
%   WARN     probe ran but passed is false/absent       -> ran, did not confirm
%   PASS     probe ran and passed is true               -> model-backed
mv = struct("status", "MISSING", "ran", false, "stage", "", ...
    "model", "", "passed", false, "note", "", "metrics", struct());
if ~isstruct(probe) || isempty(fieldnames(probe))
    mv.note = 'no ModelProbe supplied; evidence is contract-tier only';
    return
end
if isfield(probe, "ran"); mv.ran = logical(probe.ran); end
if isfield(probe, "stage"); mv.stage = char(string(probe.stage)); end
if isfield(probe, "model"); mv.model = char(string(probe.model)); end
if isfield(probe, "passed"); mv.passed = logical(probe.passed); end
if isfield(probe, "note"); mv.note = char(string(probe.note)); end
if isfield(probe, "metrics") && isstruct(probe.metrics); mv.metrics = probe.metrics; end
if ~mv.ran
    mv.status = "MISSING";
    if isempty(mv.note)
        mv.note = 'ModelProbe.ran is false; no model was exercised';
    end
elseif mv.passed
    mv.status = "PASS";
    if isempty(mv.note)
        mv.note = sprintf('model-backed: %s probe on %s passed', mv.stage, mv.model);
    end
else
    mv.status = "WARN";
    if isempty(mv.note)
        mv.note = sprintf('model probe ran (%s) but did not pass its check', mv.stage);
    end
end
end


function iWriteOutputs(outDir, summary)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "mmc_hvdc_support.json"), summary);
iWriteMarkdown(fullfile(outDir, "mmc_hvdc_support.md"), summary);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("MmcHvdcSupport:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("MmcHvdcSupport:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# MMC / HVDC Device Support Summary\n\n");
fprintf(fid, "Case: `%s`\n", summary.case_name);
fprintf(fid, "Source: `%s`\n", summary.source_model_or_script);
fprintf(fid, "Submodule: %s | Fidelity: %s | Control: %s\n", ...
    summary.submodule_type, summary.model_fidelity, summary.control_mode);
fprintf(fid, "Generated: %s\n\n", summary.generated_at);

if summary.provisional
    fprintf(fid, "> PROVISIONAL: contract not fully clean or no model-backed probe yet.\n\n");
end
fprintf(fid, "## Evidence tiers\n\n");
fprintf(fid, "| Tier | Status |\n|---|---|\n");
fprintf(fid, "| contract (metadata consistency) | %s |\n", summary.contract_status);
fprintf(fid, "| model_validation (load/update/sim) | %s |\n", summary.model_validation_status);
fprintf(fid, "| hardware/HIL | %s |\n\n", summary.hardware_validation_status);
fprintf(fid, "handoff_ready = %d (requires contract=PASS AND model_validation=PASS)\n\n", ...
    summary.handoff_ready);
fprintf(fid, "Status tally: PASS=%d WARN=%d (blocking=%d advisory=%d) MISSING=%d N/A=%d\n\n", ...
    summary.n_pass, summary.n_warn, summary.n_warn_blocking, summary.n_warn_advisory, ...
    summary.n_missing, summary.n_na);
if ~isnan(summary.energy_per_mva_kJ)
    fprintf(fid, "Stored energy: %.1f kJ/MVA\n\n", summary.energy_per_mva_kJ);
end

fprintf(fid, "## Section status\n\n");
fprintf(fid, "| Section | Status | Severity | Note |\n");
fprintf(fid, "|---|---|---|---|\n");
for k = 1:numel(summary.sections)
    sec = summary.sections(k);
    fprintf(fid, "| %s | %s | %s | %s |\n", sec.name, sec.status, sec.severity, sec.note);
end
fprintf(fid, "\n");

mv = summary.model_validation;
fprintf(fid, "## Model-backed probe\n\n");
fprintf(fid, "- status: %s\n", mv.status);
fprintf(fid, "- ran: %d", mv.ran);
if ~isempty(mv.stage); fprintf(fid, " | stage: %s", mv.stage); end
if ~isempty(mv.model); fprintf(fid, " | model: %s", mv.model); end
fprintf(fid, "\n- %s\n\n", mv.note);

fprintf(fid, "## Limitations\n\n%s\n", summary.limitations);
end
