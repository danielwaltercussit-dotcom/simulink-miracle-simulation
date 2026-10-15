# VSC, DFIG, and Synchronous-Machine Modeling Contract

Reviewed 2026-10-15. Use this before transferring parameters, changing device
adapters, or extracting local state models. It supplements the existing
[adapter contract](adapter-contract.md); it does not authorize a model change.
GitHub intake and excluded claims are recorded in
[agentic modeling policy](../../simulink-modeling-assistant/references/agentic-modeling-policy.md).

## Identify the Implemented Device

| Family | Identify before transfer | First mathematical/physical check |
|---|---|---|
| VSC | Two-level/three-level/MMC; averaged/switched; PLL/GFL or GFM; current direction; filter and modulation scaling | Match dq transforms and P/Q to raw three-phase measurements; qualify DC energy and limiter state |
| DFIG | Stator connection, rotor-side and grid-side converters, shaft/gearbox, reference frames, crowbar/DC protection, donor aggregation | Reconcile stator plus grid-side export with PCC injection; map slip and rotor/base quantities |
| SG | Round/salient rotor; model order; saturation; winding bases; mechanical input; AVR/governor/PSS; network angle reference | Match load-flow P/Q/V/angle and field/mechanical initialization; inspect rotor-speed and controller residuals |

Do not replace a wound-field grid synchronous machine with a PMSM/PMSG motor
example merely because both are synchronous. A PMSG MPPT/FOC controller is not
an AVR/governor/PSS model. A fixed 50/60 Hz angle ramp is not a PLL or GFM
synchronization model for a disturbance study.

## Bases, Angles, and Aggregation

Record power base, line-line RMS voltage base, frequency, peak/RMS convention,
mechanical/electrical speed, pole pairs, and every measurement conversion.
For a common three-phase base:

```text
Zbase = VLL_rms^2 / S3phase
Ibase = S3phase / (sqrt(3) * VLL_rms)
Zpu_new = Zpu_old * (Snew/Sold) * (Vold/Vnew)^2
omega_electrical = pole_pairs * omega_mechanical
slip = (omega_sync_electrical - pole_pairs*omega_mechanical)
       / omega_sync_electrical
```

The last two relations refer to rotor speeds in the same machine/shaft
reference; include the gearbox when the measured speed is turbine-side.
Do not confuse a block's pole count with pole pairs or rad/s with pu speed.
DFIG rotor quantities can use different winding/referral bases from stator
quantities: inspect the block's equations before combining them.

For N identical parallel units at unchanged voltage/frequency, physical
equivalent R and L divide by N, C and total rating multiply by N. On the
correspondingly scaled power base, equivalent pu impedance remains unchanged.
An aggregation parameter such as donor `Nb_wt` can already perform that
scaling; applying both methods double-counts it. Coherent identical-machine
aggregation preserves H in seconds on the aggregate rating, not N*H.

The existing DFIG field notes apply to their audited donor; 575 V, unit rating,
and aggregation limits are not universal DFIG constants. Read
[DFIG grid-attachment notes](../../simulink-power-electronics/subskills/renewable-grid-systems/references/dfig-aggregation-grid-attach.md)
and inspect the actual donor before sizing the interface transformer.

## Power and Energy Boundary

- Declare terminal current directions and use one export convention for
  comparisons. Under an export-positive convention, DFIG network injection
  combines stator export and grid-side-converter export. Rotor-side exchange
  is internal to that boundary; adding it again double-counts power.
- For a VSC, match raw `va*ia + vb*ib + vc*ic` with the implemented dq power
  expression. The 3/2 factor applies to amplitude-invariant phase-peak dq
  quantities under the matching transform, not to every Park convention.
  Reactive-power sign also depends on the axis/rotation convention.
- For a capacitor, `E=0.5*C*Vdc^2`. Reconcile its change with integrated net
  DC-link power and losses using the actual modeled storage boundary. SG/DFIG
  shaft energy additionally depends on inertia and mechanical speed; a flat
  electrical-power trace does not prove shaft equilibrium.
- Use direct VI/shaft signals with units. Apparent power, internal donor
  telemetry, and a fitted scale factor cannot replace terminal power balance.

These are algebraic contracts; the local model's equations and ports decide
the final sign and scaling. Preserve plant parameters and ratings when the
authorized task is controller tuning.

## Initialization Before A-Matrix or Fault Studies

1. Map the required dispatch to the implemented device without lowering the
   target to make a run pass. Check power, reactive capability, current limits,
   voltage, transformer ratio, and headroom.
2. For SGs, reconcile network P/Q/V/angle with rotor/field states and the
   mechanical input, AVR, governor, and PSS. Select independent initialization
   constraints; imposing every state/reference as known can overconstrain trim.
3. For DFIGs, qualify shaft speed/slip, stator/rotor flux, DC voltage, RSC/GSC
   integrators and limits, aerodynamic/mechanical input, and protection state.
   For VSCs include PLL/GFM angle, current/filter states, outer loops, and DC
   energy. A short voltage/P match is not sufficient.
4. Distinguish SPS `powergui`/load-flow initialization from Simscape load-flow
   and initialization targets. Check the installed release and actual library;
   block paths and licenses are not interchangeable.
5. Record residuals, slow drift, and active limits. Requalify changed operating
   points before sensitivity comparison or fault recovery claims. Use
   [simulink-linearize](../../simulink-linearize/SKILL.md) for API mechanics.

## PWM and Sampled-Control Diagnosis

For switched VSC/RSC/GSC paths, log controller commands and actual device gates,
then compare event timing. Simple NOT complementarity does not establish
dead-time, interlock, or shoot-through safety. Match delay/dead-time and pulse
suppression to the represented fidelity and hardware intent.

Choose electrical step, controller sample time, measurement rate, and PWM
period from required dynamics and pulse resolution. Establish convergence with
a finer relevant resolution when the result depends on switching events.
Do not adopt a community model's nanosecond step or fixed gain universally.
Average models need an explicit omitted-switching boundary, not an invented
gate test. Do not insert arbitrary shunt resistors or converter-input filters
to silence a solver problem without checking their effect on the equations.

## Reuse After Review

Local inference from the reviewed GitHub workflows: preserve a port-specific
connectivity and parameter baseline for layout changes. After save/reopen,
compare adjacency and electrical nodes; raw line-object counts can change
when branches normalize. Inspect screenshots for occlusion, long independent
wire overlaps, and the intended energy path. The existing layout skill owns
the visual gate; automatic global rerouting or hiding all names is not implied.

## Source and Verification Limits

- [MathWorks DFIG averaged-model example, R2024b](https://www.mathworks.com/help/releases/R2024b/sps/ug/wind-farm-dfig-average-model.html):
  donor/fidelity context. Detailed port and parameter claims require the
  installed example and local field-note evidence.
- [MathWorks synchronous-machine initialization](https://www.mathworks.com/help/simscape-electrical/ug/synchronous-machine-initialization-with-loadflow.html):
  load-flow initialization context; do not transplant Simscape settings to SPS.
- [MathWorks electrical-library selection](https://www.mathworks.com/help/simscape-electrical/ug/choose-blocks-to-model-electrical-systems.html):
  distinguish Simscape Foundation from the Simscape Electrical add-on and
  verify product availability for the installed blocks.

The equations above were checked with synthetic arithmetic on 2026-10-15.
That establishes unit/scaling consistency only. Device initialization,
switching behavior, A matrices, and current project models remain untested
by this documentation update.
