function build_ieee39_sg5_dfig5_layout_optimized_v06()
%BUILD_IEEE39_SG5_DFIG5_LAYOUT_OPTIMIZED_V06 Build readable v0.6 wrapper.
%
% The executable area-partitioned physical model is preserved as a detail
% subsystem. The root level becomes a clean review/navigation canvas.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(fullfile(projectRoot, "data", "matpower"));

ensureDir(fullfile(projectRoot, "build", "generated_models"));
ensureDir(fullfile(projectRoot, "build", "reports"));

sourceModel = "ieee39_sg5_dfig5_area_partitioned_v06";
sourceFile = fullfile(projectRoot, "build", "generated_models", sourceModel + ".slx");
targetModel = "ieee39_sg5_dfig5_layout_optimized_v06";
targetFile = fullfile(projectRoot, "build", "generated_models", targetModel + ".slx");

if ~isfile(sourceFile)
    optimize_ieee39_area_partitioned_layout_v06();
end
if ~isfile(sourceFile)
    error("Source model not found: %s", sourceFile);
end

safeClose(sourceModel);
safeClose(targetModel);
if isfile(targetFile)
    delete(targetFile);
end

load_system(sourceFile);
new_system(targetModel);
open_system(targetModel);
set_param(targetModel, ...
    "SolverType", get_param(sourceModel, "SolverType"), ...
    "Solver", get_param(sourceModel, "Solver"), ...
    "FixedStep", get_param(sourceModel, "FixedStep"), ...
    "StopTime", get_param(sourceModel, "StopTime"), ...
    "PreLoadFcn", "Ts=50e-6;", ...
    "InitFcn", "Ts=50e-6; if ~exist('xInitial','var'), xInitial=[]; end", ...
    "Location", [35 35 1800 1020]);

overviewPath = targetModel + "/Topology_Overview";
detailPath = targetModel + "/Area_Partitioned_Physical_Detail";
regionalPath = targetModel + "/Regional_Overviews";
rulesPath = targetModel + "/Layout_Routing_Rules";
reportsPath = targetModel + "/Reports_Trace";

add_block("built-in/Subsystem", overviewPath, "Position", [65 75 925 610]);
Simulink.SubSystem.deleteContents(overviewPath);
buildTopologyOverview(overviewPath, case39());
set_param(overviewPath, "BackgroundColor", "white", "ShowName", "on");
set_param(overviewPath, "AttributesFormatString", "Readable IEEE39 one-line overview");
applyNavigationMask(overviewPath, "Topology Overview", "review one-line");

add_block("built-in/Subsystem", detailPath, "Position", [1010 95 1515 380]);
Simulink.SubSystem.deleteContents(detailPath);
Simulink.BlockDiagram.copyContentsToSubsystem(sourceModel, detailPath);
set_param(detailPath, "BackgroundColor", "lightBlue", "ShowName", "on");
set_param(detailPath, "AttributesFormatString", "Executable physical detail\\narea-partitioned v0.6");
applyNavigationMask(detailPath, "Area Physical Detail", "open executable model");

add_block("built-in/Subsystem", regionalPath, "Position", [1010 430 1515 610]);
Simulink.SubSystem.deleteContents(regionalPath);
buildRegionalOverviews(regionalPath, case39(), defineZones());
set_param(regionalPath, "BackgroundColor", "white", "ShowName", "on");
set_param(regionalPath, "AttributesFormatString", "Readable regional one-line views");
applyNavigationMask(regionalPath, "Regional Overviews", "open clean regional diagrams");

add_block("built-in/Subsystem", rulesPath, "Position", [1010 665 1515 815]);
Simulink.SubSystem.deleteContents(rulesPath);
addLayoutRuleAnnotations(rulesPath);
set_param(rulesPath, "BackgroundColor", "yellow", "ShowName", "on");
set_param(rulesPath, "AttributesFormatString", "Routing rules\\nGoto/From policy");
applyNavigationMask(rulesPath, "Layout Rules", "routing policy");

add_block("built-in/Subsystem", reportsPath, "Position", [1010 850 1515 980]);
Simulink.SubSystem.deleteContents(reportsPath);
addReportAnnotations(reportsPath);
set_param(reportsPath, "BackgroundColor", "gray", "ShowName", "on");
set_param(reportsPath, "AttributesFormatString", "Reports, specs, trace links");
applyNavigationMask(reportsPath, "Reports and Trace", "generated artifacts");

addRootAnnotations(targetModel);
verification = runVerification(targetModel);

save_system(targetModel, targetFile);
exportPreview(targetModel, fullfile(projectRoot, "build", "reports", "ieee39_layout_optimized_v06_top.png"));
exportPreview(overviewPath, fullfile(projectRoot, "build", "reports", "ieee39_layout_optimized_v06_overview.png"));
exportPreview(regionalPath + "/Zone_Central_Overview", fullfile(projectRoot, "build", "reports", "ieee39_layout_optimized_v06_zone_central.png"));
close_system(targetModel, 0);
close_system(sourceModel, 0);

writeLayoutOptimizedReport(projectRoot, targetFile, verification);
fprintf("Generated layout-optimized wrapper model: %s\n", targetFile);
fprintf("Layout optimized report: %s\n", fullfile(projectRoot, "build", "reports", "layout_optimized_v06_report.md"));
end

function buildTopologyOverview(scope, mpc)
busXY = computeBusLayout(mpc);

for i = 1:size(mpc.branch, 1)
    fromBus = mpc.branch(i, 1);
    toBus = mpc.branch(i, 2);
    [pos, orientation] = overviewBranchPlacement(busXY(fromBus), busXY(toBus), i);
    path = scope + "/" + sprintf("L%03d_%03d_%02d", fromBus, toBus, i);
    add_block("built-in/Subsystem", path, ...
        "Position", pos, ...
        "Orientation", orientation, ...
        "BackgroundColor", "white", ...
        "ShowName", "off");
    Simulink.SubSystem.deleteContents(path);
end

for i = 1:size(mpc.bus, 1)
    busId = mpc.bus(i, 1);
    xy = busXY(busId);
    path = sprintf("%s/B%03d", scope, busId);
    add_block("built-in/Subsystem", path, ...
        "Position", centeredBox(xy(1), xy(2), 24, 38), ...
        "BackgroundColor", "lightBlue", ...
        "ShowName", "off");
    Simulink.SubSystem.deleteContents(path);
    set_param(path, "AttributesFormatString", sprintf("%d", busId));
end

for busId = [30 31 32 33 34 35 36 37 38 39]
    xy = busXY(busId);
    if ismember(busId, [33 34 35 36 37])
        name = sprintf("DFIG_%d", busId);
        label = sprintf("W%d", busId);
        color = "orange";
    else
        name = sprintf("SG_%d", busId);
        label = sprintf("G%d", busId);
        color = "green";
    end
    [x, y] = overviewDevicePosition(busId, xy);
    path = scope + "/" + name;
    add_block("built-in/Subsystem", path, ...
        "Position", [x y x+58 y+30], ...
        "BackgroundColor", color, ...
        "ShowName", "off");
    Simulink.SubSystem.deleteContents(path);
    set_param(path, "AttributesFormatString", label);
end

try
    ann = Simulink.Annotation(scope, "IEEE39 / New England topology overview");
    ann.Position = [35 25 390 55];
    ann.FontSize = 14;
    ann.FontWeight = "bold";
catch
end
try
    ann = Simulink.Annotation(scope, "Blue: busbar   White: branch   Green: SG   Orange: DFIG   Open physical detail for executable SPS wiring");
    ann.Position = [35 58 760 88];
    ann.FontSize = 10;
catch
end
end

function buildRegionalOverviews(scope, mpc, zones)
positions = {
    [35 60 465 350]
    [35 400 465 700]
    [535 60 1035 405]
    [535 455 1035 760]
};
for zi = 1:numel(zones)
    zonePath = scope + "/" + zones(zi).name + "_Overview";
    add_block("built-in/Subsystem", zonePath, ...
        "Position", positions{zi}, ...
        "BackgroundColor", zones(zi).color, ...
        "ShowName", "on");
    Simulink.SubSystem.deleteContents(zonePath);
    buildZoneOverview(zonePath, mpc, zones(zi));
    set_param(zonePath, "AttributesFormatString", zones(zi).title + "\\nclean one-line");
    applyNavigationMask(zonePath, zones(zi).title, "clean regional one-line");
end

try
    ann = Simulink.Annotation(scope, "Regional one-line overviews");
    ann.Position = [35 20 400 50];
    ann.FontSize = 14;
    ann.FontWeight = "bold";
catch
end
try
    ann = Simulink.Annotation(scope, "These views are for inspection. Open Area_Partitioned_Physical_Detail for executable SPS wiring.");
    ann.Position = [35 800 820 830];
    ann.FontSize = 10;
catch
end
end

function buildZoneOverview(scope, mpc, zone)
busXY = computeZoneBusLayout(zone.buses);

for i = 1:size(mpc.branch, 1)
    fromBus = mpc.branch(i, 1);
    toBus = mpc.branch(i, 2);
    if ~isKey(busXY, fromBus) || ~isKey(busXY, toBus)
        continue
    end
    [pos, orientation] = overviewBranchPlacement(busXY(fromBus), busXY(toBus), i);
    path = scope + "/" + sprintf("L%03d_%03d_%02d", fromBus, toBus, i);
    add_block("built-in/Subsystem", path, ...
        "Position", pos, ...
        "Orientation", orientation, ...
        "BackgroundColor", "white", ...
        "ShowName", "off");
    Simulink.SubSystem.deleteContents(path);
    set_param(path, "AttributesFormatString", "");
end

for busId = zone.buses
    xy = busXY(busId);
    path = sprintf("%s/B%03d", scope, busId);
    add_block("built-in/Subsystem", path, ...
        "Position", centeredBox(xy(1), xy(2), 26, 40), ...
        "BackgroundColor", "lightBlue", ...
        "ShowName", "off");
    Simulink.SubSystem.deleteContents(path);
    set_param(path, "AttributesFormatString", sprintf("%d", busId));
end

for busId = intersect(zone.buses, [30 31 32 33 34 35 36 37 38 39])
    xy = busXY(busId);
    if ismember(busId, [33 34 35 36 37])
        label = sprintf("W%d", busId);
        color = "orange";
    else
        label = sprintf("G%d", busId);
        color = "green";
    end
    [x, y] = zoneDevicePosition(busId, xy);
    path = scope + "/" + label;
    add_block("built-in/Subsystem", path, ...
        "Position", [x y x+62 y+30], ...
        "BackgroundColor", color, ...
        "ShowName", "off");
    Simulink.SubSystem.deleteContents(path);
    set_param(path, "AttributesFormatString", label);
end

try
    ann = Simulink.Annotation(scope, zone.title + " one-line");
    ann.Position = [25 20 330 50];
    ann.FontSize = 12;
    ann.FontWeight = "bold";
catch
end
end

function addLayoutRuleAnnotations(scope)
try
    ann = Simulink.Annotation(scope, "Routing policy");
    ann.Position = [35 30 260 60];
    ann.FontWeight = "bold";
catch
end
try
    ann = Simulink.Annotation(scope, sprintf([ ...
        "Physical SPS connections stay explicit.\n" ...
        "Goto/From is allowed only for ordinary measurement/control signals.\n" ...
        "Do not run full arrangeSystem after deterministic one-line placement.\n" ...
        "Use local routeLine and subsystem boundaries for physical detail."]));
    ann.Position = [35 78 455 165];
catch
end
end

function addReportAnnotations(scope)
try
    ann = Simulink.Annotation(scope, "Primary artifacts");
    ann.Position = [35 30 260 60];
    ann.FontWeight = "bold";
catch
end
try
    ann = Simulink.Annotation(scope, sprintf([ ...
        "Physical detail: build/generated_models/ieee39_sg5_dfig5_area_partitioned_v06.slx\n" ...
        "Layout report: build/reports/layout_optimized_v06_report.md\n" ...
        "Area report: build/reports/area_partition_v06_report.md\n" ...
        "Workflow: docs/MODELING_WORKFLOW_DRAFT.md"]));
    ann.Position = [35 78 470 145];
catch
end
end

function addRootAnnotations(modelName)
try
    ann = Simulink.Annotation(modelName, "IEEE39 SG/DFIG layout-optimized model v0.6");
    ann.Position = [65 25 590 55];
    ann.FontSize = 15;
    ann.FontWeight = "bold";
catch
end
try
    ann = Simulink.Annotation(modelName, "Top level is for review/navigation. The executable area-partitioned SPS network is in Area_Partitioned_Physical_Detail.");
    ann.Position = [65 865 1180 895];
    ann.FontSize = 10;
catch
end
end

function verification = runVerification(modelName)
verification = struct("compile", "FAIL", "smoke", "FAIL", "message", "");
try
    set_param(modelName, "SimulationCommand", "update");
    verification.compile = "PASS";
catch ME
    verification.message = "Compile: " + string(ME.message);
    return
end

try
    sim(modelName, "StopTime", "0.005");
    verification.smoke = "PASS";
catch ME
    verification.message = "Smoke: " + string(ME.message);
end
end

function busXY = computeBusLayout(mpc)
raw = canonicalIEEE39Coordinates();
x = normalizeToRange(raw(:, 2), 120, 760);
y = normalizeToRange(raw(:, 3), 170, 520);
busXY = containers.Map("KeyType", "double", "ValueType", "any");
for i = 1:size(raw, 1)
    busXY(raw(i, 1)) = [x(i), y(i)];
end
end

function busXY = computeZoneBusLayout(buses)
raw = canonicalIEEE39Coordinates();
idx = ismember(raw(:, 1), buses);
sub = raw(idx, :);
x = normalizeToRange(sub(:, 2), 90, 360);
y = normalizeToRange(sub(:, 3), 95, 250);
busXY = containers.Map("KeyType", "double", "ValueType", "any");
for i = 1:size(sub, 1)
    busXY(sub(i, 1)) = [x(i), y(i)];
end
end

function [x, y] = zoneDevicePosition(busId, xy)
switch busId
    case {30, 37}
        x = xy(1) - 31;
        y = xy(2) - 54;
    case {31, 32}
        x = xy(1) - 31;
        y = xy(2) + 44;
    case {33}
        x = xy(1) + 42;
        y = xy(2) + 34;
    case {34}
        x = xy(1) - 98;
        y = xy(2) + 34;
    case {35}
        x = xy(1) - 8;
        y = xy(2) + 44;
    case {36}
        x = xy(1) + 42;
        y = xy(2) - 16;
    case {38}
        x = xy(1) + 34;
        y = xy(2) + 24;
    case {39}
        x = xy(1) - 86;
        y = xy(2) - 15;
    otherwise
        x = xy(1) - 31;
        y = xy(2) + 44;
end
x = round(x);
y = round(y);
end

function zones = defineZones()
zones = struct("name", {}, "title", {}, "buses", {}, "color", {});
zones(1) = struct("name", "Zone_NorthWest", "title", "North-West", "buses", [1 2 3 25 30 37 39], "color", "lightBlue");
zones(2) = struct("name", "Zone_SouthWest", "title", "South-West", "buses", [4 5 6 7 8 9 11 31], "color", "cyan");
zones(3) = struct("name", "Zone_Central", "title", "Central Corridor", "buses", [10 12 13 14 15 16 17 18 19 20 32 33 34], "color", "lightBlue");
zones(4) = struct("name", "Zone_NorthEast", "title", "North-East", "buses", [21 22 23 24 26 27 28 29 35 36 38], "color", "cyan");
end

function raw = canonicalIEEE39Coordinates()
raw = [
    1   90  220
    2  145  150
    3  200  220
    4  200  365
    5  170  465
    6  270  500
    7  190  570
    8  100  650
    9   75  520
   10  410  610
   11  320  570
   12  390  545
   13  450  515
   14  485  400
   15  535  310
   16  615  330
   17  615  250
   18  405  245
   19  610  525
   20  575  615
   21  750  340
   22  760  590
   23  700  500
   24  650  425
   25  275  105
   26  585  100
   27  610  175
   28  725  105
   29  810  105
   30  100   45
   31  290  655
   32  405  665
   33  620  665
   34  560  665
   35  760  665
   36  700  425
   37  225   45
   38  790  240
   39   60  280
];
end

function values = normalizeToRange(values, lo, hi)
if max(values) == min(values)
    values = values * 0 + (lo + hi) / 2;
else
    values = lo + (values - min(values)) ./ (max(values) - min(values)) * (hi - lo);
end
end

function [pos, orientation] = overviewBranchPlacement(a, b, index)
v = b - a;
offset = branchOffset(a, b, index);
minLength = 34;
thick = 12;
if abs(v(1)) >= 1.15 * abs(v(2))
    orientation = "right";
    y = (a(2) + b(2)) / 2 + offset(2);
    x1 = min(a(1), b(1)) + 26;
    x2 = max(a(1), b(1)) - 26;
    if x2 - x1 < minLength
        pos = centeredBox((a(1)+b(1))/2 + offset(1), y, minLength, thick);
    else
        pos = round([x1 y-thick/2 x2 y+thick/2]);
    end
elseif abs(v(2)) >= 1.15 * abs(v(1))
    orientation = "down";
    x = (a(1) + b(1)) / 2 + offset(1);
    y1 = min(a(2), b(2)) + 26;
    y2 = max(a(2), b(2)) - 26;
    if y2 - y1 < minLength
        pos = centeredBox(x, (a(2)+b(2))/2 + offset(2), thick, minLength);
    else
        pos = round([x-thick/2 y1 x+thick/2 y2]);
    end
else
    orientation = "right";
    mid = (a + b) / 2 + offset;
    pos = centeredBox(mid(1), mid(2), max(minLength, abs(v(1))*0.45), thick);
end
end

function offset = branchOffset(a, b, index)
v = b - a;
if norm(v) == 0
    offset = [0 0];
    return
end
n = [-v(2), v(1)] / norm(v);
offset = n * 8 * (mod(index, 3) - 1);
end

function [x, y] = overviewDevicePosition(busId, xy)
switch busId
    case {30, 37}
        x = xy(1) - 34;
        y = xy(2) - 58;
    case {31, 32}
        x = xy(1) - 34;
        y = xy(2) + 42;
    case {33}
        x = xy(1) + 28;
        y = xy(2) + 58;
    case {34}
        x = xy(1) - 104;
        y = xy(2) + 58;
    case {35}
        x = xy(1) - 10;
        y = xy(2) + 58;
    case {36}
        x = xy(1) + 58;
        y = xy(2) + 34;
    case {38}
        x = xy(1) + 26;
        y = xy(2) + 28;
    case {39}
        x = xy(1) - 78;
        y = xy(2) - 18;
    otherwise
        x = xy(1) - 45;
        y = xy(2) + 58;
end
x = round(x);
y = round(y);
end

function pos = centeredBox(cx, cy, w, h)
pos = round([cx-w/2, cy-h/2, cx+w/2, cy+h/2]);
end

function exportPreview(scope, outFile)
try
    open_system(scope);
    set_param(scope, "ZoomFactor", "FitSystem");
    print("-s" + scope, "-dpng", "-r150", outFile);
catch
end
end

function writeLayoutOptimizedReport(projectRoot, modelFile, verification)
reportFile = fullfile(projectRoot, "build", "reports", "layout_optimized_v06_report.md");
fid = fopen(reportFile, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# IEEE39 Layout-Optimized v0.6 Report\n\n");
fprintf(fid, "Model: `%s`\n\n", modelFile);
fprintf(fid, "## Structure\n\n");
fprintf(fid, "- `Topology_Overview`: clean IEEE39 one-line review view.\n");
fprintf(fid, "- `Area_Partitioned_Physical_Detail`: executable v0.6 area-partitioned SPS network.\n");
fprintf(fid, "- `Regional_Overviews`: clean regional one-line views for opening submodules without wire clutter.\n");
fprintf(fid, "- `Layout_Routing_Rules`: local routing and Goto/From policy summary.\n");
fprintf(fid, "- `Reports_Trace`: links to generated reports, trace, and workflow docs.\n\n");
fprintf(fid, "## Layout Decision\n\n");
fprintf(fid, "- Root physical area partitioning is useful for executable inspection but too dense as the primary review canvas.\n");
fprintf(fid, "- v0.6 keeps the root and regional submodules as navigation/review layers and keeps executable physical wiring in the physical detail layer.\n");
fprintf(fid, "- Root-level physical connections in the detail model remain explicit; no physical tie-line is replaced by Goto/From.\n\n");
fprintf(fid, "## Verification\n\n");
fprintf(fid, "- `SimulationCommand update`: %s\n", verification.compile);
fprintf(fid, "- `sim()` smoke run to `0.005 s`: %s\n", verification.smoke);
if strlength(string(verification.message)) > 0
    fprintf(fid, "- Message: `%s`\n", verification.message);
end
fprintf(fid, "- Preview images:\n");
fprintf(fid, "  - `build/reports/ieee39_layout_optimized_v06_top.png`\n");
fprintf(fid, "  - `build/reports/ieee39_layout_optimized_v06_overview.png`\n");
fprintf(fid, "  - `build/reports/ieee39_layout_optimized_v06_zone_central.png`\n");
end

function applyNavigationMask(path, titleText, detailText)
try
    set_param(path, ...
        "Mask", "on", ...
        "MaskIconOpaque", "off", ...
        "MaskDisplay", sprintf("disp('%s\\n%s')", titleText, detailText));
catch
end
end

function ensureDir(path)
if ~isfolder(path)
    mkdir(path);
end
end

function safeClose(modelName)
try
    if bdIsLoaded(modelName)
        set_param(modelName, "Dirty", "off");
        close_system(modelName, 0);
    end
catch
end
end
