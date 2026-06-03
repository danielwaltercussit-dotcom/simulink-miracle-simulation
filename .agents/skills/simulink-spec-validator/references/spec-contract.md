# Spec Contract

## Minimal Fields

```yaml
system:
  name: model_name
  base_mva: 100
  frequency_hz: 50
  stop_time: 5.0
  solver: FixedStepDiscrete
  sample_time: 5e-5

topology: {}

convergence_targets:
  smoke: { duration_s: 0.005, no_nan: true }
```

## Recommended Fields

- `system.parent_models`
- `system.derivation_strategy`
- `topology.source`
- `topology.fault_injection`
- `convergence_targets.steady_state.voltage_band_pu`
- `convergence_targets.fault_recovery.recovery_window_s`
- `notes`

## Common Rejections

- `sample_time >= stop_time`
- unsupported frequency such as 55 Hz
- fault end time after stop time
- missing `convergence_targets`
- missing topology/replacement intent
