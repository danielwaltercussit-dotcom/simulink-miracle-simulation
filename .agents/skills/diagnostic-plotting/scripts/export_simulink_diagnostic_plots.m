function manifest = export_simulink_diagnostic_plots(modelName, varargin)
%EXPORT_SIMULINK_DIAGNOSTIC_PLOTS Export logsout figures and a manifest.
%
% manifest = export_simulink_diagnostic_plots("my_model", ...
%     "SimulationOutput", out, ...
%     "OutputDir", "build/reports/diagnostics/my_model/latest")

p = inputParser;
p.addRequired('modelName', @(x) ischar(x) || isstring(x));
p.addParameter('SimulationOutput', [], @(x) true);
p.addParameter('MatFile', "", @(x) ischar(x) || isstring(x));
p.addParameter('OutputDir', "", @(x) ischar(x) || isstring(x));
p.addParameter('Signals', strings(1,0), @(x) iscellstr(x) || isstring(x));
p.addParameter('MaxSignals', 12, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.addParameter('FigureFormat', "png", @(x) any(strcmpi(string(x), ["png","jpg","jpeg","pdf"])));
p.addParameter('StatusJson', "", @(x) ischar(x) || isstring(x));
p.parse(modelName, varargin{:});
opt = p.Results;

modelName = char(string(modelName));
fmt = lower(char(string(opt.FigureFormat)));
outDir = string(opt.OutputDir);
if strlength(outDir) == 0
    runId = string(datetime('now','Format','yyyyMMdd''T''HHmmss'));
    outDir = fullfile("build", "reports", "diagnostics", string(modelName), runId);
end
outDir = char(outDir);
if ~isfolder(outDir)
    mkdir(outDir);
end

[sourceObj, sourceLabel] = resolve_source(opt.SimulationOutput, opt.MatFile);
logsout = resolve_logsout(sourceObj);
requested = string(opt.Signals);
[signalNames, missingSignals] = choose_signals(logsout, requested, opt.MaxSignals);

figures = empty_figure_array();
overview = struct('names', strings(1,0), 't', {{}}, 'y', {{}});

for k = 1:numel(signalNames)
    sigName = signalNames(k);
    element = logsout.get(char(sigName));
    values = resolve_values(element);
    [t, data, ok] = extract_time_data(values);
    if ~ok
        continue
    end

    [plotData, channelsTotal, channelsPlotted] = select_plot_channels(data);
    metrics = compute_metrics(data);
    figPath = fullfile(outDir, sprintf('signal_%s.%s', safe_name(sigName), fmt));
    write_signal_figure(figPath, fmt, modelName, sigName, t, plotData);

    figures(end+1) = make_figure_entry("signal", sigName, figPath, ...
        numel(t), channelsTotal, channelsPlotted, metrics); %#ok<AGROW>

    if channelsTotal == 1 && numel(overview.names) < 6
        overview.names(end+1) = sigName;
        overview.t{end+1} = t;
        overview.y{end+1} = normalize_for_overview(plotData(:,1));
    end
end

if ~isempty(overview.names)
    overviewPath = fullfile(outDir, ['overview.' fmt]);
    write_overview_figure(overviewPath, fmt, modelName, overview);
    figures = [make_figure_entry("overview", "overview", overviewPath, ...
        0, 0, 0, empty_metrics()), figures];
end

manifest = struct();
manifest.model = modelName;
manifest.created_at = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
manifest.output_dir = outDir;
manifest.source = sourceLabel;
manifest.status_json = char(string(opt.StatusJson));
manifest.signals_requested = cellstr(requested);
manifest.missing_signals = cellstr(missingSignals);
manifest.figures = figures;

write_text(fullfile(outDir, 'figure_manifest.json'), jsonencode(manifest));
write_index(fullfile(outDir, 'index.md'), manifest);
end

function [sourceObj, sourceLabel] = resolve_source(sourceObj, matFile)
sourceLabel = 'SimulationOutput argument';
if ~isempty(sourceObj)
    return
end
matFile = string(matFile);
if strlength(matFile) == 0
    error('DiagnosticPlotting:MissingSource', ...
        'Pass SimulationOutput or MatFile containing out, simOut, or simulationOutput.');
end
loaded = load(char(matFile));
candidateNames = ["out", "simOut", "simulationOutput"];
for k = 1:numel(candidateNames)
    name = candidateNames(k);
    if isfield(loaded, char(name))
        sourceObj = loaded.(char(name));
        sourceLabel = char(matFile);
        return
    end
end
error('DiagnosticPlotting:MatFileMissingOutput', ...
    'MatFile must contain out, simOut, or simulationOutput.');
end

function logsout = resolve_logsout(sourceObj)
if isa(sourceObj, 'Simulink.SimulationData.Dataset')
    logsout = sourceObj;
    return
end
if isa(sourceObj, 'Simulink.SimulationOutput')
    names = who(sourceObj);
    if any(strcmp(names, 'logsout'))
        logsout = sourceObj.logsout;
        return
    end
end
error('DiagnosticPlotting:MissingLogsout', ...
    'The source does not contain a logsout dataset.');
end

function [signalNames, missingSignals] = choose_signals(logsout, requested, maxSignals)
allNames = string(logsout.getElementNames);
missingSignals = strings(1,0);
if isempty(requested)
    signalNames = allNames(1:min(numel(allNames), maxSignals));
    return
end
signalNames = strings(1,0);
for k = 1:numel(requested)
    if any(allNames == requested(k))
        signalNames(end+1) = requested(k); %#ok<AGROW>
    else
        missingSignals(end+1) = requested(k); %#ok<AGROW>
    end
end
end

function values = resolve_values(element)
if isobject(element) && isprop(element, 'Values')
    values = element.Values;
else
    values = element;
end
end

function [t, data, ok] = extract_time_data(values)
ok = false;
t = [];
data = [];
if isa(values, 'timeseries')
    t = values.Time(:);
    data = values.Data;
elseif istimetable(values)
    t = values.Properties.RowTimes;
    if isduration(t)
        t = seconds(t);
    else
        t = seconds(t - t(1));
    end
    data = table2array(timetable2table(values, 'ConvertRowTimes', false));
else
    return
end
if ~isnumeric(data) || isempty(t)
    return
end
data = squeeze(data);
if isvector(data)
    data = data(:);
elseif size(data,1) ~= numel(t) && size(data,2) == numel(t)
    data = data.';
end
if size(data,1) ~= numel(t)
    data = reshape(data, numel(t), []);
end
ok = true;
end

function [plotData, channelsTotal, channelsPlotted] = select_plot_channels(data)
data = reshape(data, size(data,1), []);
channelsTotal = size(data,2);
channelsPlotted = min(channelsTotal, 3);
plotData = data(:, 1:channelsPlotted);
end

function metrics = compute_metrics(data)
vals = data(:);
metrics = empty_metrics();
metrics.nan_count = sum(isnan(vals));
metrics.inf_count = sum(isinf(vals));
finiteVals = vals(isfinite(vals));
metrics.finite = ~isempty(finiteVals) && metrics.nan_count == 0 && metrics.inf_count == 0;
if isempty(finiteVals)
    return
end
metrics.min = min(finiteVals);
metrics.max = max(finiteVals);
metrics.rms = sqrt(mean(finiteVals.^2));
metrics.peak_abs = max(abs(finiteVals));
end

function metrics = empty_metrics()
metrics = struct('nan_count', 0, 'inf_count', 0, 'finite', true, ...
    'min', NaN, 'max', NaN, 'rms', NaN, 'peak_abs', NaN);
end

function entry = make_figure_entry(kind, signalName, figPath, samples, channelsTotal, channelsPlotted, metrics)
entry = struct();
entry.kind = char(string(kind));
entry.signal = char(string(signalName));
entry.path = char(string(figPath));
entry.samples = samples;
entry.channels_total = channelsTotal;
entry.channels_plotted = channelsPlotted;
entry.nan_count = metrics.nan_count;
entry.inf_count = metrics.inf_count;
entry.finite = metrics.finite;
entry.min = metrics.min;
entry.max = metrics.max;
entry.rms = metrics.rms;
entry.peak_abs = metrics.peak_abs;
end

function figures = empty_figure_array()
figures = repmat(make_figure_entry("", "", "", 0, 0, 0, empty_metrics()), 0, 1);
end

function write_signal_figure(figPath, fmt, modelName, sigName, t, data)
fig = figure('Visible','off','Color','w');
cleanup = onCleanup(@() close(fig));
plot(t, data, 'LineWidth', 1.1);
grid on;
xlabel('Time (s)');
ylabel('Value');
title(sprintf('%s: %s', modelName, char(sigName)), 'Interpreter', 'none');
if size(data,2) > 1
    legend(compose('ch%d', 1:size(data,2)), 'Location', 'best');
end
export_figure(fig, figPath, fmt);
end

function write_overview_figure(figPath, fmt, modelName, overview)
fig = figure('Visible','off','Color','w');
cleanup = onCleanup(@() close(fig));
hold on;
for k = 1:numel(overview.names)
    plot(overview.t{k}, overview.y{k}, 'LineWidth', 1.0, ...
        'DisplayName', char(overview.names(k)));
end
hold off;
grid on;
xlabel('Time (s)');
ylabel('Normalized value');
title(sprintf('%s diagnostic overview', modelName), 'Interpreter', 'none');
legend('Location', 'best', 'Interpreter', 'none');
export_figure(fig, figPath, fmt);
end

function y = normalize_for_overview(y)
y = y(:);
finiteVals = y(isfinite(y));
if isempty(finiteVals)
    return
end
scale = max(abs(finiteVals));
if scale > 0
    y = y ./ scale;
end
end

function export_figure(fig, figPath, fmt)
switch lower(fmt)
    case 'pdf'
        exportgraphics(fig, figPath, 'ContentType', 'vector');
    otherwise
        exportgraphics(fig, figPath, 'Resolution', 150);
end
end

function write_index(indexPath, manifest)
fid = fopen(indexPath, 'w');
if fid < 0
    error('DiagnosticPlotting:IndexWriteFailed', 'Cannot write %s', indexPath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Diagnostic Figures\n\n');
fprintf(fid, '- model: `%s`\n', manifest.model);
fprintf(fid, '- created_at: %s\n', manifest.created_at);
fprintf(fid, '- source: `%s`\n', manifest.source);
fprintf(fid, '- manifest: `figure_manifest.json`\n\n');
if ~isempty(manifest.missing_signals)
    fprintf(fid, '## Missing Signals\n\n');
    for k = 1:numel(manifest.missing_signals)
        fprintf(fid, '- `%s`\n', manifest.missing_signals{k});
    end
    fprintf(fid, '\n');
end
fprintf(fid, '## Figures\n\n');
for k = 1:numel(manifest.figures)
    f = manifest.figures(k);
    [~, name, ext] = fileparts(f.path);
    fprintf(fid, '- `%s`: `%s%s`', f.kind, name, ext);
    if strlength(string(f.signal)) > 0
        fprintf(fid, ' signal=`%s`', f.signal);
    end
    fprintf(fid, ' finite=`%s` nan=%d inf=%d\n', mat2str(f.finite), f.nan_count, f.inf_count);
end
end

function write_text(path, text)
fid = fopen(path, 'w');
if fid < 0
    error('DiagnosticPlotting:WriteFailed', 'Cannot write %s', path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', text);
end

function name = safe_name(raw)
name = regexprep(char(string(raw)), '[^A-Za-z0-9_]+', '_');
name = regexprep(name, '_+', '_');
name = regexprep(name, '^_|_$', '');
if isempty(name)
    name = 'signal';
end
end
