function report = scan_block_overlap(modelName, varargin)
%SCAN_BLOCK_OVERLAP  Detect overlapping blocks in a Simulink model.
%   report = scan_block_overlap(modelName) checks the root canvas only and
%   returns:
%     .nBlocks      number of blocks scanned
%     .nOverlaps    number of overlapping pairs found
%     .pairs        struct array {a, b, aPos, bPos, container}
%     .ok           true iff no overlaps
%
%   Options (Name-Value):
%     'ThrowOnFail'   default false. Errors with AIInLoop:LayoutOverlap.
%     'Margin'        default 0. Treats blocks within Margin px as overlapping.
%     'Recursive'     default false. When true, recursively scan all nested
%                     subsystems too (one report per container, aggregated).
%     'SkipLinkedBlocks' default true. Skip subsystems that are library links
%                     or under a donor link — those are upstream content we
%                     can't fix without breaking the link.
%     'SkipPattern'   cell array of substring patterns. Skip subsystems whose
%                     path contains any pattern (e.g. {'DFIG_W33'} to skip a
%                     copied donor subsystem).
%
%   Enforces the no-overlap layout rule documented in
%   .agents/skills/simulink-modeling-assistant/references/layout-cookbook.md.

p = inputParser;
p.addParameter('ThrowOnFail', false, @islogical);
p.addParameter('Margin', 0, @(x) isnumeric(x) && isscalar(x) && x>=0);
p.addParameter('Recursive', false, @islogical);
p.addParameter('SkipLinkedBlocks', true, @islogical);
p.addParameter('SkipPattern', {}, @iscell);
p.parse(varargin{:});
opt = p.Results;

assert(bdIsLoaded(modelName), 'Model "%s" must be loaded first', modelName);

% Collect containers to scan: root + (optionally) every subsystem.
containers = {char(modelName)};
if opt.Recursive
    nested = find_system(char(modelName),'LookUnderMasks','all','FollowLinks','on','BlockType','SubSystem');
    containers = [containers; nested];
end

pairs = struct('a',{},'b',{},'aPos',{},'bPos',{},'container',{});
nBlocks = 0;
for c = 1:numel(containers)
    container = containers{c};

    % Skip if linked block (library reference) and SkipLinkedBlocks
    if opt.SkipLinkedBlocks && ~strcmp(container, char(modelName))
        try
            ref = get_param(container,'ReferenceBlock');
            if ~isempty(ref); continue; end
        catch
        end
    end

    % Skip if matches SkipPattern
    if any(cellfun(@(s) contains(container, s), opt.SkipPattern))
        continue
    end

    blks = find_system(container,'SearchDepth',1,'Type','Block');
    blks = blks(~strcmp(blks, container));    % drop the container itself
    n = numel(blks);
    if n < 2; continue; end

    positions = cell(n,1);
    names     = cell(n,1);
    keep_idx  = false(n,1);
    for k = 1:n
        try
            pos = get_param(blks{k},'Position');
            if numel(pos) == 4 && ~isequal(pos,[0 0 0 0])
                positions{k} = pos;
                names{k}     = strrep(get_param(blks{k},'Name'),newline,' ');
                keep_idx(k)  = true;
            end
        catch
        end
    end
    positions = positions(keep_idx);
    names     = names(keep_idx);
    n = numel(positions);
    nBlocks = nBlocks + n;

    for i = 1:n
        a = positions{i};
        for j = i+1:n
            b = positions{j};
            if a(1)-opt.Margin < b(3) && a(3)+opt.Margin > b(1) && ...
               a(2)-opt.Margin < b(4) && a(4)+opt.Margin > b(2)
                pairs(end+1) = struct('a',names{i},'b',names{j}, ...
                    'aPos',a,'bPos',b, ...
                    'container',strrep(container, [char(modelName) '/'],'')); %#ok<AGROW>
            end
        end
    end
end

report = struct();
report.nBlocks   = nBlocks;
report.nOverlaps = numel(pairs);
report.pairs     = pairs;
report.ok        = isempty(pairs);

if ~report.ok
    fprintf('scan_block_overlap: %d overlap(s) in "%s":\n', ...
        report.nOverlaps, modelName);
    for k = 1:numel(pairs)
        fprintf('  [%s] %s [%d %d %d %d]  <->  %s [%d %d %d %d]\n', ...
            pairs(k).container, ...
            pairs(k).a, pairs(k).aPos, pairs(k).b, pairs(k).bPos);
    end
    if opt.ThrowOnFail
        ME = MException('AIInLoop:LayoutOverlap', ...
            '%d block(s) overlap in "%s". See report.pairs.', ...
            numel(pairs), modelName);
        throw(ME);
    end
end
end
