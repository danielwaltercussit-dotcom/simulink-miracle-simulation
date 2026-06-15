function [tf, reason] = tuning_entry_is_writable(entry)
%TUNING_ENTRY_IS_WRITABLE  Contract gate: may S6 set_param this registry entry?
%
%   [tf, reason] = tuning_entry_is_writable(entry)
%
%   Single source of truth for the "control-only, fully classified" write
%   contract from docs/CONTROL_TUNING_PRIORITY_AND_BOUNDARY.md. The S6 stage
%   (ai_in_loop_stage_tune) MUST consult this before any set_param, and the
%   contract tests assert it on synthetic entries. It rejects:
%
%     * unclassified entries  — missing any required classification field
%       (priority, parameter_class, control_only, rollback_value, or the core
%       id/block_path/mask_param), or a malformed priority/parameter_class;
%     * immutable entries      — control_only is anything other than logical
%       true. Plant/device physical parameters, ratings, topology, and inertia
%       are immutable and must never be writable, even if a caller hands them in.
%
%   tf      logical, true only when the entry is proven safe to write.
%   reason  short diagnostic string; starts with 'unclassified:' or
%           'immutable:' on rejection, 'ok' when writable.

tf = false;

if ~isstruct(entry) || ~isscalar(entry)
    reason = 'unclassified: entry is not a scalar struct';
    return
end

required = {'id','block_path','mask_param','priority','parameter_class', ...
    'control_only','rollback_value'};
missing = required(~isfield(entry, required));
if ~isempty(missing)
    reason = sprintf('unclassified: missing field(s) %s', strjoin(missing, ', '));
    return
end

% Immutability is decided ONLY by an explicit logical-true control_only flag.
% A non-logical, non-scalar, or false value is treated as immutable/non-control.
if ~(islogical(entry.control_only) && isscalar(entry.control_only) && entry.control_only)
    reason = ['immutable: control_only is not true; plant/device/rating ' ...
        'physical parameters are not tunable'];
    return
end

if ~(isnumeric(entry.priority) && isscalar(entry.priority) && ...
        isfinite(entry.priority) && entry.priority >= 1 && mod(entry.priority,1) == 0)
    reason = 'unclassified: priority must be a positive integer';
    return
end

if ~((ischar(entry.parameter_class) || isstring(entry.parameter_class)) && ...
        strlength(string(entry.parameter_class)) > 0)
    reason = 'unclassified: parameter_class is empty';
    return
end

if isempty(entry.rollback_value) || any(isnan(double(entry.rollback_value(:))))
    reason = 'unclassified: rollback_value is empty or NaN (no proven restore point)';
    return
end

tf = true;
reason = 'ok';
end
