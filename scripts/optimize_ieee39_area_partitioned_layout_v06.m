function optimize_ieee39_area_partitioned_layout_v06()
%OPTIMIZE_IEEE39_AREA_PARTITIONED_LAYOUT_V06 Clean regional physical layout.
%
% v0.6 starts from v0.5 and focuses on the region subsystem internals:
% - ordinary control/measurement wires inside regions become local Goto/From;
% - physical connection ports are grouped into side racks near their targets;
% - boundary and port labels are hidden where they obscure wiring;
% - physical SPS connection lines remain explicit.
% - long ordinary Simulink signal wires at root become Goto/From tag pairs;
% - physical SPS connections remain explicit wires;
% - regional internals are placed with deterministic one-line coordinates;
% - generic arrangeSystem is avoided after deterministic placement.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(fullfile(projectRoot, "data", "matpower"));

ensureDir(fullfile(projectRoot, "build", "generated_models"));
ensureDir(fullfile(projectRoot, "build", "reports"));

sourceModel = "ieee39_sg5_dfig5_area_partitioned_v05";
sourceFile = fullfile(projectRoot, "build", "generated_models", sourceModel + ".slx");
targetModel = "ieee39_sg5_dfig5_area_partitioned_v06";
targetFile = fullfile(projectRoot, "build", "generated_models", targetModel + ".slx");

if ~isfile(sourceFile)
    optimize_ieee39_area_partitioned_layout_v05();
end
if ~isfile(sourceFile)
    error("Source model not found: %s", sourceFile);
end

safeClose(sourceModel);
safeClose(targetModel);
if isfile(targetFile)
    delete(targetFile);
end

copyfile(sourceFile, targetFile);
load_system(targetFile);
set_param(targetModel, "Location", [30 30 2600 1400]);

mpc = case39();
zones = defineZones();

applyRootLayout(targetModel, zones);
layoutZoneInternals(targetModel, mpc, zones);
signalStats = replaceLongRootSignalsWithGotoFrom(targetModel);
zoneStats = polishRegionalSubsystems(targetModel, zones);
routeRootLines(targetModel);
addV06Annotations(targetModel);

verification = runVerification(targetModel);

save_system(targetModel, targetFile);
exportRootPreview(targetModel, fullfile(projectRoot, "build", "reports", "ieee39_area_partitioned_v06_top.png"));
close_system(targetModel, 0);

writeV06Report(projectRoot, targetFile, signalStats, zoneStats, verification);
fprintf("Generated layout-optimized model: %s\n", targetFile);
fprintf("Layout v0.6 report: %s\n", fullfile(projectRoot, "build", "reports", "area_partition_v06_report.md"));
end

function applyRootLayout(modelName, zones)
setIfBlock(modelName + "/powergui", ...
    "Position", [55 60 185 120], "ShowName", "on", "BackgroundColor", "yellow");

zonePos = containers.Map("KeyType", "char", "ValueType", "any");
zonePos("Zone_NorthWest") = [220 160 650 520];
zonePos("Zone_SouthWest") = [220 705 690 1105];
zonePos("Zone_Central")   = [890 375 1395 875];
zonePos("Zone_NorthEast") = [1660 185 2230 725];

for zi = 1:numel(zones)
    if isempty(zones(zi).buses)
        continue
    end
    path = modelName + "/" + zones(zi).name;
    if ~isBlock(path)
        continue
    end
    setIfBlock(path, ...
        "Position", zonePos(zones(zi).name), ...
        "ShowName", "on", ...
        "BackgroundColor", zones(zi).color, ...
        "AttributesFormatString", sprintf("%s\\nBuses: %s", zones(zi).title, compactBusList(zones(zi).buses)));
    applyNavigationMask(path, zones(zi).title, "local executable detail");
end
end

function layoutZoneInternals(modelName, mpc, zones)
rawXY = canonicalIEEE39Coordinates();
for zi = 1:numel(zones)
    if isempty(zones(zi).buses)
        continue
    end
    scope = modelName + "/" + zones(zi).name;
    if ~isBlock(scope)
        continue
    end

    buses = zones(zi).buses;
    xy = normalizeZoneCoordinates(rawXY, buses);

    for busId = buses
        path = sprintf("%s/bus_%03d_node", scope, busId);
        if isBlock(path)
            pt = xy(busId);
            setIfBlock(path, ...
                "Position", centeredBox(pt(1), pt(2), 48, 58), ...
                "ShowName", "on", ...
                "BackgroundColor", "lightBlue", ...
                "AttributesFormatString", sprintf("Bus %03d", busId));
        end
    end

    for i = 1:size(mpc.branch, 1)
        fromBus = mpc.branch(i, 1);
        toBus = mpc.branch(i, 2);
        if ~ismember(fromBus, buses) || ~ismember(toBus, buses)
            continue
        end
        path = sprintf("%s/branch_%03d_%03d_%02d", scope, fromBus, toBus, i);
        if isBlock(path)
            [pos, orientation] = localBranchPlacement(xy(fromBus), xy(toBus), i);
            setIfBlock(path, ...
                "Position", pos, ...
                "Orientation", orientation, ...
                "ShowName", "off", ...
                "BackgroundColor", "white", ...
                "AttributesFormatString", sprintf("L%d-%d", fromBus, toBus));
        end
    end

    for busId = intersect(buses, [30 31 32 33 34 35 36 37 38 39])
        if ismember(busId, [33 34 35 36 37])
            name = sprintf("dfig_G%d", busId);
            color = "orange";
            sz = [150 92];
        else
            name = sprintf("sg_G%d", busId);
            color = "green";
            sz = [138 88];
        end
        path = scope + "/" + name;
        if isBlock(path)
            pt = xy(busId);
            [x, y, orientation] = localDevicePlacement(busId, pt, sz);
            setIfBlock(path, ...
                "Position", [x y x+sz(1) y+sz(2)], ...
                "Orientation", orientation, ...
                "ShowName", "on", ...
                "BackgroundColor", color, ...
                "AttributesFormatString", sprintf("%s\\nBus %d", name, busId));
        end
    end

    layoutBoundaryPorts(scope);
    routeScopeLines(scope);
end
end

function zoneStats = polishRegionalSubsystems(modelName, zones)
zoneStats = struct("scope", strings(0, 1), "signalLinesConverted", [], "physicalPortsPlaced", []);
for zi = 1:numel(zones)
    if isempty(zones(zi).buses)
        continue
    end
    scope = modelName + "/" + zones(zi).name;
    if ~isBlock(scope)
        continue
    end
    converted = replaceLongLocalSignalsWithGotoFrom(scope, zones(zi).name);
    portsPlaced = placePhysicalPortsNearConnections(scope);
    hideObscuringNames(scope);
    routeScopeLines(scope);

    zoneStats.scope(end+1, 1) = scope; %#ok<AGROW>
    zoneStats.signalLinesConverted(end+1, 1) = converted; %#ok<AGROW>
    zoneStats.physicalPortsPlaced(end+1, 1) = portsPlaced; %#ok<AGROW>
end
end

function converted = replaceLongLocalSignalsWithGotoFrom(scope, zoneName)
converted = 0;
lines = find_system(scope, "FindAll", "on", "SearchDepth", 1, "Type", "line");
lineIndex = 0;

for k = 1:numel(lines)
    lineH = lines(k);
    if ~isLongSignalLine(lineH, 180)
        continue
    end

    try
        srcPort = get_param(lineH, "SrcPortHandle");
        dstPorts = get_param(lineH, "DstPortHandle");
        if isempty(dstPorts) || any(dstPorts == -1)
            continue
        end

        lineIndex = lineIndex + 1;
        tag = makeLocalSignalTag(zoneName, lineH, lineIndex);
        srcXY = get_param(srcPort, "Position");

        gotoPath = scope + "/" + sprintf("goto_%02d_%s", lineIndex, tag);
        add_block("built-in/Goto", gotoPath, ...
            "GotoTag", tag, ...
            "TagVisibility", "local", ...
            "IconDisplay", "Tag", ...
            "ShowName", "off", ...
            "Position", centeredBox(srcXY(1) + 62, srcXY(2), 72, 22));

        delete_line(lineH);
        gotoPorts = get_param(gotoPath, "PortHandles");
        add_line(scope, srcPort, gotoPorts.Inport(1), "autorouting", "on");

        for di = 1:numel(dstPorts)
            dstPort = dstPorts(di);
            dstXY = get_param(dstPort, "Position");
            fromPath = scope + "/" + sprintf("from_%02d_%02d_%s", lineIndex, di, tag);
            add_block("built-in/From", fromPath, ...
                "GotoTag", tag, ...
                "IconDisplay", "Tag", ...
                "ShowName", "off", ...
                "Position", centeredBox(dstXY(1) - 62, dstXY(2), 72, 22));
            fromPorts = get_param(fromPath, "PortHandles");
            add_line(scope, fromPorts.Outport(1), dstPort, "autorouting", "on");
        end
        converted = converted + 1;
    catch
    end
end
end

function tag = makeLocalSignalTag(zoneName, lineH, index)
try
    name = string(get_param(lineH, "Name"));
catch
    name = "";
end
if strlength(name) == 0
    try
        srcPort = get_param(lineH, "SrcPortHandle");
        srcBlock = string(get_param(get_param(srcPort, "Parent"), "Name"));
        name = srcBlock;
    catch
        name = "sig";
    end
end
tag = char("z_" + extractAfter(string(zoneName), "Zone_") + "_" + index + "_" + regexprep(name, "[^A-Za-z0-9_]", "_"));
tag = regexprep(tag, "_+", "_");
tag = regexprep(tag, "^_|_$", "");
if strlength(string(tag)) > 45
    tag = char(extractBefore(string(tag), 46));
end
end

function portsPlaced = placePhysicalPortsNearConnections(scope)
portsPlaced = 0;
ports = find_system(scope, "SearchDepth", 1, "BlockType", "PMIOPort");
if isempty(ports)
    return
end

targets = struct("path", {}, "xy", {}, "side", {});
for i = 1:numel(ports)
    [ok, xy] = connectedTargetPosition(ports{i});
    if ok
        side = "left";
        if xy(1) > 430
            side = "right";
        end
    else
        pos = get_param(ports{i}, "Position");
        xy = [(pos(1)+pos(3))/2, (pos(2)+pos(4))/2];
        side = "left";
        if xy(1) > 430 || mod(i, 2) == 0
            side = "right";
        end
    end
    targets(end+1).path = ports{i}; %#ok<AGROW>
    targets(end).xy = xy;
    targets(end).side = side;
end

portsPlaced = numel(targets);
placePortRack(targets, "left", 45);
placePortRack(targets, "right", 870);
end

function placePortRack(targets, side, x)
idx = find(arrayfun(@(t) t.side == side, targets));
if isempty(idx)
    return
end
[~, order] = sort(arrayfun(@(t) t.xy(2), targets(idx)));
idx = idx(order);
lastY = -Inf;
for ii = 1:numel(idx)
    t = targets(idx(ii));
    y = max(70, min(610, round(t.xy(2))));
    if y < lastY + 30
        y = lastY + 30;
    end
    lastY = y;
    try
        set_param(t.path, "Position", [x y x+32 y+18], "ShowName", "off");
        if side == "left"
            set_param(t.path, "Orientation", "right");
            safeSet(t.path, "PortLocation", "Left");
        else
            set_param(t.path, "Orientation", "left");
            safeSet(t.path, "PortLocation", "Right");
        end
    catch
    end
end
end

function [ok, xy] = connectedTargetPosition(portPath)
ok = false;
xy = [0 0];
try
    lh = get_param(portPath, "LineHandles");
    lineHandles = [lh.Inport(:); lh.Outport(:); lh.LConn(:); lh.RConn(:)];
    lineHandles = lineHandles(lineHandles ~= -1);
catch
    lineHandles = [];
end

for li = 1:numel(lineHandles)
    try
        src = get_param(lineHandles(li), "SrcPortHandle");
        dst = get_param(lineHandles(li), "DstPortHandle");
        candidates = [src; dst(:)];
        for ci = 1:numel(candidates)
            if candidates(ci) == -1
                continue
            end
            parent = string(get_param(candidates(ci), "Parent"));
            if parent ~= string(portPath)
                xy = get_param(candidates(ci), "Position");
                ok = true;
                return
            end
        end
    catch
    end
end
end

function hideObscuringNames(scope)
blocks = find_system(scope, "SearchDepth", 1, "Type", "block");
for i = 1:numel(blocks)
    try
        bt = string(get_param(blocks{i}, "BlockType"));
        if ismember(bt, ["PMIOPort", "Inport", "Outport", "Goto", "From"])
            set_param(blocks{i}, "ShowName", "off");
        end
    catch
    end
end
end

function stats = replaceLongRootSignalsWithGotoFrom(modelName)
stats = struct("converted", 0, "destinations", 0, "skipped", 0, "tags", strings(0, 1));
lines = find_system(modelName, "FindAll", "on", "SearchDepth", 1, "Type", "line");
lineIndex = 0;

for k = 1:numel(lines)
    lineH = lines(k);
    if ~isLongSignalLine(lineH, 420)
        continue
    end

    try
        srcPort = get_param(lineH, "SrcPortHandle");
        dstPorts = get_param(lineH, "DstPortHandle");
        if isempty(dstPorts) || any(dstPorts == -1)
            stats.skipped = stats.skipped + 1;
            continue
        end
        lineIndex = lineIndex + 1;
        tag = makeSignalTag(lineH, lineIndex);
        srcXY = get_param(srcPort, "Position");
        dstXY = mean(cell2mat(arrayfun(@(p) get_param(p, "Position"), dstPorts(:), "UniformOutput", false)), 1);
        xDirection = sign(dstXY(1) - srcXY(1));
        if xDirection == 0
            xDirection = 1;
        end

        gotoPath = modelName + "/" + sprintf("sig_goto_%02d_%s", lineIndex, tag);
        add_block("built-in/Goto", gotoPath, ...
            "GotoTag", tag, ...
            "TagVisibility", "global", ...
            "ShowName", "off", ...
            "Position", centeredBox(srcXY(1) + 58 * xDirection, srcXY(2), 82, 22));

        delete_line(lineH);
        gotoPorts = get_param(gotoPath, "PortHandles");
        add_line(modelName, srcPort, gotoPorts.Inport(1), "autorouting", "on");

        for di = 1:numel(dstPorts)
            dstPort = dstPorts(di);
            dstPos = get_param(dstPort, "Position");
            fromPath = modelName + "/" + sprintf("sig_from_%02d_%02d_%s", lineIndex, di, tag);
            add_block("built-in/From", fromPath, ...
                "GotoTag", tag, ...
                "ShowName", "off", ...
                "Position", centeredBox(dstPos(1) - 58 * xDirection, dstPos(2), 82, 22));
            fromPorts = get_param(fromPath, "PortHandles");
            add_line(modelName, fromPorts.Outport(1), dstPort, "autorouting", "on");
            stats.destinations = stats.destinations + 1;
        end

        stats.converted = stats.converted + 1;
        stats.tags(end+1, 1) = string(tag); %#ok<AGROW>
    catch
        stats.skipped = stats.skipped + 1;
    end
end
end

function tf = isLongSignalLine(lineH, minSpan)
tf = false;
try
    srcPort = get_param(lineH, "SrcPortHandle");
    dstPorts = get_param(lineH, "DstPortHandle");
    if srcPort == -1 || isempty(dstPorts) || any(dstPorts == -1)
        return
    end
    if string(get_param(srcPort, "PortType")) ~= "outport"
        return
    end
    for i = 1:numel(dstPorts)
        if string(get_param(dstPorts(i), "PortType")) ~= "inport"
            return
        end
    end
    points = double(get_param(lineH, "Points"));
    if isempty(points)
        return
    end
    span = (max(points(:, 1)) - min(points(:, 1))) + (max(points(:, 2)) - min(points(:, 2)));
    tf = span >= minSpan;
catch
end
end

function tag = makeSignalTag(lineH, index)
try
    name = string(get_param(lineH, "Name"));
catch
    name = "";
end
if strlength(name) == 0
    try
        srcPort = get_param(lineH, "SrcPortHandle");
        srcBlock = string(get_param(get_param(srcPort, "Parent"), "Name"));
        name = "root_sig_" + srcBlock;
    catch
        name = "root_sig";
    end
end
tag = char("v06_" + index + "_" + regexprep(name, "[^A-Za-z0-9_]", "_"));
tag = regexprep(tag, "_+", "_");
tag = regexprep(tag, "^_|_$", "");
if strlength(string(tag)) > 42
    tag = char(extractBefore(string(tag), 43));
end
end

function layoutBoundaryPorts(scope)
layoutPortList(find_system(scope, "SearchDepth", 1, "BlockType", "Inport"), 35, 80, 32, "right");
layoutPortList(find_system(scope, "SearchDepth", 1, "BlockType", "Outport"), 780, 80, 32, "right");

pmio = find_system(scope, "SearchDepth", 1, "BlockType", "PMIOPort");
left = {};
right = {};
for i = 1:numel(pmio)
    try
        pos = get_param(pmio{i}, "Position");
        if mean(pos([1 3])) < 380
            left{end+1} = pmio{i}; %#ok<AGROW>
        else
            right{end+1} = pmio{i}; %#ok<AGROW>
        end
    catch
        left{end+1} = pmio{i}; %#ok<AGROW>
    end
end
layoutPortList(left, 35, 210, 25, "right");
layoutPortList(right, 780, 210, 25, "left");
end

function layoutPortList(paths, x, y0, dy, orientation)
for i = 1:numel(paths)
    try
        y = y0 + (i - 1) * dy;
        set_param(paths{i}, ...
            "Position", [x y x+28 y+16], ...
            "Orientation", orientation, ...
            "ShowName", "off");
    catch
    end
end
end

function routeRootLines(modelName)
routeScopeLines(modelName);
end

function routeScopeLines(scope)
try
    lines = find_system(scope, "FindAll", "on", "SearchDepth", 1, "Type", "line");
    for k = 1:numel(lines)
        try
            Simulink.BlockDiagram.routeLine(lines(k));
        catch
        end
    end
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

function exportRootPreview(modelName, outFile)
try
    open_system(modelName);
    set_param(modelName, "ZoomFactor", "FitSystem");
    print("-s" + modelName, "-dpng", "-r150", outFile);
catch
end
end

function addV06Annotations(modelName)
try
    ann = Simulink.Annotation(modelName, "IEEE39 area-partitioned executable physical model v0.6");
    ann.Position = [55 24 690 54];
    ann.FontSize = 15;
    ann.FontWeight = "bold";
catch
end
try
    ann = Simulink.Annotation(modelName, "Regional internals use local signal tags and grouped physical port racks. SPS tie-lines remain explicit.");
    ann.Position = [55 1185 960 1215];
    ann.FontSize = 10;
catch
end
end

function writeV06Report(projectRoot, modelFile, signalStats, zoneStats, verification)
reportFile = fullfile(projectRoot, "build", "reports", "area_partition_v06_report.md");
fid = fopen(reportFile, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# IEEE39 Area-Partitioned v0.6 Layout Report\n\n");
fprintf(fid, "Model: `%s`\n\n", modelFile);
fprintf(fid, "## Optimization Strategy\n\n");
fprintf(fid, "- Starts from the executable v0.5 area-partitioned model.\n");
fprintf(fid, "- Keeps physical SPS cross-area tie-lines as explicit physical connections.\n");
fprintf(fid, "- Converts long ordinary Simulink control/measurement lines to local Goto/From tag pairs.\n");
fprintf(fid, "- Groups physical Connection Port blocks into side racks near connected electrical targets.\n");
fprintf(fid, "- Re-applies deterministic one-line coordinates inside regional subsystems.\n");
fprintf(fid, "- Avoids generic `arrangeSystem` after deterministic physical layout placement.\n\n");
fprintf(fid, "## Root Signal Tagging\n\n");
fprintf(fid, "- Converted long root signal lines: %d\n", signalStats.converted);
fprintf(fid, "- Reconnected destinations through From blocks: %d\n", signalStats.destinations);
fprintf(fid, "- Skipped candidate lines: %d\n", signalStats.skipped);
if ~isempty(signalStats.tags)
    fprintf(fid, "- Tags: `%s`\n", strjoin(signalStats.tags', "`, `"));
end
fprintf(fid, "\n## Regional Polishing\n\n");
for i = 1:numel(zoneStats.scope)
    fprintf(fid, "- `%s`: local signal lines tagged `%d`, physical ports placed `%d`\n", ...
        zoneStats.scope(i), zoneStats.signalLinesConverted(i), zoneStats.physicalPortsPlaced(i));
end
fprintf(fid, "\n## Verification\n\n");
fprintf(fid, "- `SimulationCommand update`: %s\n", verification.compile);
fprintf(fid, "- `sim()` smoke run to `0.005 s`: %s\n", verification.smoke);
if strlength(string(verification.message)) > 0
    fprintf(fid, "- Message: `%s`\n", verification.message);
end
fprintf(fid, "- Preview image: `build/reports/ieee39_area_partitioned_v06_top.png`\n");
end

function zones = defineZones()
zones = struct("name", {}, "title", {}, "buses", {}, "color", {});
zones(1) = struct("name", "Zone_NorthWest", "title", "North-West", "buses", [1 2 3 25 30 37 39], "color", "lightBlue");
zones(2) = struct("name", "Zone_SouthWest", "title", "South-West", "buses", [4 5 6 7 8 9 11 31], "color", "cyan");
zones(3) = struct("name", "Zone_Central", "title", "Central Corridor", "buses", [10 12 13 14 15 16 17 18 19 20 32 33 34], "color", "lightBlue");
zones(4) = struct("name", "Zone_NorthEast", "title", "North-East", "buses", [21 22 23 24 26 27 28 29 35 36 38], "color", "cyan");
end

function xyMap = normalizeZoneCoordinates(raw, buses)
idx = ismember(raw(:, 1), buses);
sub = raw(idx, :);
x = normalizeToRange(sub(:, 2), 145, 650);
y = normalizeToRange(sub(:, 3), 115, 465);
xyMap = containers.Map("KeyType", "double", "ValueType", "any");
for i = 1:size(sub, 1)
    xyMap(sub(i, 1)) = [x(i), y(i)];
end
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

function [pos, orientation] = localBranchPlacement(a, b, index)
v = b - a;
offset = branchOffset(a, b, index, 12);
minLength = 92;
thick = 34;
if abs(v(1)) >= 1.15 * abs(v(2))
    orientation = "right";
    y = (a(2) + b(2)) / 2 + offset(2);
    x1 = min(a(1), b(1)) + 38;
    x2 = max(a(1), b(1)) - 38;
    if x2 - x1 < minLength
        pos = centeredBox((a(1)+b(1))/2 + offset(1), y, minLength, thick);
    else
        pos = round([x1 y-thick/2 x2 y+thick/2]);
    end
elseif abs(v(2)) >= 1.15 * abs(v(1))
    orientation = "down";
    x = (a(1) + b(1)) / 2 + offset(1);
    y1 = min(a(2), b(2)) + 38;
    y2 = max(a(2), b(2)) - 38;
    if y2 - y1 < minLength
        pos = centeredBox(x, (a(2)+b(2))/2 + offset(2), thick, minLength);
    else
        pos = round([x-thick/2 y1 x+thick/2 y2]);
    end
else
    mid = (a + b) / 2 + offset;
    orientation = "right";
    pos = centeredBox(mid(1), mid(2), minLength, thick);
end
end

function offset = branchOffset(a, b, index, scale)
v = b - a;
if norm(v) == 0
    offset = [0 0];
    return
end
n = [-v(2), v(1)] / norm(v);
offset = n * scale * (mod(index, 3) - 1);
end

function [x, y, orientation] = localDevicePlacement(busId, xy, sz)
orientation = "right";
switch busId
    case {30, 37}
        x = xy(1) - sz(1)/2;
        y = xy(2) - 120;
    case {31, 32, 33, 34, 35}
        x = xy(1) - sz(1)/2;
        y = xy(2) + 82;
    case {36}
        x = xy(1) + 65;
        y = xy(2) - sz(2)/2;
    case {38}
        x = xy(1) + 58;
        y = xy(2) + 42;
    case {39}
        x = xy(1) - sz(1) - 58;
        y = xy(2) - sz(2)/2;
    otherwise
        x = xy(1) - sz(1)/2;
        y = xy(2) + 82;
end
x = round(x);
y = round(y);
end

function pos = centeredBox(cx, cy, w, h)
pos = round([cx-w/2, cy-h/2, cx+w/2, cy+h/2]);
end

function setIfBlock(path, varargin)
try
    set_param(path, varargin{:});
catch
end
end

function safeSet(path, paramName, value)
try
    set_param(path, paramName, value);
catch
end
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

function text = compactBusList(buses)
text = strjoin(string(buses), ",");
end

function tf = isBlock(path)
try
    get_param(path, "Handle");
    tf = true;
catch
    tf = false;
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
