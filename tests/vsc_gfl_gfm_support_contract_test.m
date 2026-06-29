function result = vsc_gfl_gfm_support_contract_test()
%VSC_GFL_GFM_SUPPORT_CONTRACT_TEST Synthetic contract test for the D1 helper.
%   Exercises summarize_vsc_gfl_gfm_support across six synthetic cases:
%     A) documented GFM with real same-study evidence files -> assumption dims
%        PASS, artifacts PASS, not provisional, consistent, handoff_ready=1.
%     B) documented GFL (PLL) with evidence files -> PASS dims, consistent.
%     C) provisional case (missing identity) -> provisional=1 and every
%        artifact PASS downgraded to WARN (a draft cannot overclaim).
%     D) mode-inconsistent (GFL declared but grid-forming sync) -> the
%        consistency screen fires and handoff_ready=0.
%     E) required artifact whose path is supplied but absent -> MISSING.
%     F) required dimension given only a case label (no artifact file) -> WARN,
%        not PASS (a label is intent, not evidence), and handoff_ready=0.
%
%   No Simulink, no toolbox dependency: pure synthetic descriptors through the
%   base-MATLAB helper. Returns a struct and prints PASS/FAIL per check.
%
%   Scratch evidence + output dirs are created under
%   build/reports/d1_vsc_gfl_gfm/contract_scratch/ and removed at end of run so
%   a later review cannot pick up a stale PASS.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

scratch = fullfile(projectRoot, 'build', 'reports', 'd1_vsc_gfl_gfm', 'contract_scratch');
iResetDir(scratch);
cleanup = onCleanup(@() iRemoveDir(scratch));

% Real evidence files so artifact dimensions can reach PASS legitimately.
evDir = fullfile(scratch, 'evidence');
iResetDir(evDir);
frtFile = iTouch(fullfile(evDir, 'frt_three_phase.json'));
tdFile  = iTouch(fullfile(evDir, 'emt_run.json'));
zFile   = iTouch(fullfile(evDir, 'impedance_summary.json'));

checks = struct([]);
checks = iAddCheck(checks, iCaseDocumentedGfm(scratch, frtFile, tdFile, zFile));
checks = iAddCheck(checks, iCaseDocumentedGfl(scratch, frtFile, tdFile));
checks = iAddCheck(checks, iCaseProvisional(scratch, tdFile));
checks = iAddCheck(checks, iCaseInconsistent(scratch, frtFile, tdFile));
checks = iAddCheck(checks, iCaseMissingArtifact(scratch));
checks = iAddCheck(checks, iCaseLabelOnly(scratch, tdFile));

allPass = all([checks.passed]);
fprintf('\n=== vsc_gfl_gfm_support_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), sum([checks.passed]), numel(checks));

result = struct('passed', allPass, 'checks', checks);
end


function c = iCaseDocumentedGfm(scratch, frtFile, tdFile, zFile)
% Fully documented grid-forming case with real same-study evidence files.
d = struct();
d.case_name = 'gfm_weakgrid';
d.control_mode = 'GFM';
d.evidence_source = 'simulated';
d.operating_point = '0.8pu, SCR=2.0';
d.base_values = struct('s_base_mva', 100, 'v_base_kv', 33, 'f_base_hz', 50);
d.grid_strength = struct('scr', 2.0, 'method', 'thevenin_L');
d.synchronization = struct('type', 'vsg');
d.active_power_control = struct('mode', 'f_droop');
d.reactive_power_control = struct('mode', 'v_droop');
d.fault_ride_through = struct('case', 'three_phase', 'artifact', frtFile, 'required', true);
d.modal_evidence = struct('artifact', zFile, 'required', false);
d.impedance_evidence = struct('artifact', zFile, 'required', false);
d.time_domain_validation = struct('artifact', tdFile, 'required', true);

outDir = fullfile(scratch, 'gfm_weakgrid');
s = summarize_vsc_gfl_gfm_support(d, 'OutputDir', outDir);

okProv   = ~s.provisional;
okConsis = s.consistency.consistent;
okNoMiss = s.status_counts.MISSING == 0;
okArtPass = iDimStatus(s, 'time_domain_validation') == "PASS" && ...
            iDimStatus(s, 'fault_ride_through') == "PASS";
okReady  = s.handoff_ready;
okFiles  = iArtifactsExist(outDir);

c.name = 'Case A: documented GFM + real evidence -> PASS, handoff_ready';
c.passed = okProv && okConsis && okNoMiss && okArtPass && okReady && okFiles;
c.detail = sprintf(['provisional=%d(want0) consistent=%d MISSING=%d(want0) ', ...
    'artifactPASS=%d handoff_ready=%d(want1) artifacts=%d'], ...
    s.provisional, okConsis, s.status_counts.MISSING, okArtPass, s.handoff_ready, okFiles);
end


function c = iCaseDocumentedGfl(scratch, frtFile, tdFile)
% Documented grid-following case (PLL sync) with required evidence files.
d = struct();
d.case_name = 'gfl_nominal';
d.control_mode = 'GFL';
d.evidence_source = 'simulated';
d.operating_point = '1.0pu, SCR=5';
d.base_values = struct('s_base_mva', 50);
d.grid_strength = struct('scr', 5.0, 'method', 'thevenin_L');
d.synchronization = struct('type', 'pll');
d.active_power_control = struct('mode', 'p_setpoint');
d.reactive_power_control = struct('mode', 'q_setpoint');
d.fault_ride_through = struct('case', 'slg', 'artifact', frtFile, 'required', true);
d.time_domain_validation = struct('artifact', tdFile, 'required', true);

outDir = fullfile(scratch, 'gfl_nominal');
s = summarize_vsc_gfl_gfm_support(d, 'OutputDir', outDir);

okProv   = ~s.provisional;
okConsis = s.consistency.consistent;
okMode   = strcmp(s.control_mode, 'GFL');
okArtPass = iDimStatus(s, 'time_domain_validation') == "PASS";
okReady  = s.handoff_ready;

c.name = 'Case B: documented GFL (PLL) -> PASS, consistent';
c.passed = okProv && okConsis && okMode && okArtPass && okReady;
c.detail = sprintf('provisional=%d consistent=%d mode=%s td=%s handoff_ready=%d', ...
    s.provisional, okConsis, s.control_mode, iDimStatus(s, 'time_domain_validation'), s.handoff_ready);
end


function c = iCaseProvisional(scratch, tdFile)
% Identity undocumented: no mode, no grid strength, no op point, no base.
% A real evidence file is supplied, but because the case is provisional the
% artifact PASS must be downgraded to WARN so the draft cannot overclaim.
d = struct();
d.case_name = 'undocumented_draft';
d.time_domain_validation = struct('artifact', tdFile, 'required', true);

outDir = fullfile(scratch, 'undocumented_draft');
s = summarize_vsc_gfl_gfm_support(d, 'OutputDir', outDir);

okProv  = s.provisional;
okMiss  = iHasMissing(s.missing_documentation, ...
    {'control_mode', 'operating_point', 'grid_strength', 'base_values'});
okWarn  = iDimStatus(s, 'time_domain_validation') == "WARN";  % downgraded
okNoPass = s.status_counts.PASS == 0;  % no assumption documented either
okReady = ~s.handoff_ready;

c.name = 'Case C: provisional draft -> artifact PASS downgraded to WARN';
c.passed = okProv && okMiss && okWarn && okNoPass && okReady;
c.detail = sprintf(['provisional=%d(want1) missing_all=%d td=%s(want WARN) ', ...
    'PASS=%d(want0) handoff_ready=%d(want0)'], ...
    s.provisional, okMiss, iDimStatus(s, 'time_domain_validation'), ...
    s.status_counts.PASS, s.handoff_ready);
end


function c = iCaseInconsistent(scratch, frtFile, tdFile)
% Fully documented but the declared synchronization contradicts the mode:
% GFL with a grid-forming (vsg) sync. The consistency screen must fire and
% block handoff readiness even though no dimension is MISSING.
d = struct();
d.case_name = 'gfl_but_vsg';
d.control_mode = 'GFL';
d.evidence_source = 'simulated';
d.operating_point = '0.9pu, SCR=3';
d.base_values = struct('s_base_mva', 100);
d.grid_strength = struct('scr', 3.0, 'method', 'thevenin_L');
d.synchronization = struct('type', 'vsg');     % contradicts GFL
d.active_power_control = struct('mode', 'p_setpoint');
d.reactive_power_control = struct('mode', 'q_setpoint');
d.fault_ride_through = struct('case', 'three_phase', 'artifact', frtFile, 'required', true);
d.time_domain_validation = struct('artifact', tdFile, 'required', true);

outDir = fullfile(scratch, 'gfl_but_vsg');
s = summarize_vsc_gfl_gfm_support(d, 'OutputDir', outDir);

okInconsis = ~s.consistency.consistent && ~isempty(s.consistency.issues);
okNoMiss   = s.status_counts.MISSING == 0;   % documentation is complete
okReady    = ~s.handoff_ready;               % but consistency blocks handoff

c.name = 'Case D: GFL declared with grid-forming sync -> consistency blocks handoff';
c.passed = okInconsis && okNoMiss && okReady;
c.detail = sprintf('consistent=%d nissues=%d MISSING=%d(want0) handoff_ready=%d(want0)', ...
    s.consistency.consistent, numel(s.consistency.issues), s.status_counts.MISSING, s.handoff_ready);
end


function c = iCaseMissingArtifact(scratch)
% A required artifact whose path is supplied but the file does not exist ->
% MISSING, not PASS. Documented identity so the case is not provisional;
% this isolates the artifact-existence check.
d = struct();
d.case_name = 'missing_td_artifact';
d.control_mode = 'GFM';
d.evidence_source = 'planned';
d.operating_point = '0.8pu, SCR=2';
d.base_values = struct('s_base_mva', 100);
d.grid_strength = struct('scr', 2.0, 'method', 'thevenin_L');
d.synchronization = struct('type', 'vsg');
d.active_power_control = struct('mode', 'f_droop');
d.reactive_power_control = struct('mode', 'v_droop');
d.time_domain_validation = struct('artifact', ...
    fullfile(scratch, 'does_not_exist_emt.json'), 'required', true);

outDir = fullfile(scratch, 'missing_td_artifact');
s = summarize_vsc_gfl_gfm_support(d, 'OutputDir', outDir);

okProv    = ~s.provisional;     % identity documented
okMissing = iDimStatus(s, 'time_domain_validation') == "MISSING";
okReady   = ~s.handoff_ready;

c.name = 'Case E: required artifact path supplied but file absent -> MISSING';
c.passed = okProv && okMissing && okReady;
c.detail = sprintf('provisional=%d(want0) td=%s(want MISSING) handoff_ready=%d(want0)', ...
    s.provisional, iDimStatus(s, 'time_domain_validation'), s.handoff_ready);
end


function c = iCaseLabelOnly(scratch, tdFile)
% A required fault-ride-through dimension given only a case LABEL (no artifact
% file) is intent, not evidence: it must read WARN, not PASS, and block
% handoff. Identity is documented and the time-domain artifact is real, so
% this isolates the label-only behaviour from the provisional downgrade.
d = struct();
d.case_name = 'frt_label_only';
d.control_mode = 'GFM';
d.evidence_source = 'planned';
d.operating_point = '0.8pu, SCR=2';
d.base_values = struct('s_base_mva', 100);
d.grid_strength = struct('scr', 2.0, 'method', 'thevenin_L');
d.synchronization = struct('type', 'vsg');
d.active_power_control = struct('mode', 'f_droop');
d.reactive_power_control = struct('mode', 'v_droop');
d.fault_ride_through = struct('case', 'three_phase', 'required', true);  % label, no file
d.time_domain_validation = struct('artifact', tdFile, 'required', true);

outDir = fullfile(scratch, 'frt_label_only');
s = summarize_vsc_gfl_gfm_support(d, 'OutputDir', outDir);

okProv  = ~s.provisional;                                       % identity documented
okWarn  = iDimStatus(s, 'fault_ride_through') == "WARN";        % label-only -> WARN
okTdPass = iDimStatus(s, 'time_domain_validation') == "PASS";   % real file still PASS
okReady = ~s.handoff_ready;                                     % WARN blocks handoff

c.name = 'Case F: fault-case label without a file -> WARN, blocks handoff';
c.passed = okProv && okWarn && okTdPass && okReady;
c.detail = sprintf(['provisional=%d(want0) frt=%s(want WARN) td=%s(want PASS) ', ...
    'handoff_ready=%d(want0)'], ...
    s.provisional, iDimStatus(s, 'fault_ride_through'), ...
    iDimStatus(s, 'time_domain_validation'), s.handoff_ready);
end


function st = iDimStatus(s, name)
st = "ABSENT";
for k = 1:numel(s.dimensions)
    if strcmp(s.dimensions(k).name, name)
        st = string(s.dimensions(k).status);
        return
    end
end
end


function tf = iHasMissing(missingList, wanted)
tf = true;
for k = 1:numel(wanted)
    if ~any(strcmp(missingList, wanted{k}))
        tf = false;
        return
    end
end
end


function tf = iArtifactsExist(outDir)
tf = isfile(fullfile(outDir, 'vsc_gfl_gfm_support.md')) && ...
     isfile(fullfile(outDir, 'vsc_gfl_gfm_support.json'));
end


function path = iTouch(path)
fid = fopen(path, 'w');
if fid >= 0
    fprintf(fid, '{"synthetic":true}\n');
    fclose(fid);
end
end


function iResetDir(d)
if isfolder(d)
    rmdir(d, 's');
end
mkdir(d);
end


function iRemoveDir(d)
if isfolder(d)
    rmdir(d, 's');
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
