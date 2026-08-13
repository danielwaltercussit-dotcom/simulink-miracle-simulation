function result = summarize_decoupled_interface_plan(plan, varargin)
%SUMMARIZE_DECOUPLED_INTERFACE_PLAN Check a decoupled-interface plan vs contract.
%   result = summarize_decoupled_interface_plan(plan)
%   result = summarize_decoupled_interface_plan(plan, 'ModelProbe', probe)
%   result = summarize_decoupled_interface_plan(plan, 'OutputDir', dir)
%
%   Pure base MATLAB. Opens no model. Statically checks a cross-scale
%   equivalent-source decoupling interface plan (EMT <-> averaged /
%   electromechanical) against references/decoupled-interface-contract.md.
%
%   Returns a struct with:
%     case_name
%     contract_status          'pass' | 'provisional' | 'fail'
%     model_validation_status  'not_attempted' | 'pass' | 'fail'
%     handoff_ready            logical (pass + model pass + zero warnings)
%     verified_against_model   logical (DERIVED, never trusted from the plan)
%     issues                   struct array: severity/location/message
%     n_failures               count
%     n_warnings               count
%     missing_required         cell of missing field names
%     provisional              logical
%     limitations              string
%     model_probe              struct (copy of attached probe or empty)

p = inputParser;
p.addParameter('ModelProbe', [], @(x) isempty(x) || isstruct(x));
p.addParameter('OutputDir', '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;

VALID_KINDS   = {'thevenin','norton','controlled_source','measurement_only','s_function_wrapper'};
VALID_DOMAINS = {'switching_emt','averaged_emt','phasor_rms','electromech'};
CROSS_SCALE_KINDS = {'thevenin','norton','controlled_source','s_function_wrapper'};

result = struct();
result.case_name = iGetField(plan, 'case_name', 'unnamed');
result.contract_status = 'pass';
result.model_validation_status = 'not_attempted';
result.handoff_ready = false;
result.verified_against_model = false;
result.issues = struct('severity',{},'location',{},'message',{});
result.n_failures = 0;
result.n_warnings = 0;
result.missing_required = {};
result.provisional = false;
result.limitations = 'Contract-only plan; no interface execution evidence unless ModelProbe attached.';
result.model_probe = struct();

% --- Required fields present? ---
requiredFields = {'interface_kind','source_domain','target_domain', ...
    'exchange_variables','sample_time_s','hold_policy','delay_s', ...
    'algebraic_loop_breaker','energy_consistency_check'};
for k = 1:numel(requiredFields)
    fn = requiredFields{k};
    if ~isfield(plan, fn) || isempty(plan.(fn))
        result.missing_required{end+1} = fn;
    end
end

% --- Required metadata gate ---
% A contract pass means the static plan is complete and internally consistent.
% Missing exchange_variables is a hard failure (handled by its own rule below).
% Any OTHER missing required field forces at least provisional: an incomplete
% plan must never read as pass. One summary issue lists the missing
% non-exchange fields so we do not double-report fields that also have their
% own undocumented/value rules.
missingNonExchange = setdiff(result.missing_required, {'exchange_variables'}, 'stable');
if ~isempty(missingNonExchange)
    result.provisional = true;
    result = iAddIssue(result, 'provisional', 'required_metadata', ...
        sprintf('Missing required metadata (%s) -> provisional; incomplete plan cannot pass', ...
        strjoin(missingNonExchange, ', ')));
end

kind   = lower(strtrim(char(string(iGetField(plan, 'interface_kind', '')))));
srcDom = lower(strtrim(char(string(iGetField(plan, 'source_domain', '')))));
tgtDom = lower(strtrim(char(string(iGetField(plan, 'target_domain', '')))));
hold_  = lower(strtrim(char(string(iGetField(plan, 'hold_policy', 'undocumented')))));
alb    = lower(strtrim(char(string(iGetField(plan, 'algebraic_loop_breaker', 'undocumented')))));
ecc    = lower(strtrim(char(string(iGetField(plan, 'energy_consistency_check', 'not_attempted')))));
sampleTs = iGetNumericField(plan, 'sample_time_s');
delayS   = iGetNumericField(plan, 'delay_s');
domainsDiffer = ~isempty(srcDom) && ~isempty(tgtDom) && ~strcmp(srcDom, tgtDom);
hasExchange = iHasExchangeVars(plan);

% --- Failure: unsupported labels ---
if ~isempty(kind) && ~ismember(kind, VALID_KINDS)
    result = iAddIssue(result, 'failure', 'interface_kind', ...
        sprintf('Unsupported interface_kind "%s"', kind));
end
if ~isempty(srcDom) && ~ismember(srcDom, VALID_DOMAINS)
    result = iAddIssue(result, 'failure', 'source_domain', ...
        sprintf('Unsupported source_domain "%s"', srcDom));
end
if ~isempty(tgtDom) && ~ismember(tgtDom, VALID_DOMAINS)
    result = iAddIssue(result, 'failure', 'target_domain', ...
        sprintf('Unsupported target_domain "%s"', tgtDom));
end

% --- Failure: exchange_variables missing/empty ---
if ~hasExchange
    result = iAddIssue(result, 'failure', 'exchange_variables', ...
        'exchange_variables missing or empty; at least one of voltage/current/power/angle/frequency required');
end

% --- Failure: same domain but cross-scale decoupling kind claimed ---
if ~isempty(kind) && ~isempty(srcDom) && ~isempty(tgtDom) && ...
        strcmp(srcDom, tgtDom) && ismember(kind, CROSS_SCALE_KINDS)
    result = iAddIssue(result, 'failure', 'interface_kind', ...
        'source_domain == target_domain but interface_kind claims cross-scale decoupling without justification');
end

% --- Failure: no hold across differing domains with positive sample time ---
if strcmp(hold_, 'none') && isfinite(sampleTs) && sampleTs > 0 && domainsDiffer
    result = iAddIssue(result, 'failure', 'hold_policy', ...
        'hold_policy none while sample_time_s > 0 and source/target domains differ');
end

% --- Failure: no loop breaker at bidirectional controlled source ---
if strcmp(kind, 'controlled_source') && strcmp(alb, 'none') && iIsBidirectional(plan)
    result = iAddIssue(result, 'failure', 'algebraic_loop_breaker', ...
        'algebraic_loop_breaker none at a bidirectional controlled_source interface (algebraic loop)');
end

% --- Failure: nonfinite / nonpositive Thevenin/Norton equivalent impedance ---
% Only fires when the field is PRESENT (not missing). Missing impedance is
% handled by the existing provisional rule below.
if ismember(kind, {'thevenin','norton'}) && isfield(plan, 'equivalent_impedance_ohm') && ~isempty(plan.equivalent_impedance_ohm)
    zEq = iGetNumericField(plan, 'equivalent_impedance_ohm');
    if ~isfinite(zEq)
        result = iAddIssue(result, 'failure', 'equivalent_impedance_ohm', ...
            'equivalent_impedance_ohm must be finite for thevenin/norton interfaces');
    elseif zEq <= 0
        result = iAddIssue(result, 'failure', 'equivalent_impedance_ohm', ...
            'equivalent_impedance_ohm must be > 0 for thevenin/norton interfaces');
    end
end

% --- Failure: impossible timing ---
if isfinite(delayS) && delayS < 0
    result = iAddIssue(result, 'failure', 'delay_s', 'delay_s < 0 (impossible)');
end
if isfinite(sampleTs) && sampleTs <= 0
    result = iAddIssue(result, 'failure', 'sample_time_s', 'sample_time_s <= 0 (impossible)');
end

% --- Failure: declared energy inconsistency ---
if strcmp(ecc, 'fail')
    result = iAddIssue(result, 'failure', 'energy_consistency_check', ...
        'energy_consistency_check == fail');
end

% --- Provisional: undocumented policies / missing recommendations ---
if strcmp(hold_, 'undocumented')
    result.provisional = true;
    result = iAddIssue(result, 'provisional', 'hold_policy', ...
        'hold_policy undocumented -> provisional');
end
if strcmp(alb, 'undocumented')
    result.provisional = true;
    result = iAddIssue(result, 'provisional', 'algebraic_loop_breaker', ...
        'algebraic_loop_breaker undocumented -> provisional');
end
if strcmp(ecc, 'not_attempted')
    result.provisional = true;
    result = iAddIssue(result, 'provisional', 'energy_consistency_check', ...
        'energy_consistency_check not_attempted -> provisional');
end

exchangesPhasorOrDq = iExchangesPhasorOrDq(plan, srcDom, tgtDom);
if exchangesPhasorOrDq
    if isempty(iGetField(plan, 'sign_convention', ''))
        result.provisional = true;
        result = iAddIssue(result, 'provisional', 'sign_convention', ...
            'sign_convention missing while exchanging phasor/dq variables -> provisional');
    end
    if isempty(iGetField(plan, 'phase_reference', ''))
        result.provisional = true;
        result = iAddIssue(result, 'provisional', 'phase_reference', ...
            'phase_reference missing while exchanging phasor/dq variables -> provisional');
    end
end

if ismember(kind, {'thevenin','norton'})
    if isempty(iGetField(plan, 'equivalent_impedance_ohm', []))
        result.provisional = true;
        result = iAddIssue(result, 'provisional', 'equivalent_impedance_ohm', ...
            'equivalent_impedance_ohm missing for thevenin/norton interface -> provisional');
    end
end

% --- Warning: delay exceeds sample time ---
if isfinite(delayS) && isfinite(sampleTs) && sampleTs > 0 && delayS > sampleTs
    result = iAddIssue(result, 'warning', 'delay_s', ...
        sprintf('delay_s (%.4g) > sample_time_s (%.4g): interface delay exceeds its own sample period', ...
        delayS, sampleTs));
end

% --- Warning: non-integer source/target sample-time ratio ---
srcTs = iGetNumericField(plan, 'source_sample_time_s');
tgtTs = iGetNumericField(plan, 'target_sample_time_s');
if isfinite(srcTs) && isfinite(tgtTs) && srcTs > 0 && tgtTs > 0
    ratio = max(srcTs, tgtTs) / min(srcTs, tgtTs);
    if abs(ratio - round(ratio)) > 1e-9
        result = iAddIssue(result, 'warning', 'rate_ratio', ...
            sprintf('source/target sample-time ratio = %.6g is not integer', ratio));
    end
end

% --- Warning: measurement_only used for bidirectional power exchange ---
if strcmp(kind, 'measurement_only') && iIsBidirectional(plan) && iExchangesPower(plan)
    result = iAddIssue(result, 'warning', 'interface_kind', ...
        'measurement_only interface used where bidirectional power exchange is claimed');
end

% --- Warning: bare verified_against_model claim ---
claimedVerif = iGetField(plan, 'verified_against_model', false);
if isequal(claimedVerif, true) && isempty(opts.ModelProbe)
    result = iAddIssue(result, 'warning', 'verified_against_model', ...
        'verified_against_model=true asserted but no ModelProbe evidence was attached; claim downgraded');
end

% --- Model probe handling ---
if ~isempty(opts.ModelProbe)
    result.model_probe = opts.ModelProbe;
    if isfield(opts.ModelProbe, 'ran') && opts.ModelProbe.ran
        % Plan-vs-probe coherence (DIF-6): fail-closed if the probe's
        % actual config disagrees with the declared plan. Centralized here so
        % every caller inherits the same behavior. Tolerance: 1e-12 relative
        % for sample times / impedance.
        [coherent, mismatchMsg] = iProbePlanCoherent(opts.ModelProbe, plan, kind);
        probeSimOk = isfield(opts.ModelProbe, 'sim_success') && opts.ModelProbe.sim_success;
        if probeSimOk && ~coherent
            result.model_validation_status = 'fail';
            result = iAddIssue(result, 'failure', 'model_probe', ...
                ['ModelProbe config does not match declared plan: ' mismatchMsg]);
            result.limitations = 'Model probe ran but its config does not match the plan; interface NOT validated.';
        elseif probeSimOk
            result.model_validation_status = 'pass';
            result.verified_against_model = true;
            result.limitations = 'Model-backed probe evidence attached; interface exercised via real load/update/sim.';
        else
            result.model_validation_status = 'fail';
            result = iAddIssue(result, 'failure', 'model_probe', ...
                'ModelProbe ran but simulation did not succeed');
            result.limitations = 'Model probe attempted but simulation failed; interface NOT validated.';
        end
    end
end

% --- Final statuses ---
result.n_failures = sum(strcmp({result.issues.severity}, 'failure'));
result.n_warnings = sum(strcmp({result.issues.severity}, 'warning'));

% A model_probe failure must not by itself flip a clean contract to fail.
contractFailures = 0;
for k = 1:numel(result.issues)
    if strcmp(result.issues(k).severity, 'failure') && ...
       ~strcmp(result.issues(k).location, 'model_probe')
        contractFailures = contractFailures + 1;
    end
end

if contractFailures > 0
    result.contract_status = 'fail';
elseif result.provisional
    result.contract_status = 'provisional';
else
    result.contract_status = 'pass';
end

result.handoff_ready = strcmp(result.contract_status, 'pass') && ...
    strcmp(result.model_validation_status, 'pass') && ...
    result.n_warnings == 0;

% --- Write artifacts ---
outDir = char(opts.OutputDir);
if strlength(string(outDir)) > 0
    iWriteArtifacts(outDir, result, plan);
end
end


%% Internal helpers

function val = iGetField(s, fn, default)
if isstruct(s) && isfield(s, fn) && ~isempty(s.(fn))
    val = s.(fn);
else
    val = default;
end
end

function val = iGetNumericField(s, fn)
if isstruct(s) && isfield(s, fn) && isnumeric(s.(fn)) && isscalar(s.(fn))
    val = s.(fn);
else
    val = NaN;
end
end

function tf = iHasExchangeVars(plan)
% True if exchange_variables declares at least one recognized quantity.
tf = false;
if ~isfield(plan, 'exchange_variables') || isempty(plan.exchange_variables)
    return
end
known = {'voltage','current','power','angle','frequency'};
ev = plan.exchange_variables;
if iscell(ev) || isstring(ev)
    items = cellstr(ev);
    for k = 1:numel(items)
        if ismember(lower(strtrim(items{k})), known); tf = true; return; end
    end
elseif ischar(ev)
    if ismember(lower(strtrim(ev)), known); tf = true; end
elseif isstruct(ev)
    fns = fieldnames(ev);
    for k = 1:numel(fns)
        if ismember(lower(fns{k}), known) && ~isempty(ev.(fns{k}))
            tf = true; return;
        end
    end
end
end

function tf = iExchangesPower(plan)
tf = false;
if ~isfield(plan, 'exchange_variables') || isempty(plan.exchange_variables); return; end
ev = plan.exchange_variables;
if iscell(ev) || isstring(ev)
    tf = any(strcmpi(cellstr(ev), 'power'));
elseif ischar(ev)
    tf = strcmpi(strtrim(ev), 'power');
elseif isstruct(ev)
    tf = isfield(ev, 'power') && ~isempty(ev.power);
end
end

function tf = iIsBidirectional(plan)
% Bidirectional when an explicit flag says so, or direction names both ways.
tf = false;
flag = iGetField(plan, 'bidirectional', []);
if islogical(flag) && isscalar(flag); tf = flag; return; end
dir = lower(char(string(iGetField(plan, 'exchange_direction', ''))));
if any(strcmp(dir, {'bidirectional','both','two_way','duplex'})); tf = true; return; end
ev = iGetField(plan, 'exchange_variables', []);
if isstruct(ev) && isfield(ev, 'bidirectional') && isequal(ev.bidirectional, true)
    tf = true;
end
end

function tf = iExchangesPhasorOrDq(plan, srcDom, tgtDom)
tf = strcmp(srcDom, 'phasor_rms') || strcmp(tgtDom, 'phasor_rms');
dq = iGetField(plan, 'dq_abc_transform', '');
if ~isempty(dq) && ~strcmpi(char(string(dq)), 'none')
    tf = true;
end
ev = iGetField(plan, 'exchange_variables', []);
if iscell(ev) || isstring(ev)
    if any(strcmpi(cellstr(ev), 'angle')); tf = true; end
elseif isstruct(ev) && isfield(ev, 'angle') && ~isempty(ev.angle)
    tf = true;
end
end

function result = iAddIssue(result, severity, location, message)
issue = struct('severity', severity, 'location', location, 'message', message);
if isempty(result.issues)
    result.issues = issue;
else
    result.issues(end+1) = issue;
end
end

function iWriteArtifacts(outDir, result, plan)
if ~isfolder(outDir)
    mkdir(outDir);
end

% Markdown
mdPath = fullfile(outDir, 'decoupled_interface_plan.md');
fid = fopen(mdPath, 'w');
if fid >= 0
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# Decoupled Interface Plan: %s\n\n', result.case_name);
    fprintf(fid, '- contract_status: `%s`\n', result.contract_status);
    fprintf(fid, '- model_validation_status: `%s`\n', result.model_validation_status);
    fprintf(fid, '- handoff_ready: `%s`\n', mat2str(result.handoff_ready));
    fprintf(fid, '- verified_against_model: `%s`\n', mat2str(result.verified_against_model));
    fprintf(fid, '- failures: %d\n', result.n_failures);
    fprintf(fid, '- warnings: %d\n', result.n_warnings);
    fprintf(fid, '- limitations: %s\n\n', result.limitations);

    if ~isempty(result.missing_required)
        fprintf(fid, '## Missing Required Fields\n\n');
        for k = 1:numel(result.missing_required)
            fprintf(fid, '- %s\n', result.missing_required{k});
        end
        fprintf(fid, '\n');
    end

    if ~isempty(result.issues)
        fprintf(fid, '## Issues\n\n');
        for k = 1:numel(result.issues)
            fprintf(fid, '- [%s] %s: %s\n', result.issues(k).severity, ...
                result.issues(k).location, result.issues(k).message);
        end
        fprintf(fid, '\n');
    end

    mp = result.model_probe;
    if isstruct(mp) && isfield(mp, 'model') && ~isempty(mp.model)
        fprintf(fid, '## Model Probe\n\n');
        fprintf(fid, '- model: `%s`\n', char(string(mp.model)));
        if isfield(mp, 'ran');         fprintf(fid, '- ran: `%s`\n', mat2str(logical(mp.ran))); end
        if isfield(mp, 'sim_success'); fprintf(fid, '- sim_success: `%s`\n', mat2str(logical(mp.sim_success))); end
        if isfield(mp, 'stop_time_s'); fprintf(fid, '- stop_time_s: `%.6g`\n', double(mp.stop_time_s)); end
        if isfield(mp, 'max_abs_state');fprintf(fid, '- max_abs_state: `%.6g`\n', double(mp.max_abs_state)); end
        if isfield(mp, 'notes');       fprintf(fid, '- notes: %s\n', char(string(mp.notes))); end
        if isfield(mp, 'mdl_path');    fprintf(fid, '- mdl_path: `%s`\n', char(string(mp.mdl_path))); end
        fprintf(fid, '\n');
    end
end

% JSON
jsonPath = fullfile(outDir, 'decoupled_interface_plan.json');
jsonStr = iSimpleJSON(result, plan);
fid2 = fopen(jsonPath, 'w');
if fid2 >= 0
    fwrite(fid2, jsonStr);
    fclose(fid2);
end
end

function out = iJsonEscape(val)
% Escape an arbitrary value for embedding inside a JSON double-quoted string.
% Backslash MUST be replaced first so the escapes added afterwards are not
% double-escaped. This keeps Windows paths (C:\...), quotes, and control
% whitespace jsondecode-safe.
s = char(string(val));
s = strrep(s, '\', '\\');           % backslash -> \\   (must be first)
s = strrep(s, '"', '\"');           % double quote -> \"
s = strrep(s, sprintf('\n'), '\n'); % LF  -> literal \n
s = strrep(s, sprintf('\r'), '\r'); % CR  -> literal \r
s = strrep(s, sprintf('\t'), '\t'); % TAB -> literal \t
out = s;
end

function s = iSimpleJSON(result, plan)
lines = {};
lines{end+1} = '{';
lines{end+1} = sprintf('  "case_name": "%s",', iJsonEscape(result.case_name));
lines{end+1} = sprintf('  "contract_status": "%s",', iJsonEscape(result.contract_status));
lines{end+1} = sprintf('  "model_validation_status": "%s",', iJsonEscape(result.model_validation_status));
lines{end+1} = sprintf('  "handoff_ready": %s,', mat2str(result.handoff_ready));
lines{end+1} = sprintf('  "verified_against_model": %s,', mat2str(result.verified_against_model));
lines{end+1} = sprintf('  "n_failures": %d,', result.n_failures);
lines{end+1} = sprintf('  "n_warnings": %d,', result.n_warnings);
lines{end+1} = sprintf('  "provisional": %s,', mat2str(result.provisional));
lines{end+1} = sprintf('  "missing_required": [%s],', iJoinQuoted(result.missing_required));
lines{end+1} = sprintf('  "issues": [%s],', iJsonIssues(result.issues));
if isfield(plan, 'interface_kind') && ~isempty(plan.interface_kind)
    lines{end+1} = sprintf('  "interface_kind": "%s",', iJsonEscape(plan.interface_kind));
end
if isfield(plan, 'source_domain') && ~isempty(plan.source_domain)
    lines{end+1} = sprintf('  "source_domain": "%s",', iJsonEscape(plan.source_domain));
end
if isfield(plan, 'target_domain') && ~isempty(plan.target_domain)
    lines{end+1} = sprintf('  "target_domain": "%s",', iJsonEscape(plan.target_domain));
end
if isfield(plan, 'sample_time_s') && isnumeric(plan.sample_time_s) && isscalar(plan.sample_time_s)
    lines{end+1} = sprintf('  "sample_time_s": %.6g,', plan.sample_time_s);
end
if isfield(plan, 'source_sample_time_s') && isnumeric(plan.source_sample_time_s) && isscalar(plan.source_sample_time_s)
    lines{end+1} = sprintf('  "source_sample_time_s": %.6g,', plan.source_sample_time_s);
end
if isfield(plan, 'target_sample_time_s') && isnumeric(plan.target_sample_time_s) && isscalar(plan.target_sample_time_s)
    lines{end+1} = sprintf('  "target_sample_time_s": %.6g,', plan.target_sample_time_s);
end
if isfield(plan, 'equivalent_impedance_ohm') && isnumeric(plan.equivalent_impedance_ohm) && isscalar(plan.equivalent_impedance_ohm)
    lines{end+1} = sprintf('  "equivalent_impedance_ohm": %.6g,', plan.equivalent_impedance_ohm);
end
if isfield(plan, 'delay_s') && isnumeric(plan.delay_s) && isscalar(plan.delay_s)
    lines{end+1} = sprintf('  "delay_s": %.6g,', plan.delay_s);
end
mpStr = iJsonModelProbe(result.model_probe);
if ~isempty(mpStr)
    lines{end+1} = sprintf('  "model_probe": %s,', mpStr);
end
lines{end+1} = sprintf('  "limitations": "%s"', iJsonEscape(result.limitations));
lines{end+1} = '}';
s = strjoin(lines, newline);
end

function [coherent, msg] = iProbePlanCoherent(mp, plan, planKind)
% Compare probe-owned actual config against the declared plan. Returns
% coherent=false with a message on any mismatch. Missing probe fields are
% treated as "not asserted" and skipped (legacy/synthetic probes stay valid).
coherent = true;
msg = '';
tol = 1e-12;
% interface_kind
if isfield(mp, 'interface_kind') && ~isempty(mp.interface_kind) && ~isempty(planKind)
    if ~strcmpi(char(string(mp.interface_kind)), planKind)
        coherent = false;
        msg = sprintf('kind plan=%s probe=%s', planKind, char(string(mp.interface_kind)));
        return
    end
end
% equivalent_impedance_ohm
planZ = iGetNumericField(plan, 'equivalent_impedance_ohm');
if isfield(mp, 'equivalent_impedance_ohm') && isfinite(planZ) && isnumeric(mp.equivalent_impedance_ohm) ...
        && isscalar(mp.equivalent_impedance_ohm) && isfinite(mp.equivalent_impedance_ohm)
    if abs(planZ - mp.equivalent_impedance_ohm) > tol * max(1, abs(planZ))
        coherent = false;
        msg = sprintf('Z plan=%.6g probe=%.6g', planZ, mp.equivalent_impedance_ohm);
        return
    end
end
% source_sample_time_s
planSrc = iGetNumericField(plan, 'source_sample_time_s');
if isfield(mp, 'source_sample_time_s') && isfinite(planSrc) && isnumeric(mp.source_sample_time_s) ...
        && isscalar(mp.source_sample_time_s) && isfinite(mp.source_sample_time_s)
    if abs(planSrc - mp.source_sample_time_s) > tol * max(1, abs(planSrc))
        coherent = false;
        msg = sprintf('source_ts plan=%.6g probe=%.6g', planSrc, mp.source_sample_time_s);
        return
    end
end
% target_sample_time_s
planTgt = iGetNumericField(plan, 'target_sample_time_s');
if isfield(mp, 'target_sample_time_s') && isfinite(planTgt) && isnumeric(mp.target_sample_time_s) ...
        && isscalar(mp.target_sample_time_s) && isfinite(mp.target_sample_time_s)
    if abs(planTgt - mp.target_sample_time_s) > tol * max(1, abs(planTgt))
        coherent = false;
        msg = sprintf('target_ts plan=%.6g probe=%.6g', planTgt, mp.target_sample_time_s);
        return
    end
end
end

function s = iJsonModelProbe(mp)
% Serialize the core model_probe fields. Returns '' when there is nothing
% meaningful to emit (empty struct or no 'model' field).
s = '';
if isempty(mp) || ~isstruct(mp) || ~isfield(mp, 'model') || isempty(mp.model)
    return
end
parts = cell(1, 7);
parts{1} = sprintf('"model": "%s"', iJsonEscape(mp.model));
parts{2} = sprintf('"ran": %s', iJsonBool(mp, 'ran'));
parts{3} = sprintf('"sim_success": %s', iJsonBool(mp, 'sim_success'));
parts{4} = sprintf('"stop_time_s": %s', iJsonNum(mp, 'stop_time_s'));
parts{5} = sprintf('"max_abs_state": %s', iJsonNum(mp, 'max_abs_state'));
parts{6} = sprintf('"notes": "%s"', iJsonEscape(iGetField(mp, 'notes', '')));
parts{7} = sprintf('"mdl_path": "%s"', iJsonEscape(iGetField(mp, 'mdl_path', '')));
% Actual-config provenance fields (DIF-6). Appended only when present so the
% legacy core fields stay first and JSON escaping is preserved.
if isfield(mp, 'probe_type') && ~isempty(mp.probe_type)
    parts{end+1} = sprintf('"probe_type": "%s"', iJsonEscape(mp.probe_type));
end
if isfield(mp, 'interface_kind') && ~isempty(mp.interface_kind)
    parts{end+1} = sprintf('"interface_kind": "%s"', iJsonEscape(mp.interface_kind));
end
if isfield(mp, 'source_sample_time_s')
    parts{end+1} = sprintf('"source_sample_time_s": %s', iJsonNum(mp, 'source_sample_time_s'));
end
if isfield(mp, 'target_sample_time_s')
    parts{end+1} = sprintf('"target_sample_time_s": %s', iJsonNum(mp, 'target_sample_time_s'));
end
if isfield(mp, 'equivalent_impedance_ohm')
    parts{end+1} = sprintf('"equivalent_impedance_ohm": %s', iJsonNum(mp, 'equivalent_impedance_ohm'));
end
if isfield(mp, 'i_boundary')
    parts{end+1} = sprintf('"i_boundary": %s', iJsonNum(mp, 'i_boundary'));
end
if isfield(mp, 'v_error')
    parts{end+1} = sprintf('"v_error": %s', iJsonNum(mp, 'v_error'));
end
if isfield(mp, 'status_ok')
    parts{end+1} = sprintf('"status_ok": %s', iJsonNum(mp, 'status_ok'));
end
s = ['{', strjoin(parts, ', '), '}'];
end

function out = iJsonBool(mp, fn)
if isfield(mp, fn) && ~isempty(mp.(fn))
    out = mat2str(logical(mp.(fn)));
else
    out = 'false';
end
end

function out = iJsonNum(mp, fn)
if isfield(mp, fn) && isnumeric(mp.(fn)) && isscalar(mp.(fn))
    out = sprintf('%.6g', double(mp.(fn)));
else
    out = 'null';
end
end

function s = iJoinQuoted(items)
if isempty(items); s = ''; return; end
parts = cell(1, numel(items));
for k = 1:numel(items)
    parts{k} = sprintf('"%s"', iJsonEscape(items{k}));
end
s = strjoin(parts, ', ');
end

function s = iJsonIssues(issues)
if isempty(issues); s = ''; return; end
parts = cell(1, numel(issues));
for k = 1:numel(issues)
    parts{k} = sprintf('{"severity":"%s","location":"%s","message":"%s"}', ...
        iJsonEscape(issues(k).severity), iJsonEscape(issues(k).location), ...
        iJsonEscape(issues(k).message));
end
s = strjoin(parts, ', ');
end
