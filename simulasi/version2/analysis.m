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
% 7. DAMPED FREQUENCY + DAMPING RATIO
% ========================================================

fprintf('4. DAMPED FREQUENCY + DAMPING RATIO\n');
fprintf('----------------------------------------------------\n');

damping_ratio    = nan(num_channels,1);
oscillation_freq = nan(num_channels,1);

for i = 1:num_channels

    fprintf('Channel %d\n',i);

    % =====================================================
    % EXTRACT SIGNAL
    % =====================================================

    t = time_rotor(:);
    x_raw = delta_win(:,i);

    % =====================================================
    % REMOVE STEADY STATE
    % =====================================================

    Nss = max(10, round(0.05*length(x_raw)));

    x_ref = mean(x_raw(end-Nss+1:end));

    x = x_raw - x_ref;

    % =====================================================
    % SAMPLING FREQUENCY
    % =====================================================

    fs_original = 1 / mean(diff(t));

    % =====================================================
    % DOWNSAMPLE
    % =====================================================

    target_fs = 200;   % Hz

    decim = max(1, round(fs_original/target_fs));

    x = decimate(x,decim);
    t = decimate(t,decim);

    fs = 1 / mean(diff(t));

    fprintf('  Sampling fs : %.2f Hz\n',fs);

    % =====================================================
    % PSD - CARI FREKUENSI DOMINAN
    % =====================================================

    [Pxx,F] = pwelch(x,[],[],[],fs);

    valid = F > 0.05 & F < 5;

    Fv  = F(valid);
    Pvv = Pxx(valid);

    if isempty(Pvv) || all(Pvv <= 0)

        fprintf('  Invalid spectrum\n\n');
        continue;

    end

    % =====================================================
    % CARI PUNCAK ELECTROMECHANICAL (0.5-3 Hz)
    % =====================================================

    valid_em = Fv >= 0.5 & Fv <= 3.0;
    Fv_em = Fv(valid_em);
    Pvv_em = Pvv(valid_em);

    if ~isempty(Pvv_em)

        [~,idxMax] = max(Pvv_em);
        f_damped = Fv_em(idxMax);

    else

        % Fallback ke puncak dominan keseluruhan
        [~,idxMax] = max(Pvv);
        f_damped = Fv(idxMax);

    end

    oscillation_freq(i) = f_damped;

    % =====================================================
    % HITUNG DAMPING RATIO
    % =====================================================

    omega_d = 2*pi*f_damped;

    Ts = settling_time(i);

    % Rumus: zeta = 4 / sqrt((wd*Ts)^2 + 16)

    if isnan(Ts) || Ts <= 0

        damping_ratio(i) = NaN;

    else

        zeta = 4 / sqrt((omega_d*Ts)^2 + 16);

        if ~isfinite(zeta) || zeta < 0 || zeta > 1

            damping_ratio(i) = NaN;

        else

            damping_ratio(i) = 100*zeta;

        end

    end

    % =====================================================
    % DISPLAY
    % =====================================================

    fprintf('  Damped Frequency : %.6f Hz\n',f_damped);

    fprintf('  Omega_d          : %.6f rad/s\n',omega_d);

    fprintf('  Settling Time    : %.6f s\n',Ts);

    fprintf('  Damping Ratio    : %.4f %%\n\n',...
        damping_ratio(i));

end

%% ========================================================
% 8. SUMMARY
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
fprintf('\n\n');

fprintf('Damping Ratio (%%)\n');

fprintf('  ');

fprintf('%10.4f ',damping_ratio);

fprintf('\n\n');

fprintf('Oscillation Frequency (Hz)\n');

fprintf('  ');

fprintf('%10.5f ',oscillation_freq);

fprintf('\n');

fprintf('====================================================\n');
fprintf('ANALISIS SELESAI\n');
fprintf('====================================================\n');



%% ========================================================
% 4. FFT ANALYSIS DELTA
% ========================================================

% Sampling time
Ts = mean(diff(time_rotor));   % detik
Fs = 1/Ts;                     % Hz

% Jumlah sample
N = length(time_rotor);

% Frequency axis
f = (0:N-1)*(Fs/N);

% Half spectrum
half_idx = 1:floor(N/2);

figure;
hold on;

% Warna plot
colors = {'g', 'b'};

for ch = 1:2

    % Ambil sinyal
    x = delta_win(:,ch);

    % Hilangkan DC component
    x = x - mean(x);

    % FFT
    X = fft(x);

    % Magnitude spectrum
    P2 = abs(X/N);
    P1 = P2(half_idx);

    % Single-sided correction
    P1(2:end-1) = 2*P1(2:end-1);

    % Plot
    plot(f(half_idx), P1, ...
        'Color', colors{ch}, ...
        'LineWidth', 1.5)

    % Frekuensi dominan
    [~, idx_peak] = max(P1);
    dominant_freq = f(idx_peak);

    fprintf('Channel %d dominant frequency = %.4f Hz\n', ...
            ch, dominant_freq);

end

grid on;
xlim([0 5])

xlabel('Frequency (Hz)')
ylabel('Magnitude')

title('FFT Delta Channel 1 dan 2')

legend('g1', 'g2')