function [core_line, clad_patch] = draw_fiber(ax, x_pts, y_pts, core_width, core_color, clad_color)
% DRAW_FIBER Draws an optical fiber with a cladding border and luminous core.
% Works in standard MATLAB and MATLAB Online.

    if nargin < 4, core_width = 3.5; end
    if nargin < 5, core_color = [0.15 0.75 0.95]; end
    if nargin < 6, clad_color = [0.18 0.24 0.35]; end

    hold(ax, 'on');

    % Outer cladding line (simulates fiber jacket/cladding)
    clad_patch = plot(ax, x_pts, y_pts, '-', ...
        'Color', clad_color, ...
        'LineWidth', core_width + 4.0, ...
        'Tag', 'fiber_clad');

    % Inner core line (where light is guided)
    core_line = plot(ax, x_pts, y_pts, '-', ...
        'Color', core_color, ...
        'LineWidth', core_width, ...
        'Tag', 'fiber_core');
end
