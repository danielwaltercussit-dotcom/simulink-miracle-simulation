# Storage / Battery / BMS Support Contract

Use this contract when generating or reviewing storage/BESS device support
evidence for converter-dominated systems. It defines the metadata, the evidence
dimensions, the PASS/WARN/MISSING/N/A rules, and the battery-vs-DC-link
separation that the helper enforces.

## Required Metadata

Record:

- case name and (where applicable) source model/script
- evidence source: `measured`, `simulated`, `analytic`, `synthetic`, or
  `planned`
- battery model type (e.g. `equivalent_circuit_2RC`, `shepherd`,
  `electrochemical`, `datasheet_table`) — `constant_dc_source` is NOT a battery
  model and is treated as undocumented battery identity
- rated energy (kWh/MWh) and rated power (kW/MW) if known
- DC-link topology (e.g. `single_stage_grid_side`, `two_stage_dcdc_plus_grid`)
- grid-support mode (see below)
- related time-domain run or required follow-up run
- optional `study_root`: a directory all this case's evidence artifacts must
  live under, enabling the same-study check (see below)

## Grid-Support Modes

Use consistent mode names:

- `peak_shaving` energy-time-shift / load levelling
- `frequency_response` primary/fast frequency response, FFR, inertia emulation
- `pcs_volt_var` voltage/var support at the point of common coupling
- `black_start` grid-forming energization
- `arbitrage` price-driven charge/discharge
- `none` undocumented / not declared

## Evidence Dimensions

The helper reports a status for each dimension. Two classes:

### Assumption dimensions

Documented-or-not. PASS if documented, MISSING if required and undocumented,
N/A if not required for the case.

- `battery_model` — chemistry/model type; `constant_dc_source` does not count
- `soc_window` — usable SOC operating window (min/max)
- `soh` — state of health assumption
- `thermal_limits` — cell/pack temperature limit and thermal model
- `protection` — BMS protection logic: overvoltage (ov), undervoltage (uv),
  overcurrent (oc), over/under-temperature (ot/ut), SOC-limit cutoffs
- `grid_support_mode` — one of the modes above

### Artifact dimensions

Point at an evidence file. PASS when a pointer is present and (if a path is
given) the file exists; WARN when present but flagged provisional/indirect;
MISSING when required and absent; N/A when not required.

- `battery_evidence` — battery/BMS-specific evidence (SOC tracking, OCV-R fit,
  thermal run, protection trip test)
- `dc_link` — bidirectional DC-link converter evidence (DC-bus regulation,
  charge/discharge current control)
- `modal_evidence` — small-signal/modal artifact (optional by default)
- `impedance_evidence` — impedance/frequency artifact (optional by default)
- `time_domain_validation` — EMT/RMS time-domain run (required by default)

## Battery vs DC-Link Separation Rule

This is the package's defining check and must not be relaxed.

- `battery_evidence` and `dc_link` are independent dimensions with independent
  required flags. One does not satisfy the other.
- If a case supplies only `dc_link` evidence (a converter run on a stiff DC
  source) and `battery_evidence` is required but absent, `battery_evidence` reads
  MISSING. The case is NOT battery-validated.
- The summary includes a `battery_vs_dc_link` separation screen:
  - `separated = true` only when battery evidence and DC-link evidence are
    distinct pointers (different artifact paths, or one declared and the other
    explicitly N/A).
  - If the same artifact path is reused for both battery and DC-link evidence,
    `separated = false` and a WARN is surfaced: a single generic converter
    artifact cannot prove both layers.
- `battery_layer_proven` is true only when `battery_model` is documented (not a
  constant DC source) AND `battery_evidence` is PASS. Generic DC-link evidence
  never sets this true.

## Same-Study Rule

Distinct artifact paths are necessary but not sufficient. Two unrelated runs —
a battery characterization from one study and a DC-link converter run from
another — have distinct paths yet must not be combined into one validated BESS
case.

- Declare an optional `study_root` (a directory path) on the descriptor.
- When `study_root` is declared, every present evidence artifact
  (`battery_evidence`, `dc_link`, `modal_evidence`, `impedance_evidence`,
  `time_domain_validation`) must canonicalize under that root. The match is on a
  path boundary, so `.../study1` does not match `.../study10`.
- `separation.same_study` is `true` (all present artifacts under the root),
  `false` (at least one outside, with a per-artifact WARN), or empty/`[]` when no
  `study_root` is declared (the check was not requested).
- `same_study = false` blocks `handoff_ready`. An empty `same_study` does not
  block: the check is opt-in.
- This is orthogonal to the battery-layer gate. Same-study never lets generic
  DC-link evidence prove the battery, and the battery-layer gate never waives the
  same-study requirement.

## Provisional Rule

A case is provisional until its identity is pinned: battery model documented
(and not a constant DC source), grid-support mode documented, and at least one
of rated energy / rated power documented. While provisional, every artifact PASS
is downgraded to WARN so a draft case cannot present validation-grade evidence.
The provisional banner lists the missing identity fields.

## Status Counts and Handoff

- `status_counts`: PASS / WARN / MISSING / N/A tallies.
- `handoff_ready` is true only when: not provisional, no MISSING dimension,
  battery and DC-link evidence are separated, `battery_layer_proven` is true,
  and (when `study_root` is declared) `same_study` is true.

## Interpretation Rules

- A PASS is documentation/pointer presence, not a proven physical result.
- SOC/SOH and thermal numbers are declared assumptions unless a named
  battery_evidence artifact backs them.
- Protection PASS means the logic is declared; a trip actually firing needs a
  time-domain or protection-test artifact.
- Do not claim hardware-level or HIL validation from declared assumptions or
  simulated runs.
- A constant-DC-source converter study is a DC-link study, not a battery study.

## Relation To Other Evidence

- Grid-side converter sync (GFL/GFM, PLL/VSG), weak-grid SCR: route to
  `device-pack-vsc-gfl-gfm`; a BESS grid-side converter reuses that evidence.
- Impedance: `impedance-frequency-analysis` may supply the impedance artifact;
  pass the report path explicitly and keep the operating point consistent.
- Modal: `small-signal-modal-analysis` may supply the modal artifact.
- IBR evidence: `ibr-model-validation-evidence` may cite a storage support
  summary; pass the report path explicitly.

## Failure Routing

- No documented battery model (or `constant_dc_source`): report provisional,
  request the battery model; do not let DC-link evidence imply battery
  validation.
- Battery and DC-link evidence share one artifact: request distinct artifacts
  before claiming both layers.
- Protection declared but untested: request a protection-trip time-domain run.
- Grid-support stability question: route to `device-pack-vsc-gfl-gfm` and the
  time-domain/impedance chain.
- Thermal limit claim without a thermal run: request the thermal artifact.
