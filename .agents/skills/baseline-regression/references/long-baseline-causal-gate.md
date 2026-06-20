# Long Baseline and Causal Gate Pattern

Use this reference when a Simulink power-system run is too expensive for an
interactive session and its result may become evidence for S6 tuning, causal
perturbation design, or cross-timescale analysis.

## Scope

This pattern covers unchanged long baselines such as IEEE39 SG5/DFIG5 T1 runs,
detached MATLAB batch execution, immutable per-run bundles, and the decision
boundary between "more evidence needed" and "S6 may be prepared".

It is not a permission to tune. A long unchanged baseline can identify or
strengthen a root-cause candidate, but it does not by itself prove causal
control authority.

## Launch Contract

Before launching an expensive baseline, require a machine-readable launch spec
with:

- `runId`
- stage
- stop time
- exact MATLAB command
- expected run directory
- detached/background requirement
- user approval requirement, when applicable
- expected status files
- expected bundle files
- expected postrun entry point

Run a no-sim preflight that proves:

- the command reconstructs byte-equivalent from structured fields;
- the target `run_<runId>` directory is absent or is an already-owned existing
  run;
- no claim, flag, bundle, model save, or simulation is created by preflight;
- old run ids are not reused after failure or consumption.

For memory-critical runs, preflight must also declare:

- how the real `MATLAB.exe` compute child PID will be resolved;
- private-byte slope, peak, free-commit, and projected-peak thresholds;
- the warm-up point after which slope is fitted;
- the required-signal retention contract.

## Detached Execution

Runs expected to exceed an interactive tool timeout must be detached. The
operator may switch networks, close Claude/Codex chats, or change VPNs without
affecting a local MATLAB worker, as long as the machine remains awake and the
MATLAB process is not terminated.

Record a compact resume artifact immediately after launch:

```text
reports/control/<runId>_launch_monitor_resume_status.md
```

Include:

- start time
- command source
- run id and stop time
- bootstrap PID and worker PID, if available
- current state
- ETA basis
- next poll command
- hard stops

Do not keep an agent busy-waiting for a multi-hour run. Return `RUNNING` and
let the next operator poll from disk.

Launch the long validator as an OS-level detached process. A background shell
task owned by the current agent/session can be reaped when that session ends.

## Status Vocabulary

Use a small, mutually exclusive vocabulary:

- `NOT_STARTED`: run directory absent.
- `RUNNING`: claim/running evidence exists and no terminal flag exists.
- `SUCCEEDED_CANDIDATE`: success flag and expected bundle files exist, but the
  authoritative MATLAB validator has not yet re-read them.
- `SUCCEEDED_VALIDATED`: success flag, finalized manifest, readable summary,
  `run_gate == true`, and bundle validator all pass.
- `FAILED`: failure flag or failed launch evidence exists.
- `INCONSISTENT`: flags, process state, or bundle metadata disagree.

Flag presence alone is never enough to promote success.

## Success Gate

Promote to `SUCCEEDED_VALIDATED` only when all required conditions hold:

1. `success.flag` exists.
2. `failed.flag` is absent.
3. `bundle/MANIFEST.json` exists.
4. manifest `final_state == FINALIZED`.
5. `bundle/summary.json` is readable.
6. summary `run_gate == true`.
7. the project bundle validator passes.

Postrun analysis must write outside the immutable bundle unless the bundle
manifest explicitly includes the file.

Memory success additionally requires a measured post-compile slope and projected
peak within the launch thresholds. Final bundle size, `LogDecimation`, or Scope
`DataLogging=off` are not substitutes. If executing Scope sinks dominate memory,
disable their execution in the task-owned runtime copy while preserving required
`logsout` signals and proving the deliverable model is unchanged.

## Network and Host Assumptions

Local MATLAB simulation does not depend on Claude/Codex network connectivity.
Network switching usually does not interrupt the run. Known exceptions:

- the host sleeps, hibernates, restarts, or logs out;
- the user kills the MATLAB worker;
- the license server becomes unreachable for long enough to abort MATLAB;
- the project path is moved or deleted during the run.

For Windows operators, provide a read-only status script where practical. The
script may inspect flags, the launch manifest, process list, and log tail, but
must not call `run_dfig_batch`, create a new run id, save a model, or run
postrun.

## Causal Gate Before S6

S6 tuning remains unauthorized until evidence proves all of:

- valid bundle and postrun;
- control-owned signal family;
- priority-1 candidate;
- resolvable candidate;
- discriminating evidence;
- damping floor or actionable damping metric;
- causal confirmation from a later perturbation or equivalent controlled
  experiment.

If the long unchanged baseline yields only a cleaner candidate, prepare a
single-factor perturbation contract instead of tuning.

## Perturbation Discipline

Do not change line parameters, wind speed, synchronous machine speed, and
controller gains in the same causal test. Start with one perturbation family:

- control/reference-side injection for PLL or converter-control candidates;
- mechanical power, load, or fault-clearance perturbation for electromechanical
  candidates;
- wind-speed step/ramp or DFIG reference perturbation for wind-unit candidates.

Keep initial conditions, logging, and acceptance gates identical to the
baseline. Preserve provenance and rollback.

## Common Launch Failure

On Windows, `Start-Process -ArgumentList` can split a MATLAB `-batch` command if
the batch body is passed as an array of fragments. Symptom: MATLAB starts, may
print a license banner or execute `addpath`, but `run_<runId>` is never created.
Fix by passing the whole `-batch "<body>"` invocation as one argument string or
by using a verified launcher script. If no run directory was created, the run id
has not been consumed; do not relaunch until that is proven.
