function reg = tuning_registry(modelName)
%TUNING_REGISTRY  Returns the list of mask parameters allowed for automatic
% tuning by ai_in_loop_stage_tune for the given derived model.
%
%   reg = tuning_registry('nebus39_dfig_weakgrid_v0')
%
%   Each entry: struct with
%     .id          short-name used in logs (e.g. 'pll_dfig')
%     .block_path  absolute Simulink path to the block (where set_param applies)
%     .mask_param  mask parameter name set on the block
%     .current     numeric current value (from get_param eval)
%     .min, .max   physical bounds (do not propose outside)
%     .units       e.g. 'rad/s', 'pu', 'dimensionless'
%     .fs_targets  cell array of FS ids this knob can fix
%     .scale_fcn   function handle: (oldVal, sigDir) -> newVal
%     .priority    integer tuning-priority group (1..4) per
%                  docs/CONTROL_TUNING_PRIORITY_AND_BOUNDARY.md
%     .parameter_class  short class string, e.g. 'pll', 'current_pi'
%     .control_only     logical; MUST be true before S6 may write the param.
%                  Plant/device physical parameters and ratings are immutable
%                  and are never registered here.
%     .rollback_value   pre-tuning value captured at registry-build time; the
%                  proven restore point for this knob.
%
% Each derived model adds its own block paths. PLL is the primary knob,
% but the rotor-side / grid-side current PI, DC-link PI and speed PI are all
% real mask parameters on the DFIG_W33-family subsystem (inherited from the
% baseline W33 donor: Krotor_side_cur_reg, Kgrid_side_cur_reg, Kdc, Kspeed).
% They are read and written directly with get_param/set_param — there is no
% InitFcn / workspace-variable indirection. Verified on
% nebus39_dfig_weakgrid_v0: all five knobs resolve via get_param and accept
% set_param.
%
% Discovery scope: root-level subsystems named 'W33'..'W37' (the five DFIG
% farms of the real IEEE39 SG5/DFIG5 test), or the legacy 'DFIG_W33'-prefixed
% form used by the single-farm bench. SG AVR/governor and supplementary
% controls are NOT invented here — they are only added once their real block
% path and mask parameter are proven by introspection, per the tuning contract.
%
% Every entry carries priority/parameter_class/control_only/rollback_value so
% the S6 write gate (tuning_entry_is_writable) can reject any unclassified or
% non-control parameter. All knobs registered here are control-only by
% construction.

reg = struct('id',{},'block_path',{},'mask_param',{}, ...
    'current',{},'min',{},'max',{},'units',{}, ...
    'fs_targets',{},'scale_fcn',{}, ...
    'priority',{},'parameter_class',{},'control_only',{},'rollback_value',{});

if ~bdIsLoaded(modelName); error('Model %s not loaded', modelName); end

mn = char(modelName);
% --- Discover DFIG instance(s) at root level (W33..W37 farms) ---
roots = find_system(mn,'SearchDepth',1,'BlockType','SubSystem');
dfig_names = {};
for k = 1:numel(roots)
    nm = strtrim(regexprep(get_param(roots{k},'Name'),'\n',' '));
    if is_dfig_farm_name(nm)
        dfig_names{end+1} = nm; %#ok<AGROW>
    end
end

maxEntries = 5 * numel(dfig_names);
if maxEntries == 0
    return
end
entryTemplate = struct('id','','block_path','','mask_param','', ...
    'current',[],'min',[],'max',[],'units','', ...
    'fs_targets',{{}},'scale_fcn',[], ...
    'priority',[],'parameter_class','','control_only',false,'rollback_value',[]);
reg = repmat(entryTemplate, 1, maxEntries);
entryCount = 0;

% --- Per-DFIG knobs ---
for d = 1:numel(dfig_names)
    dfig = dfig_names{d};
    suffix = farm_suffix(dfig, numel(dfig_names), d);
    dfigPath = sprintf('%s/%s', mn, dfig);

    % PLL ParK (sub-block of the farm's measurement & transformation).
    % Priority 1 (PLL), control-only.
    pllPath = locate_pll_in_dfig(mn, dfig);
    if ~isempty(pllPath)
        entryCount = entryCount + 1;
        reg(entryCount) = make_entry( ...
            ['pll' suffix], pllPath, 'ParK', ...
            [0.5 0.3 0.1 5], [200 1000 50 1000], ...
            '[Kp1 Ki1 Kp2 Ki2] PLL gains', ...
            {'FS-009','FS-013','FS-014'}, ...
            @(v, dir) scale_vector(v, dir, 1.5), 1, 'pll');
    end

    % Rotor-side current PI: Krotor_side_cur_reg = [Kp Ki]. Priority 1.
    if getSimulinkBlockHandle(dfigPath) ~= -1
        entryCount = entryCount + 1;
        reg(entryCount) = make_entry( ...
            ['rotor_pi' suffix], dfigPath, 'Krotor_side_cur_reg', ...
            [0.05 0.5], [10 200], ...
            '[Kp Ki] rotor-side current PI', ...
            {'FS-013','FS-014','FS-006'}, ...
            @(v, dir) scale_vector(v, dir, 1.5), 1, 'current_pi');

        % Grid-side current PI: Kgrid_side_cur_reg = [Kp Ki]. Priority 1.
        entryCount = entryCount + 1;
        reg(entryCount) = make_entry( ...
            ['grid_pi' suffix], dfigPath, 'Kgrid_side_cur_reg', ...
            [0.05 0.5], [10 200], ...
            '[Kp Ki] grid-side current PI', ...
            {'FS-013','FS-014','FS-006'}, ...
            @(v, dir) scale_vector(v, dir, 1.5), 1, 'current_pi');

        % DC link voltage PI: Kdc = [Kp Ki]. Priority 3 (outer/supplementary).
        entryCount = entryCount + 1;
        reg(entryCount) = make_entry( ...
            ['dc_pi' suffix], dfigPath, 'Kdc', ...
            [0.5 20], [200 5000], ...
            '[Kp Ki] DC bus voltage PI', ...
            {'FS-006','FS-014'}, ...
            @(v, dir) scale_vector(v, dir, 1.5), 3, 'dc_link_pi');

        % Speed PI: Kspeed = [Kp Ki]. Priority 3 (outer/supplementary).
        entryCount = entryCount + 1;
        reg(entryCount) = make_entry( ...
            ['speed_pi' suffix], dfigPath, 'Kspeed', ...
            [0.3 0.06], [50 50], ...
            '[Kp Ki] speed PI', ...
            {'FS-014'}, ...
            @(v, dir) scale_vector(v, dir, 1.5), 3, 'speed_pi');
    end
end

reg = reg(1:entryCount);

end

% ---------------------------------------------------------------
function newVal = scale_vector(oldVal, dir, factor)
% Generic vector scaler: dir +1 -> *factor; dir -1 -> /factor.
% Keeps Kp/Ki ratio fixed, shifts loop bandwidth.
if dir > 0
    newVal = oldVal .* factor;
else
    newVal = oldVal ./ factor;
end
end

% ---------------------------------------------------------------
function tf = is_dfig_farm_name(nm)
% True for root-level DFIG farm subsystems of the IEEE39 SG5/DFIG5 test.
% The real five-farm model names them bare 'W33'..'W37'; the legacy single-farm
% bench (nebus39_dfig_weakgrid_v0) uses the 'DFIG_W33' prefix. Accept both.
%
% Anchored so it matches W33..W37 (optionally 'DFIG_'-prefixed) and nothing
% else at root level — in particular NOT the bus-number subsystems '33'..'37',
% 'ST-33', 'TL-33', etc. A trailing digit (e.g. a hypothetical 'W330') is
% rejected so only the five real farm indices match.
tf = ~isempty(regexp(nm, '^(DFIG_)?W3[3-7]([^0-9]|$)', 'once'));
end

% ---------------------------------------------------------------
function suffix = farm_suffix(dfig, nFarms, d)
% Stable per-farm id suffix. With a single farm there is no suffix (keeps
% legacy ids 'pll'/'rotor_pi'/...). With multiple farms, derive '_W34' etc.
% from the farm name; fall back to an index if the name has no W-token.
suffix = '';
if nFarms <= 1
    return
end
tok = regexp(dfig, 'W3[3-7]', 'match', 'once');
if ~isempty(tok)
    suffix = ['_' tok];
else
    suffix = sprintf('_%d', d);
end
end

% ---------------------------------------------------------------
function pllPath = locate_pll_in_dfig(modelName, dfigBlockName)
pllPath = '';
parent = sprintf('%s/%s/Control/Measurement and Transformation', modelName, dfigBlockName);
if getSimulinkBlockHandle(parent) == -1
    return
end
hits = find_system(parent,'LookUnderMasks','all','SearchDepth',1,'BlockType','SubSystem');
for k = 1:numel(hits)
    nm = get_param(hits{k},'Name');
    if contains(nm, 'Improved Discrete') && contains(nm, 'PLL')
        pllPath = hits{k};
        return
    end
end
end

% ---------------------------------------------------------------
function e = make_entry(id, blkPath, maskParam, lo, hi, units, fs, sf, priority, paramClass)
% Build a registry entry. priority/parameter_class classify the knob for the
% S6 write gate; control_only is always true here because only proven control
% parameters are registered. rollback_value snapshots the pre-tuning value so
% there is always a proven restore point even before the first write.
e.id         = id;
e.block_path = blkPath;
e.mask_param = maskParam;
try
    e.current = eval(get_param(blkPath, maskParam));
catch
    e.current = NaN;
end
e.min        = lo;
e.max        = hi;
e.units      = units;
e.fs_targets = fs;
e.scale_fcn  = sf;
e.priority        = priority;
e.parameter_class = paramClass;
e.control_only    = true;
e.rollback_value  = e.current;
end
