%% plot_balancing.m - run ess_balancing_rig and plot the results
% Put this file in the same folder as ess_balancing_rig.slx and run it.
% Change I_chg / R_bleed / SOC0 below to try other cases.

mdl = 'ess_balancing_rig';
load_system(mdl);

I_chg   = 1.25;               % charge current [A]
R_bleed = 47;                 % bleed resistor [Ohm]  (try 3 for a fast demo)
SOC0    = [0.80 0.75 0.75];   % initial SOC of Cell, Cell1, Cell2

simIn = Simulink.SimulationInput(mdl);
simIn = simIn.setVariable('I_chg',I_chg).setVariable('R_bleed',R_bleed).setVariable('SOC0',SOC0);
out = sim(simIn);

% ---- pull logged data ----
S   = out.socData;    t  = S.time/60;  soc = S.signals.values;      % SOC [-], time in minutes
B   = out.balData;    tb = B.time/60;  cmd = B.signals(1).values;   % bleed commands (3 cols)
C   = out.cutoffData; tc = C.time/60;  vmax = C.signals(1).values;  icmd = C.signals(3).values;
spread = max(soc,[],2) - min(soc,[],2);

% ---- figure ----
f = figure('Name','Cell balancing results','Color','w','Position',[100 80 1000 800]);
tl = tiledlayout(f,4,1,'TileSpacing','compact');
title(tl, sprintf('Passive balancing: I_{chg}=%.2f A, R_{bleed}=%g \\Omega, SOC_0=[%s]', ...
      I_chg, R_bleed, num2str(SOC0)));

nexttile; plot(t, soc, 'LineWidth',1.5); grid on;
ylabel('SOC'); legend('Cell','Cell1','Cell2','Location','southeast'); title('Cell SOC');

nexttile; plot(t, spread*100, 'k', 'LineWidth',1.5); grid on; hold on;
yline(1,'--r','1 % target'); ylabel('Spread [%]'); title('SOC spread (max - min)');

nexttile; stairs(tb, cmd + [0 1.2 2.4], 'LineWidth',1.2); grid on;
yticks([0.5 1.7 2.9]); yticklabels({'Cell','Cell1','Cell2'}); title('Bleed switch ON (high level)');

nexttile; yyaxis left;  plot(tc, vmax, 'LineWidth',1.2); ylabel('Max cell V [V]'); yline(4.2,':');
          yyaxis right; plot(tc, icmd, 'LineWidth',1.2); ylabel('Charge cmd [A]');
grid on; xlabel('Time [min]'); title('Charger cut-off');

% ---- summary in the command window ----
i1 = find(spread < 0.01, 1);
fprintf('Final SOC: %s   spread %.2f %%\n', mat2str(soc(end,:),3), spread(end)*100);
if ~isempty(i1), fprintf('Spread below 1 %% after %.1f min\n', t(i1)); end
fprintf('Bleed ON time per cell [min]: %s\n', mat2str(sum(diff(tb).*cmd(1:end-1,:)),3));
