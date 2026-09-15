# Converter Fault and Interaction Diagnosis

Reviewed 2026-09-14. This is a focused extension of the
[problem-solving knowledge base](problem-solving-knowledge-base.md), not a
replacement workflow or a collection of transferable controller settings.
Start with the observed failure and read only the matching card below.

## Applicability Before Retrieval

Record topology, controller, operating point, fidelity, limiter/protection
state, port/frame conventions, and benchmark revision. VSC is a device class,
GFM is a control family, and VSG/VSM is not every GFM implementation. A GFM DFIG
is not interchangeable with a GFL DFIG. An IEEE39 network name alone does not
specify ten-machine dynamics, dispatch, wind penetration, or controller data.

The relationships below are **diagnostic inferences**, not established causes
in an active model. Each requires a discriminating measurement. Source type,
reading depth, and local verification are independent. Correction/retraction
status was not exhaustively checked. No active IEEE39, four-machine two-area,
VSC, MMC, or VSG model was run for this update.

## Symptom Relationships

| Symptom -> possible mechanism | Source | TEST_WITH | REQUIRES / stop |
|---|---|---|---|
| Current bounded but voltage does not recover -> limiter locking | PE-01 | Limiter-state and post-fault trajectory audit; KB-11 | Match limiter implementation; no small-signal transient PASS |
| Multi-converter weak-grid mode -> network/control interaction | PE-02 | Network reduction plus dynamic participation; KB-06/09 | Match network assumptions; no bus-name-only transfer |
| VSM support worsens another fault -> relative acceleration/coupling | PE-03 | Paired fault-location and delay tests; KB-08/11 | Fixed dispatch/ratings; no universal gain direction |
| MMC resonance missed by averaged model -> periodic internal coupling | PE-04 | HSS truncation and injected MIMO response; KB-09/13 | Resolve internal harmonics and relevant I/O |
| MMC DC overvoltage during AC fault -> energy imbalance | PE-05 | Stored-energy and terminal-power balance; KB-02/11 | Ratings immutable; no AC-to-DC-fault transfer |
| Balanced dip passes, phase jump/unbalance fails -> omitted test axis | PE-06 | Sequence/per-phase and limiter-release checks; KB-11 | Adopt applicable requirements explicitly |
| GFM DFIG fault fails -> current-limiter interaction candidate | PE-07 | Read full text, map controller, then KB-11 | Abstract-only; no parameter action |

## PE-01 GFM Current-Limit Exit Is a Separate Gate

**Source:** A. Arjomandi-Nezhad, Y. Guo, B. C. Pal, G. Yang,
*Modeling Fault Recovery and Transient Stability of Grid-Forming Converters
Equipped With Current Reference Limitation*, IEEE TEC 40(2), 2025.
[DOI](https://doi.org/10.1109/TEC.2024.3507544);
[accepted manuscript](https://backend.orbit.dtu.dk/ws/portalfiles/portal/383705582/Modeling_Fault_Recovery_and_Transient_Stability_of_Grid-Forming_Converters_Equipped_With_Current_Reference_Limitation.pdf).
**Read:** fulltext_sections, Sections II-III and V, Figs. 12-14.
**Local:** untested; reviewed diagnostic guidance.

The paper distinguishes normal equilibrium, saturated equilibrium, and
divergence. Its analysis applies to constant-angle current-reference saturation
(CACRS); circular, d-priority, and q-priority limiters need their own mapping.
A necessary exit condition alone is not a complete recovery certificate.

**Transfer inference:** log limiter entry/exit, saturation angle, voltage-loop
integrators, P/Q references and actuals, voltage, and frequency. Classify
recovery separately from current safety. Check whether the controller returns
to the intended unsaturated operating mode before judging a successful FRT.

**Falsifying check:** bounded current with persistent saturation or failed
voltage recovery defeats a current-only PASS. A different limiter invalidates
direct use of this paper's angle bounds. Do not copy its saturation angle.

## PE-02 Network Participation Is Not State Participation

**Source:** C. Yang, L. Huang, H. Xin, P. Ju, *Placing Grid-Forming Converters
to Enhance Small Signal Stability of PLL-Integrated Power Systems*.
[arXiv:2007.03997v2](https://arxiv.org/abs/2007.03997v2);
[journal DOI](https://doi.org/10.1109/TPWRS.2020.3042741).
**Read:** fulltext_sections, Sections III-V, two-area and modified IEEE39 cases.
**Local:** untested; topology-screening guidance, not a siting instruction.

The method uses reduced network structure, including
`Qred = Q1 - Q2 * solve(Q4,Q3)` and capacity weighting
`L = S^(-1/2) * Qred * S^(-1/2)`. Its reduction assumes specific network and
converter conditions, including common R/L and interior-current assumptions.
The greedy placement method is not guaranteed globally optimal.

**Transfer inference:** screen network coupling only after verifying these
assumptions. Confirm the implicated mode with the actual dynamic A matrix,
states, and parameter derivatives. A node's network participation is not a
state's modal participation; the smallest network eigenvalue is not damping.
The paper's converter benchmarks are not the current mixed SG/DFIG models.

**Stop:** changed placement, unit count, or source type requires separate
authorization. A network-only ranking cannot authorize controller tuning.

## PE-03 VSM Support Must Survive Unfavorable Fault Locations

**Source:** R. E. Avila-Martinez, L. Rouco, J. Renedo, L. Sigrist,
A. Garcia-Cerrada, *Active-power control strategies in grid-forming power
converters to improve transient stability in power systems with 100%
converter-based generation*, 2026 preprint.
[Pinned full text](https://arxiv.org/html/2603.21428v1).
**Read:** fulltext_sections, Sections 2-4.3, Table 2.
**Local:** untested; candidate mechanism, not an accepted controller.

The VSM formulation links power imbalance to frequency dynamics. The paper
compares wide-area, local, and selectively activated support in a converter
two-area system. Table 2 includes an unfavorable case: Fault IV CCT falls
from 420 ms baseline to 300 ms for local support threshold 0.75; threshold
0.5 gives 420 ms. Therefore improvement is not universal.

**Transfer inference:** compare relative acceleration and the reference used
by each converter, then test fault location, activation, delay, and saturation.
Check pu/rad/s conventions before reusing swing-equation coefficients.

**Stop:** neither these thresholds nor clearing times transfer to an SG/DFIG
Kundur model. Require matched baselines and nonlinear fault evidence even
when a small-signal sensitivity predicts improvement.

## PE-04 MMC Harmonic Coupling Needs a Convergence Test

**Source:** J. Lyu, Q. Chen, X. Cai, M. Molinas, *Impedance Analysis of Modular
Multilevel Converter Based on Harmonic State-Space Modeling Method*, 2017
author manuscript. [Full text](https://arxiv.org/pdf/1705.01030v1).
**Read:** fulltext_sections, Sections II-V, simulation and experimental discussion.
**Local:** untested; harmonic-modeling diagnostic guidance.

Periodic arm-current and capacitor-voltage dynamics motivate harmonic
state-space (HSS) impedance analysis. The paper's selected harmonic order is
case-specific, not a universal MMC setting. Its low-voltage experimental
resistance compensation is not permission to insert negative resistance into
a project controller.

**Transfer inference:** retain relevant arm-energy, circulating-current,
balancing, and sideband dynamics when simple averaged linearization disagrees
with injection data. Increase harmonic order until the relevant response and
stability conclusion converge; compare against an independent bounded sweep.

**Stop:** a scalar positive-sequence curve cannot certify coupled dq/sequence
stability. Document frequency/frame shifts and network partition before
MIMO/Nyquist interpretation. Do not change physical arm L/C to fit a curve.

## PE-05 MMC AC-Fault Diagnosis Starts With Energy Accounting

**Source:** D. Kumar, W. Shireen, *Energy Control Strategy to Enhance AC Fault
Ride-Through in Offshore Wind MMC-HVDC Systems*, 2025 preprint.
[Full text](https://arxiv.org/pdf/2511.18184v1).
**Read:** fulltext_sections, Sections II-III, equations (2)-(6); PDF page 3
rendered to inspect coefficients and energy values.
**Local:** algebra_checked only; proposed control remains untested.

For six balanced arms with N identical capacitors each,
`E = 3*N*C*Vsm^2`; additional headroom is
`3*N*C*(Vmax^2 - V0^2)`, not total final energy. Recalculation with N=76,
C=3000 microfarads and V0=8.42 kV gives 48.493 MJ. At 1.65 times initial
energy, total is 80.014 MJ but additional capacity is only 31.521 MJ.
The paper's rounded values must not be read as all additional absorption.

**Transfer inference:** reconcile capacitor/DC energy against integrated net
terminal power, losses, and dissipator power without double-counting storage.
Resolve the storage and EDD trigger definitions before implementation.

**Stop:** this AC-fault study does not establish half-bridge DC-fault blocking.
No capacitor-rating increase or dissipator downsizing is admitted locally.

## PE-06 Fault Coverage Includes Phase Jump and Unbalance

**Source:** ENTSO-E, *Grid forming capability of power park modules*, Phase II,
final 2025-10-03, released 2025-11-04.
[Official report](https://eepublicdownloads.blob.core.windows.net/public-cdn-container/clean-documents/Reports/2025/TG_GFC_Version_2.pdf).
**Read:** fulltext_sections, phase-jump, current-limit, and unbalance sections
(PDF pages 18-20, 30-33, 66).
**Local:** untested; non-binding official guidance, not project compliance.

The report treats phase jumps, current-limited behavior, and unbalanced
conditions as distinct aspects of GFM capability.

**Transfer inference:** make separate diagnostic axes for voltage dip, phase
jump, sequence imbalance, and post-fault release. Record instantaneous per-phase
limits as well as dq/sequence quantities and averaging windows. A scaled
current-reference vector does not itself demonstrate semiconductor protection
or correct transient response.

**Stop:** adopt limits, timings, and definitions only through the applicable
task specification. Passing one balanced-dip case is not broad grid-code
compliance, and this report is not a binding requirement by itself.

## PE-07 GFM DFIG Limiter: Candidate Pointer Only

**Source:** *Transient Stability Analysis of Grid-Forming DFIG Equipped With
Circular Current Limiter*, IEEE TIE 72(11), 2025.
[Publisher](https://ieeexplore.ieee.org/document/10978905/);
[DOI](https://doi.org/10.1109/TIE.2025.3559957).
**Read:** abstract_only; authors and full formulation not yet verified here.
**Local:** blocked for detailed transfer by full-text access; candidate only.

The abstract identifies virtual-impedance and limiter interactions in GFM
DFIG transient stability. It motivates a question, not a tuning direction.

**Next evidence:** obtain an authorized full text; map rotor/grid-side
controllers, circular limiter, virtual impedance, and initialization to the
actual DFIG. Do not substitute this for the GFL PLL/crowbar model or infer a
universal instruction to decrease virtual resistance.

## Local Counterchecks and Acceptance Boundary

Three arithmetic checks were executed in Python/NumPy on 2026-09-14, without
MATLAB or active models:

| Check | Result | What it prevents |
|---|---|---|
| Sum of 6N individual capacitor energies versus PE-05 compact formula | Equal; initial 48.4931376 MJ | Arm-count and total-versus-increment errors |
| `H(s)=s/(s+1)` | DC gain 0; magnitude at 1 rad/s = 0.70710678 | Treating zero DC gain as failed linearization |
| Synthetic `Z=[[1,2],[2,1]]` | Positive diagonal; Hermitian eigenvalues -1, 3 | Treating scalar/diagonal passivity as matrix passivity |

These are algebraic counterexamples, not power-system application tests. For
matrix passivity inspect the Hermitian part `(Z+Z^H)/2` with the applicable
analytic/internal-stability conditions; a finite sampled-frequency check alone
is not a global proof. Stability analysis also needs a consistent return-ratio
partition and open-loop pole count, not only a resonance or passivity screen.

Use the existing sensitivity-first closure: qualified operating point ->
state/modal ownership -> parameter derivatives -> constrained candidate ->
relinearization -> bounded nonlinear verification. For active limiters, changing
equilibria, or periodic dynamics, first qualify the hybrid/periodic analysis
domain. Neural retrieval may rank these routes but cannot bypass that gate.

## Reviewed but Not Admitted

[arXiv:1806.11529](https://arxiv.org/pdf/1806.11529) includes a first-page
author note reporting rejection and validation/explanation concerns. It was
not admitted here as peer-reviewed VSC fault guidance. This does not disprove
every claim, but requires independent support before transfer.

Maintain these cards in place using
[research-paper-review](../../research-paper-review/SKILL.md) and
[knowledge-graph-creation](../../knowledge-graph-creation/SKILL.md).
Keep full papers outside the portable repository; link to authorized sources.
