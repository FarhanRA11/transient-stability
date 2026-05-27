%% ANALISIS PARAMETER FREKUENSI DAN SUDUT ROTOR
% =========================================================
% Menghitung:
% 1. Overshoot frekuensi
% 2. RoCoF
% 3. Settling time sudut rotor (2%)
% 4. Damping ratio sudut rotor
% 5. Frekuensi osilasi sudut rotor
%
% METODE DAMPING:
%   PSD -> bandpass -> Hilbert envelope
%   -> exponential decay fitting
%
% COCOK UNTUK:
%   - electromechanical oscillation
%   - power system ringdown
%   - multi-mode oscillation
%
% =========================================================

clc;
close all

%% ========================================================
% 1. VALIDASI INPUT
% ========================================================

if ~exist('freq','var') || ~exist('delta','var')

%% ========================================================
% 6b. MAKSIMUM DEVIASI SUDUT ROTOR RELATIF TERHADAP NILAI AWAL
%% ========================================================

fprintf('4. MAKSIMUM DEVIASI SUDUT ROTOR (relatif terhadap nilai awal)\n');
fprintf('----------------------------------------------------\n');

% gunakan window rotor (time_rotor, delta_win) jika tersedia
if exist('delta_win','var')
    data_for_dev = delta_win;
    time_for_dev = time_rotor;
else
    data_for_dev = deltaData;
    time_for_dev = time;
end

[n_dev_samples, n_dev_channels] = size(data_for_dev);
max_dev = zeros(1,n_dev_channels);
max_dev_time = nan(1,n_dev_channels);

for i = 1:n_dev_channels
    init_val = data_for_dev(1,i);
    dev = abs(data_for_dev(:,i) - init_val);
    [max_dev(i), idx] = max(dev);
    max_dev_time(i) = time_for_dev(idx);

    fprintf('Channel %d\n', i);
    fprintf('  Initial Value   : %.8f rad\n', init_val);
    fprintf('  Max Deviation   : %.8f rad\n', max_dev(i));
    fprintf('  Time of Max Dev : %.6f s\n\n', max_dev_time(i));
end

    error('Variabel freq dan delta harus ada di workspace.');
end

if ~isa(freq,'timeseries') || ~isa(delta,'timeseries')
    error('freq dan delta harus bertipe timeseries.');
end

%% ========================================================
% 2. EXTRACT DATA
% ========================================================

time      = freq.Time(:);
freqData  = freq.Data;
deltaData = delta.Data;

if ~isequal(time, delta.Time(:))
    error('Time vector freq dan delta tidak sama.');
end

[num_samples, num_channels] = size(freqData);

fprintf('Jumlah sample  : %d\n', num_samples);
fprintf('Jumlah channel : %d\n\n', num_channels);

%% ========================================================
% 3. WINDOW ANALYSIS
% ========================================================

t_start_analysis = 1.1;
t_end_analysis   = 20;

idx_start = find(time >= t_start_analysis, 1, 'first');
idx_end   = find(time <= t_end_analysis, 1, 'last');

if isempty(idx_start)
    error('t_start_analysis berada di luar range waktu.');
end

if isempty(idx_end)
    idx_end = length(time);
end

% Window frekuensi
time_freq = time(idx_start:end);
freq_win  = freqData(idx_start:end,:);

% Window rotor
time_rotor = time(idx_start:idx_end);
delta_win  = deltaData(idx_start:idx_end,:);

%% ========================================================
% 4. OVERSHOOT FREKUENSI
% ========================================================

fprintf('====================================================\n');
fprintf('ANALISIS FREKUENSI\n');
fprintf('====================================================\n\n');

fprintf('1. OVERSHOOT FREKUENSI\n');
fprintf('----------------------------------------------------\n');

freq_max = zeros(1,num_channels);
freq_min = zeros(1,num_channels);

for i = 1:num_channels

    freq_max(i) = max(freq_win(:,i)) - 50;
    freq_min(i) = min(freq_win(:,i)) - 50;

    fprintf('Channel %d\n',i);
    fprintf('  Max Frequency : %.6f Hz\n',freq_max(i));
    fprintf('  Min Frequency : %.6f Hz\n',freq_min(i));
    fprintf('  Range         : %.6f Hz\n\n',...
        freq_max(i)-freq_min(i));

end

%% ========================================================
% 5. ROCOF
% ========================================================

fprintf('2. RoCoF (Rate of Change of Frequency)\n');
fprintf('----------------------------------------------------\n');

dt = diff(time_freq);

rocof = diff(freq_win,1,1)./dt;

rocof_max_pos = zeros(1,num_channels);
rocof_max_neg = zeros(1,num_channels);

for i = 1:num_channels

    rocof_max_pos(i) = max(rocof(:,i));
    rocof_max_neg(i) = min(rocof(:,i));

    fprintf('Channel %d\n',i);

    fprintf('  Max Positive RoCoF : %.6f Hz/s\n',...
        rocof_max_pos(i));

    fprintf('  Max Negative RoCoF : %.6f Hz/s\n',...
        rocof_max_neg(i));

    fprintf('  Max Magnitude      : %.6f Hz/s\n\n',...
        max(abs([rocof_max_pos(i),rocof_max_neg(i)])));

end

%% ========================================================
% 6. SETTLING TIME
% ========================================================

fprintf('====================================================\n');
fprintf('ANALISIS SUDUT ROTOR\n');
fprintf('====================================================\n\n');

fprintf('3. SETTLING TIME (2%% CRITERION)\n');
fprintf('----------------------------------------------------\n');

settling_time = nan(1,num_channels);

for i = 1:num_channels

    signal = deltaData(:,i);

    ref = signal(1);

    tol = 0.02 * abs(ref);

    upper = ref + tol;
    lower = ref - tol;

    out_idx = find(signal > upper | signal < lower);

    if isempty(out_idx)

        settling_time(i) = time(1);

    elseif out_idx(end) >= length(time)

        settling_time(i) = NaN;

    else

        settling_time(i) = time(out_idx(end)+1);

    end

    fprintf('Channel %d\n',i);

    fprintf('  Reference Value : %.8f rad\n',ref);
    fprintf('  2%% Band         : +/- %.8f rad\n',tol);

    if isnan(settling_time(i))

        fprintf('  Settling Time   : NOT SETTLED\n\n');

    else

        fprintf('  Settling Time   : %.6f s\n\n',...
            settling_time(i));

    end

end

%% ========================================================
% 6b. MAKSIMUM DEVIASI ABSOLUT SUDUT ROTOR (Nilai Awal)
% ========================================================

fprintf('4. MAKSIMUM DEVIASI ABSOLUT SUDUT ROTOR (dari nilai awal)\n');
fprintf('----------------------------------------------------\n');

max_abs_dev = zeros(1,num_channels);
max_abs_dev_time = nan(1,num_channels);
max_abs_dev_idx = nan(1,num_channels);

for i = 1:num_channels
    
    initial_angle = deltaData(1,i);
    absolute_deviation = abs(deltaData(:,i) - initial_angle);
    
    [max_abs_dev(i), idx] = max(absolute_deviation);
    max_abs_dev_time(i) = time(idx);
    max_abs_dev_idx(i) = idx;
    
    fprintf('Gen %d:\n', i);
    fprintf('  Initial Angle      : %.8f rad (%.4f deg)\n', ...
        initial_angle, rad2deg(initial_angle));
    fprintf('  Max Abs Deviation   : %.8f rad (%.4f deg)\n', ...
        max_abs_dev(i), rad2deg(max_abs_dev(i)));
    fprintf('  Time of Max Dev     : %.6f s\n\n', max_abs_dev_time(i));
    
end

fprintf('RINGKASAN GEN 1-3:\n');
fprintf('----------------------------------------------------\n');
for i = 1:min(3, num_channels)
    fprintf('Gen %d - Max Abs Dev: %.8f rad (%.4f deg) at t = %.6f s\n', ...
        i, max_abs_dev(i), rad2deg(max_abs_dev(i)), max_abs_dev_time(i));
end
fprintf('\n');

%% ========================================================
% 7. SUMMARY
% ========================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('RINGKASAN HASIL ANALISIS\n');
fprintf('====================================================\n\n');

fprintf('FREKUENSI\n');
fprintf('----------------------------------------------------\n');

fprintf('Dev Overshoot Max (Hz)   : ');
fprintf('%10.5f ',freq_max);
fprintf('\n');

fprintf('Dev Overshoot Min (Hz)   : ');
fprintf('%10.5f ',freq_min);
fprintf('\n');

fprintf('RoCoF Max Pos (Hz/s) : ');
fprintf('%10.5f ',rocof_max_pos);
fprintf('\n');

fprintf('RoCoF Max Neg (Hz/s) : ');
fprintf('%10.5f ',rocof_max_neg);
fprintf('\n\n');

fprintf('SUDUT ROTOR\n');
fprintf('----------------------------------------------------\n');

fprintf('Settling Time (s)    : ');
fprintf('%10.5f ',settling_time);
fprintf('\n');

fprintf('Max Abs Deviation (rad) : ');
fprintf('%10.8f ',max_abs_dev);
fprintf('\n');

fprintf('Max Abs Deviation (deg) : ');
fprintf('%10.4f ',rad2deg(max_abs_dev));
fprintf('\n\n');