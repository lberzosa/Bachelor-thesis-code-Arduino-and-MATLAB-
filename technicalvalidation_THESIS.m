% =========================================================================
% TECHNICAL VALIDATION
% =========================================================================
clear all; close all; clc;
fprintf('=== FATIGUE ANALYSIS ===\n\n');


userDir = char(java.lang.System.getProperty('user.home'));
carpeta = fullfile(userDir, 'Documents', 'EMG_DATA');


name = 'EMG_SubjectFem1_Group2.mat';
ruta_completa = fullfile(carpeta, name);

if exist(ruta_completa, 'file')
    load(ruta_completa);
else
    error('Nothing was found: %s', name);
end


total_real_time = datos(:,1);
emg_raw_total = datos(:,2);


fs = 500; 
skip_samples = round(2.5 * fs); 
emg_raw = emg_raw_total(skip_samples:end);
time = total_real_time(skip_samples:end);


[b, a] = butter(4, [20, 200]/(fs/2), 'bandpass');
emg_bp = filtfilt(b, a, emg_raw);

wo = 50/(fs/2); bw = wo/50;
[bn, an] = iirnotch(wo, bw);
emg_filt = filtfilt(bn, an, emg_bp);


window = round(1.0 * fs); 
step = round(0.5 * fs);
num_epochs = floor((length(emg_filt) - window) / step) + 1;

MNF = zeros(num_epochs, 1);
RMS = zeros(num_epochs, 1);
FD = zeros(num_epochs, 1);
t_axis = zeros(num_epochs, 1);

for e = 1:num_epochs
    idx_vent = (e-1)*step + (1:window);
    epoch = emg_filt(idx_vent);
    t_axis(e) = mean(time(idx_vent));
    
    
    N = length(epoch);
    xdft = fft(epoch);
    psd = (1/(fs*N)) * abs(xdft(1:N/2+1)).^2;
    freqs = 0:fs/N:fs/2;
    
    
    MNF(e) = sum(freqs .* psd') / sum(psd);
    
    
    RMS(e) = sqrt(mean(epoch.^2));
    
    
    FD(e) = hfd_calculo(epoch, 6);
end


p_mnf = polyfit(t_axis, MNF, 1);
p_rms = polyfit(t_axis, RMS, 1);
rms_ini = polyval(p_rms, t_axis(1));
rms_fin = polyval(p_rms, t_axis(end));
rms_increase = ((rms_fin - rms_ini) / rms_ini) * 100; %

p_fd = polyfit(t_axis, FD, 1);
time_till_fatigue = info.tiempo_total; %


VariableNames = {'Subject', 'Age', 'Increase RMS', 'MNF slope', 'FD slope', 'Time to Fatigue (s)'};
Resultados_Fila = {info.nombre, info.edad, rms_increase, p_mnf(1), p_fd(1), time_till_fatigue};
T = cell2table(Resultados_Fila, 'VariableNames', VariableNames);

fprintf('\n=== TABLE: %s ===\n', info.nombre);
disp(T);

% 
figure('Color', 'w', 'Name', ['Resultados - ', info.nombre], 'Position', [100 100 800 800]);

subplot(3,1,1);
plot(t_axis, MNF, 'r', 'LineWidth', 1.5); hold on;
plot(t_axis, polyval(p_mnf, t_axis), 'k--');
title('Frequency analysis (MNF Shift)'); ylabel('Hz'); grid on;

subplot(3,1,2);
plot(t_axis, RMS, 'm', 'LineWidth', 1.5); hold on;
plot(t_axis, polyval(p_rms, t_axis), 'k--');
title(['Amplitude analysis (RMS Trend: ', num2str(rms_increase, '%.1f'), '%)']); ylabel('RMS'); grid on;

subplot(3,1,3);
plot(t_axis, FD, 'g', 'LineWidth', 1.5); hold on;
plot(t_axis, polyval(p_fd, t_axis), 'k--');
title(['Fractal Dimension: ', num2str(p_fd(1), '%.5f'), ')']); 
ylabel('FD'); xlabel('Time (s)'); grid on;


function hfd = hfd_calculo(X, kmax)
    N = length(X); L = zeros(1, kmax);
    for k = 1:kmax
        Lk = zeros(1, k);
        for m = 1:k
            idx = m:k:N; n_val = length(idx);
            if n_val > 1
                L_mk = sum(abs(diff(X(idx))));
                norm_factor = (N - 1) / (floor((N - m) / k) * k);
                Lk(m) = (L_mk * norm_factor) / k;
            end
        end
        L(k) = mean(Lk);
    end
    coeffs = polyfit(log(1./(1:kmax)), log(L), 1);
    hfd = coeffs(1);
end