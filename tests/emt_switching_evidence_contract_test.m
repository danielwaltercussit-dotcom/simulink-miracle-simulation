function result = emt_switching_evidence_contract_test()
%EMT_SWITCHING_EVIDENCE_CONTRACT_TEST Synthetic contract test for the E1 helper.
%   Exercises summarize_switching_waveform_evidence across the switching-evidence
%   contract states, using only synthetic base-MATLAB data (no Simulink, no
%   toolbox):
%     A) documented, well-resolved SPWM current  -> PASS, THD + carrier band,
%        ripple with fundamental removed, artifacts written;
%     B) undocumented (no carrier/sample-time/modulation) -> provisional + WARN,
%        missing_required lists the three trust-critical fields;
%     C) undersampled carrier (few samples per carrier) -> WARN with the
%        undersampled_carrier adequacy flag;
%     D) dead-time below one fixed step -> WARN with deadtime_below_one_step;
%     E) too-short waveform -> MISSING.
%
%   Package: E1 EMT/switching-level converter modeling. Artifacts written under
%   build/reports/e1_emt_switching/<case>/. Returns a struct and prints
%   PASS/FAIL per check.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

checks = struct([]);
checks = iAddCheck(checks, iCaseDocumented(projectRoot));
checks = iAddCheck(checks, iCaseUndocumented(projectRoot));
checks = iAddCheck(checks, iCaseUndersampled(projectRoot));
checks = iAddCheck(checks, iCaseDeadtime(projectRoot));
checks = iAddCheck(checks, iCaseTooShort(projectRoot));

allPass = all([checks.passed]);
fprintf('\n=== emt_switching_evidence_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), nnz([checks.passed]), numel(checks));

result = struct('passed', allPass, 'checks', checks);
end


function c = iCaseDocumented(projectRoot)
% Fully documented SPWM current, well resolved: 50 Hz + 3rd/5th harmonics +
% 5 kHz carrier at a 2 us step (2500 samples/carrier... actually 100 with this fs).
ts = 2e-6; t = (0:ts:0.06-ts)';
f0 = 50; fc = 5000;
x = 1.0*sin(2*pi*f0*t) + 0.08*sin(2*pi*3*f0*t) + 0.05*sin(2*pi*5*f0*t) ...
    + 0.15*sin(2*pi*fc*t);
outDir = fullfile(projectRoot, 'build', 'reports', 'e1_emt_switching', 'synthetic_documented');
s = summarize_switching_waveform_evidence(t, x, ...
    'CaseName', 'synthetic_documented', 'Signal', 'current', ...
    'FundamentalHz', f0, 'CarrierHz', fc, 'SampleTimeS', ts, ...
    'DeadTimeS', 2e-6, 'ModulationMethod', 'SPWM', ...
    'DeviceLossMode', 'on-resistance', 'TransientEventWindowS', [0.02 0.05], ...
    'Units', 'A', 'SourceModelOrScript', 'contract_test', ...
    'OutputDir', outDir);

okStatus = strcmp(s.status, 'PASS') && ~s.provisional;
okLoc    = s.fundamental_well_located && abs(s.spectrum.fundamental_hz - f0) <= 1;
okThd    = abs(s.spectrum.thd_percent - 9.43) <= 1.5 && s.spectrum.n_harmonics_reported == 2;
okCarr   = s.carrier_band.applicable && abs(s.carrier_band.carrier_to_fundamental - 0.15) <= 0.03;
okRip    = s.ripple.applicable && abs(s.ripple.rms - 0.1255) <= 0.02;
okAdeq   = s.adequacy.adequate && abs(s.adequacy.samples_per_carrier - 100) <= 1;
okFiles  = iArtifactsExist(outDir);

c.name = 'Case A: documented well-resolved SPWM -> PASS';
c.passed = okStatus && okLoc && okThd && okCarr && okRip && okAdeq && okFiles;
c.detail = sprintf(['status=%s(want PASS) loc=%d THD=%.3g%%(n=%d) c/f=%.3g ', ...
    'rms=%.4g spc=%.4g adeq=%d files=%d'], ...
    s.status, okLoc, s.spectrum.thd_percent, s.spectrum.n_harmonics_reported, ...
    s.carrier_band.carrier_to_fundamental, s.ripple.rms, ...
    s.adequacy.samples_per_carrier, okAdeq, okFiles);
end


function c = iCaseUndocumented(projectRoot)
% Same waveform, but carrier / sample time / modulation undocumented.
ts = 2e-6; t = (0:ts:0.06-ts)';
f0 = 50; fc = 5000;
x = sin(2*pi*f0*t) + 0.15*sin(2*pi*fc*t);
outDir = fullfile(projectRoot, 'build', 'reports', 'e1_emt_switching', 'synthetic_undocumented');
s = summarize_switching_waveform_evidence(t, x, ...
    'CaseName', 'synthetic_undocumented', 'Signal', 'current', ...
    'FundamentalHz', f0, ...
    'OutputDir', outDir);

okProv   = s.provisional && strcmp(s.status, 'WARN');
miss     = s.missing_required;
okMiss   = iHasAll(miss, {'carrier_hz', 'modulation_method', 'sample_time_s'});
okInfer  = ~s.sample_time_documented && abs(s.sample_time_used_s - ts) <= ts*0.1;
okFiles  = iArtifactsExist(outDir);

c.name = 'Case B: undocumented metadata -> provisional + WARN';
c.passed = okProv && okMiss && okInfer && okFiles;
c.detail = sprintf('provisional=%d status=%s missing={%s} inferred_ts=%.3g files=%d', ...
    s.provisional, s.status, strjoin(miss, ','), s.sample_time_used_s, okFiles);
end


function c = iCaseUndersampled(projectRoot)
% Documented, but the sample time gives < 20 samples per carrier: a 5 kHz
% carrier at a 50 us step is only 4 samples/carrier. Metadata is complete, so
% the WARN must come from the adequacy flag, not from provisional.
ts = 50e-6; t = (0:ts:0.06-ts)';
f0 = 50; fc = 5000;
x = sin(2*pi*f0*t) + 0.1*sin(2*pi*fc*t);
outDir = fullfile(projectRoot, 'build', 'reports', 'e1_emt_switching', 'synthetic_undersampled');
s = summarize_switching_waveform_evidence(t, x, ...
    'CaseName', 'synthetic_undersampled', 'Signal', 'current', ...
    'FundamentalHz', f0, 'CarrierHz', fc, 'SampleTimeS', ts, ...
    'ModulationMethod', 'SPWM', 'DeviceLossMode', 'ideal', ...
    'OutputDir', outDir);

okNotProv = ~s.provisional;
okWarn    = strcmp(s.status, 'WARN');
okFlag    = ~s.adequacy.adequate && iHasAll(s.adequacy.flags, {'undersampled_carrier'});
okSpc     = s.adequacy.samples_per_carrier < 20;
okFiles   = iArtifactsExist(outDir);

c.name = 'Case C: undersampled carrier -> WARN (adequacy, not provisional)';
c.passed = okNotProv && okWarn && okFlag && okSpc && okFiles;
c.detail = sprintf('provisional=%d status=%s spc=%.3g flags={%s} files=%d', ...
    s.provisional, s.status, s.adequacy.samples_per_carrier, ...
    strjoin(s.adequacy.flags, ','), okFiles);
end


function c = iCaseDeadtime(projectRoot)
% Documented and well-resolved carrier, but dead-time is smaller than one
% fixed step, so the grid cannot represent it: WARN with deadtime_below_one_step.
ts = 2e-6; t = (0:ts:0.04-ts)';
f0 = 50; fc = 5000;
x = sin(2*pi*f0*t) + 0.05*sin(2*pi*fc*t);
outDir = fullfile(projectRoot, 'build', 'reports', 'e1_emt_switching', 'synthetic_deadtime');
s = summarize_switching_waveform_evidence(t, x, ...
    'CaseName', 'synthetic_deadtime', 'Signal', 'voltage', ...
    'FundamentalHz', f0, 'CarrierHz', fc, 'SampleTimeS', ts, ...
    'DeadTimeS', 5e-7, 'ModulationMethod', 'SVPWM', ...
    'DeviceLossMode', 'on-resistance+Vf', ...
    'OutputDir', outDir);

okNotProv = ~s.provisional;
okWarn    = strcmp(s.status, 'WARN');
okFlag    = iHasAll(s.adequacy.flags, {'deadtime_below_one_step'});
okSteps   = s.adequacy.deadtime_steps < 1;
okFiles   = iArtifactsExist(outDir);

c.name = 'Case D: dead-time below one step -> WARN';
c.passed = okNotProv && okWarn && okFlag && okSteps && okFiles;
c.detail = sprintf('provisional=%d status=%s deadtime_steps=%.3g flags={%s} files=%d', ...
    s.provisional, s.status, s.adequacy.deadtime_steps, ...
    strjoin(s.adequacy.flags, ','), okFiles);
end


function c = iCaseTooShort(projectRoot)
% Fewer than 8 samples cannot be transformed: MISSING.
ts = 2e-6; t = (0:ts:5*ts)';      % 6 samples
x = sin(2*pi*50*t);
outDir = fullfile(projectRoot, 'build', 'reports', 'e1_emt_switching', 'synthetic_tooshort');
s = summarize_switching_waveform_evidence(t, x, ...
    'CaseName', 'synthetic_tooshort', 'Signal', 'current', ...
    'FundamentalHz', 50, 'CarrierHz', 5000, 'SampleTimeS', ts, ...
    'ModulationMethod', 'SPWM', ...
    'OutputDir', outDir);

okMissing = strcmp(s.status, 'MISSING');
okNoLoc   = ~s.fundamental_well_located;
okFiles   = iArtifactsExist(outDir);

c.name = 'Case E: too-short waveform -> MISSING';
c.passed = okMissing && okNoLoc && okFiles;
c.detail = sprintf('status=%s located=%d files=%d', ...
    s.status, s.fundamental_well_located, okFiles);
end


function tf = iHasAll(haystack, needed)
tf = true;
for k = 1:numel(needed)
    if ~any(strcmp(haystack, needed{k}))
        tf = false;
        return
    end
end
end


function tf = iArtifactsExist(outDir)
tf = isfile(fullfile(outDir, 'switching_summary.md')) && ...
     isfile(fullfile(outDir, 'switching_summary.json')) && ...
     isfile(fullfile(outDir, 'switching_spectrum.csv'));
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
