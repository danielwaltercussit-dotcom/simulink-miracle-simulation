function build_ieee39_sg5_dfig5_skill_optimized_v09()
%build_ieee39_sg5_dfig5_skill_optimized_v09 Optimize v0.8 with local skills.
%
% v0.9 uses the project-local GitHub layout/component-library skills while
% preserving the v0.8 executable physical detail.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
ensureDir(fullfile(projectRoot, "build", "generated_models"));
ensureDir(fullfile(projectRoot, "build", "reports"));

sourceModel = "ieee39_sg5_dfig5_reference_aligned_v08";
sourceFile = fullfile(projectRoot, "build", "generated_models", sourceModel + ".slx");
targetModel = "ieee39_sg5_dfig5_skill_optimized_v09";
targetFile = fullfile(projectRoot, "build", "generated_models", targetModel + ".slx");

if ~isfile(sourceFile)
    build_ieee39_sg5_dfig5_reference_aligned_v08();
end

toolStatus = init_github_power_electronics_layout_tools();

safeClose(sourceModel);
safeClose(targetModel);
if isfile(targetFile)
    delete(targetFile);
end

load_system(sourceFile);
save_system(sourceModel, targetFile);
close_system(sourceModel, 0);

load_system(targetFile);
set_param(targetModel, "Location", [25 25 1920 1040]);

applySkillOptimizedRootLayout(targetModel);
addSkillOptimizationPanels(targetModel, toolStatus);
routeTopLevelSignalLines(targetModel);

audit = auditModelLayout(targetModel);
verification = runVerification(targetModel);

save_system(targetModel, targetFile);
exportPreview(targetModel, fullfile(projectRoot, "build", "reports", "ieee39_skill_optimized_v09_top.png"));
exportPreview(targetModel + "/Skill_Layout_Audit", ...
    fullfile(projectRoot, "build", "reports", "ieee39_skill_optimized_v09_layout_audit.png"));
exportPreview(targetModel + "/Power_Electronics_Library_Guide", ...
    fullfile(projectRoot, "build", "reports", "ieee39_skill_optimized_v09_component_guide.png"));
close_system(targetModel, 0);

writeSkillOptimizedReport(projectRoot, targetFile, toolStatus, audit, verification);
fprintf("Generated skill-optimized model: %s\n", targetFile);
fprintf("Skill-optimized report: %s\n", fullfile(projectRoot, "build", "reports", "skill_optimized_v09_report.md"));
end

function applySkillOptimizedRootLayout(modelName)
placements = {
    "Topology_Overview", [45 75 845 545]
    "Regional_Overviews", [45 590 845 960]
    "Area_Partitioned_Physical_Detail", [900 75 1315 270]
    "NEBUS39_Standard_Benchmark", [900 315 1315 500]
    "SG5_DFIG5_Scenario_Overlay", [900 545 1315 740]
    "Benchmark_Data_Interface", [900 785 1315 960]
    "Layout_Routing_Rules", [1375 75 1815 235]
    "Reports_Trace", [1375 780 1815 960]
};

for i = 1:size(placements, 1)
    path = modelName + "/" + placements{i, 1};
    if blockExists(path)
        set_param(path, "Position", placements{i, 2});
    end
end
end

function addSkillOptimizationPanels(modelName, toolStatus)
layoutAuditPath = modelName + "/Skill_Layout_Audit";
componentGuidePath = modelName + "/Power_Electronics_Library_Guide";
sourceIndexPath = modelName + "/GitHub_Skill_Source_Index";

createAnnotationSubsystem(layoutAuditPath, [1375 275 1815 465], "cyan", ...
    "Skill layout audit", [
    "Uses simulink-auto-layout-github"
    "Deterministic coordinates for topology and physical power-grid views"
    "Auto-Layout reserved for ordinary control/measurement subsystems"
    "Physical SPS and conservation-port lines remain explicit"
]);

createAnnotationSubsystem(componentGuidePath, [1375 505 1815 735], "magenta", ...
    "Power electronics library guide", [
    "Uses power-electronics-component-libraries"
    "DFIG compatibility: power_wind_dfig_avg.slx"
    "VSC/PLL/PI references: external/github/pwrsys-matlab"
    "Modern Simscape reference: Simscape_Electrical_Support_Library"
    "R2024b policy: Simscape support library is reference-only"
]);

createAnnotationSubsystem(sourceIndexPath, [45 985 1815 1115], "gray", ...
    "GitHub skill source index", githubSourceLines(toolStatus));

try
    ann = Simulink.Annotation(modelName, ...
        "IEEE39 SG/DFIG v0.9: skill-optimized review canvas with GitHub layout and component-library guidance");
    ann.Position = [45 25 1030 55];
    ann.FontSize = 15;
    ann.FontWeight = "bold";
catch
end
end

function lines = githubSourceLines(toolStatus)
lines = strings(0, 1);
for i = 1:numel(toolStatus)
    status = "reference-only";
    if toolStatus(i).added
        status = "path active";
    end
    lines(end+1, 1) = string(toolStatus(i).name) + ": " + status; %#ok<AGROW>
end
lines(end+1, 1) = "Skills: simulink-auto-layout-github, power-electronics-component-libraries";
end

function createAnnotationSubsystem(path, position, color, titleText, lines)
if blockExists(path)
    delete_block(path);
end
add_block("built-in/Subsystem", path, ...
    "Position", position, ...
    "BackgroundColor", color, ...
    "ShowName", "on");
Simulink.SubSystem.deleteContents(path);
set_param(path, "AttributesFormatString", titleText);
try
    set_param(path, ...
        "Mask", "on", ...
        "MaskIconOpaque", "off", ...
        "MaskDisplay", sprintf("disp('%s')", titleText));
catch
end
try
    ann = Simulink.Annotation(path, titleText);
    ann.Position = [35 25 390 55];
    ann.FontSize = 13;
    ann.FontWeight = "bold";
catch
end
try
    ann = Simulink.Annotation(path, strjoin(lines, newline));
    ann.Position = [35 75 620 215];
    ann.FontSize = 10;
catch
end
end

function routeTopLevelSignalLines(modelName)
lines = find_system(modelName, "SearchDepth", 1, "FindAll", "on", "Type", "Line");
for i = 1:numel(lines)
    try
        Simulink.BlockDiagram.routeLine(lines(i));
    catch
    end
end
end

function audit = auditModelLayout(modelName)
rootBlocks = find_system(modelName, "SearchDepth", 1, "Type", "Block");
rootLines = find_system(modelName, "SearchDepth", 1, "FindAll", "on", "Type", "Line");
allBlocks = find_system(modelName, "LookUnderMasks", "all", "FollowLinks", "on", "Type", "Block");
allLines = find_system(modelName, "LookUnderMasks", "all", "FollowLinks", "on", "FindAll", "on", "Type", "Line");
gotoBlocks = find_system(modelName, "LookUnderMasks", "all", "FollowLinks", "on", "BlockType", "Goto");
fromBlocks = find_system(modelName, "LookUnderMasks", "all", "FollowLinks", "on", "BlockType", "From");

audit = struct();
audit.rootBlockCount = max(0, numel(rootBlocks) - 1);
audit.rootLineCount = numel(rootLines);
audit.totalBlockCount = numel(allBlocks);
audit.totalLineCount = numel(allLines);
audit.gotoCount = numel(gotoBlocks);
audit.fromCount = numel(fromBlocks);
audit.overlapCount = countRootOverlaps(rootBlocks, modelName);
end

function count = countRootOverlaps(rootBlocks, modelName)
rects = zeros(0, 4);
for i = 1:numel(rootBlocks)
    path = string(rootBlocks{i});
    if path == modelName
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

function tf = rectanglesOverlap(a, b)
horizontalGap = a(3) <= b(1) || b(3) <= a(1);
verticalGap = a(4) <= b(2) || b(4) <= a(2);
tf = ~(horizontalGap || verticalGap);
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

function exportPreview(scope, outFile)
try
    open_system(scope);
    set_param(scope, "ZoomFactor", "FitSystem");
    print("-s" + scope, "-dpng", "-r150", outFile);
catch
end
end

function writeSkillOptimizedReport(projectRoot, modelFile, toolStatus, audit, verification)
reportFile = fullfile(projectRoot, "build", "reports", "skill_optimized_v09_report.md");
fid = fopen(reportFile, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "# IEEE39 Skill-Optimized v0.9 Report\n\n");
fprintf(fid, "Model: `%s`\n\n", modelFile);

fprintf(fid, "## Skills Used\n\n");
fprintf(fid, "- `.agents/skills/simulink-auto-layout-github`\n");
fprintf(fid, "- `.agents/skills/power-electronics-component-libraries`\n");
fprintf(fid, "- Global skill: `code-simplifier` for script clarity review\n\n");

fprintf(fid, "## Changes from v0.8\n\n");
fprintf(fid, "- Rebalanced root canvas into topology, regional overview, executable detail, benchmark, scenario, data, reports, and skill-source zones.\n");
fprintf(fid, "- Added `Skill_Layout_Audit` panel for layout rules and Auto-Layout boundaries.\n");
fprintf(fid, "- Added `Power_Electronics_Library_Guide` panel for DFIG/VSC/PLL/PI/Simscape source selection.\n");
fprintf(fid, "- Added `GitHub_Skill_Source_Index` panel listing active and reference-only GitHub sources.\n");
fprintf(fid, "- Routed only root-level ordinary lines; physical SPS detail remains explicit and unchanged.\n\n");

fprintf(fid, "## GitHub Tool Status\n\n");
fprintf(fid, "| Tool | Added to MATLAB path | Message |\n");
fprintf(fid, "|---|---:|---|\n");
for i = 1:numel(toolStatus)
    fprintf(fid, "| `%s` | %s | %s |\n", ...
        toolStatus(i).name, string(toolStatus(i).added), toolStatus(i).message);
end

fprintf(fid, "\n## Layout Audit\n\n");
fprintf(fid, "- Root blocks: %d\n", audit.rootBlockCount);
fprintf(fid, "- Root lines: %d\n", audit.rootLineCount);
fprintf(fid, "- Total blocks: %d\n", audit.totalBlockCount);
fprintf(fid, "- Total lines: %d\n", audit.totalLineCount);
fprintf(fid, "- Goto blocks: %d\n", audit.gotoCount);
fprintf(fid, "- From blocks: %d\n", audit.fromCount);
fprintf(fid, "- Root overlap count: %d\n\n", audit.overlapCount);

fprintf(fid, "## Verification\n\n");
fprintf(fid, "- `SimulationCommand update`: %s\n", verification.compile);
fprintf(fid, "- `sim()` smoke run to `0.005 s`: %s\n", verification.smoke);
if strlength(string(verification.message)) > 0
    fprintf(fid, "- Message: `%s`\n", verification.message);
end
fprintf(fid, "- Preview: `build/reports/ieee39_skill_optimized_v09_top.png`\n");
fprintf(fid, "- Layout audit preview: `build/reports/ieee39_skill_optimized_v09_layout_audit.png`\n");
fprintf(fid, "- Component guide preview: `build/reports/ieee39_skill_optimized_v09_component_guide.png`\n");
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
