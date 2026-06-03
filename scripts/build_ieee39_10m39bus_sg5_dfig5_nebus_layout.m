function build_ieee39_10m39bus_sg5_dfig5_nebus_layout()
%BUILD_IEEE39_10M39BUS_SG5_DFIG5_NEBUS_LAYOUT Rebuild clean NEBUS-style model.
%
% The model starts from NEBUS39V2, preserves the standard 39-bus network
% layout, and replaces five synchronous-generator subsystems with DFIG
% blocks from power_wind_dfig_avg. It intentionally avoids extra review or
% audit subsystems on the root canvas.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
generatedDir = fullfile(projectRoot, "build", "generated_models");
reportDir = fullfile(projectRoot, "build", "reports");
ensureDir(generatedDir);
ensureDir(reportDir);

sourceModel = "NEBUS39V2";
dfigSourceModel = "power_wind_dfig_avg";
targetModel = "ieee39_10m39bus_sg5_dfig5_nebus_layout";
targetFile = fullfile(generatedDir, targetModel + ".slx");
previewFile = fullfile(reportDir, "ieee39_10m39bus_sg5_dfig5_nebus_layout_top.png");
reportFile = fullfile(reportDir, "ieee39_10m39bus_sg5_dfig5_nebus_layout_report.md");

safeClose(sourceModel);
safeClose(dfigSourceModel);
safeClose(targetModel);
if isfile(targetFile)
    delete(targetFile);
end

load_system(fullfile(projectRoot, sourceModel + ".slx"));
load_system(fullfile(projectRoot, dfigSourceModel + ".slx"));
save_system(sourceModel, targetFile);
close_system(sourceModel, 0);

load_system(targetFile);
set_param(targetModel, ...
    "Name", targetModel, ...
    "PreLoadFcn", "Ts=50e-6;", ...
    "InitFcn", initCommand(), ...
    "StopTime", "25", ...
    "Location", [40 40 1900 1040]);

replacement = replacementMap();
for k = 1:numel(replacement)
    replaceGeneratorWithDfig(targetModel, dfigSourceModel, replacement(k));
end

addCleanRootAnnotations(targetModel, replacement);
routeLocalLines(targetModel);
audit = auditCleanModel(targetModel);
verification = verifyModel(targetModel);

save_system(targetModel, targetFile);
exportPreview(targetModel, previewFile);

close_system(targetModel, 0);
close_system(dfigSourceModel, 0);

writeReport(reportFile, targetFile, previewFile, replacement, audit, verification);
fprintf("Generated clean NEBUS-style SG5/DFIG5 model: %s\n", targetFile);
fprintf("Report: %s\n", reportFile);
end

function cmd = initCommand()
cmd = ...
    "projectRoot=fileparts(fileparts(fileparts(get_param(bdroot,'FileName')))); " + ...
    "run(fullfile(projectRoot,'NE39bus_dataV2.m')); " + ...
    "Tnum1_PSS=PSS_Data(1,2); Tden1_PSS=PSS_Data(1,3); " + ...
    "Tnum2_PSS=PSS_Data(1,4); Tden2_PSS=PSS_Data(1,5); " + ...
    "Twashout_PSS=PSS_Data(1,6); Tw_PSS=PSS_Data(1,6); Tsensor_PSS=PSS_Data(1,7); Ts_PSS=PSS_Data(1,7); " + ...
    "K_PSS=PSS_Data(1,8); Vmax_PSS=PSS_Data(1,9); Vmin_PSS=PSS_Data(1,10); " + ...
    "Ts=50e-6; " + ...
    "try, xInitial = init_power_wind_dfig_avg; catch, xInitial = []; end";
end

function items = replacementMap()
items = struct("sgName", {}, "dfigName", {}, "bus", {}, "machineId", {}, "layoutOffset", {});
items(1) = struct("sgName", "G4", "dfigName", "W33", "bus", 33, "machineId", 4, "layoutOffset", [0 0]);
items(2) = struct("sgName", "G5", "dfigName", "W34", "bus", 34, "machineId", 5, "layoutOffset", [0 0]);
items(3) = struct("sgName", "G6", "dfigName", "W35", "bus", 35, "machineId", 6, "layoutOffset", [0 45]);
items(4) = struct("sgName", "G7", "dfigName", "W36", "bus", 36, "machineId", 7, "layoutOffset", [0 45]);
items(5) = struct("sgName", "G8", "dfigName", "W37", "bus", 37, "machineId", 8, "layoutOffset", [0 -45]);
end

function replaceGeneratorWithDfig(targetModel, sourceModel, item)
oldPath = targetModel + "/" + item.sgName;
newPath = targetModel + "/" + item.dfigName;
sourcePath = sourceModel + "/DFIG Wind Turbine";

if ~blockExists(oldPath)
    error("Expected generator block not found: %s", oldPath);
end

oldPosition = get_param(oldPath, "Position");
connections = capturePhysicalConnections(oldPath);
delete_block(oldPath);

dfigPosition = dfigBoxAt(oldPosition, item.layoutOffset);
add_block(sourcePath, newPath, ...
    "Position", dfigPosition, ...
    "ShowName", "on", ...
    "BackgroundColor", "orange");

addDfigSignals(targetModel, dfigPosition, item);
connectDfigPhysicalPorts(newPath, connections);
writeTraceMetadata(newPath, item);
end

function connections = capturePhysicalConnections(blockPath)
ports = get_param(blockPath, "PortConnectivity");
connections = repmat(struct("dstBlock", [], "dstPort", []), 1, 3);
connectionCount = 0;
for i = 1:numel(ports)
    if startsWith(string(ports(i).Type), "RConn") && ~isempty(ports(i).DstBlock)
        connectionCount = connectionCount + 1;
        connections(connectionCount) = struct("dstBlock", ports(i).DstBlock, "dstPort", ports(i).DstPort);
    end
end
connections = connections(1:connectionCount);
if connectionCount ~= 3
    error("Expected three physical connections for %s, found %d.", blockPath, connectionCount);
end
end

function pos = dfigBoxAt(oldPosition, offset)
cx = (oldPosition(1) + oldPosition(3)) / 2;
cy = (oldPosition(2) + oldPosition(4)) / 2;
width = 95;
height = 126;
pos = round([cx - width/2, cy - height/2, cx + width/2, cy + height/2] + [offset offset]);
end

function addDfigSignals(modelName, dfigPosition, item)
windPath = modelName + "/" + item.dfigName + "_WindSpeed";
tripPath = modelName + "/" + item.dfigName + "_Trip";
termPath = modelName + "/" + item.dfigName + "_Measurements";

add_block("simulink/Sources/Constant", windPath, ...
    "Value", "15", ...
    "Position", [dfigPosition(1)-95 dfigPosition(2)+8 dfigPosition(1)-65 dfigPosition(2)+28], ...
    "ShowName", "on");
add_block("simulink/Sources/Constant", tripPath, ...
    "Value", "0", ...
    "Position", [dfigPosition(1)-95 dfigPosition(2)+38 dfigPosition(1)-65 dfigPosition(2)+58], ...
    "ShowName", "on");
add_block("simulink/Sinks/Terminator", termPath, ...
    "Position", [dfigPosition(3)+48 dfigPosition(2)+56 dfigPosition(3)+68 dfigPosition(2)+76], ...
    "ShowName", "on");

add_line(modelName, item.dfigName + "_WindSpeed/1", item.dfigName + "/1", "autorouting", "on");
add_line(modelName, item.dfigName + "_Trip/1", item.dfigName + "/2", "autorouting", "on");
add_line(modelName, item.dfigName + "/1", item.dfigName + "_Measurements/1", "autorouting", "on");
end

function connectDfigPhysicalPorts(dfigPath, connections)
ports = get_param(dfigPath, "PortHandles");
if numel(ports.LConn) < 3
    error("DFIG block %s does not expose three physical ports.", dfigPath);
end

for i = 1:3
    add_line(bdroot(dfigPath), ports.LConn(i), connections(i).dstPort, "autorouting", "on");
end
end

function writeTraceMetadata(blockPath, item)
trace = struct();
trace.id = item.dfigName;
trace.component_type = "dfig_wind";
trace.benchmark_source = "NEBUS39V2.slx";
trace.template_source = "power_wind_dfig_avg.slx/DFIG Wind Turbine";
trace.replaces = item.sgName;
trace.benchmark_machine_id = item.machineId;
trace.benchmark_bus = item.bus;
trace.scenario_role = "sg_to_dfig_replacement";
trace.generated_by = "build_ieee39_10m39bus_sg5_dfig5_nebus_layout.m";
trace.generated_at = char(datetime("now"));

set_param(blockPath, "UserData", trace);
set_param(blockPath, "UserDataPersistent", "on");
set_param(blockPath, "AttributesFormatString", sprintf("DFIG\\nBus %d\\nreplaces %s", item.bus, item.sgName));
end

function addCleanRootAnnotations(modelName, replacement)
try
    ann = Simulink.Annotation(modelName, "IEEE 10-machine 39-bus SG5/DFIG5 scenario rebuilt from NEBUS39V2");
    ann.Position = [70 35 760 65];
    ann.FontSize = 15;
    ann.FontWeight = "bold";
catch
end

lines = strings(0, 1);
for i = 1:numel(replacement)
    lines(end+1, 1) = sprintf("%s -> %s at bus %d", ...
        replacement(i).sgName, replacement(i).dfigName, replacement(i).bus); %#ok<AGROW>
end
try
    ann = Simulink.Annotation(modelName, "Replacement map: " + strjoin(lines, "; "));
    ann.Position = [70 70 1050 100];
    ann.FontSize = 10;
catch
end
end

function routeLocalLines(modelName)
lines = find_system(modelName, "SearchDepth", 1, "FindAll", "on", "Type", "Line");
for i = 1:numel(lines)
    try
        Simulink.BlockDiagram.routeLine(lines(i));
    catch
    end
end
end

function audit = auditCleanModel(modelName)
rootBlocks = find_system(modelName, "SearchDepth", 1, "Type", "Block");
allBlocks = find_system(modelName, "LookUnderMasks", "all", "FollowLinks", "on", "Type", "Block");
allLines = find_system(modelName, "LookUnderMasks", "all", "FollowLinks", "on", "FindAll", "on", "Type", "Line");

audit = struct();
audit.rootBlockCount = max(0, numel(rootBlocks) - 1);
audit.totalBlockCount = numel(allBlocks);
audit.totalLineCount = numel(allLines);
audit.rootOverlapCount = countRootOverlaps(rootBlocks, modelName);
audit.dfigCount = numel(find_system(modelName, "SearchDepth", 1, "Regexp", "on", "Name", "^W3[3-7]$"));
audit.remainingReplacedSgCount = numel(find_system(modelName, "SearchDepth", 1, "Regexp", "on", "Name", "^G[4-8]$"));
end

function count = countRootOverlaps(rootBlocks, modelName)
rects = zeros(0, 4);
for i = 1:numel(rootBlocks)
    blockPath = string(rootBlocks{i});
    if blockPath == modelName || isSignalAuxiliaryBlock(blockPath)
        continue
    end
    try
        rects(end+1, :) = get_param(rootBlocks{i}, "Position"); %#ok<AGROW>
    catch
    end
end

count = 0;
for i = 1:size(rects, 1)
    for j = i+1:size(rects, 1)
        if rectanglesOverlap(rects(i, :), rects(j, :))
            count = count + 1;
        end
    end
end
end

function tf = isSignalAuxiliaryBlock(blockPath)
name = get_param(blockPath, "Name");
tf = endsWith(name, "_WindSpeed") || endsWith(name, "_Trip") || endsWith(name, "_Measurements");
end

function tf = rectanglesOverlap(a, b)
horizontalGap = a(3) <= b(1) || b(3) <= a(1);
verticalGap = a(4) <= b(2) || b(4) <= a(2);
tf = ~(horizontalGap || verticalGap);
end

function verification = verifyModel(modelName)
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

function exportPreview(scope, outFile)
try
    open_system(scope);
    set_param(scope, "ZoomFactor", "FitSystem");
    print("-s" + scope, "-dpng", "-r150", outFile);
catch
end
end

function writeReport(reportFile, modelFile, previewFile, replacement, audit, verification)
fid = fopen(reportFile, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "# IEEE39 NEBUS-Layout SG5/DFIG5 Rebuild Report\n\n");
fprintf(fid, "Model: `%s`\n\n", modelFile);
fprintf(fid, "Preview: `%s`\n\n", previewFile);

fprintf(fid, "## Rebuild Policy\n\n");
fprintf(fid, "- Base layout and network source: `NEBUS39V2.slx`.\n");
fprintf(fid, "- Data source: `NE39bus_dataV2.m`.\n");
fprintf(fid, "- DFIG template: `power_wind_dfig_avg.slx/DFIG Wind Turbine`.\n");
fprintf(fid, "- Extra v0.8/v0.9 review, audit, and source-index subsystems were not copied.\n\n");

fprintf(fid, "## Replacement Map\n\n");
fprintf(fid, "| Original SG | Replacement DFIG | Benchmark bus | Benchmark machine row |\n");
fprintf(fid, "|---|---|---:|---:|\n");
for i = 1:numel(replacement)
    fprintf(fid, "| `%s` | `%s` | %d | %d |\n", ...
        replacement(i).sgName, replacement(i).dfigName, replacement(i).bus, replacement(i).machineId);
end

fprintf(fid, "\n## Layout Audit\n\n");
fprintf(fid, "- Root blocks: %d\n", audit.rootBlockCount);
fprintf(fid, "- Total blocks: %d\n", audit.totalBlockCount);
fprintf(fid, "- Total lines: %d\n", audit.totalLineCount);
fprintf(fid, "- Root overlap count excluding DFIG signal auxiliaries: %d\n", audit.rootOverlapCount);
fprintf(fid, "- Root DFIG replacements found: %d\n", audit.dfigCount);
fprintf(fid, "- Remaining G4-G8 root SG blocks: %d\n\n", audit.remainingReplacedSgCount);

fprintf(fid, "## Verification\n\n");
fprintf(fid, "- `SimulationCommand update`: %s\n", verification.compile);
fprintf(fid, "- `sim()` smoke run to `0.005 s`: %s\n", verification.smoke);
if strlength(string(verification.message)) > 0
    fprintf(fid, "- Message: `%s`\n", verification.message);
end
end

function tf = blockExists(path)
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
