# Agent Execution Gates for Decoupled Interfaces

Use these rules when a decoupled-interface task is executed by a separate agent
or in a fresh conversation. The goal is to preserve verified progress without
letting the agent spend tokens on broad strategy, re-planning, or unsafe model
edits.

## Prompt shape

Give the executing agent one concrete objective at a time. A good task packet
contains:

- the exact source files to read;
- the exact model or script paths it may create or modify;
- the command or MATLAB script that proves the work;
- the output evidence files it must write;
- allowed terminal verdicts;
- explicit forbidden scope.

Avoid asking the executor to "think about next steps", "design the whole
integration", or "plan future phases" unless the task is specifically a planning
review. Strategy stays with the orchestrating reviewer; the executor produces
bounded evidence.

## Model authority gate

Before editing a plant model, require a model-authority check:

- identify the source model path;
- record its byte-level hash, timestamp, and size;
- copy it into a generated work area before editing;
- never edit the external/source model in place.

If the required hash does not match the file on disk, stop at the authority gate
and report the mismatch. Do not let the executor decide that a different hash is
"close enough" or silently continue because another `.slx` appears similar. The
next step is reviewer-owned authority reconciliation: either accept the new
authority with evidence, locate the intended model, or regenerate the task with a
correct hash.

## Integration ladder

Do not collapse wrapper proof, parent-model signal proof, closed-loop injection,
and acceptance simulation into one claim. Use the ladder below and label evidence
with the highest gate actually passed.

1. Contract/static gate: interface fields are internally consistent.
2. Wrapper probe gate: wrapper logic runs in a controlled probe harness.
3. Parent signal gate: wrapper is attached in a copied parent model and logs real
   plant/controller signals, but does not replace the plant's current injection.
4. Closed-loop injection gate: controlled-source/current-source wiring is
   explicitly connected in the copied model and numerically checked.
5. Acceptance gate: the full target scenario runs for the declared stop time and
   passes numeric acceptance checks.

`model_validation_status = pass` must describe the scope of the actual probe. A
wrapper-only pass is not a full-plant pass; a parent signal pass is not a
closed-loop injection pass; a closed-loop wiring smoke test is not final
acceptance.

## Safe full-plant editing

For copied `.slx` models:

- prefer additive shadow/probe instrumentation before replacing plant wiring;
- write a topology audit before connecting new blocks;
- preserve the original plant/controller current path until the task explicitly
  authorizes replacement;
- log enough boundary signals to verify sign, units, phase order, and state
  carry-over;
- use explicit pass/fail numeric checks, not screenshots or subjective
  inspection.

If a task exposes a missing signal, ambiguous subsystem path, orientation/sign
uncertainty, or hash mismatch, stop and report the blocker. Do not compensate by
inventing a topology or widening the scope.

## Cost discipline

Long agent runs should not rediscover project history. Start a fresh session for
major phase changes or expensive simulations, but pass only a compact handoff:
current gate, allowed files, required evidence, and stop conditions. Prefer one
short executable step that either produces evidence or stops at a named gate.
