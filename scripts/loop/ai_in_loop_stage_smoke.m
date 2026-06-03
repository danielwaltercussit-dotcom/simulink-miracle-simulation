function s = ai_in_loop_stage_smoke(modelName, tStop)
%AI_IN_LOOP_STAGE_SMOKE  Short sim() smoke run.
s = struct('name','S5_SMOKE','status','PASS','model',char(modelName),'t_stop',tStop);
load_system(char(modelName));
sim(char(modelName),'StopTime',num2str(tStop));
s.note = sprintf('sim to %.4g s PASS', tStop);
end
