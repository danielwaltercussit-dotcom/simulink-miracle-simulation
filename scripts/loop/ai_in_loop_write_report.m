function ai_in_loop_write_report(iterDir, state)
%AI_IN_LOOP_WRITE_REPORT  Persist iteration report.md and status.json.
if ~isfolder(iterDir); mkdir(iterDir); end

% status.json
sjPath = fullfile(iterDir,'status.json');
fid = fopen(sjPath,'w');
fprintf(fid, '%s', jsonencode(state));
fclose(fid);

% report.md
rmPath = fullfile(iterDir,'report.md');
fid = fopen(rmPath,'w');
fprintf(fid, '# AI-in-Loop Iteration %02d\n\n', state.iteration);
fprintf(fid, '- goal: `%s`\n', state.goal);
fprintf(fid, '- model: `%s`\n', state.model_name);
fprintf(fid, '- spec: `%s`\n', state.spec_path);
fprintf(fid, '- evidence: `%s`\n', state.evidence);
fprintf(fid, '- passed: `%s`\n', mat2str(state.passed));
fprintf(fid, '- started: %s\n\n', state.started_at);

if isfield(state,'stages') && ~isempty(fieldnames(state.stages))
    fprintf(fid, '## Stages\n\n');
    fns = fieldnames(state.stages);
    for k = 1:numel(fns)
        st = state.stages.(fns{k});
        fprintf(fid, '### %s\n\n', st.name);
        sn = fieldnames(st);
        for j = 1:numel(sn)
            v = st.(sn{j});
            if ischar(v) || isstring(v)
                fprintf(fid, '- %s: `%s`\n', sn{j}, char(v));
            elseif isnumeric(v) && isscalar(v)
                fprintf(fid, '- %s: %g\n', sn{j}, v);
            else
                fprintf(fid, '- %s: (omitted)\n', sn{j});
            end
        end
        fprintf(fid, '\n');
    end
end

if ~state.passed
    fprintf(fid, '## Failure\n\n');
    fprintf(fid, '- signature: `%s`\n', state.failure_sig);
    fprintf(fid, '- proposed_fix: %s\n', state.proposed_fix);
    if isfield(state,'error_msg')
        fprintf(fid, '- error_id: `%s`\n', state.error_id);
        fprintf(fid, '- error_msg: %s\n', state.error_msg);
    end
end
fclose(fid);
end
