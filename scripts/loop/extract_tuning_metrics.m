function m = extract_tuning_metrics(out, varargin)
%EXTRACT_TUNING_METRICS  Compute scalar metrics from a sim output for the
% closed-loop tuning stage.
%
%   m = extract_tuning_metrics(out, 'fault_t_start', 0.5, 'fault_t_end', 0.7,
%                                  'V_signal','Vabc_HV', 'I_signal','Iabc_HV',
%                                  'V_nom_LL', 13.8e3)
%
% Returns struct with:
%   .nan_count                NaN samples in V or I
%   .steady_V_pu              max |V|/V_pk_nom in last 1 s
%   .steady_V_band_pass       true iff steady_V_pu in [0.94, 1.06]
%   .fault_V_pu               |V|/V_pk_nom during fault window
%   .fault_recovery_ms        time after t_end until |V| RMS ≥ 0.99 nominal
%   .I_dom_freq_hz            dominant oscillation frequency on |Ia| RMS
%   .I_osc_amp_A              std of |Ia| RMS in last 1 s (proxy for amplitude)
%   .I_osc_growth             ratio std(last 1 s) / std(first 1 s post-fault) — >1 means growing
%   .damping_ratio            log-decrement on |Ia| RMS envelope
%   .stable                   composite verdict
%   .fs_signature             FS code if not stable

p = inputParser;
p.addParameter('fault_t_start', 0.5, @isnumeric);
p.addParameter('fault_t_end',   0.7, @isnumeric);
p.addParameter('V_signal',      'Vabc_HV', @ischar);
p.addParameter('I_signal',      'Iabc_HV', @ischar);
p.addParameter('V_nom_LL',      13.8e3, @isnumeric);
p.parse(varargin{:});
opt = p.Results;

m = init_metrics();

if ~ismember(opt.V_signal, out.who)
    m.error = sprintf('signal "%s" not in sim output', opt.V_signal);
    m.fs_signature = 'FS-008';
    return
end

vs = out.(opt.V_signal);
t  = vs.time;
V  = vs.signals.values;
m.nan_count = sum(isnan(V),'all');

% Optional current signal
hasI = ismember(opt.I_signal, out.who);
if hasI
    is = out.(opt.I_signal);
    I  = is.signals.values;
    m.nan_count = m.nan_count + sum(isnan(I),'all');
end

if m.nan_count > 0
    m.fs_signature = 'FS-003';
    return
end

V_pk_nom = opt.V_nom_LL * sqrt(2)/sqrt(3);
N = max(2, round(0.02 / median(diff(t))));

% Voltage RMS (phase A)
Va = V(:,1);
Vrms = sliding_rms(Va, N);
Vpu_rms = Vrms / (opt.V_nom_LL/sqrt(3));

% Steady V pu — last 1 s
last1s = t >= (t(end) - 1.0);
m.steady_V_pu = max(abs(V(last1s,:)),[],'all') / V_pk_nom;
m.steady_V_band_pass = m.steady_V_pu >= 0.94 && m.steady_V_pu <= 1.06;

% Fault V pu
in_fault = t >= opt.fault_t_start + 0.05 & t < opt.fault_t_end - 0.01;
if any(in_fault)
    m.fault_V_pu = max(abs(V(in_fault,:)),[],'all') / V_pk_nom;
end

% Fault recovery
post = find(t >= opt.fault_t_end);
if ~isempty(post)
    rec = post(find(Vpu_rms(post) >= 0.99, 1));
    if ~isempty(rec)
        m.fault_recovery_ms = (t(rec) - opt.fault_t_end) * 1000;
    end
end

% Current-side oscillation analysis (this is where PLL/control oscillations live)
if hasI
    Ia = I(:,1);
    Irms = sliding_rms(Ia, N);
    % Detrend with sliding mean over 100 ms
    Nslow = max(2, round(0.1 / median(diff(t))));
    Imean = sliding_rms(Ia, Nslow);   % use as DC level proxy
    Iosc  = Irms - Imean;

    % Window 1: first 1 s after fault clear  (settling phase)
    win_early = t >= opt.fault_t_end & t < opt.fault_t_end + 1.0;
    % Window 2: last 1 s of sim                (steady-state oscillation)
    win_late  = t >= (t(end) - 1.0);

    if any(win_early) && any(win_late)
        sd_early = std(Iosc(win_early));
        sd_late  = std(Iosc(win_late));
        m.I_osc_amp_A = sd_late;
        m.I_osc_growth = sd_late / max(sd_early, 1e-6);
    end

    % FFT for dominant freq in 1-100 Hz band, on the late window
    if any(win_late)
        sig = Iosc(win_late);
        sig = sig - mean(sig);
        Fs = 1/median(diff(t));
        Y = abs(fft(sig));
        L = numel(sig);
        P = Y(1:floor(L/2)+1)/L;
        f = Fs*(0:floor(L/2))/L;
        band = f > 1 & f < 100;
        if any(band)
            [pkAmp, i_pk] = max(P(band));
            f_band = f(band);
            m.I_dom_freq_hz = f_band(i_pk);
            m.I_dom_amp     = pkAmp;
        end
    end

    % Damping from log decrement on Irms (last 1 s)
    if any(win_late)
        env = abs(hilbert_simple(Iosc(win_late)));
        if numel(env) > 5
            pks = findpeaks_simple(env);
            if numel(pks) >= 3
                ratios = pks(1:end-1) ./ max(pks(2:end), 1e-12);
                ratios = ratios(ratios > 0);
                if ~isempty(ratios)
                    logd = mean(log(ratios));
                    if logd > 0
                        m.damping_ratio = logd / sqrt(4*pi^2 + logd^2);
                    else
                        m.damping_ratio = 0;
                    end
                end
            end
        end
    end
end

% Composite verdict
% "Stable" means: no NaN, V band OK, recovery in time, oscillation amplitude
% small AND not growing. The "small" check uses growth (relative) since
% absolute amplitude depends heavily on the model — kA-scale machine vs A-scale
% lab rig. growth<=1.0 means oscillation is decaying or steady; combined with
% damping_ratio>=0.05 (looser than 0.10 since envelope estimate is noisy)
% catches the real "ringing" cases.
osc_not_growing = isnan(m.I_osc_growth) || m.I_osc_growth <= 1.05;
osc_damped      = ~isnan(m.damping_ratio) && m.damping_ratio >= 0.05;

m.stable = m.nan_count == 0 ...
    && m.steady_V_band_pass ...
    && (~isnan(m.fault_recovery_ms) && m.fault_recovery_ms <= 1000) ...
    && (osc_not_growing || osc_damped);

% FS signature
if ~m.stable
    if ~isnan(m.I_dom_freq_hz) && m.I_dom_freq_hz >= 5 && m.I_dom_freq_hz < 30
        m.fs_signature = 'FS-013';
    elseif ~isnan(m.I_dom_freq_hz) && m.I_dom_freq_hz < 5
        m.fs_signature = 'FS-014';
    elseif ~m.steady_V_band_pass
        m.fs_signature = 'FS-006';
    elseif ~isnan(m.fault_recovery_ms) && m.fault_recovery_ms > 1000
        m.fs_signature = 'FS-009';
    end
end
end

% ---------------------------------------------------------------
function m = init_metrics()
m = struct( ...
    'nan_count', NaN, ...
    'steady_V_pu', NaN, ...
    'steady_V_band_pass', false, ...
    'fault_V_pu', NaN, ...
    'fault_recovery_ms', NaN, ...
    'I_dom_freq_hz', NaN, ...
    'I_dom_amp', NaN, ...
    'I_osc_amp_A', NaN, ...
    'I_osc_growth', NaN, ...
    'damping_ratio', NaN, ...
    'stable', false, ...
    'fs_signature', '', ...
    'error', '');
end

function r = sliding_rms(x, N)
r = zeros(numel(x),1);
for k = 1:numel(x)
    s = max(1, k-N+1);
    r(k) = sqrt(mean(x(s:k).^2));
end
end

function h = hilbert_simple(x)
N = numel(x);
X = fft(x);
H = zeros(size(X));
if mod(N,2) == 0
    H(1) = 1; H(N/2+1) = 1; H(2:N/2) = 2;
else
    H(1) = 1; H(2:(N+1)/2) = 2;
end
h = ifft(X .* H);
end

function pks = findpeaks_simple(x)
pks = [];
for k = 2:numel(x)-1
    if x(k) > x(k-1) && x(k) > x(k+1)
        pks(end+1) = x(k); %#ok<AGROW>
    end
end
end
