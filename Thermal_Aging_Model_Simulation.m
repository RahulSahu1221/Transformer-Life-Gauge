%% Transformer Life Gauge — Thermal Aging Model Simulation
% Simulates 24 hours of transformer operation and computes the live
% "Life Remaining %" using the IEEE C57.91 thermal aging model.
% No extra toolboxes required — runs on plain MATLAB.

clear; clc; close all;

%% ---- Design/reference constants (from transformer temp-rise test data) ----
% Example values for a typical ONAN-cooled distribution/mid-size power
% transformer. Replace with real design-stage values if you have them.
R          = 5;      % ratio of load loss to no-load loss at rated load
dTheta_TO  = 45;      % rated top-oil temperature rise (°C)
dTheta_HS  = 20;      % rated hot-spot-to-top-oil gradient (°C)
n_exp      = 0.8;     % oil exponent (ONAN)
m_exp      = 0.8;     % winding exponent (ONAN)
ratedLifeHours = 180000;  % IEEE C57.91 reference normal insulation life

%% ---- Build a 24-hour simulated day ----
dt_min   = 5;                          % sample interval (minutes)
t_hours  = (0:dt_min/60:24-dt_min/60)'; % time vector, 24h
nSamples = length(t_hours);

% Ambient temperature: simple daily sinusoidal swing (25°C to 35°C)
ambientTemp = 30 + 5*sin(2*pi*(t_hours-9)/24);

% Load profile K = load/rated load: typical industrial daily pattern
% (low at night, ramps up during the day, peak in afternoon)
K = 0.35 + 0.45*max(0, sin(pi*(t_hours-6)/14)) ...
        + 0.15*exp(-((t_hours-14).^2)/8);   % afternoon peak bump
K = min(K, 1.25);   % cap at 125% (occasional short overload)

%% ---- Step 1-3: run the thermal aging model over the day ----
thetaH   = zeros(nSamples,1);
F_AA     = zeros(nSamples,1);
lifeUsedPercent = zeros(nSamples,1);

cumulativeAgedHours = 0;
sampleIntervalHours = dt_min/60;

for i = 1:nSamples
    % Step 1: winding hot-spot temperature
    oilRise = dTheta_TO * ((1 + K(i)^2 * R)/(1 + R))^n_exp;
    hsRise  = dTheta_HS * K(i)^(2*m_exp);
    thetaH(i) = ambientTemp(i) + oilRise + hsRise;

    % Step 2: aging acceleration factor (thermally upgraded paper, 110°C ref)
    F_AA(i) = exp( (15000/383) - (15000/(thetaH(i)+273)) );

    % Step 3: accumulate loss of life
    cumulativeAgedHours = cumulativeAgedHours + F_AA(i)*sampleIntervalHours;
    lifeUsedPercent(i) = (cumulativeAgedHours / ratedLifeHours) * 100;
end

lifeRemainingPercent = 100 - lifeUsedPercent;

%% ---- Results summary (this is your "gauge" reading) ----
fprintf('--- Transformer Life Gauge: 24-Hour Simulation Summary ---\n');
fprintf('Peak hot-spot temperature reached : %.1f C\n', max(thetaH));
fprintf('Peak aging acceleration factor    : %.2fx normal rate\n', max(F_AA));
fprintf('Life consumed in this 24h period  : %.5f %%\n', lifeUsedPercent(end));
fprintf('Life Remaining (gauge reading)    : %.4f %%\n', lifeRemainingPercent(end));

%% ---- Bonus: Dynamic Loading Advisor "what-if" ----
overloadK       = 1.3;      % proposed emergency overload (130%)
overloadHours   = 4;        % proposed duration
oilRise_o = dTheta_TO * ((1 + overloadK^2*R)/(1+R))^n_exp;
hsRise_o  = dTheta_HS * overloadK^(2*m_exp);
thetaH_o  = mean(ambientTemp) + oilRise_o + hsRise_o;
F_AA_o    = exp( (15000/383) - (15000/(thetaH_o+273)) );
extraLifeLoss = (F_AA_o * overloadHours / ratedLifeHours) * 100;

fprintf('\n--- Dynamic Loading Advisor ---\n');
fprintf('Proposed: %.0f%% load for %d hours\n', overloadK*100, overloadHours);
fprintf('Resulting hot-spot temperature    : %.1f C\n', thetaH_o);
fprintf('Estimated extra life cost          : %.5f %% of total life\n', extraLifeLoss);

%% ---- Plots (your "live dashboard", offline version) ----
figure('Name','Transformer Life Gauge Simulation','Position',[100 100 900 700]);

subplot(4,1,1);
plot(t_hours, K*100, 'LineWidth', 1.8, 'Color', [0.1 0.24 0.36]);
ylabel('Load (%)'); title('Simulated Daily Load Profile'); grid on;

subplot(4,1,2);
plot(t_hours, thetaH, 'LineWidth', 1.8, 'Color', [0.11 0.45 0.58]);
yline(110, '--r', 'Rated Hot-Spot (110C)');
ylabel('Hot-Spot Temp (C)'); title('Estimated Winding Hot-Spot Temperature'); grid on;

subplot(4,1,3);
plot(t_hours, F_AA, 'LineWidth', 1.8, 'Color', [0.95 0.65 0.29]);
yline(1, '--k', 'Normal Aging Rate');
ylabel('F_{AA}'); title('Aging Acceleration Factor'); grid on;

subplot(4,1,4);
plot(t_hours, lifeRemainingPercent, 'LineWidth', 2.2, 'Color', [0.11 0.62 0.39]);
ylabel('Life Remaining (%)'); xlabel('Time (hours)');
title('Live "Life Remaining" Gauge Trend Over the Day'); grid on;

sgtitle('Transformer Life Gauge — Offline Simulation (MATLAB)');