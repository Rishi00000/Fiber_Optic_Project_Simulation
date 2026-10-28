% Three-port ideal and lossy optical circulator models.
% Transfer-matrix convention: rows are output ports, columns are input ports.

circulatorScriptDir = fileparts(mfilename('fullpath'));
circulatorMatlabDir = fileparts(circulatorScriptDir);
circulatorProjectDir = fileparts(circulatorMatlabDir);
circulatorGraphDir = fullfile(circulatorProjectDir, 'Results', 'Graphs');
if ~exist(circulatorGraphDir, 'dir')
    mkdir(circulatorGraphDir);
end

circulatorIdealPower = zeros(3, 3);
circulatorIdealPower(2, 1) = 1; % 1 -> 2
circulatorIdealPower(3, 2) = 1; % 2 -> 3
circulatorIdealPower(1, 3) = 1; % 3 -> 1

% Assumed realistic values: 0.6 dB insertion loss on the routed path and
% -35 dB power coupling to each unintended output. Entries are power ratios.
circulatorInsertionLoss_dB = 0.6;
circulatorCrosstalk_dB = 35;
circulatorRoutedPower = 10^(-circulatorInsertionLoss_dB / 10);
circulatorCrosstalkPower = 10^(-circulatorCrosstalk_dB / 10);
circulatorRealisticPower = circulatorCrosstalkPower * ones(3, 3);
circulatorRealisticPower(2, 1) = circulatorRoutedPower;
circulatorRealisticPower(3, 2) = circulatorRoutedPower;
circulatorRealisticPower(1, 3) = circulatorRoutedPower;

fprintf('Circulator power transfer matrices (rows=output, columns=input)\n');
fprintf('Ideal routing:\n');
disp(circulatorIdealPower);
fprintf('Realistic routing (IL %.1f dB, unintended paths -%.1f dB):\n', ...
    circulatorInsertionLoss_dB, circulatorCrosstalk_dB);
disp(circulatorRealisticPower);

figure('Name', 'Circulator transfer matrices');
subplot(1, 2, 1);
imagesc(circulatorIdealPower);
axis equal tight;
set(gca, 'XTick', 1:3, 'YTick', 1:3);
xlabel('Input port');
ylabel('Output port');
title('Ideal power transfer');
colorbar;
caxis([0, 1]);
subplot(1, 2, 2);
imagesc(10 * log10(circulatorRealisticPower));
axis equal tight;
set(gca, 'XTick', 1:3, 'YTick', 1:3);
xlabel('Input port');
ylabel('Output port');
title('Realistic transfer (dB power ratio)');
colorbar;
saveas(gcf, fullfile(circulatorGraphDir, 'circulator_transfer.png'));

% Show the three output powers for 1 mW launched separately at each port.
circulatorInputPower_mW = 1;
circulatorOutputIdeal_mW = circulatorIdealPower * ...
    (circulatorInputPower_mW * ones(3, 1));
circulatorOutputRealistic_mW = circulatorRealisticPower * ...
    (circulatorInputPower_mW * ones(3, 1));
figure('Name', 'Circulator output powers');
bar([circulatorOutputIdeal_mW, circulatorOutputRealistic_mW]);
grid on;
set(gca, 'XTick', 1:3, 'XTickLabel', {'Output 1', 'Output 2', 'Output 3'});
ylabel('Output power for 1 mW at each input (mW)');
title('Circulator output power by destination port');
legend('Ideal', 'Realistic', 'Location', 'northwest');
saveas(gcf, fullfile(circulatorGraphDir, 'circulator_output_power.png'));

circulatorAnimationDir = fullfile(circulatorProjectDir, 'Results', 'Animations');
if ~exist(circulatorAnimationDir, 'dir')
    mkdir(circulatorAnimationDir);
end
circulatorGifPath = fullfile(circulatorAnimationDir, 'circulator_routing_matlab.gif');
circulatorAnimationFigure = figure('Name', 'Circulator routing animation');
circulatorPositions = [0.5, 0.88; 0.15, 0.2; 0.85, 0.2];
circulatorColors = [0.82, 0.29, 0.36; 0.96, 0.62, 0.26; 0.42, 0.30, 0.58];
for circulatorFrame = 1:60
    clf(circulatorAnimationFigure);
    hold on;
    for circulatorInputPort = 1:3
        circulatorOutputPort = mod(circulatorInputPort, 3) + 1;
        circulatorStart = circulatorPositions(circulatorInputPort, :);
        circulatorEnd = circulatorPositions(circulatorOutputPort, :);
        quiver(circulatorStart(1), circulatorStart(2), ...
            circulatorEnd(1) - circulatorStart(1), ...
            circulatorEnd(2) - circulatorStart(2), 0, ...
            'Color', [0.45, 0.45, 0.45], 'LineWidth', 1.8, 'MaxHeadSize', 0.15);
    end
    for circulatorPort = 1:3
        plot(circulatorPositions(circulatorPort, 1), ...
            circulatorPositions(circulatorPort, 2), 'o', ...
            'MarkerFaceColor', [0.09, 0.49, 0.54], ...
            'MarkerEdgeColor', 'none', 'MarkerSize', 22);
        text(circulatorPositions(circulatorPort, 1), ...
            circulatorPositions(circulatorPort, 2), ...
            sprintf('P%d', circulatorPort), 'Color', 'white', ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        circulatorOutputPort = mod(circulatorPort, 3) + 1;
        circulatorProgress = mod((circulatorFrame - 1) / 60 + ...
            (circulatorPort - 1) / 3, 1);
        circulatorPoint = (1 - circulatorProgress) * ...
            circulatorPositions(circulatorPort, :) + ...
            circulatorProgress * circulatorPositions(circulatorOutputPort, :);
        plot(circulatorPoint(1), circulatorPoint(2), 'o', ...
            'MarkerFaceColor', circulatorColors(circulatorPort, :), ...
            'MarkerEdgeColor', 'none', 'MarkerSize', 11);
    end
    text(0.5, 0.04, 'Simultaneous routing: P1 to P2, P2 to P3, P3 to P1', ...
        'HorizontalAlignment', 'center');
    axis([0, 1, 0, 1]);
    axis equal;
    axis off;
    drawnow;
    circulatorFrameData = getframe(circulatorAnimationFigure);
    [circulatorIndexed, circulatorMap] = rgb2ind(circulatorFrameData.cdata, 256);
    if circulatorFrame == 1
        imwrite(circulatorIndexed, circulatorMap, circulatorGifPath, 'gif', ...
            'LoopCount', inf, 'DelayTime', 0.05);
    else
        imwrite(circulatorIndexed, circulatorMap, circulatorGifPath, 'gif', ...
            'WriteMode', 'append', 'DelayTime', 0.05);
    end
end
close(circulatorAnimationFigure);
