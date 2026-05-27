% Data
D = [0; 1; 4; 8; 1; 10; 0.5; 0.1; 0.5; 2; 4; 12; 1; 1; 1; 1];
H = [0; 0.5; 2; 0.5; 4; 5; 5; 0.1; 0.5; 0.5; 0.5; 0.5; 1; 2; 6; 8];
cct_bus1 = [0.021; 0.024; 0.024; 0.024; 0.024; 0.024; 0.024; 0.024; 0.024; 0.024; 0.024; 0.024; 0.024; 0.024; 0.024; 0.024];
cct_bus2 = [0.118; 0.118; 0.118; 0.118; 0.118; 0.118; 0.118; 0.118; 0.118; 0.118; 0.118; 0.118; 0.118; 0.118; 0.118; 0.118];
cct_bus3 = [0.278; 0.234; 0.234; 0.252; 0.221; 0.234; 0.221; 0.234; 0.234; 0.252; 0.252; 0.252; 0.234; 0.228; 0.221; 0.221];

% Create grid untuk interpolasi
[D_grid, H_grid] = meshgrid(linspace(min(D), max(D), 100), linspace(min(H), max(H), 100));

% Interpolasi menggunakan griddata
cct1_grid = griddata(D, H, cct_bus1, D_grid, H_grid, 'cubic');
cct2_grid = griddata(D, H, cct_bus2, D_grid, H_grid, 'cubic');
cct3_grid = griddata(D, H, cct_bus3, D_grid, H_grid, 'cubic');

% Plot 3 kontur
figure;

% Plot kontur CCT Bus 1
subplot(1, 3, 1);
contourf(D_grid, H_grid, cct1_grid, 20);
colorbar;
hold on;
scatter(D, H, 30, 'k', 'filled');
xlabel('D');
ylabel('H');
title('CCT Bus 1');

% Plot kontur CCT Bus 2
subplot(1, 3, 2);
contourf(D_grid, H_grid, cct2_grid, 20);
colorbar;
hold on;
scatter(D, H, 30, 'k', 'filled');
xlabel('D');
ylabel('H');
title('CCT Bus 2');

% Plot kontur CCT Bus 3
subplot(1, 3, 3);
contourf(D_grid, H_grid, cct3_grid, 20);
colorbar;
hold on;
scatter(D, H, 30, 'k', 'filled');
xlabel('D');
ylabel('H');
title('CCT Bus 3');
