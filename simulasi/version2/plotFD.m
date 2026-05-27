close all

% Sampling time
Ts = mean(diff(time_rotor));   % detik
Fs = 1/Ts;                     % Hz

% Jumlah sample
N = length(time_rotor);

% Frequency axis
f = (0:N-1)*(Fs/N);

% Half spectrum
half_idx = 1:floor(N/2);

% Warna plot
colors = {'g', 'b', 'r'};

%% plot frekuensi

figure;
hold on;

for ch = 1:3

    % Ambil sinyal
    x = frek{1}.Values.Data(:,ch);

    % Plot
    plot(frek{1}.Values.Time, frek{1}.Values.Data(:, ch), ...
        'Color', colors{ch}, ...
        'LineWidth', 2.0)

end

grid on;
xlim([0 20])
ylim([49.2 50.8])
xlabel('Waktu (s)')
ylabel('Frekuensi (Hz)')
title('Frekuensi Rotor Generator 1-3')
legend('G1', 'G2', 'G3')


%% plot rocof

figure;
hold on;

for ch = 1:3

    % Ambil sinyal
    x = dfdt{1}.Values.Data(:,ch);

    % Plot
    plot(dfdt{1}.Values.Time, dfdt{1}.Values.Data(:, ch), ...
        'Color', colors{ch}, ...
        'LineWidth', 2.0)

end

grid on;
xlim([0 20])
ylim([-8 8])
xlabel('Waktu (s)')
ylabel('df/dt (Hz/s)')
title('RoCoF Generator 1-3')
legend('G1', 'G2', 'G3')


%% plot sudut

figure;
hold on;

for ch = 1:3

    % Ambil sinyal
    x = angle{1}.Values.Data(:,ch);

    % Plot
    plot(angle{1}.Values.Time, angle{1}.Values.Data(:, ch), ...
        'Color', colors{ch}, ...
        'LineWidth', 2.0)

end

grid on;
xlim([0 20])
ylim([-0.2 0.8])
xlabel('Waktu (s)')
ylabel('Sudut (rad)')
title('Sudut Rotor Generator 1-3')
legend('G1', 'G2', 'G3')


%% plot fft

figure;
hold on;

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
        'LineWidth', 2.0)

end

grid on;
xlim([0 10])
ylim([0 0.06])
xlabel('Frekuensi (Hz)')
ylabel('Magnitudo')
title('FFT Sudut Rotor Generator 1-2')
legend('G1', 'G2')