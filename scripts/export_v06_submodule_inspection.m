function export_v06_submodule_inspection()
%EXPORT_V06_SUBMODULE_INSPECTION Export v0.6 physical-detail inspection PNGs.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
modelName = "ieee39_sg5_dfig5_area_partitioned_v06";
modelFile = fullfile(projectRoot, "build", "generated_models", modelName + ".slx");
load_system(modelFile);

scopes = [
    modelName
    modelName + "/Zone_NorthWest"
    modelName + "/Zone_SouthWest"
    modelName + "/Zone_Central"
    modelName + "/Zone_NorthEast"
];
names = [
    "detail_root"
    "zone_nw"
    "zone_sw"
    "zone_central"
    "zone_ne"
];

for i = 1:numel(scopes)
    try
        open_system(scopes(i));
        set_param(scopes(i), "ZoomFactor", "FitSystem");
        outFile = fullfile(projectRoot, "build", "reports", "inspect_" + names(i) + "_v06.png");
        print("-s" + scopes(i), "-dpng", "-r150", outFile);
        fprintf("exported %s\n", outFile);
    catch ME
        fprintf("failed %s: %s\n", scopes(i), ME.message);
    end
end

close_system(modelName, 0);
end
