% =========================================================================
% EMG DATA ADQUISITION
% =========================================================================
clear all; close all; clc;

puerto = 'COM3'; 
baudRate = 115200;

userDir = char(java.lang.System.getProperty('user.home'));
carpeta = fullfile(userDir, 'Documents', 'EMG_DATA');
if ~exist(carpeta, 'dir'), mkdir(carpeta); end

genero = menu('Gender:', 'Male', 'Female');
gen_str = {'Masc', 'Fem'};
grupo_menu = menu('Select group:', 'Group 1 (18-34)', 'Group 2 (35-54)', 'Group 3 (55-75)');
sujeto_num = input('Subject Number (1 to 5): ');
edad = input('Actual Age: ');

nombre_sujeto = sprintf('Subject%s%d_Group%d', gen_str{genero}, sujeto_num, grupo_menu);
archivo = fullfile(carpeta, sprintf('EMG_%s.mat', nombre_sujeto));

try
    s = serialport(puerto, baudRate);
    configureTerminator(s, "LF");
    flush(s);
catch
    error('The port could not be connected %s. Verify the wire.', puerto);
end

fprintf('\n--- PHASE 1: CALIBRATION ---\n');
fprintf('Keep the arm relaxed during 5 seconds...\n');

calib_data = [];
t_calib = tic;
while toc(t_calib) < 5
    if s.NumBytesAvailable > 0
        linea = readline(s);
        valor = str2double(strtrim(linea));
        if ~isnan(valor), calib_data = [calib_data; valor]; end
    end
end

offset_base = mean(calib_data); 
if isnan(offset_base), offset_base = 0; end 
fprintf('Calibration completed (Offset: %.2f).\n', offset_base);

flush(s); 
fprintf('\n--- PHASE 2: RECORDING ---\n');
fprintf('Start the exercise NOW!\n');

fig = uifigure('Name','Recording','Position',[500 500 300 150]);
continuar = true;
uibutton(fig, 'push', 'Text', 'STOP AND SAVE', ...
    'Position', [75 60 150 40], ...
    'ButtonPushedFcn', @(btn,event) assignin('base', 'continuar', false));

datos = []; 
tiempo_inicio = tic; 

while continuar
    if s.NumBytesAvailable > 0
        linea = readline(s);
        valor = str2double(strtrim(linea));
        if ~isnan(valor)
            datos = [datos; toc(tiempo_inicio), valor - offset_base]; 
        end
    end
    drawnow; 
end

if ~isempty(datos)
    info.nombre = nombre_sujeto;
    info.edad = edad;
    info.genero = gen_str{genero};
    info.grupo = grupo_menu;
    info.offset_aplicado = offset_base;
    info.fecha = datestr(now);
    info.tiempo_total = datos(end, 1); 
    
    save(archivo, 'datos', 'info');
    fprintf('\nSUCCESS! Recording saved: %s\n', nombre_sujeto);
    fprintf('Samples captured: %d | Time: %.1f s\n', size(datos,1), info.tiempo_total);
else
    fprintf('\nError: No data was captured.\n');
end

delete(fig);
clear s;