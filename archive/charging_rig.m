%% charging_rig.m  -  simple constant-current (CC) charging test rig
% Cell: 3.7 V nominal, 2.5 Ah, Simscape "Battery (Table-Based)"
% Builds a Simulink/Simscape model, runs it, plots voltage, current, SOC.
%
% Loop:  Controlled Current Source -> Current Sensor -> Battery -> back
% The sensors only measure; they do not change the circuit.
% NOTE: block library paths / port numbers can differ slightly between
% MATLAB releases. If add_block or add_line errors, see the notes at the end.

clear; clc;
mdl = 'charging_rig';
if bdIsLoaded(mdl), close_system(mdl,0); end
new_system(mdl); open_system(mdl);

%% 1) Test parameters (change these, not the blocks)
Cap_Ah  = 2.5;              % cell capacity [Ah]
C_rate  = 0.5;              % 0.5C = gentle charge
I_chg   = C_rate*Cap_Ah;    % charge current [A]  -> 1.25 A
SOC0    = 0.2;              % start at 20 % charged
tStop   = (1-SOC0)*Cap_Ah/I_chg*3600;  % time to reach 100 % [s] = 5760 s

set_param(mdl,'StopTime',num2str(tStop));
set_param(mdl,'SolverType','Variable-step','Solver','ode23t'); % stiff solver

%% 2) Add the blocks
add_block('nesl_utility/Solver Configuration',[mdl '/Solver'],'Position',[40 200 100 240]);
add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference',[mdl '/GND'],'Position',[40 300 80 340]);

add_block('ee_lib/Sources/Battery (Table-Based)',[mdl '/Cell'],'Position',[400 150 480 230]);
add_block('fl_lib/Electrical/Electrical Sources/Controlled Current Source',[mdl '/Charger'],'Position',[150 150 210 230]);

add_block('simulink/Sources/Constant',[mdl '/I_cmd'],'Value','I_chg','Position',[40 60 90 90]);
add_block('nesl_utility/Simulink-PS Converter',[mdl '/S2PS'],'Position',[120 60 170 90]);

add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor',[mdl '/Isense'],'Position',[260 150 320 230]);
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor',[mdl '/Vsense'],'Position',[400 300 460 360]);

add_block('nesl_utility/PS-Simulink Converter',[mdl '/PS2S_I'],  'Position',[560 100 610 130]);
add_block('nesl_utility/PS-Simulink Converter',[mdl '/PS2S_V'],  'Position',[560 310 610 340]);
add_block('nesl_utility/PS-Simulink Converter',[mdl '/PS2S_SOC'],'Position',[560 200 610 230]);

add_block('simulink/Sinks/Scope',[mdl '/Scope'],'NumInputPorts','3','Position',[700 140 760 300]);

%% 3) Cell parameters (matches the settings we discussed)
cell_blk = [mdl '/Cell'];
trySet(cell_blk,'AH',                 '2.5');
trySet(cell_blk,'T_vec',              '[278 293 313]');
trySet(cell_blk,'SOC_vec',            '[0 .1 .2 .3 .4 .5 .6 .7 .8 .9 1]');
trySet(cell_blk,'V0_mat', ['[3.00 3.05 3.08;3.42 3.45 3.47;3.53 3.55 3.57;3.60 3.62 3.64;' ...
                            '3.65 3.67 3.69;3.70 3.72 3.74;3.78 3.80 3.82;3.88 3.90 3.92;' ...
                            '3.97 3.99 4.01;4.06 4.08 4.10;4.16 4.18 4.19]']);
trySet(cell_blk,'R0_mat', ['[.070 .045 .035;.055 .036 .028;.050 .033 .026;.048 .032 .025;' ...
                            '.046 .031 .024;.045 .030 .024;.045 .030 .024;.045 .030 .024;' ...
                            '.046 .031 .025;.047 .031 .025;.048 .032 .026]']);

%% 4) Wire it up  (L = left side of block, R = right side)
% Physical (electrical) loop. Convention: LConn(1)=+, RConn(1)=- for 2-terminal blocks.
% Current inside a Controlled Current Source flows from its + to its - terminal,
% so to push current INTO the cell's + terminal we connect Charger(-) -> Isense -> Cell(+).
wire(mdl,'Charger','R',1, 'Isense','L',1);   % Charger(-)  -> Isense in
wire(mdl,'Isense', 'R',1, 'Cell',  'L',1);   % Isense out  -> Cell +
wire(mdl,'Cell',   'R',1, 'Charger','L',1);  % Cell -      -> Charger(+)  (closes the loop)

% Reference and solver attach to the loop (any node of the loop)
wire(mdl,'GND',   'L',1, 'Cell',  'R',1);
wire(mdl,'Solver','L',1, 'Cell',  'R',1);

% Voltage sensor across the cell (measures, draws no current)
wire(mdl,'Vsense','L',1, 'Cell','L',1);
wire(mdl,'Vsense','L',2, 'Cell','R',1);

% Signal path for the current command
add_line(mdl,'I_cmd/1','S2PS/1');
wire(mdl,'S2PS','R',1, 'Charger','L',2);     % PS signal -> source's control port

% Measurements: sensor -> PS-Simulink Converter -> Scope
wire(mdl,'Isense','R',2, 'PS2S_I','L',1);
wire(mdl,'Vsense','R',1, 'PS2S_V','L',1);
add_line(mdl,'PS2S_I/1','Scope/1');
add_line(mdl,'PS2S_V/1','Scope/2');
% SOC: first tick "Expose SOC measurement port" on the Cell block, then:
% wire(mdl,'Cell','R',2, 'PS2S_SOC','L',1); add_line(mdl,'PS2S_SOC/1','Scope/3');

%% 5) Initial SOC (in the Cell block: Initial Targets > Initial SOC)
trySet(cell_blk,'SOC_init', num2str(SOC0));   % name may vary - set by hand if it warns

%% 6) Run
sim(mdl);
disp('Done. Open the Scope. Voltage should rise toward ~4.2 V as SOC rises.');

%% ---- helper functions ----
function trySet(blk,param,val)
    try
        set_param(blk,param,val);
    catch
        warning('Could not set "%s" on %s. Set it by hand in the block dialog.',param,blk);
    end
end

function wire(mdl,a,sideA,ia,b,sideB,ib)
    pa = get_param([mdl '/' a],'PortHandles');
    pb = get_param([mdl '/' b],'PortHandles');
    fa = [sideA 'Conn'];  fb = [sideB 'Conn'];
    add_line(mdl, pa.(fa)(ia), pb.(fb)(ib));
end
