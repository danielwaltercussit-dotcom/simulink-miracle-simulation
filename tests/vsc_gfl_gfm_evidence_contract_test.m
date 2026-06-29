function result = vsc_gfl_gfm_evidence_contract_test()
%VSC_GFL_GFM_EVIDENCE_CONTRACT_TEST Tests for the D1 same-iteration composer
%   and the GFL/GFM comparison-completeness checker.
%
%   Composer cases (compose_vsc_gfl_gfm_evidence):
%     1) same-iteration artifacts are USED and reach the support helper;
%     2) an artifact under a DIFFERENT iteration dir is rejected as STALE and
%        does NOT produce a downstream PASS;
%     3) a sibling iteration dir whose name is a prefix of the current one
%        (iter2 vs iter) is NOT mistaken for same-iteration;
%     4) a supplied-but-absent path is MISSING, not stale.
%
%   Comparison cases (compare_vsc_gfl_gfm_completeness):
%     5) a complete GFL+GFM pair with shared fairness axes -> complete;
%     6) a shared-axis mismatch without justification -> incomplete;
%     7) two same-mode cases (no GFL+GFM coverage) -> incomplete;
%     8) an individually incomplete case (MISSING required artifact) -> the
%        pair is incomplete even when axes match.
%
%   No Simulink, no toolbox dependency. Scratch lives under
%   build/reports/d1_vsc_gfl_gfm/evidence_scratch/ and is removed at end.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

scratch = fullfile(projectRoot, 'build', 'reports', 'd1_vsc_gfl_gfm', 'evidence_scratch');
iResetDir(scratch);
cleanup = onCleanup(@() iRemoveDir(scratch));

checks = struct([]);
checks = iAddCheck(checks, iCaseSameIterationUsed(scratch));
checks = iAddCheck(checks, iCaseCrossIterationStale(scratch));
checks = iAddCheck(checks, iCaseSiblingPrefixNotSame(scratch));
checks = iAddCheck(checks, iCaseMissingPath(scratch));
checks = iAddCheck(checks, iCaseComparisonComplete(scratch));
checks = iAddCheck(checks, iCaseComparisonAxisMismatch(scratch));
checks = iAddCheck(checks, iCaseComparisonModeCoverage(scratch));
checks = iAddCheck(checks, iCaseComparisonIncompleteCase(scratch));

allPass = all([checks.passed]);
fprintf('\n=== vsc_gfl_gfm_evidence_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), sum([checks.passed]), numel(checks));

result = struct('passed', allPass, 'checks', checks);
end


% ---- Composer: same-iteration acceptance --------------------------------

function c = iCaseSameIterationUsed(scratch)
iter = fullfile(scratch, 'run', 'iter_005');
z  = iTouch(fullfile(iter, 'impedance', 'z.json'));
td = iTouch(fullfile(iter, 'emt', 'run.json'));
frt = iTouch(fullfile(iter, 'frt', 'frt.json'));

d = iBaseCase('compose_used', 'GFM', 'vsg', 'v_droop');
d.fault_ride_through = struct('required', true);   % path attached by composer
d.time_domain_validation = struct('required', true);
d.impedance_evidence = struct('required', false);

s = compose_vsc_gfl_gfm_evidence(d, iter, ...
    'ImpedancePath', z, 'TimeDomainPath', td, 'WeakGridScrPath', frt, ...
    'OutputDir', fullfile(iter, 'composed'));

okUsed  = s.n_used == 3 && s.n_stale == 0 && s.n_missing == 0;
okZ     = iDimStatus(s.support, 'impedance_evidence') == "PASS";
okTd    = iDimStatus(s.support, 'time_domain_validation') == "PASS";
okFiles = isfile(fullfile(iter, 'composed', 'vsc_evidence_composition.md'));

c.name = 'Composer 1: same-iteration artifacts used -> downstream PASS';
c.passed = okUsed && okZ && okTd && okFiles;
c.detail = sprintf('used=%d stale=%d missing=%d z=%s td=%s files=%d', ...
    s.n_used, s.n_stale, s.n_missing, ...
    iDimStatus(s.support, 'impedance_evidence'), ...
    iDimStatus(s.support, 'time_domain_validation'), okFiles);
end


function c = iCaseCrossIterationStale(scratch)
% An impedance artifact from iter_001 must be rejected when iter_002 is
% current, and must NOT make impedance_evidence read PASS.
cur = fullfile(scratch, 'xrun', 'iter_002');
old = fullfile(scratch, 'xrun', 'iter_001');
iMkdir(cur);
zOld = iTouch(fullfile(old, 'impedance', 'z.json'));

d = iBaseCase('compose_stale', 'GFM', 'vsg', 'v_droop');
d.impedance_evidence = struct('required', false);

s = compose_vsc_gfl_gfm_evidence(d, cur, 'ImpedancePath', zOld);

stale = s.intake(arrayfun(@(x) strcmp(x.name, 'impedance_evidence'), s.intake));
okStale = ~isempty(stale) && stale.status == "stale";
okHasStale = s.has_stale_rejected && s.n_stale == 1;
% Rejected -> never reaches helper -> dimension is N/A (not PASS), since not required.
okNotPass = iDimStatus(s.support, 'impedance_evidence') ~= "PASS";

c.name = 'Composer 2: cross-iteration artifact rejected as stale, no PASS';
c.passed = okStale && okHasStale && okNotPass;
c.detail = sprintf('impedance intake=%s has_stale=%d n_stale=%d downstream=%s(want != PASS)', ...
    stale.status, s.has_stale_rejected, s.n_stale, iDimStatus(s.support, 'impedance_evidence'));
end


function c = iCaseSiblingPrefixNotSame(scratch)
% iter_2 must NOT be treated as same-iteration when iter is current, even
% though "iter" is a string prefix of "iter_2"/"iter2".
cur = fullfile(scratch, 'prefix', 'iter');
sib = fullfile(scratch, 'prefix', 'iter2');
iMkdir(cur);
zSib = iTouch(fullfile(sib, 'z.json'));

d = iBaseCase('compose_prefix', 'GFM', 'vsg', 'v_droop');
d.impedance_evidence = struct('required', false);

s = compose_vsc_gfl_gfm_evidence(d, cur, 'ImpedancePath', zSib);
imp = s.intake(arrayfun(@(x) strcmp(x.name, 'impedance_evidence'), s.intake));

c.name = 'Composer 3: sibling prefix dir (iter2 vs iter) is not same-iteration';
c.passed = imp.status == "stale" && s.n_used == 0;
c.detail = sprintf('intake=%s (want stale) n_used=%d (want 0)', imp.status, s.n_used);
end


function c = iCaseMissingPath(scratch)
cur = fullfile(scratch, 'missrun', 'iter_001');
iMkdir(cur);
ghost = fullfile(cur, 'impedance', 'does_not_exist.json');  % never created

d = iBaseCase('compose_missing', 'GFM', 'vsg', 'v_droop');
d.impedance_evidence = struct('required', false);

s = compose_vsc_gfl_gfm_evidence(d, cur, 'ImpedancePath', ghost);
imp = s.intake(arrayfun(@(x) strcmp(x.name, 'impedance_evidence'), s.intake));

c.name = 'Composer 4: supplied-but-absent path -> missing (not stale)';
c.passed = imp.status == "missing" && s.n_stale == 0 && s.n_missing == 1;
c.detail = sprintf('intake=%s (want missing) n_stale=%d n_missing=%d', ...
    imp.status, s.n_stale, s.n_missing);
end


% ---- Comparison: GFL/GFM completeness -----------------------------------

function c = iCaseComparisonComplete(scratch)
iter = fullfile(scratch, 'cmp', 'iter_001');
td  = iTouch(fullfile(iter, 'emt', 'run.json'));
frt = iTouch(fullfile(iter, 'frt', 'frt.json'));
gfl = iComparableCase('cmp_gfl', 'GFL', 'pll', 'q_setpoint', 'IEEE39', td, frt);
gfm = iComparableCase('cmp_gfm', 'GFM', 'vsg', 'v_droop',   'IEEE39', td, frt);

r = compare_vsc_gfl_gfm_completeness(gfl, gfm, ...
    'OutputDir', fullfile(iter, 'comparison'));

okComplete = r.comparison_complete;
okMode = r.mode_coverage_ok;
okAxes = r.shared_axes_ok;
okReady = r.case_a_handoff_ready && r.case_b_handoff_ready;
okFiles = isfile(fullfile(iter, 'comparison', 'vsc_gfl_gfm_comparison_completeness.md'));

c.name = 'Comparison 5: complete GFL+GFM pair, shared axes -> complete';
c.passed = okComplete && okMode && okAxes && okReady && okFiles;
c.detail = sprintf('complete=%d mode_ok=%d axes_ok=%d A_ready=%d B_ready=%d files=%d', ...
    r.comparison_complete, okMode, okAxes, r.case_a_handoff_ready, r.case_b_handoff_ready, okFiles);
end


function c = iCaseComparisonAxisMismatch(scratch)
iter = fullfile(scratch, 'cmp2', 'iter_001');
td  = iTouch(fullfile(iter, 'emt', 'run.json'));
frt = iTouch(fullfile(iter, 'frt', 'frt.json'));
gfl = iComparableCase('cmp_gfl', 'GFL', 'pll', 'q_setpoint', 'IEEE39',  td, frt);
gfm = iComparableCase('cmp_gfm', 'GFM', 'vsg', 'v_droop',   'IEEE118', td, frt);  % different network

r = compare_vsc_gfl_gfm_completeness(gfl, gfm);
okIncomplete = ~r.comparison_complete;
okAxesFail = ~r.shared_axes_ok;
okModeOk = r.mode_coverage_ok;   % modes are fine; only the axis differs

c.name = 'Comparison 6: unjustified network mismatch -> incomplete';
c.passed = okIncomplete && okAxesFail && okModeOk;
c.detail = sprintf('complete=%d(want0) axes_ok=%d(want0) mode_ok=%d(want1)', ...
    r.comparison_complete, r.shared_axes_ok, r.mode_coverage_ok);
end


function c = iCaseComparisonModeCoverage(scratch)
iter = fullfile(scratch, 'cmp3', 'iter_001');
td  = iTouch(fullfile(iter, 'emt', 'run.json'));
frt = iTouch(fullfile(iter, 'frt', 'frt.json'));
gfl1 = iComparableCase('cmp_gfl_a', 'GFL', 'pll', 'q_setpoint', 'IEEE39', td, frt);
gfl2 = iComparableCase('cmp_gfl_b', 'GFL', 'pll', 'q_setpoint', 'IEEE39', td, frt);

r = compare_vsc_gfl_gfm_completeness(gfl1, gfl2);
okIncomplete = ~r.comparison_complete;
okModeFail = ~r.mode_coverage_ok;   % two GFL, no GFM

c.name = 'Comparison 7: two same-mode cases -> mode coverage fails';
c.passed = okIncomplete && okModeFail;
c.detail = sprintf('complete=%d(want0) mode_ok=%d(want0)', ...
    r.comparison_complete, r.mode_coverage_ok);
end


function c = iCaseComparisonIncompleteCase(scratch)
% Axes match and modes cover GFL+GFM, but the GFM case is missing its
% required time-domain artifact, so the pair must still be incomplete.
iter = fullfile(scratch, 'cmp4', 'iter_001');
td  = iTouch(fullfile(iter, 'emt', 'run.json'));
frt = iTouch(fullfile(iter, 'frt', 'frt.json'));
gfl = iComparableCase('cmp_gfl', 'GFL', 'pll', 'q_setpoint', 'IEEE39', td, frt);
gfm = iComparableCase('cmp_gfm', 'GFM', 'vsg', 'v_droop',   'IEEE39', td, frt);
gfm.time_domain_validation = struct('required', true);   % drop the artifact path -> MISSING

r = compare_vsc_gfl_gfm_completeness(gfl, gfm);
okIncomplete = ~r.comparison_complete;
okBReady = ~r.case_b_handoff_ready;   % GFM case incomplete
okMode = r.mode_coverage_ok;
okAxes = r.shared_axes_ok;            % axes themselves still match

c.name = 'Comparison 8: individually incomplete case -> pair incomplete';
c.passed = okIncomplete && okBReady && okMode && okAxes;
c.detail = sprintf('complete=%d(want0) B_ready=%d(want0) mode_ok=%d axes_ok=%d', ...
    r.comparison_complete, r.case_b_handoff_ready, r.mode_coverage_ok, r.shared_axes_ok);
end


% ---- Shared builders / utilities ----------------------------------------

function d = iBaseCase(name, mode, sync, qmode)
d = struct();
d.case_name = name;
d.control_mode = mode;
d.evidence_source = 'simulated';
d.operating_point = '0.8pu, SCR=2';
d.base_values = struct('s_base_mva', 100);
d.grid_strength = struct('scr', 2.0, 'method', 'thevenin_L');
d.synchronization = struct('type', sync);
d.active_power_control = struct('mode', 'p_setpoint');
d.reactive_power_control = struct('mode', qmode);
end


function d = iComparableCase(name, mode, sync, qmode, network, td, frt)
d = iBaseCase(name, mode, sync, qmode);
d.fault_ride_through = struct('artifact', frt, 'required', true);
d.time_domain_validation = struct('artifact', td, 'required', true);
d.comparison_axes = struct('network', network, 'dispatch', 'D1', ...
    'disturbance', '3ph@1s', 'observables', 'V,f,P,Q');
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


function p = iTouch(p)
iMkParent(p);
fid = fopen(p, 'w');
if fid >= 0
    fprintf(fid, '{"synthetic":true}\n');
    fclose(fid);
end
end


function iMkParent(p)
parent = fileparts(p);
if ~isempty(parent) && ~isfolder(parent)
    mkdir(parent);
end
end


function iMkdir(d)
if ~isfolder(d)
    mkdir(d);
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
