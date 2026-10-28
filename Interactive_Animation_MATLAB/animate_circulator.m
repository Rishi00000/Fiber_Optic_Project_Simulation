function fig = animate_circulator(parent_fig, parent_panel, on_back_cb)
% ANIMATE_CIRCULATOR Interactive Animated Simulation of a 3-Port Optical Circulator.
% Demonstrates fundamental non-reciprocal cyclic routing:
%   Port 1 -> Port 2
%   Port 2 -> Port 3
%   Port 3 -> Port 1
% Features:
% - Real-time smooth curved animation of optical pulse along distinct geometric fiber paths.
% - Selectable Port 1, 2, or 3 inputs.
% - Ideal and Realistic (lossy/crosstalk) matrix modes.
% - Dynamic active-path glow and port detection flash.
% - Full play/pause/resume/speed/reset controls and step-by-step physical status messages.

    addpath(fullfile(fileparts(mfilename('fullpath')), 'helpers'));

    standalone = (nargin < 1 || isempty(parent_fig));
    if nargin < 3, on_back_cb = []; end

    if standalone
        scr = get(0, 'ScreenSize');
        fig_w = min(1140, max(750, round(scr(3) * 0.92)));
        fig_h = min(580, max(460, round(scr(4) * 0.74)));
        fig_x = max(15, round((scr(3) - fig_w) / 2));
        fig_y = max(45, round((scr(4) - fig_h) / 2));

        fig = figure('Name', 'Module B: Three-Port Fiber Optic Circulator Simulation', ...
            'NumberTitle', 'off', ...
            'Color', [0.06 0.08 0.13], ...
            'Position', [fig_x fig_y fig_w fig_h], ...
            'MenuBar', 'none', ...
            'ToolBar', 'none', ...
            'Resize', 'on');
        main_container = fig;
    else
        fig = parent_fig;
        if nargin < 2 || isempty(parent_panel)
            main_container = fig;
        else
            main_container = parent_panel;
        end
    end

    % State structure
    S = struct();
    S.is_running = false;
    S.is_paused = false;
    S.stop_requested = false;
    S.selected_port = 1;      % 1, 2, or 3
    S.mode = 'ideal';         % 'ideal' or 'realistic'
    S.input_power = 10.0;     % mW
    S.insertion_loss = 0.6;   % dB
    S.isolation = 35.0;       % dB
    S.speed = 1.0;
    S.standalone = standalone;

    % Palette
    c_bg      = [0.06 0.08 0.13];
    c_panel   = [0.10 0.13 0.20];
    c_card    = [0.13 0.17 0.26];
    c_border  = [0.22 0.32 0.48];
    c_cyan    = [0.00 0.90 1.00];
    c_green   = [0.00 0.90 0.45];
    c_amber   = [1.00 0.75 0.15];
    c_magenta = [1.00 0.20 0.65];
    c_text    = [0.92 0.95 0.98];
    c_subtext = [0.65 0.75 0.88];

    % Header Panel
    uicontrol('Parent', main_container, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.02 0.93 0.75 0.055], ...
        'String', 'THREE-PORT OPTICAL CIRCULATOR: NON-RECIPROCAL CYCLIC ROUTING', ...
        'FontName', 'Segoe UI', 'FontSize', 13, 'FontWeight', 'bold', ...
        'ForegroundColor', c_cyan, 'BackgroundColor', c_bg, ...
        'HorizontalAlignment', 'left');

    uicontrol('Parent', main_container, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.02 0.89 0.75 0.035], ...
        'String', 'Visualizes directional light routing: Port 1 -> Port 2 -> Port 3 -> Port 1 along continuous geometric waveguides.', ...
        'FontName', 'Segoe UI', 'FontSize', 9, ...
        'ForegroundColor', c_subtext, 'BackgroundColor', c_bg, ...
        'HorizontalAlignment', 'left');

    % Back button if inside master dashboard
    if ~standalone
        uicontrol('Parent', main_container, 'Style', 'pushbutton', ...
            'Units', 'normalized', 'Position', [0.86 0.93 0.12 0.05], ...
            'String', '< Back to Menu', ...
            'FontName', 'Segoe UI', 'FontSize', 10, 'FontWeight', 'bold', ...
            'ForegroundColor', [1 1 1], 'BackgroundColor', [0.25 0.35 0.50], ...
            'Callback', @(~, ~) handle_back_click());
    end

    % Main Animation Canvas (Axes)
    ax = axes('Parent', main_container, ...
        'Units', 'normalized', 'Position', [0.02 0.27 0.70 0.60], ...
        'Color', [0.04 0.06 0.10], ...
        'XColor', 'none', 'YColor', 'none', ...
        'XLim', [0 100], 'YLim', [0 65]);
    axis(ax, 'equal');
    hold(ax, 'on');
    S.ax = ax;

    % Controls Panel (Right Side)
    ctrl_panel = uipanel('Parent', main_container, ...
        'Units', 'normalized', 'Position', [0.73 0.02 0.25 0.89], ...
        'BackgroundColor', c_panel, 'BorderColor', c_border, ...
        'HighlightColor', c_border, ...
        'Title', ' CIRCULATOR CONTROLS ', ...
        'FontName', 'Segoe UI', 'FontSize', 11, 'FontWeight', 'bold', ...
        'ForegroundColor', c_cyan);

    % Status & Explanation Panel (Bottom Left)
    status_panel = uipanel('Parent', main_container, ...
        'Units', 'normalized', 'Position', [0.02 0.02 0.70 0.23], ...
        'BackgroundColor', c_panel, 'BorderColor', c_border, ...
        'HighlightColor', c_border, ...
        'Title', ' REAL-TIME ROUTING STATUS ', ...
        'FontName', 'Segoe UI', 'FontSize', 10, 'FontWeight', 'bold', ...
        'ForegroundColor', c_cyan);

    S.status_text = uicontrol('Parent', status_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.02 0.04 0.96 0.88], ...
        'String', 'Ready. Select Input Port (Port 1, 2, or 3) and press "Route Pulse" to begin animation.', ...
        'FontName', 'Consolas', 'FontSize', 8.8, ...
        'ForegroundColor', [0.88 0.94 1.00], 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'left');

    % Port Selection Buttons
    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.93 0.90 0.04], ...
        'String', 'SELECT INPUT PORT:', 'FontName', 'Segoe UI', ...
        'FontSize', 9, 'FontWeight', 'bold', 'ForegroundColor', c_cyan, ...
        'BackgroundColor', c_panel, 'HorizontalAlignment', 'left');

    S.btn_port1 = uicontrol('Parent', ctrl_panel, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.05 0.87 0.28 0.055], ...
        'String', 'Port 1', 'FontName', 'Segoe UI', 'FontSize', 9.5, ...
        'FontWeight', 'bold', 'ForegroundColor', [0.05 0.08 0.15], ...
        'BackgroundColor', c_cyan, ...
        'Callback', @(btn, ~) select_port(1));

    S.btn_port2 = uicontrol('Parent', ctrl_panel, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.36 0.87 0.28 0.055], ...
        'String', 'Port 2', 'FontName', 'Segoe UI', 'FontSize', 9.5, ...
        'FontWeight', 'bold', 'ForegroundColor', [0.8 0.9 1], ...
        'BackgroundColor', c_card, ...
        'Callback', @(btn, ~) select_port(2));

    S.btn_port3 = uicontrol('Parent', ctrl_panel, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.67 0.87 0.28 0.055], ...
        'String', 'Port 3', 'FontName', 'Segoe UI', 'FontSize', 9.5, ...
        'FontWeight', 'bold', 'ForegroundColor', [0.8 0.9 1], ...
        'BackgroundColor', c_card, ...
        'Callback', @(btn, ~) select_port(3));

    % Action Buttons
    S.btn_launch = uicontrol('Parent', ctrl_panel, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.05 0.79 0.90 0.065], ...
        'String', 'Route Pulse (1 -> 2)', 'FontName', 'Segoe UI', 'FontSize', 11, ...
        'FontWeight', 'bold', 'ForegroundColor', [0.05 0.08 0.15], ...
        'BackgroundColor', c_green, ...
        'Callback', @(btn, ~) start_animation());

    S.btn_pause = uicontrol('Parent', ctrl_panel, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.05 0.72 0.43 0.055], ...
        'String', 'Pause', 'FontName', 'Segoe UI', 'FontSize', 9.5, ...
        'ForegroundColor', [1 1 1], 'BackgroundColor', [0.35 0.45 0.55], ...
        'Callback', @(btn, ~) toggle_pause());

    S.btn_reset = uicontrol('Parent', ctrl_panel, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.52 0.72 0.43 0.055], ...
        'String', 'Reset', 'FontName', 'Segoe UI', 'FontSize', 9.5, ...
        'ForegroundColor', [1 1 1], 'BackgroundColor', [0.45 0.20 0.25], ...
        'Callback', @(btn, ~) reset_animation());

    % Model Mode Toggle: Ideal vs Realistic
    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.65 0.90 0.035], ...
        'String', 'TRANSFER MATRIX MODEL:', 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'FontWeight', 'bold', 'ForegroundColor', c_cyan, ...
        'BackgroundColor', c_panel, 'HorizontalAlignment', 'left');

    S.pop_mode = uicontrol('Parent', ctrl_panel, 'Style', 'popupmenu', ...
        'Units', 'normalized', 'Position', [0.05 0.61 0.90 0.04], ...
        'String', {'Ideal Circulator (0 dB IL, -Inf dB Leakage)', 'Realistic Circulator (0.6 dB IL, 35 dB Isolation)'}, ...
        'Value', 2, 'BackgroundColor', c_card, 'ForegroundColor', [1 1 1], ...
        'Callback', @(pop, ~) update_mode());

    % Sliders: Power and Speed
    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.54 0.65 0.035], ...
        'String', 'Input Power (Pin):', 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'ForegroundColor', c_text, 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'left');
    S.lbl_pwr = uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.70 0.54 0.25 0.035], ...
        'String', '10.0 mW', 'FontName', 'Segoe UI', 'FontSize', 8.5, ...
        'FontWeight', 'bold', 'ForegroundColor', c_amber, 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'right');
    S.sld_pwr = uicontrol('Parent', ctrl_panel, 'Style', 'slider', ...
        'Units', 'normalized', 'Position', [0.05 0.50 0.90 0.035], ...
        'Min', 1.0, 'Max', 25.0, 'Value', 10.0, ...
        'BackgroundColor', c_card, ...
        'Callback', @(sld, ~) update_params());

    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.43 0.65 0.035], ...
        'String', 'Animation Speed:', 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'ForegroundColor', c_text, 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'left');
    S.lbl_spd = uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.70 0.43 0.25 0.035], ...
        'String', '1.0x', 'FontName', 'Segoe UI', 'FontSize', 8.5, ...
        'FontWeight', 'bold', 'ForegroundColor', c_cyan, 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'right');
    S.sld_spd = uicontrol('Parent', ctrl_panel, 'Style', 'slider', ...
        'Units', 'normalized', 'Position', [0.05 0.39 0.90 0.035], ...
        'Min', 0.4, 'Max', 2.5, 'Value', 1.0, ...
        'BackgroundColor', c_card, ...
        'Callback', @(sld, ~) update_params());

    % Output Ports Power Matrix Display
    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.31 0.90 0.035], ...
        'String', 'PORT POWER DISTRIBUTION:', 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'FontWeight', 'bold', 'ForegroundColor', c_cyan, ...
        'BackgroundColor', c_panel, 'HorizontalAlignment', 'left');

    S.port_metrics_box = uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.03 0.90 0.27], ...
        'String', sprintf('Input  : Port 1 (10.0 mW)\nOutput : Port 2\n\n[Power Distribution]\nPort 1 : 0.003 mW (Leakage)\nPort 2 : 8.710 mW (Routed)\nPort 3 : 0.003 mW (Leakage)\n\nMatrix Routing: [2, 1] = 0.871'), ...
        'FontName', 'Consolas', 'FontSize', 8.0, ...
        'ForegroundColor', [0.85 0.95 0.85], 'BackgroundColor', c_card, ...
        'HorizontalAlignment', 'left');

    % Draw static apparatus on canvas
    draw_schematic();

    % Store state
    fig.UserData = S;

    % -------------------------------------------------------------
    % Nested functions for UI events & Animation
    % -------------------------------------------------------------

    function select_port(port_num)
        S.selected_port = port_num;

        % Reset button colors
        set(S.btn_port1, 'BackgroundColor', c_card, 'ForegroundColor', [0.8 0.9 1]);
        set(S.btn_port2, 'BackgroundColor', c_card, 'ForegroundColor', [0.8 0.9 1]);
        set(S.btn_port3, 'BackgroundColor', c_card, 'ForegroundColor', [0.8 0.9 1]);

        target_port = mod(port_num, 3) + 1;

        if port_num == 1
            set(S.btn_port1, 'BackgroundColor', c_cyan, 'ForegroundColor', [0.05 0.08 0.15]);
        elseif port_num == 2
            set(S.btn_port2, 'BackgroundColor', c_cyan, 'ForegroundColor', [0.05 0.08 0.15]);
        else
            set(S.btn_port3, 'BackgroundColor', c_cyan, 'ForegroundColor', [0.05 0.08 0.15]);
        end

        set(S.btn_launch, 'String', sprintf('Route Pulse (%d -> %d)', port_num, target_port));
        set(S.status_text, 'String', sprintf('Selected: Port %d as Input. Signal will route to Port %d.', port_num, target_port));

        update_port_metrics();
        highlight_active_path();
        fig.UserData = S;
    end

    function update_mode()
        val = get(S.pop_mode, 'Value');
        if val == 1
            S.mode = 'ideal';
        else
            S.mode = 'realistic';
        end
        update_port_metrics();
        fig.UserData = S;
    end

    function update_params()
        S.input_power = get(S.sld_pwr, 'Value');
        S.speed = get(S.sld_spd, 'Value');
        set(S.lbl_pwr, 'String', sprintf('%.1f mW', S.input_power));
        set(S.lbl_spd, 'String', sprintf('%.1fx', S.speed));
        update_port_metrics();
        fig.UserData = S;
    end

    function update_port_metrics()
        pin = S.input_power;
        in_p = S.selected_port;
        out_p = mod(in_p, 3) + 1;

        if strcmp(S.mode, 'ideal')
            p_out = zeros(3, 1);
            p_out(out_p) = pin;
            desc = 'Ideal: 100% Routed, 0 Loss';
        else
            p_routed = pin * 10^(-S.insertion_loss / 10);
            p_leak   = pin * 10^(-S.isolation / 10);
            p_out = [p_leak; p_leak; p_leak];
            p_out(out_p) = p_routed;
            desc = sprintf('Realistic (IL=%.1fdB, ISO=%.1fdB)', S.insertion_loss, S.isolation);
        end

        set(S.port_metrics_box, 'String', sprintf(...
            'Input  : Port %d (%.1f mW)\nTarget : Port %d\nModel  : %s\n\n[Output Powers]\nPort 1 : %.3f mW %s\nPort 2 : %.3f mW %s\nPort 3 : %.3f mW %s', ...
            in_p, pin, out_p, desc, ...
            p_out(1), cond_str(out_p == 1, '(Routed)', '(Leak)'), ...
            p_out(2), cond_str(out_p == 2, '(Routed)', '(Leak)'), ...
            p_out(3), cond_str(out_p == 3, '(Routed)', '(Leak)')));
    end

    function s = cond_str(cond, a, b)
        if cond, s = a; else, s = b; end
    end

    function draw_schematic()
        cla(ax);
        hold(ax, 'on');

        % Center of circulator body
        cx = 50; cy = 33; cr = 14;

        % 1. Optical Fibers:
        % Port 1: Left horizontal from x = 12 to x = 36 at y = 33
        draw_fiber(ax, [12 36], [33 33], 4.5, [0.15 0.75 0.95], [0.16 0.22 0.32]);
        draw_device_box(ax, 11, 33, 9, 11, [0.08 0.12 0.20], c_cyan, 'PORT 1', 'Input/Output');

        % Port 2: Top-Right (angle +45 deg): from (cx + cr*cos(45), cy + cr*sin(45)) -> out to (86, 56)
        x2_start = cx + cr * cosd(45);
        y2_start = cy + cr * sind(45);
        draw_fiber(ax, [x2_start 85], [y2_start 56], 4.5, [0.15 0.75 0.95], [0.16 0.22 0.32]);
        draw_device_box(ax, 88, 56, 9, 11, [0.08 0.12 0.20], c_green, 'PORT 2', 'Output/Input');

        % Port 3: Bottom-Right (angle -45 deg): from (cx + cr*cos(-45), cy + cr*sin(-45)) -> out to (86, 10)
        x3_start = cx + cr * cosd(-45);
        y3_start = cy + cr * sind(-45);
        draw_fiber(ax, [x3_start 85], [y3_start 10], 4.5, [0.15 0.75 0.95], [0.16 0.22 0.32]);
        draw_device_box(ax, 88, 10, 9, 11, [0.08 0.12 0.20], c_amber, 'PORT 3', 'Output/Input');

        % 2. Central Circulator Housing (Circular with metallic gradient)
        theta = linspace(0, 2*pi, 100);
        patch(ax, cx + (cr+1)*cos(theta), cy + (cr+1)*sin(theta), [0.14 0.18 0.28], ...
            'EdgeColor', [0.35 0.65 0.95], 'LineWidth', 2.5);
        patch(ax, cx + cr*cos(theta), cy + cr*sin(theta), [0.08 0.12 0.20], ...
            'EdgeColor', [0.20 0.40 0.70], 'LineWidth', 1.5);

        % Title on Circulator Body
        text(ax, cx, cy + 3.5, sprintf('OPTICAL\nCIRCULATOR'), ...
            'Color', c_text, 'FontSize', 9.5, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center');
        text(ax, cx, cy - 5.5, 'Non-Reciprocal Magneto-Optic', ...
            'Color', c_subtext, 'FontSize', 7, 'HorizontalAlignment', 'center');

        % 3. Directional Non-Reciprocal Cyclic Arrows inside circulator: 1 -> 2 -> 3 -> 1
        draw_cyclic_arrow(cx, cy, 7.5);

        highlight_active_path();
    end

    function draw_cyclic_arrow(cx, cy, r)
        t = linspace(pi/6, 2*pi - pi/6, 60);
        plot(ax, cx + r*cos(t), cy + r*sin(t), ':', 'Color', [0.4 0.7 1.0], 'LineWidth', 1.8);

        % Three arrowheads indicating clockwise flow
        draw_arrowhead(cx + r*cosd(150), cy + r*sind(150), 30);
        draw_arrowhead(cx + r*cosd(10),  cy + r*sind(10), -70);
        draw_arrowhead(cx + r*cosd(270), cy + r*sind(270), 180);
    end

    function draw_arrowhead(x, y, angle_deg)
        head_len = 2.0;
        ang = angle_deg * pi / 180;
        p1 = [x, y];
        p2 = [x - head_len*cos(ang - pi/6), y - head_len*sin(ang - pi/6)];
        p3 = [x - head_len*cos(ang + pi/6), y - head_len*sin(ang + pi/6)];
        patch(ax, [p1(1) p2(1) p3(1)], [p1(2) p2(2) p3(2)], c_cyan, ...
            'EdgeColor', 'none', 'FaceAlpha', 0.85);
    end

    function highlight_active_path()
        delete(findobj(ax, 'Tag', 'active_path_glow'));

        in_p = S.selected_port;
        out_p = mod(in_p, 3) + 1;
        pts = get_route_points(in_p, out_p);

        plot(ax, pts(:, 1), pts(:, 2), '-', 'LineWidth', 6.0, ...
            'Color', [0.0 0.9 0.45 0.35], 'Tag', 'active_path_glow');
    end

    function pts = get_route_points(in_p, out_p)
        cx = 50; cy = 33; cr = 14;

        % Key coordinates:
        % Port 1: outside (12, 33), junction (cx - cr, cy) = (36, 33)
        % Port 2: outside (85, 56), junction (cx + cr*cosd(45), cy + cr*sind(45))
        % Port 3: outside (85, 10), junction (cx + cr*cosd(-45), cy + cr*sind(-45))

        j1 = [cx - cr, cy];
        j2 = [cx + cr*cosd(45), cy + cr*sind(45)];
        j3 = [cx + cr*cosd(-45), cy + cr*sind(-45)];

        if in_p == 1 && out_p == 2
            % Fiber 1: (12, 33) to j1
            f_in = [linspace(12, j1(1), 30)', repmat(33, 30, 1)];
            % Inside arc: from 180 deg to 45 deg clockwise (180 -> 45)
            theta = linspace(pi, pi/4, 35)';
            arc = [cx + cr*0.65*cos(theta), cy + cr*0.65*sin(theta)];
            % Fiber 2: j2 to (85, 56)
            f_out = [linspace(j2(1), 85, 30)', linspace(j2(2), 56, 30)'];
            pts = [f_in; arc; f_out];

        elseif in_p == 2 && out_p == 3
            % Fiber 2 in: (85, 56) to j2
            f_in = [linspace(85, j2(1), 30)', linspace(56, j2(2), 30)'];
            % Inside arc: from 45 deg to -45 deg clockwise
            theta = linspace(pi/4, -pi/4, 35)';
            arc = [cx + cr*0.65*cos(theta), cy + cr*0.65*sin(theta)];
            % Fiber 3 out: j3 to (85, 10)
            f_out = [linspace(j3(1), 85, 30)', linspace(j3(2), 10, 30)'];
            pts = [f_in; arc; f_out];

        else % in_p == 3 && out_p == 1
            % Fiber 3 in: (85, 10) to j3
            f_in = [linspace(85, j3(1), 30)', linspace(10, j3(2), 30)'];
            % Inside arc: from -45 deg to -180 deg clockwise (-pi/4 -> -pi)
            theta = linspace(-pi/4, -pi, 35)';
            arc = [cx + cr*0.65*cos(theta), cy + cr*0.65*sin(theta)];
            % Fiber 1 out: j1 to (12, 33)
            f_out = [linspace(j1(1), 12, 30)', repmat(33, 30, 1)];
            pts = [f_in; arc; f_out];
        end
    end

    function toggle_pause()
        if ~S.is_running, return; end
        S.is_paused = ~S.is_paused;
        if S.is_paused
            set(S.btn_pause, 'String', 'Resume', 'BackgroundColor', [0.15 0.55 0.35]);
            set(S.status_text, 'String', [get(S.status_text, 'String'), ' [PAUSED]']);
        else
            set(S.btn_pause, 'String', 'Pause', 'BackgroundColor', [0.35 0.45 0.55]);
        end
        fig.UserData = S;
    end

    function reset_animation()
        S.stop_requested = true;
        S.is_running = false;
        S.is_paused = false;
        clean_pulses();
        set(S.btn_pause, 'String', 'Pause', 'BackgroundColor', [0.35 0.45 0.55]);
        set(S.status_text, 'String', 'Simulation reset. Ready for next route.');
        fig.UserData = S;
    end

    function clean_pulses()
        delete(findobj(ax, 'Tag', 'pulse_object'));
    end

    function start_animation()
        if S.is_running, return; end

        S.is_running = true;
        S.is_paused = false;
        S.stop_requested = false;
        clean_pulses();

        in_p = S.selected_port;
        out_p = mod(in_p, 3) + 1;
        pts = get_route_points(in_p, out_p);
        spd = S.speed;
        pin = S.input_power;

        if strcmp(S.mode, 'ideal')
            p_rec = pin;
        else
            p_rec = pin * 10^(-S.insertion_loss / 10);
        end

        % Luminous routed pulse
        pulse_core = plot(ax, pts(1, 1), pts(1, 2), 'o', 'MarkerSize', 11, ...
            'MarkerFaceColor', [1 1 1], 'MarkerEdgeColor', c_green, ...
            'LineWidth', 2.0, 'Tag', 'pulse_object');
        pulse_glow = plot(ax, pts(1, 1), pts(1, 2), 'o', 'MarkerSize', 22, ...
            'MarkerFaceColor', [0 0.9 0.4], 'MarkerEdgeColor', 'none', ...
            'Tag', 'pulse_object');
        pulse_tail = plot(ax, [pts(1,1) pts(1,1)], [pts(1,2) pts(1,2)], '-', ...
            'LineWidth', 5.0, 'Color', [c_green 0.5], 'Tag', 'pulse_object');

        n_pts = size(pts, 1);
        dt = 0.024 / spd;

        for k = 1:n_pts
            if S.stop_requested || ~ishandle(ax), return; end
            while S.is_paused
                pause(0.08);
                if S.stop_requested, return; end
            end

            curr_pos = pts(k, :);
            tail_idx = max(1, k - 4);
            tail_pos = pts(tail_idx, :);

            % Real-time physical stage explanations
            frac = k / n_pts;
            if frac < 0.30
                set(S.status_text, 'String', sprintf(...
                    '1. [GENERATION & INJECTION] Optical pulse generated and entering Port %d input fiber (Pin = %.1f mW)...', in_p, pin));
            elseif frac >= 0.30 && frac < 0.70
                set(S.status_text, 'String', sprintf(...
                    '2. [CIRCULATOR ROUTING] Pulse inside magneto-optic core. Polarization rotation steers beam non-reciprocally toward Port %d...', out_p));
            elseif frac >= 0.70 && frac < 0.95
                set(S.status_text, 'String', sprintf(...
                    '3. [OUTPUT TRANSMISSION] Pulse exiting circulator housing and propagating down Port %d output fiber...', out_p));
            else
                set(S.status_text, 'String', sprintf(...
                    '4. [ROUTING COMPLETE] Port %d -> Port %d successful! Received Power = %.3f mW.', in_p, out_p, p_rec));
            end

            set(pulse_core, 'XData', curr_pos(1), 'YData', curr_pos(2));
            set(pulse_glow, 'XData', curr_pos(1), 'YData', curr_pos(2));
            set(pulse_tail, 'XData', [tail_pos(1) curr_pos(1)], 'YData', [tail_pos(2) curr_pos(2)]);

            drawnow;
            pause(dt);
        end

        % Flash destination port
        flash_target_port(out_p);

        S.is_running = false;
        fig.UserData = S;
    end

    function flash_target_port(port_num)
        if port_num == 1
            x = 11; y = 33;
        elseif port_num == 2
            x = 88; y = 56;
        else
            x = 88; y = 10;
        end

        flash = patch(ax, [x-4.5 x+4.5 x+4.5 x-4.5], [y-5.5 y-5.5 y+5.5 y+5.5], c_green, ...
            'FaceAlpha', 0.6, 'EdgeColor', [1 1 1], 'LineWidth', 2.0, 'Tag', 'pulse_object');
        for i = 1:4
            pause(0.06);
            if ~ishandle(flash), return; end
            set(flash, 'FaceAlpha', 0.1);
            pause(0.06);
            set(flash, 'FaceAlpha', 0.6);
        end
        delete(flash);
    end

    function handle_back_click()
        S.stop_requested = true;
        S.is_running = false;
        S.is_paused = false;
        fig.UserData = S;
        if ~isempty(on_back_cb)
            feval(on_back_cb);
        end
    end
end
