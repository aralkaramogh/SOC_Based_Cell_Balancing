function add_supervisor(mdl)
%ADD_SUPERVISOR  Replace the fixed charger logic in the BMS with a mode supervisor.
%   add_supervisor('pack3s_passive_balancing')
%
%   Before: charger always on (with 4.20 V cut-off), balancing always enabled.
%   After : a MATLAB Function block "Supervisor" runs a timed cycle
%             1 CHARGE     (+I_chg, cut-off 4.20 V / resume 4.15 V)  balancing ON
%             2 REST       (0 A)                                      balancing ON
%             3 DISCHARGE  (-I_dis, stops early if any cell < V_min) balancing OFF
%             4 REST       (0 A)                                      balancing ON
%           and back to 1. Durations and currents are in params_pack3s.m.
%   Safe to run twice (it does nothing if the Supervisor is already there).

s = [mdl '/BMS'];
if getSimulinkBlockHandle([s '/Supervisor']) > 0
    disp('Supervisor already present - nothing to do.'); return
end

% ---- 1. remove the old fixed charger logic --------------------------------
old = {'Cut-off relay','Delay1','Gate','I_chg','Highest cell V','Enable (always on for now)'};
for k = 1:numel(old)
    b = [s '/' old{k}];
    if getSimulinkBlockHandle(b) > 0
        ph = get_param(b,'PortHandles');
        for p = [ph.Inport ph.Outport]
            l = get_param(p,'Line'); if l > 0, delete_line(l); end
        end
        delete_block(b);
    end
end

% ---- 2. add the Supervisor (MATLAB Function block) ------------------------
sup = [s '/Supervisor'];
add_block('simulink/User-Defined Functions/MATLAB Function', sup, 'Position', [200 40 360 160]);
rt = sfroot;
ch = rt.find('-isa','Stateflow.EMChart','Path',sup);
ch.Script = supervisor_code();
ch.ChartUpdate = 'DISCRETE';
ch.SampleTime  = 'Ts_bms';
prm = {'I_chg','I_dis','V_cutoff','V_resume','V_min','T_chg','T_rest1','T_dis','T_rest2','Ts_bms'};
for k = 1:numel(prm)
    d = ch.find('-isa','Stateflow.Data','Name',prm{k});
    if isempty(d), d = Stateflow.Data(ch); d.Name = prm{k}; end
    d.Scope = 'Parameter';
end

% ---- 3. new outport for the mode ------------------------------------------
add_block('simulink/Sinks/Out1',[s '/Mode'],'Position',[620 193 650 207],'Port','5');

% ---- 4. wire it ------------------------------------------------------------
% one-step memory on the measured voltages (avoids an algebraic loop:
% current -> cell voltage -> supervisor -> current in the same instant)
add_block('simulink/Discrete/Memory',[s '/V delay'],'Position',[140 85 170 115]);
add_line(s,'Vcell/1','V delay/1','autorouting','on');
add_line(s,'V delay/1','Supervisor/1','autorouting','on');
add_line(s,'Supervisor/1','I_cmd/1','autorouting','on');
add_line(s,'Supervisor/2','Passive Cell Balancing/2','autorouting','on');
add_line(s,'Supervisor/3','ChargerOn/1','autorouting','on');
add_line(s,'Supervisor/4','Mode/1','autorouting','on');

% ---- 5. log the mode at the top level -------------------------------------
t = add_block('simulink/Sinks/Terminator',[mdl '/Mode_term'],'Position',[620 520 640 540]);
ph = get_param([mdl '/BMS'],'PortHandles');
l  = add_line(mdl, ph.Outport(5), get_param(t,'PortHandles').Inport(1),'autorouting','on');
set_param(l,'Name','Mode');
set_param(ph.Outport(5),'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName','Mode');
disp('Supervisor added.');
end

function c = supervisor_code()
c = strjoin({
'function [I_cmd, bal_en, chg_on, mode_id] = Supervisor(Vcell)'
'% BMS supervisor: decides the pack current and whether balancing may run.'
'% mode_id: 1 = CHARGE, 2 = REST, 3 = DISCHARGE, 4 = REST'
'persistent m t_in cut'
'if isempty(m)'
'    m = 1;  t_in = 0;  cut = false;     % start in CHARGE'
'end'
't_in = t_in + Ts_bms;                    % time spent in the current mode [s]'
'Vmax = max(Vcell);  Vmin = min(Vcell);'
''
'switch m'
'    case 1  % CHARGE: constant current, stop at V_cutoff, resume below V_resume'
'        if Vmax >= V_cutoff, cut = true;  end'
'        if Vmax <  V_resume, cut = false; end'
'        I_cmd  = I_chg * double(~cut);'
'        bal_en = true;'
'        if t_in >= T_chg, m = 2; t_in = 0; end'
'    case 2  % REST after charge: no current, balancing continues'
'        I_cmd  = 0;'
'        bal_en = true;'
'        if t_in >= T_rest1, m = 3; t_in = 0; end'
'    case 3  % DISCHARGE: drive a load, no balancing (would waste energy twice)'
'        I_cmd  = -I_dis;'
'        bal_en = false;'
'        if t_in >= T_dis || Vmin <= V_min, m = 4; t_in = 0; end'
'    otherwise  % REST after discharge'
'        I_cmd  = 0;'
'        bal_en = true;'
'        if t_in >= T_rest2, m = 1; t_in = 0; cut = false; end'
'end'
'chg_on = double(I_cmd > 0);'
'mode_id = m;'
}, newline);
end
