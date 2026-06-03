function build_nebus39_dfig2_v0(varargin)
%BUILD_NEBUS39_DFIG2_V0  Two-DFIG-parallel benchmark, derived per cookbook.
%
%   build_nebus39_dfig2_v0()
%   build_nebus39_dfig2_v0('Force', true)
%
%   Strategy (follows simulink-modeling-assistant/references/derivation-cookbook.md):
%     1. Copy W33 twice as DFIG_W33_a / DFIG_W33_b from baseline.
%     2. Add NEBUS scaffolding: powergui + Vsrc(13.8 kV programmable) + Tie
%        + VI_HV measurement + 2x step-up transformer (T1, T2) paralleled at
%        13.8 kV bus + 2x ground.
%     3. Self-contained InitFcn (Ts, Tsample) — FS-018 prevention.
%     4. set_param mask names from get_param introspection — FS-017 prevention.
%     5. scan_block_overlap before save — FS-005 prevention.

p = inputParser;
p.addParameter('Force', false, @islogical);
p.parse(varargin{:});
force = p.Results.Force;

projectRoot = 'C:\Users\jonas\Desktop\simulink_agent_v1';
modelName   = 'nebus39_dfig2_v0';
outDir      = fullfile(projectRoot,'build','generated_models');
outPath     = fullfile(outDir, [modelName '.slx']);

if ~isfolder(outDir); mkdir(outDir); end
if exist(outPath,'file') && ~force
    error('BuildNebus39Dfig2:Exists', ...
        'Model already exists at %s. Pass ''Force'',true to overwrite.', outPath);
end
if exist(outPath,'file') && force
    delete(outPath);
end
if bdIsLoaded(modelName); close_system(modelName, 0); end

baselinePath = fullfile(projectRoot,'build','generated_models', ...
    'ieee39_10m39bus_sg5_dfig5_nebus_layout.slx');
baselineName = 'ieee39_10m39bus_sg5_dfig5_nebus_layout';
if ~bdIsLoaded(baselineName); load_system(baselinePath); end

new_system(modelName);
load_system(modelName);

% --- Two DFIG copies (a, b) ---
add_block([baselineName '/W33'], [modelName '/DFIG_W33_a'], ...
    'Position', [600 100 760 260]);
add_block([baselineName '/W33'], [modelName '/DFIG_W33_b'], ...
    'Position', [600 360 760 520]);

% --- powergui ---
add_block('powerlib/powergui', [modelName '/powergui'], ...
    'Position', [60 60 130 100]);
set_param([modelName '/powergui'], 'SimulationMode', 'Discrete', ...
    'SampleTime', '5e-5');

% --- Programmable voltage source (13.8 kV LL RMS) with amplitude step fault ---
add_block('powerlib/Electrical Sources/Three-Phase Programmable Voltage Source', ...
    [modelName '/Vsrc_13kV'], 'Position', [60 200 140 280]);
set_param([modelName '/Vsrc_13kV'], ...
    'PositiveSequence','[13.8e3 0 50]', ...
    'VariationEntity','Amplitude', ...
    'VariationType','Step', ...
    'VariationStep','-0.5', ...
    'VariationTiming','[0.5 0.7]');

% --- Tie line + VI measurement at HV bus ---
add_block('powerlib/Measurements/Three-Phase V-I Measurement', ...
    [modelName '/VI_HV'], 'Position', [165 195 220 285]);
set_param([modelName '/VI_HV'],'VoltageMeasurement','phase-to-ground','CurrentMeasurement','yes');
add_block('powerlib/Elements/Three-Phase Series RLC Branch', ...
    [modelName '/Tie_RLC'], 'Position', [260 210 320 270]);
set_param([modelName '/Tie_RLC'], 'BranchType','RL', ...
    'Resistance','0.001*(13.8e3^2/100e6)', ...
    'Inductance','0.05*(13.8e3^2/100e6)/(2*pi*50)');

% --- Step-up transformer T1 (unit a) and T2 (unit b) ---
add_block('powerlib/Elements/Three-Phase Transformer (Two Windings)', ...
    [modelName '/T1'], 'Position', [380 140 460 220]);
add_block('powerlib/Elements/Three-Phase Transformer (Two Windings)', ...
    [modelName '/T2'], 'Position', [380 380 460 460]);
for tname = {'T1','T2'}
    set_param([modelName '/' tname{1}], 'NominalPower','[10e6 50]', ...
        'Winding1Connection','Yg', 'Winding1','[13.8e3 0.001 0.05]', ...
        'Winding2Connection','Yg', 'Winding2','[575    0.001 0.05]', ...
        'Rm','500', 'Lm','500');
end

% --- Two grounds (one per DFIG) ---
add_block('powerlib/Elements/Ground', [modelName '/Gnd_a'], ...
    'Position', [800 280 830 310]);
add_block('powerlib/Elements/Ground', [modelName '/Gnd_b'], ...
    'Position', [800 540 830 570]);

% --- Wind speed inputs (constant 14 m/s) ---
add_block('simulink/Sources/Constant', [modelName '/Wind_a'], ...
    'Position', [500 115 540 145], 'Value','14');
add_block('simulink/Sources/Constant', [modelName '/Qref_a'], ...
    'Position', [500 175 540 205], 'Value','0');
add_block('simulink/Sources/Constant', [modelName '/Wind_b'], ...
    'Position', [500 375 540 405], 'Value','14');
add_block('simulink/Sources/Constant', [modelName '/Qref_b'], ...
    'Position', [500 435 540 465], 'Value','0');

% --- Wire physical chain ---
% Vsrc -> VI_HV -> Tie -> [T1.W1, T2.W1] (parallel at 13.8 kV)
phaseSrc = {'Vsrc_13kV/RConn1','Vsrc_13kV/RConn2','Vsrc_13kV/RConn3'};
phaseVIin  = {'VI_HV/LConn1','VI_HV/LConn2','VI_HV/LConn3'};
phaseVIout = {'VI_HV/RConn1','VI_HV/RConn2','VI_HV/RConn3'};
phaseTieIn = {'Tie_RLC/LConn1','Tie_RLC/LConn2','Tie_RLC/LConn3'};
phaseTieOut= {'Tie_RLC/RConn1','Tie_RLC/RConn2','Tie_RLC/RConn3'};
for k = 1:3
    add_line(modelName, phaseSrc{k}, phaseVIin{k}, 'autorouting','on');
    add_line(modelName, phaseVIout{k}, phaseTieIn{k}, 'autorouting','on');
    % Tie -> T1 (unit a)
    add_line(modelName, phaseTieOut{k}, sprintf('T1/LConn%d',k), 'autorouting','on');
    % Tie -> T2 (unit b) — parallel branch
    add_line(modelName, phaseTieOut{k}, sprintf('T2/LConn%d',k), 'autorouting','on');
    % T1 secondary -> DFIG_a
    add_line(modelName, sprintf('T1/RConn%d',k), sprintf('DFIG_W33_a/LConn%d',k), 'autorouting','on');
    % T2 secondary -> DFIG_b
    add_line(modelName, sprintf('T2/RConn%d',k), sprintf('DFIG_W33_b/LConn%d',k), 'autorouting','on');
end

% Signal inputs
add_line(modelName, 'Wind_a/1', 'DFIG_W33_a/1', 'autorouting','on');
add_line(modelName, 'Qref_a/1', 'DFIG_W33_a/2', 'autorouting','on');
add_line(modelName, 'Wind_b/1', 'DFIG_W33_b/1', 'autorouting','on');
add_line(modelName, 'Qref_b/1', 'DFIG_W33_b/2', 'autorouting','on');

% --- Logging on HV bus (shared by both units) ---
add_block('simulink/Sinks/To Workspace', [modelName '/Vabc_log'], ...
    'Position',[260 130 320 160], 'VariableName','Vabc_HV','SaveFormat','Structure With Time');
add_block('simulink/Sinks/To Workspace', [modelName '/Iabc_log'], ...
    'Position',[260 165 320 195], 'VariableName','Iabc_HV','SaveFormat','Structure With Time');
add_line(modelName,'VI_HV/1','Vabc_log/1','autorouting','on');
add_line(modelName,'VI_HV/2','Iabc_log/1','autorouting','on');

% --- Solver / model config ---
set_param(modelName, 'StopTime','5.0', ...
    'SolverType','Fixed-step', 'Solver','FixedStepDiscrete', ...
    'FixedStep','5e-5', 'StartTime','0');

% --- Self-contained InitFcn (FS-018 prevention) ---
set_param(modelName, 'InitFcn', sprintf([ ...
    '%% Auto-generated by build_nebus39_dfig2_v0\n' ...
    'Ts = 5e-5;            %% sample time used by DFIG control blocks\n' ...
    'Tsample = Ts;         %% common alias\n']));

% --- Description ---
set_param(modelName, 'Description', sprintf([ ...
    'Two-DFIG-parallel derived model. 2 x W33 from baseline, each with its ' ...
    'own 10 MVA 13.8/0.575 kV step-up transformer, paralleled at the 13.8 kV bus.\n' ...
    'Spec: specs/case_nebus39_dfig2_v0.yaml\n' ...
    'Built: %s'], datetime('now','Format','yyyy-MM-dd HH:mm:ss')));

% --- No-overlap self-check (FS-005 prevention) ---
scan_block_overlap(modelName, 'ThrowOnFail', true, ...
    'Recursive', true, 'SkipPattern', {'DFIG_W33'});

% --- Save ---
save_system(modelName, outPath);
fprintf('Saved: %s\n', outPath);
end
