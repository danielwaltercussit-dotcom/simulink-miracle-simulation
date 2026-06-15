function r = tuning_write_then_sim(preWriteSnapshot, writeFcn, simFcn, restoreFcn)
%TUNING_WRITE_THEN_SIM  Apply a tuning write, simulate, and roll back on failure.
%
%   r = tuning_write_then_sim(preWriteSnapshot, writeFcn, simFcn, restoreFcn)
%
%   Enforces the S6 safety contract: a parameter write that is followed by a
%   failed simulation must NOT be left on the model. Callbacks keep this pure
%   and unit-testable without a live Simulink model.
%
%     preWriteSnapshot  struct {id -> value} captured BEFORE writeFcn runs.
%     writeFcn()        applies the parameter write (e.g. set_param + save).
%                       May throw; a throwing write may have applied a partial
%                       change, so a write error also triggers rollback.
%     simFcn()          -> [out, ok(logical), msg]; this is the SAME output
%                          order as safe_sim (the real S6 callback). ok=false
%                          means the post-write simulation failed/errored. If
%                          simFcn itself THROWS, that is also treated as a
%                          failed sim and triggers rollback.
%     restoreFcn(snap)  restores snap back onto the model; returns logical ok.
%
%   Whenever the write OR the simulation fails, restoreFcn(preWriteSnapshot) is
%   invoked before returning, so the caller can guarantee the model is back at
%   its pre-write state. Result fields:
%     r.write_ok     did writeFcn complete without throwing
%     r.sim_ok       did the post-write simulation succeed (false if no write)
%     r.out          simulation output (only meaningful when sim_ok)
%     r.msg          error message when write or sim failed
%     r.rolled_back  was a rollback attempted (true iff write or sim failed)
%     r.restore_ok   did restoreFcn report success

r = struct('write_ok',false,'sim_ok',false,'out',[],'msg','', ...
    'rolled_back',false,'restore_ok',false);

% 1) Attempt the write. A throwing writeFcn may have partially applied the
%    change on the live model, so capture the failure and fall through to
%    rollback rather than letting the exception escape unhandled.
try
    writeFcn();
    r.write_ok = true;
catch ME
    r.write_ok = false;
    r.msg = sprintf('write failed: %s', ME.message);
end

% 2) Only simulate if the write actually landed. simFcn shares safe_sim's
%    [out, ok, msg] order so the real S6 callback drops in without adaptation.
%    safe_sim is expected to TRAP its own errors and report ok=false, but a
%    callback can still throw (bug, setup error, Ctrl-C). A throw here must be
%    treated as a failed post-write sim and fall through to rollback, never
%    escape and leave the written value stranded on the model.
if r.write_ok
    try
        [out, ok, msg] = simFcn();
        r.sim_ok = logical(ok);
        r.out    = out;
        r.msg    = msg;
    catch ME
        r.sim_ok = false;
        r.msg    = sprintf('sim failed: %s', ME.message);
    end
end

% 3) Roll back on either a failed write or a failed simulation. restore_ok is
%    true only if restoreFcn reports a complete restore.
if ~r.write_ok || ~r.sim_ok
    r.rolled_back = true;
    try
        r.restore_ok = logical(restoreFcn(preWriteSnapshot));
    catch ME
        r.restore_ok = false;
        r.msg = sprintf('%s | rollback also failed: %s', r.msg, ME.message);
    end
end
end
