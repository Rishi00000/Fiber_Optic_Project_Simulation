% Four-channel complex-envelope WDM model with attenuation and dispersion.
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

wdmWavelength_nm = [1530, 1540, 1550, 1560];
wdmFiberLength_km = 50;
wdmAttenuation_dB_per_km = 0.2;
wdmBeta2_ps2_per_km = -21.7;
wdmSampleCount = 4096;
wdmSampleRate_Hz = 16e12;
wdmModulation_Hz = 18e9;
wdmSpeedOfLight_m_s = 299792458;

wdmOpticalFrequency_Hz = wdmSpeedOfLight_m_s ./ (wdmWavelength_nm * 1e-9);
wdmReferenceFrequency_Hz = mean(wdmOpticalFrequency_Hz);
wdmChannelOffset_Hz = wdmOpticalFrequency_Hz - wdmReferenceFrequency_Hz;
wdmTime_s = (0:wdmSampleCount - 1) / wdmSampleRate_Hz;
wdmFrequencyOffset_Hz = [0:wdmSampleCount / 2 - 1, ...
    -wdmSampleCount / 2:-1] * (wdmSampleRate_Hz / wdmSampleCount);

wdmChannelFields = zeros(numel(wdmWavelength_nm), wdmSampleCount);
for wdmChannelIndex = 1:numel(wdmWavelength_nm)
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

wdmSortedOffsets_Hz = sort(wdmChannelOffset_Hz);
wdmChannelSpacing_Hz = min(diff(wdmSortedOffsets_Hz));
wdmChannelHalfWidth_Hz = 0.45 * wdmChannelSpacing_Hz;
wdmSpectrum = fft(wdmTransmitted);
wdmChannelOutputs = zeros(size(wdmChannelFields));
for wdmChannelIndex = 1:numel(wdmWavelength_nm)
    wdmMask = abs(wdmFrequencyOffset_Hz - ...
        wdmChannelOffset_Hz(wdmChannelIndex)) <= wdmChannelHalfWidth_Hz;
    wdmChannelOutputs(wdmChannelIndex, :) = ifft(wdmSpectrum .* wdmMask);
end

fprintf('Four-channel WDM complex-envelope model\n');
fprintf('  Wavelengths (nm): %g %g %g %g\n', wdmWavelength_nm);
fprintf('  Fiber: %.1f km, attenuation %.2f dB/km; output power fraction %.4f\n', ...
    wdmFiberLength_km, wdmAttenuation_dB_per_km, wdmPowerAttenuation);
fprintf('  Dispersion beta2: %.1f ps^2/km\n', wdmBeta2_ps2_per_km);
fprintf('  Channel offsets (GHz): %.3f %.3f %.3f %.3f\n', ...
    wdmChannelOffset_Hz / 1e9);

wdmTime_ps = wdmTime_s * 1e12;
wdmPlotCount = 300;
wdmColors = lines(numel(wdmWavelength_nm));
figure('Name', 'WDM individual and multiplexed envelopes');
subplot(2, 1, 1);
hold on;
for wdmChannelIndex = 1:numel(wdmWavelength_nm)
    plot(wdmTime_ps(1:wdmPlotCount), ...
        real(wdmChannelFields(wdmChannelIndex, 1:wdmPlotCount)), ...
        'Color', wdmColors(wdmChannelIndex, :));
end
grid on;
xlabel('Time (ps)');
ylabel('Real field envelope');
title('Individual WDM channel envelopes');
legend('1530 nm', '1540 nm', '1550 nm', '1560 nm');
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
figure('Name', 'WDM spectrum before and after fiber');
plot(wdmFrequencyGHzSorted, ...
    10 * log10(wdmSpectrumBefore(wdmOrder) + 1e-15), ...
    'LineWidth', 1.3);
hold on;
plot(wdmFrequencyGHzSorted, ...
    10 * log10(wdmSpectrumAfter(wdmOrder) + 1e-15), ...
    'LineWidth', 1.3);
xlim([-2500, 2500]);
grid on;
xlabel('Offset from reference optical carrier (GHz)');
ylabel('Relative power (dB)');
title('WDM spectrum before and after 50 km of fiber');
legend('Before fiber', 'After fiber');
saveas(gcf, fullfile(wdmGraphDir, 'wdm_spectrum_before_after.png'));

figure('Name', 'WDM demultiplexed channel outputs');
hold on;
for wdmChannelIndex = 1:numel(wdmWavelength_nm)
    plot(wdmTime_ps(1:wdmPlotCount), ...
        real(wdmChannelOutputs(wdmChannelIndex, 1:wdmPlotCount)), ...
        'Color', wdmColors(wdmChannelIndex, :));
end
grid on;
xlabel('Time (ps)');
ylabel('Real field envelope');
title('Ideal frequency-mask demultiplexer outputs');
legend('1530 nm', '1540 nm', '1550 nm', '1560 nm');
saveas(gcf, fullfile(wdmGraphDir, 'wdm_demultiplexed.png'));

wdmLengths_km = 0:100;
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

wdmOutput = table((1:numel(wdmWavelength_nm)).', ...
    wdmWavelength_nm.', (wdmOpticalFrequency_Hz / 1e12).', ...
    repmat(wdmPowerAttenuation, numel(wdmWavelength_nm), 1), ...
    'VariableNames', {'channel', 'wavelength_nm', ...
    'optical_frequency_thz', 'power_transmission'});
writetable(wdmOutput, fullfile(wdmDataDir, 'wdm_results_matlab.csv'));

wdmAnimationDir = fullfile(wdmProjectDir, 'Results', 'Animations');
if ~exist(wdmAnimationDir, 'dir')
    mkdir(wdmAnimationDir);
end
wdmGifPath = fullfile(wdmAnimationDir, 'wdm_co_propagation_matlab.gif');
wdmAnimationFigure = figure('Name', 'WDM co-propagation animation');
wdmDistance_km = linspace(0, 50, 300);
for wdmFrame = 1:60
    clf(wdmAnimationFigure);
    hold on;
    wdmProgress = (wdmFrame - 1) / 59;
    for wdmChannelIndex = 1:numel(wdmWavelength_nm)
        wdmSpatialPhase = 2 * pi * (wdmDistance_km / ...
            (10 + (wdmChannelIndex - 1) * 1.7) - ...
            50 * wdmProgress / (50 + (wdmChannelIndex - 1) * 2));
        plot(wdmDistance_km, sin(wdmSpatialPhase), ...
            'Color', wdmColors(wdmChannelIndex, :), 'LineWidth', 1.4);
    end
    grid on;
    xlabel('Distance along common fiber (km)');
    ylabel('Illustrative field oscillation');
    title('Four wavelength channels co-propagating in one fiber');
    legend('1530 nm', '1540 nm', '1550 nm', '1560 nm', ...
        'Location', 'northeast');
    axis([0, 50, -1.5, 1.5]);
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
