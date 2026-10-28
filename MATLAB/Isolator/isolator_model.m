% Isolator power and Jones-matrix models.
% Run this script from MATLAB; plots are written to Results/Graphs.

isolatorScriptDir = fileparts(mfilename('fullpath'));
isolatorMatlabDir = fileparts(isolatorScriptDir);
isolatorProjectDir = fileparts(isolatorMatlabDir);
isolatorGraphDir = fullfile(isolatorProjectDir, 'Results', 'Graphs');
if ~exist(isolatorGraphDir, 'dir')
    mkdir(isolatorGraphDir);
end

% Scalar power model. ISO is reverse attenuation relative to input power.
isolatorIL_dB = 0.5;
isolatorISO_dB = 30;
isolatorInput_mW = 10;
isolatorForwardTransmission = 10^(-isolatorIL_dB / 10);
isolatorReverseTransmission = 10^(-isolatorISO_dB / 10);
isolatorForwardOutput_mW = isolatorInput_mW * isolatorForwardTransmission;
isolatorReverseOutput_mW = isolatorInput_mW * isolatorReverseTransmission;

fprintf('Isolator scalar power model\n');
fprintf('  Input power: %.4g mW\n', isolatorInput_mW);
fprintf('  Forward output (IL %.1f dB): %.6g mW\n', ...
    isolatorIL_dB, isolatorForwardOutput_mW);
fprintf('  Reverse output (ISO %.1f dB): %.6g mW\n', ...
    isolatorISO_dB, isolatorReverseOutput_mW);

% Jones model: ideal-axis polarizers and a +45 degree non-reciprocal
% Faraday rotation with the same signed rotation in either travel direction.
isolatorRotation_deg = 45;
isolatorRotation_rad = isolatorRotation_deg * pi / 180;
isolatorRotation = [cos(isolatorRotation_rad), -sin(isolatorRotation_rad); ...
                    sin(isolatorRotation_rad),  cos(isolatorRotation_rad)];
isolatorInputAxis = [1; 0];
isolatorAnalyzerAxis = [cos(isolatorRotation_rad); sin(isolatorRotation_rad)];
isolatorInputPolarizer = isolatorInputAxis * isolatorInputAxis.';
isolatorAnalyzerPolarizer = isolatorAnalyzerAxis * isolatorAnalyzerAxis.';

isolatorLaunchField = [1; 0];
isolatorForwardField = isolatorAnalyzerPolarizer * ...
    isolatorRotation * isolatorInputPolarizer * isolatorLaunchField;
% In reverse, light enters aligned to the analyzer pass axis. The Faraday
% rotation keeps the same sign, so the input polarizer rejects it.
isolatorReverseLaunchField = isolatorAnalyzerAxis;
isolatorReverseField = isolatorInputPolarizer * ...
    isolatorRotation * isolatorAnalyzerPolarizer * isolatorReverseLaunchField;
isolatorJonesForward_mW = isolatorInput_mW * sum(abs(isolatorForwardField).^2);
isolatorJonesReverse_mW = isolatorInput_mW * sum(abs(isolatorReverseField).^2);
isolatorJonesForward_dB = 10 * log10(isolatorJonesForward_mW / isolatorInput_mW);
isolatorJonesReverse_dB = 10 * log10(isolatorJonesReverse_mW / isolatorInput_mW);

fprintf('Isolator ideal Jones model\n');
fprintf('  Forward output: %.6g mW (%.3f dB relative to input)\n', ...
    isolatorJonesForward_mW, isolatorJonesForward_dB);
fprintf('  Reverse output: %.6g mW (%.3f dB relative to input)\n', ...
    isolatorJonesReverse_mW, isolatorJonesReverse_dB);

isolatorInputPlot_mW = linspace(0, isolatorInput_mW, 200);
figure('Name', 'Isolator power model');
plot(isolatorInputPlot_mW, isolatorInputPlot_mW * isolatorForwardTransmission, ...
    'LineWidth', 1.8);
hold on;
plot(isolatorInputPlot_mW, isolatorInputPlot_mW * isolatorReverseTransmission, ...
    'LineWidth', 1.8);
plot(isolatorInput_mW, isolatorForwardOutput_mW, 'o', 'MarkerSize', 7, ...
    'LineWidth', 1.5);
plot(isolatorInput_mW, isolatorReverseOutput_mW, 's', 'MarkerSize', 7, ...
    'LineWidth', 1.5);
grid on;
xlabel('Input power (mW)');
ylabel('Output power (mW)');
title('Optical isolator: forward and reverse power');
legend(sprintf('Forward, IL = %.1f dB', isolatorIL_dB), ...
    sprintf('Reverse, ISO = %.1f dB', isolatorISO_dB), ...
    'Forward at 10 mW', 'Reverse at 10 mW', 'Location', 'northwest');
saveas(gcf, fullfile(isolatorGraphDir, 'isolator_power.png'));

isolatorJonesBars_mW = [isolatorJonesForward_mW, isolatorJonesReverse_mW];
figure('Name', 'Isolator Jones model');
bar(1:2, isolatorJonesBars_mW);
set(gca, 'XTick', 1:2, 'XTickLabel', {'Forward', 'Reverse'});
grid on;
ylabel('Output power (mW)');
title('Jones model with input polarizer, Faraday rotator, and analyzer');
saveas(gcf, fullfile(isolatorGraphDir, 'isolator_jones.png'));

isolatorAnimationDir = fullfile(isolatorProjectDir, 'Results', 'Animations');
if ~exist(isolatorAnimationDir, 'dir')
    mkdir(isolatorAnimationDir);
end
isolatorGifPath = fullfile(isolatorAnimationDir, 'isolator_propagation_matlab.gif');
isolatorFigure = figure('Name', 'Isolator propagation animation');
for isolatorFrame = 1:60
    clf(isolatorFigure);
    hold on;
    for isolatorX = [0.15, 0.50, 0.85]
        plot([isolatorX, isolatorX], [-0.28, 0.28], ...
            'Color', [0.3, 0.3, 0.3], 'LineWidth', 4);
    end
    text(0.15, 0.34, 'Input polarizer', 'HorizontalAlignment', 'center');
    text(0.50, 0.34, 'Faraday rotator', 'HorizontalAlignment', 'center');
    text(0.85, 0.34, 'Analyzer', 'HorizontalAlignment', 'center');
    quiver(0.15, -0.08, 0.68, 0, 0, 'Color', [0.09, 0.49, 0.54], ...
        'LineWidth', 2, 'MaxHeadSize', 0.12);
    quiver(0.85, -0.20, -0.34, 0, 0, 'Color', [0.82, 0.29, 0.36], ...
        'LineWidth', 2, 'MaxHeadSize', 0.16);
    isolatorProgress = (isolatorFrame - 1) / 59;
    isolatorForwardX = 0.15 + 0.70 * isolatorProgress;
    isolatorReverseX = max(0.50, 0.85 - 0.70 * isolatorProgress);
    plot(isolatorForwardX, -0.08, 'o', 'MarkerFaceColor', ...
        [0.09, 0.49, 0.54], 'MarkerEdgeColor', 'none', 'MarkerSize', 12);
    plot(isolatorReverseX, -0.20, 'o', 'MarkerFaceColor', ...
        [0.82, 0.29, 0.36], 'MarkerEdgeColor', 'none', 'MarkerSize', 12);
    isolatorPolarizationAngle = min(45, max(0, ...
        (isolatorForwardX - 0.15) / 0.35 * 45)) * pi / 180;
    quiver(0.5, 0.08, 0.12 * cos(isolatorPolarizationAngle), ...
        0.12 * sin(isolatorPolarizationAngle), 0, ...
        'Color', [0.09, 0.49, 0.54], 'LineWidth', 2);
    text(0.5, -0.38, ...
        'Forward passes; reverse polarization rotates away from input axis', ...
        'HorizontalAlignment', 'center');
    axis([-0.05, 1.05, -0.45, 0.48]);
    axis off;
    drawnow;
    isolatorFrameData = getframe(isolatorFigure);
    [isolatorIndexed, isolatorMap] = rgb2ind(isolatorFrameData.cdata, 256);
    if isolatorFrame == 1
        imwrite(isolatorIndexed, isolatorMap, isolatorGifPath, 'gif', ...
            'LoopCount', inf, 'DelayTime', 0.05);
    else
        imwrite(isolatorIndexed, isolatorMap, isolatorGifPath, 'gif', ...
            'WriteMode', 'append', 'DelayTime', 0.05);
    end
end
close(isolatorFigure);
