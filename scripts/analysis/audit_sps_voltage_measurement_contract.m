function result = audit_sps_voltage_measurement_contract(modelRef, varargin)
%AUDIT_SPS_VOLTAGE_MEASUREMENT_CONTRACT Verify SPS VI output units and mode.
% This audit prevents a healthy physical-voltage signal from being mistaken
% for a dead bus when a per-unit output is divided by base voltage again.

p = inputParser;
p.addRequired('modelRef', @(x)ischar(x) || isstring(x));
p.addParameter('MeasurementBlocks', strings(0,1));
p.addParameter('ExpectedVoltageMeasurement', 'phase-to-phase');
p.addParameter('ExpectedVpu', 'off');
p.addParameter('ExpectedVpuLL', 'off');
p.addParameter('ReportPath', '');
p.parse(modelRef, varargin{:});
opt = p.Results;

[modelName, loadedHere] = load_model_ref(char(modelRef));
cleanup = onCleanup(@()close_if_loaded_here(modelName, loadedHere));
blocks = string(opt.MeasurementBlocks);
if isempty(blocks)
    error('AIInLoop:VoltageMeasurementContractFail', ...
        'MeasurementBlocks must list the VI measurement blocks to audit.');
end

rows = struct('block', {}, 'exists', {}, 'maskType', {}, ...
    'voltageMeasurement', {}, 'vpu', {}, 'vpuLL', {}, 'labelV', {}, ...
    'verdict', {});
for i = 1:numel(blocks)
    path = modelName + "/" + blocks(i);
    exists = getSimulinkBlockHandle(path) > 0;
    row = struct('block', char(blocks(i)), 'exists', exists, 'maskType', '', ...
        'voltageMeasurement', '', 'vpu', '', 'vpuLL', '', 'labelV', '', ...
        'verdict', 'FAIL');
    if exists
        row.maskType = get_param(path, 'MaskType');
        row.voltageMeasurement = get_param(path, 'VoltageMeasurement');
        row.vpu = get_param(path, 'Vpu');
        row.vpuLL = get_param(path, 'VpuLL');
        row.labelV = get_param(path, 'LabelV');
        isViMeasurement = contains(row.maskType, 'Three-Phase VI Measurement') || ...
            contains(row.maskType, 'Three-Phase V-I Measurement');
        ok = isViMeasurement && ...
            strcmp(row.voltageMeasurement, opt.ExpectedVoltageMeasurement) && ...
            strcmp(row.vpu, opt.ExpectedVpu) && strcmp(row.vpuLL, opt.ExpectedVpuLL);
        if ok, row.verdict = 'PASS'; end
    end
    rows(end+1) = row; %#ok<AGROW>
end

result = struct('model', modelName, 'overall', 'PASS', 'rows', rows, ...
    'interpretation', ['This audit verifies measurement mode and units only; ' ...
    'it does not prove that a bus is electrically energized.']);
if any(strcmp({rows.verdict}, 'FAIL'))
    result.overall = 'FAIL';
end
if ~isempty(opt.ReportPath)
    write_report(opt.ReportPath, result, opt);
end
if strcmp(result.overall, 'FAIL')
    error('AIInLoop:VoltageMeasurementContractFail', ...
        'SPS voltage measurement contract failed. Inspect the generated report.');
end
clear cleanup
end

function [modelName, loadedHere] = load_model_ref(modelRef)
[folder, name, ext] = fileparts(modelRef);
if isempty(ext)
    modelName = modelRef;
    loadedHere = ~bdIsLoaded(modelName);
    if loadedHere, load_system(modelName); end
else
    modelName = name;
    loadedHere = ~bdIsLoaded(modelName);
    if loadedHere, load_system(fullfile(folder, [name ext])); end
end
end

function close_if_loaded_here(modelName, loadedHere)
if loadedHere && bdIsLoaded(modelName), close_system(modelName, 0); end
end

function write_report(path, result, opt)
folder = fileparts(path);
if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
fid = fopen(path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@()fclose(fid));
fprintf(fid, '# SPS Voltage Measurement Contract Audit\n\n');
fprintf(fid, 'Model: `%s`\n\nOverall: **%s**\n\n', result.model, result.overall);
fprintf(fid, 'Expected: `%s`, Vpu=`%s`, VpuLL=`%s`.\n\n', ...
    opt.ExpectedVoltageMeasurement, opt.ExpectedVpu, opt.ExpectedVpuLL);
fprintf(fid, '| Block | Exists | Mode | Vpu | VpuLL | LabelV | Verdict |\n');
fprintf(fid, '|---|---|---|---|---|---|---|\n');
for i = 1:numel(result.rows)
    r = result.rows(i);
    fprintf(fid, '| %s | %d | %s | %s | %s | %s | %s |\n', ...
        r.block, r.exists, r.voltageMeasurement, r.vpu, r.vpuLL, r.labelV, r.verdict);
end
fprintf(fid, '\nThis audit verifies output units and mode. It does not prove electrical energization.\n');
clear cleanup
end
