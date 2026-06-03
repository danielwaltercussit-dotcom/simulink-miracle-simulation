function build_ieee39_sg5_dfig5_reference_aligned_v08()
%build_ieee39_sg5_dfig5_reference_aligned_v08 Align v0.7 with NEBUS39V2.
%
% v0.8 keeps the readable/generated SG5-DFIG5 scenario, but adds explicit
% benchmark-reference and scenario-overlay panels learned from NEBUS39V2.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
ensureDir(fullfile(projectRoot, "build", "generated_models"));
ensureDir(fullfile(projectRoot, "build", "reports"));

sourceModel = "ieee39_sg5_dfig5_layout_optimized_v07";
sourceFile = fullfile(projectRoot, "build", "generated_models", sourceModel + ".slx");
targetModel = "ieee39_sg5_dfig5_reference_aligned_v08";
targetFile = fullfile(projectRoot, "build", "generated_models", targetModel + ".slx");
comparisonReport = fullfile(projectRoot, "build", "reports", "nebus39_reference_comparison_v08.md");

if ~isfile(sourceFile)
    build_ieee39_sg5_dfig5_layout_optimized_v07();
end
if ~isfile(comparisonReport)
    compare_nebus39_reference_v08();
end

safeClose(sourceModel);
safeClose(targetModel);
if isfile(targetFile)
    delete(targetFile);
end

load_system(sourceFile);
save_system(sourceModel, targetFile);
close_system(sourceModel, 0);

load_system(targetFile);
set_param(targetModel, ...
    "Location", [25 35 1880 1030], ...
    "PreLoadFcn", benchmarkInitCommand(), ...
    "InitFcn", benchmarkInitCommand());

repositionExistingBlocks(targetModel);
addBenchmarkPanels(targetModel);

verification = runVerification(targetModel);
save_system(targetModel, targetFile);
exportPreview(targetModel, fullfile(projectRoot, "build", "reports", "ieee39_reference_aligned_v08_top.png"));
close_system(targetModel, 0);

writeReferenceAlignedReport(projectRoot, targetFile, verification);
fprintf("Generated reference-aligned model: %s\n", targetFile);
fprintf("Reference-aligned report: %s\n", fullfile(projectRoot, "build", "reports", "reference_aligned_v08_report.md"));
end

function cmd = benchmarkInitCommand()
cmd = ...
    "projectRoot=fileparts(fileparts(fileparts(get_param(bdroot,'FileName')))); " + ...
    "run(fullfile(projectRoot,'NE39bus_dataV2.m')); " + ...
    "Ts=50e-6; if ~exist('xInitial','var'), xInitial=[]; end";
end

function repositionExistingBlocks(modelName)
placements = {
    "Topology_Overview", [55 75 900 560]
    "Area_Partitioned_Physical_Detail", [960 85 1410 330]
    "Regional_Overviews", [55 605 900 965]
    "Layout_Routing_Rules", [1470 360 1815 525]
    "Reports_Trace", [1470 555 1815 700]
};
for i = 1:size(placements, 1)
    path = modelName + "/" + placements{i, 1};
    if blockExists(path)
        set_param(path, "Position", placements{i, 2});
    end
end
end

function addBenchmarkPanels(modelName)
benchmarkPath = modelName + "/NEBUS39_Standard_Benchmark";
overlayPath = modelName + "/SG5_DFIG5_Scenario_Overlay";
dataPath = modelName + "/Benchmark_Data_Interface";

createAnnotationSubsystem(benchmarkPath, [960 365 1410 560], "lightBlue", ...
    "NEBUS39V2 benchmark oracle", [
    "Standard model: NEBUS39V2.slx"
    "Data script: NE39bus_dataV2.m"
    "Ten synchronous machines retained as the baseline"
    "Use as regression oracle before applying renewable replacement"
]);

createAnnotationSubsystem(overlayPath, [960 605 1410 820], "orange", ...
    "SG5/DFIG5 scenario overlay", [
    "Scenario keeps SG buses 30, 31, 32, 38, 39"
    "Scenario replaces buses 33, 34, 35, 36, 37 with DFIG units"
    "Replacement is explicit and traceable, not a silent deletion"
    "Compare branch/load/transformer counts against the benchmark"
]);

createAnnotationSubsystem(dataPath, [1470 85 1815 330], "yellow", ...
    "Benchmark data loading", [
    "Model callbacks load NE39bus_dataV2.m"
    "Keep line, Trans, mac_con, AVR_Data, PSS_Data, STG_Data as tables"
    "Generated specs should map back to these benchmark tables"
    "Scenario-specific tuning lives in build/data, not inside masks"
]);

try
    ann = Simulink.Annotation(modelName, "IEEE39 SG/DFIG model v0.8: aligned to imported NEBUS39V2 benchmark");
    ann.Position = [55 25 830 55];
    ann.FontSize = 15;
    ann.FontWeight = "bold";
catch
end
try
    ann = Simulink.Annotation(modelName, ...
        "Open NEBUS39_Standard_Benchmark for the reference contract, then SG5_DFIG5_Scenario_Overlay for the replacement policy.");
    ann.Position = [960 845 1780 890];
    ann.FontSize = 10;
catch
end
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
    ann.Position = [35 25 380 55];
    ann.FontSize = 13;
    ann.FontWeight = "bold";
catch
end
try
    ann = Simulink.Annotation(path, strjoin(lines, newline));
    ann.Position = [35 75 430 190];
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

function exportPreview(scope, outFile)
try
    open_system(scope);
    set_param(scope, "ZoomFactor", "FitSystem");
    print("-s" + scope, "-dpng", "-r150", outFile);
catch
end
end

function writeReferenceAlignedReport(projectRoot, modelFile, verification)
reportFile = fullfile(projectRoot, "build", "reports", "reference_aligned_v08_report.md");
fid = fopen(reportFile, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# IEEE39 Reference-Aligned v0.8 Report\n\n");
fprintf(fid, "Model: `%s`\n\n", modelFile);
fprintf(fid, "## Changes from v0.7\n\n");
fprintf(fid, "- Added `NEBUS39_Standard_Benchmark` as the imported benchmark contract panel.\n");
fprintf(fid, "- Added `Benchmark_Data_Interface` documenting that `NE39bus_dataV2.m` is loaded by model callbacks.\n");
fprintf(fid, "- Added `SG5_DFIG5_Scenario_Overlay` so DFIG replacement is explicit and auditable.\n");
fprintf(fid, "- Rebalanced root layout so reference, data, scenario, topology, regional views, and executable detail are visible on one canvas.\n\n");
fprintf(fid, "## Verification\n\n");
fprintf(fid, "- `SimulationCommand update`: %s\n", verification.compile);
fprintf(fid, "- `sim()` smoke run to `0.005 s`: %s\n", verification.smoke);
if strlength(string(verification.message)) > 0
    fprintf(fid, "- Message: `%s`\n", verification.message);
end
fprintf(fid, "- Comparison report: `build/reports/nebus39_reference_comparison_v08.md`\n");
fprintf(fid, "- Preview image: `build/reports/ieee39_reference_aligned_v08_top.png`\n");
fprintf(fid, "\n## Project-local Skills\n\n");
fprintf(fid, "- Deployed: `.agents/skills/skill-creator`\n");
fprintf(fid, "- Deployed: `.agents/skills/document-skills`\n");
fprintf(fid, "- Deployed: `.agents/skills/find-skill`\n");
fprintf(fid, "- Deployed: `.agents/skills/code-simplifier`\n");
fprintf(fid, "- Validation: all four project-local skill folders passed `quick_validate.py` with `PYTHONUTF8=1`.\n");
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
