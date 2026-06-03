# Layout Cookbook

ASCII-templated root-canvas layouts derived from the eight reference models.
Use these as deterministic coordinate templates instead of running global
auto-layout.

After any root-canvas layout change, run `simulink-model-quality-layout` /
`scripts/layout/audit_model_quality_layout.m`. The desktop
`实验室仿真模型汇总` archive is the read-only source for M01-M08 layout style:
M01/M02 for two-area spacing, M07 for compact single-machine layouts, and M08
for legal signal-only Goto/From usage.

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

## Anti-patterns (don't do these)

- Auto-layout / `arrangeSystem` over a power-grid one-line diagram. It loses electrical-flow semantics.
- Goto/From on three-phase wires. Always reroute physically.
- A single "everything" SubSystem at the top level. Split by electrical role: Plant / Power / Control / Measurement / Diagnostics.
- Long descriptive subsystem names like `DFIG_WIND_FARM_VSG_BASED_GRID_FORMING_INVERTER_AREA_1`. Use `wind farmG1` or `DFIG WIND FARM2`.
