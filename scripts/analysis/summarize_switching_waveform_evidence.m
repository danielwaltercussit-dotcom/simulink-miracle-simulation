function summary = summarize_switching_waveform_evidence(timeS, waveform, varargin)
%SUMMARIZE_SWITCHING_WAVEFORM_EVIDENCE Summarize switching-level EMT evidence.
%
%   summary = summarize_switching_waveform_evidence(timeS, waveform, ...
%       "CaseName","case1", "FundamentalHz",50, "CarrierHz",5000, ...
%       "SampleTimeS",2e-6, "ModulationMethod","SVPWM", "OutputDir",dir)
%
%   Inputs
%     timeS     real vector, ascending, uniform fixed-step time stamps (s).
%     waveform  real vector, same length. Interpretation set by "Signal":
%                 "current"  a converter current (A or pu)
%                 "voltage"  a converter/terminal voltage (V or pu)
%                 "signal"   a generic time signal
%
%   This helper produces SWITCHING-LEVEL EVIDENCE (THD, harmonics, carrier-band
%   content, ripple, and discretization adequacy) from a waveform the caller
%   already has (a Simulink EMT run or a captured trace). It deliberately does
%   NOT run a Simulink model itself, and it does NOT claim hardware-level
%   validation. A waveform proves only what its sample rate resolves; aliased or
%   undersampled content is not harmonic evidence. Confirm physical claims with
%   the documented fidelity decision and, where relevant, averaged-model and
%   impedance evidence.
%
%   See .agents/skills/emt-switching-level-converter/references/switching-evidence-contract.md

arguments
    timeS double {mustBeVector}
    waveform double {mustBeVector}
end
arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
[t, x, ts_inferred] = iNormalizeInputs(timeS, waveform);

[provisional, missingReq, sampleTimeUsed, stDocumented, stMismatch] = ...
    iResolveMetadata(opts, ts_inferred);

summary = struct();
summary.case_name = char(opts.CaseName);
summary.signal = char(opts.Signal);
summary.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));
summary.n_samples = numel(t);
summary.duration_s = t(end) - t(1);
summary.inferred_sample_time_s = ts_inferred;
summary.sample_time_used_s = sampleTimeUsed;
summary.sample_time_documented = stDocumented;
summary.sample_time_mismatch = stMismatch;
summary.metadata = iMetadataStruct(opts, sampleTimeUsed);
summary.provisional = provisional;
summary.missing_required = missingReq;
[summary.provenance, summary.model_backed, summary.provenance_downgraded] = ...
    iResolveProvenance(opts);

if numel(t) < 8
    summary.status = "MISSING";
    summary.spectrum = iEmptySpectrum();
    summary.carrier_band = iEmptyCarrier("waveform too short to transform");
    summary.ripple = iEmptyRipple("waveform too short");
    summary.adequacy = iAdequacy(opts.CarrierHz, sampleTimeUsed, ...
        opts.DeadTimeS, opts.FundamentalHz, opts.MaxHarmonic, stMismatch);
    summary.fundamental_well_located = false;
    summary.limitations = char(opts.LimitationsNote);
    summary.status = char(summary.status);
    if strlength(opts.OutputDir) > 0
        iWriteOutputs(opts.OutputDir, summary, [], []);
    end
    return
end

[fOne, magOne] = iOneSidedSpectrum(x, sampleTimeUsed);
[spectrum, located] = iSpectrumMetrics(fOne, magOne, opts.FundamentalHz, ...
    opts.MaxHarmonic);
carrier = iCarrierBand(fOne, magOne, opts.CarrierHz, spectrum.fundamental_magnitude);
ripple = iRippleMetric(t, x, opts.FundamentalHz, opts.TransientEventWindowS);
adequacy = iAdequacy(opts.CarrierHz, sampleTimeUsed, opts.DeadTimeS, ...
    opts.FundamentalHz, opts.MaxHarmonic, stMismatch);

summary.spectrum = spectrum;
summary.carrier_band = carrier;
summary.ripple = ripple;
summary.adequacy = adequacy;
summary.fundamental_well_located = located;
summary.status = char(iStatus(provisional, adequacy, located));
summary.limitations = char(opts.LimitationsNote);

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, summary, fOne, magOne);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("CaseName", "switching_case", @(x) ischar(x) || isstring(x));
p.addParameter("Signal", "signal", @(x) ischar(x) || isstring(x));
p.addParameter("FundamentalHz", 50, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("CarrierHz", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("SampleTimeS", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("Solver", "", @(x) ischar(x) || isstring(x));
p.addParameter("SolverStepS", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("DeadTimeS", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("ModulationMethod", "", @(x) ischar(x) || isstring(x));
p.addParameter("DeviceLossMode", "ideal", @(x) ischar(x) || isstring(x));
p.addParameter("TransientEventWindowS", [], @(x) isnumeric(x) && (isempty(x) || numel(x)==2));
p.addParameter("MaxHarmonic", 50, @(x) isnumeric(x) && isscalar(x) && x >= 2);
p.addParameter("Units", "", @(x) ischar(x) || isstring(x));
p.addParameter("BaseValue", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("SourceModelOrScript", "", @(x) ischar(x) || isstring(x));
p.addParameter("RelatedAveragedRun", "", @(x) ischar(x) || isstring(x));
p.addParameter("Provenance", struct(), @(x) isstruct(x));
p.addParameter("ModelBacked", false, @(x) islogical(x) || (isnumeric(x) && isscalar(x)));
p.addParameter("SampleTimeMismatchTol", 0.05, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("OutputDir", "", @(x) ischar(x) || isstring(x));
p.addParameter("LimitationsNote", ...
    "Switching evidence from a supplied waveform; resolves only what the sample rate captures and is not hardware-validated. Confirm with the fidelity decision and averaged/impedance evidence.", ...
    @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.CaseName = string(opts.CaseName);
opts.Signal = lower(string(opts.Signal));
opts.Solver = string(opts.Solver);
opts.ModulationMethod = string(opts.ModulationMethod);
opts.DeviceLossMode = lower(string(opts.DeviceLossMode));
opts.Units = string(opts.Units);
opts.SourceModelOrScript = string(opts.SourceModelOrScript);
opts.RelatedAveragedRun = string(opts.RelatedAveragedRun);
opts.ModelBacked = logical(opts.ModelBacked);
opts.OutputDir = string(opts.OutputDir);
opts.LimitationsNote = string(opts.LimitationsNote);
if ~ismember(opts.Signal, ["current","voltage","signal"])
    opts.Signal = "signal";
end
end


function [t, x, tsInferred] = iNormalizeInputs(timeS, waveform)
t = double(timeS(:));
x = double(waveform(:));
if numel(t) ~= numel(x)
    error("SwitchingSummary:LengthMismatch", ...
        "timeS (%d) and waveform (%d) must have equal length.", numel(t), numel(x));
end
if numel(t) < 2
    error("SwitchingSummary:TooFewPoints", "Need at least 2 time samples.");
end
if any(diff(t) <= 0)
    [t, order] = sort(t);
    x = x(order);
end
dt = diff(t);
tsInferred = median(dt);
if tsInferred <= 0
    error("SwitchingSummary:BadTimeGrid", "Inferred sample time is non-positive.");
end
end


function mustBeVector(x)
if ~isvector(x) || isscalar(x)
    error("SwitchingSummary:NotVector", "Input must be a vector with 2+ elements.");
end
end


function [provisional, missingReq, sampleTimeUsed, stDocumented, stMismatch] = iResolveMetadata(opts, tsInferred)
% Carrier, sample time, and modulation method are the trust-critical metadata.
% A documented sample time is preferred; otherwise fall back to the inferred
% grid step but record that it was undocumented. A documented sample time that
% disagrees with the actual time grid is stale/mismatched metadata and is
% reported via stMismatch so the caller can downgrade trust.
missingReq = {};
if isnan(opts.CarrierHz) || opts.CarrierHz <= 0
    missingReq{end+1} = 'carrier_hz';
end
if strlength(opts.ModulationMethod) == 0
    missingReq{end+1} = 'modulation_method';
end
stMismatch = struct("flagged", false, "declared_s", NaN, "inferred_s", tsInferred, ...
    "rel_error", NaN, "tol", opts.SampleTimeMismatchTol);
stDocumented = ~isnan(opts.SampleTimeS) && opts.SampleTimeS > 0;
if stDocumented
    sampleTimeUsed = opts.SampleTimeS;
    relErr = abs(opts.SampleTimeS - tsInferred) / tsInferred;
    stMismatch.declared_s = opts.SampleTimeS;
    stMismatch.rel_error = relErr;
    if relErr > opts.SampleTimeMismatchTol
        % The declared step does not match the waveform's own grid. Trust the
        % grid for the spectrum (so the FFT frequency axis stays correct) but
        % flag the metadata as stale/mismatched.
        stMismatch.flagged = true;
        sampleTimeUsed = tsInferred;
    end
else
    missingReq{end+1} = 'sample_time_s';
    sampleTimeUsed = tsInferred;
end
provisional = ~isempty(missingReq);
end


function m = iMetadataStruct(opts, sampleTimeUsed)
m = struct();
m.source_model_or_script = char(opts.SourceModelOrScript);
m.fundamental_hz = opts.FundamentalHz;
m.carrier_hz = opts.CarrierHz;
m.sample_time_s = sampleTimeUsed;
m.solver = char(opts.Solver);
m.solver_step_s = opts.SolverStepS;
m.dead_time_s = opts.DeadTimeS;
m.modulation_method = char(opts.ModulationMethod);
m.device_loss_mode = char(opts.DeviceLossMode);
m.units = char(opts.Units);
m.base_value = opts.BaseValue;
if isempty(opts.TransientEventWindowS)
    m.transient_event_window_s = [NaN NaN];
else
    m.transient_event_window_s = double(opts.TransientEventWindowS(:)');
end
m.related_averaged_run = char(opts.RelatedAveragedRun);
m.max_harmonic = opts.MaxHarmonic;
end


function [f, mag] = iOneSidedSpectrum(x, ts)
% One-sided amplitude spectrum via base-MATLAB fft (no toolbox). Amplitudes are
% scaled so a pure sinusoid of amplitude A reports ~A at its bin.
x = x - mean(x);                 % remove DC so it does not dominate
n = numel(x);
w = hann(n);                     % reduce spectral leakage; local hann below
xw = x .* w;
ampCorr = n / sum(w);            % coherent-gain correction for the window
X = fft(xw);
half = floor(n/2) + 1;
mag = abs(X(1:half)) / n * 2 * ampCorr;
mag(1) = mag(1) / 2;             % DC bin is not doubled
fs = 1 / ts;
f = (0:half-1)' * fs / n;
end


function w = hann(n)
% Local Hann window so the helper does not need the Signal Processing Toolbox.
if n == 1
    w = 1;
    return
end
k = (0:n-1)';
w = 0.5 - 0.5 * cos(2*pi*k/(n-1));
end


function [s, located] = iSpectrumMetrics(f, mag, fundHz, maxHarmonic)
% Locate the fundamental as the largest bin within +/-20% of fundHz, then sum
% harmonic bins for THD. Pure base-MATLAB.
s = iEmptySpectrum();
band = abs(f - fundHz) <= 0.2 * fundHz;
if ~any(band)
    located = false;
    return
end
idxBand = find(band);
[~, rel] = max(mag(idxBand));
kFund = idxBand(rel);
fundMag = mag(kFund);
located = fundMag > 0 && f(kFund) > 0;
if ~located
    return
end
s.fundamental_hz = f(kFund);
s.fundamental_magnitude = fundMag;
fs2 = f(end);                    % Nyquist
df = f(2) - f(1);
harmMag2 = 0;
harmRows = iEmptyHarmonicArray();
nH = 0;
for h = 2:maxHarmonic
    fh = h * s.fundamental_hz;
    if fh > fs2
        break
    end
    kh = round(fh / df) + 1;
    lo = max(kh-1, 1); hi = min(kh+1, numel(mag));
    mh = max(mag(lo:hi));
    harmMag2 = harmMag2 + mh^2;
    if mh / fundMag >= 0.01      % record harmonics >= 1% of fundamental
        nH = nH + 1;
        harmRows(nH) = iBuildHarmonic(h, fh, mh, mh / fundMag);
    end
end
s.thd_fraction = sqrt(harmMag2) / fundMag;
s.thd_percent = 100 * s.thd_fraction;
s.n_harmonics_reported = nH;
if nH > 0
    s.harmonics = harmRows(1:nH);
end
end


function hrow = iBuildHarmonic(order, fh, mag, frac)
hrow = struct("order", order, "frequency_hz", fh, "magnitude", mag, ...
    "fraction_of_fundamental", frac);
end


function c = iCarrierBand(f, mag, carrierHz, fundMag)
% Magnitude near the carrier and its first two sidebands, relative to the
% fundamental. N/A when the carrier is undocumented or above Nyquist.
if isnan(carrierHz) || carrierHz <= 0
    c = iEmptyCarrier("carrier undocumented; carrier-band screen N/A");
    return
end
if carrierHz > f(end)
    c = iEmptyCarrier("carrier above Nyquist; not resolved by this grid");
    c.carrier_hz = carrierHz;
    return
end
c = iEmptyCarrier("");
c.applicable = true;
c.carrier_hz = carrierHz;
df = f(2) - f(1);
kc = round(carrierHz / df) + 1;
lo = max(kc-2, 1); hi = min(kc+2, numel(mag));
c.carrier_magnitude = max(mag(lo:hi));
if fundMag > 0
    c.carrier_to_fundamental = c.carrier_magnitude / fundMag;
else
    c.carrier_to_fundamental = NaN;
end
if c.carrier_to_fundamental >= 0.5
    c.note = 'carrier-band magnitude rivals fundamental; review filter/modulation design';
else
    c.note = 'carrier-band content present and resolved';
end
end


function r = iRippleMetric(t, x, fundHz, windowS)
% Peak-to-peak and RMS of the fundamental-removed signal over the event window
% (or the whole record if no window supplied). The fundamental (and DC) is
% removed by a least-squares fit of [1, sin(w0 t), cos(w0 t)], so the residual
% is the harmonic + switching ripple. Pure base-MATLAB.
if isempty(windowS)
    sel = true(size(t));
    r = iEmptyRipple("whole record (no event window supplied)");
else
    sel = t >= windowS(1) & t <= windowS(2);
    r = iEmptyRipple(sprintf("event window [%.4g, %.4g] s", windowS(1), windowS(2)));
end
if nnz(sel) < 4
    r.note = [r.note, ' - too few samples in window'];
    return
end
ts = t(sel);
xs = x(sel);
w0 = 2 * pi * fundHz;
basis = [ones(numel(ts),1), sin(w0*ts), cos(w0*ts)];
coef = basis \ xs;
ac = xs - basis * coef;          % fundamental + DC removed
r.applicable = true;
r.n_points = numel(xs);
r.peak_to_peak = max(ac) - min(ac);
r.rms = sqrt(mean(ac.^2));
end


function a = iAdequacy(carrierHz, ts, deadTimeS, fundHz, maxHarmonic, stMismatch)
a = struct();
a.nyquist_hz = 1 / (2 * ts);
a.max_harmonic_of_interest_hz = maxHarmonic * fundHz;
a.resolves_max_harmonic = a.max_harmonic_of_interest_hz <= a.nyquist_hz;
a.flags = {};
if ~isnan(carrierHz) && carrierHz > 0
    a.samples_per_carrier = 1 / (carrierHz * ts);
    if a.samples_per_carrier < 20
        a.flags{end+1} = 'undersampled_carrier';
    end
    if carrierHz > a.nyquist_hz
        a.flags{end+1} = 'carrier_above_nyquist';
    end
else
    a.samples_per_carrier = NaN;
end
if ~a.resolves_max_harmonic
    a.flags{end+1} = 'aliasing_risk_max_harmonic';
end
if ~isnan(deadTimeS) && deadTimeS > 0
    a.deadtime_steps = deadTimeS / ts;
    if a.deadtime_steps < 1
        a.flags{end+1} = 'deadtime_below_one_step';
    end
else
    a.deadtime_steps = NaN;
end
if nargin >= 6 && isstruct(stMismatch) && stMismatch.flagged
    a.flags{end+1} = 'sample_time_mismatch';
end
a.adequate = isempty(a.flags);
end


function [prov, modelBacked, downgraded] = iResolveProvenance(opts)
% Establish provenance and the final model_backed flag with an explicit
% downgrade rule. model_backed is true only when the caller both asserts it AND
% supplies sufficient provenance to back the claim:
%   - source_type is a model/simulation source (simulation_output | mat_file),
%   - a model or source identifier is recorded,
%   - the run is not marked synthetic.
% Any shortfall forces model_backed=false and records a downgrade reason, so a
% synthetic or weakly-sourced run can never overclaim model-level evidence.
prov = iNormalizeProvenance(opts.Provenance, opts.SourceModelOrScript);
asserted = opts.ModelBacked;
reasons = {};
modelSource = ismember(prov.source_type, ["simulation_output", "mat_file"]);
if ~asserted
    reasons{end+1} = 'model_backed not asserted by caller';
end
if ~modelSource
    reasons{end+1} = sprintf('source_type "%s" is not a model/simulation source', prov.source_type);
end
if strlength(string(prov.source_id)) == 0
    reasons{end+1} = 'no model/source identifier recorded';
end
if prov.synthetic
    reasons{end+1} = 'run flagged synthetic';
end
modelBacked = asserted && modelSource && strlength(string(prov.source_id)) > 0 && ~prov.synthetic;
downgraded = asserted && ~modelBacked;
prov.model_backed_asserted = asserted;
prov.downgrade_reasons = reasons;
if modelBacked
    prov.evidence_level = "model_backed";
elseif modelSource && ~prov.synthetic
    prov.evidence_level = "model_referenced";
else
    prov.evidence_level = "contract_only";
end
prov.evidence_level = char(prov.evidence_level);
end


function prov = iNormalizeProvenance(raw, fallbackSource)
% Coerce a free-form provenance struct into a stable schema. Unknown source
% types collapse to "synthetic" so an unrecognised tag never reads as a model.
prov = struct("source_type", "synthetic", "source_id", "", "source_path", "", ...
    "model_name", "", "simulated", false, "synthetic", true, ...
    "captured_at", "", "notes", "");
fn = fieldnames(raw);
for k = 1:numel(fn)
    key = lower(fn{k});
    val = raw.(fn{k});
    switch key
        case "source_type";  prov.source_type = lower(string(val));
        case "source_id";    prov.source_id = string(val);
        case "source_path";  prov.source_path = string(val);
        case "model_name";   prov.model_name = string(val);
        case "simulated";    prov.simulated = logical(val);
        case "synthetic";    prov.synthetic = logical(val);
        case "captured_at";  prov.captured_at = string(val);
        case "notes";        prov.notes = string(val);
    end
end
known = ["simulation_output", "mat_file", "generated", "synthetic", "captured"];
if ~ismember(prov.source_type, known)
    prov.source_type = "synthetic";
end
if prov.source_type == "synthetic"
    prov.synthetic = true;
end
if strlength(prov.source_id) == 0 && strlength(prov.model_name) > 0
    prov.source_id = prov.model_name;
end
if strlength(prov.source_id) == 0 && strlength(string(fallbackSource)) > 0
    prov.source_id = string(fallbackSource);
end
prov.source_type = char(prov.source_type);
prov.source_id = char(prov.source_id);
prov.source_path = char(prov.source_path);
prov.model_name = char(prov.model_name);
prov.captured_at = char(prov.captured_at);
prov.notes = char(prov.notes);
end


function st = iStatus(provisional, adequacy, located)
if provisional || ~adequacy.adequate || ~located
    st = "WARN";
else
    st = "PASS";
end
end


function s = iEmptySpectrum()
s = struct("fundamental_hz", NaN, "fundamental_magnitude", 0, ...
    "thd_fraction", NaN, "thd_percent", NaN, "n_harmonics_reported", 0, ...
    "harmonics", iEmptyHarmonicArray());
end


function h = iEmptyHarmonic()
h = struct("order", 0, "frequency_hz", 0, "magnitude", 0, ...
    "fraction_of_fundamental", 0);
end


function arr = iEmptyHarmonicArray()
arr = iEmptyHarmonic();
arr = arr([]);
end


function c = iEmptyCarrier(note)
c = struct("applicable", false, "carrier_hz", NaN, "carrier_magnitude", NaN, ...
    "carrier_to_fundamental", NaN, "note", note);
end


function r = iEmptyRipple(note)
r = struct("applicable", false, "n_points", 0, "peak_to_peak", NaN, ...
    "rms", NaN, "note", note);
end


function iWriteOutputs(outDir, summary, f, mag)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "switching_summary.json"), summary);
iWriteMarkdown(fullfile(outDir, "switching_summary.md"), summary);
iWriteCsv(fullfile(outDir, "switching_spectrum.csv"), f, mag);
end


function iWriteJson(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("SwitchingSummary:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(summary, "PrettyPrint", true));
end


function iWriteMarkdown(path, summary)
fid = fopen(path, "w");
if fid < 0
    error("SwitchingSummary:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
m = summary.metadata;
fprintf(fid, "# Switching-Level EMT Waveform Summary\n\n");
if summary.provisional
    fprintf(fid, "> **PROVISIONAL** - missing required metadata: %s. ", ...
        strjoin(summary.missing_required, ", "));
    fprintf(fid, "Do not use for harmonic, loss, or protection claims.\n\n");
end
if isfield(summary, 'sample_time_mismatch') && summary.sample_time_mismatch.flagged
    sm = summary.sample_time_mismatch;
    fprintf(fid, "> **SAMPLE-TIME MISMATCH** - declared %.4g s vs grid %.4g s ", ...
        sm.declared_s, sm.inferred_s);
    fprintf(fid, "(%.1f%% > %.1f%% tol). Metadata is stale; spectrum uses the grid step.\n\n", ...
        100*sm.rel_error, 100*sm.tol);
end
if isfield(summary, 'provenance_downgraded') && summary.provenance_downgraded
    fprintf(fid, "> **PROVENANCE DOWNGRADE** - model_backed asserted but not supported: %s. ", ...
        strjoin(summary.provenance.downgrade_reasons, "; "));
    fprintf(fid, "Forced model_backed=false.\n\n");
end
fprintf(fid, "Case: `%s`\n", summary.case_name);
fprintf(fid, "Signal: %s | Status: **%s**\n", summary.signal, summary.status);
if isfield(summary, 'model_backed')
    fprintf(fid, "Evidence level: **%s** | model_backed: %d\n", ...
        summary.provenance.evidence_level, summary.model_backed);
end
fprintf(fid, "Samples: %d over %.4g s (sample time %.4g s%s)\n", ...
    summary.n_samples, summary.duration_s, summary.sample_time_used_s, ...
    iDocTag(summary.sample_time_documented));
fprintf(fid, "Generated: %s\n\n", summary.generated_at);

fprintf(fid, "## Required metadata\n\n");
fprintf(fid, "| Field | Value |\n|---|---|\n");
fprintf(fid, "| source_model_or_script | %s |\n", iOrDash(m.source_model_or_script));
fprintf(fid, "| fundamental_hz | %.6g |\n", m.fundamental_hz);
fprintf(fid, "| carrier_hz | %s |\n", iNumOrDash(m.carrier_hz));
fprintf(fid, "| sample_time_s | %.4g |\n", m.sample_time_s);
fprintf(fid, "| solver | %s |\n", iOrDash(m.solver));
fprintf(fid, "| solver_step_s | %s |\n", iNumOrDash(m.solver_step_s));
fprintf(fid, "| dead_time_s | %s |\n", iNumOrDash(m.dead_time_s));
fprintf(fid, "| modulation_method | %s |\n", iOrDash(m.modulation_method));
fprintf(fid, "| device_loss_mode | %s |\n", iOrDash(m.device_loss_mode));
fprintf(fid, "| units | %s |\n", iOrDash(m.units));
fprintf(fid, "| transient_event_window_s | [%s, %s] |\n", ...
    iNumOrDash(m.transient_event_window_s(1)), iNumOrDash(m.transient_event_window_s(2)));
fprintf(fid, "| related_averaged_run | %s |\n\n", iOrDash(m.related_averaged_run));

iWriteSpectrumSection(fid, summary);
iWriteCarrierSection(fid, summary.carrier_band);
iWriteRippleSection(fid, summary.ripple, summary.metadata.device_loss_mode);
iWriteAdequacySection(fid, summary.adequacy);
iWriteProvenanceSection(fid, summary);

fprintf(fid, "## Limitations\n\n%s\n", summary.limitations);
end


function iWriteProvenanceSection(fid, summary)
if ~isfield(summary, 'provenance')
    return
end
p = summary.provenance;
fprintf(fid, "## Provenance\n\n");
fprintf(fid, "- evidence level: **%s** | model_backed: %d (asserted: %d)\n", ...
    p.evidence_level, summary.model_backed, p.model_backed_asserted);
fprintf(fid, "- source_type: %s | source_id: %s\n", ...
    iOrDash(p.source_type), iOrDash(p.source_id));
if ~isempty(p.source_path)
    fprintf(fid, "- source_path: %s\n", p.source_path);
end
if summary.provenance_downgraded
    fprintf(fid, "- downgrade: %s\n", strjoin(p.downgrade_reasons, "; "));
end
if ~strcmp(p.evidence_level, 'model_backed')
    fprintf(fid, "- NOTE: not model-backed; treat as %s evidence, not a model/hardware validation.\n", ...
        p.evidence_level);
end
fprintf(fid, "\n");
end


function iWriteSpectrumSection(fid, summary)
s = summary.spectrum;
fprintf(fid, "## Spectrum / THD\n\n");
if ~summary.fundamental_well_located
    fprintf(fid, "_Fundamental not well located near %.6g Hz; THD not reported._\n\n", ...
        summary.metadata.fundamental_hz);
    return
end
fprintf(fid, "- fundamental: %.6g Hz, magnitude %.5g\n", ...
    s.fundamental_hz, s.fundamental_magnitude);
fprintf(fid, "- THD: %.4g %% (%.4g fraction), %d harmonic(s) >= 1%%\n\n", ...
    s.thd_percent, s.thd_fraction, s.n_harmonics_reported);
if s.n_harmonics_reported > 0
    fprintf(fid, "| Order | Freq Hz | Magnitude | %% of fundamental |\n");
    fprintf(fid, "|---:|---:|---:|---:|\n");
    for k = 1:numel(s.harmonics)
        h = s.harmonics(k);
        fprintf(fid, "| %d | %.6g | %.5g | %.3g |\n", ...
            h.order, h.frequency_hz, h.magnitude, 100*h.fraction_of_fundamental);
    end
    fprintf(fid, "\n");
end
end


function iWriteCarrierSection(fid, c)
fprintf(fid, "## Carrier band\n\n");
if ~c.applicable
    fprintf(fid, "- %s\n\n", c.note);
    return
end
fprintf(fid, "- carrier: %.6g Hz, magnitude %.5g (%.3g x fundamental)\n", ...
    c.carrier_hz, c.carrier_magnitude, c.carrier_to_fundamental);
fprintf(fid, "- %s\n\n", c.note);
end


function iWriteRippleSection(fid, r, lossMode)
fprintf(fid, "## Ripple\n\n");
if r.applicable
    fprintf(fid, "- over %s: pk-pk %.5g, RMS %.5g (N=%d)\n\n", ...
        r.note, r.peak_to_peak, r.rms, r.n_points);
else
    fprintf(fid, "- %s\n\n", r.note);
end
if strcmp(lossMode, 'ideal')
    fprintf(fid, "_Device loss: N/A (ideal switches; a loss claim needs a non-ideal device model)._\n\n");
end
end


function iWriteAdequacySection(fid, a)
fprintf(fid, "## Discretization adequacy\n\n");
fprintf(fid, "- samples per carrier: %s\n", iNumOrDash(a.samples_per_carrier));
fprintf(fid, "- Nyquist: %.5g Hz | max harmonic of interest: %.5g Hz (resolved: %d)\n", ...
    a.nyquist_hz, a.max_harmonic_of_interest_hz, a.resolves_max_harmonic);
fprintf(fid, "- dead-time steps: %s\n", iNumOrDash(a.deadtime_steps));
if a.adequate
    fprintf(fid, "- adequate: yes\n\n");
else
    fprintf(fid, "- adequate: no - flags: %s\n\n", strjoin(a.flags, ", "));
end
end


function iWriteCsv(path, f, mag)
if isempty(f)
    FrequencyHz = zeros(0,1);
    Magnitude = zeros(0,1);
else
    FrequencyHz = f(:);
    Magnitude = mag(:);
end
T = table(FrequencyHz, Magnitude);
writetable(T, path);
end


function s = iDocTag(documented)
if documented; s = ""; else; s = ", inferred/undocumented"; end
end


function s = iOrDash(v)
if isempty(char(v)); s = "-"; else; s = char(v); end
end


function s = iNumOrDash(v)
if isempty(v) || isnan(v); s = "-"; else; s = sprintf("%.4g", v); end
end
