# Modeling Problem-Solving Knowledge Base

This is the portable diagnostic router for modeling failures. It stores
distilled methods, not run history, copied papers, or model-specific parameter
values. Start from observed evidence, choose one primary path, and stop when a
prerequisite is unqualified.

## Use Contract

1. Preserve the failing model, operating point, configuration, warning text,
   signal names, and tool version before making a change.
2. Classify the first failed layer: structure, initialization, numerical
   execution, physical plausibility, linear evidence, frequency evidence, or
   nonlinear transient evidence.
3. Follow one primary path below. Add a second method only to answer a specific
   ambiguity from the first.
4. Change one bounded parameter group or one structural cause at a time.
5. Re-run the failed prerequisite before downstream analysis.
6. Data-driven and neural outputs may rank paths or parameter classes only.
   Deterministic evidence owns diagnosis, direction, step size, and acceptance.

Never infer model validity from compilation, finite output, a plausible plot,
or agreement with an external tool alone.

## Fast Router

| ID | Observed problem | First discriminator | Primary route | Stop condition |
|---|---|---|---|---|
| KB-01 | Update or compile fails | Is the failure structural, masked, variant-dependent, or callback-dependent? | Structural read/check | Unresolved ownership or hidden initialization |
| KB-02 | Power flow or initialization fails | Are bases, P/Q balance, limits, targets, and control states mutually consistent? | Operating-point qualification | No admissible operating point |
| KB-03 | Algebraic loop warning or iteration failure | Real physical constraint or artificial direct-feedthrough loop? | Loop inspection and DAE reformulation | Proposed delay has no physical contract |
| KB-04 | Minimum step, nonfinite output, or very slow run | Zero crossing, reset, Jacobian, stiffness, or discontinuity? | Solver profiling | Runtime evidence is still nonfinite or nonreproducible |
| KB-05 | Linear model is finite but suspicious | Does it reproduce the same local input/output response at the same operating point? | Linearization qualification | I/O, state map, or perturbation is unqualified |
| KB-06 | Oscillation exists but its owner is unknown | Which states participate, and which inputs observe/control the mode? | Modal participation, sensitivity, residue | Frequency coincidence is the only match |
| KB-07 | Tuning direction is unknown | Which parameter derivatives improve the target mode under constraints? | Sensitivity-first tuning closure | Wrong polarity, mode mismatch, or operating-point drift |
| KB-08 | Loops interact or tuning causes cross-regulation | Does coupling or sign change invalidate independent-loop tuning? | MIMO sweep and coupling analysis | Rank/coherence/conditioning is inadequate |
| KB-09 | Weak-grid or converter resonance is suspected | Is the instability local, interface-driven, or multi-bus? | Impedance/frequency-domain stability | Source/load partition or subsystem stability is unknown |
| KB-10 | DFIG replacement runs but is physically wrong | Is the aggregate, base conversion, control, protection, and plant interface complete? | Replacement-model audit | Physical energization or observability fails |
| KB-11 | Fault transient fails after a small-signal pass | Are limiters, protection, saturation, reset, or PLL nonlinear dynamics active? | Nonlinear transient path | Linear evidence is being used as transient proof |
| KB-12 | Spectrum or damping estimate is unstable | Is the record long, clean, and sampled well enough for the claimed mode? | Raw-signal and estimator audit | Estimators disagree beyond declared tolerance |
| KB-13 | Two fidelities or tools disagree | Are equations, states, bases, operating point, and interfaces equivalent? | Fidelity bridge and equation audit | Comparison contract is incomplete |
| KB-14 | External advice conflicts with local evidence | Is the source applicable, versioned, licensed, and locally reproduced? | External-knowledge admission | No reproducible local support |

## KB-01 Structural, Update, or Compile Failure

**Question:** Can the executable graph be constructed with known ownership and
configuration?

- Read the model structure, masks, variants, model references, callbacks,
  libraries, and root connectivity before editing.
- Separate a missing dependency from a malformed model and from a target-host
  portability error.
- Apply `model_read -> model_check`; a successful compile is only structural
  evidence and does not qualify physics.
- Route device construction to `simulink-device-adapters`, generic structure to
  `building-simulink-models`, and final evidence to
  `simulink-model-verification`.

**Stop:** Do not simulate while a callback, variant, protected parameter, or
source model is unresolved. Never edit an oracle model to make a derived model
compile.

## KB-02 Power Flow and Initialization Failure

**Question:** Does a physically admissible equilibrium exist for the complete
set of equations, limits, and controller states?

- Check unit and per-unit bases, voltage levels, transformer ratios, sign
  conventions, P/Q balance, slack/PV/PQ roles, reactive limits, current limits,
  and controller references.
- Check that initialization targets and priorities are mutually consistent.
  Inspect final initialized states rather than assuming a requested target was
  achieved.
- In Simscape releases that provide it, use the Initialization Analyzer to
  inspect targets, priorities, convergence, and the initialized network state.
- Distinguish a missing equilibrium from a numerical failure to reach an
  existing equilibrium. Solver changes cannot create a physical equilibrium.

**Stop:** An unqualified operating point blocks modal comparison, parameter
sensitivity, and tuning. Preserve the residuals and violated limits.

**Primary sources:** [Simscape variable initialization](https://www.mathworks.com/help/simscape/variable-initialization.html),
[Initialization Analyzer](https://www.mathworks.com/help/simscape/ref/simscapeinitializationanalyzer-app.html),
[Simscape troubleshooting](https://www.mathworks.com/help/simscape/ug/troubleshooting-simulation-errors.html).

## KB-03 Algebraic Loop Failure

**Question:** Is the loop an intended simultaneous physical constraint or an
artificial direct-feedthrough cycle?

- Enumerate loops with `Simulink.BlockDiagram.getAlgebraicLoops` and identify
  every direct-feedthrough block in the cycle.
- For an artificial loop, change the signal architecture at its cause.
- For a legitimate physical loop, prefer a consistent DAE formulation,
  coordinate change, or qualified initial guess.
- Add a delay, memory, zero-order hold, or rate transition only when that
  dynamic element belongs to the physical/interface contract. Then revalidate
  phase, energy, and cross-fidelity behavior.
- Route cross-domain boundary loops to `decoupled-interface-sfunctions`.

**Stop:** Do not insert delay merely to suppress a diagnostic; it changes the
dynamics and can create or hide a mode.

**Primary sources:** [Identify algebraic loops](https://www.mathworks.com/help/simulink/ug/identify-algebraic-loops-in-your-model.html),
[Algebraic loop concepts](https://www.mathworks.com/help/simulink/ug/algebraic-loops.html),
[Remove algebraic loops](https://www.mathworks.com/help/simulink/ug/remove-algebraic-loops.html).

## KB-04 Minimum Step, Nonfinite Output, or Slow Execution

**Question:** Which event forces the solver to reduce the step or recompute the
solution?

- Use Solver Profiler evidence for zero crossings, solver exceptions, resets,
  Jacobian recomputations, and step-size restrictions.
- Inspect discontinuities, saturation/limit chatter, switching events,
  dependent states, ill-scaled equations, algebraic constraints, and abrupt
  source changes near the first failure time.
- Reduce the model or time window around the first event before changing solver
  family or tolerances.
- Change solver settings only from a named numerical hypothesis, then compare
  the same physical outputs and event times.

**Stop:** Nonfinite output, unresolved warnings, or solver-dependent physics is
not a valid baseline and cannot feed learning or tuning.

**Primary source:** [Simulink Solver Profiler](https://www.mathworks.com/help/simulink/slref/solverprofiler.html).

## KB-05 Linearization Is Finite but Unqualified

**Question:** Does the linear model represent the local nonlinear behavior at
the stated operating point and I/O definition?

- Record the exact operating point, state ordering/names, I/O points, model
  configuration, and linearization method.
- Compare exact/block linearization with numerical perturbation or frequency
  response at the same operating point and I/O when supported blocks or hidden
  states are uncertain.
- Sweep perturbation size to test numerical convergence; a single finite
  Jacobian is insufficient.
- Reproduce the selected mode or local response in a bounded time-domain test.
- Inspect unsupported blocks that can linearize to zero or omit switching,
  protection, saturation, or sampled-data effects.

**Stop:** Block modal ownership, sensitivity-based tuning, and PASS claims when
the state map, I/O map, operating point, or local reproduction is missing.

**Primary sources:** [Linearization basics](https://www.mathworks.com/help/slcontrol/linearization-basics.html),
[`linearize`](https://www.mathworks.com/help/slcontrol/ug/linearize.html),
[`frestimate`](https://www.mathworks.com/help/slcontrol/ug/frestimate.html).

## KB-06 Oscillation Frequency Known, Owner Unknown

**Question:** Which physical states form the mode, and which I/O path can
observe and influence it?

1. Classify the symptom as rotor-angle, voltage, frequency, resonance,
   converter-driven, or unclassified before choosing a diagnostic tool.
2. Use participation to identify the state-mode association.
3. Use eigenvalue/damping sensitivity to identify parameter classes that move
   the mode.
4. Use modal residues or equivalent I/O measures to test actuator and sensor
   placement.
5. Confirm the mode with matching frequency, shape, operating point, and a
   time-domain or frequency-response observation.

Participation, sensitivity, and residue answer different questions. They are
not interchangeable, and matching frequency alone does not establish identity.

**Stop:** Do not assign source ownership or tune a controller from a peak label
without qualified state and I/O evidence.

**Theory sources:** [Power-system stability classification, 2021](https://doi.org/10.1109/TPWRS.2020.3041774),
[Selective Modal Analysis Part I](https://doi.org/10.1109/TPAS.1982.317524),
[participation, sensitivity, and residue foundations](https://doi.org/10.1109/59.32489).

## KB-07 Sensitivity-First Tuning Closure

**Question:** What bounded parameter direction improves the target metric while
respecting all operating and control constraints?

1. Start from a qualified operating point and a matched target mode.
2. Compute the parameter sensitivity matrix for eligible control parameters.
   Include eigenvalue real/imaginary parts or damping/frequency metrics as
   required by the objective.
3. Normalize columns by meaningful parameter ranges; inspect conditioning,
   sign stability, and finite-difference step convergence.
4. Exclude plant identity, network physics, rating, protection, and frozen
   parameters unless the user explicitly authorizes a design change.
5. Solve a constrained direction and bounded step from the sensitivity matrix.
6. Re-linearize, match the post-change mode, compare prediction with measured
   movement, and reject polarity or mode-tracking errors.
7. Run a short time-domain verification, then accept or roll back.

A neural assistant may rank parameter classes after the mathematical screen or
break a near-tie. It may not invent direction, magnitude, or acceptance. After
a rollback, recompute the local sensitivity instead of guessing a new knob.

**Stop:** Halt on operating-point drift, mode mismatch, ill-conditioned
eigenvectors, unstable derivative sign, constraint violation, or failed
time-domain verification.

**Primary source:** [Simulink Design Optimization sensitivity analysis](https://www.mathworks.com/help/pdf_doc/sldo/sldo_ug.pdf).

## KB-08 MIMO Coupling and Cross-Regulation

**Question:** Can each loop be tuned independently over the active frequency
band?

- Excite one input at a time and retain all relevant outputs.
- Build the complex response matrix `G(jw)` with units, scaling, operating
  point, and coherence or uncertainty attached.
- Inspect off-diagonal gain, relative gain behavior, singular values,
  conditioning, phase/sign changes, and repeated behavior across operating
  points.
- Use residues or controllability/observability evidence to distinguish a bad
  pairing from a structurally uncontrollable or unobservable mode.
- If coupling is strong or reverses with frequency, design or schedule the
  multivariable action instead of independently tuning diagonal loops.

**Stop:** Do not compute a tuning move from rank-deficient, incoherent,
poorly-scaled, or single-channel evidence.

**Route:** `multivariable-control-cross-regulation`.

## KB-09 Weak-Grid and Converter Resonance

**Question:** Does the instability arise from the converter-grid interface, and
is a single-bus representation sufficient?

- Perform an active frequency sweep around a qualified operating point. Record
  injection location, amplitude, band, dwell/settling, windowing, bases, I/O,
  and coherence.
- Define the source/load partition and sign convention before forming an
  impedance ratio or applying Nyquist reasoning. Check subsystem stability and
  interface assumptions.
- In a white-box multi-bus network, prefer nodal or multi-bus admittance
  analysis when remote coupling matters. A selected single bus can miss a
  network instability.
- Use frequency-dependent impedance sensitivity to identify the controller or
  setpoint class associated with a problematic band.
- Re-sweep after every accepted candidate because the local frequency response
  changes with operating point and controller settings.

**Stop:** An impedance crossing without a declared partition, bases, subsystem
stability, and frequency-response quality is not an instability verdict.

**Theory sources:** [Impedance-based stability criterion](https://doi.org/10.1109/TPEL.2011.2136439),
[nodal versus bus impedance analysis](https://doi.org/10.1109/TPWRS.2023.3267504),
[WTG impedance sensitivity](https://doi.org/10.1049/icp.2025.4571).

## KB-10 DFIG Replacement Runs but Is Physically Wrong

**Question:** Does the replacement preserve the intended plant rating,
network interface, dynamics, controls, limits, and measurements?

- Audit installed MVA versus dispatched MW, machine count, base conversion,
  transformer/collector impedance, voltage level, and P/Q sign convention.
- Verify rotor dynamics, converter controls, PLL where applicable, DC-link,
  current limits, reactive/voltage control, protection/FRT behavior, and
  initialization states required by the chosen fidelity.
- Confirm physical terminal voltage/current and P/Q at the network interface;
  an internal signal that is zero is not proof of physical disconnection.
- Qualify the replacement operating point before comparing modal or transient
  behavior with the synchronous-machine donor.

**Stop:** Compile/smoke success cannot pass a replacement whose physical
energization, observability, rating, or operating point is unqualified.

**Theory source:** [DFIG dynamic modeling for power-system studies](https://doi.org/10.1109/TPWRS.2003.811178).

## KB-11 Fault Transient Fails after Small-Signal PASS

**Question:** Which nonlinear or hybrid behavior is absent from the local
linear model?

- Inspect current limiting, saturation, anti-windup, protection, FRT logic,
  PLL angle/frequency excursion, discrete reset, mode switching, and recovery
  after fault clearing.
- Treat the small-signal result as a local screen around one equilibrium, not a
  certificate for a large disturbance.
- Use a bounded fault window with explicit pre-fault equilibrium, event times,
  post-fault topology, pass metrics, and rollback conditions.
- Requalify the post-fault operating region if the controller or network enters
  a different mode.

**Stop:** Do not repair a nonlinear fault failure solely by shifting a local
eigenvalue; identify the active limiter/protection/PLL mechanism first.

**Theory source:** [PLL nonlinear transient stability under grid faults](https://doi.org/10.1109/TPEL.2020.3000516).

## KB-12 Spectrum or Damping Estimate Is Misleading

**Question:** Does the raw record contain enough stationary, observable signal
to support the claimed mode and damping?

- Preserve raw signals before filtering or resampling. Record native time,
  sample interval, duration, missing data, event boundaries, and units.
- Separate cold-start ringdown, forced oscillation, control transients, and
  ambient behavior. Do not label start-up decay as instability.
- Check frequency resolution, aliasing, leakage/windowing, detrending, signal
  floor, and estimator assumptions.
- Compare at least two suitable estimators when damping is decision-critical,
  and report disagreement as uncertainty rather than selecting the preferred
  answer.
- Confirm the candidate mode against state participation, I/O response, or a
  controlled perturbation.

**Stop:** If the record is too short, nonstationary, clipped, or below the
measurement floor, report `inconclusive` and obtain better evidence.

## KB-13 Fidelity or Cross-Tool Disagreement

**Question:** Are the compared models solving equivalent equations at the same
operating point and observation boundary?

- Align topology, component equations, parameters, units/bases, operating
  point, controller/protection state, delays/holds, state order, I/O, events,
  and solver interpretation.
- Declare what each fidelity omits: switching, electromagnetic states, network
  algebraics, saturation, protection, or sampled-data effects.
- Compare invariants and local behavior before comparing every waveform.
- Use an independent implementation to detect formulation mistakes, not as a
  majority vote over local evidence.
- For hybrid symbolic-numeric tools, verify generated residuals/Jacobians and
  state identity before trusting eigenvalues.

**Stop:** Do not tune away a disagreement until the comparison contract is
complete and the discrepancy has an identified owner.

**Theory/source:** [ANDES hybrid symbolic-numeric framework](https://doi.org/10.1109/TPWRS.2020.3017019).

## KB-14 External Advice Conflicts with Local Evidence

**Question:** Is the external method applicable and reproducible in this model,
tool version, and fidelity?

1. Prefer official documentation, standards, and primary papers; then
   maintained repositories with tests; then community material.
2. Record source URL/DOI, publication or release, revision/tag, license,
   applicable model/fidelity, assumptions, and known limits.
3. Review mathematical consistency and map variables/units to the local model.
4. Reproduce the useful claim on a small fixture or existing local evidence.
5. Distill only the accepted rule and provenance into the existing skill. Keep
   rejected or superseded status explicit; do not copy the source repository.

**Stop:** External authority, popularity, or a health check is not acceptance.
When external and qualified local evidence conflict, the local deterministic
gate owns the decision and the conflict remains open.

### Paper Distillation Card

Use this compact card when a paper contributes a diagnostic or modeling rule:

- **Identity:** title, authors, venue/year, DOI or stable URL, version, and any
  correction/retraction status.
- **Question and claim:** the exact problem and the narrow claim being tested;
  separate author claims from the agent's inference.
- **Mathematical object:** equations, states, inputs/outputs, parameters,
  constraints, linear/nonlinear domain, and continuous/discrete domain.
- **Assumptions:** operating point, topology, timescale, device fidelity,
  source/load partition, observability, perturbation size, and stability of
  subsystems where required.
- **Evidence:** analytical proof, simulation, experiment, benchmarks, metrics,
  uncertainty, and negative or ablation results.
- **Transfer map:** local variable and unit mapping, applicable skill/KB route,
  expected benefit, and conditions that would invalidate transfer.
- **Reproduction:** smallest local fixture or existing evidence that can test
  the useful claim without changing an active model.
- **Decision:** `candidate`, `admitted`, `rejected`, or `superseded`, with the
  deterministic gate and evidence path. Only admitted rules enter this file.

The reading workflow was cross-checked against the MIT-licensed
[BESSER-PEARL research-paper-review skill](https://github.com/BESSER-PEARL/research-agent-skills/blob/main/research-paper-review/SKILL.md),
the [OpenAI research-documentation skill](https://github.com/openai/skills/tree/main/skills/.curated/notion-research-documentation),
and the [Anthropic PDF skill](https://github.com/anthropics/skills/blob/main/skills/pdf/SKILL.md).
Their useful ideas were reduced to source tracking, structured extraction,
consistency checks, limitations, and reproducibility. No external skill was
installed or copied, and none is a runtime dependency of this library.

## Theory Map

| Question | Theory anchor | Practical use | Boundary |
|---|---|---|---|
| What kind of instability is this? | IEEE/CIGRE stability classification, 2021 | Choose rotor-angle, voltage, frequency, resonance, or converter-driven route | Classification is not root-cause proof |
| Which states form the mode? | Selective Modal Analysis, 1982 | Focus state/mode analysis on the relevant subsystem | Requires a qualified local model |
| Which parameter moves the mode? | Eigenvalue sensitivity and participation foundations, 1989 | Build the first tuning direction from derivatives | Local result; relinearize after changes |
| Can the I/O path control and observe it? | Modal residues and MIMO response | Select sensors, actuators, and pairings | Scaling and operating point matter |
| Is a converter-grid interface unstable? | Impedance-ratio/Nyquist criterion, 2011 | Diagnose interface resonance by frequency | Partition and subsystem assumptions are mandatory |
| Can one bus represent a multi-bus interaction? | Nodal versus bus admittance, 2023 | Escalate white-box studies to nodal analysis | Single-bus black-box use remains context-dependent |
| Why do low-inertia controls interfere? | Full-order timescale-coupling analysis, 2021 | Retain relevant converter, line, load, and SG dynamics | Reduced models must demonstrate preserved modes |
| Why can a fault fail after linear PASS? | Nonlinear PLL transient analysis, 2020 | Route to nonlinear/hybrid fault mechanisms | Not every transient failure is PLL-owned |

Additional theory anchor for mixed synchronous-machine and converter systems:
[Understanding small-signal stability of low-inertia systems](https://doi.org/10.1109/TPWRS.2021.3061434).

## Admission State (2026-09-08)

| Source group | Verified now | Untested or bounded |
|---|---|---|
| MathWorks algebraic-loop, Solver Profiler, initialization, and linearization documentation | Current official behavior and stated tool scope | No active project model was opened or run; Initialization Analyzer requires R2026a or later |
| Peer-reviewed modal, sensitivity, stability-classification, DFIG, PLL, and impedance papers | Bibliographic identity and diagnostic role | No paper result is treated as a local model result or parameter recommendation |
| 2025 WTG impedance-sensitivity paper | Publication metadata, abstract-level method, and frequency-dependent sensitivity use | Candidate extension until reproduced on a bounded local sweep |
| ANDES hybrid symbolic-numeric framework | Primary paper method and cross-tool validation concept | No local ANDES/MATLAB equivalence claim |

These entries are admitted as theory and diagnostic guidance. Any claim about a
specific IEEE39, DFIG, or four-machine two-area model remains `untested` until
the relevant project-local gate produces disk evidence.

## Local Application Validation (2026-09-08)

KB-07 was applied to a temporary second-order low-damping Simulink model, not
to an active IEEE39 or four-machine two-area model. The model was deleted after
the run; the machine-readable result remains at
`build/reports/knowledge_application_validation/kb07_sensitivity_closure.json`.

| Gate | Baseline | Candidate/result |
|---|---:|---:|
| Damping parameter | 0.2 | 1.0053096491 |
| Oscillatory-mode damping ratio | 0.0159154943 | 0.08 |
| Estimated `d(damping ratio)/dp` | 0.0795774715 | positive, central difference |
| Tail-response RMS | 0.3579619993 | 0.0207335556 |

The model passed read/edit/read/update, finite-output, bounded-candidate,
re-linearization, mode-improvement, and time-domain-decay checks. Neural advice
was not used because the mathematical sensitivity produced a decisive
direction. This validates the KB-07 control flow on a transparent fixture; it
does not validate a parameter value or PASS state for any project power-system
model.

## Refresh Rule

Refresh an entry only when a tool release changes the diagnostic behavior, a
new primary result changes its mathematical boundary, or local evidence shows
the rule is incomplete. Update the existing entry and provenance in place.
Do not create a new report, bundle, manifest, copied repository, or vector
database merely because a source was reviewed.
