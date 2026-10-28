% User-configurable WDM complex-envelope simulation.
% Sampling represents complex envelopes, not optical-carrier oscillations.

wdmScriptDir = fileparts(mfilename('fullpath'));
wdmMatlabDir = fileparts(wdmScriptDir);
wdmProjectDir = fileparts(wdmMatlabDir);
wdmGraphDir = fullfile(wdmProjectDir, 'Results', 'Graphs');
if ~exist(wdmGraphDir, 'dir')
    mkdir(wdmGraphDir);
end
wdmDataDir = fullfile(wdmProjectDir, 'Results', 'Data');
if ~exist(wdmDataDir, 'dir')
    mkdir(wdmDataDir);
end
if ~exist('wdmWavelength_nm', 'var')
    wdmWavelength_nm = [1530, 1540, 1550, 1560];
end
if ~exist('wdmFiberLength_km', 'var')
    wdmFiberLength_km = 50;
end
if ~exist('wdmAttenuation_dB_per_km', 'var')
    wdmAttenuation_dB_per_km = 0.2;
end
if ~exist('wdmBeta2_ps2_per_km', 'var')
    wdmBeta2_ps2_per_km = -21.7;
end
if ~exist('wdmModulation_Hz', 'var')
    wdmModulation_Hz = 18e9;
end

wdmSampleCount = 4096;
wdmSampleRate_Hz = 16e12;
wdmSpeedOfLight_m_s = 299792458;
wdmWavelength_nm = wdmWavelength_nm(:).';
wdmChannelCount = numel(wdmWavelength_nm);
if wdmChannelCount < 1 || any(~isfinite(wdmWavelength_nm)) || ...
        any(wdmWavelength_nm <= 0) || numel(unique(wdmWavelength_nm)) ~= wdmChannelCount
    error('WDM wavelengths must be unique, finite, positive values.');
end
wdmOpticalFrequency_Hz = wdmSpeedOfLight_m_s ./ (wdmWavelength_nm * 1e-9);
wdmReferenceFrequency_Hz = mean(wdmOpticalFrequency_Hz);
wdmChannelOffset_Hz = wdmOpticalFrequency_Hz - wdmReferenceFrequency_Hz;
if max(abs(wdmChannelOffset_Hz)) + wdmModulation_Hz >= wdmSampleRate_Hz / 2
    error('WDM channel offsets exceed the configured sample-rate Nyquist limit.');
end
if wdmChannelCount > 1
    wdmChannelSpacing_Hz = min(diff(sort(wdmChannelOffset_Hz)));
else
    wdmChannelSpacing_Hz = wdmSampleRate_Hz;
end
wdmChannelHalfWidth_Hz = 0.45 * wdmChannelSpacing_Hz;
if wdmModulation_Hz >= wdmChannelHalfWidth_Hz
    error('WDM modulation exceeds the ideal channel filter bandwidth.');
end
wdmTime_s = (0:wdmSampleCount - 1) / wdmSampleRate_Hz;
wdmFrequencyOffset_Hz = [0:wdmSampleCount / 2 - 1, ...
    -wdmSampleCount / 2:-1] * (wdmSampleRate_Hz / wdmSampleCount);

wdmChannelFields = zeros(wdmChannelCount, wdmSampleCount);
for wdmChannelIndex = 1:wdmChannelCount
    wdmChannelFields(wdmChannelIndex, :) = ...
        exp(1i * 2 * pi * wdmChannelOffset_Hz(wdmChannelIndex) * wdmTime_s) .* ...
        (1 + 0.25 * cos(2 * pi * wdmModulation_Hz * wdmTime_s));
end
wdmMultiplexed = sum(wdmChannelFields, 1);
wdmBeta2_s2_per_m = wdmBeta2_ps2_per_km * 1e-24 / 1000;
wdmLength_m = wdmFiberLength_km * 1000;
wdmDispersionPhase = exp(-1i * 2 * pi^2 * wdmBeta2_s2_per_m * ...
    wdmLength_m * wdmFrequencyOffset_Hz.^2);
wdmPowerAttenuation = 10^(-wdmAttenuation_dB_per_km * ...
    wdmFiberLength_km / 10);
wdmTransmitted = ifft(fft(wdmMultiplexed) .* wdmDispersionPhase) * ...
    sqrt(wdmPowerAttenuation);

wdmSpectrum = fft(wdmTransmitted);
wdmChannelOutputs = zeros(size(wdmChannelFields));
for wdmChannelIndex = 1:wdmChannelCount
    wdmMask = abs(wdmFrequencyOffset_Hz - ...
        wdmChannelOffset_Hz(wdmChannelIndex)) <= wdmChannelHalfWidth_Hz;
    wdmChannelOutputs(wdmChannelIndex, :) = ifft(wdmSpectrum .* wdmMask);
end

fprintf('WDM channels: %d\n', wdmChannelCount);
fprintf('  Wavelengths (nm): %s\n', sprintf('%.4g ', wdmWavelength_nm));
fprintf('  Fiber: %.4g km, attenuation %.4g dB/km; power transmission %.6g\n', ...
    wdmFiberLength_km, wdmAttenuation_dB_per_km, wdmPowerAttenuation);
fprintf('  Dispersion beta2: %.4g ps^2/km\n', wdmBeta2_ps2_per_km);

wdmTime_ps = wdmTime_s * 1e12;
wdmPlotCount = 300;
wdmColors = lines(wdmChannelCount);
wdmLegend = cell(1, wdmChannelCount);
for wdmChannelIndex = 1:wdmChannelCount
    wdmLegend{wdmChannelIndex} = sprintf('%.4g nm', ...
        wdmWavelength_nm(wdmChannelIndex));
end
figure('Name', 'WDM individual and multiplexed envelopes');
subplot(2, 1, 1);
hold on;
for wdmChannelIndex = 1:wdmChannelCount
    plot(wdmTime_ps(1:wdmPlotCount), ...
        real(wdmChannelFields(wdmChannelIndex, 1:wdmPlotCount)), ...
        'Color', wdmColors(wdmChannelIndex, :));
end
grid on;
xlabel('Time (ps)');
ylabel('Real field envelope');
title('Individual WDM channel envelopes');
legend(wdmLegend, 'Location', 'best');
subplot(2, 1, 2);
plot(wdmTime_ps(1:wdmPlotCount), ...
    real(wdmMultiplexed(1:wdmPlotCount)), 'k');
grid on;
xlabel('Time (ps)');
ylabel('Real field envelope');
title('Multiplexed field before fiber');
saveas(gcf, fullfile(wdmGraphDir, 'wdm_signals.png'));

wdmSpectrumBefore = abs(fft(wdmMultiplexed)).^2;
wdmSpectrumAfter = abs(fft(wdmTransmitted)).^2;
wdmFrequencyGHz = wdmFrequencyOffset_Hz / 1e9;
[wdmFrequencyGHzSorted, wdmOrder] = sort(wdmFrequencyGHz);
wdmSpectrumLimitGHz = max(abs(wdmChannelOffset_Hz)) / 1e9 + ...
    wdmModulation_Hz / 1e9 + 50;
figure('Name', 'WDM spectrum before and after fiber');
plot(wdmFrequencyGHzSorted, ...
    10 * log10(wdmSpectrumBefore(wdmOrder) + 1e-15), ...
    'LineWidth', 1.3);
hold on;
plot(wdmFrequencyGHzSorted, ...
    10 * log10(wdmSpectrumAfter(wdmOrder) + 1e-15), ...
    'LineWidth', 1.3);
xlim([-wdmSpectrumLimitGHz, wdmSpectrumLimitGHz]);
grid on;
xlabel('Offset from reference optical carrier (GHz)');
ylabel('Relative power (dB)');
title(sprintf('WDM spectrum before and after %.4g km fiber', wdmFiberLength_km));
legend('Before fiber', 'After fiber');
saveas(gcf, fullfile(wdmGraphDir, 'wdm_spectrum_before_after.png'));

figure('Name', 'WDM demultiplexed channel outputs');
hold on;
for wdmChannelIndex = 1:wdmChannelCount
    plot(wdmTime_ps(1:wdmPlotCount), ...
        real(wdmChannelOutputs(wdmChannelIndex, 1:wdmPlotCount)), ...
        'Color', wdmColors(wdmChannelIndex, :));
end
grid on;
xlabel('Time (ps)');
ylabel('Real field envelope');
title('Ideal frequency-mask demultiplexer outputs');
legend(wdmLegend, 'Location', 'best');
saveas(gcf, fullfile(wdmGraphDir, 'wdm_demultiplexed.png'));

wdmLengths_km = linspace(0, max(100, wdmFiberLength_km), 101);
wdmOutputPower_dB = -wdmAttenuation_dB_per_km * wdmLengths_km;
figure('Name', 'WDM power versus distance');
plot(wdmLengths_km, wdmOutputPower_dB, 'LineWidth', 1.6);
hold on;
plot(wdmFiberLength_km, ...
    -wdmAttenuation_dB_per_km * wdmFiberLength_km, 'o');
grid on;
xlabel('Fiber length (km)');
ylabel('Relative power (dB)');
title('WDM channel power attenuation versus distance');
saveas(gcf, fullfile(wdmGraphDir, 'wdm_power_vs_distance.png'));

wdmOutputPowerFraction = wdmPowerAttenuation * ...
    mean(abs(wdmChannelFields).^2, 2);
wdmOutput = table((1:wdmChannelCount).', wdmWavelength_nm.', ...
    (wdmOpticalFrequency_Hz / 1e12).', ...
    repmat(wdmFiberLength_km, wdmChannelCount, 1), ...
    repmat(wdmAttenuation_dB_per_km, wdmChannelCount, 1), ...
    repmat(wdmBeta2_ps2_per_km, wdmChannelCount, 1), ...
    wdmOutputPowerFraction, ...
    'VariableNames', {'channel', 'wavelength_nm', ...
    'optical_frequency_thz', 'fiber_length_km', 'attenuation_db_per_km', ...
    'beta2_ps2_per_km', 'fiber_output_power_fraction'});
writetable(wdmOutput, fullfile(wdmDataDir, 'wdm_results_matlab.csv'));

wdmAnimationDir = fullfile(wdmProjectDir, 'Results', 'Animations');
if ~exist(wdmAnimationDir, 'dir')
    mkdir(wdmAnimationDir);
end
wdmGifPath = fullfile(wdmAnimationDir, 'wdm_co_propagation_matlab.gif');
wdmAnimationFigure = figure('Name', 'WDM transmitter-mux-fiber-demux animation', ...
    'Position', [100, 100, 1200, max(500, 140 + 72 * wdmChannelCount)]);
wdmLaneY = wdmChannelCount:-1:1;
wdmCenterY = (wdmChannelCount + 1) / 2;
wdmBundleSpacing = min(0.16, max(0.06, 0.48 / wdmChannelCount));
wdmBundleOffsets = ((0:wdmChannelCount - 1) - ...
    (wdmChannelCount - 1) / 2) * wdmBundleSpacing;
wdmRouteX = [1.25, 2.70, 3.35, 6.65, 7.30, 8.75];
wdmRouteY = zeros(wdmChannelCount, numel(wdmRouteX));
for wdmChannelIndex = 1:wdmChannelCount
    wdmRouteY(wdmChannelIndex, :) = [wdmLaneY(wdmChannelIndex), ...
        wdmLaneY(wdmChannelIndex), ...
        wdmCenterY + wdmBundleOffsets(wdmChannelIndex), ...
        wdmCenterY + wdmBundleOffsets(wdmChannelIndex), ...
        wdmLaneY(wdmChannelIndex), wdmLaneY(wdmChannelIndex)];
end
for wdmFrame = 1:120
    clf(wdmAnimationFigure);
    hold on;
    wdmProgress = (wdmFrame - 1) / 119;
    if wdmProgress < 0.22
        wdmStage = '1/5  Transmitters -> MUX';
    elseif wdmProgress < 0.34
        wdmStage = '2/5  MUX combines channels';
    elseif wdmProgress < 0.70
        wdmStage = '3/5  Together in shared fiber';
    elseif wdmProgress < 0.82
        wdmStage = '4/5  DEMUX separates wavelengths';
    else
        wdmStage = '5/5  Channels -> receivers';
    end
    rectangle('Position', [3.35, wdmCenterY - 0.36, 3.30, 0.72], ...
        'FaceColor', [0.91, 0.94, 0.97], 'EdgeColor', [0.38, 0.49, 0.61], ...
        'LineWidth', 1.5);
    text(5, wdmCenterY + 0.48, ...
        sprintf('ONE FIBER  |  %.4g km', wdmFiberLength_km), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
        'Color', [0.20, 0.29, 0.37]);

    patch([2.70, 3.35, 3.35, 2.70], ...
        [wdmLaneY(1) + 0.35, wdmCenterY + 0.30, ...
        wdmCenterY - 0.30, wdmLaneY(end) - 0.35], ...
        [0.73, 0.91, 0.93], 'EdgeColor', [0.14, 0.42, 0.47], ...
        'LineWidth', 2);
    patch([6.65, 7.30, 7.30, 6.65], ...
        [wdmCenterY + 0.30, wdmLaneY(1) + 0.35, ...
        wdmLaneY(end) - 0.35, wdmCenterY - 0.30], ...
        [0.73, 0.91, 0.93], 'EdgeColor', [0.14, 0.42, 0.47], ...
        'LineWidth', 2);
    text(0.75, wdmChannelCount + 0.45, 'TRANSMITTERS', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    text(3.02, wdmChannelCount + 0.45, 'MUX', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    text(6.98, wdmChannelCount + 0.45, 'DEMUX', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    text(9.25, wdmChannelCount + 0.45, 'RECEIVERS', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    text(5, 0.64, wdmStage, ...
        'HorizontalAlignment', 'center', 'Color', [0.12, 0.31, 0.48], ...
        'FontWeight', 'bold', 'FontSize', 10);

    wdmRouteColors = lines(wdmChannelCount);
    for wdmChannelIndex = 1:wdmChannelCount
        wdmY = wdmLaneY(wdmChannelIndex);
        rectangle('Position', [0.25, wdmY - 0.20, 0.90, 0.40], ...
            'FaceColor', [0.96, 0.97, 0.98], 'EdgeColor', [0.20, 0.29, 0.37]);
        text(0.70, wdmY, sprintf('TX %d\\n%.4g nm', ...
            wdmChannelIndex, wdmWavelength_nm(wdmChannelIndex)), ...
            'HorizontalAlignment', 'center', 'FontSize', 8);
        rectangle('Position', [8.75, wdmY - 0.20, 0.90, 0.40], ...
            'FaceColor', [0.96, 0.97, 0.98], 'EdgeColor', [0.20, 0.29, 0.37]);
        text(9.20, wdmY, sprintf('RX %d\\n%.4g nm', ...
            wdmChannelIndex, wdmWavelength_nm(wdmChannelIndex)), ...
            'HorizontalAlignment', 'center', 'FontSize', 8);

        plot(wdmRouteX, wdmRouteY(wdmChannelIndex, :), ...
            'Color', wdmRouteColors(wdmChannelIndex, :) * 0.25 + 0.75, ...
            'LineWidth', 1.5);
        wdmLengths = hypot(diff(wdmRouteX), ...
            diff(wdmRouteY(wdmChannelIndex, :)));
        wdmCumulative = [0, cumsum(wdmLengths)];
        wdmTotalLength = wdmCumulative(end);
        wdmTravelDistance = wdmProgress * wdmTotalLength;
        wdmSampleDistance = linspace(0, wdmTravelDistance, ...
            max(2, round(160 * wdmProgress)));
        wdmActiveX = interp1(wdmCumulative, wdmRouteX, ...
            wdmSampleDistance, 'linear');
        wdmActiveY = interp1(wdmCumulative, ...
            wdmRouteY(wdmChannelIndex, :), wdmSampleDistance, 'linear');
        plot(wdmActiveX, wdmActiveY, ...
            'Color', wdmRouteColors(wdmChannelIndex, :), 'LineWidth', 3);
    end
    plot([0.25, 9.65], [0.28, 0.28], 'Color', [0.34, 0.40, 0.45], ...
        'LineWidth', 1.5);
    quiver(9.30, 0.28, 0.35, 0, 0, 'Color', [0.34, 0.40, 0.45], ...
        'LineWidth', 1.5, 'MaxHeadSize', 0.8);
    text(5, 0.34, 'SIGNAL FLOW', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'Color', [0.34, 0.40, 0.45]);
    axis([0, 10, 0, wdmChannelCount + 1]);
    axis off;
    drawnow;
    wdmFrameData = getframe(wdmAnimationFigure);
    [wdmIndexed, wdmMap] = rgb2ind(wdmFrameData.cdata, 256);
    if wdmFrame == 1
        imwrite(wdmIndexed, wdmMap, wdmGifPath, 'gif', ...
            'LoopCount', inf, 'DelayTime', 0.05);
    else
        imwrite(wdmIndexed, wdmMap, wdmGifPath, 'gif', ...
            'WriteMode', 'append', 'DelayTime', 0.05);
    end
end
close(wdmAnimationFigure);

% Retain the original fiber-only view as a second animation for presentations.
wdmFiberGifPath = fullfile(wdmAnimationDir, 'wdm_fiber_propagation_matlab.gif');
wdmFiberFigure = figure('Name', 'WDM waves inside shared fiber');
wdmDistance_km = linspace(0, wdmFiberLength_km, 400);
for wdmFrame = 1:60
    clf(wdmFiberFigure);
    hold on;
    wdmProgress = (wdmFrame - 1) / 59;
    wdmDistanceTraveled_km = wdmFiberLength_km * wdmProgress;
    for wdmChannelIndex = 1:wdmChannelCount
        wdmPhaseScale_km = 10 + (wdmChannelIndex - 1) * 1.7;
        wdmPhaseShift = wdmDistanceTraveled_km / ...
            (50 + (wdmChannelIndex - 1) * 2);
        wdmPhase = 2 * pi * ...
            (wdmDistance_km / wdmPhaseScale_km - wdmPhaseShift);
        wdmLocalLoss_dB = wdmAttenuation_dB_per_km * ...
            wdmDistanceTraveled_km;
        wdmAmplitude = 10^(-wdmLocalLoss_dB / 20);
        plot(wdmDistance_km, wdmAmplitude * sin(wdmPhase), ...
            'Color', wdmRouteColors(wdmChannelIndex, :), 'LineWidth', 1.6);
    end
    grid on;
    xlabel('Distance along the shared fiber (km)');
    ylabel('Illustrative field oscillation');
    title('WDM channels co-propagating through one fiber');
    legend(wdmLegend, 'Location', 'northeast');
    text(0.02, 0.93, sprintf('All %d channels together | distance: %.1f km', ...
        wdmChannelCount, wdmDistanceTraveled_km), ...
        'Units', 'normalized', 'HorizontalAlignment', 'left', ...
        'Color', [0.20, 0.29, 0.37]);
    axis([0, max(wdmFiberLength_km, eps), -1.5, 1.5]);
    drawnow;
    wdmFrameData = getframe(wdmFiberFigure);
    [wdmIndexed, wdmMap] = rgb2ind(wdmFrameData.cdata, 256);
    if wdmFrame == 1
        imwrite(wdmIndexed, wdmMap, wdmFiberGifPath, 'gif', ...
            'LoopCount', inf, 'DelayTime', 0.05);
    else
        imwrite(wdmIndexed, wdmMap, wdmFiberGifPath, 'gif', ...
            'WriteMode', 'append', 'DelayTime', 0.05);
    end
end
close(wdmFiberFigure);
