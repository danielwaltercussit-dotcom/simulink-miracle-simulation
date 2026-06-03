function result = validate_power_system_spec(specPath, varargin)
%VALIDATE_POWER_SYSTEM_SPEC Lightweight spec contract checks for project YAML.
%   This validator intentionally checks the contract surface used by the
%   agentic build loop without trying to be a full YAML parser.

p = inputParser;
p.addParameter('ReportPath', '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opt = p.Results;

specPath = char(specPath);
txt = fileread(specPath);
result = struct();
result.name = 'POWER_SYSTEM_SPEC_VALIDATION';
result.spec_path = specPath;
result.status = 'FAIL';
result.passed = false;
result.checks = struct();
result.values = struct();
result.message = '';
result.report_path = char(opt.ReportPath);

result.checks.non_empty = strlength(string(strtrim(txt))) > 0;
result.checks.has_system = has_section(txt, 'system');
result.checks.has_convergence_targets = has_section(txt, 'convergence_targets');
result.checks.has_topology_or_replacement = has_section(txt, 'topology') || has_section(txt, 'replacement_policy');

result.values.name = read_scalar_string(txt, 'name');
result.values.base_mva = read_scalar_number(txt, 'base_mva');
result.values.frequency_hz = read_scalar_number(txt, 'frequency_hz');
result.values.stop_time = read_scalar_number(txt, 'stop_time');
result.values.sample_time = read_scalar_number(txt, 'sample_time');

result.checks.has_name = strlength(string(result.values.name)) > 0;
result.checks.base_mva_positive = isfinite(result.values.base_mva) && result.values.base_mva > 0;
result.checks.frequency_supported = any(abs(result.values.frequency_hz - [50 60]) < 1e-9);
result.checks.stop_time_positive = isfinite(result.values.stop_time) && result.values.stop_time > 0;
result.checks.sample_time_positive = isfinite(result.values.sample_time) && result.values.sample_time > 0;
result.checks.sample_time_smaller_than_stop = result.checks.sample_time_positive ...
    && result.checks.stop_time_positive ...
    && result.values.sample_time < result.values.stop_time;

if contains(txt, 'fault_injection:')
    result.values.fault_t_start_s = read_scalar_number(txt, 't_start_s');
    result.values.fault_t_end_s = read_scalar_number(txt, 't_end_s');
    result.values.fault_amplitude_pu = read_scalar_number(txt, 'amplitude_pu_during_fault');
    result.checks.fault_window_valid = isfinite(result.values.fault_t_start_s) ...
        && isfinite(result.values.fault_t_end_s) ...
        && result.values.fault_t_start_s < result.values.fault_t_end_s ...
        && result.values.fault_t_end_s <= result.values.stop_time;
    result.checks.fault_amplitude_valid = isfinite(result.values.fault_amplitude_pu) ...
        && result.values.fault_amplitude_pu >= 0 ...
        && result.values.fault_amplitude_pu <= 1.5;
else
    result.checks.fault_window_valid = true;
    result.checks.fault_amplitude_valid = true;
end

result.passed = all_boolean_checks(result.checks);
if result.passed
    result.status = 'PASS';
    result.message = 'PASS';
else
    result.message = build_failure_message(result.checks);
end

if strlength(string(opt.ReportPath)) > 0
    write_spec_report(char(opt.ReportPath), result);
end
end

function tf = has_section(txt, sectionName)
pat = ['(?m)^' regexptranslate('escape', sectionName) ':\s*$'];
tf = ~isempty(regexp(txt, pat, 'once'));
end

function value = read_scalar_string(txt, key)
value = '';
pat = ['(?m)^\s*' regexptranslate('escape', key) ':\s*([^#\r\n]+)'];
tok = regexp(txt, pat, 'tokens', 'once');
if isempty(tok)
    pat = ['(?:^|[\s,{])' regexptranslate('escape', key) '\s*:\s*([^,}\r\n#]+)'];
    tok = regexp(txt, pat, 'tokens', 'once');
end
if ~isempty(tok)
    value = strtrim(tok{1});
    value = regexprep(value, '^["'']|["'']$', '');
end
end

function value = read_scalar_number(txt, key)
value = NaN;
s = read_scalar_string(txt, key);
if strlength(string(s)) > 0
    value = str2double(s);
end
end

function tf = all_boolean_checks(checks)
tf = true;
names = fieldnames(checks);
for k = 1:numel(names)
    value = checks.(names{k});
    if islogical(value) && isscalar(value)
        tf = tf && value;
    end
end
end

function msg = build_failure_message(checks)
failed = {};
names = fieldnames(checks);
for k = 1:numel(names)
    value = checks.(names{k});
    if islogical(value) && isscalar(value) && ~value
        failed{end+1} = names{k}; %#ok<AGROW>
    end
end
msg = ['Failed checks: ' strjoin(failed, ', ')];
end

function write_spec_report(path, result)
reportDir = fileparts(path);
if ~isempty(reportDir) && ~isfolder(reportDir)
    mkdir(reportDir);
end
fid = fopen(path, 'w');
if fid < 0
    warning('ValidatePowerSystemSpec:CannotWriteReport', 'Cannot write %s', path);
    return
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Spec Validation Summary\n\n');
fprintf(fid, '- spec: `%s`\n', result.spec_path);
fprintf(fid, '- status: `%s`\n', result.status);
fprintf(fid, '- message: %s\n\n', result.message);

fprintf(fid, '## Values\n\n');
names = fieldnames(result.values);
for k = 1:numel(names)
    value = result.values.(names{k});
    if isnumeric(value)
        fprintf(fid, '- %s: %.12g\n', names{k}, value);
    else
        fprintf(fid, '- %s: `%s`\n', names{k}, char(value));
    end
end

fprintf(fid, '\n## Checks\n\n');
names = fieldnames(result.checks);
for k = 1:numel(names)
    fprintf(fid, '- %s: `%s`\n', names{k}, mat2str(result.checks.(names{k})));
end
end
