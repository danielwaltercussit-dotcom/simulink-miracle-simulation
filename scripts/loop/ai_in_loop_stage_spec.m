function s = ai_in_loop_stage_spec(specAbs)
%AI_IN_LOOP_STAGE_SPEC  Validate spec file contract used by the loop.
s = struct('name','S1_SPEC','status','PASS','spec', char(specAbs));
info = dir(specAbs);
if isempty(info) || info.bytes == 0
    error('AIInLoop:EmptySpec','Spec is empty: %s', specAbs);
end
s.bytes = info.bytes;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(projectRoot, 'scripts', 'verification'));
[~, specName] = fileparts(char(specAbs));
reportPath = fullfile(projectRoot, 'build', 'reports', 'spec_validation', [specName '.md']);
validation = validate_power_system_spec(specAbs, 'ReportPath', reportPath);
s.validation_report_path = reportPath;
s.validation_checks = validation.checks;
if ~validation.passed
    error('AIInLoop:SpecValidationFail', 'Spec validation failed: %s', validation.message);
end
end
