# Lab Model Pattern Miner Contract

Use this contract before changing the miner's extracted fields, drift kinds, or
output schema.

## Inputs

- `ArchiveDir` — read-only lab archive root (default Desktop `实验室仿真模型汇总`)
- `OutputDir` — gitignored output root (default `build/reports/lab_patterns`)
- `Subset` — optional cellstr of pattern ids to limit the scan (e.g. `{'M03'}`)
- `ScanBlocks` — load `.slx` to count blocks (default true; set false for speed)
- `PatternLibPath` — curated pattern library used for drift comparison

## Per-Pattern Facts (machine-extracted)

- `id`, `folder`
- `n_files` and `files[]`: name, rel path, bytes, ext, mtime
- `slx_models[]`: name, n_blocks, n_root_subsystems, scanned flag
- `m_scripts[]`: name, n_vars, vars[] (assigned-variable names)
- `total_assigned_vars`

## Drift Kinds

- `undocumented_file` — archive `.slx`/`.m` not referenced by the pattern lib
- `missing_reference` — pattern-lib-cited filename absent from the archive
  (full scan only; skipped on subset scans)
- `no_pattern_lib` — pattern library file not found

## Invariants

- Never write inside `ArchiveDir`. Validate with a before/after file-count and
  max-mtime check around any scan.
- Never simulate a model. `load_system` for block counts only; close models the
  miner opened.
- Report-only: drift findings are advisory. Editing
  `docs/MODELING_PATTERN_LIBRARY.md` or `pattern-rows.md` requires human review.

## Known Limitations

- `.pscx` (PSCAD, e.g. M06) and `.mat` are inventoried but not block-counted.
- A lab `.slx` sharing a name with a project model (e.g. `NEBUS39V2.slx`)
  triggers a MATLAB path-shadow warning during load; counts still read from the
  archive copy, but treat shadowed-model counts with mild caution.
- Variable extraction is lexical (assignment LHS), not semantic; it will not
  catch struct-field or dynamically-named parameters.
