# Scenario Catalog

## voltage_sag_0p5pu_200ms

Intent: low-voltage ride-through and fault recovery.

Patch:

```yaml
topology:
  source:
    fault_injection:
      enabled: true
      mode: amplitude_step
      t_start_s: 0.5
      t_end_s: 0.7
      amplitude_pu_during_fault: 0.5
```

Expected signals: `Vabc_HV`, `Iabc_HV`.

Metrics: no NaN, voltage recovers within 1 s, current oscillation not growing.

Likely FS: `FS-003`, `FS-006`, `FS-009`, `FS-013`.

## weak_grid_scr_2p5

Intent: expose PLL/grid-current instability under weak grid.

Patch:

```yaml
topology:
  weak_tie_line: { R_pu: 0.05, L_pu: 0.40 }
```

Metrics: `I_osc_growth <= 1.05`, finite outputs, voltage band pass.

Likely FS: `FS-013`, `FS-014`.

## wind_speed_step

Intent: verify wind input and speed loop response.

Patch:

```yaml
scenario:
  wind_speed_step: { from_mps: 12, to_mps: 14, t_step_s: 1.0 }
```

Metrics: finite outputs, no DC-link/PLL blowup, active power settles.

Likely FS: `FS-014`, `FS-006`.
