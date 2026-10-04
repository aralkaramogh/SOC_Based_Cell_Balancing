%% Builds a VERY SIMPLE Simulink cell model: step2_cell.slx
% Run once. It creates the model, saves it, and opens it.
% Afterwards, just open step2_cell.slx and press Run - no need to rebuild.
%
% What's inside (6 blocks of physics):
%   current I --> Gain(-1/Q) --> Integrator --> SOC --> Lookup --> OCV
%   V = OCV - I*R0
% The RC "slow sag" is deliberately LEFT OUT - adding it is your task.

mdl = 'step2_cell';
if bdIsLoaded(mdl), close_system(mdl, 0); end
if exist([mdl '.slx'], 'file'), delete([mdl '.slx']); end
new_system(mdl);
open_system(mdl);

% Parameters load automatically every time the model runs
set_param(mdl, 'InitFcn', 'step2_params;', ...
               'StopTime', 't_end', 'MaxStep', '1');
step2_params;

% ---- Blocks -------------------------------------------------------------
add_block('simulink/Sources/Pulse Generator', [mdl '/Load current I'], ...
    'Amplitude', 'I_pulse', 'Period', 'T_cycle', 'PulseWidth', '50', ...
    'Position', [30 100 80 140]);

add_block('simulink/Math Operations/Gain', [mdl '/SOC gain'], ...
    'Gain', '-1/Q', 'Position', [150 100 200 140]);

add_block('simulink/Continuous/Integrator', [mdl '/Integrator'], ...
    'InitialCondition', 'SOC0', 'Position', [250 100 290 140]);

add_block('simulink/Lookup Tables/1-D Lookup Table', [mdl '/OCV(SOC)'], ...
    'Table', 'ocv_table', 'BreakpointsForDimension1', 'soc_table', ...
    'Position', [360 100 420 140]);

add_block('simulink/Math Operations/Gain', [mdl '/R0'], ...
    'Gain', 'R0', 'Position', [360 200 410 240]);

add_block('simulink/Math Operations/Sum', [mdl '/Sum'], ...
    'Inputs', '+-', 'Position', [490 120 520 190]);

add_block('simulink/Sinks/Scope', [mdl '/Voltage scope'], ...
    'Position', [600 140 640 170]);

add_block('simulink/Sinks/To Workspace', [mdl '/V_sim'], ...
    'VariableName', 'V_sim', 'SaveFormat', 'Timeseries', ...
    'Position', [600 210 680 240]);

add_block('simulink/Sinks/To Workspace', [mdl '/SOC_sim'], ...
    'VariableName', 'SOC_sim', 'SaveFormat', 'Timeseries', ...
    'Position', [360 30 440 60]);

% ---- Wires --------------------------------------------------------------
add_line(mdl, 'Load current I/1', 'SOC gain/1',      'autorouting', 'on');
add_line(mdl, 'SOC gain/1',          'Integrator/1', 'autorouting', 'on');
add_line(mdl, 'Integrator/1',     'OCV(SOC)/1',   'autorouting', 'on');
add_line(mdl, 'Integrator/1',     'SOC_sim/1',    'autorouting', 'on');
add_line(mdl, 'Load current I/1', 'R0/1',         'autorouting', 'on');
add_line(mdl, 'OCV(SOC)/1',       'Sum/1',        'autorouting', 'on');
add_line(mdl, 'R0/1',             'Sum/2',        'autorouting', 'on');
add_line(mdl, 'Sum/1',            'Voltage scope/1', 'autorouting', 'on');
add_line(mdl, 'Sum/1',            'V_sim/1',      'autorouting', 'on');

save_system(mdl);
disp('step2_cell.slx created. Press Run in the model, then double-click the Scope.');
