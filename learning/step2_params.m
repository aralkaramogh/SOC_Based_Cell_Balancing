%% STEP 2 - Parameters for the Simulink cell model (step2_cell.slx)
% Run this BEFORE running the Simulink model.
% Every block in the model uses these variable NAMES instead of numbers,
% so you never have to type a number inside a block dialog.
% They are the same values as step 1, so the two results should match.

Q_Ah = 2.5;            % capacity (Ah)
Q    = Q_Ah * 3600;    % capacity (A*s)
R0   = 0.030;          % ohms
R1   = 0.020;          % ohms
C1   = 2000;           % farads
SOC0 = 1.0;            % starting SOC

soc_table = 0:0.1:1;
ocv_table = [3.00 3.45 3.55 3.62 3.68 3.75 3.85 3.95 4.05 4.12 4.20];

I_pulse = 4;           % A, discharge current during a pulse
T_cycle = 600;         % s, one pulse + one rest
t_end   = 3600;        % s, stop time

disp('Step 2 parameters loaded.');
