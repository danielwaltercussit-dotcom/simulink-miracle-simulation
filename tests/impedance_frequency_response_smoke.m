function result = impedance_frequency_response_smoke()
%IMPEDANCE_FREQUENCY_RESPONSE_SMOKE Synthetic smoke test for the P3 helper.
%   Exercises summarize_impedance_frequency_response on two synthetic cases:
%     A) a passive parallel-RLC impedance with one obvious resonance peak,
%        so resonance detection and the dominant-frequency report fire and
%        the passivity screen correctly reports NO negative resistance;
%     B) an impedance with real(Z)<0 over a band, so the negative-resistance
%        passivity screen fires and reports the band edges.
%
%   No Simulink, no toolbox dependency: pure synthetic data through the
%   base-MATLAB helper. Returns a struct and prints PASS/FAIL per check.
%
%   Artifacts written under build/reports/impedance/<case>/.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

checks = struct([]);
checks = iAddCheck(checks, iCaseResonance(projectRoot));
checks = iAddCheck(checks, iCaseNegativeResistance(projectRoot));

allPass = all([checks.passed]);
fprintf('\n=== impedance_frequency_response_smoke ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s\n', iTag(allPass));

result = struct('passed', allPass, 'checks', checks);
end


function c = iCaseResonance(projectRoot)
% Parallel RLC: |Z| peaks at f0; real(Z)>=0 everywhere (passive).
f = logspace(0, 3, 200);            % 1..1000 Hz, log grid
R = 100; C = 100e-6;
f0 = 30;                            % target resonance (Hz)
L = 1 / ((2*pi*f0)^2 * C);
w = 2*pi*f;
Y = 1/R + 1j*(w*C - 1./(w*L));
Z = 1 ./ Y;

outDir = fullfile(projectRoot, 'build', 'reports', 'impedance', 'synthetic_resonance');
s = summarize_impedance_frequency_response(f, Z, ...
    'CaseName', 'synthetic_resonance', ...
    'Kind', 'impedance', ...
    'EvidenceSource', 'synthetic', ...
    'OutputDir', outDir);

okPeak  = s.n_resonances >= 1;
okFreq  = ~isnan(s.dominant_resonance_hz) && abs(s.dominant_resonance_hz - f0) <= 8;
okPass  = s.passivity.applicable && ~s.passivity.negative_resistance;
okFiles = iArtifactsExist(outDir);

c.name = 'Case A: parallel-RLC resonance peak, passive';
c.passed = okPeak && okFreq && okPass && okFiles;
c.detail = sprintf(['n_resonances=%d (>=1:%d) dominant=%.3g Hz (~%g:%d) ', ...
    'neg_resistance=%d (want 0) artifacts=%d'], ...
    s.n_resonances, okPeak, s.dominant_resonance_hz, f0, okFreq, ...
    s.passivity.negative_resistance, okFiles);
end


function c = iCaseNegativeResistance(projectRoot)
% Real part dips below zero over a band centred near 50 Hz.
f = linspace(1, 200, 300);
reZ = 1.0 - 1.5 * exp(-((f - 50)/15).^2);   % min ~ -0.5 near 50 Hz
imZ = 0.3 * (f/50);
Z = reZ + 1j*imZ;

outDir = fullfile(projectRoot, 'build', 'reports', 'impedance', 'synthetic_negres');
s = summarize_impedance_frequency_response(f, Z, ...
    'CaseName', 'synthetic_negres', ...
    'Kind', 'impedance', ...
    'EvidenceSource', 'synthetic', ...
    'OutputDir', outDir);

ps = s.passivity;
okApplies = ps.applicable;
okNeg     = ps.negative_resistance && ps.n_negative_points > 0;
band      = ps.negative_band_hz;
okBand    = all(isfinite(band)) && band(1) >= 1 && band(2) <= 200 && band(1) <= 50 && band(2) >= 50;
okFiles   = iArtifactsExist(outDir);

c.name = 'Case B: real(Z)<0 band triggers passivity screen';
c.passed = okApplies && okNeg && okBand && okFiles;
c.detail = sprintf(['applicable=%d neg_resistance=%d n_neg=%d band=[%.4g %.4g]Hz ', ...
    '(brackets 50Hz:%d) artifacts=%d'], ...
    okApplies, ps.negative_resistance, ps.n_negative_points, ...
    band(1), band(2), okBand, okFiles);
end


function tf = iArtifactsExist(outDir)
tf = isfile(fullfile(outDir, 'impedance_summary.md')) && ...
     isfile(fullfile(outDir, 'impedance_summary.json')) && ...
     isfile(fullfile(outDir, 'frequency_response.csv'));
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
