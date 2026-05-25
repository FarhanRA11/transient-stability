tic
clear 
% warning('off','all')
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

% Simulation sampling period (seconds)
Ts = 1e-5; % 2e-6

%% Grid Parameters
Sbase = 1e6;            % Base nominal power (VA)
Vbase = 345e3;          % Base grid voltage (V)
f_grid  = 50;           % Nominal grid frequency (Hz)
omega   = 2*pi*f_grid;  % Nominal grid angular speed (rad/s)

Ppv = 2;

% Generator mechanical parameters
H1 = 7;
H2 = 8;
H3 = 12; % default 60
D = 2;
% Dinv = 0.0;
% Hinv = 0.0;

% RL load power demand at i-th bus (p.u.)
S1pu = (1.5 + .45j);
S2pu = (1.0 + .3j);
S3pu = (12.4 + 2.5j);

% Transmission line reactance (p.u.)
Z12pu = .46j;
Z13pu = .26j;
Z23pu = .0806j;

% per unit (pu) to standard unit (SI)
Zbase = Vbase^2/Sbase;
[R12, L12] = puToSI(Z12pu, Zbase, f_grid);
[R13, L13] = puToSI(Z13pu, Zbase, f_grid);
[R23, L23] = puToSI(Z23pu, Zbase, f_grid);

%% V2GG2V Params
% Grid & LCL filter
Snom_trafo = 1050e6;    % transformer nominal power (VA)
Linv    = 1/10*0.48e-3; %(Henry)   
Lgrid   = 1/10*0.69e-3; %(Henry)
Rd      = 1.31;         %(Ohm)
Cf      = 10*165e-6;    %(Farad)

% Inverter
C_Vdc   = 100*18e-3;    %(Farad)
V0_Vdc  = 1.5e3;        %(Volt)

% Buck-Boost Converter 
% Lbat = 2e-3;            %(Henry)

% Battery
Batt_Vnom       = 800;  %(Volt)
Batt_Ah         = 2000;   %(Ah)
Batt_InitSOC    = 80;   %(%)
Batt_RespTime   = 1;    %(seconds) 

% Phase Locked Loop (PLL)
Kp_PLL = 100;
Ki_PLL = 10000;

% PWM Control Switching Frequency
f_SW = 5000; %(Hz)

% DC Link Voltage Control
Vdc_ref = 1.5e3; %(Volt)
Kp_outer = 250;
Ki_outer = 10000;
Kp_inner = 100;
Ki_inner = 5000;

% Battery Current Control
Kp_CC       = 10;
Ki_CC       = 1;
UpSat_CC    = 1;
LowSat_CC   = 0;

%% Fault starting & clearing time (seconds)
t_fault_start = 1; % masuk ke variabel simulink
FCT = 0.1;
t_fault_end = t_fault_start + FCT; % masuk ke variabel simulink
Dinv = 0;
Hinv = 0;

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
Vac_l_rms = Vac_inv*(1/sqrt(3));
fg = 50;
fs_inv = 5e3;

wg = 2*pi*fg;
fn = fs_inv-2*fg;
wn = 2*pi*fn;
lmd = fn/fg;
mn = 0.314;
Vin_inv = mn*Vdc_link;
be = 1;
al = 3;
fres = fn*sqrt(2/al); % <=2500
r = 15;
Lmin_inv = (100*Vac_l_rms*Vin_inv*(al-be))/(wn*r*(Pinv/3)*(-be+al-1));
C_inv = (r*(Pinv/3)*al*(-be+al-1))/(100*Vac_l_rms*Vin_inv*wn*(al-be));


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

% Kirim ke workspace (dipakai Simulink)
assignin('base','t_fault_start',t_fault_start);
assignin('base','t_fault_end',t_fault_end);

simOut = sim('V2G_FDCC','StopTime','10');

%% Ambil sinyal (sesuaikan dengan nama To Workspace Anda)

delta1 = simOut.delta1.Data;
delta2 = simOut.delta2.Data;
delta3 = simOut.delta3.Data;

omega1 = simOut.omega1.Data;
omega2 = simOut.omega2.Data;
omega3 = simOut.omega3.Data;

toc