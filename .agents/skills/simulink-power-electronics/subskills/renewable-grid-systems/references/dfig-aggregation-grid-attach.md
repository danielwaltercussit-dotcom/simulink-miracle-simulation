# DFIG Aggregation & Grid-Attachment Field Notes

Source: 2026-06 external capability test
(`Claude_demo/ieee39_sg5_dfig5_skills_test`), replacing 5 IEEE39 synchronous
machines (buses 33-37) with aggregated `power_wind_dfig_avg` DFIG farms. These
are hard-won, netlist-verified lessons for anyone repeating SG->DFIG replacement
in a large SPS network. Treat as a reference checklist, not auto-run code.

## 1. The averaged DFIG terminal is 575 V (NOT the `nom(3)` value)

`power_wind_dfig_avg.slx / DFIG Wind Turbine` mask:
`nom = [1.5e6/0.9  575  1975  60]` = [VA, statorV, **converter-internal V**, Hz].

- The **physical three-phase terminal is 575 V** (it wires to a `B575` bus in
  the donor). The donor collector chain is **575 V -> 25 kV -> 120 kV**.
- The `1975` is an internal grid-side-converter quantity, **NOT** the terminal
  voltage. Building a station transformer at 1.975 kV LV instead of 0.575 kV
  causes a ~3.4x voltage mismatch and a large sustained bus-voltage oscillation
  (observed 0.49<->1.05 pu, ripple ~0.56). Correct LV winding = **0.575 kV**.
- Single unit: 1.6667 MVA / 1.5 MW (pf 0.9). `Pmec1 = 1.5e6`.

## 2. Size the farm with Nb_wt only — never lower the target Pg

To replace a synchronous machine of dispatch `Pg` (MW):

```
Nb_wt = ceil(Pg / 1.5)          % 1.5 MW per aggregated unit
farm_MVA = Nb_wt * 1.6667
```

- Keep all donor single-unit params (`nom/sta/rot/Lm/mec` + controllers).
  Only `Nb_wt` scales the farm. Do NOT touch internal control gains or reduce
  the target Pg to force a sim to pass.
- Check `farm_MVA <= network interface capacity` (the existing IEEE39 step-up
  rating from `NE39bus_dataV2.m` `Trans` table). Report capacity margin.

## 3. Station interface transformer

Insert an explicit station transformer between the DFIG terminal and the
existing IEEE39 generator-bus step-up:

- LV winding = **0.575 kV** (DFIG terminal), HV = the **real** step-up LV winding
  voltage. For the NEBUS39V2 benchmark that LV winding is **20 kV** (the
  benchmark uses 20 kV / 500 kV step-ups, NOT the 22/345 kV labels in the data
  file comments — always read the actual `Winding1/Winding2` params).
- Capacity = farm MVA. Donor-style leakage ~0.025 pu.
- Three-phase **explicit physical wiring**. NEVER tie the 575 V terminal
  straight to the 20 kV bus.

## 4. Netlist-based island diagnosis (the high-value technique)

A farm can be perfectly wired by visual/port inspection yet read 0 V because it
sits on an isolated electrical node. `compile` passes, static port checks pass
(SPS bidirectional lines legitimately show `DstPortHandle = -1`), but the node
is dead. **Do not** debug this by repeatedly rebuilding visible wiring.

Use the SPS network analyzer to compare nodes:

```matlab
r = power_analyze(modelName, 'sort');
names = r.RlcBranchNames;      % branch labels
% r.RlcBranch(i,1:2) = the two node numbers of branch i
% A healthy generator step-up's network winding (winding_2) shares a node with
% real transmission LINES (names containing '-', e.g. '39-1','4-1').
% A dead one shares a node only with a local Load + another transformer
% secondary (a load pocket), with NO transmission line on that node.
```

Procedure:
1. Find each step-up `winding_2` node.
2. List every branch on that node. If a transmission-line branch is present ->
   the farm is on the grid. If only `Load*` + another transformer secondary ->
   the farm is on a dead pocket; reattach its network winding to the true bus
   transmission node (the node carrying that bus's lines and its `Load`).
3. After `add_line`, re-run `power_analyze` and confirm the two intended ports
   now report the **same node number** (SPS only merges when you connect onto
   the existing net, not merely a block port).

## 5. Failure-loop discipline (process)

When the same symptom survives 2 distinct fixes, STOP patching and isolate the
root cause with a different instrument (here: A/B parameter swap + netlist node
comparison) before any further edit. In this test, bus-34 stayed at 0 V through
6+ wiring/parameter fixes; an A/B test (set its `Nb_wt` to a healthy twin's
value -> still dead) proved the cause was structural/positional, not parametric
or capacity-related. That single test saved further wasted rebuild cycles.

## 6. Simulation cost (this machine, 19507-block averaged-EMT, 50 us)

0.3 s ~ 110 s; 0.5 s ~ 188 s; 1 s ~ 286 s; 2 s ~ 652 s; 8 s ~ 4861 s. More
energized branches -> slower. Run long settling sims via a detached
`matlab -batch` writing a result file; do NOT run them on the MCP synchronous
channel (it times out and looks "stuck"). Averaged-DFIG cold start
(`xInitial=[]`) needs multiple seconds to settle, so a 5 ms "smoke" proves
nothing about steady-state correctness.

## 7. Verdict criteria for a SG->DFIG replacement (use a numeric gate)

A replacement is only correct if, per farm: CAPACITY (farm MW >= Pg and
MVA <= interface cap), TRANSFORMER (0.575/<busLV> ratio, Pn >= farm MVA, no
direct terminal->bus short), and VOLTAGE (settled bus Vpu in [0.94,1.06] AND
small ripple, not a single end-sample that may land near 1.0 mid-oscillation).
"Compiles + runs + no NaN" is necessary but FAR from sufficient.
