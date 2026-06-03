function run_ieee39_sg5_dfig5_tuning()
%RUN_IEEE39_SG5_DFIG5_TUNING Create rule-based v0.1 control tuning report.

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(projectRoot, "data", "matpower"));
mpc = case39();

dfigBuses = [33 34 35 36 37];
sgBuses = [30 31 32 38 39];

ensureDir(fullfile(projectRoot, "build", "reports"));
ensureDir(fullfile(projectRoot, "build", "data"));

tuned = struct();
tuned.system = "ieee39_sg5_dfig5_v0";
tuned.method = "rule_based_initial_control_tuning_v0";
tuned.sg = tuneSg(mpc, sgBuses);
tuned.dfig = tuneDfig(mpc, dfigBuses);
tuned.convergence = evaluateSolvedPowerFlow(mpc);
tuned.post_tuning_screen = evaluateTunedReferences(tuned.sg, tuned.dfig);

writeJson(fullfile(projectRoot, "build", "data", "ieee39_sg5_dfig5_tuned_params.json"), tuned);
writeReport(projectRoot, tuned);

fprintf("Tuned parameter file: %s\n", fullfile(projectRoot, "build", "data", "ieee39_sg5_dfig5_tuned_params.json"));
fprintf("Tuning report: %s\n", fullfile(projectRoot, "build", "reports", "tuning_report.md"));
end

function out = tuneSg(mpc, sgBuses)
gens = mpc.gen;
buses = mpc.bus;
out = struct([]);
for i = 1:numel(sgBuses)
    bus = sgBuses(i);
    gen = gens(gens(:, 1) == bus, :);
    busRow = buses(buses(:, 1) == bus, :);
    pg = gen(2);
    pmax = gen(9);
    item = struct();
    item.id = sprintf("sg_G%d", bus);
    item.bus = bus;
    item.pg_mw = pg;
    item.pmax_mw = pmax;
    item.original_vref_pu = gen(6);
    item.tuned_vref_pu = clamp(gen(6), 0.94, 1.06);
    item.bus_vm_pu = busRow(8);
    item.H = round(3.0 + 2.5 * min(pg / 1000, 1), 3);
    item.D = 2.0;
    item.governor_R = 0.05;
    item.governor_Tg = 0.2;
    item.avr_Ka = round(80 + 40 * min(pg / 1000, 1), 3);
    item.avr_Ta = 0.05;
    item.pss_K = 10;
    item.pss_Tw = 10;
    item.note = "Initial SG rules; verify after physical network load-flow initialization.";
    out = appendStruct(out, item);
end
end

function out = tuneDfig(mpc, dfigBuses)
gens = mpc.gen;
buses = mpc.bus;
out = struct([]);
for i = 1:numel(dfigBuses)
    bus = dfigBuses(i);
    gen = gens(gens(:, 1) == bus, :);
    busRow = buses(buses(:, 1) == bus, :);
    pg = gen(2);
    pmax = gen(9);
    pllBandwidthHz = 20;
    zeta = 0.707;
    wn = 2*pi*pllBandwidthHz;
    item = struct();
    item.id = sprintf("dfig_G%d", bus);
    item.bus = bus;
    item.rated_mva = max(pmax, pg);
    item.p_ref_mw = pg;
    item.q_ref_mvar = gen(3);
    item.original_vref_pu = gen(6);
    item.tuned_vref_pu = clamp(gen(6), 0.94, 1.06);
    item.bus_vm_pu = busRow(8);
    item.q_control = "voltage";
    item.pll_Kp = round(2*zeta*wn, 3);
    item.pll_Ki = round(wn^2, 3);
    item.current_loop_bandwidth_hz = 200;
    item.current_Kp = 0.3;
    item.current_Ki = 40;
    item.dc_voltage_Kp = 4.0;
    item.dc_voltage_Ki = 80;
    item.pitch_Kp = 2.0;
    item.pitch_Ki = 0.5;
    item.note = "Equal-capacity DFIG replacement using original MATPOWER Pg/Qg as initial P/Q references.";
    out = appendStruct(out, item);
end
end

function post = evaluateTunedReferences(sg, dfig)
refs = [extractfield(sg, "tuned_vref_pu"), extractfield(dfig, "tuned_vref_pu")];
post = struct();
post.source = "clamped SG/DFIG control voltage references";
post.min_vref_pu = min(refs);
post.max_vref_pu = max(refs);
post.voltage_reference_range_target = [0.94 1.06];
post.voltage_reference_range_pass = min(refs) >= 0.94 && max(refs) <= 1.06;
post.note = "This is a control-reference screen, not a re-solved physical load flow.";
end

function conv = evaluateSolvedPowerFlow(mpc)
vm = mpc.bus(:, 8);
conv = struct();
conv.source = "MATPOWER case39 solved bus voltages";
conv.min_vm_pu = min(vm);
conv.max_vm_pu = max(vm);
conv.voltage_range_target = [0.94 1.06];
conv.voltage_range_pass = min(vm) >= 0.94 && max(vm) <= 1.06;
conv.generator_count = size(mpc.gen, 1);
conv.branch_count = size(mpc.branch, 1);
end

function writeReport(projectRoot, tuned)
reportFile = fullfile(projectRoot, "build", "reports", "tuning_report.md");
fid = fopen(reportFile, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# IEEE39 SG/DFIG v0.1 Control Tuning Report\n\n");
fprintf(fid, "Method: `%s`\n\n", tuned.method);
fprintf(fid, "## Convergence Screening\n\n");
fprintf(fid, "- Source: %s\n", tuned.convergence.source);
fprintf(fid, "- Min Vm: %.6f pu\n", tuned.convergence.min_vm_pu);
fprintf(fid, "- Max Vm: %.6f pu\n", tuned.convergence.max_vm_pu);
fprintf(fid, "- Voltage range target [0.94, 1.06] pu: %s\n\n", passText(tuned.convergence.voltage_range_pass));
fprintf(fid, "## Post-Tuning Reference Screen\n\n");
fprintf(fid, "- Source: %s\n", tuned.post_tuning_screen.source);
fprintf(fid, "- Min tuned Vref: %.6f pu\n", tuned.post_tuning_screen.min_vref_pu);
fprintf(fid, "- Max tuned Vref: %.6f pu\n", tuned.post_tuning_screen.max_vref_pu);
fprintf(fid, "- Tuned reference range target [0.94, 1.06] pu: %s\n", passText(tuned.post_tuning_screen.voltage_reference_range_pass));
fprintf(fid, "- Note: %s\n\n", tuned.post_tuning_screen.note);
fprintf(fid, "## SG Initial Rules\n\n");
for i = 1:numel(tuned.sg)
    item = tuned.sg(i);
    fprintf(fid, "- `%s`: Vref %.4f -> %.4f pu, H=%.3f, D=%.3f, AVR Ka=%.3f, governor R=%.3f, PSS K=%.3f\n", ...
        item.id, item.original_vref_pu, item.tuned_vref_pu, item.H, item.D, item.avr_Ka, item.governor_R, item.pss_K);
end
fprintf(fid, "\n## DFIG Initial Rules\n\n");
for i = 1:numel(tuned.dfig)
    item = tuned.dfig(i);
    fprintf(fid, "- `%s`: Vref %.4f -> %.4f pu, Pref=%.3f MW, Qref=%.3f MVAr, PLL Kp=%.3f, PLL Ki=%.3f, current Kp=%.3f, current Ki=%.3f\n", ...
        item.id, item.original_vref_pu, item.tuned_vref_pu, item.p_ref_mw, item.q_ref_mvar, item.pll_Kp, item.pll_Ki, item.current_Kp, item.current_Ki);
end
fprintf(fid, "\n## Limitations\n\n");
fprintf(fid, "- This is rule-based initial tuning for the traceable v0.1 assembly.\n");
fprintf(fid, "- Closed-loop EMT convergence cannot be claimed until the detailed physical network is wired and initialized.\n");
fprintf(fid, "- Next iteration should run `power_loadflow`, short no-disturbance simulation, then automatic parameter update loops.\n");
end

function s = appendStruct(s, item)
if isempty(s)
    s = item;
else
    s(end+1) = item; %#ok<AGROW>
end
end

function ensureDir(path)
if ~isfolder(path)
    mkdir(path);
end
end

function writeJson(path, value)
fid = fopen(path, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s", jsonencode(value, "PrettyPrint", true));
end

function text = passText(value)
if value
    text = "PASS";
else
    text = "FAIL";
end
end

function y = clamp(x, lo, hi)
y = min(max(x, lo), hi);
end
