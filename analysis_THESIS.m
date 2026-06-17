%% ========================================================================
%% MULTIVARIABLE ANALYSIS
%% ========================================================================
clear all; close all; clc;

userDir = char(java.lang.System.getProperty('user.home'));
carpeta = fullfile(userDir, 'Documents', 'EMG_DATA');
archivos = dir(fullfile(carpeta, '*.mat'));

if isempty(archivos)
    error('No se encontraron archivos .mat en la carpeta especificada: %s', carpeta); 
end

res_table = table(); 

for i = 1:length(archivos)
    load(fullfile(carpeta, archivos(i).name)); 
    
    t = datos(:,1);
    raw_signal = datos(:,2);
    
    
    diff_t = diff(t);
    fs = round(1 / mean(diff_t)); 
    
    
    f_corte_sup = 450;
    if f_corte_sup >= (fs/2)
        f_corte_sup = floor((fs/2) - 5); 
    end
    
    
    [b, a] = butter(4, [20 f_corte_sup]/(fs/2), 'bandpass');
    emg_filt = filtfilt(b, a, raw_signal);
    
    
    win_len = fs; 
    step = round(win_len / 2); 
    n_wins = floor((length(emg_filt) - win_len) / step) + 1;
    
    
    rms_v = zeros(n_wins, 1); 
    mav_v = zeros(n_wins, 1); 
    mnf_v = zeros(n_wins, 1); 
    mdf_v = zeros(n_wins, 1); 
    fd_v  = zeros(n_wins, 1);
    
    for w = 1:n_wins
        idx = (1:win_len) + (w-1)*step;
        seg = emg_filt(idx);
        
        
        rms_v(w) = rms(seg);
        mav_v(w) = mean(abs(seg));
        
        
        [pxx, f_ax] = periodogram(seg, rectwin(win_len), win_len, fs);
        
        
        mnf_v(w) = sum(f_ax .* pxx) / sum(pxx);
        
        
        cumsum_pow = cumsum(pxx);
        idx_mdf = find(cumsum_pow >= sum(pxx)/2, 1);
        mdf_v(w) = f_ax(idx_mdf);
        
        
        fd_v(w) = higuchi_fd(seg, 10);
    end
    
    
    res_table.Grupo(i) = info.grupo;
    res_table.Genero{i} = info.genero;
    res_table.Time(i) = info.tiempo_total;
   
    
    
    p_rms = polyfit(1:length(rms_v), rms_v, 1);
    rms_ini_trend = polyval(p_rms, 1);
    rms_fin_trend = polyval(p_rms, length(rms_v));
    res_table.RMS_Incr(i) = ((rms_fin_trend - rms_ini_trend) / rms_ini_trend) * 100;
    
   
    p_mav = polyfit(1:length(mav_v), mav_v, 1);
    mav_ini_trend = polyval(p_mav, 1);
    mav_fin_trend = polyval(p_mav, length(mav_v));
    res_table.MAV_Incr(i) = ((mav_fin_trend - mav_ini_trend) / mav_ini_trend) * 100;
    
    
    p_mnf = polyfit(1:length(mnf_v), mnf_v, 1);
    res_table.MNF_Slope(i) = p_mnf(1);
    
    p_mdf = polyfit(1:length(mdf_v), mdf_v, 1);
    res_table.MDF_Slope(i) = p_mdf(1);
    
    p_fd = polyfit(1:length(fd_v), fd_v, 1);
    res_table.FD_Slope(i) = p_fd(1);
    
    
    sujeto(i).rms = interp1(1:length(rms_v), rms_v/rms_v(1), linspace(1,length(rms_v),100));
    sujeto(i).mnf = interp1(1:length(mnf_v), mnf_v/mnf_v(1), linspace(1,length(mnf_v),100));
    sujeto(i).fd  = interp1(1:length(fd_v), fd_v/fd_v(1), linspace(1,length(fd_v),100));
end


nombres_g = {'G1 (18-34)', 'G2 (35-54)', 'G3 (55-75)'};
gen_list = {'Masc', 'Fem'};
colores_edad = [0 0.447 0.741;  ...
                0.850 0.325 0.098; ... 
                0.466 0.674 0.188];    
            
titulos = {'Amplitude (RMS)', 'Frequency (MNF)', 'Complexity (FD)'};
campos = {'rms', 'mnf', 'fd'};

for p = 1:3
    figure('Name', titulos{p}, 'Color', 'w', 'Position', [100 100 800 500]);
    hold on; grid on;
    title(['Evolution of ', titulos{p}, ' by gender and group'], 'FontSize', 14);
    
    for g = 1:3
        for gn = 1:2
            
            idx = (res_table.Grupo == g) & strcmp(res_table.Genero, gen_list{gn});
            if any(idx)
                data_group = vertcat(sujeto(idx).(campos{p}));
                mean_line = mean(data_group, 1);
                mean_line = movmean(mean_line, 5); 
                x_axis = linspace(0, 100, 100);
                
                if gn == 1, estilo = '-'; else, estilo = '--'; end
                
                plot(x_axis, mean_line, estilo, 'LineWidth', 2.5, ...
                    'Color', colores_edad(g,:), ...
                    'DisplayName', sprintf('%s %s', nombres_g{g}, gen_list{gn}));
            end
        end
    end
    xlabel('% Exercise duration', 'FontSize', 12);
    ylabel('Normalized value (relative to the beginning)', 'FontSize', 12);
    legend('Location', 'northeastoutside', 'FontSize', 10);
    if p > 1, ylim([0.7 1.3]); end 
end


figure('Name', 'Correlation Matrix');
d_corr = [res_table.Time, res_table.RMS_Incr, res_table.MAV_Incr, ...
          res_table.MNF_Slope, res_table.MDF_Slope, res_table.FD_Slope];
      
labels = {'Time', 'RMS%', 'MAV%', 'MNF Slope', 'MDF Slope', 'FD Slope'};
heatmap(labels, labels, corr(d_corr));
title('Correlation of Fatigue Indicators (N=30)');


disp(' ');
disp('--- RESULTS SUMMARY ---');
res_table.Properties.VariableNames{'Grupo'} = 'Group';
res_table.Properties.VariableNames{'Genero'} = 'Gender';
disp(groupsummary(res_table, {'Group', 'Gender'}, 'mean'));

%% ========================================================================
%% Auxiliar functions
%% ========================================================================
function fd = higuchi_fd(x, kmax)
    
    N = length(x); 
    L = zeros(1, kmax);
    for k = 1:kmax
        Lk = 0;
        for m = 1:k
            n_max = floor((N - m) / k);
            norm_fact = (N - 1) / (n_max * k);
            temp_L = sum(abs(diff(x(m:k:m+n_max*k))));
            Lk = Lk + (temp_L * norm_fact) / k;
        end
        L(k) = Lk / m;
    end
    % Ajuste lineal sobre la escala logarítmica
    p = polyfit(log(1./(1:kmax)), log(L), 1);
    fd = p(1);
end