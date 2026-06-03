# DFIG PLL Tuning References (weak-grid focus)

Compiled 2026-06-02 for the closed-loop tuning experiment in
`scripts/loop/ai_in_loop_stage_tune.m`. Synthesised from web search
(WebFetch was blocked by network policy, so this is title/abstract level).

## Headline rule

For SCR < ~3, **lower the PLL bandwidth** (target ~10-20 Hz). Aggressive PLL
(Kp ≈ 60, Ki ≈ 1400 in the M01 default) creates sub-synchronous oscillations
through PLL-grid coupling. The internal-mode oscillation frequency commonly
sits in the 5-30 Hz band — that band is what `extract_tuning_metrics`
should look for.

## What "high enough damping" means

Practical thresholds used by the references below:
- `damping_ratio ≥ 0.10` for stable operation
- `damping_ratio ≥ 0.05` is borderline-stable; the system survives but rings
- `damping_ratio < 0` clearly unstable (oscillation grows)

For DFIG nameplate with integral PLL `Kp / 2*sqrt(Ki) ≈ ζ` rule of thumb,
`(Kp, Ki) = (60, 1400) → ζ ≈ 0.8` looks fine but **only at high SCR**;
weak-grid coupling effectively reshapes the closed-loop poles.

## SCR ↔ PLL bandwidth (rule of thumb)

| SCR | suggested PLL ω_n (rad/s) | suggested ω_n (Hz) | Kp,Ki order of magnitude |
|---|---|---|---|
| ≥ 5 (strong) | 60-100 | 10-16 | Kp~60 / Ki~1000-1400 |
| 3-5 (moderate) | 30-60 | 5-10 | Kp~30 / Ki~500-700 |
| 2-3 (weak) | 15-30 | 2.5-5 | Kp~12 / Ki~200-300 |
| < 2 (very weak) | < 15 | < 2.5 | Kp~6 / Ki~50-100 |

Use this only for the rule-driven first kick. Refine with a sim.

## References (titles only; abstracts via web search)

1. [Impact of Short-Circuit Ratio on Control Parameter Settings of DFIG Wind Turbines](https://www.mdpi.com/1996-1073/17/8/1825) — MDPI Energies 2024. Direct SCR-vs-control-tuning study.
2. [Impact of Power Grid Strength and PLL Parameters on Stability of Grid-Connected DFIG Wind Farm](https://vbn.aau.dk/ws/files/308304977/Impact_of_Power_Grid_Strength_and_PLL_Parameters_on_Stability_of_Grid_Connected_DFIG_Wind_Farm.pdf) — Aalborg University. Quantifies PLL-grid coupling.
3. [Small-Signal Modelling and Stability Assessment of Phase-Locked Loops in Weak Grids](https://www.mdpi.com/1996-1073/12/7/1227) — MDPI Energies 2019. PLL Kp/Ki small-signal analysis.
4. [Grid-Synchronization Stability Analysis for Multi DFIGs Connected in Parallel to Weak AC Grids](https://pdfs.semanticscholar.org/be1f/610be4447529214a8f2c1aeedfa26fa32f8d.pdf)
5. [Wind SSO (USF, 2019)](http://power.eng.usf.edu/docs/papers/2019/wind_SSO.pdf) — sub-synchronous oscillation analysis.
6. [Parameter Setting Strategy for the Controller of the DFIG Wind Turbine](https://ieeexplore.ieee.org/ielx7/6287639/8948470/08993816.pdf) — IEEE. Direct setting recipe.
7. Project's own [modeling-pattern-library M01](C:\Users\jonas\Desktop\simulink_agent_v1\docs\MODELING_PATTERN_LIBRARY.md) — `kp_pll = 60, ki_pll = 1400` is the **strong-grid default**.
8. Project's own [pattern-rows M03](pattern-rows.md) — `Copll = 0.5, Covol = 0.8` are oscillation-study amplifiers; do **not** use for normal grid stability.

## What FS-009 should fix

In `ai_in_loop_diagnose.m`, FS-009 currently says "scale PLL kp by sqrt(2)".
That move is correct only at moderate SCR. Update fix text to:

> If `dom_freq_hz` is in 5-30 Hz band AND `damping_ratio < 0.1`: SCR is likely
> weak. Halve PLL bandwidth: scale `[Kp1 Ki1 Kp2 Ki2]` by 0.5 (Kp) and 0.5
> (Ki). Re-sim. If still oscillating, halve again (down to 4× total).
