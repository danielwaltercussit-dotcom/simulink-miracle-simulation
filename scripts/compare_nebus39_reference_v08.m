function compare_nebus39_reference_v08()
%compare_nebus39_reference_v08 Compare imported NE39 reference and v0.7 model.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
reportFile = fullfile(projectRoot, "build", "reports", "nebus39_reference_comparison_v08.md");
ensureDir(fileparts(reportFile));

referenceFile = fullfile(projectRoot, "NEBUS39V2.slx");
generatedFile = fullfile(projectRoot, "build", "generated_models", "ieee39_sg5_dfig5_layout_optimized_v07.slx");

if ~isfile(referenceFile)
    error("Reference model not found: %s", referenceFile);
end
if ~isfile(generatedFile)
    error("Generated model not found: %s", generatedFile);
end

safeClose("NEBUS39V2");
safeClose("ieee39_sg5_dfig5_layout_optimized_v07");

load_system(referenceFile);
load_system(generatedFile);

reference = inspectModel("NEBUS39V2");
generated = inspectModel("ieee39_sg5_dfig5_layout_optimized_v07");

writeReport(reportFile, referenceFile, generatedFile, reference, generated);

close_system("NEBUS39V2", 0);
close_system("ieee39_sg5_dfig5_layout_optimized_v07", 0);

fprintf("Comparison report: %s\n", reportFile);
end

function info = inspectModel(modelName)
blocks = find_system(modelName, ...
    "LookUnderMasks", "all", ...
    "FollowLinks", "on", ...
    "Type", "Block");
topBlocks = find_system(modelName, "SearchDepth", 1, "Type", "Block");
lines = find_system(modelName, "FindAll", "on", "Type", "Line");
annotations = find_system(modelName, "FindAll", "on", "Type", "Annotation");

info = struct();
info.name = modelName;
info.blockCount = numel(blocks);
info.topBlockCount = max(0, numel(topBlocks) - 1);
info.lineCount = numel(lines);
info.annotationCount = numel(annotations);
info.maxDepth = maxDepth(blocks, modelName);
info.topBlocks = topBlockSummary(topBlocks, modelName);
info.blockTypes = countParam(blocks, "BlockType");
info.maskTypes = countParam(blocks, "MaskType");
info.referenceBlocks = countParam(blocks, "ReferenceBlock");
info.gotoFrom = countMatchingBlocks(blocks, ["Goto", "From"]);
info.subsystems = countMatchingBlocks(blocks, "SubSystem");
info.powerLike = filterNames(blocks, ["powergui", "Synchronous", "Machine", "Transformer", ...
    "Three-Phase", "Line", "Breaker", "Load", "Bus", "Busbar", "PMU"]);
info.sgLike = filterNames(blocks, ["Synchronous", "SM", "Machine"]);
info.dfigLike = filterNames(blocks, ["DFIG", "Wind"]);
end

function depth = maxDepth(blocks, modelName)
depth = 0;
for i = 1:numel(blocks)
    path = string(blocks{i});
    rest = erase(path, modelName);
    depth = max(depth, count(rest, "/"));
end
end

function summary = topBlockSummary(topBlocks, modelName)
summary = strings(0, 1);
for i = 1:numel(topBlocks)
    path = string(topBlocks{i});
    if path == modelName
        continue
    end
    summary(end+1, 1) = erase(path, modelName + "/"); %#ok<AGROW>
end
end

function counts = countParam(blocks, paramName)
keys = strings(0, 1);
values = zeros(0, 1);
for i = 1:numel(blocks)
    value = "";
    try
        value = string(get_param(blocks{i}, paramName));
    catch
    end
    if strlength(value) == 0
        continue
    end
    idx = find(keys == value, 1);
    if isempty(idx)
        keys(end+1, 1) = value; %#ok<AGROW>
        values(end+1, 1) = 1; %#ok<AGROW>
    else
        values(idx) = values(idx) + 1;
    end
end
[values, order] = sort(values, "descend");
keys = keys(order);
counts = table(keys(:), values(:), 'VariableNames', {'Name', 'Count'});
end

function count = countMatchingBlocks(blocks, types)
count = 0;
types = string(types);
for i = 1:numel(blocks)
    try
        if any(string(get_param(blocks{i}, "BlockType")) == types)
            count = count + 1;
        end
    catch
    end
end
end

function names = filterNames(blocks, patterns)
patterns = lower(string(patterns));
names = strings(0, 1);
for i = 1:numel(blocks)
    blockName = lower(string(get_param(blocks{i}, "Name")));
    path = string(blocks{i});
    if any(contains(blockName, patterns))
        names(end+1, 1) = path; %#ok<AGROW>
    end
end
names = names(1:min(numel(names), 80));
end

function writeReport(reportFile, referenceFile, generatedFile, reference, generated)
fid = fopen(reportFile, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "# NEBUS39V2 Reference Comparison v0.8\n\n");
fprintf(fid, "Reference model: `%s`\n\n", referenceFile);
fprintf(fid, "Generated model: `%s`\n\n", generatedFile);

fprintf(fid, "## High-Level Counts\n\n");
fprintf(fid, "| Metric | NEBUS39V2 standard | Generated v0.7 |\n");
fprintf(fid, "|---|---:|---:|\n");
fprintf(fid, "| Blocks | %d | %d |\n", reference.blockCount, generated.blockCount);
fprintf(fid, "| Top-level blocks | %d | %d |\n", reference.topBlockCount, generated.topBlockCount);
fprintf(fid, "| Lines | %d | %d |\n", reference.lineCount, generated.lineCount);
fprintf(fid, "| Annotations | %d | %d |\n", reference.annotationCount, generated.annotationCount);
fprintf(fid, "| Max hierarchy depth | %d | %d |\n", reference.maxDepth, generated.maxDepth);
fprintf(fid, "| Goto/From blocks | %d | %d |\n", reference.gotoFrom, generated.gotoFrom);
fprintf(fid, "| Subsystem blocks | %d | %d |\n\n", reference.subsystems, generated.subsystems);

fprintf(fid, "## Top-Level Organization\n\n");
fprintf(fid, "### NEBUS39V2\n\n");
writeStringList(fid, reference.topBlocks, 40);
fprintf(fid, "\n### Generated v0.7\n\n");
writeStringList(fid, generated.topBlocks, 40);

fprintf(fid, "\n## Dominant Block Types\n\n");
fprintf(fid, "### NEBUS39V2\n\n");
writeCountTable(fid, reference.blockTypes, 20);
fprintf(fid, "\n### Generated v0.7\n\n");
writeCountTable(fid, generated.blockTypes, 20);

fprintf(fid, "\n## Dominant Mask Types\n\n");
fprintf(fid, "### NEBUS39V2\n\n");
writeCountTable(fid, reference.maskTypes, 25);
fprintf(fid, "\n### Generated v0.7\n\n");
writeCountTable(fid, generated.maskTypes, 25);

fprintf(fid, "\n## Power-System Named Blocks Sample\n\n");
fprintf(fid, "### NEBUS39V2\n\n");
writeStringList(fid, reference.powerLike, 80);
fprintf(fid, "\n### Generated v0.7\n\n");
writeStringList(fid, generated.powerLike, 80);

fprintf(fid, "\n## Generator/Wind Named Blocks Sample\n\n");
fprintf(fid, "- NEBUS39V2 SG-like blocks: %d sampled\n", numel(reference.sgLike));
fprintf(fid, "- NEBUS39V2 DFIG/wind-like blocks: %d sampled\n", numel(reference.dfigLike));
fprintf(fid, "- Generated SG-like blocks: %d sampled\n", numel(generated.sgLike));
fprintf(fid, "- Generated DFIG/wind-like blocks: %d sampled\n\n", numel(generated.dfigLike));

fprintf(fid, "## Modeling Lessons\n\n");
fprintf(fid, "- The standard model is an executable benchmark first: full synchronous-generator data, line/transformer/load data, and control parameters are centralized in `NE39bus_dataV2.m`.\n");
fprintf(fid, "- The standard model keeps the network electrically literal and uses recognizable power-system block names, while generated v0.7 separates review diagrams from executable detail.\n");
fprintf(fid, "- Future generated cases should preserve the v0.7 review/detail split, but data and masks should be reorganized around the reference model's data-table pattern.\n");
fprintf(fid, "- Imported standard models should be treated as regression oracles: compare bus, branch, transformer, generator, AVR, PSS, and governor counts before changing replacement policies.\n");
fprintf(fid, "- DFIG replacement must be an explicit scenario overlay on top of a complete SG benchmark, not a silent loss of the original ten-machine parameter set.\n");
end

function writeStringList(fid, values, limit)
if isempty(values)
    fprintf(fid, "- None found\n");
    return
end
for i = 1:min(numel(values), limit)
    fprintf(fid, "- `%s`\n", values(i));
end
end

function writeCountTable(fid, counts, limit)
if isempty(counts) || height(counts) == 0
    fprintf(fid, "- None found\n");
    return
end
fprintf(fid, "| Name | Count |\n");
fprintf(fid, "|---|---:|\n");
for i = 1:min(height(counts), limit)
    fprintf(fid, "| `%s` | %d |\n", counts.Name(i), counts.Count(i));
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
