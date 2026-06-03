function result = generate_fault_scenario_patch(scenarioId, varargin)
%GENERATE_FAULT_SCENARIO_PATCH Write a reusable scenario YAML patch.

p = inputParser;
p.addParameter('ModelName', '', @(x) ischar(x) || isstring(x));
p.addParameter('OutPath', '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opt = p.Results;

scenarioId = char(scenarioId);
result = struct('name','FAULT_SCENARIO_PATCH', 'scenario_id', scenarioId, ...
    'model', char(opt.ModelName), 'status','FAIL', 'passed', false, ...
    'out_path', char(opt.OutPath), 'message','');

[txt, ok] = scenario_text(scenarioId, char(opt.ModelName));
if ~ok
    result.message = ['Unknown scenario: ' scenarioId];
    return
end

if strlength(string(opt.OutPath)) > 0
    outDir = fileparts(char(opt.OutPath));
    if ~isempty(outDir) && ~isfolder(outDir)
        mkdir(outDir);
    end
    fid = fopen(char(opt.OutPath), 'w');
    if fid < 0
        result.message = ['Cannot write ' char(opt.OutPath)];
        return
    end
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', txt);
end

result.patch = txt;
result.status = 'PASS';
result.passed = true;
result.message = 'PASS';
end

function [txt, ok] = scenario_text(id, modelName)
ok = true;
header = sprintf('# Scenario patch generated for %s\nscenario:\n  id: %s\n', modelName, id);
switch id
    case 'voltage_sag_0p5pu_200ms'
        body = sprintf([ ...
            'topology:\n' ...
            '  source:\n' ...
            '    fault_injection: { enabled: true, mode: amplitude_step, t_start_s: 0.5, t_end_s: 0.7, amplitude_pu_during_fault: 0.5 }\n' ...
            'expected_outputs: [Vabc_HV, Iabc_HV]\n' ...
            'pass_metrics: { no_nan: true, recovery_window_s: 1.0, I_osc_growth_max: 1.05 }\n']);
    case 'weak_grid_scr_2p5'
        body = sprintf([ ...
            'topology:\n' ...
            '  weak_tie_line: { R_pu: 0.05, L_pu: 0.40 }\n' ...
            'expected_outputs: [Vabc_HV, Iabc_HV]\n' ...
            'pass_metrics: { no_nan: true, I_osc_growth_max: 1.05 }\n']);
    case 'wind_speed_step'
        body = sprintf([ ...
            'scenario:\n' ...
            '  wind_speed_step: { from_mps: 12, to_mps: 14, t_step_s: 1.0 }\n' ...
            'expected_outputs: [Vabc_HV, Iabc_HV]\n' ...
            'pass_metrics: { no_nan: true, finite_outputs: true }\n']);
    otherwise
        txt = "";
        ok = false;
        return
end
txt = [header body];
end
