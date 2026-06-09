function results = dangling_line_cleanup_test()
%DANGLING_LINE_CLEANUP_TEST Contract test for SPS-safe line cleanup.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'scripts', 'layout'));

modelName = 'dangling_line_cleanup_fixture';
cleanup = onCleanup(@() close_fixture(modelName));
new_system(modelName);
add_block('simulink/Sources/Constant', [modelName '/Source'], ...
    'Position', [40 40 70 70]);
add_block('simulink/Sinks/Terminator', [modelName '/Sink'], ...
    'Position', [220 40 240 60]);
add_line(modelName, 'Source/1', 'Sink/1');
add_line(modelName, [100 120; 180 120]);

dryRun = cleanup_dangling_lines(modelName, 'Apply', false, 'SaveModel', false);
assert(~dryRun.passed);
assert(dryRun.before_count == 1);
assert(dryRun.after_count == 1);

applied = cleanup_dangling_lines(modelName, 'Apply', true, 'SaveModel', false);
assert(applied.passed);
assert(applied.removed_count == 1);
assert(applied.after_count == 0);

connected = find_system(modelName, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'line');
assert(isscalar(connected));
assert(strcmp(get_param(connected(1), 'Connected'), 'on'));

results = struct('passed', true, 'dry_run_count', dryRun.before_count, ...
    'removed_count', applied.removed_count);
fprintf('dangling_line_cleanup_test: PASS (%d removed)\n', applied.removed_count);
end

function close_fixture(modelName)
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end
