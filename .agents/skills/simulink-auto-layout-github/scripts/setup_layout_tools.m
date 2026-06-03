function status = setup_layout_tools()
%SETUP_LAYOUT_TOOLS Initialize project-local GitHub Simulink layout tools.

skillRoot = fileparts(fileparts(mfilename("fullpath")));
projectRoot = fileparts(fileparts(fileparts(skillRoot)));
addpath(fullfile(projectRoot, "scripts"));
status = init_github_power_electronics_layout_tools();
end
