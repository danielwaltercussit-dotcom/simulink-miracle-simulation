---
name: lab-model-pattern-miner
description: Use when checking whether the project pattern library (M01-M08 in docs/MODELING_PATTERN_LIBRARY.md and pattern-rows.md) still matches the read-only lab reference archive. Extracts machine-readable facts (file inventory, .slx block/subsystem counts, .m assigned-variable names) from the archive and reports drift, so agents stop re-verifying M01-M08 by hand. Never edits the archive or the curated docs.
---

# Lab Model Pattern Miner

Use this skill to detect **drift** between the read-only lab reference archive
and the project's human-curated pattern library. It is a checker, not a
knowledge generator.

## Core Rule

The archive README and the project pattern docs
(`docs/MODELING_PATTERN_LIBRARY.md`, `pattern-rows.md`) are **human-authored
and authoritative**. Critical constraints there (e.g. M03 `Co_Rrs/Lm/Lls` must
reset to 1.0; M05 keeps three voltage bases in SI not pu) come from a human
reading the models and cannot be reliably auto-extracted. This skill never
rewrites that knowledge. It only surfaces machine-checkable facts and flags
mismatches for human review.

## Hard Rules

1. The lab archive (`C:\Users\jonas\Desktop\实验室仿真模型汇总`) is **read-only**.
   The helper never writes inside it; verified by a before/after file-count and
   mtime check.
2. All output goes under `build/reports/lab_patterns/` (gitignored).
3. Only update `docs/MODELING_PATTERN_LIBRARY.md` / `pattern-rows.md` **after a
   human reviews the drift report** — never automatically.
4. Models are `load_system`-ed for block counting only, **never simulated**, and
   closed afterward if the miner opened them.

## What It Extracts (machine-reliable only)

- per-`M0x` file inventory: name, relative path, bytes, extension, mtime
- `.slx` total block count and root subsystem count (load-only)
- `.m` assigned-variable names (regex on assignment LHS) and their count

## What It Does NOT Do

- interpret control structure, stability constraints, or parameter meaning
- assign new pattern IDs
- edit the archive or the curated pattern docs

## Drift Findings

- `undocumented_file` — a `.slx`/`.m` in the archive that no pattern doc names
- `missing_reference` — a filename the pattern library cites that is absent
  from the archive (only computed on a **full** scan; skipped on subsets to
  avoid false positives from unscanned folders)

## Helper

```matlab
cd("C:\Users\jonas\Desktop\simulink_agent_v1")
addpath("scripts/analysis")
% Full scan (M01-M08) with .slx block counts:
r = mine_lab_model_patterns();
% Fast subset, skip block counting:
r = mine_lab_model_patterns('Subset',{'M03'},'ScanBlocks',false);
```

## Output

```text
build/reports/lab_patterns/
  lab_patterns_index.json   machine facts per pattern
  lab_patterns_index.md     human-readable index table
  lab_patterns_drift.md     drift findings (review before editing docs)
```

Read `references/miner-contract.md` before changing extracted fields, drift
kinds, or output schema.
