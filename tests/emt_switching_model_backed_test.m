function result = emt_switching_model_backed_test()
%EMT_SWITCHING_MODEL_BACKED_TEST Model-level (real Simulink) E1 evidence test.
%   Completes the E1 model-level evidence task by exercising the model-backed
%   path in a committed, reproducible test rather than only manually:
%     1. build_tiny_switching_example actually builds + compiles + simulates a
%        tiny non-private half-bridge SPWM leg;
%     2. its SimulationOutput is ingested through ingest_switching_waveform_evidence;
%     3. the result MUST be model_backed=true, fundamental located, carrier
%        resolved, and write artifacts to disk.
%
%   This test REQUIRES Simulink. If Simulink is unavailable (license or install)
%   it returns a skipped (non-failing) result with a clear reason, so a base
%   install still gets a green suite from the Simulink-free contract tests. It
%   does NOT silently pass a model claim it never ran: skipped != model_backed.
%
%   Memory note: Simulink core can fail to load under low system memory. The
%   test attempts a bdclose/retry once; a hard load failure is reported as a
%   skip with the environment reason, not a false PASS.
%
%   Package: E1 EMT/switching-level converter modeling.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

[ok, reason] = iSimulinkAvailable();
if ~ok
    fprintf('\n=== emt_switching_model_backed_test ===\n');
    fprintf('[SKIP] Simulink unavailable: %s\n', reason);
    fprintf('Overall: SKIP (model-level evidence not run; not a model_backed claim)\n');
    result = struct('passed', true, 'skipped', true, 'reason', reason, 'checks', struct([]));
    return
end

outDir = fullfile(projectRoot, 'build', 'reports', 'e1_emt_switching', 'model_backed_tiny_leg');
checks = struct([]);
checks = iAddCheck(checks, iModelBackedCase(outDir));

allPass = all([checks.passed]);
fprintf('\n=== emt_switching_model_backed_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d, real Simulink run)\n', iTag(allPass), nnz([checks.passed]), numel(checks));

result = struct('passed', allPass, 'skipped', false, 'reason', '', 'checks', checks);
end


function [ok, reason] = iSimulinkAvailable()
ok = false; reason = '';
if ~license('test', 'Simulink') || isempty(ver('simulink'))
    reason = 'Simulink not licensed or not installed';
    return
end
try
    bdclose('all');
    probe = 'e1_simulink_probe';
    new_system(probe); close_system(probe, 0);
    ok = true;
catch ME
    reason = ME.message;
end
end


function c = iModelBackedCase(outDir)
c.name = 'Model-backed: tiny SPWM leg simulated -> model_backed evidence';
fc = 2000; ts = 5e-6;
try
    art = build_tiny_switching_example('StopTime', 0.04, 'SampleTimeS', ts, ...
        'CarrierHz', fc, 'OutputDir', outDir);
    s = ingest_switching_waveform_evidence(art, ...
        'CaseName', 'tiny_leg_model_backed', 'Signal', 'current', ...
        'FundamentalHz', 50, 'CarrierHz', fc, 'SampleTimeS', ts, ...
        'ModulationMethod', 'SPWM', 'DeviceLossMode', 'ideal', ...
        'Solver', 'fixed-step discrete', 'Units', 'A', ...
        'TransientEventWindowS', [0.01 0.03], 'OutputDir', outDir);
catch ME
    c.passed = false;
    c.detail = sprintf('build/sim/ingest threw: %s', ME.message);
    iCloseQuietly();
    return
end
iCloseQuietly();

okMb   = s.model_backed && strcmp(s.provenance.evidence_level, 'model_backed');
okSrc  = strcmp(s.provenance.source_type, 'simulation_output') && ~s.provenance.synthetic;
okLoc  = s.fundamental_well_located && abs(s.spectrum.fundamental_hz - 50) <= 1;
okCarr = s.carrier_band.applicable && s.adequacy.samples_per_carrier >= 20;
okRan  = numel(art.t) > 1000;                       % a real multi-cycle run
% Re-read from disk so the PASS is not trusted from memory only.
okDisk = iDiskModelBacked(outDir);

c.passed = okMb && okSrc && okLoc && okCarr && okRan && okDisk;
c.detail = sprintf(['n=%d model_backed=%d level=%s src=%s synth=%d fund=%.4g ', ...
    'spc=%.4g disk_mb=%d'], ...
    numel(art.t), s.model_backed, s.provenance.evidence_level, ...
    s.provenance.source_type, s.provenance.synthetic, s.spectrum.fundamental_hz, ...
    s.adequacy.samples_per_carrier, okDisk);
end


function tf = iDiskModelBacked(outDir)
jsonPath = fullfile(outDir, 'switching_summary.json');
if ~isfile(jsonPath)
    tf = false;
    return
end
j = jsondecode(fileread(jsonPath));
tf = isfield(j, 'model_backed') && j.model_backed == 1 && ...
     isfield(j.provenance, 'evidence_level') && ...
     strcmp(j.provenance.evidence_level, 'model_backed');
end


function iCloseQuietly()
try
    bdclose('all');
catch
end
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
