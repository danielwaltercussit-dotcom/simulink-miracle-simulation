function s = ai_in_loop_stage_layout(projectRoot, modelName)
%AI_IN_LOOP_STAGE_LAYOUT  Audit root layout and model quality.
s = struct('name','S3_LAYOUT','status','PASS','model',char(modelName));
modelPath = fullfile(projectRoot,'build','generated_models', strcat(char(modelName), ".slx"));
load_system(modelPath);
rootBlocks = find_system(char(modelName), 'SearchDepth', 1, ...
    'LookUnderMasks', 'none', 'FollowLinks', 'off', 'Type', 'Block');
s.root_block_count = numel(rootBlocks);
overlap = ai_in_loop_count_overlap(rootBlocks);
s.root_overlap = overlap;
if overlap > 0
    error('AIInLoop:LayoutOverlap','Root overlap = %d (expected 0). FS-005.', overlap);
end
addpath(fullfile(projectRoot, 'scripts'));
addpath(fullfile(projectRoot, 'scripts', 'layout'));
layoutReportPath = fullfile(projectRoot, 'build', 'reports', 'layout', [char(modelName) '.md']);
audit = audit_model_quality_layout(char(modelName), ...
    'ProjectRoot', projectRoot, ...
    'ReportPath', layoutReportPath);
s.layout_quality_report_path = layoutReportPath;
s.layout_quality_checks = audit.checks;
s.layout_quality_metrics = audit.metrics;
if ~audit.passed
    error('AIInLoop:ModelQualityLayoutFail', 'Layout quality audit failed: %s', audit.message);
end
end
