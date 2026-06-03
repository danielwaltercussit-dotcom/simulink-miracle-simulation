function init_simulink_agent_project_cache(varargin)
%INIT_SIMULINK_AGENT_PROJECT_CACHE  One-shot path cache for fast -batch startup.
%
%   Run ONCE in an interactive MATLAB session:
%     >> cd("C:\Users\jonas\Desktop\simulink_agent_v1")
%     >> init_simulink_agent_project_cache
%
%   This adds the project's scripts/, scripts/loop/, and external/
%   simulink-agentic-toolkit/ folders to MATLAB's saved path (pathdef.m
%   under userpath), so subsequent `matlab -batch "ai_in_loop_run(...)"`
%   commands skip the 60-90 s `satk_initialize` phase.
%
%   Call init_simulink_agent_project_cache('clear') to remove these entries.
%
%   This is OPT-IN; the regular `init_simulink_agent_project` workflow
%   continues to work unchanged. Caching is mostly useful for the AI agent's
%   -batch invocations.

projectRoot = fileparts(mfilename("fullpath"));
toolkitRoot = fullfile(projectRoot, "external", "simulink-agentic-toolkit");
scriptsRoot = fullfile(projectRoot, "scripts");
loopRoot    = fullfile(scriptsRoot, "loop");

paths = {char(scriptsRoot), char(loopRoot), char(toolkitRoot)};

if nargin >= 1 && strcmpi(varargin{1}, 'clear')
    for k = 1:numel(paths)
        if any(strcmp(strsplit(path, pathsep), paths{k}))
            rmpath(paths{k});
        end
    end
    savepath;
    fprintf('[init-cache] Cleared %d project path entries from saved path.\n', numel(paths));
    return
end

% Verify the toolkit root exists; cache is only useful when the toolkit is here.
if ~isfolder(toolkitRoot)
    error("SimulinkAgent:MissingToolkit", ...
        "Expected toolkit folder not found: %s", toolkitRoot);
end

% Add and persist.
for k = 1:numel(paths)
    if isfolder(paths{k})
        addpath(paths{k});
    end
end
status = savepath;
if status ~= 0
    warning("SimulinkAgent:SavepathFailed", ...
        "savepath returned %d. The path was added to this session but not " + ...
        "persisted. Check MATLAB ''Save'' permission on %s.", status, ...
        fullfile(matlabroot,'toolbox','local','pathdef.m'));
    return
end

fprintf('[init-cache] Saved project paths to MATLAB pathdef.m:\n');
for k = 1:numel(paths)
    fprintf('  + %s\n', paths{k});
end
fprintf('[init-cache] Future "matlab -batch" calls can skip init_simulink_agent_project.\n');
fprintf('[init-cache] To revert: init_simulink_agent_project_cache(''clear'')\n');
end
