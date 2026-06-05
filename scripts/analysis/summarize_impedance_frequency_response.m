function summary = summarize_impedance_frequency_response(frequencyHz, response, varargin)
%SUMMARIZE_IMPEDANCE_FREQUENCY_RESPONSE Summarize impedance/frequency evidence.
%
%   summary = summarize_impedance_frequency_response(frequencyHz, response, ...
%       "CaseName","case1", "Kind","impedance", "OutputDir",dir)
%
%   Inputs
%     frequencyHz  real vector, strictly positive, ascending. Frequency grid.
%     response     complex vector, same length. Interpretation set by "Kind":
%                    "impedance"  positive-sequence Z(f) in ohms (or pu)
%                    "admittance" positive-sequence Y(f); converted to Z=1/Y
%                    "response"   a generic transfer-function-like response
%                                 (magnitude peaks flagged; no Z/Y physics)
%
%   This helper produces FREQUENCY-DOMAIN EVIDENCE from data the caller already
%   has (measured sweep, simulated injection sweep, or an analytic transfer
%   function). It deliberately does NOT run a Simulink sweep itself, and it does
%   NOT claim hardware-level validation. Resonance peaks here are spectral
%   features of the supplied data; mapping them to a physical instability still
%   needs time-domain (EMT/RMS) and, where available, modal evidence.
%
%   See .agents/skills/impedance-frequency-analysis/references/impedance-contract.md

arguments
    frequencyHz double {mustBeVector, mustBePositive}
    response double {mustBeVector}
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
[f, z, kind] = iNormalizeInputs(frequencyHz, response, opts.Kind);

mag = abs(z);
phaseDeg = angle(z) * 180/pi;

peaks = iFindResonancePeaks(f, mag, opts.PeakProminenceRatio, opts.MaxPeaks);
bands = iBandEnergy(f, mag, opts.BandEdgesHz);

summary = struct();
summary.case_name = char(opts.CaseName);
summary.kind = char(kind);
summary.evidence_source = char(opts.EvidenceSource);
summary.n_points = numel(f);
summary.frequency_min_hz = f(1);
summary.frequency_max_hz = f(end);
summary.peak_prominence_ratio = opts.PeakProminenceRatio;
summary.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));
summary.resonance_peaks = peaks;
summary.frequency_bands = bands;
summary.n_resonances = numel(peaks);
summary.dominant_resonance_hz = iDominant(peaks);
summary.limitations = char(opts.LimitationsNote);
summary.passivity = iPassivityScreen(f, z, kind);

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, summary, f, mag, phaseDeg);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("CaseName", "impedance_case", @(x) ischar(x) || isstring(x));
p.addParameter("Kind", "impedance", @(x) ischar(x) || isstring(x));
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("EvidenceSource", "synthetic", @(x) ischar(x) || isstring(x));
p.addParameter("PeakProminenceRatio", 1.5, @(x) isnumeric(x) && isscalar(x) && x > 1);
p.addParameter("MaxPeaks", 10, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.addParameter("BandEdgesHz", [1 10 100 1000], @(x) isnumeric(x) && isvector(x));
p.addParameter("LimitationsNote", ...
    "Spectral evidence from supplied data; not hardware-validated. Confirm with time-domain and modal evidence.", ...
    @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.CaseName = string(opts.CaseName);
opts.Kind = lower(string(opts.Kind));
opts.OutputDir = string(opts.OutputDir);
opts.EvidenceSource = string(opts.EvidenceSource);
opts.LimitationsNote = string(opts.LimitationsNote);
end


function [f, z, kind] = iNormalizeInputs(frequencyHz, response, kind)
f = double(frequencyHz(:));
r = double(response(:));
if numel(f) ~= numel(r)
    error("ImpedanceSummary:LengthMismatch", ...
        "frequencyHz (%d) and response (%d) must have equal length.", numel(f), numel(r));
end
if numel(f) < 3
    error("ImpedanceSummary:TooFewPoints", "Need at least 3 frequency points.");
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
            error("ImpedanceSummary:ZeroAdmittance", "Admittance has zero entries; cannot invert to Z.");
        end
        z = 1 ./ r;
    case "response"
        z = r;
    otherwise
        error("ImpedanceSummary:BadKind", ...
            "Kind must be 'impedance', 'admittance', or 'response'; got '%s'.", kind);
end
end


function mustBeVector(x)
if ~isvector(x) || isscalar(x)
    error("ImpedanceSummary:NotVector", "Input must be a vector with 2+ elements.");
end
end


function peaks = iFindResonancePeaks(f, mag, prominenceRatio, maxPeaks)
% Local maxima whose magnitude exceeds prominenceRatio x the larger
% neighbouring valley. Pure-MATLAB (no Signal Processing Toolbox dependency)
% so the helper runs on a base install.
peaks = iEmptyPeakArray();
n = numel(mag);
if n < 3
    return
end
cand = [];
for k = 2:n-1
    if mag(k) > mag(k-1) && mag(k) >= mag(k+1)
        cand(end+1) = k; %#ok<AGROW>
    end
end
if isempty(cand)
    return
end
keptList = iEmptyPeakArray();
nKept = 0;
for c = cand
    leftValley = min(mag(1:c-1));
    rightValley = min(mag(c+1:end));
    refValley = max(leftValley, rightValley);
    if refValley <= 0
        refValley = min(mag(mag > 0));
        if isempty(refValley); refValley = eps; end
    end
    ratio = mag(c) / refValley;
    if ratio >= prominenceRatio
        nKept = nKept + 1;
        keptList(nKept) = iBuildPeak(c, f, mag, ratio, refValley);
    end
end
if nKept == 0
    return
end
keptList = keptList(1:nKept);
[~, order] = sort([keptList.prominence_ratio], "descend");
keptList = keptList(order);
peaks = keptList(1:min(maxPeaks, nKept));
% Re-sort kept peaks by frequency for stable reporting.
[~, byFreq] = sort([peaks.frequency_hz]);
peaks = peaks(byFreq);
end


function pk = iBuildPeak(k, f, mag, ratio, refValley)
% Sharpness via a crude -3 dB (half-power in magnitude/sqrt(2)) width estimate.
pk = iEmptyPeak();
pk.index = k;
pk.frequency_hz = f(k);
pk.magnitude = mag(k);
pk.prominence_ratio = ratio;
pk.reference_valley = refValley;
half = mag(k) / sqrt(2);
loF = f(1); hiF = f(end);
for j = k:-1:1
    if mag(j) <= half; loF = f(j); break; end
end
for j = k:numel(mag)
    if mag(j) <= half; hiF = f(j); break; end
end
pk.bandwidth_hz = max(hiF - loF, 0);
if pk.bandwidth_hz > 0
    pk.q_factor = f(k) / pk.bandwidth_hz;
else
    pk.q_factor = NaN;
end
pk.band = iBandName(f(k));
end


function bands = iBandEnergy(f, mag, edges)
edges = sort(unique(double(edges(:))'));
labels = ["subsync_lt_1Hz", iBandLabels(edges)];
allEdges = [0, edges, inf];
bands = repmat(iEmptyBand(), 1, numel(allEdges)-1);
for b = 1:numel(allEdges)-1
    lo = allEdges(b); hi = allEdges(b+1);
    inBand = f >= lo & f < hi;
    bands(b).label = char(labels(min(b, numel(labels))));
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


function labels = iBandLabels(edges)
labels = strings(1, numel(edges));
for k = 1:numel(edges)
    if k < numel(edges)
        labels(k) = sprintf("band_%g_%gHz", edges(k), edges(k+1));
    else
        labels(k) = sprintf("band_gt_%gHz", edges(k));
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


function fd = iDominant(peaks)
if isempty(peaks)
    fd = NaN;
    return
end
[~, idx] = max([peaks.prominence_ratio]);
fd = peaks(idx).frequency_hz;
end


function pass = iPassivityScreen(f, z, kind)
% A converter that injects negative resistance over a band is a classic
% oscillation risk. For impedance/admittance data, real(Z)<0 is the screen.
% For generic "response" data the concept does not apply.
pass = struct("applicable", false, "negative_resistance", false, ...
    "n_negative_points", 0, "negative_band_hz", [NaN NaN], "note", "");
if kind == "response"
    pass.note = 'passivity screen N/A for generic transfer-function response';
    return
end
pass.applicable = true;
reZ = real(z);
neg = reZ < 0;
pass.n_negative_points = nnz(neg);
pass.negative_resistance = any(neg);
if any(neg)
    fn = f(neg);
    pass.negative_band_hz = [min(fn) max(fn)];
    pass.note = 'real(Z)<0 over a band: potential negative-resistance instability; confirm with time-domain';
else
    pass.note = 'real(Z)>=0 across the supplied grid (passive on this data)';
end
end


function p = iEmptyPeak()
p = struct("index",0, "frequency_hz",0, "magnitude",0, "prominence_ratio",0, ...
    "reference_valley",0, "bandwidth_hz",0, "q_factor",0, "band","");
end


function arr = iEmptyPeakArray()
arr = iEmptyPeak();
arr = arr([]);
end


function b = iEmptyBand()
b = struct("label","", "f_lo_hz",0, "f_hi_hz",0, "n_points",0, ...
    "peak_magnitude",0, "mean_magnitude",0);
end


function iWriteOutputs(outDir, summary, f, mag, phaseDeg)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "impedance_summary.json"), summary);
iWriteMarkdown(fullfile(outDir, "impedance_summary.md"), summary);
iWriteCsv(fullfile(outDir, "frequency_response.csv"), f, mag, phaseDeg);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("ImpedanceSummary:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("ImpedanceSummary:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Impedance / Frequency-Domain Summary\n\n");
fprintf(fid, "Case: `%s`\n", summary.case_name);
fprintf(fid, "Kind: %s | Evidence source: %s\n", summary.kind, summary.evidence_source);
fprintf(fid, "Points: %d over [%.4g, %.4g] Hz\n", summary.n_points, ...
    summary.frequency_min_hz, summary.frequency_max_hz);
fprintf(fid, "Resonances found: %d", summary.n_resonances);
if ~isnan(summary.dominant_resonance_hz)
    fprintf(fid, " | dominant ~ %.4g Hz", summary.dominant_resonance_hz);
end
fprintf(fid, "\nGenerated: %s\n\n", summary.generated_at);

fprintf(fid, "## Resonance peaks\n\n");
if summary.n_resonances == 0
    fprintf(fid, "_No peaks above prominence ratio %.3g._\n\n", summary.peak_prominence_ratio);
else
    fprintf(fid, "| Freq Hz | Magnitude | Prominence | Bandwidth Hz | Q | Band |\n");
    fprintf(fid, "|---:|---:|---:|---:|---:|---|\n");
    for k = 1:numel(summary.resonance_peaks)
        p = summary.resonance_peaks(k);
        fprintf(fid, "| %.5g | %.5g | %.4gx | %.4g | %.4g | %s |\n", ...
            p.frequency_hz, p.magnitude, p.prominence_ratio, ...
            p.bandwidth_hz, p.q_factor, p.band);
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


function iWriteCsv(path, f, mag, phaseDeg)
FrequencyHz = f(:);
Magnitude = mag(:);
PhaseDeg = phaseDeg(:);
T = table(FrequencyHz, Magnitude, PhaseDeg);
writetable(T, path);
end
