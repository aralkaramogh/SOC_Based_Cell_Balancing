%% STEP 1 - One lithium-ion cell, simulated in a plain MATLAB script
% Goal: see with your own eyes that TERMINAL VOLTAGE is not the same as SOC.
%
% The cell model (called a "1-RC equivalent circuit model"):
%
%      +----[ R0 ]----[ R1 || C1 ]----+
%      |                              |
%    (OCV)                        terminal voltage V
%      |                              |
%      +------------------------------+
%
%   OCV : "open circuit voltage" - the voltage the cell would show if it
%         rested for a long time. It depends ONLY on SOC (a lookup table).
%   R0  : instant resistance. The moment current flows, voltage drops by I*R0.
%   R1,C1 : slow "relaxation" effect. Voltage keeps sagging for a while under
%         load and slowly recovers after the load stops.
%
% Equations (I > 0 means discharging):
%   SOC(next) = SOC - I*dt / Q                 <- Coulomb counting, the true SOC
%   V1(next)  = V1 + dt*( -V1/(R1*C1) + I/C1 ) <- voltage across the RC pair
%   V         = OCV(SOC) - I*R0 - V1           <- what a voltmeter would read

clear; clc; close all;

%% 1. Cell parameters  (try changing these later!)
Q_Ah = 2.5;            % capacity in amp-hours (a typical 18650 cell)
Q    = Q_Ah * 3600;    % capacity in amp-seconds (coulombs)
R0   = 0.030;          % ohms
R1   = 0.020;          % ohms
C1   = 2000;           % farads  -> time constant R1*C1 = 40 seconds

% OCV-vs-SOC lookup table (rough shape of a real NMC cell)
soc_table = 0:0.1:1;
ocv_table = [3.00 3.45 3.55 3.62 3.68 3.75 3.85 3.95 4.05 4.12 4.20];

%% 2. Simulation settings
dt    = 1;                 % time step in seconds
t_end = 3600;              % simulate 1 hour
t     = 0:dt:t_end;
N     = length(t);

% Load profile: 4 A for 5 minutes, then rest 5 minutes, repeat
% (4 A = 1.6C for this cell, i.e. it would empty in ~37 min if continuous)
I = zeros(1, N);
for k = 1:N
    if mod(t(k), 600) < 300
        I(k) = 4;          % discharging
    else
        I(k) = 0;          % resting
    end
end

%% 3. Storage for results
SOC = zeros(1, N);
V1  = zeros(1, N);
V   = zeros(1, N);
OCV = zeros(1, N);

SOC(1) = 1.0;              % start fully charged
V1(1)  = 0;

%% 4. The simulation loop - one small time step at a time
for k = 1:N
    OCV(k) = interp1(soc_table, ocv_table, SOC(k));
    V(k)   = OCV(k) - I(k)*R0 - V1(k);

    if k < N
        SOC(k+1) = SOC(k) - I(k)*dt/Q;
        V1(k+1)  = V1(k) + dt*( -V1(k)/(R1*C1) + I(k)/C1 );
    end
end

%% 5. Plots
tm = t/60;   % minutes, easier to read

figure('Name', 'Step 1 - single cell');

subplot(3,1,1);
plot(tm, I, 'LineWidth', 1.5);
ylabel('Current (A)'); title('Load current (positive = discharge)');
grid on; ylim([-0.5 5]);

subplot(3,1,2);
plot(tm, SOC*100, 'LineWidth', 1.5);
ylabel('SOC (%)'); title('State of charge (the truth)');
grid on;

subplot(3,1,3);
plot(tm, OCV, '--', tm, V, 'LineWidth', 1.5);
ylabel('Voltage (V)'); xlabel('Time (minutes)');
legend('OCV (what SOC "really" corresponds to)', 'Terminal voltage (what you can measure)', ...
       'Location', 'southwest');
title('Voltage');
grid on;

fprintf('Final SOC: %.1f %%\n', SOC(end)*100);
fprintf('Voltage just before first rest: %.3f V\n', V(300));
fprintf('Voltage 5 min into first rest:  %.3f V  (same SOC!)\n', V(600));
