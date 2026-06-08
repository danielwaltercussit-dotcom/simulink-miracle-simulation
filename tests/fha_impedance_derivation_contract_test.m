function result = fha_impedance_derivation_contract_test()
%FHA_IMPEDANCE_DERIVATION_CONTRACT_TEST Contract test for the F1 analytic helper.
%   Exercises summarize_fha_impedance_response on synthetic / known cases and
%   asserts the analytic-derivation contract (see
%   .agents/skills/analytic-fha-impedance-derivation/references/fha-impedance-contract.md):
%
%     A) transfer_function 2nd-order resonant Z: an EXACT analytic pole is
%        reported (source=analytic_pole) at the known frequency, documented
%        case is non-provisional, contract band labels are present.
%     B) rlc_branches parallel R||L||C: resonance near the design f0, passive
%        (no negative resistance), artifacts written with F1 file names.
%     C) undocumented case: provisional=1 and missing_required lists
%        topology_assumptions, operating_point, units, and fha_validity_bound.
%     D) FHA validity band: grid extends beyond the bound -> in_band_fraction<1
%        and the out-of-band note fires; bound basis is half_switching_frequency
%        when only SwitchingHz is given.
%     E) negative-resistance transfer function: passivity screen flags the band.
%
%   Comparison helper (compare_fha_measured_impedance) cases:
%     F) good fit: analytic model vs its own samples (+noise) inside the FHA
%        band -> evidence_grade=data_backed, in_band_pass=1, high R^2.
%     G) mismatch: wrong model vs data -> data_backed_mismatch, in_band_pass=0,
%        large in-band magnitude error (honest negative, not a crash).
%     H) out-of-band only: measured grid entirely above the FHA bound ->
%        contract_only, n_in_band=0, "cannot data-validate" note.
%     I) provisional: undocumented metadata -> contract_only, provisional=1,
%        measured_source among the missing required fields.
%
%   Bound-verification helper (verify_fha_dynamic_phasor_bounds) cases:
%     J) FHA square wave: THD ~= 48.34%, fundamental retains ~81.06% power,
%        triangle sup-norm bound holds -> math_verified.
%     K) FHA single harmonic: exact analytic THD for one added harmonic,
%        bound holds -> math_verified.
%     L) dynamic phasor narrowband valid: fs/B large, 2B<fs, Parseval
%        truncation identity holds -> math_verified.
%     M) dynamic phasor narrowband INVALID: fs/B below threshold -> bound_holds
%        false -> math_verification_failed (honest negative).
%     N) frequency_response_pair within / exceeding bound and a provisional
%        case -> math_verified / math_verification_failed / contract_only.
%
%   Pure synthetic data, base MATLAB only. Returns a struct, prints PASS/FAIL
%   per check. Scratch artifacts go under build/reports/f1_fha_impedance/ and
%   are package-local (F1 file names) so they cannot collide with P3/P4.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

checks = struct([]);
checks = iAddCheck(checks, iCaseAnalyticPole(projectRoot));
checks = iAddCheck(checks, iCaseRlcPassive(projectRoot));
checks = iAddCheck(checks, iCaseProvisional());
checks = iAddCheck(checks, iCaseFhaBand());
checks = iAddCheck(checks, iCaseNegativeResistance());
checks = iAddCheck(checks, iCaseCompareGoodFit(projectRoot));
checks = iAddCheck(checks, iCaseCompareMismatch());
checks = iAddCheck(checks, iCaseCompareOutOfBand());
checks = iAddCheck(checks, iCaseCompareProvisional());
checks = iAddCheck(checks, iCaseFhaSquareWave(projectRoot));
checks = iAddCheck(checks, iCaseFhaSingleHarmonic());
checks = iAddCheck(checks, iCaseDpNarrowbandValid());
checks = iAddCheck(checks, iCaseDpNarrowbandInvalid());
checks = iAddCheck(checks, iCaseFreqPairWithinBound());
checks = iAddCheck(checks, iCaseFreqPairExceedsBound());
checks = iAddCheck(checks, iCaseVerifyProvisional());

allPass = all([checks.passed]);
fprintf('\n=== fha_impedance_derivation_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), nnz([checks.passed]), numel(checks));

result = struct('passed', allPass, 'checks', checks);
end


function c = iCaseAnalyticPole(projectRoot)
% 2nd-order resonant Z(s) with complex poles at ~40 Hz; zero at origin.
wn = 2*pi*40; zeta = 0.02;
model.type = "transfer_function";
model.num = [1 0];
model.den = [1/wn^2 2*zeta/wn 1];
model.kind = "impedance";

outDir = fullfile(projectRoot, 'build', 'reports', 'f1_fha_impedance', 'tf_analytic_pole');
s = summarize_fha_impedance_response("Model", model, ...
    "CaseName", "tf_analytic_pole", ...
    "FreqMinHz", 1, "FreqMaxHz", 500, "NPoints", 600, "Spacing", "log", ...
    "TopologyAssumptions", "2nd-order resonant branch", ...
    "OperatingPoint", "linear small-signal", "Units", "ohm", ...
    "FundamentalHz", 50, "ValidUpToHz", 500, ...
    "OutputDir", outDir);

okPole  = s.n_resonances >= 1 && strcmp(s.resonances(1).source, 'analytic_pole');
okFreq  = ~isnan(s.dominant_resonance_hz) && abs(s.dominant_resonance_hz - 40) <= 2;
okProv  = s.provisional == false && isempty(s.missing_required);
okBands = iHasContractBands(s.frequency_bands);
okSrc   = strcmp(s.evidence_source, 'analytic');
okFiles = iArtifactsExist(outDir);

c.name = 'Case A: transfer_function reports EXACT analytic pole';
c.passed = okPole && okFreq && okProv && okBands && okSrc && okFiles;
c.detail = sprintf(['n_res=%d source=%s dominant=%.4g Hz (~40:%d) provisional=%d ', ...
    'bands_ok=%d analytic_src=%d artifacts=%d'], ...
    s.n_resonances, s.resonances(1).source, s.dominant_resonance_hz, okFreq, ...
    s.provisional, okBands, okSrc, okFiles);
end


function c = iCaseRlcPassive(projectRoot)
% Parallel R||L||C, design resonance f0=30 Hz, passive.
R = 100; C = 100e-6; f0 = 30; L = 1/((2*pi*f0)^2 * C);
model.type = "rlc_branches";
model.branches = struct("R", {R, 0, 0}, "L", {0, L, 0}, "C", {0, 0, C});

outDir = fullfile(projectRoot, 'build', 'reports', 'f1_fha_impedance', 'rlc_passive');
s = summarize_fha_impedance_response("Model", model, ...
    "CaseName", "rlc_passive", ...
    "FreqMinHz", 1, "FreqMaxHz", 1000, "NPoints", 400, "Spacing", "log", ...
    "TopologyAssumptions", "parallel R||L||C", ...
    "OperatingPoint", "no-load", "Units", "ohm", ...
    "SwitchingHz", 4000, "OutputDir", outDir);

okRes   = s.n_resonances >= 1;
okFreq  = ~isnan(s.dominant_resonance_hz) && abs(s.dominant_resonance_hz - f0) <= 8;
okPass  = s.passivity.applicable && ~s.passivity.negative_resistance;
okProv  = s.provisional == false;
okFiles = iArtifactsExist(outDir);

c.name = 'Case B: rlc_branches resonance, passive, documented';
c.passed = okRes && okFreq && okPass && okProv && okFiles;
c.detail = sprintf(['n_res=%d dominant=%.4g Hz (~%g:%d) neg_resistance=%d (want 0) ', ...
    'provisional=%d artifacts=%d'], ...
    s.n_resonances, s.dominant_resonance_hz, f0, okFreq, ...
    s.passivity.negative_resistance, s.provisional, okFiles);
end


function c = iCaseProvisional()
% No topology / operating point / units / FHA bound -> provisional with all
% four missing fields listed. No OutputDir (assert in-memory contract only).
wn = 2*pi*40; zeta = 0.05;
model.type = "transfer_function";
model.num = [1 0];
model.den = [1/wn^2 2*zeta/wn 1];

s = summarize_fha_impedance_response("Model", model, "CaseName", "provisional");

want = {'topology_assumptions', 'operating_point', 'units', 'fha_validity_bound'};
okProv = s.provisional == true;
okMiss = iSetEquals(s.missing_required, want);
okNan  = isnan(s.fha_validity.valid_up_to_hz) && isempty(s.fha_validity.basis);

c.name = 'Case C: undocumented derivation is provisional';
c.passed = okProv && okMiss && okNan;
c.detail = sprintf('provisional=%d missing={%s} (want 4 fields:%d) fha_up=NaN:%d', ...
    s.provisional, strjoin(s.missing_required, ','), okMiss, okNan);
end


function c = iCaseFhaBand()
% Grid extends past the FHA bound; only SwitchingHz given -> bound is
% half_switching_frequency and in_band_fraction is strictly < 1.
R = 50; C = 50e-6; f0 = 60; L = 1/((2*pi*f0)^2 * C);
model.type = "rlc_branches";
model.branches = struct("R", {R, 0, 0}, "L", {0, L, 0}, "C", {0, 0, C});

s = summarize_fha_impedance_response("Model", model, ...
    "CaseName", "fha_band", ...
    "FreqMinHz", 1, "FreqMaxHz", 5000, "NPoints", 500, "Spacing", "log", ...
    "TopologyAssumptions", "parallel R||L||C", ...
    "OperatingPoint", "rated", "Units", "ohm", ...
    "SwitchingHz", 4000);   % bound -> 2000 Hz, grid goes to 5000 Hz

fha = s.fha_validity;
okBasis  = strcmp(fha.basis, 'half_switching_frequency');
okBound  = abs(fha.valid_up_to_hz - 2000) <= 1e-6;
okFrac   = fha.in_band_fraction > 0 && fha.in_band_fraction < 1;
okNote   = contains(fha.note, 'beyond');
okNotProv = s.provisional == false;   % SwitchingHz documents the bound

c.name = 'Case D: FHA validity band bounds the grid';
c.passed = okBasis && okBound && okFrac && okNote && okNotProv;
c.detail = sprintf(['basis=%s (half_sw:%d) up_to=%.5g (2000:%d) in_band=%.3g (0<f<1:%d) ', ...
    'note_beyond=%d provisional=%d'], ...
    fha.basis, okBasis, fha.valid_up_to_hz, okBound, fha.in_band_fraction, okFrac, ...
    okNote, s.provisional);
end


function c = iCaseNegativeResistance()
% Z(s) = (s - a)/(s + b) has real(Z) = (w^2 - a*b)/(b^2 + w^2), which is
% negative for w < sqrt(a*b). With a=2*pi*60, b=2*pi*5 the negative-resistance
% band is roughly f < 17 Hz, so the passivity screen must fire on a grid that
% starts at 1 Hz.
a = 2*pi*60; b = 2*pi*5;
f = linspace(1, 200, 400);
model.type = "transfer_function";
model.num = [1 -a];
model.den = [1 b];
model.kind = "impedance";

s = summarize_fha_impedance_response("Model", model, ...
    "CaseName", "neg_resistance", ...
    "FrequencyHz", f, ...
    "TopologyAssumptions", "RHP-zero impedance (synthetic)", ...
    "OperatingPoint", "synthetic", "Units", "ohm", "ValidUpToHz", 200);

ps = s.passivity;
okApplies = ps.applicable;
okNeg     = ps.negative_resistance && ps.n_negative_points > 0;
okBand    = all(isfinite(ps.negative_band_hz));

c.name = 'Case E: negative-resistance band triggers passivity screen';
c.passed = okApplies && okNeg && okBand;
c.detail = sprintf('applicable=%d neg=%d n_neg=%d band=[%.4g %.4g]Hz', ...
    okApplies, ps.negative_resistance, ps.n_negative_points, ...
    ps.negative_band_hz(1), ps.negative_band_hz(2));
end


function truth = iTruthRlc(f0)
% Parallel R||L||C truth model at design resonance f0 (Hz).
R = 100; C = 100e-6; L = 1/((2*pi*f0)^2 * C);
truth.type = "rlc_branches";
truth.branches = struct("R", {R, 0, 0}, "L", {0, L, 0}, "C", {0, 0, C});
end


function z = iMeasuredFrom(model, f, validUpToHz)
% Generate synthetic "measured" samples from a model via the F1 helper's
% second output, so the comparison test has self-consistent data.
[~, d] = summarize_fha_impedance_response("Model", model, ...
    "FrequencyHz", f, "ValidUpToHz", validUpToHz);
z = d.z;
end


function c = iCaseCompareGoodFit(projectRoot)
truth = iTruthRlc(30);
f = logspace(0, 3, 120);
z = iMeasuredFrom(truth, f, 1000);
zNoisy = z .* (1 + 0.01*cos(2*pi*(1:numel(z))/7));   % ~1% structured noise

outDir = fullfile(projectRoot, 'build', 'reports', 'f1_fha_impedance', 'cmp_good_fit');
cmp = compare_fha_measured_impedance(truth, f, zNoisy, ...
    "MeasuredSource", "simulated_injection", "TopologyAssumptions", "parallel R||L||C", ...
    "OperatingPoint", "no-load", "Units", "ohm", "ValidUpToHz", 1000, ...
    "CaseName", "cmp_good_fit", "OutputDir", outDir);

okGrade = strcmp(cmp.evidence_grade, 'data_backed');
okPass  = cmp.in_band_pass == true;
okErr   = cmp.error_in_band.mag_rmse_pct < 10;
okR2    = cmp.error_overall.mag_r2 > 0.99;
okFiles = isfile(fullfile(outDir, 'fha_comparison_summary.json'));

c.name = 'Case F: comparison good fit -> data_backed';
c.passed = okGrade && okPass && okErr && okR2 && okFiles;
c.detail = sprintf('grade=%s pass=%d magRMSE=%.3g%% r2=%.4g artifacts=%d', ...
    cmp.evidence_grade, cmp.in_band_pass, cmp.error_in_band.mag_rmse_pct, ...
    cmp.error_overall.mag_r2, okFiles);
end


function c = iCaseCompareMismatch()
% Data from a 30 Hz model, but compare against a wrong 60 Hz model.
dataModel = iTruthRlc(30);
wrongModel = iTruthRlc(60);
f = logspace(0, 3, 120);
z = iMeasuredFrom(dataModel, f, 1000);

cmp = compare_fha_measured_impedance(wrongModel, f, z, ...
    "MeasuredSource", "simulated_injection", "TopologyAssumptions", "parallel R||L||C (wrong L)", ...
    "OperatingPoint", "no-load", "Units", "ohm", "ValidUpToHz", 1000, ...
    "CaseName", "cmp_mismatch");

okGrade = strcmp(cmp.evidence_grade, 'data_backed_mismatch');
okFail  = cmp.in_band_pass == false;
okErr   = cmp.error_in_band.mag_rmse_pct > 10;   % clearly out of tolerance

c.name = 'Case G: comparison mismatch -> data_backed_mismatch (no crash)';
c.passed = okGrade && okFail && okErr;
c.detail = sprintf('grade=%s pass=%d (want 0) magRMSE=%.3g%% (>10:%d)', ...
    cmp.evidence_grade, cmp.in_band_pass, cmp.error_in_band.mag_rmse_pct, okErr);
end


function c = iCaseCompareOutOfBand()
% Measured grid entirely ABOVE the FHA bound -> no in-band points.
truth = iTruthRlc(30);
f = logspace(2, 3, 80);          % 100..1000 Hz
z = iMeasuredFrom(truth, f, 50);  % bound 50 Hz

cmp = compare_fha_measured_impedance(truth, f, z, ...
    "MeasuredSource", "simulated_injection", "TopologyAssumptions", "parallel R||L||C", ...
    "OperatingPoint", "no-load", "Units", "ohm", "ValidUpToHz", 50, ...
    "CaseName", "cmp_oob");

okGrade = strcmp(cmp.evidence_grade, 'contract_only');
okNoIn  = cmp.n_in_band == 0 && cmp.n_out_of_band == numel(f);
okNote  = contains(cmp.verdict_note, 'in-band') || contains(cmp.verdict_note, 'in band');

c.name = 'Case H: comparison out-of-band only -> contract_only';
c.passed = okGrade && okNoIn && okNote;
c.detail = sprintf('grade=%s n_in=%d n_out=%d note_ok=%d', ...
    cmp.evidence_grade, cmp.n_in_band, cmp.n_out_of_band, okNote);
end


function c = iCaseCompareProvisional()
% Undocumented metadata -> provisional, contract_only, measured_source missing.
truth = iTruthRlc(30);
f = logspace(0, 3, 80);
z = iMeasuredFrom(truth, f, 1000);

cmp = compare_fha_measured_impedance(truth, f, z, "CaseName", "cmp_prov");

okGrade = strcmp(cmp.evidence_grade, 'contract_only');
okProv  = cmp.provisional == true;
okMiss  = any(strcmp('measured_source', cmp.missing_required)) && ...
          any(strcmp('fha_validity_bound', cmp.missing_required));

c.name = 'Case I: comparison undocumented -> provisional contract_only';
c.passed = okGrade && okProv && okMiss;
c.detail = sprintf('grade=%s provisional=%d missing={%s}', ...
    cmp.evidence_grade, cmp.provisional, strjoin(cmp.missing_required, ','));
end


function c = iCaseFhaSquareWave(projectRoot)
% Ideal square wave: a_k = 4/(pi*k) for odd k. Two checks:
%  (1) the helper's THD / retained-power must match an INDEPENDENT recompute
%      from the same finite harmonics (exact contract check, tol 1e-9);
%  (2) with many harmonics the THD approaches the textbook infinite-series
%      value sqrt(pi^2/8 - 1) ~= 48.34% (finite-truncation tol 1e-2).
kk = 1:2:999;                 % 500 odd harmonics -> close to the infinite sum
a = 4 ./ (pi * kk);
spec.type = "harmonic_series";
spec.harmonic_index = kk;
spec.amplitude = a;

outDir = fullfile(projectRoot, 'build', 'reports', 'f1_fha_impedance', 'verify_square');
r = verify_fha_dynamic_phasor_bounds(spec, "CaseName", "fha_square", ...
    "OperatingPoint", "ideal 2-level", "Units", "pu", "OutputDir", outDir);

% Independent recompute from the same finite arrays.
thdIndep = sqrt(sum(a(kk >= 3).^2)) / a(1);
retIndep = a(1)^2 / sum(a.^2);
thdTextbook = sqrt(pi^2/8 - 1);

okGrade  = strcmp(r.evidence_grade, 'math_verified');
okHolds  = r.bound_holds == true;
okThdEx  = abs(r.metrics.thd - thdIndep) <= 1e-9;            % helper vs recompute
okRetEx  = abs(r.metrics.retained_energy_fraction - retIndep) <= 1e-9;
okThdTb  = abs(r.metrics.thd - thdTextbook) <= 1e-2;          % vs textbook (finite)
okFiles  = isfile(fullfile(outDir, 'fha_bound_verification.json'));

c.name = 'Case J: FHA square-wave THD + triangle sup bound -> math_verified';
c.passed = okGrade && okHolds && okThdEx && okRetEx && okThdTb && okFiles;
c.detail = sprintf(['grade=%s holds=%d THD=%.4f%% indep=%.4f%% (eq:%d) textbook=%.4f%% (<=1e-2:%d) ' ...
    'ret=%.4f indep=%.4f files=%d'], ...
    r.evidence_grade, r.bound_holds, r.metrics.thd_pct, 100*thdIndep, okThdEx, ...
    100*thdTextbook, okThdTb, r.metrics.retained_energy_fraction, retIndep, okFiles);
end


function c = iCaseFhaSingleHarmonic()
% Fundamental 1.0 + a single 5th harmonic at 0.2: THD = 0.2 exactly.
spec.type = "harmonic_series";
spec.harmonic_index = [1 5];
spec.amplitude = [1.0 0.2];

r = verify_fha_dynamic_phasor_bounds(spec, "CaseName", "fha_single", ...
    "OperatingPoint", "synthetic", "Units", "pu");

okGrade = strcmp(r.evidence_grade, 'math_verified');
okThd   = abs(r.metrics.thd - 0.2) <= 1e-9;
okBound = abs(r.bound.value - 0.2) <= 1e-9;        % sum|a_k|, k>1
okHolds = r.bound_holds == true;

c.name = 'Case K: FHA single harmonic exact THD -> math_verified';
c.passed = okGrade && okThd && okBound && okHolds;
c.detail = sprintf('grade=%s THD=%.6g (exp 0.2) bound=%.6g sup=%.6g holds=%d', ...
    r.evidence_grade, r.metrics.thd, r.bound.value, r.numeric.sup_norm, r.bound_holds);
end


function c = iCaseDpNarrowbandValid()
% Carrier 2 kHz, envelope BW 50 Hz -> fs/B=40 >> 5, 2B<fs. Keep |k|<=1,
% drop a small k=+/-3 content; Parseval truncation identity must hold.
spec.type = "dynamic_phasor";
spec.carrier_hz = 2000;
spec.envelope_bw_hz = 50;
spec.coeff_index = [-3 -1 0 1 3];
spec.coeff_norm  = [0.05 1.0 0.4 1.0 0.05];
spec.keep_max_index = 1;

r = verify_fha_dynamic_phasor_bounds(spec, "CaseName", "dp_valid", ...
    "OperatingPoint", "synthetic", "Units", "pu", "NarrowbandRatioMin", 5);

boundExpect = sqrt(0.05^2 + 0.05^2);
okGrade = strcmp(r.evidence_grade, 'math_verified');
okHolds = r.bound_holds == true;
okBound = abs(r.bound.value - boundExpect) <= 1e-9;
okPars  = r.numeric.parseval_residual <= 1e-6;
okNB    = r.validity.narrowband_valid == true;

c.name = 'Case L: dynamic phasor narrowband valid + Parseval -> math_verified';
c.passed = okGrade && okHolds && okBound && okPars && okNB;
c.detail = sprintf('grade=%s holds=%d fs/B=%.4g bound=%.6g rms=%.6g resid=%.2g', ...
    r.evidence_grade, r.bound_holds, r.metrics.narrowband_ratio_fs_over_B, ...
    r.bound.value, r.numeric.rms_error, r.numeric.parseval_residual);
end


function c = iCaseDpNarrowbandInvalid()
% Envelope BW 600 Hz vs carrier 1 kHz: fs/B=1.67<5 AND 2B>fs -> narrowband
% INVALID. Truncation identity itself still holds, but the grade must fail.
spec.type = "dynamic_phasor";
spec.carrier_hz = 1000;
spec.envelope_bw_hz = 600;
spec.coeff_index = [-1 0 1];
spec.coeff_norm  = [1.0 0.3 1.0];
spec.keep_max_index = 1;

r = verify_fha_dynamic_phasor_bounds(spec, "CaseName", "dp_invalid", ...
    "OperatingPoint", "synthetic", "Units", "pu", "NarrowbandRatioMin", 5);

okGrade = strcmp(r.evidence_grade, 'math_verification_failed');
okHolds = r.bound_holds == false;
okNB    = r.validity.narrowband_valid == false;
okOver  = r.validity.non_overlap_2B_lt_fs == false;

c.name = 'Case M: dynamic phasor narrowband INVALID -> math_verification_failed';
c.passed = okGrade && okHolds && okNB && okOver;
c.detail = sprintf('grade=%s holds=%d fs/B=%.4g narrowband_valid=%d 2B<fs=%d', ...
    r.evidence_grade, r.bound_holds, r.metrics.narrowband_ratio_fs_over_B, ...
    r.validity.narrowband_valid, r.validity.non_overlap_2B_lt_fs);
end


function c = iCaseFreqPairWithinBound()
% Analytic vs reference differ by 2% multiplicative inside band -> within
% 10% sup/L2 tolerance -> math_verified.
f = logspace(0, 3, 200);
zr = 1 ./ (1j*2*pi*f*1e-4 + 0.01);            % arbitrary smooth reference
za = zr .* (1 + 0.02);                          % 2% magnitude error
spec.type = "frequency_response_pair";
spec.frequency_hz = f; spec.z_analytic = za; spec.z_reference = zr;

r = verify_fha_dynamic_phasor_bounds(spec, "CaseName", "pair_ok", ...
    "OperatingPoint", "synthetic", "Units", "ohm", "ValidUpToHz", 1000, ...
    "SupTolRel", 0.1, "L2TolRel", 0.1);

okGrade = strcmp(r.evidence_grade, 'math_verified');
okHolds = r.bound_holds == true;
okSup   = r.metrics.sup_rel_in_band <= 0.1;

c.name = 'Case N1: freq-response pair within bound -> math_verified';
c.passed = okGrade && okHolds && okSup;
c.detail = sprintf('grade=%s holds=%d sup_rel_ib=%.4g l2_rel_ib=%.4g', ...
    r.evidence_grade, r.bound_holds, r.metrics.sup_rel_in_band, r.metrics.l2_rel_in_band);
end


function c = iCaseFreqPairExceedsBound()
% 25% error in-band, tolerance 10% -> exceeds -> math_verification_failed.
f = logspace(0, 3, 200);
zr = 1 ./ (1j*2*pi*f*1e-4 + 0.01);
za = zr .* (1 + 0.25);
spec.type = "frequency_response_pair";
spec.frequency_hz = f; spec.z_analytic = za; spec.z_reference = zr;

r = verify_fha_dynamic_phasor_bounds(spec, "CaseName", "pair_bad", ...
    "OperatingPoint", "synthetic", "Units", "ohm", "ValidUpToHz", 1000, ...
    "SupTolRel", 0.1, "L2TolRel", 0.1);

okGrade = strcmp(r.evidence_grade, 'math_verification_failed');
okHolds = r.bound_holds == false;
okSup   = r.metrics.sup_rel_in_band > 0.1;

c.name = 'Case N2: freq-response pair exceeds bound -> math_verification_failed';
c.passed = okGrade && okHolds && okSup;
c.detail = sprintf('grade=%s holds=%d sup_rel_ib=%.4g (tol 0.1)', ...
    r.evidence_grade, r.bound_holds, r.metrics.sup_rel_in_band);
end


function c = iCaseVerifyProvisional()
% frequency_response_pair without ValidUpToHz / units -> provisional ->
% contract_only regardless of numeric agreement.
f = logspace(0, 3, 100);
zr = 1 ./ (1j*2*pi*f*1e-4 + 0.01);
spec.type = "frequency_response_pair";
spec.frequency_hz = f; spec.z_analytic = zr; spec.z_reference = zr;   % identical

r = verify_fha_dynamic_phasor_bounds(spec, "CaseName", "verify_prov");

okGrade = strcmp(r.evidence_grade, 'contract_only');
okProv  = r.provisional == true;
okMiss  = any(strcmp('fha_validity_bound', r.missing_required)) && ...
          any(strcmp('units', r.missing_required));

c.name = 'Case N3: bound verification undocumented -> provisional contract_only';
c.passed = okGrade && okProv && okMiss;
c.detail = sprintf('grade=%s provisional=%d missing={%s}', ...
    r.evidence_grade, r.provisional, strjoin(r.missing_required, ','));
end


function tf = iHasContractBands(bands)
want = {'subsync_lt_1Hz','low_1_10Hz','mid_10_100Hz','high_100_1000Hz','vhf_gt_1000Hz'};
got = {bands.label};
tf = numel(got) == numel(want) && all(cellfun(@(w) any(strcmp(w, got)), want));
end


function tf = iSetEquals(a, b)
a = a(:)'; b = b(:)';
tf = numel(a) == numel(b) && all(cellfun(@(x) any(strcmp(x, b)), a)) && ...
     all(cellfun(@(x) any(strcmp(x, a)), b));
end


function tf = iArtifactsExist(outDir)
tf = isfile(fullfile(outDir, 'fha_impedance_summary.md')) && ...
     isfile(fullfile(outDir, 'fha_impedance_summary.json')) && ...
     isfile(fullfile(outDir, 'fha_frequency_response.csv'));
end


function checks = iAddCheck(checks, c)
if isempty(checks)
    checks = c;
else
    checks(end+1) = c;
end
end


function t = iTag(passed)
if passed; t = 'PASS'; else; t = 'FAIL'; end
end
