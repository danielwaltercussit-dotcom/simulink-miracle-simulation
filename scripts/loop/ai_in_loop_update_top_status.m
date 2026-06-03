function ai_in_loop_update_top_status(loopRoot, iterDir, state)
%AI_IN_LOOP_UPDATE_TOP_STATUS  Always-latest pointer at build/reports/loop/status.json.
top = struct();
top.latest_iteration_dir = char(iterDir);
top.latest_iteration     = state.iteration;
top.passed               = state.passed;
top.failure_sig          = state.failure_sig;
top.proposed_fix         = state.proposed_fix;
top.evidence             = state.evidence;
top.updated_at           = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
fid = fopen(fullfile(loopRoot,'status.json'),'w');
fprintf(fid,'%s', jsonencode(top));
fclose(fid);
end
