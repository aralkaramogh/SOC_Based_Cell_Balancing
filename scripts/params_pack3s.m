%% params_pack3s.m  -  ALL numbers for the 3S passive-balancing model
% The model loads this automatically (model PreLoadFcn / InitFcn).
% Change values here, never inside block dialogs.

%% Cell: 3.7 V nominal, 2.5 Ah Li-ion (generic 18650-type, NCA/NMC)
Cell_AH     = 2.5;                    % nominal capacity [Ah] (per-cell values: Cap below)
Cell_T_bp   = [278 293 313];          % temperature breakpoints [K]
Cell_SOC_bp = 0:0.1:1;                % SOC breakpoints [-]
% Open-circuit voltage V0(SOC,T) [V]   rows = SOC, columns = T
Cell_V0 = [3.00 3.05 3.08; 3.42 3.45 3.47; 3.53 3.55 3.57; 3.60 3.62 3.64;
           3.65 3.67 3.69; 3.70 3.72 3.74; 3.78 3.80 3.82; 3.88 3.90 3.92;
           3.97 3.99 4.01; 4.06 4.08 4.10; 4.16 4.18 4.19];
% Internal resistance R0(SOC,T) [Ohm]
Cell_R0 = [.070 .045 .035; .055 .036 .028; .050 .033 .026; .048 .032 .025;
           .046 .031 .024; .045 .030 .024; .045 .030 .024; .045 .030 .024;
           .046 .031 .025; .047 .031 .025; .048 .032 .026];
Cell_Vrange = [2.5 4.3];              % allowed terminal voltage window [V]

%% Pack: 3 cells in series, deliberately unbalanced
SOC0     = [0.68 0.75 0.70];          % initial SOC of Cell 1, 2, 3
Cap      = [2.5 2.5 2.5];             % capacity of Cell 1, 2, 3 [Ah]   (step A: make them differ)
R0_scale = [1.0 1.0 1.0];             % R0 multiplier of Cell 1, 2, 3   (1.5 = 50 % higher resistance)

%% Charger (constant current) + hard cut-off
I_chg    = 1.25;                      % charge current [A]  (0.5C)
V_cutoff = 4.20;                      % stop charging when ANY cell reaches this [V]
V_resume = 4.15;                      % allow charging again when ALL cells are below this [V]

%% BMS supervisor: timed cycle CHARGE -> REST -> DISCHARGE -> REST -> ...
I_dis   = 1.25;                       % discharge (load) current [A]  (0.5C)
V_min   = 3.00;                       % stop discharging when ANY cell falls to this [V]
T_chg   = 90*60;                      % time in CHARGE [s]
T_rest1 = 20*60;                      % time in REST after charging [s]
T_dis   = 40*60;                      % time in DISCHARGE [s]
T_rest2 = 10*60;                      % time in REST after discharging [s]

%% Passive balancing
R_bleed       = 47;                   % bleed resistor per cell [Ohm]  (~88 mA at 4.15 V)
Bal_threshold = 0.01;                 % start bleeding a cell 1 % SOC above the lowest cell
Bal_hyst      = 0.005;                % stop bleeding when it is 0.5 % above the lowest cell
Ts_bms        = 1;                    % BMS sample time [s]

%% Simulation
t_stop = 4*3600;                      % [s]  (one full cycle + start of the next)
