close all; clear;

%% data jaringan
% Sbase = 1MVA; Vbase_grid = 345kV
% frekuensi grid
f_s = 50; % (Hz)
w_s = 2*pi*50; % (rad/s)
W_s = diag([w_s, w_s, w_s]);

% reaktansi generator (p.u.)
X_d1 = 0.088;
X_d2 = 0.05;
X_d3 = 0.015;

% damping generator (pu_T/pu_w)
D_1 = 2;
D_2 = 2;
D_3 = 2;
D_vi = 0.81;
D_pure = diag([D_1, D_2, D_3]);
D_hybrid = diag([D_1+(D_vi*f_s), D_2, D_3]);

% inersia generator (s)
H_1 = 7;
H_2 = 8;
H_3 = 12;
H_vi = 3;
M_pure = diag([(2*H_1)/w_s, (2*H_2)/w_s, (2*H_3)/w_s]);
M_hybrid = diag([(2*(H_1+H_vi))/w_s, (2*H_2)/w_s, (2*H_3)/w_s]);

% reaktansi saluran (p.u.)
X_12 = 0.46;
X_13 = 0.26;
X_23 = 0.0806;

%% hasil loadflow
% magnitude tegangan bus (p.u.)
V_1 = 1.0;
V_2 = 1.0;
V_3 = 1.0;

% sudut tegangan bus (rad)
theta_1 = deg2rad(30.9052);
theta_2 = deg2rad(17.4308);
theta_3 = deg2rad(0);

% tegangan internal generator (p.u.)
E_1 = 1.1146;
E_2 = 1.0674;
E_3 = 1.059;

% sudut rotor initial (rad)
delta_1_0 = deg2rad(42.2426);
delta_2_0 = deg2rad(28.8041);
delta_3_0 = deg2rad(5.45199);



%% perhitungan
Bbus = [1/X_12+1/X_13, -1/X_12, -1/X_13;
        -1/X_12, 1/X_12+1/X_23, -1/X_23;
        -1/X_13, -1/X_23, 1/X_13+1/X_23];
Bgg = diag([1/X_d1, 1/X_d2, 1/X_d3]);
Bgb = -diag([1/X_d1, 1/X_d2, 1/X_d3]);
Bbg = transpose(Bgb);
Bbb = Bbus + diag([1/X_d1, 1/X_d2, 1/X_d3]);
Bred = Bgg - Bgb*inv(Bbb)*Bbg;

J = [-(E_1*E_2*Bred(1,2)*cos(delta_1_0-delta_2_0))-(E_1*E_3*Bred(1,3)*cos(delta_1_0-delta_3_0)), (E_1*E_2*Bred(1,2)*cos(delta_1_0-delta_2_0)), (E_1*E_3*Bred(1,3)*cos(delta_1_0-delta_3_0));
     (E_2*E_1*Bred(2,1)*cos(delta_2_0-delta_1_0)), -(E_2*E_1*Bred(2,1)*cos(delta_2_0-delta_1_0))-(E_2*E_3*Bred(2,3)*cos(delta_2_0-delta_3_0)), (E_2*E_3*Bred(2,3)*cos(delta_2_0-delta_3_0));
     (E_3*E_1*Bred(3,1)*cos(delta_3_0-delta_1_0)), (E_3*E_2*Bred(3,2)*cos(delta_3_0-delta_2_0)), -(E_3*E_1*Bred(3,1)*cos(delta_3_0-delta_1_0))-(E_3*E_2*Bred(3,2)*cos(delta_3_0-delta_2_0))];

A_pure = [zeros(3),         eye(3)*w_s;
          -inv(M_pure)*J,   -inv(M_pure)*D_pure];
A_vi = [zeros(3),           eye(3)*w_s;
            -inv(M_hybrid)*J,   -inv(M_hybrid)*D_hybrid];



eig(A_pure)
eigvals_pure = eig(A_pure);
% Filter eigenvalue kompleks saja (complex pair)
complex_eigs_pure = eigvals_pure(abs(imag(eigvals_pure)) > 1e-6);
% Pilih eigenvalue kompleks terdekat ke sumbu imajiner
[~, min_real_idx_pure] = min(abs(real(complex_eigs_pure)));
dominant_pure = complex_eigs_pure(min_real_idx_pure);
zeta_pure = -real(dominant_pure) / abs(dominant_pure);
omega_pure = abs(imag(dominant_pure));
fprintf('A_pure - Dominant eigenvalue: %.4f + %.4fi\n', real(dominant_pure), imag(dominant_pure));
fprintf('A_pure - Zeta (damping ratio): %.6f\n', zeta_pure);
fprintf('A_pure - Omega (natural frequency): %.6f\n\n', omega_pure);

% eig(A_vi)



% sweep H_vi and D_vi to compute dominant eigenvalue and damping ratio
H_vi_vals = linspace(0, 100e-3, 101);
D_vi_vals = linspace(0, 100e-3, 101);
[H_grid, D_grid] = meshgrid(H_vi_vals, D_vi_vals);

dominant_eig_real = nan(size(H_grid));
zeta_dominant = nan(size(H_grid));
omega_dominant = nan(size(H_grid));

tol = 1e-4;
for idx = 1:numel(H_grid)
    H_vi_tmp = H_grid(idx);
    D_vi_tmp = D_grid(idx);

    M_hybrid_tmp = diag([(2*(H_1 + H_vi_tmp))/w_s, (2*H_2)/w_s, (2*H_3)/w_s]);
    D_hybrid_tmp = diag([D_1 + (D_vi_tmp * f_s), D_2, D_3]);
    A_tmp = [zeros(3), eye(3) * w_s;
             -inv(M_hybrid_tmp) * J, -inv(M_hybrid_tmp) * D_hybrid_tmp];

    eigvals = eig(A_tmp);
    eigvals(abs(eigvals) < tol) = [];
    if isempty(eigvals)
        continue;
    end

    % Filter eigenvalue kompleks saja (complex pair)
    complex_eigs = eigvals(abs(imag(eigvals)) > 1e-6);
    if isempty(complex_eigs)
        continue;
    end
    
    % Pilih eigenvalue kompleks terdekat ke sumbu imajiner
    % (real part dengan magnitude terkecil)
    [~, min_real_idx] = min(abs(real(complex_eigs)));
    dominant = complex_eigs(min_real_idx);
    dominant_eig_real(idx) = real(dominant);
    zeta_dominant(idx) = -real(dominant) / abs(dominant);
    omega_dominant(idx) = abs(imag(dominant));
end

% Plot kedua data dalam 1 figure dengan 2 subplot
fig = figure('Position', [100, 100, 1200, 500]);

% Subplot 1: Zeta
subplot(1, 2, 1);
data_masked = zeta_dominant;
mask_out = data_masked < 0.75 | data_masked > 5.0;
data_masked(mask_out) = NaN;
contourf(H_grid, D_grid, data_masked, 20, 'LineColor', 'none');
hold on;
scatter(H_grid(mask_out), D_grid(mask_out), 5, [0.7 0.7 0.7], 'filled');
hold off;
colorbar;
xlabel('H\_vi');
ylabel('D\_vi');
title('Damping ratio \zeta of the dominant eigenvalue');
set(gca, 'FontSize', 12);
h_ax1 = gca;

% Subplot 2: Omega
subplot(1, 2, 2);
data_masked = omega_dominant;
mask_out = data_masked < 0 | data_masked > 71.71;
data_masked(mask_out) = NaN;
contourf(H_grid, D_grid, data_masked, 20, 'LineColor', 'none');
hold on;
scatter(H_grid(mask_out), D_grid(mask_out), 5, [0.7 0.7 0.7], 'filled');
hold off;
colorbar;
xlabel('H\_vi');
ylabel('D\_vi');
title('Natural frequency \omega of the dominant eigenvalue');
set(gca, 'FontSize', 12);
h_ax2 = gca;

% Setup synchronized data cursor
dcm = datacursormode(fig);
set(dcm, 'UpdateFcn', @(obj, evt) syncDataCursor(obj, evt, h_ax1, h_ax2, H_grid, D_grid, zeta_dominant, omega_dominant));
datacursormode(fig, 'on');

function output_txt = syncDataCursor(obj, evt, ax1, ax2, H_grid, D_grid, zeta_data, omega_data)
    % Fungsi untuk synchronized data cursor di kedua plot
    current_ax = evt.Target.Parent;
    pos = evt.Position;
    H_val = pos(1);
    D_val = pos(2);
    
    % Cari indeks terdekat
    [~, idx_H] = min(abs(H_grid(1, :) - H_val));
    [~, idx_D] = min(abs(D_grid(:, 1) - D_val));
    
    % Dapatkan nilai dari kedua data
    zeta_val = zeta_data(idx_D, idx_H);
    omega_val = omega_data(idx_D, idx_H);
    
    % Output text
    output_txt = sprintf('H_vi: %.2f\nD_vi: %.4f\nZeta: %.4f\nOmega: %.4f', ...
        H_val, D_val, zeta_val, omega_val);
end