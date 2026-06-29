function margin = dt_loop_stability_metric(varargin)
%DT_LOOP_STABILITY_METRIC Discrete-time current-loop stability margin.
%
%   margin = dt_loop_stability_metric("Ts",100e-6, "DelaySamples",1, ...
%       "SCR",3, "Kp",0.5, "Ki",50, ...)
%
%   Returns a scalar closed-loop stability margin for an ILLUSTRATIVE discrete
%   grid-following current loop. The margin is:
%
%       margin = 1 - max(|closed-loop poles|)
%
%   so margin > 0 means all poles are inside the unit circle (stable) and
%   margin < 0 means at least one pole is outside (unstable). Use it as an
%   "above" pass metric with PassThreshold = 0 (or a small positive margin).
%
%   EVIDENCE TIER: analytic / illustrative ONLY. This is a transparent,
%   reproducible stand-in so the F3 joint boundary-scan machinery has a real
%   coupled metric to exercise. It is NOT a validated converter model, it is
%   NOT a Simulink run, and it is NOT hardware evidence. In particular it models
%   a bare current loop and therefore does NOT capture PLL-driven weak-grid
%   (low-SCR) instability; here higher SCR lowers series inductance and raises
%   loop gain, which is the loop-gain interpretation of SCR, not the PLL one.
%   Do not quote a margin from this function as a physical stability limit.
%
%   Model (closed-loop characteristic polynomial in z):
%     Plant  G(s) = 1/(L s + R),  L = Lf + Lbase/SCR        (ZOH-discretized)
%       a = exp(-(R/L) Ts),  b = (1 - a)/R,  Hd(z) = b/(z - a)
%     PI controller (backward-Euler integrator):
%       C(z) = ((Kp + Ki Ts) z - Kp) / (z - 1)
%     Computational/PWM delay: z^{-nd},  nd = DelaySamples (>= 0 integer)
%     Char. poly:
%       P(z) = (z-1)(z-a) z^{nd} + b (Kp + Ki Ts) z - b Kp
%
%   Couplings: increasing Ts, DelaySamples, Kp, or Ki reduces the margin
%   (all destabilizing in this loop-gain model), and these dominate the
%   boundary. SCR enters only weakly through L = Lf + Lbase/SCR: with a stiff
%   filter inductance Lf the series L barely changes across SCR, so the SCR
%   axis is an ILLUSTRATIVE placeholder here, NOT a weak-grid stability result.
%   A faithful SCR/PLL weak-grid boundary needs a PLL + grid model (next round).
%
%   See .agents/skills/perturbation-stability-boundary-scan/references/stability-boundary-contract.md

opts = iParseOpts(varargin{:});

L = opts.Lf + opts.Lbase / opts.SCR;
if ~(isfinite(L) && L > 0)
    error("DtLoopMetric:BadInductance", ...
        "Series inductance L = Lf + Lbase/SCR must be finite and positive.");
end

a = exp(-(opts.R / L) * opts.Ts);
b = (1 - a) / opts.R;
nd = opts.DelaySamples;
deg = nd + 2;

% (z-1)(z-a) z^{nd} = (z^2 - (1+a) z + a) z^{nd}
c = zeros(1, deg + 1);
c(1) = 1;             % z^{nd+2}
c(2) = -(1 + a);      % z^{nd+1}
c(3) = c(3) + a;      % z^{nd}     (add: overlaps low terms when nd == 0)

% + b (Kp + Ki Ts) z - b Kp
gain = b * (opts.Kp + opts.Ki * opts.Ts);
c(deg)     = c(deg)     + gain;        % z^1
c(deg + 1) = c(deg + 1) - b * opts.Kp; % z^0

poles = roots(c);
if isempty(poles)
    margin = 1;   % degenerate: no dynamics
else
    margin = 1 - max(abs(poles));
end
end


function opts = iParseOpts(varargin)
p = inputParser;
p.addParameter("Ts", 100e-6, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("DelaySamples", 1, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter("SCR", 3, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("Kp", 0.5, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter("Ki", 50, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter("R", 0.01, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter("Lf", 0.5e-3, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter("Lbase", 2e-3, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.parse(varargin{:});
opts = p.Results;
opts.DelaySamples = round(opts.DelaySamples);
end
