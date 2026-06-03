function init_simulink_agent_project()
%INIT_SIMULINK_AGENT_PROJECT Initialize this project's Simulink agent toolkit.

projectRoot = fileparts(mfilename("fullpath"));
toolkitRoot = fullfile(projectRoot, "external", "simulink-agentic-toolkit");
scriptsRoot = fullfile(projectRoot, "scripts");

if ~isfolder(toolkitRoot)
    error("SimulinkAgent:MissingToolkit", ...
        "Expected toolkit folder not found: %s", toolkitRoot);
end

addpath(scriptsRoot);
loopRoot = fullfile(scriptsRoot, "loop");
if isfolder(loopRoot); addpath(loopRoot); end
addpath(toolkitRoot);
if exist("init_github_power_electronics_layout_tools", "file") == 2
    init_github_power_electronics_layout_tools;
end
satk_initialize;
end
