# Layout Cookbook

ASCII-templated root-canvas layouts derived from the eight reference models.
Use these as deterministic coordinate templates instead of running global
auto-layout.

After any root-canvas layout change, run `simulink-model-quality-layout` /
`scripts/layout/audit_model_quality_layout.m`. `${LAB_MODEL_ARCHIVE}` is the
read-only source for M01-M08 layout style: M01/M02 for two-area spacing, M07
for compact single-machine layouts, and M08 for legal signal-only Goto/From
usage.

Use full layout only inside new or empty ordinary signal-flow subsystems. Use
incremental placement for existing signal-flow subsystems. These modes never
override the deterministic-coordinate rule for a power-system root canvas.

## Contents

- Root-canvas no-overlap rule and six universal layout rules.
- M07, M08, M02, M05, and IEEE39/DFIG layout templates.
- W33-W37 local wind-farm pattern.
- Anti-patterns to avoid.

## Hard rule: zero overlap at root canvas

**No two top-level blocks may overlap.** Bounding boxes of any pair of root
blocks must be disjoint (axis-aligned rect intersection empty). Recommended
margin: ≥ 20 px gap between any two blocks for visual clarity.

Why: overlapping blocks (a) hide signal/physical port handles so add_line
silently picks the wrong port and breaks wiring; (b) make Auto Layout flag
false-positive collisions for the next derivation; (c) signal sloppy spec
authoring (a layout disagreement usually means the topology was inconsistent
to begin with).

How to enforce: every build script **must** call

```matlab
scan_block_overlap(modelName, 'ThrowOnFail', true, ...
    'Recursive', true, 'SkipPattern', {'DFIG_W33'});
```

before `save_system`. The helper is at `scripts/scan_block_overlap.m` and
errors with id `AIInLoop:LayoutOverlap` (FS-005) when overlaps are found.

Options:
- `'Recursive', true` — scans every nested SubSystem too, not just the root.
  Default is false for backward compatibility.
- `'SkipLinkedBlocks', true` (default) — skips library-link blocks; you can't
  fix overlaps inside library content without breaking the link.
- `'SkipPattern', {'DFIG_W33'}` — also skip subsystems whose path contains
  any of these substrings. Use to exclude donor subsystems copied from
  baselines (W33, etc.) so the scan only enforces what the build script
  itself authors.

Default coordinate budget per signal-row block:
- Constant / source signal blocks: width 40, height 30
- Three-Phase library blocks: width 80, height 60-90
- Subsystem boxes: width ≥ 100, height ≥ 100
- Leave ≥ 60 px between adjacent block centers in the same row

Common collision patterns to avoid:
- Putting Constant inputs at `(440, 210)` while a Three-Phase Transformer is
  at `(380 200 460 280)` — Constant lands inside transformer rect.
  **Fix**: shift Constant inputs to the gap between the transformer and the
  consuming subsystem (e.g. `(500 215 540 245)`).
- Stacking Goto/From at default `(0,0)` after `add_block` without an explicit
  Position — Simulink puts them on top of each other.

## The 6 universal rules

1. **Top canvas = electrical main path + powergui only**; everything else in SubSystem.
2. **Horizontal = electrical flow** (source → transformer → bus → device → bus → transformer → equivalent); **vertical = symmetry** (double circuit / two areas).
3. **Three-phase physical = explicit lines**, **measurement / control = Goto/From**, never mixed.
4. Block sizes: SubSystem 75×60–140, RLC branch 70×60, measurement / source 70×50, busbar bar 5×80, Goto/From 35×16.
5. Block spacing ≥ block width; unit Y-stagger ≈ 250 px.
6. Naming: bus `B1/B2/...`, SG `G1/G2/...`, wind farm `wind farmGn` or `DFIG WIND FARMn`, line `Line1/Line2/...`, signals `Utabc/Itabc/Inetabc/Unetabc/WindSpeed/Pref`.

## §1 Single-machine NEBUS benchmark (M07 SGbyhjq)

```
+---------+
|powergui |     ← (500, 170) yellow
+---------+
   ┊
+----+    +----------------+    +-------------+    +----+
| G2 |───►| 3-phase RLC    |───►| Programmable|───►|GND |
| SS |    | (升压变 / 等值)|    | Voltage Src |    +----+
+----+    +----------------+    +-------------+
(550)        (645)                  (775)         (874)
```

All blocks Y ≈ 250–315; canvas span ≈ 400×200 px.

## §2 Single VSC three-bus (M08 VSCbyhjq)

```
                    ┌───── Goto Utabc ───┐
                    │      Goto Itabc    │  measurements (top-right)
+---+     +-----+   ▼                    ▼
|VSC|◄───►| B1  |───►RLC1───►| B2 |───►RLC2───►| B3 |───►PV Source
|SS |     |bus  |             | bus|             | bus|
+---+     +-----+             +----+             +----+
(540)     (730)                (965)              (1195)         (1305)
                                                      └─►Scope (1425, 200) ◄─Inetabc/Unetabc From
                                                  Ground (1484, 380)
```

Use Goto/From for `Utabc, Itabc, Inetabc, Unetabc` only.

## §3 4-machine 2-area, two-zone symmetric (M02 DFIG_VSG_direct_4M2A)

```
canvas span ≈ 770–3460 (X), 380–1750 (Y)

   ┌──────────────────────── LEFT ZONE ────────────────────────┐    ┌─── PI Line ───┐    ┌──────────────────────── RIGHT ZONE ────────────────────────┐
   │ wind farmG1 (910, 854)    G3-3 (-)  load            line1 │    │ Three-Phase   │    │  DFIG WIND FARM3 (2845, 862)        G3 (3410, 421)         │
   │                                                            │    │   PI Section  │    │                                                              │
   │ wind farmG2 (1330, 907)                          line2     │    │   Line  ×2    │    │  G4 (2975, 1117)                    Three-Phase Fault ×2     │
   │                                                            │    │               │    │                                                              │
   │ DFIG WIND FARM2 (910, 1401)                                │    └───────────────┘    │                                                              │
   └────────────────────────────────────────────────────────────┘                          └────────────────────────────────────────────────────────────┘
```

Y stagger ~ 250 px between adjacent units. Each SubSystem ≈ 75×60–140.

## §4 MMC HVDC + 4 SG 两区 (M05 SG_mmc_phy)

Top canvas has 313 blocks but is readable because:

- **Each Line is one SubSystem** (`Line1/Line2/.../Line9`).
- **Each SG is one SubSystem** (`G1/G2/G3/G4`).
- **Each control / power calc is a `MATLAB Function` SubSystem** (`MATLAB Function1..6`).
- 70 × `From` + 39 × `Goto` carry measurement and control signals only.
- 12 Ground blocks (every physical bus has one).
- Three-Phase VI Measurement ×7 placed at strategic monitoring points.

When generating an M05-style canvas, use **bus-by-bus subsystem encapsulation**, not flat layout.

## §5 Hybrid scenario layout (e.g., NEBUS39 with G4-G8 → DFIG)

Combine §1 (per-machine) with §3 (multi-zone). Each remaining SG keeps the §1 5-block pattern inside a SubSystem; each replaced DFIG W3x block gets the M01 / M02 internal structure inside a SubSystem; both join the IEEE39 root via Three-Phase RLC branches sized 70×60.

For the existing project model `ieee39_10m39bus_sg5_dfig5_nebus_layout.slx`,
this is already implemented. Treat it as the worked example.

### IEEE39 W33-W37 local wind-farm pattern

For the latest saved `ieee39_sg5_dfig5_decoupled_interface/models/
ieee39_10m39bus_sg5_dfig5_skills_test.slx` top canvas, the usable local
wind-farm motif is:

```
WindSpeed / Trip constants  ->  W3x DFIG SubSystem  ->  Measurements / terminator
          left side                 center                    right side
```

Observed saved-model examples from the 2026-06-29 decoupled-interface layout:

- W33: constants at x≈1020-1050, `W33` at x≈1062-1188, measurement sink at
  x≈1115-1135 below the block.
- W34: constants at x≈1300-1330, `W34` at x≈1342-1468, measurement sink at
  x≈1395-1415 below the block.
- W35: constants at x≈1555-1585, `W35` at x≈1587-1713, measurement sink at
  x≈1640-1660 below the block.
- W36: constants at x≈1810-1840, `W36` at x≈1857-1983, measurement sink at
  x≈1910-1930 below the block.
- W37: constants at x≈20-50, `W37` at x≈200-295, measurement sink at x≈340-360.

W33-W36 intentionally form a readable horizontal row at y≈2445 with roughly
245-280 px between wind-farm subsystem left edges. This is preferable for the
cluster view: enough separation for physical wiring and labels, while still
making the W33-W36 group visually scan as one staged wind-farm band.

Keep this left-to-right signal direction when adding or repairing DFIG roots:
scenario/reference inputs on the left, physical DFIG block centered at its
electrical bus location, diagnostics to the right. This keeps ports readable
without hiding the IEEE39 one-line topology.

For local DFIG accessory blocks, 25-40 px visual gaps are readable for
neighboring constants, loads, taps, and measurement blocks. Allow larger
inter-device spacing to preserve the bus topology. Do not globally compress
W33-W37 into a neat table if doing so destroys the electrical geography of the
39-bus diagram.

#### 2026-07-01 L1/W37 donor layout update

For the current IEEE39 1DFIG ladder line, treat
`Claude_demo/ieee39_sg5_dfig5_skills_test/models_ladder/ieee39_l1_w37_1dfig.slx`
as the W37 layout donor. Its root-canvas W37 cluster is cleaner than the older
kX derivative layout and should be reused for weak-grid copies:

- Put `W37_WindSpeed` and `W37_Trip` immediately left of `W37`
  (`[-55 730 -25 750]`, `[-55 775 -25 795]`).
- Keep `W37` central at `[75 727 170 853]`.
- Put `TW_W37_mbus` and `W37_Measurements` just to the right of W37
  (`[220 735 280 755]`, `[240 780 260 800]`).
- Keep bus37 electrical diagnostics grouped by function: `PQ_bus37` with
  `TW_bus37_PQ` above/right (`[535 677 595 748]`, `[440 705 500 725]`),
  `TW_bus37_Iabc` nearby (`[535 770 595 790]`), and `TW_bus37_Vabc` /
  `VI_bus37` as the lower voltage group (`[255 905 315 925]`,
  `[255 1004 295 1086]`).
- Apply this as a layout-only donor pattern to `models_ladder/weakgrid/kX*`
  derivatives; do not move the canonical electrical bus topology, alter
  controller gains, or use global `arrangeSystem`.

## Anti-patterns (don't do these)

- Auto-layout / `arrangeSystem` over a power-grid one-line diagram. It loses electrical-flow semantics.
- Goto/From on three-phase wires. Always reroute physically.
- A single "everything" SubSystem at the top level. Split by electrical role: Plant / Power / Control / Measurement / Diagnostics.
- Long descriptive subsystem names like `DFIG_WIND_FARM_VSG_BASED_GRID_FORMING_INVERTER_AREA_1`. Use `wind farmG1` or `DFIG WIND FARM2`.
