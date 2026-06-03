function build_nebus39_dfig_weakgrid_v0(varargin)
%BUILD_NEBUS39_DFIG_WEAKGRID_V0  Single-DFIG weak-grid test bench for the
% closed-loop tuning experiment. Initial PLL ParK is intentionally set to
% an unstable value so S6 has to detune.

p = inputParser;
p.addParameter('Force', false, @islogical);
p.parse(varargin{:});
force = p.Results.Force;

projectRoot = 'C:\Users\jonas\Desktop\simulink_agent_v1';
modelName   = 'nebus39_dfig_weakgrid_v0';
outDir      = fullfile(projectRoot,'build','generated_models');
outPath     = fullfile(outDir, [modelName '.slx']);

if ~isfolder(outDir); mkdir(outDir); end
if exist(outPath,'file') && ~force
    error('BuildNebus39WeakGrid:Exists', 'Model exists. Pass Force=true.');
end
if exist(outPath,'file') && force; delete(outPath); end
if bdIsLoaded(modelName); close_system(modelName, 0); end

baselinePath = fullfile(projectRoot,'build','generated_models', ...
    'ieee39_10m39bus_sg5_dfig5_nebus_layout.slx');
baselineName = 'ieee39_10m39bus_sg5_dfig5_nebus_layout';
if ~bdIsLoaded(baselineName); load_system(baselinePath); end

new_system(modelName); load_system(modelName);

% W33 DFIG copy
add_block([baselineName '/W33'], [modelName '/DFIG_W33'], ...
    'Position', [600 200 760 360]);

% NEBUS scaffolding
add_block('powerlib/powergui', [modelName '/powergui'], ...
    'Position', [60 60 130 100]);
set_param([modelName '/powergui'], 'SimulationMode','Discrete', 'SampleTime','5e-5');

add_block('powerlib/Electrical Sources/Three-Phase Programmable Voltage Source', ...
    [modelName '/Vsrc_13kV'], 'Position', [60 200 140 280]);
set_param([modelName '/Vsrc_13kV'], ...
    'PositiveSequence','[13.8e3 0 50]', ...
    'VariationEntity','Amplitude', ...
    'VariationType','Step', ...
    'VariationStep','-0.5', ...
    'VariationTiming','[0.5 0.7]');

add_block('powerlib/Measurements/Three-Phase V-I Measurement', ...
    [modelName '/VI_HV'], 'Position', [165 195 220 285]);
set_param([modelName '/VI_HV'], 'VoltageMeasurement','phase-to-ground','CurrentMeasurement','yes');

% Weak-grid tie line: 0.05 + j0.40 pu (SCR ≈ 2.5)
add_block('powerlib/Elements/Three-Phase Series RLC Branch', ...
    [modelName '/Tie_RLC'], 'Position', [260 210 320 270]);
set_param([modelName '/Tie_RLC'], 'BranchType','RL', ...
    'Resistance','0.05*(13.8e3^2/100e6)', ...
    'Inductance','0.40*(13.8e3^2/100e6)/(2*pi*50)');

add_block('powerlib/Elements/Three-Phase Transformer (Two Windings)', ...
    [modelName '/T1'], 'Position', [380 200 460 280]);
set_param([modelName '/T1'], 'NominalPower','[10e6 50]', ...
    'Winding1Connection','Yg', 'Winding1','[13.8e3 0.001 0.05]', ...
    'Winding2Connection','Yg', 'Winding2','[575    0.001 0.05]', ...
    'Rm','500', 'Lm','500');

add_block('powerlib/Elements/Ground', [modelName '/Gnd'], ...
    'Position', [800 380 830 410]);

add_block('simulink/Sources/Constant', [modelName '/Wind_14'], ...
    'Position', [500 215 540 245], 'Value','14');
add_block('simulink/Sources/Constant', [modelName '/Qref_0'], ...
    'Position', [500 275 540 305], 'Value','0');

% Wire physical
for k = 1:3
    add_line(modelName, sprintf('Vsrc_13kV/RConn%d',k), sprintf('VI_HV/LConn%d',k), 'autorouting','on');
    add_line(modelName, sprintf('VI_HV/RConn%d',k),    sprintf('Tie_RLC/LConn%d',k), 'autorouting','on');
    add_line(modelName, sprintf('Tie_RLC/RConn%d',k),  sprintf('T1/LConn%d',k), 'autorouting','on');
    add_line(modelName, sprintf('T1/RConn%d',k),       sprintf('DFIG_W33/LConn%d',k), 'autorouting','on');
end
add_line(modelName, 'Wind_14/1', 'DFIG_W33/1', 'autorouting','on');
add_line(modelName, 'Qref_0/1',  'DFIG_W33/2', 'autorouting','on');

% Logging
add_block('simulink/Sinks/To Workspace', [modelName '/Vabc_log'], ...
    'Position',[260 130 320 160], 'VariableName','Vabc_HV','SaveFormat','Structure With Time');
add_block('simulink/Sinks/To Workspace', [modelName '/Iabc_log'], ...
    'Position',[260 165 320 195], 'VariableName','Iabc_HV','SaveFormat','Structure With Time');
add_line(modelName,'VI_HV/1','Vabc_log/1','autorouting','on');
add_line(modelName,'VI_HV/2','Iabc_log/1','autorouting','on');

% Solver / InitFcn
set_param(modelName, 'StopTime','5.0', ...
    'SolverType','Fixed-step', 'Solver','FixedStepDiscrete', ...
    'FixedStep','5e-5', 'StartTime','0');
set_param(modelName, 'InitFcn', sprintf([ ...
    'Ts = 5e-5;\n' 'Tsample = Ts;\n']));

set_param(modelName, 'Description', sprintf([ ...
    'Weak-grid (SCR=2.5) DFIG test bench for closed-loop PLL tuning.\n' ...
    'Spec: specs/case_nebus39_dfig_weakgrid_v0.yaml\n' ...
    'Built: %s'], datetime('now','Format','yyyy-MM-dd HH:mm:ss')));

% Intentionally raise PLL ParK to push it into unstable region
% (M01 default ≈ [5 3.2 1 50]; we set 3x to drive oscillation)
pllParent = sprintf('%s/DFIG_W33/Control/Measurement and Transformation', modelName);
hits = find_system(pllParent,'LookUnderMasks','all','SearchDepth',1,'BlockType','SubSystem');
for k = 1:numel(hits)
    nm = get_param(hits{k},'Name');
    if contains(nm,'Improved Discrete') && contains(nm,'PLL')
        set_param(hits{k}, 'ParK', '[15 9.6 3 150]');
        fprintf('PLL ParK set to [15 9.6 3 150] (3x M01 default, expected unstable at SCR=2.5)\n');
        break
    end
end

% Self-checks
scan_block_overlap(modelName, 'ThrowOnFail', true, ...
    'Recursive', true, 'SkipPattern', {'DFIG_W33'});

save_system(modelName, outPath);
fprintf('Saved: %s\n', outPath);
end
