function report = verify_fha_dynamic_phasor_bounds(spec, varargin)
%VERIFY_FHA_DYNAMIC_PHASOR_BOUNDS Math verification of FHA / dynamic-phasor /
%   frequency-domain error bounds for analytic converter models.
%
%   report = verify_fha_dynamic_phasor_bounds(spec, "Name",value, ...)
%
%   This helper provides MATHEMATICAL verification (not model or hardware
%   validation) that a stated approximation error bound actually holds. It
%   re-checks each provable bound against a numerical computation and reports
%   one of:
%     contract_only            metadata present, no numerical bound checked
%                              (e.g. undocumented => provisional).
%     math_verified            the provable bound was numerically re-checked
%                              and HOLDS (within MathTolRel).
%     math_verification_failed the numerical quantity VIOLATES the stated bound
%                              (an honest negative result, not an error).
%   It NEVER returns a model_validated or hardware_validated grade: no Simulink
%   model is run here. Pair these certificates with an actual sim/EMT run and,
%   separately, with HIL evidence before claiming those higher grades.
%
%   spec.type selects the verification:
%
%   "harmonic_series"  FHA (fundamental-only) truncation error of a periodic
%       signal given its harmonic amplitudes.
%         spec.harmonic_index   integer vector k (>=1), fundamental is k==1
%         spec.amplitude        real vector a_k (peak amplitude per harmonic)
%         spec.phase_rad        optional phase per harmonic (default 0)
%       Verifies: THD, retained energy fraction, and the time-domain sup-norm
%       bound |e(t)| <= sum_{k>1}|a_k| (triangle inequality) against a dense
%       numerical reconstruction of the dropped harmonics.
%
%   "dynamic_phasor"  Narrowband validity + phasor truncation bound for a
%       generalized-averaging (dynamic phasor) representation
%       x(t)=sum_k X_k e^{j k ws t}.
%         spec.carrier_hz       fs (switching/carrier), ws=2*pi*fs
%         spec.envelope_bw_hz   B, one-sided envelope bandwidth of X_k(t)
%         spec.coeff_index      integer vector k
%         spec.coeff_norm       |X_k| per index (>=0); used for truncation
%         spec.keep_max_index   K, keep |k|<=K
%       Verifies: narrowband ratio fs/B vs NarrowbandRatioMin, adjacent-band
%       non-overlap (B < fs), and the Parseval truncation bound
%       rms_error == sqrt(sum_{|k|>K}|X_k|^2) against a sampled reconstruction.
%
%   "frequency_response_pair"  Frequency-domain error bound between an analytic
%       response and a reference, both on a common grid.
%         spec.frequency_hz     ascending positive grid
%         spec.z_analytic       complex analytic Z(f)
%         spec.z_reference      complex reference Z(f)
%       Verifies: sup-norm, relative sup, L2, per-band, and FHA-validity-band-
%       restricted error against SupTolRel / L2TolRel within the validity band.
%
%   See .agents/skills/analytic-fha-impedance-derivation/references/fha-impedance-contract.md

opts = iParseNameValues(varargin{:});
if ~isstruct(spec) || ~isfield(spec, "type")
    error("FhaVerify:NoSpec", "spec must be a struct with a 'type' field.");
end
specType = lower(string(spec.type));

switch specType
    case "harmonic_series"
        core = iVerifyHarmonicSeries(spec, opts);
    case "dynamic_phasor"
        core = iVerifyDynamicPhasor(spec, opts);
    case "frequency_response_pair"
        core = iVerifyFreqResponsePair(spec, opts);
    otherwise
        error("FhaVerify:BadType", ...
            "spec.type must be harmonic_series | dynamic_phasor | frequency_response_pair; got '%s'.", specType);
end

[provisional, missing] = iProvisionalCheck(spec, opts, specType);
grade = iGrade(core, provisional);

report = struct();
report.case_name = char(opts.CaseName);
report.spec_type = char(specType);
report.evidence_grade = grade;
report.bound_holds = core.bound_holds;
report.provisional = provisional;
report.missing_required = missing;
report.metrics = core.metrics;
report.bound = core.bound;
report.numeric = core.numeric;
report.verdict_note = core.note;
report.validity = core.validity;
report.math_tol_rel = opts.MathTolRel;
report.limitations = char(opts.LimitationsNote);
report.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));

if strlength(opts.OutputDir) > 0
    iWriteOutputs(opts.OutputDir, report);
end
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("CaseName", "fha_verify_case", @iIsText);
p.addParameter("MathTolRel", 1e-6, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("NarrowbandRatioMin", 5, @(x) isnumeric(x) && isscalar(x) && x > 1);
p.addParameter("SupTolRel", 0.1, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("L2TolRel", 0.1, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("ValidUpToHz", NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter("OperatingPoint", "", @iIsText);
p.addParameter("Units", "", @iIsText);
p.addParameter("Notes", "", @iIsText);
p.addParameter("OutputDir", "", @iIsText);
p.addParameter("LimitationsNote", ...
    "Mathematical bound verification only; NOT model- or hardware-validated. Confirm with sim/EMT and HIL separately.", ...
    @iIsText);
p.parse(varargin{:});
opts = p.Results;
for f = ["CaseName","OperatingPoint","Units","Notes","OutputDir","LimitationsNote"]
    opts.(f) = string(opts.(f));
end
end


function tf = iIsText(x)
tf = ischar(x) || isstring(x);
end

function core = iVerifyHarmonicSeries(spec, opts)
% FHA truncation: keep only the fundamental (k==1). The dropped-harmonic error
% e(t)=sum_{k>1} a_k cos(k w0 t + phi_k) obeys the PROVABLE sup-norm bound
% |e(t)| <= sum_{k>1}|a_k| (triangle inequality). We re-check it numerically.
[k, a, phi] = iHarmonicInputs(spec);
isFund = (k == 1);
if ~any(isFund)
    error("FhaVerify:NoFundamental", "harmonic_series needs a k==1 entry.");
end
aFund = sum(abs(a(isFund)));
dropped = ~isFund;

% THD and retained energy (power-based, standard definitions).
aHarm = a(k >= 2);
thd = sqrt(sum(aHarm.^2)) / aFund;
retained = aFund^2 / sum(a.^2);

% Provable bound and numeric reconstruction of the dropped content.
boundSup = sum(abs(a(dropped)));
N = max(4096, 8*max(k));
t = (0:N-1) / N;                 % one fundamental period, w0 = 2*pi
w0 = 2*pi;
e = zeros(1, N);
kd = k(dropped); ad = a(dropped); pd = phi(dropped);
for idx = 1:numel(kd)
    e = e + ad(idx) * cos(kd(idx)*w0*t + pd(idx));
end
numericSup = max(abs(e));

holds = numericSup <= boundSup * (1 + opts.MathTolRel) + opts.MathTolRel;

core.metrics = struct("thd", thd, "thd_pct", 100*thd, ...
    "retained_energy_fraction", retained, "n_harmonics", numel(k), ...
    "fundamental_amplitude", aFund);
core.bound = struct("type", "time_sup_norm", "value", boundSup, ...
    "basis", "triangle_inequality_sum_abs_a_k_for_k_gt_1");
core.numeric = struct("sup_norm", numericSup, "n_samples", N, ...
    "tightness_ratio", numericSup / max(boundSup, eps));
core.validity = struct("applicable", false, "note", "n/a for harmonic series");
core.bound_holds = holds;
if holds
    core.note = sprintf(['FHA dropped-harmonic sup-norm %.6g <= bound %.6g ' ...
        '(THD %.4g%%, fundamental retains %.4g%% power).'], ...
        numericSup, boundSup, 100*thd, 100*retained);
else
    core.note = sprintf(['FHA numeric sup-norm %.6g EXCEEDS triangle bound %.6g ' ...
        '(unexpected: check inputs).'], numericSup, boundSup);
end
end


function [k, a, phi] = iHarmonicInputs(spec)
if ~isfield(spec,"harmonic_index") || ~isfield(spec,"amplitude")
    error("FhaVerify:BadHarmonic", "harmonic_series needs harmonic_index and amplitude.");
end
k = double(spec.harmonic_index(:)).';
a = double(spec.amplitude(:)).';
if numel(k) ~= numel(a)
    error("FhaVerify:HarmonicLen", "harmonic_index and amplitude length mismatch.");
end
if any(k < 1) || any(mod(k,1) ~= 0)
    error("FhaVerify:HarmonicIdx", "harmonic_index must be positive integers.");
end
if isfield(spec,"phase_rad") && ~isempty(spec.phase_rad)
    phi = double(spec.phase_rad(:)).';
    if numel(phi) ~= numel(k)
        error("FhaVerify:PhaseLen", "phase_rad length must match harmonic_index.");
    end
else
    phi = zeros(1, numel(k));
end
end


function core = iVerifyDynamicPhasor(spec, opts)
% Dynamic phasor x(t)=sum_k X_k e^{j k ws t}. Two facts are verified:
%   1) narrowband validity: envelope bandwidth B must keep adjacent carrier
%      bands from overlapping, i.e. 2B < fs (B < fs/2); a stronger separation
%      fs/B >= NarrowbandRatioMin is the documented trust threshold.
%   2) truncation identity (Parseval): keeping |k|<=K, the RMS reconstruction
%      error equals sqrt(sum_{|k|>K}|X_k|^2) exactly. We re-check numerically.
[fs, B, k, Xn, K] = iPhasorInputs(spec);
ws = 2*pi*fs;

ratio = fs / B;
nonOverlap = (2*B < fs);
narrowOk = (ratio >= opts.NarrowbandRatioMin) && nonOverlap;

dropped = abs(k) > K;
boundRms = sqrt(sum(Xn(dropped).^2));

% Numeric reconstruction over one carrier period; discrete orthogonality is
% exact when N > 2*max|k|, so phase choice is irrelevant -> use real X_k.
N = max(64, 4*max(abs(k)) + 4);
t = (0:N-1) / N / fs;            % one period T = 1/fs
xFull = zeros(1, N); xTrunc = zeros(1, N);
for idx = 1:numel(k)
    e = Xn(idx) * exp(1j * k(idx) * ws * t);
    xFull = xFull + e;
    if abs(k(idx)) <= K
        xTrunc = xTrunc + e;
    end
end
rmsNum = sqrt(mean(abs(xFull - xTrunc).^2));
parsevalOk = abs(rmsNum - boundRms) <= opts.MathTolRel * (1 + boundRms);

holds = parsevalOk && narrowOk;

core.metrics = struct("narrowband_ratio_fs_over_B", ratio, ...
    "carrier_hz", fs, "envelope_bw_hz", B, "keep_max_index", K, ...
    "n_coeffs", numel(k), "n_dropped", nnz(dropped));
core.bound = struct("type", "parseval_truncation_rms", "value", boundRms, ...
    "basis", "sqrt_sum_abs_Xk_sq_for_abs_k_gt_K");
core.numeric = struct("rms_error", rmsNum, "n_samples", N, ...
    "parseval_residual", abs(rmsNum - boundRms));
core.validity = struct("applicable", true, "narrowband_valid", narrowOk, ...
    "non_overlap_2B_lt_fs", nonOverlap, "ratio_min", opts.NarrowbandRatioMin);
core.bound_holds = holds;
if ~parsevalOk
    core.note = sprintf(['Parseval truncation identity FAILED: numeric RMS %.6g ' ...
        'vs bound %.6g.'], rmsNum, boundRms);
elseif ~narrowOk
    core.note = sprintf(['Truncation RMS identity holds (%.4g), but narrowband ' ...
        'validity FAILED: fs/B=%.4g (min %.4g), 2B<fs=%d. Dynamic-phasor ' ...
        'representation not trustworthy here.'], ...
        rmsNum, ratio, opts.NarrowbandRatioMin, nonOverlap);
else
    core.note = sprintf(['Narrowband valid (fs/B=%.4g) and Parseval truncation ' ...
        'RMS %.6g == bound %.6g.'], ratio, rmsNum, boundRms);
end
end


function [fs, B, k, Xn, K] = iPhasorInputs(spec)
req = ["carrier_hz","envelope_bw_hz","coeff_index","coeff_norm","keep_max_index"];
for r = req
    if ~isfield(spec, r)
        error("FhaVerify:BadPhasor", "dynamic_phasor needs field %s.", r);
    end
end
fs = double(spec.carrier_hz);
B = double(spec.envelope_bw_hz);
k = double(spec.coeff_index(:)).';
Xn = abs(double(spec.coeff_norm(:)).');
K = double(spec.keep_max_index);
if fs <= 0 || B <= 0
    error("FhaVerify:PhasorPos", "carrier_hz and envelope_bw_hz must be positive.");
end
if numel(k) ~= numel(Xn)
    error("FhaVerify:PhasorLen", "coeff_index and coeff_norm length mismatch.");
end
end

function core = iVerifyFreqResponsePair(spec, opts)
% Frequency-domain error bound between analytic Z and a reference Z on a common
% grid. Errors are computed overall and restricted to the FHA validity band;
% the validity-band-restricted sup/L2 relative errors drive the verdict.
[f, za, zr] = iPairInputs(spec);
e = za - zr;
absErr = abs(e);
refMag = abs(zr);
denom = max(refMag, realmin);

supAbs = max(absErr);
supRel = max(absErr ./ denom);
l2Abs = sqrt(mean(absErr.^2));
l2Rel = sqrt(mean((absErr ./ denom).^2));

bands = iPerBandError(f, absErr ./ denom);

if ~isnan(opts.ValidUpToHz)
    inBand = f <= opts.ValidUpToHz;
else
    inBand = true(size(f));     % no bound documented -> whole grid, provisional
end
if any(inBand)
    supRelIB = max(absErr(inBand) ./ denom(inBand));
    l2RelIB = sqrt(mean((absErr(inBand) ./ denom(inBand)).^2));
else
    supRelIB = NaN; l2RelIB = NaN;
end

withinSup = ~isnan(supRelIB) && supRelIB <= opts.SupTolRel;
withinL2 = ~isnan(l2RelIB) && l2RelIB <= opts.L2TolRel;
holds = withinSup && withinL2;

core.metrics = struct("n_points", numel(f), "n_in_band", nnz(inBand), ...
    "sup_abs", supAbs, "sup_rel", supRel, "l2_abs", l2Abs, "l2_rel", l2Rel, ...
    "sup_rel_in_band", supRelIB, "l2_rel_in_band", l2RelIB, ...
    "per_band", bands);
core.bound = struct("type", "freq_domain_relative", ...
    "sup_tol_rel", opts.SupTolRel, "l2_tol_rel", opts.L2TolRel, ...
    "basis", "in_band_relative_sup_and_L2_vs_reference");
core.numeric = struct("sup_rel_in_band", supRelIB, "l2_rel_in_band", l2RelIB);
core.validity = struct("applicable", true, ...
    "valid_up_to_hz", opts.ValidUpToHz, "restricted_to_band", ~isnan(opts.ValidUpToHz));
core.bound_holds = holds;
if isnan(supRelIB)
    core.note = 'No in-band points to verify the frequency-domain bound.';
elseif holds
    core.note = sprintf(['In-band freq-domain error within bound: sup_rel %.4g <= %.4g, ' ...
        'L2_rel %.4g <= %.4g over %d points.'], ...
        supRelIB, opts.SupTolRel, l2RelIB, opts.L2TolRel, nnz(inBand));
else
    core.note = sprintf(['In-band freq-domain error EXCEEDS bound: sup_rel %.4g (tol %.4g), ' ...
        'L2_rel %.4g (tol %.4g).'], supRelIB, opts.SupTolRel, l2RelIB, opts.L2TolRel);
end
end


function [f, za, zr] = iPairInputs(spec)
req = ["frequency_hz","z_analytic","z_reference"];
for r = req
    if ~isfield(spec, r)
        error("FhaVerify:BadPair", "frequency_response_pair needs field %s.", r);
    end
end
f = double(spec.frequency_hz(:)).';
za = double(spec.z_analytic(:)).';
zr = double(spec.z_reference(:)).';
if numel(f) < 3 || numel(f) ~= numel(za) || numel(f) ~= numel(zr)
    error("FhaVerify:PairLen", "frequency_hz, z_analytic, z_reference must share length >=3.");
end
if any(f <= 0)
    error("FhaVerify:PairGrid", "frequency_hz must be strictly positive.");
end
if any(diff(f) <= 0)
    [f, order] = sort(f); za = za(order); zr = zr(order);
end
end


function bands = iPerBandError(f, relErr)
edges = [0 1 10 100 1000 inf];
labels = ["subsync_lt_1Hz","low_1_10Hz","mid_10_100Hz","high_100_1000Hz","vhf_gt_1000Hz"];
bands = repmat(struct("label","","n",0,"max_rel",NaN,"mean_rel",NaN), 1, numel(labels));
for b = 1:numel(labels)
    inB = f >= edges(b) & f < edges(b+1);
    bands(b).label = char(labels(b));
    bands(b).n = nnz(inB);
    if any(inB)
        bands(b).max_rel = max(relErr(inB));
        bands(b).mean_rel = mean(relErr(inB));
    end
end
end


function [provisional, missing] = iProvisionalCheck(spec, opts, specType)
missing = {};
if strlength(opts.OperatingPoint) == 0
    missing{end+1} = 'operating_point';
end
if strlength(opts.Units) == 0
    missing{end+1} = 'units';
end
if specType == "frequency_response_pair" && isnan(opts.ValidUpToHz)
    missing{end+1} = 'fha_validity_bound';
end
if specType == "dynamic_phasor" && ~isfield(spec, "carrier_hz")
    missing{end+1} = 'carrier_hz';
end
provisional = ~isempty(missing);
end


function grade = iGrade(core, provisional)
if provisional
    grade = 'contract_only';
elseif core.bound_holds
    grade = 'math_verified';
else
    grade = 'math_verification_failed';
end
end

function iWriteOutputs(outDir, report)
if ~isfolder(outDir)
    mkdir(outDir);
end
iWriteJson(fullfile(outDir, "fha_bound_verification.json"), report);
iWriteMarkdown(fullfile(outDir, "fha_bound_verification.md"), report);
end


function iWriteJson(path, report)
fid = fopen(path, "w");
if fid < 0
    error("FhaVerify:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(report, "PrettyPrint", true));
end


function iWriteMarkdown(path, r)
fid = fopen(path, "w");
if fid < 0
    error("FhaVerify:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# FHA / Dynamic-Phasor / Frequency-Domain Bound Verification\n\n");
fprintf(fid, "> **Evidence grade: %s** — %s\n\n", upper(r.evidence_grade), r.verdict_note);
if r.provisional
    fprintf(fid, "> **PROVISIONAL** — missing: %s\n\n", strjoin(r.missing_required, ", "));
end
fprintf(fid, "Case: `%s` | spec_type: %s | bound_holds: %d\n", ...
    r.case_name, r.spec_type, r.bound_holds);
fprintf(fid, "Math tolerance (rel): %.3g | Generated: %s\n\n", r.math_tol_rel, r.generated_at);

fprintf(fid, "## Provable bound\n\n");
fprintf(fid, "- type: %s\n", r.bound.type);
fprintf(fid, "- basis: %s\n", r.bound.basis);
fn = fieldnames(r.bound);
for i = 1:numel(fn)
    if ~ismember(fn{i}, {'type','basis'})
        fprintf(fid, "- %s: %s\n", fn{i}, iNum(r.bound.(fn{i})));
    end
end
fprintf(fid, "\n## Numeric re-check\n\n");
nf = fieldnames(r.numeric);
for i = 1:numel(nf)
    fprintf(fid, "- %s: %s\n", nf{i}, iNum(r.numeric.(nf{i})));
end

if isfield(r.validity, "applicable") && r.validity.applicable
    fprintf(fid, "\n## Validity\n\n");
    vf = fieldnames(r.validity);
    for i = 1:numel(vf)
        fprintf(fid, "- %s: %s\n", vf{i}, iNum(r.validity.(vf{i})));
    end
end

fprintf(fid, "\n## Limitations\n\n%s\n", r.limitations);
end


function s = iNum(v)
if ischar(v) || isstring(v)
    s = char(v);
elseif isscalar(v) && islogical(v)
    s = sprintf('%d', v);
elseif isscalar(v)
    s = sprintf('%.6g', v);
else
    s = mat2str(v, 6);
end
end
