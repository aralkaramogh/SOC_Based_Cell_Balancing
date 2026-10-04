%% build_pack3s_passive_balancing.m
% Builds models/pack3s_passive_balancing.slx from scratch.
% Run it once (or again after changing the STRUCTURE). For new numbers,
% just edit params_pack3s.m - no rebuild needed.
%
% Top level (left to right):
%   Charger  ->  Cell 1 -> Cell 2 -> Cell 3 (series)  ->  back to Charger
%   BMS      :  reads SOC + cell voltages, decides charge current and bleed commands
%   Scopes   :  SOC, voltages/current, BMS decisions
%
% Simscape port order used below (found by testing in R2025b):
%   Battery (Table-Based): LConn1 = +, LConn2 = SOC out, RConn1 = -
%   Controlled Current Source: LConn1 = head (+, current leaves here), RConn1 = command, RConn2 = tail
%   Current/Voltage Sensor: LConn1 = +, RConn1 = measurement out, RConn2 = -
%   Switch: LConn1 = p, RConn1 = control, RConn2 = n

mdl  = 'pack3s_passive_balancing';
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
params_pack3s;                                   % load numbers into the workspace

if bdIsLoaded(mdl), close_system(mdl,0); end
slx = fullfile(root,'models',[mdl '.slx']);
if isfile(slx), delete(slx); end                 % rebuilding = start from a clean file
new_system(mdl); open_system(mdl);
load_system('nesl_utility'); load_system('fl_lib'); load_system('ee_lib'); load_system('batt_sl_lib');

set_param(mdl,'PreLoadFcn','params_pack3s;','InitFcn','params_pack3s;', ...
    'StopTime','t_stop','SolverType','Variable-step','Solver','ode23t','MaxStep','1', ...
    'SignalLogging','on','SignalLoggingName','logsout','ReturnWorkspaceOutputs','on');

%% ================= ROW 1: the PLANT (physics) =================
% Signals between plant and BMS use Goto/From tags (same tag name = connected),
% so the power path stays readable without crossing lines.
cx = [450 800 1150];                                  % x of Cell 1..3
cells = {'Cell 1','Cell 2','Cell 3'};
buildCharger(mdl,'Charger',[130 200 250 320]);
for k = 1:3
    buildCell(mdl,cells{k},[cx(k) 200 cx(k)+120 320],k);
    tagFrom(mdl,sprintf('Bleed_%d',k),cells{k},1);
    tagGoto(mdl,sprintf('SOC_%d',k),cells{k},1);
    tagGoto(mdl,sprintf('V_%d',k),  cells{k},2);
end
tagFrom(mdl,'I_cmd','Charger',1);
tagGoto(mdl,'I_meas','Charger',1);

add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference',[mdl '/GND'],'Position',[1300 380 1330 410]);
add_block('nesl_utility/Solver Configuration',[mdl '/Solver Configuration'],'Position',[1350 365 1410 395]);

% power path (series string)
pwire(mdl,'Charger','RConn',1,'Cell 1','LConn',1);   % charger +  -> cell 1 +
pwire(mdl,'Cell 1','RConn',1,'Cell 2','LConn',1);    % cell 1 -   -> cell 2 +
pwire(mdl,'Cell 2','RConn',1,'Cell 3','LConn',1);    % cell 2 -   -> cell 3 +
pwire(mdl,'Cell 3','RConn',1,'Charger','RConn',2);   % cell 3 -   -> charger -
pwire(mdl,'GND','LConn',1,'Cell 3','RConn',1);
pwire(mdl,'Solver Configuration','RConn',1,'Cell 3','RConn',1);

%% ================= ROW 2: the BMS (control) =================
add_block('simulink/Signal Routing/Mux',[mdl '/SOC_mux'],'Inputs','3','Position',[420 485 425 575]);
add_block('simulink/Signal Routing/Mux',[mdl '/V_mux'],'Inputs','3','Position',[420 605 425 695]);
for k = 1:3
    tagFrom(mdl,sprintf('SOC_%d',k),'SOC_mux',k);
    tagFrom(mdl,sprintf('V_%d',k),  'V_mux',k);
end
buildBMS(mdl,'BMS',[520 500 720 680]);
sline(mdl,'SOC_mux/1','BMS/1');
sline(mdl,'V_mux/1','BMS/2');
tagGoto(mdl,'I_cmd','BMS',1);
add_block('simulink/Signal Routing/Demux',[mdl '/Cmd_demux'],'Outputs','3','Position',[860 535 865 625]);
sline(mdl,'BMS/2','Cmd_demux/1');
for k = 1:3, tagGoto(mdl,sprintf('Bleed_%d',k),'Cmd_demux',k); end

%% ================= scopes =================
add_block('simulink/Sinks/Scope',[mdl '/SOC scope'],'NumInputPorts','1','Position',[1050 470 1100 520]);
add_block('simulink/Sinks/Scope',[mdl '/Voltage & current scope'],'NumInputPorts','2','Position',[1050 580 1100 640]);
add_block('simulink/Sinks/Scope',[mdl '/BMS scope'],'NumInputPorts','3','Position',[1050 680 1100 750]);
sline(mdl,'SOC_mux/1','SOC scope/1');
sline(mdl,'V_mux/1','Voltage & current scope/1');
add_block('simulink/Signal Routing/From',[mdl '/From_I_meas'],'GotoTag','I_meas','Position',[960 618 1020 638]);
sline(mdl,'From_I_meas/1','Voltage & current scope/2');
sline(mdl,'BMS/2','BMS scope/1');
sline(mdl,'BMS/3','BMS scope/2');
sline(mdl,'BMS/4','BMS scope/3');

c = get_param([mdl '/SOC scope'],'ScopeConfiguration');
c.ShowLegend = true; c.ShowGrid = true; c.YLimits = [0.7 1.0]; c.Title = 'SOC of each cell';
c = get_param([mdl '/Voltage & current scope'],'ScopeConfiguration');
c.LayoutDimensions = [2 1]; c.ShowLegend = true; c.ShowGrid = true;
c = get_param([mdl '/BMS scope'],'ScopeConfiguration');
c.LayoutDimensions = [3 1]; c.ShowLegend = true; c.ShowGrid = true;

%% ---------- name + log the important signals ----------
logSig(mdl,'SOC_mux',1,'SOC');
logSig(mdl,'V_mux',1,'Vcell');
logSig(mdl,'Charger',1,'I_meas');
logSig(mdl,'BMS',1,'I_cmd');
logSig(mdl,'BMS',2,'BleedCmd');
logSig(mdl,'BMS',3,'ChargerOn');
logSig(mdl,'BMS',4,'BalancingActive');

%% ---------- notes on the canvas ----------
a = Simulink.Annotation(mdl,'3S pack, passive SOC balancing  -  all numbers live in scripts\params_pack3s.m');
a.Position = [40 60 800 80]; a.FontSize = 14; a.FontWeight = 'bold';
a = Simulink.Annotation(mdl,'PLANT (physics):  Charger -> Cell 1 -> Cell 2 -> Cell 3 -> back to Charger, in series');
a.Position = [40 100 800 115]; a.FontWeight = 'bold';
a = Simulink.Annotation(mdl,'BMS (control logic):  reads SOC_k and V_k, sends I_cmd to the charger and Bleed_k to each cell');
a.Position = [300 440 1000 455]; a.FontWeight = 'bold';

Simulink.BlockDiagram.arrangeSystem([mdl '/BMS']);
Simulink.BlockDiagram.arrangeSystem([mdl '/Charger']);
set_param([mdl '/BMS'],'ContentPreviewEnabled','off');
set_param([mdl '/Charger'],'ContentPreviewEnabled','off');

save_system(mdl, fullfile(root,'models',[mdl '.slx']));
fprintf('Built and saved %s\n', fullfile(root,'models',[mdl '.slx']));

%% =====================================================================
%%                          local functions
%% =====================================================================
function sys = newSubsystem(parent,name,pos)
    sys = [parent '/' name];
    add_block('simulink/Ports & Subsystems/Subsystem',sys,'Position',pos);
    delete_line(sys,'In1/1','Out1/1'); delete_block([sys '/In1']); delete_block([sys '/Out1']);
end

function buildCell(parent,name,pos,k)
% One cell + its own bleed circuit + sensors.
% Ports: in BleedCmd | out SOC, V | physical + (left), - (right)
    s = newSubsystem(parent,name,pos);
    % layout: [bleed branch]  [battery]  [voltage sensor]  -> outputs
    add_block('simulink/Sources/In1',[s '/BleedCmd'],'Position',[20 268 50 282]);
    add_block('simulink/Sinks/Out1',[s '/SOC'],'Position',[720 93 750 107]);
    add_block('simulink/Sinks/Out1',[s '/V'],'Position',[720 323 750 337],'Port','2');
    add_block('nesl_utility/Connection Port',[s '/+'],'Position',[40 50 70 70],'Side','Left','Port','1');
    add_block('nesl_utility/Connection Port',[s '/-'],'Position',[40 410 70 430],'Side','Right','Port','2');

    b = [s '/Battery'];
    add_block('ee_lib/Sources/Battery (Table-Based)',b,'Position',[400 180 470 280]);
    set_param(b,'AH','Cap_cell','T_vec','Cell_T_bp','SOC_vec','Cell_SOC_bp', ...
        'V0_mat','Cell_V0','R0_mat','Cell_R0*R0_k','V_range','Cell_Vrange', ...
        'SOC_port','simscape.enum.tablebattery.enable.yes', ...
        'stateOfCharge_specify','on','stateOfCharge_priority','High','stateOfCharge','SOC_init');

    add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor',[s '/Vsense'],'Position',[560 200 610 260]);
    add_block('nesl_utility/PS-Simulink Converter',[s '/PS2S_SOC'],'Position',[600 85 640 115]);
    add_block('nesl_utility/PS-Simulink Converter',[s '/PS2S_V'],'Position',[640 315 680 345]);
    add_block('nesl_utility/Simulink-PS Converter',[s '/S2PS_Cmd'],'Position',[100 260 140 290]);
    add_block('fl_lib/Electrical/Electrical Elements/Switch',[s '/Bleed switch'],'Position',[200 160 240 220],'Threshold','0.5');
    add_block('fl_lib/Electrical/Electrical Elements/Resistor',[s '/R_bleed'],'Position',[205 290 235 340],'R','R_bleed','Orientation','down');

    pwire(s,'+','RConn',1,'Battery','LConn',1);
    pwire(s,'-','RConn',1,'Battery','RConn',1);
    pwire(s,'Vsense','LConn',1,'Battery','LConn',1);
    pwire(s,'Vsense','RConn',2,'Battery','RConn',1);
    pwire(s,'Vsense','RConn',1,'PS2S_V','LConn',1);
    pwire(s,'Battery','LConn',2,'PS2S_SOC','LConn',1);
    pwire(s,'S2PS_Cmd','RConn',1,'Bleed switch','RConn',1);
    pwire(s,'Bleed switch','LConn',1,'Battery','LConn',1);
    pwire(s,'Bleed switch','RConn',2,'R_bleed','LConn',1);
    pwire(s,'R_bleed','RConn',1,'Battery','RConn',1);
    sline(s,'BleedCmd/1','S2PS_Cmd/1');
    sline(s,'PS2S_SOC/1','SOC/1');
    sline(s,'PS2S_V/1','V/1');

    m = Simulink.Mask.create(s);
    m.addParameter('Type','edit','Name','SOC_init','Prompt','Initial SOC [-]','Value',sprintf('SOC0(%d)',k));
    m.addParameter('Type','edit','Name','Cap_cell','Prompt','Capacity [Ah]','Value',sprintf('Cap(%d)',k));
    m.addParameter('Type','edit','Name','R0_k','Prompt','R0 multiplier [-]','Value',sprintf('R0_scale(%d)',k));
    m.Description = 'One Li-ion cell (Battery Table-Based) with its own bleed switch + resistor. BleedCmd = 1 turns the bleed resistor on.';
    m.Display = sprintf('disp(''%s\\nSOC0 = SOC0(%d)\\nCap = Cap(%d)'')',name,k,k);
end

function buildCharger(parent,name,pos)
% Constant-current source following the BMS command I_cmd.
% Ports: in I_cmd | out I_meas | physical + and - (both right)
    s = newSubsystem(parent,name,pos);
    add_block('simulink/Sources/In1',[s '/I_cmd'],'Position',[30 63 60 77]);
    add_block('simulink/Sinks/Out1',[s '/I_meas'],'Position',[520 153 550 167]);
    add_block('nesl_utility/Connection Port',[s '/+'],'Position',[520 40 550 60],'Side','Right','Port','1');
    add_block('nesl_utility/Connection Port',[s '/-'],'Position',[520 240 550 260],'Side','Right','Port','2');
    add_block('nesl_utility/Simulink-PS Converter',[s '/S2PS'],'Position',[100 55 140 85]);
    add_block('fl_lib/Electrical/Electrical Sources/Controlled Current Source',[s '/Current source'],'Position',[200 100 260 180]);
    add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor',[s '/Isense'],'Position',[330 30 390 90]);
    add_block('nesl_utility/PS-Simulink Converter',[s '/PS2S_I'],'Position',[440 145 480 175]);
    sline(s,'I_cmd/1','S2PS/1');
    pwire(s,'S2PS','RConn',1,'Current source','RConn',1);
    pwire(s,'Current source','LConn',1,'Isense','LConn',1);   % head -> sensor +
    pwire(s,'Isense','RConn',2,'+','RConn',1);                % sensor - -> pack +
    pwire(s,'Current source','RConn',2,'-','RConn',1);        % tail -> pack -
    pwire(s,'Isense','RConn',1,'PS2S_I','LConn',1);
    sline(s,'PS2S_I/1','I_meas/1');
end

function buildBMS(parent,name,pos)
% Pure control logic (Simulink only, no physics).
% in : SOC[3], Vcell[3]
% out: I_cmd, BleedCmd[3], ChargerOn, BalancingActive
    s = newSubsystem(parent,name,pos);
    add_block('simulink/Sources/In1',[s '/SOC'],'Position',[30 213 60 227]);
    add_block('simulink/Sources/In1',[s '/Vcell'],'Position',[30 63 60 77],'Port','2');
    add_block('simulink/Sinks/Out1',[s '/I_cmd'],'Position',[620 73 650 87]);
    add_block('simulink/Sinks/Out1',[s '/BleedCmd'],'Position',[620 213 650 227],'Port','2');
    add_block('simulink/Sinks/Out1',[s '/ChargerOn'],'Position',[620 133 650 147],'Port','3');
    add_block('simulink/Sinks/Out1',[s '/BalancingActive'],'Position',[620 273 650 287],'Port','4');

    % --- charge cut-off: highest cell voltage vs V_cutoff / V_resume ---
    add_block('simulink/Math Operations/MinMax',[s '/Highest cell V'],'Function','max','Inputs','1','Position',[110 55 150 85]);
    add_block('simulink/Discontinuities/Relay',[s '/Cut-off relay'],'Position',[200 55 250 85], ...
        'OnSwitchValue','V_cutoff','OffSwitchValue','V_resume','OnOutputValue','0','OffOutputValue','1');
    add_block('simulink/Discrete/Memory',[s '/Delay1'],'InitialCondition','1','Position',[290 55 320 85]);
    add_block('simulink/Sources/Constant',[s '/I_chg'],'Value','I_chg','Position',[290 100 330 120]);
    add_block('simulink/Math Operations/Product',[s '/Gate'],'Inputs','2','Position',[400 65 430 100]);
    sline(s,'Vcell/1','Highest cell V/1');
    sline(s,'Highest cell V/1','Cut-off relay/1');
    sline(s,'Cut-off relay/1','Delay1/1');
    sline(s,'Delay1/1','Gate/1');
    sline(s,'I_chg/1','Gate/2');
    sline(s,'Gate/1','I_cmd/1');
    sline(s,'Delay1/1','ChargerOn/1');

    % --- passive balancing on SOC ---
    add_block('batt_sl_lib/Cell Balancing/Passive Cell Balancing',[s '/Passive Cell Balancing'], ...
        'Position',[200 200 320 270],'Threshold','Bal_threshold','HysteresisBand','Bal_hyst','Ts','Ts_bms');
    add_block('simulink/Sources/Constant',[s '/Enable (always on for now)'],'Value','true', ...
        'OutDataTypeStr','boolean','Position',[100 250 140 270]);
    add_block('simulink/Discrete/Memory',[s '/Delay2'],'InitialCondition','0','Position',[400 205 430 235]);
    sline(s,'SOC/1','Passive Cell Balancing/1');
    sline(s,'Enable (always on for now)/1','Passive Cell Balancing/2');
    sline(s,'Passive Cell Balancing/1','Delay2/1');
    sline(s,'Delay2/1','BleedCmd/1');
    sline(s,'Passive Cell Balancing/2','BalancingActive/1');
end

function pwire(sys,a,sa,ia,b,sb,ib)
% physical (Simscape) connection between two blocks inside sys
    pa = get_param([sys '/' a],'PortHandles');
    pb = get_param([sys '/' b],'PortHandles');
    add_line(sys, pa.(sa)(ia), pb.(sb)(ib), 'autorouting','smart');
end

function sline(sys,from,to)
% normal Simulink signal line
    add_line(sys, from, to, 'autorouting','smart');
end

function tagGoto(sys,tag,blk,port)
% send output 'port' of 'blk' to a named tag, placed right next to the port
    ph = get_param([sys '/' blk],'PortHandles');
    xy = get_param(ph.Outport(port),'Position');
    g  = ['Goto_' tag];
    add_block('simulink/Signal Routing/Goto',[sys '/' g],'GotoTag',tag,'ShowName','off', ...
        'Position',[xy(1)+25 xy(2)-9 xy(1)+85 xy(2)+9]);
    add_line(sys, sprintf('%s/%d',blk,port), [g '/1']);
end

function tagFrom(sys,tag,blk,port)
% read a named tag into input 'port' of 'blk', placed right next to the port
    ph = get_param([sys '/' blk],'PortHandles');
    xy = get_param(ph.Inport(port),'Position');
    f  = ['From_' tag];
    add_block('simulink/Signal Routing/From',[sys '/' f],'GotoTag',tag,'ShowName','off', ...
        'Position',[xy(1)-85 xy(2)-9 xy(1)-25 xy(2)+9]);
    add_line(sys, [f '/1'], sprintf('%s/%d',blk,port));
end

function logSig(sys,blk,port,name)
    ph = get_param([sys '/' blk],'PortHandles');
    set_param(ph.Outport(port),'Name',name,'DataLogging','on');
end
