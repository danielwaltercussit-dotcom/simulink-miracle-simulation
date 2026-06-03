function status = init_github_power_electronics_layout_tools()
%INIT_GITHUB_POWER_ELECTRONICS_LAYOUT_TOOLS Add project-local GitHub tools.
%
% This initializer is intentionally project-local. It does not edit startup.m
% or any user/global MATLAB path configuration.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
githubRoot = fullfile(projectRoot, "external", "github");

tools = [
    tool("McSCert-Auto-Layout", true, "Simulink auto-layout algorithms")
    tool("McSCert-Simulink-Utility", true, "layout, bounds, line-routing utilities")
    tool("pwrsys-matlab", true, "converter-interfaced power-system component library")
    tool("Simscape_Electrical_Support_Library", isR2025bOrNewer(), ...
        "MathWorks Simscape Electrical support library for power systems")
];

status = struct("name", {}, "path", {}, "added", {}, "message", {});

for k = 1:numel(tools)
    toolPath = fullfile(githubRoot, tools(k).name);
    entry = struct("name", tools(k).name, "path", toolPath, ...
        "added", false, "message", "");

    if ~isfolder(toolPath)
        entry.message = "missing";
    elseif ~tools(k).enabled
        entry.message = "installed but not added to path for this MATLAB release";
    else
        addpath(genpath(toolPath));
        entry.added = true;
        entry.message = tools(k).purpose;
    end
    status(end+1) = entry; %#ok<AGROW>
end

disp(struct2table(status));
end

function value = tool(name, enabled, purpose)
value = struct("name", name, "enabled", enabled, "purpose", purpose);
end

function tf = isR2025bOrNewer()
releaseNumber = sscanf(version, "%f", 1);
tf = ~isempty(releaseNumber) && releaseNumber >= 25.2;
end
