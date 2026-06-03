function n = ai_in_loop_count_overlap(blocks)
%AI_IN_LOOP_COUNT_OVERLAP  Axis-aligned bbox overlap among non-DFIG-aux blocks.
n = 0;
positions = zeros(numel(blocks),4);
keep = true(numel(blocks),1);
for k = 1:numel(blocks)
    blk = blocks{k};
    name = get_param(blk,'Name');
    if contains(lower(name), {'wind','dfig','speed','trip','meter'})
        keep(k) = false; continue;
    end
    pos = get_param(blk,'Position');
    if numel(pos) ~= 4; keep(k) = false; continue; end
    positions(k,:) = pos;
end
positions = positions(keep,:);
for i = 1:size(positions,1)-1
    for j = i+1:size(positions,1)
        if positions(i,1) < positions(j,3) && positions(i,3) > positions(j,1) && ...
           positions(i,2) < positions(j,4) && positions(i,4) > positions(j,2)
            n = n + 1;
        end
    end
end
end
