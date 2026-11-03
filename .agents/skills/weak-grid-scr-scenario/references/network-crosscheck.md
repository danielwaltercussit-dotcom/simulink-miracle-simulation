# Independent Network Crosscheck

Reviewed 2026-11-03. Source review only; no pandapower package, model, or
solver was executed. Local application status: `untested`.

## Use When

Use an optional independent network calculation when a weak-grid diagnosis
depends on load flow, topology, reactive limits, or short-circuit strength.
This is not a substitute for the project's converter/SG dynamic equations.

## Evidence Bridge

1. Export only the authorized network parameters, topology, switch states,
   dispatch, and bases to a temporary analysis location. Build a persistent
   bus/device ID mapping; dataframe row numbers are not physical bus numbers.
2. Match frequency, line length and per-km units, transformer taps/vector group,
   voltage bases, shunts, load model, slack treatment, and source P/Q convention.
   Treat `gen` and `sgen` element types separately; a static generator is not a
   dynamic DFIG, SG, or GFM controller.
3. Run the appropriate balanced or three-phase flow with explicit solver,
   tolerance, initialization, and reactive-limit settings. Check both convergence
   and the retained bus set. Automatic island handling can omit unsupplied buses;
   a converged supplied island does not validate the full intended topology.
4. Compare mapped bus V/angle, branch-end P/Q, losses, and generator Q. Align
   angle reference before comparing angles. Record PV-to-PQ changes due to Q
   limits; do not tune controllers to hide a static-equation mismatch.
5. Short-circuit analysis requires a separate source model and fault definition.
   Record IEC method/options, source short-circuit data, converter contribution,
   sequence impedances, grounding, and fault impedance. Missing values remain
   unknown; do not infer them from rated power or a controller current clamp.
6. If SCR is derived from a short-circuit result, record which sources were
   included. For the applicable balanced three-phase convention,
   `Ssc_MVA = sqrt(3)*VLL_kV*Isc_kA`, then `SCR = Ssc_MVA/Srated_MVA`.
   Total fault current including the studied converter is not automatically
   the external-grid strength seen by that converter. Do not compare unlike
   partitions or generalize this scalar index to multi-infeed dynamics.
7. Reconcile discrepancies before returning to modal/sensitivity tuning.
   Preserve the two implementations and their assumptions rather than voting
   on which tool reports a more favorable answer.

## Version and Physics Boundaries

- Record the installed pandapower version; the reviewed community skill targets
  3.4.0, while documentation under `latest` can describe newer behavior.
- Import submodules explicitly, e.g. `import pandapower.shortcircuit as sc`;
  verify the installed signature before using a copied example.
- Short-circuit source parameters for full converters and doubly-fed machines
  differ. Their fields and conventions must be checked against the matching
  installed implementation. Documentation versions disagree about the wording
  of `k`; verify its actual formula instead of copying a ratio label.
- An IEC short-circuit calculation does not simulate PLL loss of synchronism,
  limiter release, crowbar timing, DC energy, or nonlinear fault recovery.
- OPF can propose dispatch only inside an authorized optimization task. Do not
  replace the study dispatch with an optimum merely to obtain a feasible flow.
- Solver-backend speed claims and generic default networks do not establish
  equivalence to the current IEEE39 or four-machine two-area model.

## Source Relations

`network mismatch -> TEST_WITH -> mapped independent flow` is a local diagnostic
inference. `short-circuit index -> REQUIRES -> explicit source partition` is an
applicability condition, not a finding about a project case.

- [Reviewed GitHub skill](https://github.com/datathings/marketplace/tree/16729afb6224050a7f6ef2c8511dcfc9b1f5cab4/plugins/pandapower/skills/pandapower),
  Apache-2.0 repository; SKILL.md and api-powerflow.md read. Methods distilled
  here; no implementation, full API manual, or plugin copied.
- [Official AC-flow documentation](https://pandapower.readthedocs.io/en/latest/powerflow/ac.html).
- [Versioned 3.4.0 static-generator documentation](https://pandapower.readthedocs.io/en/v3.4.0/elements/sgen.html)
  and [current static-generator documentation](https://pandapower.readthedocs.io/en/latest/elements/sgen.html).

Minimum future verification: one mapped network with known power balance,
one deliberately disconnected bus, and one Q-limit violation. A scalar SCR
arithmetic check alone cannot admit this bridge as model-verified.
