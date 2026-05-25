tic
clc;
tempFolder = tempdir;
files = dir(tempFolder);
warning('off', 'all');

% Tabel kombinasi Dinv dan Hinv
D_H_data = [
    0    0;
    0.1  0.5;
    0.5  0.5;
    2    0.5;
    6    0.5;
    12   0.5;
    1    0.5;
    1    1;
    1    2;
    1    6;
    1    8;
    1    12;
];

% Siapkan array untuk menyimpan hasil
numCombinations = size(D_H_data, 1);
results = table();
results.Dinv = D_H_data(:, 1);
results.Hinv = D_H_data(:, 2);
results.CCT = zeros(numCombinations, 1);
results.Status = cell(numCombinations, 1);


function isStable = check_stability(t,d1,d2,d3,w1,w2,w3)

isStable = true;

% Samakan panjang
N = min([length(t),length(w1),length(w2),length(w3), ...
         length(d1),length(d2),length(d3)]);

t  = t(1:N);
d1 = d1(1:N);
d2 = d2(1:N);
d3 = d3(1:N);
w1 = w1(1:N);
w2 = w2(1:N);
w3 = w3(1:N);

% Jika ada NaN → unstable
if any(isnan([w1;w2;w3]))
    isStable = false;
    return;
end

%% Speed divergence
% if any(abs([w1(end),w2(end),w3(end)] - 1) > 0.05)
%     isStable = false;
%     return;
% end
% 
% if max(abs([w1;w2;w3])) > 1.1
%     isStable = false;
%     return;
% end

%% Angle separation
d12 = d1 - d2;
d13 = d1 - d3;
d23 = d2 - d3;

if max(abs([d12;d13;d23])) > pi
    isStable = false;
    return;
end

%% Damping check
% t_settle = 9.99;
% idx = find(t > t_settle);
% 
% if ~isempty(idx)
%     if std(w1(idx)) > 0.01 || ...
%        std(w2(idx)) > 0.01 || ...
%        std(w3(idx)) > 0.01
%         isStable = false;
%         return;
%     end
% end

end


function isStable = simulate_and_check(modelName, t_fault_start, FCT, t_sim)

t_fault_end = t_fault_start + FCT;

% Kirim ke workspace (dipakai Simulink)
assignin('base','t_fault_start',t_fault_start);
assignin('base','t_fault_end',t_fault_end);

simOut = sim(modelName,'StopTime',num2str(t_sim));

%% Ambil sinyal (sesuaikan dengan nama To Workspace Anda)

delta1 = simOut.delta1.Data;
delta2 = simOut.delta2.Data;
delta3 = simOut.delta3.Data;

omega1 = simOut.omega1.Data;
omega2 = simOut.omega2.Data;
omega3 = simOut.omega3.Data;

t = simOut.tout;

%% Evaluasi stabilitas

isStable = check_stability(t, delta1, delta2, delta3, omega1, omega2, omega3);

end



modelName = 'V2G_FDCC';
t_fault_start = 1; % masuk ke variabel simulink
t_sim = 10;

tol = 1e-3;       % toleransi CCT
max_iter = 20;

fprintf('\n=============================\n');
fprintf('Mulai perhitungan CCT untuk semua kombinasi Dinv & Hinv\n');
fprintf('Total kombinasi: %d\n', numCombinations);
fprintf('=============================\n\n');

%% Loop untuk setiap kombinasi Dinv dan Hinv
for comb_idx = 1:numCombinations
    
    Dinv = results.Dinv(comb_idx);
    Hinv = results.Hinv(comb_idx);
    
    % Kirim ke workspace Simulink
    assignin('base','Dinv',Dinv);
    assignin('base','Hinv',Hinv);
    
    fprintf('=============================\n');
    fprintf('Kombinasi %d / %d\n', comb_idx, numCombinations);
    fprintf('Dinv = %.1f, Hinv = %.1f\n', Dinv, Hinv);
    fprintf('=============================\n');
    
    % Binary search untuk CCT
    FCT_min = 0;    % tebakan bawah (stable)
    FCT_max = 0.5;  % tebakan atas (unstable)
    
    try
        for k = 1:max_iter

            for f = 1:length(files)
                fname = files(f).name;
                if ~files(f).isdir
                    try
                        delete(fullfile(tempFolder, fname));
                    catch
                        % Abaikan file yang sedang dipakai
                    end
                end
            end
            
            % Reset Simulink cache
            Simulink.fileGenControl('reset');
            
            FCT_mid = (FCT_min + FCT_max)/2;
            
            isStable = simulate_and_check(modelName, t_fault_start, FCT_mid, t_sim);
            
            fprintf('  Iter %2d: FCT = %.6f → ', k, FCT_mid);
            
            if isStable
                fprintf('STABLE\n');
                FCT_min = FCT_mid;
            else
                fprintf('UNSTABLE\n');
                FCT_max = FCT_mid;
            end
            
            if abs(FCT_max - FCT_min) < tol
                break;
            end
        end
        
        CCT = FCT_min;
        results.CCT(comb_idx) = CCT;
        results.Status{comb_idx} = 'OK';
        
        fprintf('  → CCT = %.5f s\n\n', CCT);
        
    catch ME
        fprintf('  ✗ Error: %s\n\n', ME.message);
        results.Status{comb_idx} = 'Error';
    end
end

%% Tampilkan hasil ringkas
fprintf('\n');
fprintf('================== RINGKASAN HASIL ==================\n');
disp(results);
fprintf('=====================================================\n');

toc