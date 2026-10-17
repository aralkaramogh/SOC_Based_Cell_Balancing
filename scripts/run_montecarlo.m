%% run_montecarlo.m  -  Monte Carlo over cell-to-cell variation of the 3S passive-balancing pack
% Each run = one "random pack": capacities, R0 and starting SOC are drawn from
% normal distributions, the SAME model is simulated, metrics are collected.
% Existing model/scripts are NOT changed. Set N before calling to override.
%
%   N = 20; run_montecarlo      % quick pilot
%   run_montecarlo              % full run (N = 200)

mdl  = 'pack3s_passive_balancing';
root = fileparts(fileparts(mfilename('fullpath')));
params_pack3s;                                   % gives Cap, SOC0, R_bleed ...

if ~exist('N','var'),    N = 100; end
if ~exist('seed','var'), seed = 42; end
sig_cap = 0.02;      % 2 % std of capacity  (literature: mostly within +-5 % ~ 2.5 sigma)
sig_r0  = 0.10;      % 10 % std of R0
sig_soc = 0.02;      % 2 SOC-points std of starting SOC around the baseline
SOC_base = SOC0;     % [0.80 0.75 0.75]

%% ---- 1. SAMPLING --------------------------------------------------------
rng(seed);                                        % same seed -> same 200 packs every time
CapS = 2.5 * (1 + sig_cap*randn(N,3));            % Ah     ~ N(2.5, (0.05)^2)
R0S  = max(0.5, 1 + sig_r0*randn(N,3));           % scale  ~ N(1, 0.1^2), floored at 0.5
SOCS = min(0.95, max(0.30, SOC_base + sig_soc*randn(N,3)));   % clipped to a sane range

%% ---- 2. BUILD N SIMULATION INPUTS --------------------------------------
load_system(mdl);
for i = N:-1:1
    in(i) = Simulink.SimulationInput(mdl);
    in(i) = in(i).setVariable('Cap',      CapS(i,:));
    in(i) = in(i).setVariable('R0_scale', R0S(i,:));
    in(i) = in(i).setVariable('SOC0',     SOCS(i,:));
end

%% ---- 3. RUN IN PARALLEL -------------------------------------------------
tic;
out = parsim(in, 'ShowProgress','on', 'TransferBaseWorkspaceVariables','on', ...
             'UseFastRestart','off', 'StopOnError','off');
fprintf('%d simulations in %.1f min\n', N, toc/60);

%% ---- 4. METRICS ---------------------------------------------------------
M = nan(N,9);  % [t_bal_min  peak_spread_pct  final_spread_pct  bleedmin1 2 3  E_J  E_pct  usableAh]
for i = 1:N
    if ~isempty(out(i).ErrorMessage), continue; end
    L   = out(i).logsout;
    soc = L.getElement('SOC').Values;     t = soc.Time/60;   SOC = squeeze(soc.Data);
    vc  = L.getElement('Vcell').Values;   V = squeeze(vc.Data);
    cmd = L.getElement('BleedCmd').Values; CMD = squeeze(cmd.Data);
    if size(SOC,1)==3 && size(SOC,2)~=3, SOC = SOC.'; end
    if size(V,1)==3   && size(V,2)~=3,   V   = V.';   end
    if size(CMD,1)==3 && size(CMD,2)~=3, CMD = CMD.'; end
    sp = (max(SOC,[],2) - min(SOC,[],2))*100;
    k  = find(sp < 1, 1);    if isempty(k), tb = NaN; else, tb = t(k); end
    [tu,iu] = unique(vc.Time);
    Vc = interp1(tu, V(iu,:), cmd.Time, 'previous','extrap');
    dtc = diff(cmd.Time);
    E  = sum(sum(Vc(1:end-1,:).^2 .* CMD(1:end-1,:),2) .* dtc) / R_bleed;     % J
    bm = (sum(CMD(1:end-1,:) .* dtc, 1)) / 60;                                % min per cell
    Epack = min(CapS(i,:)) * 11.1;                                            % Wh (nominal)
    M(i,:) = [tb, max(sp), sp(end), bm, E, E/3600/Epack*100, min(CapS(i,:))];
end
ok = ~isnan(M(:,3));
fprintf('%d of %d runs valid\n', nnz(ok), N);

%% ---- 5. STATISTICS ------------------------------------------------------
names = {'Time to spread<1% [min]','Peak spread [%]','Final spread [%]', ...
         'Bleed time C1 [min]','Bleed time C2 [min]','Bleed time C3 [min]', ...
         'Bleed energy [J]','Bleed energy [% of pack]','Usable capacity [Ah]'};
T = table(names', mean(M(ok,:),'omitnan')', std(M(ok,:),'omitnan')', ...
          min(M(ok,:))', prctile(M(ok,:),95)', max(M(ok,:))', ...
          'VariableNames',{'Metric','Mean','Std','Min','P95','Max'});
disp(T);

%% ---- 6. FIGURES + SAVE --------------------------------------------------
od = fullfile(root,'results','montecarlo'); if ~exist(od,'dir'), mkdir(od); end
stamp = datestr(now,'yyyymmdd_HHMMSS');
writetable(T, fullfile(od,['mc_summary_' stamp '.csv']));
save(fullfile(od,['mc_data_' stamp '.mat']),'CapS','R0S','SOCS','M','names','seed','N');

f1 = figure('Color','w','Position',[80 80 1100 700]);
tl = tiledlayout(f1,2,3,'TileSpacing','compact');
title(tl, sprintf('Monte Carlo: %d random packs (\\sigma_{cap}=%g%%, \\sigma_{R0}=%g%%, \\sigma_{SOC0}=%g pts)', N, sig_cap*100, sig_r0*100, sig_soc*100));
sel = [1 2 3 7 8 9];
for j = 1:6
    nexttile; histogram(M(ok,sel(j)), 20, 'FaceColor',[0.2 0.4 0.7]); grid on;
    xline(mean(M(ok,sel(j)),'omitnan'),'r','LineWidth',1.5);
    xlabel(names{sel(j)}); ylabel('count');
end
exportgraphics(f1, fullfile(od,['mc_histograms_' stamp '.png']), 'Resolution',150);

f2 = figure('Color','w','Position',[80 80 1000 420]);
tl2 = tiledlayout(f2,1,3,'TileSpacing','compact');
title(tl2,'What drives the result? (each dot = one random pack)');
capSpread = (max(CapS,[],2)-min(CapS,[],2))./mean(CapS,2)*100;
r0Spread  = (max(R0S,[],2)-min(R0S,[],2));
socSpread = (max(SOCS,[],2)-min(SOCS,[],2))*100;
nexttile; scatter(socSpread(ok), M(ok,1), 20, 'filled'); grid on; xlabel('initial SOC spread [pts]'); ylabel('time to <1 % [min]');
nexttile; scatter(capSpread(ok), M(ok,2), 20, 'filled'); grid on; xlabel('capacity spread [%]'); ylabel('peak spread [%]');
nexttile; scatter(capSpread(ok), M(ok,8), 20, 'filled'); grid on; xlabel('capacity spread [%]'); ylabel('bleed energy [% of pack]');
exportgraphics(f2, fullfile(od,['mc_drivers_' stamp '.png']), 'Resolution',150);

c = corrcoef([socSpread(ok) capSpread(ok) r0Spread(ok) M(ok,[1 2 3 8])]);
fprintf('\nCorrelation with [t_bal, peak spread, final spread, bleed %%]:\n');
disp(array2table(c(1:3,4:7),'RowNames',{'SOC0 spread','Cap spread','R0 spread'}, ...
     'VariableNames',{'t_bal','peak','final','bleedPct'}));
clear N seed
