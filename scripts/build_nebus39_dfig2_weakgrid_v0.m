function build_nebus39_dfig2_weakgrid_v0(varargin)
%BUILD_NEBUS39_DFIG2_WEAKGRID_V0  Two-DFIG-parallel weak-grid bench for
% multi-knob closed-loop tuning. SCR ≈ 2.5; DFIG_W33_a has its PLL set to
% an unstable value while DFIG_W33_b is at M01 default. The closed loop has
% to identify which unit is misconfigured and detune only that knob.

p = inputParser;
p.addParameter('Force', false, @islogical);
p.parse(varargin{:});
force = p.Results.Force;

projectRoot = 'C:\Users\jonas\Desktop\simulink_agent_v1';
modelName   = 'nebus39_dfig2_weakgrid_v0';
outDir      = fullfile(projectRoot,'build','generated_models');
outPath     = fullfile(outDir, [modelName '.slx']);

if ~isfolder(outDir); mkdir(outDir); end
if exist(outPath,'file') && ~force
    error('Build:Exists','Model exists. Force=true to overwrite.');
end
if exist(outPath,'file') && force; delete(outPath); end
if bdIsLoaded(modelName); close_system(modelName, 0); end

baselinePath = fullfile(projectRoot,'build','generated_models', ...
    'ieee39_10m39bus_sg5_dfig5_nebus_layout.slx');
baselineName = 'ieee39_10m39bus_sg5_dfig5_nebus_layout';
if ~bdIsLoaded(baselineName); load_system(baselinePath); end

new_system(modelName); load_system(modelName);

% Two DFIG copies
add_block([baselineName '/W33'], [modelName '/DFIG_W33_a'], 'Position',[600 100 760 260]);
add_block([baselineName '/W33'], [modelName '/DFIG_W33_b'], 'Position',[600 360 760 520]);

add_block('powerlib/powergui',[modelName '/powergui'],'Position',[60 60 130 100]);
set_param([modelName '/powergui'],'SimulationMode','Discrete','SampleTime','5e-5');

add_block('powerlib/Electrical Sources/Three-Phase Programmable Voltage Source', ...
    [modelName '/Vsrc_13kV'],'Position',[60 200 140 280]);
set_param([modelName '/Vsrc_13kV'], ...
    'PositiveSequence','[13.8e3 0 50]','VariationEntity','Amplitude', ...
    'VariationType','Step','VariationStep','-0.5','VariationTiming','[0.5 0.7]');

add_block('powerlib/Measurements/Three-Phase V-I Measurement', ...
    [modelName '/VI_HV'],'Position',[165 195 220 285]);
set_param([modelName '/VI_HV'],'VoltageMeasurement','phase-to-ground','CurrentMeasurement','yes');

% Weak tie line: same impedance as nebus39_dfig_weakgrid_v0
add_block('powerlib/Elements/Three-Phase Series RLC Branch', ...
    [modelName '/Tie_RLC'],'Position',[260 210 320 270]);
set_param([modelName '/Tie_RLC'],'BranchType','RL', ...
    'Resistance','0.05*(13.8e3^2/100e6)', ...
    'Inductance','0.40*(13.8e3^2/100e6)/(2*pi*50)');

% Two transformers
add_block('powerlib/Elements/Three-Phase Transformer (Two Windings)', ...
    [modelName '/T1'],'Position',[380 140 460 220]);
add_block('powerlib/Elements/Three-Phase Transformer (Two Windings)', ...
    [modelName '/T2'],'Position',[380 380 460 460]);
for tname = {'T1','T2'}
    set_param([modelName '/' tname{1}],'NominalPower','[10e6 50]', ...
        'Winding1Connection','Yg','Winding1','[13.8e3 0.001 0.05]', ...
        'Winding2Connection','Yg','Winding2','[575    0.001 0.05]', ...
        'Rm','500','Lm','500');
end

add_block('powerlib/Elements/Ground',[modelName '/Gnd_a'],'Position',[800 280 830 310]);
add_block('powerlib/Elements/Ground',[modelName '/Gnd_b'],'Position',[800 540 830 570]);

add_block('simulink/Sources/Constant',[modelName '/Wind_a'],'Position',[500 115 540 145],'Value','14');
add_block('simulink/Sources/Constant',[modelName '/Qref_a'],'Position',[500 175 540 205],'Value','0');
add_block('simulink/Sources/Constant',[modelName '/Wind_b'],'Position',[500 375 540 405],'Value','14');
add_block('simulink/Sources/Constant',[modelName '/Qref_b'],'Position',[500 435 540 465],'Value','0');

% Wire physical
for k = 1:3
    add_line(modelName, sprintf('Vsrc_13kV/RConn%d',k), sprintf('VI_HV/LConn%d',k),'autorouting','on');
    add_line(modelName, sprintf('VI_HV/RConn%d',k),    sprintf('Tie_RLC/LConn%d',k),'autorouting','on');
    add_line(modelName, sprintf('Tie_RLC/RConn%d',k),  sprintf('T1/LConn%d',k),'autorouting','on');
    add_line(modelName, sprintf('Tie_RLC/RConn%d',k),  sprintf('T2/LConn%d',k),'autorouting','on');
    add_line(modelName, sprintf('T1/RConn%d',k),       sprintf('DFIG_W33_a/LConn%d',k),'autorouting','on');
    add_line(modelName, sprintf('T2/RConn%d',k),       sprintf('DFIG_W33_b/LConn%d',k),'autorouting','on');
end
add_line(modelName,'Wind_a/1','DFIG_W33_a/1','autorouting','on');
add_line(modelName,'Qref_a/1','DFIG_W33_a/2','autorouting','on');
add_line(modelName,'Wind_b/1','DFIG_W33_b/1','autorouting','on');
add_line(modelName,'Qref_b/1','DFIG_W33_b/2','autorouting','on');

% Logging
add_block('simulink/Sinks/To Workspace',[modelName '/Vabc_log'], ...
    'Position',[260 130 320 160],'VariableName','Vabc_HV','SaveFormat','Structure With Time');
add_block('simulink/Sinks/To Workspace',[modelName '/Iabc_log'], ...
    'Position',[260 165 320 195],'VariableName','Iabc_HV','SaveFormat','Structure With Time');
add_line(modelName,'VI_HV/1','Vabc_log/1','autorouting','on');
add_line(modelName,'VI_HV/2','Iabc_log/1','autorouting','on');

% Solver / InitFcn
set_param(modelName,'StopTime','5.0','SolverType','Fixed-step', ...
    'Solver','FixedStepDiscrete','FixedStep','5e-5','StartTime','0');
set_param(modelName,'InitFcn',sprintf('Ts = 5e-5;\nTsample = Ts;\n'));
set_param(modelName,'Description',sprintf([ ...
    'Two-DFIG parallel weak-grid (SCR=2.5) bench. DFIG_W33_a PLL set to\n' ...
    'unstable value [15 9.6 3 150]; DFIG_W33_b at M01 default [5 3.2 1 50].\n' ...
    'Built: %s'],datetime('now','Format','yyyy-MM-dd HH:mm:ss')));

% --- Configure PLLs differently per unit ---
configure_pll(modelName, 'DFIG_W33_a', '[15 9.6 3 150]');   % unstable
configure_pll(modelName, 'DFIG_W33_b', '[5 3.2 1 50]');     % default

scan_block_overlap(modelName,'ThrowOnFail',true, ...
    'Recursive', true, 'SkipPattern', {'DFIG_W33'});
save_system(modelName, outPath);
fprintf('Saved: %s\n', outPath);
end

function configure_pll(modelName, dfigName, parkVal)
parent = sprintf('%s/%s/Control/Measurement and Transformation', modelName, dfigName);
hits = find_system(parent,'LookUnderMasks','all','SearchDepth',1,'BlockType','SubSystem');
for k = 1:numel(hits)
    nm = get_param(hits{k},'Name');
    if contains(nm,'Improved Discrete') && contains(nm,'PLL')
        set_param(hits{k},'ParK',parkVal);
        fprintf('PLL @ %s: ParK = %s\n', dfigName, parkVal);
        return
    end
end
warning('PLL not found in %s', dfigName);
end
