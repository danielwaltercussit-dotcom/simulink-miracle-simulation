function summary = ingest_switching_waveform_evidence(source, varargin)
%INGEST_SWITCHING_WAVEFORM_EVIDENCE Provenance-aware switching evidence intake.
%
%   summary = ingest_switching_waveform_evidence(source, ...
%       "SignalName","Iabc_a", "CaseName","tinyVSC", ...metadata..., "OutputDir",dir)
%
%   Loads a switching waveform from one of several source kinds, attaches
%   explicit provenance, and routes the data through
%   summarize_switching_waveform_evidence. The model_backed flag is decided by
%   the summarizer's downgrade rule: it is true ONLY for a genuine
%   simulation/model source (a Simulink.SimulationOutput or a MAT-file that
%   records a real run) and is forced false for generated/synthetic data.
%
%   Accepted source kinds (auto-detected, or forced with "SourceType"):
%     - Simulink.SimulationOutput        -> source_type "simulation_output"
%     - struct with .time and .signals   -> source_type "simulation_output"
%                                           (a logged-signal / Dataset-like struct)
%     - char/string path to a .mat file  -> source_type "mat_file"
%     - struct with .t and .x (or .time, -> source_type "generated" unless the
%       .waveform) generated artifact        struct sets .source_type/.synthetic
%
%   For a MAT-file or generated artifact, the struct/file may carry a nested
%   `provenance` struct (source_type, source_id, model_name, simulated,
%   synthetic, captured_at, source_path); it is honoured and normalized.
%
%   This helper never runs a Simulink model itself. It ingests the OUTPUT of a
%   run (or a generated trace) and records where the data came from. A
%   synthetic or weakly-sourced trace can validate the contract but cannot reach
%   model_backed=true.
%
%   See .agents/skills/emt-switching-level-converter/references/switching-evidence-contract.md

opts = iParseIngestOpts(varargin{:});
[t, x, prov] = iLoadSource(source, opts);

fwd = iForwardArgs(opts, prov);
summary = summarize_switching_waveform_evidence(t, x, fwd{:});
end


function opts = iParseIngestOpts(varargin)
p = inputParser;
p.KeepUnmatched = true;            % pass-through metadata to the summarizer
p.PartialMatching = false;         % so "Signal" (summarizer) != "SignalName" (here)
p.addParameter("SourceType", "", @(x) ischar(x) || isstring(x));
p.addParameter("SignalName", "", @(x) ischar(x) || isstring(x));
p.addParameter("TimeField", "", @(x) ischar(x) || isstring(x));
p.addParameter("DataField", "", @(x) ischar(x) || isstring(x));
p.addParameter("MatVariable", "", @(x) ischar(x) || isstring(x));
p.addParameter("Provenance", struct(), @(x) isstruct(x));
p.parse(varargin{:});
opts = p.Results;
opts.Unmatched = p.Unmatched;
opts.SourceType = lower(string(opts.SourceType));
opts.SignalName = string(opts.SignalName);
opts.TimeField = string(opts.TimeField);
opts.DataField = string(opts.DataField);
opts.MatVariable = string(opts.MatVariable);
end


function [t, x, prov] = iLoadSource(source, opts)
prov = opts.Provenance;
% A struct artifact may carry its own provenance (e.g. the output of
% build_tiny_switching_example). Honour it, but let an explicit caller-supplied
% Provenance option win on any conflicting field.
if isstruct(source) && isfield(source, "provenance") && isstruct(source.provenance)
    prov = iMergeProv(source.provenance, prov);
end
kind = opts.SourceType;
if kind == ""
    kind = iDetectKind(source, prov);
end
switch kind
    case "simulation_output"
        [t, x] = iFromSimOutput(source, opts);
        prov = iDefaultProv(prov, "simulation_output", false);
    case "mat_file"
        [t, x, prov] = iFromMatFile(source, opts, prov);
    case {"generated", "synthetic", "captured"}
        [t, x] = iFromGenerated(source, opts);
        prov = iDefaultProv(prov, char(kind), kind ~= "captured");
    otherwise
        error("SwitchingIngest:UnknownSource", ...
            "Cannot ingest source of kind '%s'.", kind);
end
t = double(t(:));
x = double(x(:));
end


function kind = iDetectKind(source, prov) %#ok<INUSD>
% Structural detection. Embedded provenance (already merged by the caller) sets
% the declared origin and the model_backed claim; it does not change HOW the
% waveform is read, so a plain (t,x) struct that declares a model origin is
% still read by the generated extractor while keeping its declared source_type.
if isa(source, "Simulink.SimulationOutput")
    kind = "simulation_output";
elseif (ischar(source) || isstring(source)) && endsWith(lower(string(source)), ".mat")
    kind = "mat_file";
elseif iStructIsSimShape(source)
    kind = "simulation_output";       % logged-signal struct shape
elseif isstruct(source)
    kind = "generated";
else
    kind = "unknown";
end
end


function tf = iStructIsSimShape(source)
tf = isstruct(source) && isfield(source, "signals") && isfield(source, "time");
end


function p = iDefaultProv(p, sourceType, isSynthetic)
% Fill source_type/synthetic only when the caller did not already set them.
if ~isfield(p, "source_type") || strlength(string(p.source_type)) == 0
    p.source_type = sourceType;
end
if ~isfield(p, "synthetic")
    p.synthetic = isSynthetic;
end
end


function [t, x] = iFromSimOutput(source, opts)
% Extract a time vector and one signal from a Simulink.SimulationOutput or a
% logged-signal struct. Base-MATLAB only; no Simulink call is made here.
sig = char(opts.SignalName);
if isa(source, "Simulink.SimulationOutput")
    if isempty(sig)
        error("SwitchingIngest:NoSignalName", ...
            "SignalName is required to pick a signal from a SimulationOutput.");
    end
    data = source.(sig);            % e.g. a logged timeseries
    [t, x] = iFromTimeseriesLike(data);
    return
end
% logged-signal struct: source.time + source.signals(k).values
t = source.time;
sigs = source.signals;
if isempty(sig)
    x = sigs(1).values;
else
    x = iPickNamedSignal(sigs, sig);
end
x = iFirstColumn(x);
end


function x = iPickNamedSignal(sigs, name)
for k = 1:numel(sigs)
    if isfield(sigs(k), "label") && strcmp(char(sigs(k).label), name)
        x = sigs(k).values;
        return
    end
    if isfield(sigs(k), "name") && strcmp(char(sigs(k).name), name)
        x = sigs(k).values;
        return
    end
end
error("SwitchingIngest:SignalNotFound", "Signal '%s' not found in struct.", name);
end


function [t, x] = iFromTimeseriesLike(data)
if isa(data, "timeseries")
    t = data.Time;
    x = iFirstColumn(data.Data);
elseif isstruct(data) && isfield(data, "Time") && isfield(data, "Data")
    t = data.Time;
    x = iFirstColumn(data.Data);
else
    error("SwitchingIngest:BadSimSignal", ...
        "Signal must be a timeseries or have .Time/.Data.");
end
end


function [t, x, prov] = iFromMatFile(source, opts, prov)
% Load a waveform and (optionally) a provenance struct from a .mat file. The
% file is treated as a real-run artifact by default, but the embedded
% provenance/synthetic flag is honoured if present.
path = char(source);
if ~isfile(path)
    error("SwitchingIngest:MatNotFound", "MAT-file not found: %s", path);
end
S = load(path);
if isfield(S, "provenance") && isstruct(S.provenance)
    prov = iMergeProv(prov, S.provenance);
end
prov = iDefaultProv(prov, "mat_file", false);
if strlength(string(iGetField(prov, "source_path"))) == 0
    prov.source_path = path;
end
var = char(opts.MatVariable);
if ~isempty(var)
    payload = S.(var);
else
    payload = iSolePayload(S);
end
[t, x] = iFromGenerated(payload, opts);
end


function [t, x] = iFromGenerated(source, opts)
% A generated/captured artifact: a struct carrying time + waveform under
% configurable field names (defaults cover t/x, time/waveform, time/data).
tf = char(opts.TimeField);
df = char(opts.DataField);
if ~isstruct(source)
    error("SwitchingIngest:BadGenerated", ...
        "Generated source must be a struct with time and waveform fields.");
end
if isempty(tf); tf = iFirstPresent(source, {'t','time','Time'}); end
if isempty(df); df = iFirstPresent(source, {'x','waveform','data','Data','values'}); end
if isempty(tf) || isempty(df)
    error("SwitchingIngest:MissingFields", ...
        "Could not find time/waveform fields; pass TimeField/DataField.");
end
t = source.(tf);
x = iFirstColumn(source.(df));
end


function name = iFirstPresent(s, candidates)
name = '';
for k = 1:numel(candidates)
    if isfield(s, candidates{k})
        name = candidates{k};
        return
    end
end
end


function payload = iSolePayload(S)
fn = fieldnames(S);
fn = fn(~strcmp(fn, "provenance"));
if numel(fn) ~= 1
    error("SwitchingIngest:AmbiguousMat", ...
        "MAT-file has %d candidate variables; pass MatVariable.", numel(fn));
end
payload = S.(fn{1});
end


function p = iMergeProv(p, extra)
fn = fieldnames(extra);
for k = 1:numel(fn)
    p.(fn{k}) = extra.(fn{k});
end
end


function v = iGetField(s, name)
if isfield(s, name); v = s.(name); else; v = ""; end
end


function x = iFirstColumn(x)
if ~isvector(x)
    x = x(:, 1);
end
x = x(:);
end


function fwd = iForwardArgs(opts, prov)
% Build the name/value list for the summarizer: pass-through metadata plus the
% normalized provenance. The summarizer owns the model_backed downgrade rule.
u = opts.Unmatched;
fn = fieldnames(u);
passthrough = cell(1, 2*numel(fn));
for k = 1:numel(fn)
    passthrough{2*k-1} = fn{k};
    passthrough{2*k} = u.(fn{k});
end
% A declared model/simulation source ASSERTS model_backed; the summarizer is
% the single authority that validates the assertion and downgrades it when the
% provenance does not support it (synthetic flag set, or no source identifier).
% Asserting even for a synthetic-flagged model source makes the downgrade
% explicit (with a reason) rather than silently never-asserted.
asserted = ismember(string(iGetField(prov, "source_type")), ["simulation_output","mat_file"]);
fwd = [passthrough, {"Provenance", prov, "ModelBacked", asserted}];
end
