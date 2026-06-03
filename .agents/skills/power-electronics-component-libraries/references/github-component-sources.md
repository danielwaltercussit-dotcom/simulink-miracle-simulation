# GitHub Component Sources

## Installed Sources

| Source | Local path | Use |
|---|---|---|
| mathworks/Simscape_Electrical_Support_Library | `external/github/Simscape_Electrical_Support_Library` | Modern Simscape Electrical support library for power-system engineers; includes component tests, motor drive, 30/57/118-bus power-system examples, switch-fidelity examples, visualization, and SLRT examples. |
| efantnu/pwrsys-matlab | `external/github/pwrsys-matlab` | Open MATLAB/Simulink library for converter-interfaced equipment; includes PLLs, PI controllers, filters, transformations, power theories, voltage/current controls, VSC sources, and example models. |
| simulink/skills | `external/github/simulink-skills-upstream` | Simulink agent skills for interaction, debugging, initialization profiling, simulation profiling, and solver profiling. |

## Selection Notes

- Use `NEBUS39V2.slx` and `NE39bus_dataV2.m` as the benchmark oracle for New England 39-bus work.
- Use `power_wind_dfig_avg.slx` for DFIG behavior compatibility in the current R2024b project.
- Use `pwrsys-matlab` when the task involves VSC controls, PLLs, p-q/CPT power theories, or average converter behavior.
- Use `Simscape_Electrical_Support_Library` as a design reference for modern Simscape native components; verify MATLAB release before executing.

## Required Report Fields

When a component library informs a generated model, report:

- source repository and local path
- source model or block
- toolbox and MATLAB release assumptions
- copied or referenced parameters
- replaced benchmark component, if any
- compile and smoke-test status
