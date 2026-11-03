# Variant Experiment Boundary

Reviewed 2026-11-03. Optional workflow for models that already use named variant
configurations; local model application remains `untested`.

Before comparing GFL/GFM, donor types, or fidelity variants, identify the exact
model, attached configuration object, dictionary/workspace source, control
variables, activation time, and installed release. Simulink configuration sets,
FRT runtime states, mask protection enables, and structural variant configurations
are different mechanisms. Do not convert one into another implicitly.

For R2024a+ with the required Variant Manager functionality, a named existing
configuration can be selected on the experiment's SimulationInput:

```matlab
in = Simulink.SimulationInput(mdl);
in = setVariantConfiguration(in, configurationName);
selectedName = getVariantConfiguration(in);
```

This only prepares an experiment. Verify model dependencies, active paths and
constraints before simulating; a recorded name does not prove the intended
blocks were active. Preserve baseline solver, rates, dispatch, observables, and
fidelity when comparing variants, or explicitly explain the intended differences.

The preferred-configuration label alone does not demonstrate activation. Record
the configuration actually used, the source revision, and relevant control values
in the existing run evidence. Unknown or incompatible selections are blocked,
not silently replaced with another configuration.

Check release-specific APIs locally. The reviewed upstream introduces newer
object names in R2026b; those names must not be copied into an R2024b workflow.
Do not require parallel-computing or test products for an ordinary serial
experiment just because an upstream all-workflows manifest lists them.

Avoid broad dictionary closing/discarding and UI reload helpers during automated
trials: they can discard unrelated unsaved work. Preserve original in-memory
values and restore experiment-owned changes on error. Never enumerate and run
every valid combination by default; use the task's bounded case list.

Source: [MathWorks variant-configuration skill](https://github.com/matlab/simulink-agentic-toolkit/tree/f7330c565877a2bce42eb029baa988398e0dc415/skills-catalog/model-based-system-engineering/simulink-manage-variant-configuration),
SKILL.md and manifest reviewed. This is a project diagnostic synthesis, not an
installation of its scripts. API availability/syntax cross-checked with
[setVariantConfiguration](https://www.mathworks.com/help/simulink/slref/simulink.simulationinput.setvariantconfiguration.html).

Future verification must include actual active-path inspection, two isolated
serial configurations, and restore-on-error readback before claiming this
workflow works in a project model. No MATLAB run was launched for this update.
