function s = ai_in_loop_stage_modal(projectRoot, modelName, iterDir, opt)
%AI_IN_LOOP_STAGE_MODAL  S8B small-signal modal analysis (diagnostic evidence).
%   Linearizes the (discrete) model with dlinmod, maps discrete poles to the
%   continuous s-plane (s = ln(z)/Ts), and reports oscillatory modes with their
%   damping ratios. Flags lightly-damped modes that explain time-domain
%   ringing seen in S5/S5B/S6.
%
%   Discrete-model note: this project's benches are FixedStepDiscrete, so
%   linmod returns an empty A and dlinmod is required. Discrete eigenvalues z
%   must be converted to continuous s before damping/frequency are meaningful;
%   z=0 deadbeat/algebraic states are dropped.
%
%   s.status        'PASS' (analysis ran) | 'SKIPPED' (no state matrix)
%   s.report_path   modal_summary.md  (also mirrored to build/reports/modal/)
%   s.min_damping   smallest damping ratio among oscillatory modes
%   s.n_modes       number of non-degenerate modes analyzed
%   Never blocks the loop: a low damping ratio is diagnostic evidence, not a
%   stage failure.

s = struct('name','S8B_MODAL','status','PASS','model',char(modelName), ...
    'report_path','','json_path','','min_damping',NaN,'n_modes',0, ...
    'n_oscillatory',0);

modelName = char(modelName);
if ~bdIsLoaded(modelName); load_system(modelName); end

Ts = opt.modal_ts;
try
    [A,~,~,~] = dlinmod(modelName, Ts);
catch ME
    s.status = 'SKIPPED';
    s.note = sprintf('dlinmod failed: %s', ME.message);
    return
end
if isempty(A) || size(A,1) == 0
    s.status = 'SKIPPED';
    s.note = 'dlinmod returned empty state matrix; model may be purely algebraic';
    return
end

z = eig(A);
keep = abs(z) > opt.modal_zmin;          % drop deadbeat/algebraic z~0 states
zc = z(keep);
if isempty(zc)
    s.status = 'SKIPPED';
    s.note = 'no non-degenerate modes after dropping z~0 states';
    return
end
sp = log(zc) / Ts;                        % discrete -> continuous s-plane
fn = abs(sp) / (2*pi);                    % natural frequency, Hz
zeta = -real(sp) ./ max(abs(sp), eps);    % damping ratio
isOsc = imag(sp) ~= 0;

s.n_modes = numel(zc);
oscMask = isOsc & fn >= opt.modal_fmin & fn <= opt.modal_fmax;
s.n_oscillatory = nnz(oscMask);
if any(oscMask)
    s.min_damping = min(zeta(oscMask));
else
    s.min_damping = NaN;
end

% Assemble a sorted mode table (oscillatory modes by frequency).
modes = struct('freq_hz',{},'damping',{},'real',{},'imag',{});
idxOsc = find(oscMask);
[~, ord] = sort(fn(idxOsc));
idxOsc = idxOsc(ord);
for j = 1:numel(idxOsc)
    i = idxOsc(j);
    modes(end+1) = struct('freq_hz',fn(i),'damping',zeta(i), ...
        'real',real(sp(i)),'imag',imag(sp(i))); %#ok<AGROW>
end
s.modes = modes;
s.lightly_damped = arrayfun(@(m) m.damping < opt.modal_min_damping, modes);

% Reports.
outDir = fullfile(projectRoot, 'build', 'reports', 'modal', modelName);
if ~isfolder(outDir); mkdir(outDir); end
s.report_path = fullfile(iterDir, 'modal_summary.md');
s.json_path   = fullfile(iterDir, 'modal_summary.json');
write_modal_reports(s, modelName, opt, outDir);
end


% ---------------------------------------------------------------
function write_modal_reports(s, modelName, opt, mirrorDir)
lines = {};
lines{end+1} = '# Small-Signal Modal Analysis (S8B)';
lines{end+1} = '';
lines{end+1} = sprintf('Model: `%s`', modelName);
lines{end+1} = sprintf('Linearization: dlinmod, Ts=%.3g s, discrete->s via s=ln(z)/Ts', opt.modal_ts);
lines{end+1} = sprintf('Modes analyzed: %d (oscillatory in [%.3g,%.3g] Hz: %d)', ...
    s.n_modes, opt.modal_fmin, opt.modal_fmax, s.n_oscillatory);
if ~isnan(s.min_damping)
    lines{end+1} = sprintf('Minimum oscillatory damping ratio: %.4f (floor %.3g)', ...
        s.min_damping, opt.modal_min_damping);
end
lines{end+1} = '';
lines{end+1} = '| Freq (Hz) | Damping | Re(s) | Im(s) | lightly-damped |';
lines{end+1} = '|---:|---:|---:|---:|---|';
for k = 1:numel(s.modes)
    m = s.modes(k);
    flag = '';
    if m.damping < opt.modal_min_damping; flag = 'YES'; end
    lines{end+1} = sprintf('| %.3f | %.4f | %.4g | %.4g | %s |', ...
        m.freq_hz, m.damping, m.real, m.imag, flag); %#ok<AGROW>
end
txt = strjoin(lines, newline);

fid = fopen(s.report_path, 'w');
if fid >= 0
    oc = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', txt);
end
% mirror canonical copy
mp = fullfile(mirrorDir, 'modal_summary.md');
fm = fopen(mp, 'w');
if fm >= 0
    oc2 = onCleanup(@() fclose(fm));
    fprintf(fm, '%s\n', txt);
end
% json
payload = struct('model',modelName,'n_modes',s.n_modes, ...
    'n_oscillatory',s.n_oscillatory,'min_damping',s.min_damping,'modes',s.modes);
fj = fopen(s.json_path, 'w');
if fj >= 0
    oc3 = onCleanup(@() fclose(fj));
    fprintf(fj, '%s\n', jsonencode(payload, 'PrettyPrint', true));
end
end
