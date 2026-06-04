function matrix = generate_weak_grid_scr_matrix(varargin)
%GENERATE_WEAK_GRID_SCR_MATRIX Generate a weak-grid scenario matrix artifact.

arguments (Repeating)
    varargin
end

opts = iParseNameValues(varargin{:});
rows = iBuildRows(opts);
matrix = struct();
matrix.case_name = char(opts.CaseName);
matrix.scr_values = opts.ScrValues;
matrix.escr_values = opts.EscrValues;
matrix.pll_gain_scales = opts.PllGainScales;
matrix.gfm_shares = opts.GfmShares;
matrix.fault_types = cellstr(opts.FaultTypes);
matrix.disturbance_times_s = opts.DisturbanceTimes;
matrix.clear_times_s = opts.ClearTimes;
matrix.required_observables = cellstr(opts.RequiredObservables);
matrix.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));
matrix.rows = rows;

outDir = char(opts.OutputDir);
if ~isfolder(outDir)
    mkdir(outDir);
end
jsonPath = fullfile(outDir, sprintf("%s_weak_grid_matrix.json", opts.CaseName));
mdPath = fullfile(outDir, sprintf("%s_weak_grid_matrix.md", opts.CaseName));
iWriteJson(jsonPath, matrix);
iWriteMarkdown(mdPath, matrix);
matrix.json_path = jsonPath;
matrix.report_path = mdPath;
end


function opts = iParseNameValues(varargin)
p = inputParser;
p.addParameter("CaseName", "weak_grid_case", @(x) ischar(x) || isstring(x));
p.addParameter("ScrValues", [1.2 1.5 2 3 5], @(x) isnumeric(x) && isvector(x));
p.addParameter("EscrValues", [], @(x) isnumeric(x) && isvector(x));
p.addParameter("PllGainScales", 1, @(x) isnumeric(x) && isvector(x));
p.addParameter("GfmShares", NaN, @(x) isnumeric(x) && isvector(x));
p.addParameter("FaultTypes", ["none" "three_phase"], @(x) iscellstr(x) || isstring(x));
p.addParameter("DisturbanceTimes", 1, @(x) isnumeric(x) && isvector(x));
p.addParameter("ClearTimes", 0.1, @(x) isnumeric(x) && isvector(x));
p.addParameter("RequiredObservables", ...
    ["Vrms" "P" "Q" "frequency" "dc_link" "current_limit"], ...
    @(x) iscellstr(x) || isstring(x));
p.addParameter("OutputDir", fullfile("build","reports","scenarios"), ...
    @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;
opts.CaseName = string(opts.CaseName);
opts.FaultTypes = string(opts.FaultTypes);
opts.RequiredObservables = string(opts.RequiredObservables);
opts.OutputDir = string(opts.OutputDir);
end


function rows = iBuildRows(opts)
if isempty(opts.EscrValues)
    escrValues = NaN;
else
    escrValues = opts.EscrValues;
end
rows = repmat(iEmptyRow(), 1, iEstimateRows(opts, escrValues));
idx = 0;
for scr = opts.ScrValues
    for escr = escrValues
        for pllScale = opts.PllGainScales
            for gfmShare = opts.GfmShares
                for fault = opts.FaultTypes
                    for tFault = opts.DisturbanceTimes
                        for clearTime = opts.ClearTimes
                            idx = idx + 1;
                            rows(idx) = iMakeRow(idx, scr, escr, pllScale, ...
                                gfmShare, fault, tFault, clearTime);
                        end
                    end
                end
            end
        end
    end
end
rows = rows(1:idx);
end


function n = iEstimateRows(opts, escrValues)
n = numel(opts.ScrValues) * numel(escrValues) * numel(opts.PllGainScales) * ...
    numel(opts.GfmShares) * numel(opts.FaultTypes) * ...
    numel(opts.DisturbanceTimes) * numel(opts.ClearTimes);
end


function row = iEmptyRow()
row = struct("id","", "scr",NaN, "escr",NaN, "pll_gain_scale",NaN, ...
    "gfm_share",NaN, "fault_type","", "disturbance_time_s",NaN, ...
    "clear_time_s",NaN, "notes","");
end


function row = iMakeRow(idx, scr, escr, pllScale, gfmShare, fault, tFault, clearTime)
row = iEmptyRow();
row.id = sprintf("WG%04d", idx);
row.scr = scr;
row.escr = escr;
row.pll_gain_scale = pllScale;
row.gfm_share = gfmShare;
row.fault_type = char(fault);
row.disturbance_time_s = tFault;
row.clear_time_s = clearTime;
row.notes = "planned";
end


function iWriteJson(path, matrix)
fid = fopen(path, "w");
if fid < 0
    error("WeakGridMatrix:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(matrix, "PrettyPrint", true));
end


function iWriteMarkdown(path, matrix)
fid = fopen(path, "w");
if fid < 0
    error("WeakGridMatrix:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Weak-Grid SCR Scenario Matrix\n\n");
fprintf(fid, "Case: `%s`\n", matrix.case_name);
fprintf(fid, "Generated: %s\n", matrix.generated_at);
fprintf(fid, "Rows: %d\n\n", numel(matrix.rows));
fprintf(fid, "Required observables: %s\n\n", ...
    strjoin(string(matrix.required_observables), ", "));
fprintf(fid, "| ID | SCR | ESCR | PLL scale | GFM share | Fault | t fault | clear |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---|---:|---:|\n");
for k = 1:numel(matrix.rows)
    r = matrix.rows(k);
    fprintf(fid, "| %s | %.4g | %.4g | %.4g | %.4g | %s | %.4g | %.4g |\n", ...
        r.id, r.scr, r.escr, r.pll_gain_scale, r.gfm_share, ...
        r.fault_type, r.disturbance_time_s, r.clear_time_s);
end
end
