function comparison = compare_fha_measured_impedance(model, measuredHz, measuredResponse, varargin)
%COMPARE_FHA_MEASURED_IMPEDANCE Compare analytic FHA impedance vs measured data.
%
%   comparison = compare_fha_measured_impedance(model, measuredHz, ...
%       measuredResponse, "Name",value, ...)
%
%   Derives the analytic impedance Z_fha(jw) from MODEL (same model forms as
%   summarize_fha_impedance_response: "transfer_function" or "rlc_branches") on
%   the SUPPLIED measured/simulated frequency grid, then quantifies how well the
%   analytic model reproduces the measured samples and whether the agreement
%   lies inside the FHA validity band.
%
%   Inputs
%     model             struct, see summarize_fha_impedance_response.
%     measuredHz        real vector, strictly positive. Measured grid (Hz).
%     measuredResponse  complex vector, same length. Measured Z (or Y if
%                       "MeasuredKind"="admittance"; converted to Z).
%
%   Key Name-Value options
%     "MeasuredKind"        "impedance" (default) | "admittance"
%     "MeasuredSource"      provenance string, e.g. "simulated_injection",
%                           "measured_lab", "vendor_sheet". Undocumented =>
%                           provisional.
%     "ValidUpToHz"/"SwitchingHz"  FHA validity bound (same semantics as the
%                           derivation helper). Absent => provisional and the
%                           in-band/out-of-band split cannot be trusted.
%     "MagTolPct"           in-band magnitude rel-error PASS threshold (def 10).
%     "PhaseTolDeg"         in-band phase abs-error PASS threshold (def 10).
%     plus the derivation-contract fields (TopologyAssumptions, OperatingPoint,
%     Units, BaseValues, SequenceFrame, FundamentalHz, RelatedTimeDomainRun,
%     CaseName, OutputDir).
%
%   EVIDENCE GRADE (never silently inflated):
%     contract_only  derivation consistent, but no trustworthy in-band data
%                    comparison (provisional, or no in-band points).
%     data_backed    analytic model compared against documented measured/
%                    simulated samples inside the FHA band, within tolerance.
%     data_backed_mismatch  same as above but the model does NOT meet tolerance
%                    (an honest negative result, not a crash).
%   This helper NEVER returns a hardware_backed grade: a comparison against
%   simulated or even measured small-signal sweeps is not HIL/field validation.
%
%   See .agents/skills/analytic-fha-impedance-derivation/references/fha-impedance-contract.md

opts = iParseNameValues(varargin{:});
[fMeas, zMeas] = iNormalizeMeasured(measuredHz, measuredResponse, opts.MeasuredKind);

% Derive the analytic curve on the SAME grid via the F1 derivation helper.
derivArgs = iDerivationArgs(model, opts, fMeas);
[derivSummary, derived] = summarize_fha_impedance_response(derivArgs{:});
zFha = derived.z(:);

[errors, perPoint] = iErrorMetrics(fMeas, zMeas, zFha);
[bandSplit, inBandMask] = iBandSplit(fMeas, errors, perPoint, derived.fha_valid_up_to_hz);
[provisional, missing] = iProvisionalCheck(opts, derived.fha_valid_up_to_hz);
verdict = iVerdict(bandSplit, provisional, opts);

comparison = struct();
comparison.case_name = char(opts.CaseName);
comparison.evidence_grade = verdict.evidence_grade;
comparison.in_band_pass = verdict.in_band_pass;
comparison.measured_source = char(opts.MeasuredSource);
comparison.measured_kind = char(opts.MeasuredKind);
comparison.n_points = numel(fMeas);
comparison.n_in_band = nnz(inBandMask);
comparison.n_out_of_band = nnz(~inBandMask);
comparison.fha_valid_up_to_hz = derived.fha_valid_up_to_hz;
comparison.frequency_min_hz = fMeas(1);
comparison.frequency_max_hz = fMeas(end);
comparison.tolerances = struct("mag_rel_pct", opts.MagTolPct, ...
    "phase_abs_deg", opts.PhaseTolDeg);
comparison.error_overall = errors;
comparison.error_in_band = bandSplit.in_band;
comparison.error_out_of_band = bandSplit.out_of_band;
comparison.provisional = provisional;
comparison.missing_required = missing;
comparison.verdict_note = verdict.note;
comparison.derivation = iDerivDigest(derivSummary);
comparison.limitations = char(opts.LimitationsNote);
comparison.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, comparison, fMeas, zMeas, zFha, perPoint, inBandMask);
end
end

function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("MeasuredKind", "impedance", @iIsText);
p.addParameter("MeasuredSource", "", @iIsText);
p.addParameter("ValidUpToHz", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("SwitchingHz", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("MagTolPct", 10, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("PhaseTolDeg", 10, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("CaseName", "fha_compare_case", @iIsText);
p.addParameter("TopologyAssumptions", "", @iIsText);
p.addParameter("OperatingPoint", "", @iIsText);
p.addParameter("Units", "", @iIsText);
p.addParameter("BaseValues", "", @iIsText);
p.addParameter("SequenceFrame", "positive_sequence", @iIsText);
p.addParameter("FundamentalHz", 50, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("RelatedTimeDomainRun", "", @iIsText);
p.addParameter("OutputDir", "", @iIsText);
p.addParameter("LimitationsNote", ...
    "Analytic-vs-data comparison; not hardware-validated even when measured samples match. Confirm dynamics with time-domain runs.", ...
    @iIsText);
p.parse(varargin{:});
opts = p.Results;
flds = ["MeasuredKind","MeasuredSource","CaseName","TopologyAssumptions", ...
    "OperatingPoint","Units","BaseValues","SequenceFrame", ...
    "RelatedTimeDomainRun","OutputDir","LimitationsNote"];
for k = 1:numel(flds)
    opts.(flds(k)) = string(opts.(flds(k)));
end
opts.MeasuredKind = lower(opts.MeasuredKind);
end


function tf = iIsText(x)
tf = ischar(x) || isstring(x);
end


function [f, z] = iNormalizeMeasured(measuredHz, measuredResponse, kind)
f = double(measuredHz(:));
r = double(measuredResponse(:));
if ~isvector(measuredHz) || numel(f) < 3
    error("FhaCompare:TooFewPoints", "measuredHz needs at least 3 points.");
end
if numel(f) ~= numel(r)
    error("FhaCompare:LengthMismatch", ...
        "measuredHz (%d) and measuredResponse (%d) must match.", numel(f), numel(r));
end
if any(f <= 0)
    error("FhaCompare:BadGrid", "measuredHz must be strictly positive.");
end
if any(diff(f) <= 0)
    [f, order] = sort(f);
    r = r(order);
end
switch kind
    case "impedance"
        z = r;
    case "admittance"
        if any(r == 0)
            error("FhaCompare:ZeroAdmittance", "Admittance has zero entries; cannot invert.");
        end
        z = 1 ./ r;
    otherwise
        error("FhaCompare:BadKind", "MeasuredKind must be 'impedance' or 'admittance'.");
end
end


function args = iDerivationArgs(model, opts, fMeas)
% Build the name-value list for summarize_fha_impedance_response so the
% analytic curve is derived on EXACTLY the measured grid.
args = {"Model", model, ...
    "FrequencyHz", fMeas(:).', ...
    "CaseName", opts.CaseName + "_analytic", ...
    "TopologyAssumptions", opts.TopologyAssumptions, ...
    "OperatingPoint", opts.OperatingPoint, ...
    "Units", opts.Units, ...
    "BaseValues", opts.BaseValues, ...
    "SequenceFrame", opts.SequenceFrame, ...
    "FundamentalHz", opts.FundamentalHz, ...
    "RelatedTimeDomainRun", opts.RelatedTimeDomainRun};
if ~isnan(opts.ValidUpToHz)
    args = [args, {"ValidUpToHz", opts.ValidUpToHz}];
end
if ~isnan(opts.SwitchingHz)
    args = [args, {"SwitchingHz", opts.SwitchingHz}];
end
end

function [errors, perPoint] = iErrorMetrics(f, zMeas, zFha)
% Per-point and aggregate error between analytic and measured complex Z.
magMeas = abs(zMeas);
magFha = abs(zFha);
denom = max(magMeas, realmin);
magAbsErr = abs(magFha - magMeas);
magRelPct = 100 * magAbsErr ./ denom;
phaseErrDeg = iWrapDeg((angle(zFha) - angle(zMeas)) * 180/pi);
complexRel = abs(zFha - zMeas) ./ denom;   % normalized complex error

perPoint = struct("frequency_hz", f(:).', ...
    "mag_meas", magMeas(:).', "mag_fha", magFha(:).', ...
    "mag_rel_pct", magRelPct(:).', "phase_err_deg", phaseErrDeg(:).', ...
    "complex_rel", complexRel(:).');

% R^2 of the analytic magnitude against measured magnitude.
ssRes = sum((magFha - magMeas).^2);
ssTot = sum((magMeas - mean(magMeas)).^2);
if ssTot > 0
    r2 = 1 - ssRes/ssTot;
else
    r2 = NaN;
end

errors = iAggregate(magRelPct, phaseErrDeg, complexRel);
errors.mag_r2 = r2;
end


function agg = iAggregate(magRelPct, phaseErrDeg, complexRel)
if isempty(magRelPct)
    agg = struct("n",0, "mag_rmse_pct",NaN, "mag_max_pct",NaN, ...
        "phase_rmse_deg",NaN, "phase_max_deg",NaN, ...
        "complex_rel_rmse",NaN, "complex_rel_max",NaN, "mag_r2",NaN);
    return
end
agg = struct();
agg.n = numel(magRelPct);
agg.mag_rmse_pct = sqrt(mean(magRelPct.^2));
agg.mag_max_pct = max(magRelPct);
agg.phase_rmse_deg = sqrt(mean(phaseErrDeg.^2));
agg.phase_max_deg = max(abs(phaseErrDeg));
agg.complex_rel_rmse = sqrt(mean(complexRel.^2));
agg.complex_rel_max = max(complexRel);
agg.mag_r2 = NaN;
end


function d = iWrapDeg(d)
% Wrap angle error to (-180, 180] so a +179/-179 pair is a 2-deg error.
d = mod(d + 180, 360) - 180;
end


function [split, inBandMask] = iBandSplit(f, ~, perPoint, validUpToHz)
% Partition points into in-band (<= FHA bound) and out-of-band. If the bound
% is undocumented (NaN) we cannot trust the split: everything is treated as
% out-of-band and the in-band aggregate is empty.
if isnan(validUpToHz)
    inBandMask = false(size(f(:)));
else
    inBandMask = f(:) <= validUpToHz;
end
split.in_band = iAggregate(perPoint.mag_rel_pct(inBandMask), ...
    perPoint.phase_err_deg(inBandMask), perPoint.complex_rel(inBandMask));
split.out_of_band = iAggregate(perPoint.mag_rel_pct(~inBandMask), ...
    perPoint.phase_err_deg(~inBandMask), perPoint.complex_rel(~inBandMask));
end


function [provisional, missing] = iProvisionalCheck(opts, validUpToHz)
missing = {};
if strlength(opts.TopologyAssumptions) == 0
    missing{end+1} = 'topology_assumptions';
end
if strlength(opts.OperatingPoint) == 0
    missing{end+1} = 'operating_point';
end
if strlength(opts.Units) == 0
    missing{end+1} = 'units';
end
if strlength(opts.MeasuredSource) == 0
    missing{end+1} = 'measured_source';
end
if isnan(validUpToHz)
    missing{end+1} = 'fha_validity_bound';
end
provisional = ~isempty(missing);
end


function verdict = iVerdict(split, provisional, opts)
% Grade the comparison. data_backed requires trustworthy in-band points that
% meet tolerance; a documented-but-failing comparison is an honest mismatch;
% everything else is contract_only. Never hardware_backed here.
ib = split.in_band;
hasInBand = ib.n > 0;
verdict = struct("evidence_grade","contract_only", "in_band_pass",false, "note","");
if provisional || ~hasInBand
    if ~hasInBand && ~provisional
        verdict.note = ['No in-band points: measured grid lies outside the FHA ' ...
            'validity band, so the analytic model cannot be data-validated here.'];
    elseif provisional
        verdict.note = ['Provisional: missing required metadata, comparison is ' ...
            'contract-consistency only.'];
    end
    return
end
withinMag = ib.mag_rmse_pct <= opts.MagTolPct;
withinPhase = ib.phase_rmse_deg <= opts.PhaseTolDeg;
verdict.in_band_pass = withinMag && withinPhase;
if verdict.in_band_pass
    verdict.evidence_grade = 'data_backed';
    verdict.note = sprintf(['In-band fit within tolerance (mag RMSE %.3g%% <= %.3g%%, ' ...
        'phase RMSE %.3g deg <= %.3g deg) over %d points.'], ...
        ib.mag_rmse_pct, opts.MagTolPct, ib.phase_rmse_deg, opts.PhaseTolDeg, ib.n);
else
    verdict.evidence_grade = 'data_backed_mismatch';
    verdict.note = sprintf(['In-band fit EXCEEDS tolerance (mag RMSE %.3g%% vs %.3g%%, ' ...
        'phase RMSE %.3g deg vs %.3g deg): analytic model does not reproduce the ' ...
        'measured data in-band; revisit topology/operating point.'], ...
        ib.mag_rmse_pct, opts.MagTolPct, ib.phase_rmse_deg, opts.PhaseTolDeg);
end
end


function d = iDerivDigest(s)
d = struct("model_type", s.model_type, "n_resonances", s.n_resonances, ...
    "dominant_resonance_hz", s.dominant_resonance_hz, ...
    "derivation_provisional", s.provisional);
end

function iWriteOutputs(outDir, comparison, f, zMeas, zFha, perPoint, inBandMask)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "fha_comparison_summary.json"), comparison);
iWriteMarkdown(fullfile(outDir, "fha_comparison_summary.md"), comparison);
iWriteCsv(fullfile(outDir, "fha_comparison_points.csv"), f, zMeas, zFha, perPoint, inBandMask);
end


function iWriteJson(path, comparison)
fid = fopen(path, "w");
if fid < 0
    error("FhaCompare:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(comparison, "PrettyPrint", true));
end


function iWriteMarkdown(path, c)
fid = fopen(path, "w");
if fid < 0
    error("FhaCompare:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Analytic FHA vs Measured Impedance Comparison\n\n");
fprintf(fid, "> **Evidence grade: %s** — %s\n\n", upper(c.evidence_grade), c.verdict_note);
if c.provisional
    fprintf(fid, "> **PROVISIONAL** — missing: %s\n\n", strjoin(c.missing_required, ", "));
end
fprintf(fid, "Case: `%s`\n", c.case_name);
fprintf(fid, "Measured source: %s (kind: %s)\n", iOrUndoc(c.measured_source), c.measured_kind);
fprintf(fid, "Points: %d (%d in-band, %d out-of-band) over [%.4g, %.4g] Hz\n", ...
    c.n_points, c.n_in_band, c.n_out_of_band, c.frequency_min_hz, c.frequency_max_hz);
fprintf(fid, "FHA valid up to: %s Hz\n", iNumOrUndoc(c.fha_valid_up_to_hz));
fprintf(fid, "Tolerances: mag <= %.3g%% rel, phase <= %.3g deg\n", ...
    c.tolerances.mag_rel_pct, c.tolerances.phase_abs_deg);
fprintf(fid, "Generated: %s\n\n", c.generated_at);

fprintf(fid, "## Fit metrics (magnitude rel%%, phase deg, complex rel)\n\n");
fprintf(fid, "| Scope | N | mag RMSE%% | mag max%% | phase RMSE | phase max | cplx RMSE | mag R2 |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|---:|---:|\n");
iRow(fid, "overall", c.error_overall);
iRow(fid, "in-band", c.error_in_band);
iRow(fid, "out-of-band", c.error_out_of_band);
fprintf(fid, "\n");

fprintf(fid, "## Derivation digest\n\n");
d = c.derivation;
fprintf(fid, "- model_type: %s\n- resonances: %d (dominant %s Hz)\n- derivation_provisional: %d\n\n", ...
    d.model_type, d.n_resonances, iNumOrUndoc(d.dominant_resonance_hz), d.derivation_provisional);

fprintf(fid, "## Limitations\n\n%s\n", c.limitations);
end


function iRow(fid, label, e)
fprintf(fid, "| %s | %d | %s | %s | %s | %s | %s | %s |\n", label, e.n, ...
    iNumOrUndoc(e.mag_rmse_pct), iNumOrUndoc(e.mag_max_pct), ...
    iNumOrUndoc(e.phase_rmse_deg), iNumOrUndoc(e.phase_max_deg), ...
    iNumOrUndoc(e.complex_rel_rmse), iNumOrUndoc(e.mag_r2));
end


function s = iOrUndoc(v)
v = string(v);
if strlength(v) == 0
    s = '_(undocumented)_';
else
    s = char(v);
end
end


function s = iNumOrUndoc(v)
if isnan(v)
    s = '_(n/a)_';
else
    s = sprintf('%.4g', v);
end
end


function iWriteCsv(path, f, zMeas, zFha, perPoint, inBandMask)
FrequencyHz = f(:);
InBand = double(inBandMask(:));
MagMeas = abs(zMeas(:));
MagFha = abs(zFha(:));
MagRelPct = perPoint.mag_rel_pct(:);
PhaseErrDeg = perPoint.phase_err_deg(:);
ComplexRel = perPoint.complex_rel(:);
T = table(FrequencyHz, InBand, MagMeas, MagFha, MagRelPct, PhaseErrDeg, ComplexRel);
writetable(T, path);
end
