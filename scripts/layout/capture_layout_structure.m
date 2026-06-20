function snapshot = capture_layout_structure(modelName, varargin)
%CAPTURE_LAYOUT_STRUCTURE Capture layout-invariant Simulink structure.
%   The snapshot excludes block positions and line points. It records block
%   inventory, resolvable signal connectivity, total lines, and lines that
%   Simulink explicitly marks disconnected. Physical SPS/Simscape lines with
%   unresolved port handles are counted without being declared invalid.

p = inputParser;
p.addParameter('Scope', modelName, @(x) ischar(x) || isstring(x));
p.parse(varargin{:});

modelName = char(modelName);
scope = char(p.Results.Scope);
load_model_if_needed(modelName);

blocks = find_system(scope, 'LookUnderMasks', 'all', 'FollowLinks', 'off', ...
    'Type', 'Block');
blockSignatures = cell(numel(blocks), 1);
for k = 1:numel(blocks)
    blockSignatures{k} = block_signature(blocks{k});
end
blockSignatures = sort(blockSignatures);

lines = find_system(scope, 'FindAll', 'on', 'LookUnderMasks', 'all', ...
    'FollowLinks', 'off', 'Type', 'line');
lines = unique(lines, 'stable');
connections = {};
unresolvedCount = 0;
disconnectedCount = 0;

for k = 1:numel(lines)
    try
        disconnectedCount = disconnectedCount + ...
            strcmp(get_param(lines(k), 'Connected'), 'off');
    catch
    end

    signature = connection_signature(lines(k));
    if isempty(signature)
        unresolvedCount = unresolvedCount + 1;
    else
        connections{end+1, 1} = signature; %#ok<AGROW>
    end
end

snapshot = struct( ...
    'schema_version', 1, ...
    'model', modelName, ...
    'scope', scope, ...
    'block_signatures', {blockSignatures}, ...
    'resolved_connections', {sort(connections)}, ...
    'block_count', numel(blockSignatures), ...
    'line_count', numel(lines), ...
    'resolved_connection_count', numel(connections), ...
    'unresolved_line_count', unresolvedCount, ...
    'disconnected_line_count', disconnectedCount);
end

function load_model_if_needed(modelName)
if ~bdIsLoaded(modelName)
    load_system(modelName);
end
end

function signature = block_signature(blockPath)
blockType = safe_param(blockPath, 'BlockType');
referenceBlock = safe_param(blockPath, 'ReferenceBlock');
ports = [];
try
    ports = get_param(blockPath, 'Ports');
catch
end
signature = sprintf('%s|%s|%s|%s', char(blockPath), blockType, ...
    referenceBlock, mat2str(ports));
end

function signature = connection_signature(lineHandle)
signature = '';
try
    srcPort = get_param(lineHandle, 'SrcPortHandle');
    dstPorts = get_param(lineHandle, 'DstPortHandle');
catch
    return
end

if isempty(srcPort) || any(srcPort < 0) || isempty(dstPorts) || any(dstPorts < 0)
    return
end

src = port_signature(srcPort(1));
dst = cell(numel(dstPorts), 1);
for k = 1:numel(dstPorts)
    dst{k} = port_signature(dstPorts(k));
end
signature = [src '->' strjoin(sort(dst), ',')];
end

function value = port_signature(portHandle)
parent = get_param(portHandle, 'Parent');
if isnumeric(parent)
    parent = getfullname(parent);
else
    parent = char(parent);
end
portNumber = safe_param(portHandle, 'PortNumber');
portType = safe_param(portHandle, 'PortType');
value = sprintf('%s:%s:%s', parent, portType, portNumber);
end

function value = safe_param(handle, name)
value = '';
try
    raw = get_param(handle, name);
    if isnumeric(raw) || islogical(raw)
        value = mat2str(raw);
    else
        value = char(raw);
    end
catch
end
end
