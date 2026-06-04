# Fidelity Decision Contract

Use this contract when writing or reviewing a model fidelity decision.

## Required Fields

Record:

- case name and study objective
- decisive dynamics and time scales
- candidate fidelity family
- included dynamics
- excluded dynamics
- acceptable assumptions
- forbidden shortcuts
- required observables
- validation route
- source models or lab references
- downstream skill routing

## Decision Matrix

| Study need | Preferred fidelity | Must not hide |
|---|---|---|
| Load flow or slow plant response | RMS / positive-sequence | voltage support limits, plant controller mode |
| DFIG/VSC PLL or VSG interaction | averaged EMT or dynamic phasor | PLL/VSG state, current limit, DC-link |
| Low SCR or ESCR scan | averaged EMT plus modal checks | system strength change, controller gain sensitivity |
| Fault ride-through and recovery | EMT; averaged first, switching if protection matters | current limiting, voltage recovery, fault timing |
| Protection or harmonics | switching EMT or impedance | modulation, phase detail, harmonic filters |
| Oscillation mechanism | small-signal/modal plus time-domain validation | mode ownership, damping, participation |
| Large scenario sweep | RMS/phasor with EMT spot checks | missing fast-control failure cases |

## PASS Criteria

A fidelity decision is usable when:

- the chosen fidelity can answer the stated question,
- at least one validation or cross-check route is named,
- excluded dynamics are explicitly judged non-decisive,
- required signals are observable in the selected model, and
- the report can be audited without reading the whole model.

## Failure Routing

- If the decisive observable is not logged, route to `diagnostic-plotting` or
  model logging work before accepting results.
- If the question is about damping or mode ownership, route to
  `small-signal-modal-analysis`.
- If the question is about weak-grid operation, route to
  `weak-grid-scr-scenario`.
- If the question is about plant model credibility, route to
  `ibr-model-validation-evidence`.
