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
%
% Each derived model adds its own block paths. PLL is the primary knob,
% but the rotor-side / grid-side current PI, DC-link PI and speed PI are all
% real mask parameters on the DFIG_W33 subsystem (inherited from the baseline
% W33 donor: Krotor_side_cur_reg, Kgrid_side_cur_reg, Kdc, Kspeed). They are
% read and written directly with get_param/set_param — there is no InitFcn /
% workspace-variable indirection. Verified on nebus39_dfig_weakgrid_v0:
% all five knobs resolve via get_param and accept set_param.

reg = struct('id',{},'block_path',{},'mask_param',{}, ...
    'current',{},'min',{},'max',{},'units',{}, ...
    'fs_targets',{},'scale_fcn',{});

if ~bdIsLoaded(modelName); error('Model %s not loaded', modelName); end

mn = char(modelName);
% --- Discover DFIG instance(s) at root level ---
roots = find_system(mn,'SearchDepth',1,'BlockType','SubSystem');
dfig_names = {};
for k = 1:numel(roots)
    nm = strtrim(regexprep(get_param(roots{k},'Name'),'\n',' '));
    if startsWith(nm,'DFIG_W33')
        dfig_names{end+1} = nm; %#ok<AGROW>
    end
end

maxEntries = 5 * numel(dfig_names);
if maxEntries == 0
    return
end
entryTemplate = struct('id','','block_path','','mask_param','', ...
    'current',[],'min',[],'max',[],'units','', ...
    'fs_targets',{{}},'scale_fcn',[]);
reg = repmat(entryTemplate, 1, maxEntries);
entryCount = 0;

% --- Per-DFIG knobs ---
for d = 1:numel(dfig_names)
    dfig = dfig_names{d};
    suffix = '';
    if numel(dfig_names) > 1
        suffix = strrep(dfig, 'DFIG_W33', '');
        if isempty(suffix); suffix = sprintf('_%d', d); end
    end
    dfigPath = sprintf('%s/%s', mn, dfig);

    % PLL ParK (sub-block of W33's measurement & transformation)
    pllPath = locate_pll_in_dfig(mn, dfig);
    if ~isempty(pllPath)
        entryCount = entryCount + 1;
        reg(entryCount) = make_entry( ...
            ['pll' suffix], pllPath, 'ParK', ...
            [0.5 0.3 0.1 5], [200 1000 50 1000], ...
            '[Kp1 Ki1 Kp2 Ki2] PLL gains', ...
            {'FS-009','FS-013','FS-014'}, ...
            @(v, dir) scale_vector(v, dir, 1.5));
    end

    % Rotor-side current PI: Krotor_side_cur_reg = [Kp Ki]
    if getSimulinkBlockHandle(dfigPath) ~= -1
        entryCount = entryCount + 1;
        reg(entryCount) = make_entry( ...
            ['rotor_pi' suffix], dfigPath, 'Krotor_side_cur_reg', ...
            [0.05 0.5], [10 200], ...
            '[Kp Ki] rotor-side current PI', ...
            {'FS-013','FS-014','FS-006'}, ...
            @(v, dir) scale_vector(v, dir, 1.5));

        % Grid-side current PI: Kgrid_side_cur_reg = [Kp Ki]
        entryCount = entryCount + 1;
        reg(entryCount) = make_entry( ...
            ['grid_pi' suffix], dfigPath, 'Kgrid_side_cur_reg', ...
            [0.05 0.5], [10 200], ...
            '[Kp Ki] grid-side current PI', ...
            {'FS-013','FS-014','FS-006'}, ...
            @(v, dir) scale_vector(v, dir, 1.5));

        % DC link voltage PI: Kdc = [Kp Ki]
        entryCount = entryCount + 1;
        reg(entryCount) = make_entry( ...
            ['dc_pi' suffix], dfigPath, 'Kdc', ...
            [0.5 20], [200 5000], ...
            '[Kp Ki] DC bus voltage PI', ...
            {'FS-006','FS-014'}, ...
            @(v, dir) scale_vector(v, dir, 1.5));

        % Speed PI: Kspeed = [Kp Ki]
        entryCount = entryCount + 1;
        reg(entryCount) = make_entry( ...
            ['speed_pi' suffix], dfigPath, 'Kspeed', ...
            [0.3 0.06], [50 50], ...
            '[Kp Ki] speed PI', ...
            {'FS-014'}, ...
            @(v, dir) scale_vector(v, dir, 1.5));
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
function e = make_entry(id, blkPath, maskParam, lo, hi, units, fs, sf)
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
end
