# Reference Model Layout Observations

This note records layout patterns observed from the two source Simulink models
in this project.

## Source Models

- `power_KundurTwoAreaSystem.slx`
- `power_wind_dfig_avg.slx`

## Observed Practices

- The main electrical path is drawn as a readable circuit, not as a dense block
  graph. Blocks follow a left-to-right power-flow style when the example is a
  radial or two-area system.
- Bus nodes are shown as narrow visual busbars. The busbar is used as a
  connection and inspection point, while large device internals are kept in
  subsystems.
- Three-phase conductors are kept parallel and local. Long electrical lines are
  represented by line or breaker blocks stretched along the path, which reduces
  loose wire spans.
- Measurement and control logic is separated from the main electrical network.
  Kundur places PMU and signal processing logic in a shaded region below the
  network. The DFIG model places measurement outputs and scopes on the right or
  lower-right.
- Goto/From tags are used for long signal paths and measurement signals such as
  voltage, current, power, DC voltage, and speed. They are not used as a
  replacement for physical electrical connections.
- Top-level labels are concise. Detailed signal names and explanations are used
  only where they help inspection.
- `powergui` is placed in a fixed low-noise area, separate from the main
  electrical path.

## Rules Added To The Workflow

- In generated top-level network views, prefer busbar-like compact nodes over
  large load-like visual blocks when the block is being used as a bus
  connection point.
- Stretch and orient line/transformer/breaker blocks along the intended route,
  so the block itself carries most of the visual distance.
- Use Goto/From only for Simulink signal and measurement paths. For physical
  electrical connections, use local routing, rotated blocks, or subsystem
  boundaries instead.
- Keep detailed trace data in `UserData` and external trace indexes; keep the
  top-level diagram labels short enough to read.
