function analysis = ai_in_loop_stage_tuning_analysis(projectRoot, modelName, reg, metrics, round, iterDir, opt)
%AI_IN_LOOP_STAGE_TUNING_ANALYSIS Re-linearize and rank S6 knob directions.
% Each registered knob is perturbed along one relative group direction. The
% model is changed only in memory and restored before this function returns.

analysis = struct('name','S6A_MATHEMATICAL_CANDIDATES','status','SKIPPED', ...
    'sensitivity',struct(),'report_path','','candidate_count',0,'note','');
if isempty(reg) || ~isfield(metrics,'fs_signature') || isempty(metrics.fs_signature)
    analysis.note = 'registry or failure signature unavailable';
    return
end

eligible = false(1,numel(reg));
for k = 1:numel(reg)
    [writable, ~] = tuning_entry_is_writable(reg(k));
    eligible(k) = writable && any(strcmp(reg(k).fs_targets, metrics.fs_signature)) && ...
        isnumeric(reg(k).current) && all(isfinite(reg(k).current(:))) && ...
        all(reg(k).current(:) > 0);
end
reg = reg(eligible);
if isempty(reg)
    analysis.note = sprintf('no writable positive-valued knob targets %s', metrics.fs_signature);
    return
end
truncated = false;
if numel(reg) > opt.modal_sensitivity_max_knobs
    rank = table([reg.priority].',string({reg.id}).',(1:numel(reg)).', ...
        'VariableNames',{'priority','id','index'});
    rank = sortrows(rank,{'priority','id'});
    reg = reg(rank.index(1:opt.modal_sensitivity_max_knobs));
    truncated = true;
end

addpath(fullfile(projectRoot,'scripts','analysis'));
modelName = char(modelName);
baseValues = cell(1,numel(reg));
lowerRelative = zeros(1,numel(reg));
upperRelative = zeros(1,numel(reg));
for k = 1:numel(reg)
    baseValues{k} = reg(k).current;
    lowerRelative(k) = max((reg(k).min - baseValues{k}) ./ baseValues{k}, [], 'all');
    upperRelative(k) = min((reg(k).max - baseValues{k}) ./ baseValues{k}, [], 'all');
end
lowerRelative = max(lowerRelative, -opt.modal_sensitivity_max_relative_step);
upperRelative = min(upperRelative, opt.modal_sensitivity_max_relative_step);

initialDirty = get_param(modelName,'Dirty');
restore = onCleanup(@() iRestore(modelName,reg,baseValues,initialDirty));
matrixFcn = @(relative) iLinearizeRelative(modelName,reg,baseValues,relative,opt.modal_ts);
try
    derivative = estimate_state_matrix_parameter_derivatives(zeros(1,numel(reg)), matrixFcn, ...
        'ParameterNames', string({reg.id}), ...
        'LowerBounds', lowerRelative, 'UpperBounds', upperRelative, ...
        'AbsoluteStep', opt.modal_sensitivity_step, ...
        'OperatingPointTolerance', opt.modal_operating_point_tolerance);
catch ME
    analysis.note = sprintf('parameter derivative failed: %s', ME.message);
    return
end

roundDir = fullfile(iterDir, sprintf('tuning_analysis_round_%02d',round));
try
    sensitivity = summarize_modal_parameter_sensitivity(derivative.A, derivative.dAdp, ...
        derivative.parameter_names, 'CaseName', sprintf('%s_s6_round_%02d',modelName,round), ...
        'ParameterValues', zeros(1,numel(reg)), 'ParameterScales', ones(1,numel(reg)), ...
        'LowerBounds', lowerRelative, 'UpperBounds', upperRelative, ...
        'TargetDampingRatio', opt.modal_target_damping, ...
        'MaxRelativeStep', opt.modal_sensitivity_max_relative_step, ...
        'MatrixSource', 'dlinmod_parameter_perturbation', ...
        'MatrixDomain', 'discrete', 'SampleTime', opt.modal_ts, ...
        'OperatingPoint', 'current S6 model state; acceptance requires re-linearization and time-domain check', ...
        'OutputDir', roundDir);
catch ME
    analysis.note = sprintf('modal sensitivity failed: %s', ME.message);
    return
end

analysis.status = 'PASS';
analysis.sensitivity = sensitivity;
analysis.report_path = fullfile(roundDir,'modal_parameter_sensitivity.json');
analysis.candidate_count = nnz(abs(sensitivity.recommendation.relative_step) > 0);
analysis.derivative_status = derivative.status;
analysis.derivative_warnings = derivative.warnings;
analysis.registry_truncated = truncated;
if truncated
    analysis.note = sprintf('sensitivity limited to %d highest-priority knobs', ...
        opt.modal_sensitivity_max_knobs);
end
end


function raw = iLinearizeRelative(modelName,reg,baseValues,relative,Ts)
for k = 1:numel(reg)
    value = baseValues{k} .* (1 + relative(k));
    value = max(reg(k).min, min(reg(k).max, value));
    set_param(reg(k).block_path,reg(k).mask_param,mat2str(value));
end
[A,~,~,~] = dlinmod(modelName,Ts);
raw = A;
end


function iRestore(modelName,reg,baseValues,initialDirty)
for k = 1:numel(reg)
    try
        set_param(reg(k).block_path,reg(k).mask_param,mat2str(baseValues{k}));
    catch
    end
end
try
    set_param(modelName,'Dirty',initialDirty);
catch
end
end
