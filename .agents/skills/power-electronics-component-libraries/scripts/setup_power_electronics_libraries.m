function status = setup_power_electronics_libraries()
%SETUP_POWER_ELECTRONICS_LIBRARIES Initialize project-local component libs.

skillRoot = fileparts(fileparts(mfilename("fullpath")));
projectRoot = fileparts(fileparts(fileparts(skillRoot)));
addpath(fullfile(projectRoot, "scripts"));
status = init_github_power_electronics_layout_tools();
end
