function result = cross_regulation_tuning_contract_test()
%CROSS_REGULATION_TUNING_CONTRACT_TEST Synthetic contract test for the F2 helper.
%   Exercises summarize_cross_regulation_tuning on synthetic cases that pin the
%   contract behaviour:
%     A) fully documented coupled dq current tuning, good margins
%        -> classification "documented_tuning", provisional=0;
%     B) a bare gain change with no rationale/margin/bandwidth/sampling
%        -> classification "undocumented_gain_tweak", provisional=1;
%     C) partial metadata (op-point/frame missing, some loop fields missing)
%        -> classification "provisional", missing_required lists the gaps;
%     D) strong off-diagonal cross-coupling -> coupling.strongly_coupled=1 and
%        the strong pair is reported;
%     E) documented metadata but a non-positive phase margin
%        -> classification "documented_at_risk", margin worst class "at_risk".
%
%   No Simulink, no toolbox dependency: pure synthetic structs through the
%   base-MATLAB helper. Returns a struct and prints PASS/FAIL per check.
%
%   Artifacts written under build/reports/f2_cross_regulation/<case>/, then the
%   scratch cases are cleaned so a later review cannot read a stale PASS.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'analysis'));

scratch = {};
checks = struct([]);
[c, d] = iCaseDocumented(projectRoot);   checks = iAddCheck(checks, c); scratch{end+1} = d;
[c, d] = iCaseUndocumented(projectRoot); checks = iAddCheck(checks, c); scratch{end+1} = d;
[c, d] = iCaseProvisional(projectRoot);  checks = iAddCheck(checks, c); scratch{end+1} = d;
[c, d] = iCaseStrongCoupling(projectRoot); checks = iAddCheck(checks, c); scratch{end+1} = d;
[c, d] = iCaseAtRisk(projectRoot);       checks = iAddCheck(checks, c); scratch{end+1} = d;
[c, d] = iCaseRgaDiagonal(projectRoot);  checks = iAddCheck(checks, c); scratch{end+1} = d;
[c, d] = iCaseRgaInteractive(projectRoot); checks = iAddCheck(checks, c); scratch{end+1} = d;
[c, d] = iCaseImprovementSupported(projectRoot); checks = iAddCheck(checks, c); scratch{end+1} = d;
[c, d] = iCaseImprovementUnverified(projectRoot); checks = iAddCheck(checks, c); scratch{end+1} = d;
[c, d] = iCaseRegression(projectRoot);   checks = iAddCheck(checks, c); scratch{end+1} = d;
[c, d] = iCaseDelayPhaseLoss(projectRoot); checks = iAddCheck(checks, c); scratch{end+1} = d;
[c, d] = iCasePseudoImprovement(projectRoot); checks = iAddCheck(checks, c); scratch{end+1} = d;
[c, d] = iCaseUndocumentedDelayChange(projectRoot); checks = iAddCheck(checks, c); scratch{end+1} = d;
[c, d] = iCaseLegitDelayImprovement(projectRoot); checks = iAddCheck(checks, c); scratch{end+1} = d;

allPass = all([checks.passed]);
fprintf('\n=== cross_regulation_tuning_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s\n', iTag(allPass));

iCleanup(scratch);
result = struct('passed', allPass, 'checks', checks);
end


function [c, outDir] = iCaseDocumented(projectRoot)
% Two coupled dq current loops, fully documented, healthy margins.
tuning = iBaseCoupledTuning();
outDir = iOutDir(projectRoot, 'doc_documented');
s = summarize_cross_regulation_tuning(tuning, ...
    'CaseName', 'doc_documented', 'OutputDir', outDir);

okClass = strcmp(s.classification, 'documented_tuning');
okProv  = ~s.provisional && isempty(s.missing_required);
okDoc   = s.n_documented == 2 && s.n_provisional == 0;
okGain  = s.n_gain_changes == 2;
okFiles = iArtifactsExist(outDir);

c.name = 'Case A: fully documented coupled tuning -> documented_tuning';
c.passed = okClass && okProv && okDoc && okGain && okFiles;
c.detail = sprintf('class=%s(want documented_tuning) provisional=%d(want 0) n_doc=%d(want 2) artifacts=%d', ...
    s.classification, s.provisional, s.n_documented, okFiles);
end


function [c, outDir] = iCaseUndocumented(projectRoot)
% Bare gain change: kp/ki move, but no sampling, bandwidth, saturation,
% margin, rationale, operating point, frame, or coupling. The case the
% contract must reject as evidence.
tuning = struct();
tuning.loops(1) = struct('name','id_current','kp_before',0.8,'kp_after',1.6, ...
    'ki_before',50,'ki_after',120);
outDir = iOutDir(projectRoot, 'doc_undocumented');
s = summarize_cross_regulation_tuning(tuning, ...
    'CaseName', 'doc_undocumented', 'OutputDir', outDir);

okClass = strcmp(s.classification, 'undocumented_gain_tweak');
okProv  = s.provisional;
okTweak = s.n_gain_changes == 1 && s.n_documented == 0;
okMiss  = any(strcmp(s.missing_required, 'operating_point')) && ...
          any(contains(s.missing_required, 'id_current.rationale'));
okFiles = iArtifactsExist(outDir);

c.name = 'Case B: bare gain change -> undocumented_gain_tweak';
c.passed = okClass && okProv && okTweak && okMiss && okFiles;
c.detail = sprintf('class=%s(want undocumented_gain_tweak) provisional=%d(want 1) n_doc=%d(want 0) miss_ok=%d artifacts=%d', ...
    s.classification, s.provisional, s.n_documented, okMiss, okFiles);
end
function [c, outDir] = iCaseProvisional(projectRoot)
% Documented loops but case-level metadata missing (no operating point/frame),
% and one loop missing its bandwidth target. Not a pure blind tweak, so it
% should land as "provisional", not "undocumented_gain_tweak".
tuning = iBaseCoupledTuning();
tuning = rmfield(tuning, 'operating_point');
tuning = rmfield(tuning, 'control_frame');
tuning.loops(2).bandwidth_target_hz = [];   % drop one required loop field
outDir = iOutDir(projectRoot, 'doc_provisional');
s = summarize_cross_regulation_tuning(tuning, ...
    'CaseName', 'doc_provisional', 'OutputDir', outDir);

okClass = strcmp(s.classification, 'provisional');
okProv  = s.provisional;
okCase  = any(strcmp(s.missing_required, 'operating_point')) && ...
          any(strcmp(s.missing_required, 'control_frame'));
okLoop  = any(contains(s.missing_required, 'iq_current.bandwidth_target_hz'));
okNotTweak = ~strcmp(s.classification, 'undocumented_gain_tweak');
okFiles = iArtifactsExist(outDir);

c.name = 'Case C: partial metadata -> provisional with listed gaps';
c.passed = okClass && okProv && okCase && okLoop && okNotTweak && okFiles;
c.detail = sprintf('class=%s(want provisional) case_miss=%d loop_miss=%d artifacts=%d', ...
    s.classification, okCase, okLoop, okFiles);
end


function [c, outDir] = iCaseStrongCoupling(projectRoot)
% Strong off-diagonal coupling must be detected and the pair reported.
tuning = iBaseCoupledTuning();
tuning.cross_coupling = [1 0.6; 0.6 1];   % 0.6 >= 0.30 default threshold
outDir = iOutDir(projectRoot, 'doc_strong_coupling');
s = summarize_cross_regulation_tuning(tuning, ...
    'CaseName', 'doc_strong_coupling', 'OutputDir', outDir);

okDoc    = s.coupling.documented;
okStrong = s.coupling.strongly_coupled;
okMax    = abs(s.coupling.max_off_diagonal - 0.6) < 1e-9;
okPairs  = ~isempty(s.coupling.strong_pairs);
okFiles  = iArtifactsExist(outDir);

c.name = 'Case D: strong off-diagonal coupling detected';
c.passed = okDoc && okStrong && okMax && okPairs && okFiles;
c.detail = sprintf('documented=%d strongly_coupled=%d max_off=%.3g n_pairs=%d artifacts=%d', ...
    okDoc, okStrong, s.coupling.max_off_diagonal, numel(s.coupling.strong_pairs), okFiles);
end


function [c, outDir] = iCaseAtRisk(projectRoot)
% Fully documented, but a non-positive phase margin must classify at_risk.
tuning = iBaseCoupledTuning();
tuning.loops(1).phase_margin_deg = -2;     % non-positive -> unstable screen
tuning.loops(2).phase_margin_deg = 55;
outDir = iOutDir(projectRoot, 'doc_at_risk');
s = summarize_cross_regulation_tuning(tuning, ...
    'CaseName', 'doc_at_risk', 'OutputDir', outDir);

okClass = strcmp(s.classification, 'documented_at_risk');
okProv  = ~s.provisional;
okWorst = strcmp(s.margin_assessment.worst_class, 'at_risk');
okFiles = iArtifactsExist(outDir);

c.name = 'Case E: documented but non-positive margin -> documented_at_risk';
c.passed = okClass && okProv && okWorst && okFiles;
c.detail = sprintf('class=%s(want documented_at_risk) provisional=%d(want 0) worst=%s artifacts=%d', ...
    s.classification, s.provisional, s.margin_assessment.worst_class, okFiles);
end


function [c, outDir] = iCaseRgaDiagonal(projectRoot)
% A near-identity gain matrix: RGA diagonal ~ 1, well-conditioned, diagonal
% pairing recommended.
tuning = iBaseCoupledTuning();
tuning.gain_matrix = [1.0 0.05; 0.05 1.0];
outDir = iOutDir(projectRoot, 'doc_rga_diagonal');
s = summarize_cross_regulation_tuning(tuning, ...
    'CaseName', 'doc_rga_diagonal', 'OutputDir', outDir);

it = s.interaction;
okDoc    = it.documented && ~isempty(it.rga_diagonal);
okDiag   = all(abs(it.rga_diagonal - 1) <= 0.30);
okPair   = strcmp(it.pairing, 'diagonal_recommended') && it.pairing_ok;
okCond   = ~it.ill_conditioned && it.condition_number < 10;
okFiles  = iArtifactsExist(outDir);

c.name = 'Case F: near-identity gain -> RGA diagonal pairing recommended';
c.passed = okDoc && okDiag && okPair && okCond && okFiles;
c.detail = sprintf('pairing=%s(want diagonal_recommended) cond=%.3g(<10) diag_ok=%d artifacts=%d', ...
    it.pairing, it.condition_number, okDiag, okFiles);
end


function [c, outDir] = iCaseRgaInteractive(projectRoot)
% A strongly interactive gain matrix (large off-diagonal): RGA diagonal far from
% 1 and/or ill-conditioned, so diagonal pairing is NOT blindly recommended.
tuning = iBaseCoupledTuning();
tuning.gain_matrix = [1.0 0.95; 0.95 1.0];   % near-singular, cond large
outDir = iOutDir(projectRoot, 'doc_rga_interactive');
s = summarize_cross_regulation_tuning(tuning, ...
    'CaseName', 'doc_rga_interactive', 'OutputDir', outDir);

it = s.interaction;
okDoc    = it.documented;
okNotRec = ~strcmp(it.pairing, 'diagonal_recommended');
okIll    = it.ill_conditioned && it.condition_number >= 10;
okFiles  = iArtifactsExist(outDir);

c.name = 'Case G: strongly interactive gain -> pairing not diagonal, ill-conditioned';
c.passed = okDoc && okNotRec && okIll && okFiles;
c.detail = sprintf('pairing=%s(not diagonal_recommended) cond=%.4g(>=10) ill=%d artifacts=%d', ...
    it.pairing, it.condition_number, it.ill_conditioned, okFiles);
end


function [c, outDir] = iCaseImprovementSupported(projectRoot)
% Before/after margins improve AND a model-backed (simulation) time-domain
% artifact exists under the current iteration dir -> improvement "supported",
% evidence tier "model_backed".
outDir = iOutDir(projectRoot, 'doc_improve_supported');
artifact = iWriteFakeArtifact(outDir, 'dist_run.json');

tuning = iBaseCoupledTuning();
tuning.loops(1).phase_margin_before_deg = 38;
tuning.loops(1).phase_margin_after_deg = 52;
tuning.loops(2).phase_margin_before_deg = 40;
tuning.loops(2).phase_margin_after_deg = 50;
tuning.time_domain = struct('artifact_path', artifact, 'source', 'simulation', ...
    'disturbance', 'grid 0.5pu dip 100ms', 'settling_time_s', 0.012, ...
    'overshoot_pct', 8.5, 'peak_coupling', 0.06);
s = summarize_cross_regulation_tuning(tuning, ...
    'CaseName', 'doc_improve_supported', ...
    'CurrentIterationDir', outDir, 'OutputDir', outDir);

okStatus = strcmp(s.improvement.status, 'supported');
okTier   = strcmp(s.evidence_tier, 'model_backed');
okBack   = s.improvement.time_domain_backed && s.time_domain.model_backed;
okImp    = s.improvement.margin_improved && s.margin_comparison.n_improved == 2;
% Before/after-only margins must still count as documented evidence (not a tweak).
okClass  = ~strcmp(s.classification, 'undocumented_gain_tweak') && ...
           ~strcmp(s.classification, 'provisional') && s.n_documented == 2;
okFiles  = iArtifactsExist(outDir);

c.name = 'Case H: margin improvement + model-backed run -> supported';
c.passed = okStatus && okTier && okBack && okImp && okClass && okFiles;
c.detail = sprintf('status=%s(want supported) tier=%s(want model_backed) class=%s n_doc=%d n_improved=%d artifacts=%d', ...
    s.improvement.status, s.evidence_tier, s.classification, s.n_documented, s.margin_comparison.n_improved, okFiles);
end


function [c, outDir] = iCaseImprovementUnverified(projectRoot)
% Margins improve on paper but NO time-domain artifact is linked. Improvement
% must NOT be claimed: status "margin_only_unverified", tier
% "contract_consistency".
tuning = iBaseCoupledTuning();
tuning.loops(1).phase_margin_before_deg = 38;
tuning.loops(1).phase_margin_after_deg = 52;
tuning.loops(2).phase_margin_before_deg = 40;
tuning.loops(2).phase_margin_after_deg = 50;
outDir = iOutDir(projectRoot, 'doc_improve_unverified');
s = summarize_cross_regulation_tuning(tuning, ...
    'CaseName', 'doc_improve_unverified', 'OutputDir', outDir);

okStatus = strcmp(s.improvement.status, 'margin_only_unverified');
okTier   = strcmp(s.evidence_tier, 'contract_consistency');
okNotBack = ~s.improvement.time_domain_backed;
okFiles  = iArtifactsExist(outDir);

c.name = 'Case I: margins improve but no time-domain run -> not a validated improvement';
c.passed = okStatus && okTier && okNotBack && okFiles;
c.detail = sprintf('status=%s(want margin_only_unverified) tier=%s(want contract_consistency) backed=%d artifacts=%d', ...
    s.improvement.status, s.evidence_tier, s.improvement.time_domain_backed, okFiles);
end


function [c, outDir] = iCaseRegression(projectRoot)
% One loop margin worsens after retune -> improvement status "regression",
% regardless of any linked run.
tuning = iBaseCoupledTuning();
tuning.loops(1).phase_margin_before_deg = 52;
tuning.loops(1).phase_margin_after_deg = 40;   % worse
tuning.loops(2).phase_margin_before_deg = 50;
tuning.loops(2).phase_margin_after_deg = 51;
outDir = iOutDir(projectRoot, 'doc_regression');
s = summarize_cross_regulation_tuning(tuning, ...
    'CaseName', 'doc_regression', 'OutputDir', outDir);

okStatus = strcmp(s.improvement.status, 'regression');
okWorse  = s.margin_comparison.n_worsened >= 1;
okNotImp = ~s.improvement.margin_improved;
okFiles  = iArtifactsExist(outDir);

c.name = 'Case J: a loop margin worsens -> regression, not improvement';
c.passed = okStatus && okWorse && okNotImp && okFiles;
c.detail = sprintf('status=%s(want regression) n_worsened=%d margin_improved=%d artifacts=%d', ...
    s.improvement.status, s.margin_comparison.n_worsened, s.improvement.margin_improved, okFiles);
end


function [c, outDir] = iCaseDelayPhaseLoss(projectRoot)
% A documented delay inventory erodes the delay-adjusted phase margin by
% 360*f*tau at the loop crossover. 200us total at 300Hz -> 21.6 deg loss.
tuning = iBaseCoupledTuning();
tuning.delays = struct();
tuning.delays.sources = struct( ...
    'name', {'computation','pwm_zoh','unit_delay'}, ...
    'seconds', {1.0e-4, 5.0e-5, 5.0e-5}, ...
    'kind', {'numeric','numeric','numeric'}, ...
    'block', {'MATLAB Fcn','ZOH','Unit Delay'});
outDir = iOutDir(projectRoot, 'doc_delay_phaseloss');
s = summarize_cross_regulation_tuning(tuning, ...
    'CaseName', 'doc_delay_phaseloss', 'OutputDir', outDir);

dly = s.delays;
okDoc   = dly.documented && dly.n_sources == 3;
okTotal = abs(dly.total_s - 2.0e-4) < 1e-12 && abs(dly.numeric_s - 2.0e-4) < 1e-12;
% Expected phase loss at 300 Hz crossover = 360*300*2e-4 = 21.6 deg.
L1 = s.loops(1);
okLoss  = abs(L1.delay_phase_loss_deg - 21.6) < 1e-6;
okAdj   = abs(L1.phase_margin_delay_adjusted_deg - (52 - 21.6)) < 1e-6;
okFiles = iArtifactsExist(outDir);

c.name = 'Case K: delay inventory -> phase loss erodes delay-adjusted PM';
c.passed = okDoc && okTotal && okLoss && okAdj && okFiles;
c.detail = sprintf('total=%.4gus loss@300Hz=%.4gdeg(want 21.6) PMadj=%.4g(want 30.4) artifacts=%d', ...
    1e6*dly.total_s, L1.delay_phase_loss_deg, L1.phase_margin_delay_adjusted_deg, okFiles);
end


function [c, outDir] = iCasePseudoImprovement(projectRoot)
% Two delay cases: baseline has a numerical Unit Delay; the "improved" case
% removes it (numeric delay down) with gains unchanged. The PM gain is a
% numerical artifact -> improvement blocked as pseudo_improvement.
tuning = iBaseCoupledTuning();
tuning.delay_cases = struct( ...
    'name', {'with_unit_delay','unit_delay_removed'}, ...
    'numeric_delay_s', {2.0e-4, 5.0e-5}, ...
    'physical_delay_s', {0, 0}, ...
    'phase_margin_deg', {30, 52}, ...
    'gains_changed_vs_baseline', {false, false}, ...
    'documented', {true, true});
outDir = iOutDir(projectRoot, 'doc_pseudo_improve');
s = summarize_cross_regulation_tuning(tuning, ...
    'CaseName', 'doc_pseudo_improve', 'OutputDir', outDir);

dc = s.delay_cases;
okFlag   = dc.any_pseudo_improvement;
okCase   = strcmp(dc.cases(2).verdict, 'pseudo_improvement_numeric_delay');
okStatus = strcmp(s.improvement.status, 'pseudo_improvement_numeric_delay');
okFiles  = iArtifactsExist(outDir);

c.name = 'Case L: numeric-delay removal -> pseudo_improvement, blocked';
c.passed = okFlag && okCase && okStatus && okFiles;
c.detail = sprintf('any_pseudo=%d case2=%s status=%s(want pseudo_improvement_numeric_delay) artifacts=%d', ...
    okFlag, dc.cases(2).verdict, s.improvement.status, okFiles);
end


function [c, outDir] = iCaseUndocumentedDelayChange(projectRoot)
% A delay changes across cases but the case is not documented -> improvement
% blocked as blocked_undocumented_delay_change (highest precedence).
tuning = iBaseCoupledTuning();
tuning.delay_cases = struct( ...
    'name', {'baseline','tweaked'}, ...
    'numeric_delay_s', {1.0e-4, 1.0e-4}, ...
    'physical_delay_s', {0, 5.0e-5}, ...
    'phase_margin_deg', {45, 50}, ...
    'gains_changed_vs_baseline', {false, false}, ...
    'documented', {true, false});
outDir = iOutDir(projectRoot, 'doc_undoc_delay');
s = summarize_cross_regulation_tuning(tuning, ...
    'CaseName', 'doc_undoc_delay', 'OutputDir', outDir);

dc = s.delay_cases;
okFlag   = dc.any_undocumented_delay_change;
okStatus = strcmp(s.improvement.status, 'blocked_undocumented_delay_change');
okFiles  = iArtifactsExist(outDir);

c.name = 'Case M: undocumented delay change -> improvement blocked';
c.passed = okFlag && okStatus && okFiles;
c.detail = sprintf('any_undoc=%d status=%s(want blocked_undocumented_delay_change) artifacts=%d', ...
    okFlag, s.improvement.status, okFiles);
end


function [c, outDir] = iCaseLegitDelayImprovement(projectRoot)
% A documented case with an actual gain change and a model-backed run: a real
% margin gain that is NOT a numeric-delay artifact (numeric delay unchanged,
% gains changed) must NOT be blocked -> improvement supported.
outDir = iOutDir(projectRoot, 'doc_legit_delay');
artifact = iWriteFakeArtifact(outDir, 'dist_run.json');

tuning = iBaseCoupledTuning();
tuning.loops(1).phase_margin_before_deg = 38;
tuning.loops(1).phase_margin_after_deg = 52;
tuning.loops(2).phase_margin_before_deg = 40;
tuning.loops(2).phase_margin_after_deg = 50;
tuning.time_domain = struct('artifact_path', artifact, 'source', 'simulation', ...
    'disturbance', 'grid dip', 'settling_time_s', 0.012);
tuning.delay_cases = struct( ...
    'name', {'baseline','retuned'}, ...
    'numeric_delay_s', {1.0e-4, 1.0e-4}, ...
    'physical_delay_s', {0, 0}, ...
    'phase_margin_deg', {38, 52}, ...
    'gains_changed_vs_baseline', {false, true}, ...
    'documented', {true, true});
s = summarize_cross_regulation_tuning(tuning, ...
    'CaseName', 'doc_legit_delay', ...
    'CurrentIterationDir', outDir, 'OutputDir', outDir);

okNotPseudo = ~s.improvement.pseudo_improvement;
okNotUndoc  = ~s.improvement.undocumented_delay_change;
okStatus    = strcmp(s.improvement.status, 'supported');
okFiles     = iArtifactsExist(outDir);

c.name = 'Case N: documented gain change + model-backed -> supported (not delay-blocked)';
c.passed = okNotPseudo && okNotUndoc && okStatus && okFiles;
c.detail = sprintf('pseudo=%d undoc=%d status=%s(want supported) artifacts=%d', ...
    s.improvement.pseudo_improvement, s.improvement.undocumented_delay_change, ...
    s.improvement.status, okFiles);
end


function tuning = iBaseCoupledTuning()
% Two symmetric, fully documented dq current loops with healthy margins and a
% moderate (below-threshold) coupling matrix. Reused and mutated per case.
tuning = struct();
tuning.operating_point = 'P=0.8pu, SCR=2.5, GFL';
tuning.control_frame = 'dq';
tuning.model_path = 'models/synthetic_vsc_dq.slx';
tuning.cross_coupling = [1 0.2; 0.2 1];
tuning.loops(1) = struct('name','id_current','type','PI', ...
    'kp_before',0.8,'kp_after',1.2,'ki_before',60,'ki_after',90, ...
    'sample_time_s',1e-4,'bandwidth_target_hz',300, ...
    'output_min',-1,'output_max',1,'anti_windup','back-calculation', ...
    'phase_margin_deg',52,'disturbance_channels',"grid_voltage_dip", ...
    'rationale','raise BW to 300Hz for FRT current step');
tuning.loops(2) = struct('name','iq_current','type','PI', ...
    'kp_before',0.8,'kp_after',1.2,'ki_before',60,'ki_after',90, ...
    'sample_time_s',1e-4,'bandwidth_target_hz',300, ...
    'output_min',-1,'output_max',1,'anti_windup','back-calculation', ...
    'phase_margin_deg',50,'disturbance_channels',"reactive_ref_step", ...
    'rationale','match id loop for symmetric dq response');
end


function outDir = iOutDir(projectRoot, caseName)
outDir = fullfile(projectRoot, 'build', 'reports', 'f2_cross_regulation', caseName);
end


function tf = iArtifactsExist(outDir)
tf = isfile(fullfile(outDir, 'cross_regulation_summary.md')) && ...
     isfile(fullfile(outDir, 'cross_regulation_summary.json')) && ...
     isfile(fullfile(outDir, 'loop_tuning.csv'));
end


function artifact = iWriteFakeArtifact(outDir, name)
% Create a small on-disk artifact so the time-domain link can be model-backed.
% Must exist BEFORE the helper runs (the helper checks isfile). Returned path
% is removed with the scratch dir in iCleanup.
if ~isfolder(outDir)
    mkdir(outDir);
end
artifact = fullfile(outDir, name);
fid = fopen(artifact, 'w');
if fid < 0
    error('CrossRegTest:CannotWriteArtifact', 'Cannot write %s', artifact);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '{"disturbance":"grid dip","settling_time_s":0.012}\n');
end


function iCleanup(scratch)
% Remove per-case scratch dirs so a stale artifact cannot produce a false PASS
% in a later Codex review. Leaves the parent build/reports tree intact.
for k = 1:numel(scratch)
    d = scratch{k};
    if ~isempty(d) && isfolder(d)
        rmdir(d, 's');
    end
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
