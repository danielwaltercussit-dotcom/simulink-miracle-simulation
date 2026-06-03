function s = ai_in_loop_stage_compile(modelName)
%AI_IN_LOOP_STAGE_COMPILE  Run SimulationCommand update for the model.
s = struct('name','S4_COMPILE','status','PASS','model',char(modelName));
load_system(char(modelName));
set_param(char(modelName),'SimulationCommand','update');
s.note = 'update PASS';
end
