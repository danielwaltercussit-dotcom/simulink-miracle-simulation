function mapping = map_average_to_switching_state(varargin)
%MAP_AVERAGE_TO_SWITCHING_STATE Map averaged-model states to switching init conditions.
%   mapping = map_average_to_switching_state("InductorCurrent",20, ...
%       "Duty",0.4,"Vdc",100,"CarrierFreqHz",2000, ...)
%
%   Given the states of an averaged converter model at an operating point, this
%   computes the initial conditions a detailed switching model needs to start
%   from the same point, plus a continuity residual that says whether the
%   mapping is self-consistent:
%
%     - inductor current carries over directly (a shared state variable);
%     - the carrier phase is a FREE initialization the mapping must DECLARE,
%       not hide (default 0);
%     - the instantaneous switch output q(0) is reconstructed by comparing the
%       averaged duty against the carrier at the chosen phase;
%     - the one-carrier-cycle mean of the reconstructed switched output is
%       compared against the averaged output voltage (Vdc*duty). The relative
%       mismatch is the continuity residual.
%
%   This is a STATE-MAPPING + consistency helper. It does NOT run a model. A
%   small mapping residual means the mapping is internally consistent
%   (contract-level); it is NOT proof that a simulation stays continuous. Use
%   run_fidelity_switch_prototype + summarize_fidelity_switch_evidence for the
%   model-backed (measured) check.
%
%   Artifacts:
%     build/reports/e2_fidelity_switching/<case>/state_mapping.{md,json}

arguments (Repeating)
    varargin
end

opts = iParse(varargin{:});
outDir = char(opts.OutputDir);
if ~isfolder(outDir)
    mkdir(outDir);
end

mapping = struct();
mapping.case_name = char(opts.CaseName);
mapping.inductor_current_a = double(opts.InductorCurrent);
mapping.duty = double(opts.Duty);
mapping.vdc_v = double(opts.Vdc);
mapping.carrier_freq_hz = double(opts.CarrierFreqHz);
mapping.carrier_phase = double(opts.CarrierPhase);   % in [0,1) of a carrier period
mapping.carrier_cycle_samples = double(opts.CarrierCycleSamples);

% --- Required-field completeness (contract axis) -------------------------
missing = {};
if ~iHasNum(mapping.inductor_current_a); missing{end+1} = 'inductor_current_a'; end
if ~iHasNum(mapping.duty);               missing{end+1} = 'duty'; end
if ~iHasNum(mapping.vdc_v);              missing{end+1} = 'vdc_v'; end
if ~iHasNum(mapping.carrier_freq_hz);    missing{end+1} = 'carrier_freq_hz'; end
mapping.missing_required = missing;

dutyValid = iHasNum(mapping.duty) && mapping.duty >= 0 && mapping.duty <= 1;
mapping.duty_in_range = dutyValid;

% --- Reconstruct switching initial state ---------------------------------
if iHasNum(mapping.vdc_v) && dutyValid
    mapping.averaged_output_v = mapping.vdc_v * mapping.duty;
else
    mapping.averaged_output_v = NaN;
end

% Switching initial conditions handed to the detailed model.
ic = struct();
ic.inductor_current_a = mapping.inductor_current_a;   % continuity of the state
ic.carrier_phase = mapping.carrier_phase;
[q0, cycleMean, residual] = iReconstruct(mapping.duty, mapping.carrier_phase, ...
    mapping.vdc_v, mapping.carrier_cycle_samples, dutyValid);
ic.switch_state_q0 = q0;
mapping.switching_initial_conditions = ic;
mapping.reconstructed_cycle_mean_v = cycleMean;

% --- Continuity residual (relative) --------------------------------------
mapping.continuity_residual_abs = residual;
if iHasNum(mapping.averaged_output_v) && mapping.averaged_output_v ~= 0
    mapping.continuity_residual_rel = residual / abs(mapping.averaged_output_v);
else
    mapping.continuity_residual_rel = NaN;
end
mapping.residual_tol = double(opts.ResidualTol);

% --- Contract status (consistency only; NOT model-backed) ----------------
consistent = isempty(missing) && dutyValid && ...
    iHasNum(mapping.continuity_residual_rel) && ...
    (mapping.continuity_residual_rel <= mapping.residual_tol);
if consistent
    mapping.contract_status = 'consistent';
else
    mapping.contract_status = 'provisional';
end
% Make the boundary explicit so callers never read this as a sim result.
mapping.model_validation_status = 'not_run';
mapping.note = ['state-mapping consistency only; not model-backed. ' ...
    'run the prototype simulation for measured equivalence.'];
mapping.generated_at = char(datetime("now","Format","yyyy-MM-dd HH:mm:ss"));

jsonPath = fullfile(outDir, "state_mapping.json");
mdPath = fullfile(outDir, "state_mapping.md");
iWriteJson(jsonPath, mapping);
iWriteMarkdown(mdPath, mapping);
mapping.json_path = char(jsonPath);
mapping.report_path = char(mdPath);
end

function opts = iParse(varargin)
p = inputParser;
isText = @(x) ischar(x) || isstring(x);
isScalarNum = @(x) isnumeric(x) && isscalar(x);
p.addParameter("CaseName", "state_map_case", isText);
p.addParameter("InductorCurrent", NaN, isScalarNum);
p.addParameter("Duty", NaN, isScalarNum);
p.addParameter("Vdc", NaN, isScalarNum);
p.addParameter("CarrierFreqHz", NaN, isScalarNum);
p.addParameter("CarrierPhase", 0, isScalarNum);
p.addParameter("CarrierCycleSamples", 1000, isScalarNum);
p.addParameter("ResidualTol", 1e-3, isScalarNum);
p.addParameter("OutputDir", fullfile("build","reports","e2_fidelity_switching","state_map"), isText);
p.parse(varargin{:});
opts = p.Results;
end


function tf = iHasNum(x)
tf = isnumeric(x) && isscalar(x) && ~isnan(x);
end


function [q0, cycleMean, residual] = iReconstruct(duty, phase, vdc, nSamp, dutyValid)
% Reconstruct one carrier cycle of the trailing-edge PWM switched output and
% compare its mean against the averaged output Vdc*duty.
if ~dutyValid || ~iHasNum(vdc)
    q0 = NaN; cycleMean = NaN; residual = NaN;
    return
end
n = max(2, round(nSamp));
% Normalized carrier ramp in [0,1) starting at the declared phase.
tau = mod((0:n-1)/n + phase, 1);
% q=1 while ramp < duty (trailing-edge modulation).
q = double(tau < duty);
sw = vdc * q;
cycleMean = mean(sw);
q0 = q(1);
residual = abs(cycleMean - vdc*duty);
end


function iWriteJson(path, s)
fid = fopen(path, "w");
if fid < 0
    error("StateMap:CannotWriteJson", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(s, "PrettyPrint", true));
end


function iWriteMarkdown(path, s)
fid = fopen(path, "w");
if fid < 0
    error("StateMap:CannotWriteMarkdown", "Cannot write %s", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Average -> Switching State Mapping\n\n");
fprintf(fid, "Case: `%s`\n", s.case_name);
fprintf(fid, "Contract status: **%s**\n", upper(s.contract_status));
fprintf(fid, "Model validation: **%s**\n", upper(s.model_validation_status));
fprintf(fid, "Generated: %s\n\n", s.generated_at);
fprintf(fid, "> %s\n\n", s.note);

fprintf(fid, "## Averaged States In\n\n");
fprintf(fid, "| Field | Value |\n|---|---|\n");
fprintf(fid, "| inductor_current_a | %s |\n", iNum(s.inductor_current_a));
fprintf(fid, "| duty | %s |\n", iNum(s.duty));
fprintf(fid, "| vdc_v | %s |\n", iNum(s.vdc_v));
fprintf(fid, "| carrier_freq_hz | %s |\n", iNum(s.carrier_freq_hz));
fprintf(fid, "| averaged_output_v | %s |\n\n", iNum(s.averaged_output_v));

fprintf(fid, "## Switching Initial Conditions Out\n\n");
ic = s.switching_initial_conditions;
fprintf(fid, "| Field | Value |\n|---|---|\n");
fprintf(fid, "| inductor_current_a | %s |\n", iNum(ic.inductor_current_a));
fprintf(fid, "| carrier_phase | %s |\n", iNum(ic.carrier_phase));
fprintf(fid, "| switch_state_q0 | %s |\n", iNum(ic.switch_state_q0));
fprintf(fid, "| reconstructed_cycle_mean_v | %s |\n\n", iNum(s.reconstructed_cycle_mean_v));

fprintf(fid, "## Continuity Residual\n\n");
fprintf(fid, "| Field | Value |\n|---|---|\n");
fprintf(fid, "| continuity_residual_abs | %s |\n", iNum(s.continuity_residual_abs));
fprintf(fid, "| continuity_residual_rel | %s |\n", iNum(s.continuity_residual_rel));
fprintf(fid, "| residual_tol | %s |\n", iNum(s.residual_tol));
if ~isempty(s.missing_required)
    fprintf(fid, "\n## Missing Required\n\n");
    for k = 1:numel(s.missing_required)
        fprintf(fid, "- %s\n", s.missing_required{k});
    end
end
fprintf(fid, "\n");
end


function out = iNum(value)
if isnumeric(value) && isscalar(value) && ~isnan(value)
    out = sprintf('%g', value);
else
    out = '(n/a)';
end
end
