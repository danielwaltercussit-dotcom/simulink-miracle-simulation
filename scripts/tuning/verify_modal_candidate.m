function check = verify_modal_candidate(modelName,analysis,Ts,varargin)
%VERIFY_MODAL_CANDIDATE Re-linearize and confirm predicted modal movement.

p = inputParser;
p.addParameter('Tolerance',1e-5,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
p.addParameter('LinearizeFcn',[],@(x)isempty(x)||isa(x,'function_handle'));
p.parse(varargin{:});
opt = p.Results;

check = struct('status','FAIL','confirmed',false,'reason','', ...
    'sample_time',Ts,'tolerance',opt.Tolerance,'pre_damping',[], ...
    'post_damping',[],'damping_delta',[],'post_pole_real',[], ...
    'post_pole_imag',[]);
if ~isstruct(analysis) || ~isfield(analysis,'sensitivity') || ...
        ~isstruct(analysis.sensitivity) || ...
        ~isfield(analysis.sensitivity,'modes') || ...
        ~isfield(analysis.sensitivity,'recommendation')
    check.reason = 'pre-write modal sensitivity is unavailable';
    return
end
sensitivity = analysis.sensitivity;
rows = reshape(double(sensitivity.recommendation.critical_mode_rows),1,[]);
rows = rows(rows >= 1 & rows <= numel(sensitivity.modes));
if isempty(rows)
    check.reason = 'pre-write sensitivity contains no critical modes';
    return
end
preModes = sensitivity.modes(rows);
prePoles = [preModes.real] + 1i*[preModes.imag];
check.pre_damping = [preModes.damping_ratio];
try
    if isempty(opt.LinearizeFcn)
        [A,~,~,~] = dlinmod(modelName,Ts);
    else
        A = opt.LinearizeFcn();
    end
catch ME
    check.reason = sprintf('post-write dlinmod failed: %s',ME.message);
    return
end
if ~ismatrix(A) || size(A,1) ~= size(A,2) || any(~isfinite(A),'all')
    check.reason = 'post-write linearization returned an invalid A matrix';
    return
end
z = eig(A);
usable = isfinite(z) & abs(z) > 1e-9;
postPoles = log(z(usable)) / Ts;
if any(imag(prePoles) > 1e-8)
    postPoles = postPoles(imag(postPoles) > 1e-8);
end
if numel(postPoles) < numel(prePoles)
    check.reason = 'post-write linearization has too few matching modes';
    return
end
matched = NaN(size(prePoles));
available = postPoles(:).';
for k = 1:numel(prePoles)
    [~,idx] = min(abs(available-prePoles(k)));
    matched(k) = available(idx);
    available(idx) = [];
end
postDamping = iPoleDamping(matched);
delta = postDamping-check.pre_damping;
check.post_damping = postDamping;
check.damping_delta = delta;
check.post_pole_real = real(matched);
check.post_pole_imag = imag(matched);
check.confirmed = all(isfinite(delta)) && all(delta >= -opt.Tolerance) && ...
    any(delta > opt.Tolerance);
if check.confirmed
    check.status = 'PASS';
    check.reason = 'critical modal damping moved in a non-degrading direction';
else
    check.reason = 'predicted critical-mode damping movement was not confirmed';
end
end


function zeta = iPoleDamping(pole)
mag = abs(pole);
zeta = NaN(size(pole));
valid = mag > eps;
zeta(valid) = -real(pole(valid))./mag(valid);
end
