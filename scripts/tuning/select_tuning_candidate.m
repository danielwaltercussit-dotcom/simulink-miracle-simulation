function decision = select_tuning_candidate(reg, failureSignature, sensitivity, neuralAdvice, varargin)
%SELECT_TUNING_CANDIDATE Select a knob with mathematics as primary authority.
% Neural advice may break ties between mathematically valid candidates. It
% never supplies the direction or makes an otherwise invalid candidate valid.

p = inputParser;
p.addParameter('AllowRuleFallback', false, @(x)islogical(x)||isnumeric(x));
p.addParameter('MinimumRelativeStep', 1e-6, @isnumeric);
p.parse(varargin{:});
opt = p.Results;

decision = struct('status','NO_CANDIDATE','source','none','registry_index',0, ...
    'id','','parameter_class','','relative_step',NaN,'math_score',NaN, ...
    'neural_supported',false,'reason','');
if isempty(reg)
    decision.reason = 'empty tuning registry';
    return
end

eligible = false(1,numel(reg));
for k = 1:numel(reg)
    [writable, ~] = tuning_entry_is_writable(reg(k));
    eligible(k) = writable && any(strcmp(reg(k).fs_targets, failureSignature));
end
if ~any(eligible)
    decision.reason = sprintf('no writable registry knob targets %s', failureSignature);
    return
end

[mathNames, relativeStep, mathScore, mathValid] = iMathEvidence(sensitivity, opt.MinimumRelativeStep);
neuralIds = string(iFieldOr(neuralAdvice, 'candidate_parameters', {}));
neuralClasses = string(iFieldOr(neuralAdvice, 'candidate_parameter_classes', {}));
candidates = repmat(struct('registry_index',0,'id','','parameter_class','', ...
    'relative_step',0,'math_score',0,'neural_supported',false,'priority',0), ...
    1,nnz(eligible));
candidateCount = 0;

for k = find(eligible)
    nameIndex = find(strcmp(mathNames, string(reg(k).id)), 1);
    if isempty(nameIndex) || ~mathValid(nameIndex)
        continue
    end
    neuralSupported = any(strcmp(neuralIds, string(reg(k).id))) || ...
        any(strcmp(neuralClasses, string(reg(k).parameter_class)));
    candidateCount = candidateCount + 1;
    candidates(candidateCount) = struct( ...
        'registry_index',k, 'id',reg(k).id, ...
        'parameter_class',reg(k).parameter_class, ...
        'relative_step',relativeStep(nameIndex), ...
        'math_score',mathScore(nameIndex), ...
        'neural_supported',neuralSupported, 'priority',reg(k).priority);
end
candidates = candidates(1:candidateCount);

if ~isempty(candidates)
    neuralRank = -double([candidates.neural_supported]).';
    mathRank = -[candidates.math_score].';
    priorityRank = [candidates.priority].';
    idRank = string({candidates.id}).';
    tableRank = table(mathRank, neuralRank, priorityRank, idRank, (1:numel(candidates)).', ...
        'VariableNames', {'math','neural','priority','id','index'});
    tableRank = sortrows(tableRank, {'math','neural','priority','id'});
    chosen = candidates(tableRank.index(1));
    decision.status = 'CANDIDATE';
    decision.source = 'mathematical_sensitivity';
    decision.registry_index = chosen.registry_index;
    decision.id = chosen.id;
    decision.parameter_class = chosen.parameter_class;
    decision.relative_step = chosen.relative_step;
    decision.math_score = chosen.math_score;
    decision.neural_supported = chosen.neural_supported;
    decision.reason = 'direction from d(zeta)/dp; neural advice used only as a tie-break prior';
    return
end

if logical(opt.AllowRuleFallback)
    fallback = find(eligible, 1);
    decision.status = 'FALLBACK';
    decision.source = 'registry_rule_without_sensitivity';
    decision.registry_index = fallback;
    decision.id = reg(fallback).id;
    decision.parameter_class = reg(fallback).parameter_class;
    decision.neural_supported = any(strcmp(neuralIds, string(reg(fallback).id))) || ...
        any(strcmp(neuralClasses, string(reg(fallback).parameter_class)));
    decision.reason = 'mathematical sensitivity unavailable; explicit fallback enabled';
else
    decision.reason = 'no usable mathematical sensitivity; rule fallback disabled';
end
end


function [names, relativeStep, score, valid] = iMathEvidence(sensitivity, minimumStep)
names = strings(1,0);
relativeStep = zeros(1,0);
score = zeros(1,0);
valid = false(1,0);
if isempty(sensitivity) || ~isstruct(sensitivity) || ...
        ~isfield(sensitivity,'parameter_names') || ~isfield(sensitivity,'recommendation')
    return
end
names = string(sensitivity.parameter_names);
names = reshape(names,1,[]);
rec = sensitivity.recommendation;
if ~isfield(rec,'relative_step')
    return
end
relativeStep = reshape(double(rec.relative_step),1,[]);
if numel(relativeStep) ~= numel(names)
    relativeStep = NaN(size(names));
end
score = zeros(size(names));
nonDegrading = false(size(names));
if isfield(sensitivity,'d_damping_per_relative_change')
    matrix = double(sensitivity.d_damping_per_relative_change);
    if size(matrix,2) == numel(names)
        rows = 1:size(matrix,1);
        if isfield(rec,'critical_mode_rows') && ~isempty(rec.critical_mode_rows)
            rows = reshape(double(rec.critical_mode_rows),1,[]);
            rows = rows(rows >= 1 & rows <= size(matrix,1));
        end
        if ~isempty(rows)
            predictedGain = matrix(rows,:) .* relativeStep;
            score = sum(max(predictedGain,0),1,'omitnan');
            nonDegrading = all(predictedGain >= -1e-10,1) & ...
                any(predictedGain > 1e-10,1);
        end
    end
end
score(~isfinite(score)) = 0;
valid = isfinite(relativeStep) & abs(relativeStep) >= minimumStep & ...
    score > 0 & nonDegrading;
end


function value = iFieldOr(input, field, fallback)
value = fallback;
if isstruct(input) && isfield(input,field)
    value = input.(field);
end
end
