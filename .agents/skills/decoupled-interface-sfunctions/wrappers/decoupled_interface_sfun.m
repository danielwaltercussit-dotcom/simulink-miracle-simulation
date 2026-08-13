function decoupled_interface_sfun(block)
%DECOUPLED_INTERFACE_SFUN  Level-2 MATLAB S-Function scaffold for decoupled interface.
%
%   THIS IS A TOY SCAFFOLD ONLY.
%     - NOT a C/MEX S-Function (no compilation required, no mex files).
%     - NOT validated against a real EMT/averaged boundary.
%     - A demonstration of how a decoupled-interface wrapper block looks.
%     - Self-contained: the math is INLINED here so the block is callable in
%       normal / accelerator / rapid-accel modes without an external function
%       dependency. The unit-tested pure-MATLAB equivalent is
%       decoupled_interface_step.
%
%   Port map (toy):
%     Input  1: V_source   (double, source domain rate)
%     Input  2: feedback   (double, target domain rate, sample-aligned)
%     Input  3: z_eq_ohm   (double, equivalent impedance, must be > 0)
%     Output 1: i_boundary (double, (V_source - feedback) / z_eq_ohm)
%     Output 2: v_error    (double, V_source - feedback)
%     Output 3: status_ok  (double, 0/1 logical as double)

setup(block);
end


function setup(block)
% Register number of ports.
block.NumInputPorts  = 3;
block.NumOutputPorts = 3;

% Port properties: scalar doubles, direct feedthrough.
for k = 1:3
    block.InputPort(k).Dimensions  = 1;
    block.InputPort(k).DatatypeID  = 0;   % double
    block.InputPort(k).Complexity  = 'Real';
    block.InputPort(k).DirectFeedthrough = true;
end

for k = 1:3
    block.OutputPort(k).Dimensions = 1;
    block.OutputPort(k).DatatypeID = 0;
    block.OutputPort(k).Complexity = 'Real';
end

% Sample times: inherit.
block.SampleTimes = [-1 0];

% Setup runtime method. Numeric defaults (NumDialogPrms, NumDworks,
% NumContStates, NumDiscStates) are all 0 already; do NOT re-assign here
% because some MATLAB releases treat them as read-only at this stage.
block.RegBlockMethod('Outputs', @iOutputs);
end


function iOutputs(block)
% Inlined core math (no external function call). Mirrors
% decoupled_interface_step for the unit-tested values:
%   v_error    = V_source - feedback
%   i_boundary = v_error / z_eq_ohm   (only if all inputs finite and z_eq>0)
%   status_ok  = 1 iff valid, else 0
V_source = block.InputPort(1).Data;
feedback = block.InputPort(2).Data;
z_eq_ohm = block.InputPort(3).Data;

if isfinite(V_source) && isfinite(feedback) && isfinite(z_eq_ohm) && (z_eq_ohm > 0)
    v_error    = V_source - feedback;
    i_boundary = v_error / z_eq_ohm;
    status_ok  = 1;
else
    v_error    = 0;
    i_boundary = 0;
    status_ok  = 0;
end

block.OutputPort(1).Data = i_boundary;
block.OutputPort(2).Data = v_error;
block.OutputPort(3).Data = status_ok;
end
