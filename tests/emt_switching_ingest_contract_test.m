function result = emt_switching_ingest_contract_test()
%EMT_SWITCHING_INGEST_CONTRACT_TEST Contract test for the E1 ingestion path.
%   Exercises ingest_switching_waveform_evidence across its source kinds and the
%   provenance/model_backed downgrade rule, WITHOUT running Simulink (synthetic
%   data only, so it runs on a base install and under memory pressure):
%     A) generated (t,x) struct, no provenance        -> contract_only, mb=0;
%     B) logged-signal struct (time+signals) with a    -> model_backed=1
%        documented simulation provenance;
%     C) MAT-file artifact with embedded provenance     -> model_backed=1,
%        source_path recorded;
%     D) generated struct that FALSELY embeds a         -> downgraded, mb=0
%        simulation_output provenance but synthetic=true;
%     E) "Signal" (summarizer arg) is not swallowed by  -> SignalName honoured,
%        "SignalName" (ingest arg) partial matching.       Signal forwarded.
%
%   The model-backed path is also exercised end-to-end against a real Simulink
%   run by build_tiny_switching_example, but that is intentionally NOT done here
%   so this test stays Simulink-free and fast. See the handoff packet.
%
%   Package: E1 EMT/switching-level converter modeling.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));
scratch = fullfile(projectRoot, 'build', 'reports', 'e1_emt_switching', '_ingest_scratch');
if ~isfolder(scratch); mkdir(scratch); end
cleanup = onCleanup(@() iCleanupScratch(scratch));

checks = struct([]);
checks = iAddCheck(checks, iCaseGenerated());
checks = iAddCheck(checks, iCaseSimStruct());
checks = iAddCheck(checks, iCaseMatFile(scratch));
checks = iAddCheck(checks, iCaseFalseProvenance());
checks = iAddCheck(checks, iCasePartialMatch());

allPass = all([checks.passed]);
fprintf('\n=== emt_switching_ingest_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), nnz([checks.passed]), numel(checks));

result = struct('passed', allPass, 'checks', checks);
end


function [t, x] = iWave()
ts = 2e-6; t = (0:ts:0.06-ts)';
x = sin(2*pi*50*t) + 0.08*sin(2*pi*150*t) + 0.1*sin(2*pi*5000*t);
end


function args = iCommon()
args = {'Signal','current','FundamentalHz',50,'CarrierHz',5000, ...
    'SampleTimeS',2e-6,'ModulationMethod','SPWM','DeviceLossMode','ideal','OutputDir',''};
end


function c = iCaseGenerated()
[t, x] = iWave();
cm = iCommon();
art = struct('t', t, 'x', x);
s = ingest_switching_waveform_evidence(art, cm{:}, 'CaseName','ingest_generated');
okLevel = strcmp(s.provenance.evidence_level, 'contract_only');
okMb    = ~s.model_backed && ~s.provenance_downgraded;
okData  = s.fundamental_well_located && abs(s.spectrum.fundamental_hz - 50) <= 1;
c.name = 'Case A: generated (t,x) struct -> contract_only';
c.passed = okLevel && okMb && okData;
c.detail = sprintf('level=%s mb=%d dg=%d fund=%.4g', ...
    s.provenance.evidence_level, s.model_backed, s.provenance_downgraded, s.spectrum.fundamental_hz);
end


function c = iCaseSimStruct()
[t, x] = iWave();
cm = iCommon();
lg = struct('time', t, 'signals', struct('values', x, 'label', 'Ia'));
prov = struct('source_id','tinyVSC_leg','model_name','tinyVSC_leg','simulated',true,'synthetic',false);
s = ingest_switching_waveform_evidence(lg, cm{:}, ...
    'SignalName','Ia', 'CaseName','ingest_simstruct', 'Provenance', prov);
okType  = strcmp(s.provenance.source_type, 'simulation_output');
okMb    = s.model_backed && ~s.provenance_downgraded && strcmp(s.provenance.evidence_level, 'model_backed');
okData  = s.fundamental_well_located;
c.name = 'Case B: sim-struct (time+signals) + provenance -> model_backed';
c.passed = okType && okMb && okData;
c.detail = sprintf('source_type=%s mb=%d level=%s', ...
    s.provenance.source_type, s.model_backed, s.provenance.evidence_level);
end


function c = iCaseMatFile(scratch)
[t, x] = iWave();
cm = iCommon();
matPath = fullfile(scratch, 'run.mat');
waveform = struct('t', t, 'x', x);
provenance = struct('source_type','mat_file','source_id','tinyVSC_run1', ...
    'model_name','tinyVSC','simulated',true,'synthetic',false,'captured_at','2026-06-06');
save(matPath, 'waveform', 'provenance');
s = ingest_switching_waveform_evidence(matPath, cm{:}, ...
    'MatVariable','waveform', 'CaseName','ingest_matfile');
okType = strcmp(s.provenance.source_type, 'mat_file');
okMb   = s.model_backed && strcmp(s.provenance.evidence_level, 'model_backed');
okPath = ~isempty(s.provenance.source_path) && contains(s.provenance.source_path, 'run.mat');
c.name = 'Case C: MAT-file + embedded provenance -> model_backed, path recorded';
c.passed = okType && okMb && okPath;
c.detail = sprintf('source_type=%s mb=%d path_set=%d', ...
    s.provenance.source_type, s.model_backed, okPath);
end


function c = iCaseFalseProvenance()
% A generated struct that LIES: it embeds source_type=simulation_output but
% synthetic=true. The synthetic flag must force the downgrade.
[t, x] = iWave();
cm = iCommon();
art = struct('t', t, 'x', x, ...
    'provenance', struct('source_type','simulation_output','source_id','x','synthetic',true));
s = ingest_switching_waveform_evidence(art, cm{:}, 'CaseName','ingest_false_prov');
okDown = ~s.model_backed && s.provenance_downgraded;
okReason = any(contains(string(s.provenance.downgrade_reasons), "synthetic"));
c.name = 'Case D: false simulation provenance (synthetic) -> downgraded';
c.passed = okDown && okReason;
c.detail = sprintf('mb=%d dg=%d reasons={%s}', ...
    s.model_backed, s.provenance_downgraded, strjoin(s.provenance.downgrade_reasons, ' | '));
end


function c = iCasePartialMatch()
% Regression: inputParser PartialMatching must be OFF so the summarizer's
% "Signal" arg is not consumed by the ingest "SignalName" parameter.
[t, x] = iWave();
cm = iCommon();
lg = struct('time', t, 'signals', struct('values', x, 'label', 'Ia'));
detail = 'forwarded Signal=current, SignalName=Ia both honoured';
try
    s = ingest_switching_waveform_evidence(lg, cm{:}, ...
        'SignalName','Ia', 'CaseName','ingest_partialmatch');
    ok = strcmp(s.signal, 'current');     % Signal reached the summarizer
catch ME
    ok = false; detail = ['threw: ' ME.message];
end
c.name = 'Case E: no Signal/SignalName partial-match collision';
c.passed = ok;
c.detail = detail;
end


function iCleanupScratch(scratch)
if isfolder(scratch)
    rmdir(scratch, 's');
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
