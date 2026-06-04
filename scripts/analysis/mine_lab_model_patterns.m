function result = mine_lab_model_patterns(varargin)
%MINE_LAB_MODEL_PATTERNS  Extract machine-readable facts from the read-only lab
% reference archive and compare them against the project pattern docs.
%
%   result = mine_lab_model_patterns('ArchiveDir', D, 'OutputDir', O, ...
%                                    'Subset', {'M03'}, 'ScanBlocks', true)
%
% This is a DRIFT DETECTOR, not a knowledge generator. The archive README and
% the project's MODELING_PATTERN_LIBRARY.md / pattern-rows.md are human-curated
% and authoritative. This helper only extracts facts a machine can reliably
% read — file inventory, .slx block/subsystem counts, .m assigned variable
% names — and reports where those facts disagree with the pattern docs, so an
% agent does not have to re-verify M01-M08 by hand.
%
% HARD RULE: the archive is read-only. This function never writes inside
% ArchiveDir; all output goes under OutputDir (default ignored build/reports).
%
% Returns a struct with .patterns (per-folder facts) and .drift (findings),
% and writes lab_patterns_index.{json,md} + lab_patterns_drift.md to OutputDir.

opt = iParse(varargin{:});
archive = char(opt.ArchiveDir);
assert(isfolder(archive), 'Archive not found: %s', archive);

% Discover M0x pattern folders.
d = dir(archive);
folders = {};
for k = 1:numel(d)
    if d(k).isdir && ~ismember(d(k).name, {'.','..'}) && ~isempty(regexp(d(k).name,'^M\d','once'))
        folders{end+1} = d(k).name; %#ok<AGROW>
    end
end
if ~isempty(opt.Subset)
    keep = false(1,numel(folders));
    for k = 1:numel(folders)
        keep(k) = any(contains(folders{k}, opt.Subset));
    end
    folders = folders(keep);
end

patterns = repmat(iEmptyPattern(), 1, numel(folders));
for k = 1:numel(folders)
    patterns(k) = iScanFolder(archive, folders{k}, opt);
end

result = struct();
result.archive = archive;
result.generated_at = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
result.patterns = patterns;

% Drift comparison against project pattern docs.
result.drift = iComputeDrift(patterns, opt);

% Write artifacts (never into the archive).
outDir = char(opt.OutputDir);
if ~isfolder(outDir); mkdir(outDir); end
iWriteJson(fullfile(outDir,'lab_patterns_index.json'), result);
iWriteIndexMd(fullfile(outDir,'lab_patterns_index.md'), result);
iWriteDriftMd(fullfile(outDir,'lab_patterns_drift.md'), result);
result.output_dir = outDir;
end


% ---------------------------------------------------------------
function opt = iParse(varargin)
p = inputParser;
p.addParameter('ArchiveDir', fullfile(getenv('USERPROFILE'),'Desktop','实验室仿真模型汇总'), @(x)ischar(x)||isstring(x));
p.addParameter('OutputDir', fullfile('build','reports','lab_patterns'), @(x)ischar(x)||isstring(x));
p.addParameter('Subset', {}, @(x)iscell(x)||isstring(x));
p.addParameter('ScanBlocks', true, @(x)islogical(x)||isnumeric(x));
p.addParameter('PatternLibPath', fullfile('docs','MODELING_PATTERN_LIBRARY.md'), @(x)ischar(x)||isstring(x));
p.parse(varargin{:});
opt = p.Results;
if isstring(opt.Subset); opt.Subset = cellstr(opt.Subset); end
opt.ScanBlocks = logical(opt.ScanBlocks);
end


function pat = iEmptyPattern()
pat = struct('id','','folder','','n_files',0,'files',struct([]), ...
    'slx_models',struct([]),'m_scripts',struct([]),'total_assigned_vars',0);
end


function pat = iScanFolder(archive, folderName, opt)
pat = iEmptyPattern();
pat.folder = folderName;
tok = regexp(folderName,'^(M\d+(?:-\d+)?)','tokens','once');
if ~isempty(tok); pat.id = tok{1}; else; pat.id = folderName; end

folderPath = fullfile(archive, folderName);
listing = dir(fullfile(folderPath,'**','*'));
files = struct('name',{},'rel',{},'bytes',{},'ext',{},'mtime',{});
slxList = {};
mList = {};
for k = 1:numel(listing)
    if listing(k).isdir; continue; end
    rel = erase(fullfile(listing(k).folder, listing(k).name), [archive filesep]);
    [~,~,ext] = fileparts(listing(k).name);
    files(end+1) = struct('name',listing(k).name,'rel',rel, ...
        'bytes',listing(k).bytes,'ext',lower(ext), ...
        'mtime',datestr(listing(k).datenum,'yyyy-mm-dd')); %#ok<AGROW>
    if strcmpi(ext,'.slx'); slxList{end+1} = fullfile(listing(k).folder,listing(k).name); end %#ok<AGROW>
    if strcmpi(ext,'.m');   mList{end+1}   = fullfile(listing(k).folder,listing(k).name); end %#ok<AGROW>
end
pat.files = files;
pat.n_files = numel(files);

% Scan .m parameter variable names (regex on assignment LHS).
mScripts = struct('name',{},'n_vars',{},'vars',{});
totalVars = 0;
for k = 1:numel(mList)
    [~,nm,ex] = fileparts(mList{k});
    vars = iScanAssignedVars(mList{k});
    mScripts(end+1) = struct('name',[nm ex],'n_vars',numel(vars),'vars',{vars}); %#ok<AGROW>
    totalVars = totalVars + numel(vars);
end
pat.m_scripts = mScripts;
pat.total_assigned_vars = totalVars;

% Scan .slx block/subsystem counts (load only, never simulate).
slxModels = struct('name',{},'n_blocks',{},'n_root_subsystems',{},'scanned',{});
for k = 1:numel(slxList)
    [~,nm,ex] = fileparts(slxList{k});
    entry = struct('name',[nm ex],'n_blocks',NaN,'n_root_subsystems',NaN,'scanned',false);
    if opt.ScanBlocks
        entry = iScanSlx(slxList{k}, entry);
    end
    slxModels(end+1) = entry; %#ok<AGROW>
end
pat.slx_models = slxModels;
end


function vars = iScanAssignedVars(mfile)
vars = {};
try
    txt = fileread(mfile);
catch
    return
end
toks = regexp(txt,'^\s*([A-Za-z]\w*)\s*=','tokens','lineanchors');
if isempty(toks); return; end
names = cellfun(@(c)c{1}, toks, 'uni', 0);
vars = unique(names);
end


function entry = iScanSlx(slxPath, entry)
[~,nm] = fileparts(slxPath);
wasLoaded = bdIsLoaded(nm);
try
    if ~wasLoaded; load_system(slxPath); end
    entry.n_blocks = numel(find_system(nm,'LookUnderMasks','all','FollowLinks','on','Type','Block'));
    entry.n_root_subsystems = numel(find_system(nm,'SearchDepth',1,'BlockType','SubSystem'));
    entry.scanned = true;
catch
    entry.scanned = false;
end
if ~wasLoaded && bdIsLoaded(nm)
    close_system(nm, 0);   % leave the session as we found it
end
end


% ---------------------------------------------------------------
function drift = iComputeDrift(patterns, opt)
% Compare machine facts against the human pattern library. Report-only:
% never edits the curated docs. Two finding kinds:
%   undocumented_file  - a non-trivial archive file no pattern doc mentions
%   missing_reference  - a filename the pattern doc cites that is not on disk
drift = struct('findings',struct('kind',{},'pattern',{},'detail',{}), ...
    'pattern_lib_found',false,'n_findings',0);
libPath = char(opt.PatternLibPath);
if ~isfile(libPath)
    drift.findings(end+1) = struct('kind','no_pattern_lib','pattern','', ...
        'detail',sprintf('pattern library not found at %s; cannot compute drift', libPath));
    drift.n_findings = 1;
    return
end
drift.pattern_lib_found = true;
libTxt = fileread(libPath);

% Only flag substantive source files (.slx/.m), skip caches/binaries.
for p = 1:numel(patterns)
    pat = patterns(p);
    for f = 1:numel(pat.files)
        fl = pat.files(f);
        if ~ismember(fl.ext, {'.slx','.m'}); continue; end
        if contains(libTxt, fl.name); continue; end
        drift.findings(end+1) = struct('kind','undocumented_file', ...
            'pattern',pat.id, ...
            'detail',sprintf('%s present in archive but not referenced in pattern library', fl.rel)); %#ok<AGROW>
    end
end

% Missing references: filenames the lib cites for these ids that are absent.
% Only meaningful on a FULL scan — on a subset we have only some folders, so
% files from unscanned patterns would false-positive as "missing". Skip it.
if isempty(opt.Subset)
    allNames = {};
    for p = 1:numel(patterns)
        for f = 1:numel(patterns(p).files); allNames{end+1} = patterns(p).files(f).name; end %#ok<AGROW>
    end
    cited = regexp(libTxt, '`([^`]+\.(?:slx|m))`', 'tokens');
    seen = {};
    for c = 1:numel(cited)
        nm = cited{c}{1};
        [~,base,ext] = fileparts(nm); nm = [base ext];
        if ismember(nm, seen); continue; end
        seen{end+1} = nm; %#ok<AGROW>
        if ~any(strcmp(allNames, nm))
            drift.findings(end+1) = struct('kind','missing_reference','pattern','', ...
                'detail',sprintf('pattern library cites `%s` but it is not in the scanned archive', nm)); %#ok<AGROW>
        end
    end
end
drift.n_findings = numel(drift.findings);
end


% ---------------------------------------------------------------
function iWriteJson(path, result)
fid = fopen(path,'w');
if fid < 0; warning('LabMiner:json','cannot write %s',path); return; end
oc = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n', jsonencode(result,'PrettyPrint',true));
end


function iWriteIndexMd(path, result)
fid = fopen(path,'w');
if fid < 0; return; end
oc = onCleanup(@() fclose(fid));
fprintf(fid,'# Lab Model Pattern Index (machine-extracted facts)\n\n');
fprintf(fid,'Archive (read-only): `%s`\n', result.archive);
fprintf(fid,'Generated: %s\n\n', result.generated_at);
fprintf(fid,'| Pattern | Files | .slx (blocks/root-subs) | .m vars |\n');
fprintf(fid,'|---|---:|---|---:|\n');
for p = 1:numel(result.patterns)
    pat = result.patterns(p);
    slxStr = '';
    for k = 1:numel(pat.slx_models)
        s = pat.slx_models(k);
        if s.scanned
            slxStr = [slxStr sprintf('%s:%d/%d ', s.name, s.n_blocks, s.n_root_subsystems)]; %#ok<AGROW>
        else
            slxStr = [slxStr sprintf('%s:n/a ', s.name)]; %#ok<AGROW>
        end
    end
    fprintf(fid,'| %s | %d | %s | %d |\n', pat.id, pat.n_files, strtrim(slxStr), pat.total_assigned_vars);
end
end


function iWriteDriftMd(path, result)
fid = fopen(path,'w');
if fid < 0; return; end
oc = onCleanup(@() fclose(fid));
fprintf(fid,'# Lab Pattern Drift Report\n\n');
fprintf(fid,'Generated: %s\n', result.generated_at);
fprintf(fid,'Findings: %d (report-only; human review before editing MODELING_PATTERN_LIBRARY.md)\n\n', result.drift.n_findings);
if result.drift.n_findings == 0
    fprintf(fid,'_No drift: every scanned .slx/.m is referenced and every cited file exists._\n');
    return
end
fprintf(fid,'| Kind | Pattern | Detail |\n|---|---|---|\n');
for k = 1:numel(result.drift.findings)
    f = result.drift.findings(k);
    fprintf(fid,'| %s | %s | %s |\n', f.kind, f.pattern, f.detail);
end
end
