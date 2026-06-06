function [summary, derived] = summarize_fha_impedance_response(varargin)
%SUMMARIZE_FHA_IMPEDANCE_RESPONSE Analytic FHA / impedance derivation evidence.
%
%   summary = summarize_fha_impedance_response("Model", model, ...)
%   [summary, derived] = summarize_fha_impedance_response("Model", model, ...)
%
%   Unlike summarize_impedance_frequency_response (P3), which SUMMARIZES a
%   frequency response the caller already has, this helper DERIVES the
%   positive-sequence analytic impedance Z(jw) from a stated model:
%
%     model.type = "transfer_function"
%       model.num, model.den  polynomial coeffs in s (descending powers),
%       so Z(s)=num(s)/den(s). Poles/zeros (hence resonances) are exact.
%
%     model.type = "rlc_branches"
%       model.branches  struct array of parallel branches, each a series RLC
%       with fields R (ohm), L (H), C (F). Missing/0 L or C drops that term.
%       Z = 1 / sum_k (1 / (R_k + jwL_k + 1/(jwC_k))).
%
%   It records the analytic-derivation contract (topology assumptions,
%   operating point, units, base values, sequence frame, frequency grid,
%   approximation limits, fundamental/switching frequency, related
%   time-domain run) and flags the band where the fundamental-frequency /
%   linear small-signal approximation (FHA) is trusted.
%
%   This is ANALYTIC evidence: only as good as the stated topology and
%   operating point. It does NOT prove instability and does NOT claim
%   hardware-level validation. Confirm resonances with EMT/RMS time-domain
%   runs and, where available, modal evidence. If topology, operating point,
%   or units are undocumented, the result is marked provisional.
%
%   The optional second output DERIVED returns the raw derived curve on the
%   evaluation grid (fields: frequency_hz, z complex, magnitude, phase_deg,
%   fha_valid_up_to_hz, kind). compare_fha_measured_impedance uses it to align
%   an analytic model with supplied measured/simulated samples; reuse it rather
%   than re-deriving Z elsewhere.
%
%   See .agents/skills/analytic-fha-impedance-derivation/references/fha-impedance-contract.md

opts = iParseNameValues(varargin{:});
[f, gridSpacing] = iResolveGrid(opts);
[z, modelInfo] = iEvaluateModel(opts.Model, f);

mag = abs(z);
magDb = 20*log10(max(mag, realmin));
phaseDeg = angle(z) * 180/pi;

fha = iFhaValidity(f, opts);
resonances = iAnalyticResonances(modelInfo, f, mag, opts);
bands = iBandEnergy(f, mag);
passivity = iPassivityScreen(f, z, modelInfo.kind);
[provisional, missing] = iProvisionalCheck(opts);

summary = struct();
summary.case_name = char(opts.CaseName);
summary.evidence_source = 'analytic';
summary.model_type = char(modelInfo.type);
summary.kind = char(modelInfo.kind);
summary.topology_assumptions = char(opts.TopologyAssumptions);
summary.operating_point = char(opts.OperatingPoint);
summary.units = char(opts.Units);
summary.base_values = char(opts.BaseValues);
summary.sequence_frame = char(opts.SequenceFrame);
summary.fundamental_hz = opts.FundamentalHz;
summary.switching_hz = opts.SwitchingHz;
summary.approximation_limits = char(opts.ApproximationLimits);
summary.related_time_domain_run = char(opts.RelatedTimeDomainRun);
summary.follow_up_required = char(opts.FollowUpRequired);
summary.frequency_grid = struct("min_hz", f(1), "max_hz", f(end), ...
    "n_points", numel(f), "spacing", gridSpacing);
summary.fha_validity = fha;
summary.resonances = resonances;
summary.n_resonances = numel(resonances);
summary.dominant_resonance_hz = iDominant(resonances);
summary.frequency_bands = bands;
summary.passivity = passivity;
summary.provisional = provisional;
summary.missing_required = missing;
summary.limitations = char(opts.LimitationsNote);
summary.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));

if nargout > 1
    derived = struct("frequency_hz", f(:).', "z", z(:).', ...
        "magnitude", mag(:).', "phase_deg", phaseDeg(:).', ...
        "fha_valid_up_to_hz", fha.valid_up_to_hz, "kind", char(modelInfo.kind));
end

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, summary, f, mag, magDb, phaseDeg);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("Model", struct(), @isstruct);
p.addParameter("FrequencyHz", [], @isnumeric);
p.addParameter("FreqMinHz", 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("FreqMaxHz", 1000, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("NPoints", 200, @(x) isnumeric(x) && isscalar(x) && x >= 3);
p.addParameter("Spacing", "log", @iIsText);
p.addParameter("CaseName", "fha_case", @iIsText);
p.addParameter("TopologyAssumptions", "", @iIsText);
p.addParameter("OperatingPoint", "", @iIsText);
p.addParameter("Units", "", @iIsText);
p.addParameter("BaseValues", "", @iIsText);
p.addParameter("SequenceFrame", "positive_sequence", @iIsText);
p.addParameter("FundamentalHz", 50, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("SwitchingHz", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("ValidUpToHz", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("ApproximationLimits", "", @iIsText);
p.addParameter("RelatedTimeDomainRun", "", @iIsText);
p.addParameter("FollowUpRequired", "", @iIsText);
p.addParameter("MaxPeaks", 10, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.addParameter("PeakProminenceRatio", 1.5, @(x) isnumeric(x) && isscalar(x) && x > 1);
p.addParameter("OutputDir", "", @iIsText);
p.addParameter("LimitationsNote", ...
    "Analytic derivation from stated topology and operating point; not hardware-validated. Confirm resonances with time-domain and modal evidence.", ...
    @iIsText);
p.parse(varargin{:});
opts = p.Results;
opts.CaseName = string(opts.CaseName);
opts.Spacing = lower(string(opts.Spacing));
opts.TopologyAssumptions = string(opts.TopologyAssumptions);
opts.OperatingPoint = string(opts.OperatingPoint);
opts.Units = string(opts.Units);
opts.BaseValues = string(opts.BaseValues);
opts.SequenceFrame = string(opts.SequenceFrame);
opts.ApproximationLimits = string(opts.ApproximationLimits);
opts.RelatedTimeDomainRun = string(opts.RelatedTimeDomainRun);
opts.FollowUpRequired = string(opts.FollowUpRequired);
opts.OutputDir = string(opts.OutputDir);
opts.LimitationsNote = string(opts.LimitationsNote);
end


function tf = iIsText(x)
tf = ischar(x) || isstring(x);
end


function [f, spacing] = iResolveGrid(opts)
if ~isempty(opts.FrequencyHz)
    f = double(opts.FrequencyHz(:)).';
    if any(f <= 0)
        error("FhaImpedance:BadGrid", "FrequencyHz must be strictly positive.");
    end
    if any(diff(f) <= 0)
        f = sort(f);
    end
    spacing = iDetectSpacing(f);
else
    switch opts.Spacing
        case "log"
            f = logspace(log10(opts.FreqMinHz), log10(opts.FreqMaxHz), opts.NPoints);
            spacing = "log";
        case "linear"
            f = linspace(opts.FreqMinHz, opts.FreqMaxHz, opts.NPoints);
            spacing = "linear";
        otherwise
            error("FhaImpedance:BadSpacing", "Spacing must be 'log' or 'linear'.");
    end
end
if numel(f) < 3
    error("FhaImpedance:TooFewPoints", "Need at least 3 frequency points.");
end
end


function s = iDetectSpacing(f)
f = f(:).';
if numel(f) < 3
    s = "unknown";
    return
end
dLin = diff(f);
dLog = diff(log10(f));
isLin = max(abs(dLin - mean(dLin))) <= 1e-6 * max(abs(dLin));
isLog = max(abs(dLog - mean(dLog))) <= 1e-6 * max(abs(dLog));
if isLin
    s = "linear";
elseif isLog
    s = "log";
else
    s = "nonuniform";
end
end
function [z, info] = iEvaluateModel(model, f)
% Derive Z(jw) analytically from the stated model.
if ~isfield(model, "type") || isempty(model.type)
    error("FhaImpedance:NoModel", ...
        "Model.type required: 'transfer_function' or 'rlc_branches'.");
end
w = 2*pi*f(:).';
s = 1j*w;
info = struct("type", lower(string(model.type)), "kind", "impedance", ...
    "poles_hz", [], "zeros_hz", []);
switch info.type
    case "transfer_function"
        if ~isfield(model,"num") || ~isfield(model,"den")
            error("FhaImpedance:BadTF", "transfer_function needs num and den.");
        end
        num = double(model.num(:)).';
        den = double(model.den(:)).';
        z = polyval(num, s) ./ polyval(den, s);
        info.poles_hz = iRootsHz(den);
        info.zeros_hz = iRootsHz(num);
        if isfield(model,"kind") && strlength(string(model.kind)) > 0
            info.kind = lower(string(model.kind));
        end
    case "rlc_branches"
        if ~isfield(model,"branches") || isempty(model.branches)
            error("FhaImpedance:BadRLC", "rlc_branches needs a branches struct array.");
        end
        Y = zeros(size(w));
        for k = 1:numel(model.branches)
            b = model.branches(k);
            R = iField(b,"R",0); L = iField(b,"L",0); C = iField(b,"C",0);
            zb = R + s.*L;
            if C > 0
                zb = zb + 1 ./ (s.*C);
            end
            Y = Y + 1 ./ zb;
        end
        z = 1 ./ Y;
    otherwise
        error("FhaImpedance:BadModelType", ...
            "Model.type must be 'transfer_function' or 'rlc_branches'; got '%s'.", info.type);
end
z = z(:).';
if any(~isfinite(z))
    z(~isfinite(z)) = realmax;
end
end


function v = iField(s, name, default)
if isfield(s, name) && ~isempty(s.(name))
    v = double(s.(name));
else
    v = default;
end
end


function fHz = iRootsHz(poly)
% Imag part of polynomial roots mapped to Hz (resonant frequencies).
if numel(poly) < 2
    fHz = [];
    return
end
r = roots(poly);
r = r(abs(imag(r)) > 1e-9);
fHz = sort(unique(round(abs(imag(r))/(2*pi), 6)));
fHz = fHz(fHz > 0).';
end


function fha = iFhaValidity(f, opts)
% FHA / linear small-signal trust band. Default upper bound is half the
% switching frequency (Nyquist-style) when given, else the requested
% ValidUpToHz, else unbounded with a provisional note.
fha = struct("valid_from_hz", f(1), "valid_up_to_hz", NaN, ...
    "in_band_fraction", 1, "basis", "", "note", "");
upper = NaN;
basis = "";
if ~isnan(opts.ValidUpToHz)
    upper = opts.ValidUpToHz;
    basis = "explicit_valid_up_to";
elseif ~isnan(opts.SwitchingHz)
    upper = opts.SwitchingHz / 2;
    basis = "half_switching_frequency";
end
fha.valid_up_to_hz = upper;
fha.basis = char(basis);
if isnan(upper)
    fha.in_band_fraction = NaN;
    fha.note = 'No switching/validity bound supplied: FHA trust band undocumented (provisional).';
else
    inBand = f >= f(1) & f <= upper;
    fha.in_band_fraction = nnz(inBand) / numel(f);
    if f(end) > upper
        fha.note = sprintf(['Grid extends to %.4g Hz beyond the FHA trust bound %.4g Hz; ', ...
            'features above the bound are NOT covered by the fundamental-frequency approximation.'], ...
            f(end), upper);
    else
        fha.note = 'Full grid within the FHA trust band.';
    end
end
end


function res = iAnalyticResonances(info, f, mag, opts)
% Prefer exact analytic poles within the grid; fall back to a
% prominence-ratio magnitude screen (shared philosophy with the P3 helper).
poles = info.poles_hz;
poles = poles(poles >= f(1) & poles <= f(end));
if ~isempty(poles)
    n = min(numel(poles), opts.MaxPeaks);
    res = repmat(iEmptyRes(), 1, n);
    for k = 1:n
        res(k) = iResAt(poles(k), f, mag, "analytic_pole");
    end
    return
end
cand = iPromPeaks(mag, opts.PeakProminenceRatio, opts.MaxPeaks);
res = repmat(iEmptyRes(), 1, numel(cand));
for k = 1:numel(cand)
    res(k) = iResAt(f(cand(k)), f, mag, "magnitude_peak");
end
if isempty(cand)
    res = iEmptyResArray();
end
end


function r = iResAt(fHz, f, mag, source)
[~, idx] = min(abs(f - fHz));
r = iEmptyRes();
r.frequency_hz = fHz;
r.magnitude = mag(idx);
r.source = char(source);
r.band = iBandName(fHz);
half = mag(idx) / sqrt(2);
loF = f(1); hiF = f(end);
for j = idx:-1:1
    if mag(j) <= half; loF = f(j); break; end
end
for j = idx:numel(mag)
    if mag(j) <= half; hiF = f(j); break; end
end
r.bandwidth_hz = max(hiF - loF, 0);
if r.bandwidth_hz > 0
    r.q_factor = fHz / r.bandwidth_hz;
else
    r.q_factor = NaN;
end
end


function cand = iPromPeaks(mag, ratio, maxPeaks)
cand = [];
n = numel(mag);
for k = 2:n-1
    if mag(k) > mag(k-1) && mag(k) >= mag(k+1)
        leftValley = min(mag(1:k-1));
        rightValley = min(mag(k+1:end));
        refValley = max(leftValley, rightValley);
        if refValley <= 0; refValley = eps; end
        if mag(k)/refValley >= ratio
            cand(end+1) = k; %#ok<AGROW>
        end
    end
end
if numel(cand) > maxPeaks
    [~, order] = sort(mag(cand), "descend");
    cand = sort(cand(order(1:maxPeaks)));
end
end


function bands = iBandEnergy(f, mag)
% Fixed canonical bands matching the P3 impedance-contract labels exactly.
edges = [0 1 10 100 1000 inf];
labels = ["subsync_lt_1Hz","low_1_10Hz","mid_10_100Hz","high_100_1000Hz","vhf_gt_1000Hz"];
bands = repmat(iEmptyBand(), 1, numel(labels));
for b = 1:numel(labels)
    lo = edges(b); hi = edges(b+1);
    inBand = f >= lo & f < hi;
    bands(b).label = char(labels(b));
    bands(b).f_lo_hz = lo;
    bands(b).f_hi_hz = hi;
    bands(b).n_points = nnz(inBand);
    if any(inBand)
        bands(b).peak_magnitude = max(mag(inBand));
        bands(b).mean_magnitude = mean(mag(inBand));
    else
        bands(b).peak_magnitude = NaN;
        bands(b).mean_magnitude = NaN;
    end
end
end


function name = iBandName(fHz)
if fHz < 1
    name = "subsync_lt_1Hz";
elseif fHz < 10
    name = "low_1_10Hz";
elseif fHz < 100
    name = "mid_10_100Hz";
elseif fHz < 1000
    name = "high_100_1000Hz";
else
    name = "vhf_gt_1000Hz";
end
name = char(name);
end


function fd = iDominant(res)
if isempty(res)
    fd = NaN;
    return
end
[~, idx] = max([res.magnitude]);
fd = res(idx).frequency_hz;
end


function pass = iPassivityScreen(f, z, kind)
pass = struct("applicable", false, "negative_resistance", false, ...
    "n_negative_points", 0, "negative_band_hz", [NaN NaN], "note", "");
if kind == "response"
    pass.note = 'passivity screen N/A for generic transfer-function response';
    return
end
pass.applicable = true;
neg = real(z) < 0;
pass.n_negative_points = nnz(neg);
pass.negative_resistance = any(neg);
if any(neg)
    fn = f(neg);
    pass.negative_band_hz = [min(fn) max(fn)];
    pass.note = 'real(Z)<0 over a band: potential negative-resistance instability; confirm with time-domain';
else
    pass.note = 'real(Z)>=0 across the derived grid (passive on this analytic model)';
end
end


function [provisional, missing] = iProvisionalCheck(opts)
% Analytic evidence is provisional unless topology, operating point, and
% units are documented. FHA trust bound absence is noted separately but
% also forces provisional, since an unbounded FHA claim is not trustworthy.
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
if isnan(opts.ValidUpToHz) && isnan(opts.SwitchingHz)
    missing{end+1} = 'fha_validity_bound';
end
provisional = ~isempty(missing);
end


function r = iEmptyRes()
r = struct("frequency_hz",0, "magnitude",0, "bandwidth_hz",0, ...
    "q_factor",0, "band","", "source","");
end


function arr = iEmptyResArray()
arr = iEmptyRes();
arr = arr([]);
end


function b = iEmptyBand()
b = struct("label","", "f_lo_hz",0, "f_hi_hz",0, "n_points",0, ...
    "peak_magnitude",0, "mean_magnitude",0);
end
function iWriteOutputs(outDir, summary, f, mag, magDb, phaseDeg)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "fha_impedance_summary.json"), summary);
iWriteMarkdown(fullfile(outDir, "fha_impedance_summary.md"), summary);
iWriteCsv(fullfile(outDir, "fha_frequency_response.csv"), f, mag, magDb, phaseDeg);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("FhaImpedance:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("FhaImpedance:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Analytic FHA / Impedance Derivation Summary\n\n");
if summary.provisional
    fprintf(fid, "> **PROVISIONAL** — missing: %s. ", strjoin(summary.missing_required, ", "));
    fprintf(fid, "Analytic evidence cannot be trusted for a stability claim until documented.\n\n");
end
fprintf(fid, "Case: `%s`\n", summary.case_name);
fprintf(fid, "Evidence source: %s (model_type: %s, kind: %s)\n", ...
    summary.evidence_source, summary.model_type, summary.kind);
g = summary.frequency_grid;
fprintf(fid, "Grid: %d points over [%.4g, %.4g] Hz (%s)\n", ...
    g.n_points, g.min_hz, g.max_hz, g.spacing);
fprintf(fid, "Resonances: %d", summary.n_resonances);
if ~isnan(summary.dominant_resonance_hz)
    fprintf(fid, " | dominant ~ %.4g Hz", summary.dominant_resonance_hz);
end
fprintf(fid, "\nGenerated: %s\n\n", summary.generated_at);

fprintf(fid, "## Derivation contract\n\n");
fprintf(fid, "| Field | Value |\n|---|---|\n");
fprintf(fid, "| topology_assumptions | %s |\n", iOrUndoc(summary.topology_assumptions));
fprintf(fid, "| operating_point | %s |\n", iOrUndoc(summary.operating_point));
fprintf(fid, "| units | %s |\n", iOrUndoc(summary.units));
fprintf(fid, "| base_values | %s |\n", iOrUndoc(summary.base_values));
fprintf(fid, "| sequence_frame | %s |\n", iOrUndoc(summary.sequence_frame));
fprintf(fid, "| fundamental_hz | %.4g |\n", summary.fundamental_hz);
fprintf(fid, "| switching_hz | %s |\n", iNumOrUndoc(summary.switching_hz));
fprintf(fid, "| approximation_limits | %s |\n", iOrUndoc(summary.approximation_limits));
fprintf(fid, "| related_time_domain_run | %s |\n", iOrUndoc(summary.related_time_domain_run));
fprintf(fid, "| follow_up_required | %s |\n\n", iOrUndoc(summary.follow_up_required));

fha = summary.fha_validity;
fprintf(fid, "## FHA validity band\n\n");
fprintf(fid, "- valid from: %.4g Hz\n", fha.valid_from_hz);
fprintf(fid, "- valid up to: %s (basis: %s)\n", iNumOrUndoc(fha.valid_up_to_hz), iOrUndoc(string(fha.basis)));
fprintf(fid, "- in-band grid fraction: %s\n", iNumOrUndoc(fha.in_band_fraction));
fprintf(fid, "- %s\n\n", fha.note);

fprintf(fid, "## Resonances\n\n");
if summary.n_resonances == 0
    fprintf(fid, "_No analytic poles or prominent peaks within the grid._\n\n");
else
    fprintf(fid, "| Freq Hz | Magnitude | Bandwidth Hz | Q | Band | Source |\n");
    fprintf(fid, "|---:|---:|---:|---:|---|---|\n");
    for k = 1:numel(summary.resonances)
        r = summary.resonances(k);
        fprintf(fid, "| %.5g | %.5g | %.4g | %.4g | %s | %s |\n", ...
            r.frequency_hz, r.magnitude, r.bandwidth_hz, r.q_factor, r.band, r.source);
    end
    fprintf(fid, "\n");
end

fprintf(fid, "## Frequency bands\n\n");
fprintf(fid, "| Band | f_lo Hz | f_hi Hz | N | Peak mag | Mean mag |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|\n");
for k = 1:numel(summary.frequency_bands)
    b = summary.frequency_bands(k);
    fprintf(fid, "| %s | %.4g | %.4g | %d | %.5g | %.5g |\n", ...
        b.label, b.f_lo_hz, b.f_hi_hz, b.n_points, b.peak_magnitude, b.mean_magnitude);
end
fprintf(fid, "\n");

ps = summary.passivity;
fprintf(fid, "## Passivity screen\n\n");
if ps.applicable
    fprintf(fid, "- negative resistance: %d (points: %d)\n", ...
        ps.negative_resistance, ps.n_negative_points);
    if ps.negative_resistance
        fprintf(fid, "- negative-resistance band: [%.4g, %.4g] Hz\n", ...
            ps.negative_band_hz(1), ps.negative_band_hz(2));
    end
end
fprintf(fid, "- %s\n\n", ps.note);

fprintf(fid, "## Limitations\n\n%s\n", summary.limitations);
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
    s = '_(undocumented)_';
else
    s = sprintf('%.4g', v);
end
end


function iWriteCsv(path, f, mag, magDb, phaseDeg)
FrequencyHz = f(:);
Magnitude = mag(:);
MagnitudeDb = magDb(:);
PhaseDeg = phaseDeg(:);
T = table(FrequencyHz, Magnitude, MagnitudeDb, PhaseDeg);
writetable(T, path);
end
