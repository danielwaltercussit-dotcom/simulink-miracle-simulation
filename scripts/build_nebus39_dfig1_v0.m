function build_nebus39_dfig1_v0(varargin)
%BUILD_NEBUS39_DFIG1_V0  Derive a single-DFIG benchmark from M07 top + W33 DFIG.
%
%   build_nebus39_dfig1_v0()
%   build_nebus39_dfig1_v0('Force', true)
%
%   Strategy:
%     1. Copy W33 (a complete Asynchronous-Machine-based DFIG sub-system,
%        ~1860 blocks incl. controls) from the project baseline into a new
%        empty model.
%     2. Add the M07 NEBUS top-level scaffolding: powergui, programmable
%        voltage source, series RLC tie line, step-up transformer, ground.
%     3. Wire 13.8 kV source -> RLC tie -> 13.8/0.575 kV transformer ->
%        DFIG W33 -> ground. All three-phase physical, no Goto/From.
%
%   Output: build/generated_models/nebus39_dfig1_v0.slx

p = inputParser;
p.addParameter('Force', false, @islogical);
p.parse(varargin{:});
force = p.Results.Force;

projectRoot = 'C:\Users\jonas\Desktop\simulink_agent_v1';
modelName   = 'nebus39_dfig1_v0';
outDir      = fullfile(projectRoot,'build','generated_models');
outPath     = fullfile(outDir, [modelName '.slx']);

if ~isfolder(outDir); mkdir(outDir); end
if exist(outPath,'file') && ~force
    error('BuildNebus39Dfig1:Exists', ...
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

% --- Create new model ---
new_system(modelName);
load_system(modelName);

% --- Copy W33 from baseline ---
add_block([baselineName '/W33'], [modelName '/DFIG_W33'], ...
    'Position', [600 200 760 360]);

% --- Add NEBUS top scaffolding ---
add_block('powerlib/powergui', [modelName '/powergui'], ...
    'Position', [60 60 130 100]);
set_param([modelName '/powergui'], 'SimulationMode', 'Discrete', ...
    'SampleTime', '5e-5');

% Programmable voltage source (3-phase) - 13.8 kV LL RMS
add_block('powerlib/Electrical Sources/Three-Phase Programmable Voltage Source', ...
    [modelName '/Vsrc_13kV'], 'Position', [60 200 140 280]);
% Configure for fault injection at t=0.5s (drop amplitude to 0.5 pu, recover at 0.7s)
set_param([modelName '/Vsrc_13kV'], ...
    'PositiveSequence','[13.8e3 0 50]', ...        % [Vrms_LL phase_deg freq_Hz]
    'VariationEntity','Amplitude', ...
    'VariationType','Step', ...
    'VariationStep','-0.5', ...                    % step magnitude in pu
    'VariationTiming','[0.5 0.7]');                 % [start end] seconds

% RLC tie line
add_block('powerlib/Elements/Three-Phase Series RLC Branch', ...
    [modelName '/Tie_RLC'], 'Position', [220 210 290 270]);
set_param([modelName '/Tie_RLC'], 'BranchType','RL', ...
    'Resistance','0.001*(13.8e3^2/100e6)', ...
    'Inductance','0.05*(13.8e3^2/100e6)/(2*pi*50)');

% Step-up transformer 13.8/0.575 kV, 10 MVA
add_block('powerlib/Elements/Three-Phase Transformer (Two Windings)', ...
    [modelName '/T1'], 'Position', [380 200 460 280]);
set_param([modelName '/T1'], 'NominalPower','[10e6 50]', ...
    'Winding1Connection','Yg', 'Winding1','[13.8e3 0.001 0.05]', ...
    'Winding2Connection','Yg', 'Winding2','[575    0.001 0.05]', ...
    'Rm','500', 'Lm','500');

% Ground for DFIG return path
add_block('powerlib/Elements/Ground', [modelName '/Gnd'], ...
    'Position', [800 380 830 410]);

% --- Wind speed input (constant 14 m/s) ---
add_block('simulink/Sources/Constant', [modelName '/Wind_14'], ...
    'Position', [500 215 540 245], 'Value','14');
% Qref input (constant 0)
add_block('simulink/Sources/Constant', [modelName '/Qref_0'], ...
    'Position', [500 275 540 305], 'Value','0');

% --- Wire physical (RConn-LConn) chain: Vsrc -> Tie -> T1.W1 -> [T1.W2 -> DFIG] ---
add_line(modelName, 'Vsrc_13kV/RConn1', 'Tie_RLC/LConn1', 'autorouting','on');
add_line(modelName, 'Vsrc_13kV/RConn2', 'Tie_RLC/LConn2', 'autorouting','on');
add_line(modelName, 'Vsrc_13kV/RConn3', 'Tie_RLC/LConn3', 'autorouting','on');
add_line(modelName, 'Tie_RLC/RConn1',   'T1/LConn1',     'autorouting','on');
add_line(modelName, 'Tie_RLC/RConn2',   'T1/LConn2',     'autorouting','on');
add_line(modelName, 'Tie_RLC/RConn3',   'T1/LConn3',     'autorouting','on');
add_line(modelName, 'T1/RConn1', 'DFIG_W33/LConn1','autorouting','on');
add_line(modelName, 'T1/RConn2', 'DFIG_W33/LConn2','autorouting','on');
add_line(modelName, 'T1/RConn3', 'DFIG_W33/LConn3','autorouting','on');

% Wire signal inputs
% (DFIG W33 has 2 input ports: Wind, Qref)
add_line(modelName, 'Wind_14/1', 'DFIG_W33/1', 'autorouting','on');
add_line(modelName, 'Qref_0/1',  'DFIG_W33/2', 'autorouting','on');

% --- Solver / model config ---
set_param(modelName, 'StopTime','5.0', ...
    'SolverType','Fixed-step', 'Solver','FixedStepDiscrete', ...
    'FixedStep','5e-5', 'StartTime','0');

% --- Self-contained InitFcn: define Ts so DFIG_W33 sub-blocks resolve ---
% Without this, base workspace must contain Ts. We set Ts here and also
% any other commonly-used aliases the DFIG donor expects.
set_param(modelName, 'InitFcn', sprintf([ ...
    '%% Auto-generated by build_nebus39_dfig1_v0\n' ...
    'Ts = 5e-5;            %% sample time used by DFIG_W33 control blocks\n' ...
    'Tsample = Ts;         %% common alias\n']));

% --- Add traceability metadata ---
set_param(modelName, 'Description', sprintf([ ...
    'Derived from M07 SGbyhjq.slx top-level scaffolding + W33 DFIG ' ...
    'subsystem from ieee39_10m39bus_sg5_dfig5_nebus_layout.slx.\n' ...
    'Spec: specs/case_nebus39_dfig1_v0.yaml\n' ...
    'Built: %s'], datetime('now','Format','yyyy-MM-dd HH:mm:ss')));

% --- No-overlap layout self-check (FS-005 prevention) ---
% Recursive across all subsystems we author; skip the W33 donor and any
% library-linked block (those are upstream we can't fix without breaking link).
scan_block_overlap(modelName, 'ThrowOnFail', true, ...
    'Recursive', true, 'SkipPattern', {'DFIG_W33'});

% Save
save_system(modelName, outPath);
fprintf('Saved: %s\n', outPath);
end
