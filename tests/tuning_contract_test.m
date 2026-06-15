function result = tuning_contract_test()
%TUNING_CONTRACT_TEST  Helper-level contract tests for the S6 tuning safety
%   guards. No full model is built or simulated; the rollback path is proven
%   with synthetic snapshots and callbacks. Covers:
%
%     A) immutable entry (control_only=false)        -> NOT writable
%     B) unclassified entry (missing required field)  -> NOT writable
%     C) unclassified entry (NaN rollback_value)      -> NOT writable
%     D) proven control-only entry                    -> writable
%     E) rollback: a failed post-write sim restores the EXACT pre-write
%        snapshot and reports rolled_back/restore_ok
%     F) happy path: a successful post-write sim performs NO rollback and
%        returns the sim output
%     G) safe_sim contract order: a callback with safe_sim's REAL
%        [out, ok, msg] signature is interpreted correctly (regression for the
%        reversed-output S6 integration defect)
%     H) write failure: a throwing writeFcn triggers rollback to the pre-write
%        snapshot (a partial write must not be left on the model)
%     I) partial restore: a restoreFcn that reports incomplete restore yields
%        restore_ok=false even though a rollback was attempted (all-or-nothing)
%     J) sim throw: a simFcn that THROWS (not just returns ok=false) triggers
%        rollback to the pre-write snapshot — a post-write sim exception must
%        not escape and strand the written value on the model
%
%   Entry point for run_matlab_test_file / runtests via the function name.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'tuning'));

checks = struct([]);
checks = iAdd(checks, iCaseImmutableRejected());
checks = iAdd(checks, iCaseMissingFieldRejected());
checks = iAdd(checks, iCaseNanRollbackRejected());
checks = iAdd(checks, iCaseControlOnlyWritable());
checks = iAdd(checks, iCaseRollbackOnSimFailure());
checks = iAdd(checks, iCaseNoRollbackOnSuccess());
checks = iAdd(checks, iCaseSafeSimContractOrder());
checks = iAdd(checks, iCaseRollbackOnWriteFailure());
checks = iAdd(checks, iCasePartialRestoreReportsFailure());
checks = iAdd(checks, iCaseRollbackOnSimThrow());

allPass = all([checks.passed]);
fprintf('\n=== tuning_contract_test ===\n');
for k = 1:numel(checks)
    fprintf('[%s] %s\n', iTag(checks(k).passed), checks(k).name);
    if ~isempty(checks(k).detail)
        fprintf('       %s\n', checks(k).detail);
    end
end
fprintf('Overall: %s (%d/%d)\n', iTag(allPass), sum([checks.passed]), numel(checks));

assert(allPass, 'tuning_contract_test: %d/%d checks failed', ...
    numel(checks) - sum([checks.passed]), numel(checks));
result = struct('passed', allPass, 'checks', checks);
end


function c = iCaseImmutableRejected()
% A physically-immutable parameter handed in with control_only=false must be
% rejected even though every other field is present.
e = iBaseEntry();
e.control_only = false;
[tf, reason] = tuning_entry_is_writable(e);
c.name = 'Case A: immutable entry (control_only=false) -> NOT writable';
c.passed = ~tf && startsWith(reason, 'immutable:');
c.detail = sprintf('writable=%d reason="%s"', tf, reason);
end


function c = iCaseMissingFieldRejected()
% Missing a required classification field -> unclassified -> rejected.
e = iBaseEntry();
e = rmfield(e, 'priority');
[tf, reason] = tuning_entry_is_writable(e);
c.name = 'Case B: unclassified entry (missing priority) -> NOT writable';
c.passed = ~tf && startsWith(reason, 'unclassified:');
c.detail = sprintf('writable=%d reason="%s"', tf, reason);
end


function c = iCaseNanRollbackRejected()
% A NaN rollback_value means no proven restore point -> unclassified.
e = iBaseEntry();
e.rollback_value = [NaN NaN];
[tf, reason] = tuning_entry_is_writable(e);
c.name = 'Case C: NaN rollback_value -> NOT writable';
c.passed = ~tf && startsWith(reason, 'unclassified:');
c.detail = sprintf('writable=%d reason="%s"', tf, reason);
end


function c = iCaseControlOnlyWritable()
% A fully-classified, proven control-only entry is writable.
e = iBaseEntry();
[tf, reason] = tuning_entry_is_writable(e);
c.name = 'Case D: proven control-only entry -> writable';
c.passed = tf && strcmp(reason, 'ok');
c.detail = sprintf('writable=%d reason="%s"', tf, reason);
end


function c = iCaseRollbackOnSimFailure()
% Prove the rollback guarantee: with a simulated post-write sim FAILURE, the
% helper must call the restore callback with the exact pre-write snapshot. A
% mutable handle stands in for the live model so we can assert the final state.
preWrite = struct('pll', [15 9.6 3 150]);
writtenVal = [22.5 14.4 4.5 225];

state = iModelState(preWrite);              % "model" current state
writeFcn   = @() state.set('pll', writtenVal);
simFcn     = @() deal([], false, 'synthetic: simulation diverged');
restoreFcn = @(snap) iRestore(state, snap);

r = tuning_write_then_sim(preWrite, writeFcn, simFcn, restoreFcn);

afterWriteThenRollback = state.get('pll');
okFailReported = ~r.sim_ok;
okRolled       = r.rolled_back && r.restore_ok;
okRestoredVal  = isequal(afterWriteThenRollback, preWrite.pll);
okMsg          = contains(r.msg, 'diverged');

c.name = 'Case E: failed post-write sim -> pre-write snapshot restored';
c.passed = okFailReported && okRolled && okRestoredVal && okMsg;
c.detail = sprintf(['sim_ok=%d rolled_back=%d restore_ok=%d final=%s ', ...
    '(want pre-write %s)'], r.sim_ok, r.rolled_back, r.restore_ok, ...
    mat2str(afterWriteThenRollback), mat2str(preWrite.pll));
end


function c = iCaseNoRollbackOnSuccess()
% Happy path: a successful sim must NOT roll back and must surface the output;
% the written value stays on the model.
preWrite = struct('pll', [15 9.6 3 150]);
writtenVal = [22.5 14.4 4.5 225];

state = iModelState(preWrite);
writeFcn   = @() state.set('pll', writtenVal);
simFcn     = @() deal(struct('tag','sim-output'), true, '');
restoreFcn = @(snap) iRestore(state, snap);

r = tuning_write_then_sim(preWrite, writeFcn, simFcn, restoreFcn);

finalVal = state.get('pll');
okSim     = r.sim_ok;
okNoRoll  = ~r.rolled_back;
okOut     = isstruct(r.out) && strcmp(r.out.tag, 'sim-output');
okKept    = isequal(finalVal, writtenVal);

c.name = 'Case F: successful post-write sim -> no rollback, output returned';
c.passed = okSim && okNoRoll && okOut && okKept;
c.detail = sprintf('sim_ok=%d rolled_back=%d out_ok=%d final=%s', ...
    r.sim_ok, r.rolled_back, okOut, mat2str(finalVal));
end


function c = iCaseSafeSimContractOrder()
% Regression for the reversed-output S6 defect: the real callback is
% @() safe_sim(...), whose signature is [out, ok, msg]. A simFcn using that
% exact order must be interpreted with ok in the 2nd slot. Here ok=true and a
% tagged struct sits in the 1st (out) slot; the helper must treat the run as a
% success and surface that struct as r.out — NOT mistake the struct for ok.
preWrite = struct('pll', [15 9.6 3 150]);
writtenVal = [22.5 14.4 4.5 225];

state = iModelState(preWrite);
writeFcn   = @() state.set('pll', writtenVal);
% [out, ok, msg] — safe_sim's real order.
simFcn     = @() deal(struct('tag','safe-sim-out'), true, '');
restoreFcn = @(snap) iRestore(state, snap);

r = tuning_write_then_sim(preWrite, writeFcn, simFcn, restoreFcn);

okSim    = r.sim_ok;                                   % ok read from slot 2
okNoRoll = ~r.rolled_back;
okOut    = isstruct(r.out) && strcmp(r.out.tag, 'safe-sim-out');  % out from slot 1
okKept   = isequal(state.get('pll'), writtenVal);

c.name = 'Case G: safe_sim [out, ok, msg] order interpreted correctly';
c.passed = okSim && okNoRoll && okOut && okKept;
c.detail = sprintf('sim_ok=%d rolled_back=%d out_ok=%d', r.sim_ok, r.rolled_back, okOut);
end


function c = iCaseRollbackOnWriteFailure()
% A throwing writeFcn may have applied a partial change, so the helper must
% roll back to the pre-write snapshot and report write_ok=false. We simulate a
% write that mutates the model and THEN throws; rollback must restore the
% pre-write value and the sim must never run.
preWrite = struct('pll', [15 9.6 3 150]);

state = iModelState(preWrite);
writeFcn   = @() iWriteThenThrow(state, 'pll', [99 99 99 99]);
simRan = iFlag();
simFcn     = @() iMarkAndDeal(simRan);   % must NOT be called
restoreFcn = @(snap) iRestore(state, snap);

r = tuning_write_then_sim(preWrite, writeFcn, simFcn, restoreFcn);

okWriteFailed = ~r.write_ok;
okNotSimmed   = ~simRan.get();
okRolled      = r.rolled_back && r.restore_ok;
okRestored    = isequal(state.get('pll'), preWrite.pll);
okMsg         = contains(r.msg, 'write failed');

c.name = 'Case H: throwing writeFcn -> rollback to pre-write, sim skipped';
c.passed = okWriteFailed && okNotSimmed && okRolled && okRestored && okMsg;
c.detail = sprintf(['write_ok=%d sim_ran=%d rolled_back=%d restore_ok=%d ', ...
    'final=%s'], r.write_ok, simRan.get(), r.rolled_back, r.restore_ok, ...
    mat2str(state.get('pll')));
end


function c = iCasePartialRestoreReportsFailure()
% All-or-nothing rollback: if restoreFcn reports incomplete restore (false),
% the helper must surface restore_ok=false even though rolled_back is true, so
% a caller never treats a mixed-state model as a clean rollback.
preWrite = struct('pll', [15 9.6 3 150]);
writtenVal = [22.5 14.4 4.5 225];

state = iModelState(preWrite);
writeFcn   = @() state.set('pll', writtenVal);
simFcn     = @() deal([], false, 'synthetic: diverged');
restoreFcn = @(snap) false;   % restore could not complete

r = tuning_write_then_sim(preWrite, writeFcn, simFcn, restoreFcn);

c.name = 'Case I: incomplete restore -> rolled_back true but restore_ok false';
c.passed = r.rolled_back && ~r.restore_ok;
c.detail = sprintf('rolled_back=%d restore_ok=%d', r.rolled_back, r.restore_ok);
end


function c = iCaseRollbackOnSimThrow()
% safe_sim is expected to trap its own errors, but a post-write callback can
% still THROW (bug, setup failure, interrupt). The helper must treat a thrown
% sim exception exactly like a returned ok=false: roll the written value back
% to the pre-write snapshot rather than letting the exception escape and strand
% the change on the model. Regression for the sim-callback rollback gap.
preWrite = struct('pll', [15 9.6 3 150]);
writtenVal = [22.5 14.4 4.5 225];

state = iModelState(preWrite);
writeFcn   = @() state.set('pll', writtenVal);
simFcn     = @() iSimThrow();
restoreFcn = @(snap) iRestore(state, snap);

r = tuning_write_then_sim(preWrite, writeFcn, simFcn, restoreFcn);

afterWriteThenRollback = state.get('pll');
okWriteLanded = r.write_ok;                 % write succeeded before sim threw
okSimFailed   = ~r.sim_ok;                  % thrown sim reported as failure
okRolled      = r.rolled_back && r.restore_ok;
okRestoredVal = isequal(afterWriteThenRollback, preWrite.pll);
okMsg         = contains(r.msg, 'sim failed') && contains(r.msg, 'sim exploded');

c.name = 'Case J: throwing simFcn -> rollback to pre-write snapshot';
c.passed = okWriteLanded && okSimFailed && okRolled && okRestoredVal && okMsg;
c.detail = sprintf(['write_ok=%d sim_ok=%d rolled_back=%d restore_ok=%d ', ...
    'final=%s (want pre-write %s) msg="%s"'], r.write_ok, r.sim_ok, ...
    r.rolled_back, r.restore_ok, mat2str(afterWriteThenRollback), ...
    mat2str(preWrite.pll), r.msg);
end


function e = iBaseEntry()
% Canonical fully-classified control-only registry entry.
e = struct( ...
    'id', 'pll', ...
    'block_path', 'm/DFIG_W33/Control/PLL', ...
    'mask_param', 'ParK', ...
    'current', [15 9.6 3 150], ...
    'min', [0.5 0.3 0.1 5], ...
    'max', [200 1000 50 1000], ...
    'units', '[Kp1 Ki1 Kp2 Ki2] PLL gains', ...
    'fs_targets', {{'FS-009','FS-013','FS-014'}}, ...
    'scale_fcn', @(v,d) v, ...
    'priority', 1, ...
    'parameter_class', 'pll', ...
    'control_only', true, ...
    'rollback_value', [15 9.6 3 150]);
end


function s = iModelState(init)
% Minimal mutable key->value store standing in for a live model's params.
% get/set are NESTED functions (not anonymous) so they share `store` by
% reference — an anonymous getter would freeze the initial value and never
% observe a write, masking a broken rollback.
store = init;
s.set = @setter;
s.get = @getter;
    function setter(k, v)
        store.(k) = v;
    end
    function v = getter(k)
        v = store.(k);
    end
end


function ok = iRestore(state, snap)
% Restore every field of snap back onto the mutable model state.
ok = false;
f = fieldnames(snap);
for k = 1:numel(f)
    state.set(f{k}, snap.(f{k}));
    ok = true;
end
end


function iWriteThenThrow(state, k, v)
% Simulate a write that applies a partial change and THEN fails, so the test
% can prove rollback restores the pre-write value rather than leaving v on the
% model.
state.set(k, v);
error('TuningContractTest:writeBoom', 'synthetic: set_param failed mid-write');
end


function f = iFlag()
% Minimal mutable boolean flag (nested-function closure over `tripped`) used to
% assert that a callback was or was not invoked.
tripped = false;
f.set = @() assignTrue();
f.get = @() tripped;
    function assignTrue()
        tripped = true;
    end
end


function [out, ok, msg] = iMarkAndDeal(flag)
% simFcn stand-in that records it was called. If the write-failure contract
% holds this is never invoked; if it is, the recorded flag fails the test.
flag.set();
out = []; ok = true; msg = '';
end


function [out, ok, msg] = iSimThrow()
% simFcn stand-in that THROWS instead of returning. Stands in for a post-write
% simulation callback that errors out (rather than reporting ok=false). The
% outputs are declared to match the [out, ok, msg] contract but are never
% reached because the function errors first.
out = []; ok = false; msg = ''; %#ok<NASGU>
error('TuningContractTest:simBoom', 'synthetic: sim exploded mid-run');
end


function checks = iAdd(checks, c)
if isempty(checks); checks = c; else; checks(end+1) = c; end
end


function t = iTag(passed)
if passed; t = 'PASS'; else; t = 'FAIL'; end
end
