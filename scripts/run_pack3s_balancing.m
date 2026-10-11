%% run_pack3s_balancing.m  -  run the 3S balancing model and plot the results
% Uses the numbers in params_pack3s.m. To try another case without editing
% that file, change the "overrides" below (leave empty to use the defaults).

mdl  = 'pack3s_passive_balancing';
root = fileparts(fileparts(mfilename('fullpath')));
params_pack3s;

% ---- optional overrides for this run (comment out to use params file) ----
if ~exist('overrides','var') || ~isstruct(overrides), overrides = struct(); end   % can be set before calling
% overrides.R_bleed = 3;                 % fast demo
% overrides.SOC0    = [0.80 0.20 0.20];  % big imbalance
% overrides.Cap      = [2.5 2.3 2.5];      % mismatched capacity
% overrides.R0_scale = [1 1 1.5];         % one high-resistance cell
if ~exist('tag','var'), tag = ''; end     % optional label added to the figure file name

load_system(mdl);
in = Simulink.SimulationInput(mdl);
f = fieldnames(overrides);
for k = 1:numel(f)
    in = in.setVariable(f{k}, overrides.(f{k}));
    eval([f{k} ' = overrides.(f{k});']);   % so the plot titles show the used values
end
out = sim(in);

% ---- logged signals ----
L    = out.logsout;
soc  = L.getElement('SOC').Values;           t  = soc.Time/60;  SOC = squeeze(soc.Data);
vc   = L.getElement('Vcell').Values;         V  = squeeze(vc.Data);
icmd = L.getElement('I_cmd').Values;
imea = L.getElement('I_meas').Values;
cmd  = L.getElement('BleedCmd').Values;      CMD = squeeze(cmd.Data);
if size(SOC,1) == 3 && size(SOC,2) ~= 3, SOC = SOC.'; end
if size(V,1)   == 3 && size(V,2)   ~= 3, V   = V.';   end
if size(CMD,1) == 3 && size(CMD,2) ~= 3, CMD = CMD.'; end
spread = max(SOC,[],2) - min(SOC,[],2);
md   = L.getElement('Mode').Values;          MD = squeeze(md.Data);
% energy burned in the bleed resistors: P = V^2/R while the switch is on
[tu, iu] = unique(vc.Time);
Vc   = interp1(tu, V(iu,:), cmd.Time, 'previous', 'extrap');
E_bleed = sum( sum(Vc(1:end-1,:).^2 .* CMD(1:end-1,:), 2) .* diff(cmd.Time) ) / R_bleed;   % [J]

% ---- figure ----
fig = figure('Name','3S passive balancing','Color','w','Position',[80 40 1050 1000]);
tl  = tiledlayout(fig,5,1,'TileSpacing','compact');
title(tl,{sprintf('I_{chg} = %.2f A,  R_{bleed} = %g \\Omega,  SOC_0 = [%s],  cut-off %.2f V / resume %.2f V', ...
      I_chg, R_bleed, strjoin(compose('%.2f',SOC0),' '), V_cutoff, V_resume), ...
      sprintf('Capacity = [%s] Ah,   R_0 multiplier = [%s]', strjoin(compose('%.2f',Cap),' '), strjoin(compose('%.1f',R0_scale),' '))});
styles = {'-','--',':'};    % Cell 2 and 3 often overlap - different styles keep both visible

ax1 = nexttile; h = plot(t,SOC,'LineWidth',1.8); set(h,{'LineStyle'},styles'); grid on; ylabel('SOC [-]');
legend('Cell 1','Cell 2','Cell 3','Location','southeast'); title('1) State of charge of each cell');

ax2 = nexttile; plot(t,spread*100,'k','LineWidth',1.6); grid on; hold on;
yline(Bal_threshold*100,'--r','start bleeding'); yline(Bal_hyst*100,':b','stop bleeding');
ylabel('max - min [%]'); title('2) SOC spread = how unbalanced the pack is');

ax3 = nexttile; tc = cmd.Time/60;
stairs(tc, CMD + [0 1.5 3], 'LineWidth',1.3); grid on; ylim([-0.3 4.3]);
yticks([0.5 2 3.5]); yticklabels({'Cell 1','Cell 2','Cell 3'});
title('3) Bleed switch per cell (raised = resistor ON)');

ax4 = nexttile; yyaxis left; h = plot(t,V,'LineWidth',1.2); set(h,{'LineStyle'},styles'); ylabel('Cell V [V]');
yline(V_cutoff,':','cut-off'); yline(V_resume,':','resume');
yyaxis right; stairs(icmd.Time/60, squeeze(icmd.Data),'LineWidth',1.2); ylabel('Charge current [A]');
grid on; title('4) Cell voltages (left) and pack current, + = charge / - = discharge (right)');
ax5 = nexttile; stairs(md.Time/60, MD, 'k', 'LineWidth',1.5); grid on; ylim([0.5 4.5]);
yticks(1:4); yticklabels({'CHARGE','REST','DISCHARGE','REST'}); xlabel('Time [min]');
title('5) BMS mode (balancing allowed in CHARGE and REST, blocked in DISCHARGE)');
linkaxes([ax1 ax2 ax3 ax4 ax5],'x');

% ---- save figure + summary ----
if ~isfolder(fullfile(root,'results')), mkdir(fullfile(root,'results')); end
for ax = [ax1 ax2 ax3 ax4 ax5], ax.Toolbar.Visible = 'off'; end
png = fullfile(root,'results',sprintf('balancing_%s%s.png',tag,string(datetime('now'),'yyyyMMdd_HHmmss')));
exportgraphics(fig,png,'Resolution',130);

i1 = find(spread < Bal_threshold, 1);
fprintf('\nFinal SOC        : %s  (spread %.2f %%)\n', mat2str(SOC(end,:),3), spread(end)*100);
if ~isempty(i1), fprintf('Spread < %.1f %% at: %.1f min\n', Bal_threshold*100, t(i1)); end
fprintf('Bleed ON time    : %s min (Cell 1..3)\n', mat2str(sum(diff(tc).*CMD(1:end-1,:)),3));
fprintf('Bleed energy     : %.0f J  (%.2f Wh)\n', E_bleed, E_bleed/3600);
fprintf('Figure saved to  : %s\n', png);
clear overrides tag   % so the next run starts from the params file again
