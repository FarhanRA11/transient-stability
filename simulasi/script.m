tic
clear;
close all;
tempFolder = tempdir;
files = dir(tempFolder);

for k = 1:length(files)
    fname = files(k).name;
    if ~files(k).isdir
        try
            delete(fullfile(tempFolder, fname));
        catch
            % Abaikan file yang sedang dipakai
        end
    end
end

% Reset Simulink cache
Simulink.fileGenControl('reset');

%% grid
Sbase = 1e6;
Vbase = 345e3;
Zbase = Vbase^2/Sbase;
ibase = Sbase/Vbase;
Xline_12 = 7/6; % pu
Xline_13 = 8/6;
Xline_23 = 4/6; % 784
% from loadflow
Vmag1 = 1; % pu
Vmag2 = 1;
Vmag3 = 0.9965;
Vang1 = 0 * pi/180; % deg --> rad
Vang2 = -1.6466 * pi/180;
Vang3 = -1.7702 * pi/180;


%% dc-dc unidirectional boost converter design
Ppv = 2e6;
Vpv = 1100; % 900-1000V
eff_pv = 1;
Vdc_link = 1500;
rippleI = 0.2;
rippleV = 0.01;
fs_mppt = 5e3;

D_mppt = 1-(Vpv/Vdc_link);
Iout_mppt = Ppv/Vdc_link;
Ipv = Ppv/(eff_pv*Vpv);
deltaI = rippleI*Ipv;
deltaV = rippleV*Vdc_link;

L_mppt = 1*(Vpv*D_mppt)/(deltaI*fs_mppt);
C_mppt = 20*(Iout_mppt*D_mppt)/(deltaV*fs_mppt); % margin
RL_mppt_dummy = Vdc_link^2/Ppv;


%% LCL inverter design
Pinv = 2e6; 
Vac_inv = 800; % rms, line-line
fg = 50;
fs_inv = 5e3;

fres_inv = fs_inv/10;
ws_inv = 2*pi*fs_inv;
wg = 2*pi*fg;
wres_inv = 2*pi*fres_inv;
Iinv = (Pinv/3)/Vac_inv;
Iinv_sw = 0.003*Iinv;
Vac_inv_sw = 0.9*Vac_inv;

C_inv = (0.05*Pinv)/((Vac_inv^2)*2*pi*fg)*4e0; % ~Q
Lmin_inv = abs(1/(ws_inv*(Iinv_sw/Vac_inv_sw)*(1-(ws_inv^2/wres_inv^2))))/2;
Lmax_inv = (0.2*Vac_inv)/(wg*Iinv);
Lmin_inv = Lmax_inv*1e0;

%% generator specs
Vac_grid = Vbase;

D_g1 = 5;
H_g1 = 4;
Rdroop_g1 = 0.05;
Tg_g1 = 0.4;
Snom_g1 = 7e6;
pairPoles_g1 = 2;
R_g1 = 0.015;
X_g1 = 0.3;
Pmin_g1 = 2.1e6;
Pmax_g1 = 6.65e6;
Qmin_g1 = -2.1e6;
Qmax_g1 = 2.8e6;
Pmlf_g1 = 0.84;
Elf_g1 = 1.06;

D_g2 = 5;
H_g2 = 1.8;
Rdroop_g2 = 0.06;
Tg_g2 = 0.25;
Snom_g2 = 5e6;
pairPoles_g2 = 3;
R_g2 = 0.02;
X_g2 = 0.35;
Pmin_g2 = 1e6;
Pmax_g2 = 4.25e6;
Qmin_g2 = -1.25e6;
Qmax_g2 = 1.5e6;
Pmlf_g2 = 0.82;
Elf_g2 = 1.15;


%% battery specs
Vbat = 750;
cap_bat = 2000;
Rint_bat = 0.02;


%% dc-dc bidirectional buck-boost converter design
fs_bat = 5e3;
Inom_bat = 1*cap_bat;

deltaV_bat = 0.001*Vbat;
deltaI_bat = 0.02*Inom_bat;
L_bat = (Vbat*(Vdc_link-Vbat))/(deltaI_bat*fs_bat*Vdc_link);
Cbat_buck = deltaI_bat/(8*fs_bat*deltaV_bat);
Cdc_boost = 50*Cbat_buck;

Cdc = 30e-3;