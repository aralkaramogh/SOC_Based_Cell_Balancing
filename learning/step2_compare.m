%% STEP 2 - Check the Simulink model against the step 1 script
% Runs step 1 (the script) and step 2 (the Simulink model) and plots both.
% If your Simulink model is right, the two lines lie on top of each other.

% 1) Run the script version and keep its results
step1_single_cell;             % creates t, SOC, V
t_ref   = t;
SOC_ref = SOC;
V_ref   = V;
close all;

% 2) Load parameters and run the Simulink model
step2_params;
out = sim('step2_cell');

% The "To Workspace" blocks save time series named SOC_sim and V_sim
SOC_sl = out.SOC_sim;
V_sl   = out.V_sim;

% 3) Plot both
figure('Name', 'Step 2 - script vs Simulink');

subplot(2,1,1);
plot(t_ref/60, SOC_ref*100, 'LineWidth', 2); hold on;
plot(SOC_sl.Time/60, SOC_sl.Data*100, '--', 'LineWidth', 1.5);
ylabel('SOC (%)'); legend('Step 1 script', 'Step 2 Simulink'); grid on;
title('SOC');

subplot(2,1,2);
plot(t_ref/60, V_ref, 'LineWidth', 2); hold on;
plot(V_sl.Time/60, V_sl.Data, '--', 'LineWidth', 1.5);
ylabel('Voltage (V)'); xlabel('Time (minutes)');
legend('Step 1 script', 'Step 2 Simulink'); grid on;
title('Terminal voltage');

% 4) One number to judge the match
[t_u, idx] = unique(V_sl.Time, 'last');     % Simulink repeats time points at pulse edges
V_sl_on_ref_grid = interp1(t_u, V_sl.Data(idx), t_ref);
err = abs(V_sl_on_ref_grid - V_ref);
fprintf('Average voltage difference: %.4f V\n', mean(err));
disp('Below ~0.005 V = your model matches the script.');
