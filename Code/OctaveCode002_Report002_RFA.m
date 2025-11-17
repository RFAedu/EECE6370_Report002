#Data Generation & Optimization script
#Roberto Avila
#EECE6370 Report002

clear all; close all; clc;
pkg load optim;

rng(0);  % reproducible

%% -------------------- Parameters --------------------
Nuc_Base   = 90000;
Sol_Base   = 85000;
Wind_Base1 = 35000;
Wind_Base2 = 10000;

GVar = 0.05;
DVar = 0.06;

Dat_Var = 0.2;
Dat_Rmp = 1200;

Time_H = linspace(0,7,168)';
N = length(Time_H);

%% -------------------- Generation --------------------
Nuc_Gen = ones(N,1)*Nuc_Base;
Sol_Gen = -cos(7*Time_H)*Sol_Base;
Sol_Gen(Sol_Gen<0)=0;

Win_Gen = Wind_Base1 + Wind_Base2.*sin(7*Time_H) - rand(N,1).*Wind_Base2;

Tot_Gen = Nuc_Gen + Sol_Gen + Win_Gen;

Dat_Dem = DVar * Tot_Gen;

%% -------------------- Total demand  --------------------
Tot_Dem = zeros(N,1);
for i = 1:N
    Tot_Dem(i) = Tot_Gen(i) + randi([-4,1])*(GVar/2)*Tot_Gen(i) + Dat_Dem(i);
end

Oth_Dem = Tot_Dem - Dat_Dem;

Dat_Max = (1+Dat_Var).*Dat_Dem;
Dat_Min = (1-Dat_Var).*Dat_Dem;


%% ================================================================
%%  (1) Greedy optimizer
%% ================================================================
ideal_dc = Tot_Gen - Oth_Dem;
vec_dc = min(max(ideal_dc,Dat_Min),Dat_Max);

% forward ramp pass
for i = 2:N
    diff = vec_dc(i) - vec_dc(i-1);
    if diff > Dat_Rmp
        vec_dc(i) = vec_dc(i-1) + Dat_Rmp;
    elseif diff < -Dat_Rmp
        vec_dc(i) = vec_dc(i-1) - Dat_Rmp;
    end
end

% backward ramp smoothing
for i = N-1:-1:1
    diff = vec_dc(i) - vec_dc(i+1);
    if diff > Dat_Rmp
        vec_dc(i) = vec_dc(i+1) + Dat_Rmp;
    elseif diff < -Dat_Rmp
        vec_dc(i) = vec_dc(i+1) - Dat_Rmp;
    end
    vec_dc(i) = min(max(vec_dc(i),Dat_Min(i)),Dat_Max(i));
end

Opt_Dat_Dem_vec = vec_dc;
Opt_Dem_vec = Oth_Dem + Opt_Dat_Dem_vec;


%% ================================================================
%%  (2) MPC Rolling Horizon
%%    * uses vectorized solver inside each horizon
%% ================================================================
H_mpc = 24;
Opt_Dat_Dem_mpc = Dat_Dem;

for t0 = 1:N
    t_end = min(N, t0 + H_mpc - 1);

    % Extract short horizon slice
    sub_Tot = Tot_Gen(t0:t_end);
    sub_Oth = Oth_Dem(t0:t_end);
    sub_Min = Dat_Min(t0:t_end);
    sub_Max = Dat_Max(t0:t_end);

    ideal_sub = sub_Tot - sub_Oth;

    % vectorized solver over short horizon
    sub_dc = min(max(ideal_sub, sub_Min), sub_Max);

    for i = 2:length(sub_dc)
        diff = sub_dc(i) - sub_dc(i-1);
        if diff > Dat_Rmp
            sub_dc(i) = sub_dc(i-1) + Dat_Rmp;
        elseif diff < -Dat_Rmp
            sub_dc(i) = sub_dc(i-1) - Dat_Rmp;
        end
    end

    Opt_Dat_Dem_mpc(t0) = sub_dc(1);
end

Opt_Dem_mpc = Oth_Dem + Opt_Dat_Dem_mpc;


%% ================================================================
%%  Metrics
%% ================================================================
RMSE = @(e) sqrt(mean(e.^2));

fprintf("\nRMSE (generation - demand):\n");
fprintf(" Unoptimized:   %.1f\n", RMSE(Tot_Gen-Tot_Dem));
fprintf(" Greedy: %.1f\n", RMSE(Tot_Gen-Opt_Dem_vec));
fprintf(" MPC:        %.1f\n", RMSE(Tot_Gen-Opt_Dem_mpc));


%% ================================================================
%%  Plots
%% ================================================================
figure(1);
plot(Time_H, Tot_Gen, 'k',"linewidth",2, Time_H, Tot_Dem,'c',...
     Time_H, Opt_Dem_vec,'m', Time_H, Opt_Dem_mpc, 'r');
legend('Gen','Demand','vec', 'MPC');
title('Greedy Optimization vs MPC Optimization'); grid on;
xlabel('Hours (decimal)');
ylabel('Power in MWh');

%% ================================================================
%%  Save CSV
%% ================================================================
data_out = [Time_H Nuc_Gen Sol_Gen Win_Gen Tot_Gen Tot_Dem Oth_Dem ...
            Dat_Dem Opt_Dat_Dem_vec ...
            Opt_Dat_Dem_mpc Opt_Dem_vec Opt_Dem_mpc];

csvwrite("Report002_results.csv", data_out);
fprintf("Saved Report002_results.csv\n");

