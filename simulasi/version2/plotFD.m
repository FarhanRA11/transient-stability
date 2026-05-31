close all

time      = freq.Time(:);
freqData  = freq.Data;
deltaData = delta.Data;

if ~isequal(time, delta.Time(:))
    error('Time vector freq dan delta tidak sama.');
end

[num_samples, num_channels] = size(freqData);

fprintf('Jumlah sample  : %d\n', num_samples);
fprintf('Jumlah channel : %d\n\n', num_channels);

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

%% Warna plot
colors = {'g', 'b', 'r'};

%% plot kecepatan rotor

figure;
hold on;

% Hitung steady state untuk setiap channel (t > 1.1s)
time_w = w{1}.Values.Time;
data_w = w{1}.Values.Data;
idx_ss = find(time_w > 1.1);
w_steady_state = data_w(idx_ss, :);

for ch = 1:3
    % Plot data
    plot(w{1}.Values.Time, w{1}.Values.Data(:, ch), ...
        'Color', colors{ch}, ...
        'LineWidth', 2.0)
    
    % Hitung steady state (rata-rata 10% terakhir dari data)
    num_ss_samples = max(1, round(0.1 * length(w_steady_state)));
    w_ss_value = mean(w_steady_state(end-num_ss_samples+1:end, ch));
    
    % Plot steady state line
    yline(w_ss_value, '--', 'Color', colors{ch}, 'LineWidth', 1.5, 'Alpha', 0.7);
end

% Tambahkan reference line 1.0 pu
yline(1.0, 'k--', 'LineWidth', 1.5, 'Alpha', 0.5);

grid on;
xlim([0 20])
ylim([0.98 1.02])
xlabel('Waktu (s)')
ylabel('ω (p.u.)')
title('Kecepatan Rotor Generator 1-3 (-- = Steady State untuk t > 1.1s)')
legend('G1', 'G2', 'G3', 'Location', 'best')


%% plot rocof

figure;
hold on;

for ch = 1:3

    % Plot
    plot(dfdt{1}.Values.Time, dfdt{1}.Values.Data(:, ch), ...
        'Color', colors{ch}, ...
        'LineWidth', 2.0)

end

grid on;
xlim([0 20])
ylim([-10 10])
xlabel('Waktu (s)')
ylabel('$\dot{f}$ (Hz/s)', 'Interpreter', 'latex')
title('RoCoF Generator 1-3')
legend('G1', 'G2', 'G3')


%% plot sudut

figure;
hold on;

for ch = 1:3

    % Plot
    plot(angle{1}.Values.Time, angle{1}.Values.Data(:, ch), ...
        'Color', colors{ch}, ...
        'LineWidth', 2.0)

end

grid on;
xlim([0 20])
ylim([-0.2 0.8])
xlabel('Waktu (s)')
ylabel('δ (rad)')
title('Sudut Rotor Generator 1-3')
legend('G1', 'G2', 'G3')


%% plot fft

figure;
hold on;

% Sampling time
Ts = mean(diff(time_rotor));   % detik
Fs = 1/Ts;                     % Hz

% Jumlah sample
N = length(time_rotor);

% Frequency axis
f = (0:N-1)*(Fs/N);

% Half spectrum
half_idx = 1:floor(N/2);

for ch = 1:3

    % Ambil sinyal
    x = freq_win(:,ch);
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
        'LineWidth', 2.0)

end

grid on;
xlim([0 5])
ylim([0 0.003])
xlabel('Frekuensi (Hz)')
ylabel('Magnitudo')
title('FFT Osilasi Kecepatan Rotor Generator 1-3')
legend('G1', 'G2', 'G3')


%% Perhitungan Karakteristik Sistem
fprintf('\n========================================\n')
fprintf('ANALISIS KARAKTERISTIK SISTEM (t > 1.1s)\n')
fprintf('========================================\n\n')

% Ambil data dari struktur
time_w     = w{1}.Values.Time;
data_w     = w{1}.Values.Data;
data_dfdt  = dfdt{1}.Values.Data;
data_angle = angle{1}.Values.Data;

% Ts = 1e-5 s (given)
Ts = 1e-5;

% Tentukan index untuk t > 1.1s
t_threshold = 1.1;
idx_analysis = find(time_w > t_threshold);

if isempty(idx_analysis)
    error('Tidak ada data untuk t > 1.1s');
end

% Extract data setelah t > 1.1s
time_analysis = time_w(idx_analysis);
w_analysis    = data_w(idx_analysis, :);
dfdt_analysis = data_dfdt(idx_analysis, :);
angle_analysis = data_angle(idx_analysis, :);

% Persiapan untuk setiap channel
channel_names = {'Generator 1', 'Generator 2', 'Generator 3'};

for ch = 1:3
    fprintf('--- %s ---\n', channel_names{ch})
    
    % Data channel tertentu
    w_ch     = w_analysis(:, ch);
    dfdt_ch  = dfdt_analysis(:, ch);
    angle_ch = angle_analysis(:, ch);
    
    % Hitung steady state (rata-rata 10% terakhir dari data)
    num_ss_samples = max(1, round(0.1 * length(w_ch)));
    w_ss = mean(w_ch(end-num_ss_samples+1:end));
    ss_error = w_ss - 1.0;  % Error terhadap 1.0 pu
    
    fprintf('   Steady State (t > 1.1s)            : %.6f pu\n', w_ss);
    fprintf('   Steady State Error (vs 1.0 pu)     : %.6f pu\n', ss_error);
    fprintf('\n');
    
    % ===== 1a. Simpangan tertinggi w > 1pu (relatif terhadap 1 pu) =====
    w_high = w_ch(w_ch > 1);
    if ~isempty(w_high)
        w_max_high = max(w_high);
        overshoot_1pu = w_max_high - 1.0;
        fprintf('1a. Max ω (>1pu) relatif 1.0 pu      : %.6f pu\n', overshoot_1pu);
    else
        fprintf('1a. Max ω (>1pu) relatif 1.0 pu      : Tidak ada\n');
    end
    
    % ===== 1b. Simpangan tertinggi w > 1pu (relatif terhadap steady state) =====
    w_high_ss = w_ch(w_ch > w_ss);
    if ~isempty(w_high_ss)
        w_max_high_ss = max(w_high_ss);
        overshoot_ss = w_max_high_ss - w_ss;
        fprintf('1b. Max ω (>ss) relatif ss           : %.6f pu\n', overshoot_ss);
    else
        fprintf('1b. Max ω (>ss) relatif ss           : Tidak ada\n');
    end
    
    % ===== 2a. Simpangan tertinggi w < 1pu (relatif terhadap 1 pu) =====
    w_low = w_ch(w_ch < 1);
    if ~isempty(w_low)
        w_min_low = min(w_low);
        undershoot_1pu = 1.0 - w_min_low;
        fprintf('2a. Min ω (<1pu) relatif 1.0 pu      : %.6f pu\n', undershoot_1pu);
    else
        fprintf('2a. Min ω (<1pu) relatif 1.0 pu      : Tidak ada\n');
    end
    
    % ===== 2b. Simpangan tertinggi w < 1pu (relatif terhadap steady state) =====
    w_low_ss = w_ch(w_ch < w_ss);
    if ~isempty(w_low_ss)
        w_min_low_ss = min(w_low_ss);
        undershoot_ss = w_ss - w_min_low_ss;
        fprintf('2b. Min ω (<ss) relatif ss           : %.6f pu\n', undershoot_ss);
    else
        fprintf('2b. Min ω (<ss) relatif ss           : Tidak ada\n');
    end
    
    % ===== 3. Settling time w (kriteria 2% dari steady state) =====
    tolerance = 0.005 * w_ss;  % 2% dari steady state
    
    % Tentukan error terhadap steady state
    error_w = abs(w_ch - w_ss);
    
    % Cari index pertama kali error keluar dari tolerance
    idx_outside = find(error_w > tolerance);
    
    if ~isempty(idx_outside)
        % Cari settling time: waktu terakhir error keluar dari tolerance
        idx_last_outside = idx_outside(end);
        settling_time = time_analysis(idx_last_outside);
        fprintf('3. Settling time w (0.5%% dari ss)      : %.6f s\n', settling_time);
    else
        fprintf('3. Settling time w (0.5%% dari ss)      : Data sudah dalam tolerance\n');
    end
    
    % ===== 4. Puncak positif RoCoF =====
    rocof_max = max(dfdt_ch);
    fprintf('4. Puncak positif RoCoF              : %.6f Hz/s\n', rocof_max);
    
    % ===== 5. Puncak negatif RoCoF =====
    rocof_min = min(dfdt_ch);
    fprintf('5. Puncak negatif RoCoF              : %.6f Hz/s\n', rocof_min);
    
    % ===== 6. Deviasi absolut tertinggi sudut rotor dari steady state =====
    % Asumsikan steady state adalah rata-rata 10% terakhir
    num_angle_ss = max(1, round(0.1 * length(angle_ch)));
    angle_ss = mean(angle_ch(end-num_angle_ss+1:end));
    angle_deviation = abs(angle_ch - angle_ss);
    angle_max_dev = max(angle_deviation);
    fprintf('6. Deviasi abs. sudut rotor (vs ss)  : %.6f rad\n', angle_max_dev);
    
    fprintf('\n');
    
end

fprintf('========================================\n\n')