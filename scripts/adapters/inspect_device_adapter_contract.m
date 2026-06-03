function result = inspect_device_adapter_contract(modelName, varargin)
%INSPECT_DEVICE_ADAPTER_CONTRACT Inspect root-level device subsystem contracts.
%   This is a lightweight gate for derived power-system models. It checks the
%   adapter-facing surface without editing the model.

p = inputParser;
p.addParameter('ProjectRoot', default_project_root(), @(x) ischar(x) || isstring(x));
p.addParameter('ReportPath', '', @(x) ischar(x) || isstring(x));
p.addParameter('StrictTrace', false, @(x) islogical(x) || isnumeric(x));
p.parse(varargin{:});
opt = p.Results;
opt.ProjectRoot = char(opt.ProjectRoot);
opt.StrictTrace = logical(opt.StrictTrace);

modelName = char(modelName);
result = struct('name','DEVICE_ADAPTER_CONTRACT_INSPECTION', ...
    'model', modelName, 'status','FAIL', 'passed', false, ...
    'checks', struct(), 'devices', repmat(empty_device(), 1, 0), ...
    'warnings', {{}}, 'message','', 'report_path', char(opt.ReportPath));

try
    load_model_if_needed(opt.ProjectRoot, modelName);

    result.checks.self_contained_init = has_self_contained_init(modelName);

    rootBlocks = find_system(modelName, 'SearchDepth', 1, ...
        'LookUnderMasks', 'none', 'FollowLinks', 'off');
    deviceBlocks = {};
    for k = 1:numel(rootBlocks)
        nm = get_param(rootBlocks{k}, 'Name');
        if is_device_name(nm)
            deviceBlocks{end+1} = rootBlocks{k}; %#ok<AGROW>
        end
    end

    result.checks.has_device_subsystems = ~isempty(deviceBlocks);
    result.checks.device_names_unique = true;
    result.checks.device_ports_present = true;
    result.checks.trace_metadata_present = true;

    names = {};
    warnings = {};
    if ~isempty(deviceBlocks)
        result.devices = repmat(empty_device(), 1, numel(deviceBlocks));
    end

    for k = 1:numel(deviceBlocks)
        dev = inspect_device(deviceBlocks{k});
        result.devices(k) = dev;
        names{end+1} = dev.name; %#ok<AGROW>
        result.checks.device_ports_present = result.checks.device_ports_present && dev.has_adapter_ports;
        result.checks.trace_metadata_present = result.checks.trace_metadata_present && dev.has_trace_metadata;
        if ~dev.has_trace_metadata
            warnings{end+1} = sprintf('%s has no trace UserData metadata', dev.name); %#ok<AGROW>
        end
    end
    result.warnings = warnings;

    if ~isempty(names)
        result.checks.device_names_unique = numel(unique(names)) == numel(names);
    end

    essential = result.checks.has_device_subsystems ...
        && result.checks.device_names_unique ...
        && result.checks.device_ports_present ...
        && result.checks.self_contained_init;
    if opt.StrictTrace
        essential = essential && result.checks.trace_metadata_present;
    end

    result.passed = essential;
    if result.passed
        result.status = 'PASS';
        result.message = 'PASS';
    else
        result.message = build_failure_message(result.checks, opt.StrictTrace);
    end
catch ME
    result.message = ME.message;
    result.error_id = ME.identifier;
end

if strlength(string(opt.ReportPath)) > 0
    write_adapter_report(char(opt.ReportPath), result);
end
end

function root = default_project_root()
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
end

function load_model_if_needed(projectRoot, modelName)
if bdIsLoaded(modelName)
    return
end
candidate = fullfile(projectRoot, 'build', 'generated_models', [modelName '.slx']);
if isfile(candidate)
    load_system(candidate);
else
    load_system(modelName);
end
end

function tf = has_self_contained_init(modelName)
initFcn = get_param(modelName, 'InitFcn');
tf = contains(initFcn, 'Ts') || contains(initFcn, 'Tsample') || ~isempty(strtrim(initFcn));
end

function tf = is_device_name(name)
name = char(name);
    patterns = {'^DFIG', '^W\d+', '^G\d+', '^SG', '^VSC', '^MMC', '^LCC', ...
    'BESS', 'Storage', 'wind farm', 'WIND FARM', 'Load', 'RLC', ...
    'Transformer', 'Xfmr', '^Line', 'Tie[-_ ]?Line', '^Bus[_ ]?\d+'};
tf = false;
for k = 1:numel(patterns)
    if ~isempty(regexpi(name, patterns{k}, 'once'))
        tf = true;
        return
    end
end
end

function dev = inspect_device(blockPath)
dev = empty_device();
dev.name = get_param(blockPath, 'Name');
dev.block_path = blockPath;
dev.sid = safe_sid(blockPath);
dev.block_type = get_param(blockPath, 'BlockType');
dev.mask_names = safe_mask_names(blockPath);

ports = get_param(blockPath, 'PortHandles');
dev.signal_inports = numel(ports.Inport);
dev.signal_outports = numel(ports.Outport);
dev.physical_lconn = count_field(ports, 'LConn');
dev.physical_rconn = count_field(ports, 'RConn');
dev.has_physical_ports = (dev.physical_lconn + dev.physical_rconn) > 0;
dev.has_signal_ports = (dev.signal_inports + dev.signal_outports) > 0;
dev.has_adapter_ports = dev.has_physical_ports || dev.has_signal_ports;

ud = get_param(blockPath, 'UserData');
dev.has_trace_metadata = isstruct(ud) && ...
    (isfield(ud, 'trace_id') || isfield(ud, 'id') || isfield(ud, 'source_spec'));
end

function sid = safe_sid(blockPath)
sid = '';
try
    sid = Simulink.ID.getSID(blockPath);
catch
end
end

function names = safe_mask_names(blockPath)
names = {};
try
    names = get_param(blockPath, 'MaskNames');
catch
end
end

function n = count_field(s, fieldName)
if isfield(s, fieldName)
    n = numel(s.(fieldName));
else
    n = 0;
end
end

function dev = empty_device()
dev = struct('name','', 'block_path','', 'sid','', 'block_type','', ...
    'signal_inports',0, 'signal_outports',0, 'physical_lconn',0, ...
    'physical_rconn',0, 'has_physical_ports',false, ...
    'has_signal_ports',false, 'has_adapter_ports',false, ...
    'mask_names', {{}}, 'has_trace_metadata',false);
end

function msg = build_failure_message(checks, strictTrace)
failed = {};
names = fieldnames(checks);
for k = 1:numel(names)
    name = names{k};
    if strcmp(name, 'trace_metadata_present') && ~strictTrace
        continue
    end
    value = checks.(name);
    if islogical(value) && isscalar(value) && ~value
        failed{end+1} = name; %#ok<AGROW>
    end
end
msg = ['Failed checks: ' strjoin(failed, ', ')];
end

function write_adapter_report(path, result)
reportDir = fileparts(path);
if ~isempty(reportDir) && ~isfolder(reportDir)
    mkdir(reportDir);
end
fid = fopen(path, 'w');
if fid < 0
    warning('InspectDeviceAdapter:CannotWriteReport', 'Cannot write %s', path);
    return
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Device Adapter Contract Inspection\n\n');
fprintf(fid, '- model: `%s`\n', result.model);
fprintf(fid, '- status: `%s`\n', result.status);
fprintf(fid, '- message: %s\n\n', result.message);

fprintf(fid, '## Checks\n\n');
names = fieldnames(result.checks);
for k = 1:numel(names)
    fprintf(fid, '- %s: `%s`\n', names{k}, mat2str(result.checks.(names{k})));
end

if ~isempty(result.warnings)
    fprintf(fid, '\n## Warnings\n\n');
    for k = 1:numel(result.warnings)
        fprintf(fid, '- %s\n', result.warnings{k});
    end
end

fprintf(fid, '\n## Devices\n\n');
for k = 1:numel(result.devices)
    dev = result.devices(k);
    fprintf(fid, '### %s\n\n', dev.name);
    fprintf(fid, '- block_path: `%s`\n', dev.block_path);
    fprintf(fid, '- sid: `%s`\n', dev.sid);
    fprintf(fid, '- signal_inports: %d\n', dev.signal_inports);
    fprintf(fid, '- signal_outports: %d\n', dev.signal_outports);
    fprintf(fid, '- physical_lconn: %d\n', dev.physical_lconn);
    fprintf(fid, '- physical_rconn: %d\n', dev.physical_rconn);
    fprintf(fid, '- has_trace_metadata: `%s`\n', mat2str(dev.has_trace_metadata));
    if ~isempty(dev.mask_names)
        fprintf(fid, '- mask_names: `%s`\n', strjoin(dev.mask_names, ', '));
    end
    fprintf(fid, '\n');
end
end
