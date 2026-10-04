%% STEP 2b - The SAME cell, built with Simscape Battery
% Builds a tiny model: Battery (Table-Based) + pulse load + voltage sensor.
% Then runs it and overlays it on your step 1 script, so you can see that the
% ready-made battery block is the same equations you wrote by hand.
%
% Run this file. It creates step2b_simscape.slx, simulates, and plots.

step1_single_cell;  close all;      % gives t, SOC, V from your own script
step2_params;                       % gives Q_Ah, R0, R1, C1, soc_table, ocv_table ...

m = 'step2b_simscape';
if bdIsLoaded(m), close_system(m, 0); end
if exist([m '.slx'], 'file'), delete([m '.slx']); end
new_system(m); open_system(m);
load_system('batt_lib'); load_system('ee_lib'); load_system('nesl_utility');

%% Blocks
cell_ = add_block(['batt_lib/Cells/Battery' newline '(Table-Based)'], [m '/Cell'], ...
    'Position', [300 100 380 200]);

% ---- Parameters: the SAME numbers as step 1 ------------------------------
set_param(cell_, ...
    'T_dependence', 'simscape.enum.tablebattery.temperature_dependence.no', ... % no temperature tables
    'SOC_vec',  'soc_table', ...                 % breakpoints
    'V0_vec',   'ocv_table', ...                 % OCV at each SOC  (same as step 1)
    'R0_vec',   'R0*ones(size(soc_table))', ...  % series resistance (same at every SOC)
    'AH',       'Q_Ah', ...                      % capacity
    'prm_dyn',  'simscape.enum.tablebattery.prm_dyn.rc1', ...  % turn ON one RC pair
    'R1_vec',   'R1*ones(size(soc_table))', ...
    'tau1_vec', 'R1*C1*ones(size(soc_table))', ...   % tau = R1*C1 = 40 s
    'SOC_port', 'simscape.enum.tablebattery.enable.yes', ...  % expose SOC as an output
    'stateOfCharge', 'SOC0');                        % starting SOC

load_ = add_block('ee_lib/Sources/Pulse Current Source', [m '/Load'], ...
    'Position', [450 100 510 200], ...
    'I1', '0', 'I2', 'I_pulse', 'TD', '0', ...
    'PW', '300', 'PER', 'T_cycle');                  % 4 A for 300 s, every 600 s

vs   = add_block(['ee_lib/Sensors &' newline 'Transducers/Voltage Sensor'], [m '/Vsense'], ...
    'Position', [300 260 360 320], 'Orientation', 'right');
ref  = add_block(['ee_lib/Connectors &' newline 'References/Electrical Reference'], [m '/Ref'], ...
    'Position', [380 380 420 420]);
solv = add_block(['nesl_utility/Solver' newline 'Configuration'], [m '/Solver'], ...
    'Position', [120 380 180 420]);

p2sV   = add_block(['nesl_utility/PS-Simulink' newline 'Converter'], [m '/V_PS2S'],   'Position', [420 270 460 300]);
p2sSOC = add_block(['nesl_utility/PS-Simulink' newline 'Converter'], [m '/SOC_PS2S'], 'Position', [460 20 500 50]);

toV   = add_block('simulink/Sinks/To Workspace', [m '/V_ss'],   'VariableName', 'V_ss',   'SaveFormat', 'Timeseries', 'Position', [500 270 570 300]);
toSOC = add_block('simulink/Sinks/To Workspace', [m '/SOC_ss'], 'VariableName', 'SOC_ss', 'SaveFormat', 'Timeseries', 'Position', [540 20 610 50]);
sc    = add_block('simulink/Sinks/Scope', [m '/Voltage scope'], 'Position', [500 320 540 350]);

%% Wires  (physical connections use port handles)
ph = @(b) get_param(b, 'PortHandles');
c = ph(cell_); l = ph(load_); v = ph(vs); r = ph(ref); s = ph(solv);
pv = ph(p2sV); ps = ph(p2sSOC);

% Cell has 2 electrical ports + 1 SOC output when SOC_port = yes
cp = get_param(cell_, 'PortHandles');
Cplus  = cp.LConn(1);   % battery +
Cminus = cp.RConn(1);   % battery -
Csoc   = cp.LConn(2);   % SOC output (appears because SOC_port = yes)

% Load across the cell: current flows out of the cell's + terminal, through the load
add_line(m, Cplus,    l.LConn(1), 'autorouting', 'on');
add_line(m, Cminus,   l.RConn(1), 'autorouting', 'on');
% Voltage sensor across the cell
add_line(m, Cplus,    v.LConn(1), 'autorouting', 'on');   % sensor +
add_line(m, Cminus,   v.RConn(2), 'autorouting', 'on');   % sensor -
% Ground and solver
add_line(m, Cminus,   r.LConn(1), 'autorouting', 'on');
add_line(m, Cminus,   s.RConn(1), 'autorouting', 'on');
% Signals out
add_line(m, v.RConn(1), pv.LConn(1), 'autorouting', 'on');   % sensor signal output
add_line(m, pv.Outport(1), get_param(toV, 'PortHandles').Inport(1), 'autorouting', 'on');
add_line(m, pv.Outport(1), get_param(sc,  'PortHandles').Inport(1), 'autorouting', 'on');
add_line(m, Csoc, ps.LConn(1), 'autorouting', 'on');
add_line(m, ps.Outport(1), get_param(toSOC, 'PortHandles').Inport(1), 'autorouting', 'on');

set_param(m, 'StopTime', 't_end', 'MaxStep', '1');
save_system(m);

%% Run and compare with your step 1 script
out = sim(m);
Vs = out.V_ss;  Ss = out.SOC_ss;
socScale = 1; if max(Ss.Data) > 1.5, socScale = 0.01; end      % block may report % instead of fraction

figure('Name', 'Step 2b - Simscape Battery vs your script');
subplot(2,1,1);
plot(t/60, SOC*100, 'LineWidth', 2); hold on;
plot(Ss.Time/60, Ss.Data*socScale*100, '--', 'LineWidth', 1.5);
ylabel('SOC (%)'); legend('Step 1 script', 'Simscape Battery'); grid on;
subplot(2,1,2);
plot(t/60, V, 'LineWidth', 2); hold on;
plot(Vs.Time/60, Vs.Data, '--', 'LineWidth', 1.5);
ylabel('Voltage (V)'); xlabel('Time (minutes)');
legend('Step 1 script', 'Simscape Battery'); grid on;

[tu, ix] = unique(Vs.Time, 'last');
err = abs(interp1(tu, Vs.Data(ix), t) - V);
fprintf('Average voltage difference vs your script: %.4f V\n', mean(err));
fprintf('Final SOC (Simscape): %.1f %%\n', Ss.Data(end)*socScale*100);
