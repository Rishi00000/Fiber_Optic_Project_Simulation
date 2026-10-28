function fig = animate_isolator(parent_fig, parent_panel, on_back_cb)
% ANIMATE_ISOLATOR Interactive Animated Simulation of a Fiber Optic Isolator.
% Features:
% - Real-time animation of optical pulse propagation along optical fibers.
% - Forward transmission: 0° Polarizer -> 45° Faraday Rotator -> 45° Analyzer -> Output.
% - Reverse isolation: 45° Analyzer -> 45° Rotator (total 90°) -> Blocked by 0° Polarizer.
% - Interactive controls: Forward/Reverse launch, Power, Loss, Isolation, Speed.
% - Scientific dark navy/charcoal UI compatible with MATLAB Desktop and MATLAB Online.

    addpath(fullfile(fileparts(mfilename('fullpath')), 'helpers'));

    standalone = (nargin < 1 || isempty(parent_fig));
    if nargin < 3, on_back_cb = []; end

    if standalone
        scr = get(0, 'ScreenSize');
        fig_w = min(1140, max(750, round(scr(3) * 0.92)));
        fig_h = min(580, max(460, round(scr(4) * 0.74)));
        fig_x = max(15, round((scr(3) - fig_w) / 2));
        fig_y = max(45, round((scr(4) - fig_h) / 2));

        fig = figure('Name', 'Module A: Fiber Optic Isolator Simulation', ...
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
    S.direction = 'forward'; % 'forward' or 'reverse'
    S.input_power = 10.0;    % mW
    S.insertion_loss = 0.5;  % dB
    S.isolation = 30.0;      % dB
    S.speed = 1.0;
    S.pulse_handles = [];
    S.standalone = standalone;

    % Palette
    c_bg      = [0.06 0.08 0.13];
    c_panel   = [0.10 0.13 0.20];
    c_card    = [0.13 0.17 0.26];
    c_border  = [0.22 0.32 0.48];
    c_cyan    = [0.00 0.90 1.00];
    c_blue    = [0.20 0.60 1.00];
    c_green   = [0.00 0.90 0.45];
    c_red     = [1.00 0.25 0.35];
    c_amber   = [1.00 0.75 0.15];
    c_text    = [0.92 0.95 0.98];
    c_subtext = [0.65 0.75 0.88];

    % Header Panel
    uicontrol('Parent', main_container, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.02 0.93 0.75 0.055], ...
        'String', 'FIBER OPTIC ISOLATOR: NON-RECIPROCAL TRANSMISSION & ISOLATION', ...
        'FontName', 'Segoe UI', 'FontSize', 13, 'FontWeight', 'bold', ...
        'ForegroundColor', c_cyan, 'BackgroundColor', c_bg, ...
        'HorizontalAlignment', 'left');

    uicontrol('Parent', main_container, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.02 0.89 0.75 0.035], ...
        'String', 'Demonstrates forward low-loss propagation and reverse magnetic-optical blocking using Faraday rotation.', ...
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
        'XLim', [0 100], 'YLim', [0 60]);
    axis(ax, 'equal');
    hold(ax, 'on');
    S.ax = ax;

    % Controls Panel (Right Side)
    ctrl_panel = uipanel('Parent', main_container, ...
        'Units', 'normalized', 'Position', [0.73 0.02 0.25 0.89], ...
        'BackgroundColor', c_panel, 'BorderColor', c_border, ...
        'HighlightColor', c_border, ...
        'Title', ' CONTROLS & METRICS ', ...
        'FontName', 'Segoe UI', 'FontSize', 11, 'FontWeight', 'bold', ...
        'ForegroundColor', c_cyan);

    % Status & Explanation Panel (Bottom Left)
    status_panel = uipanel('Parent', main_container, ...
        'Units', 'normalized', 'Position', [0.02 0.02 0.70 0.23], ...
        'BackgroundColor', c_panel, 'BorderColor', c_border, ...
        'HighlightColor', c_border, ...
        'Title', ' REAL-TIME PHYSICAL EXPLANATION ', ...
        'FontName', 'Segoe UI', 'FontSize', 10, 'FontWeight', 'bold', ...
        'ForegroundColor', c_cyan);

    S.status_text = uicontrol('Parent', status_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.02 0.04 0.96 0.88], ...
        'String', 'Ready. Select propagation direction (Forward or Reverse) and press Launch Pulse to observe light propagation.', ...
        'FontName', 'Consolas', 'FontSize', 8.8, ...
        'ForegroundColor', [0.88 0.94 1.00], 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'left');

    % Controls inside ctrl_panel
    % Direction toggle
    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.93 0.90 0.04], ...
        'String', 'PROPAGATION DIRECTION:', 'FontName', 'Segoe UI', ...
        'FontSize', 9, 'FontWeight', 'bold', 'ForegroundColor', c_cyan, ...
        'BackgroundColor', c_panel, 'HorizontalAlignment', 'left');

    S.dir_btn_fwd = uicontrol('Parent', ctrl_panel, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.05 0.87 0.43 0.055], ...
        'String', 'Forward -->', 'FontName', 'Segoe UI', 'FontSize', 9.5, ...
        'FontWeight', 'bold', 'ForegroundColor', [1 1 1], ...
        'BackgroundColor', [0.05 0.55 0.35], ...
        'Callback', @(btn, ~) set_direction('forward'));

    S.dir_btn_rev = uicontrol('Parent', ctrl_panel, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.52 0.87 0.43 0.055], ...
        'String', '<-- Reverse', 'FontName', 'Segoe UI', 'FontSize', 9.5, ...
        'FontWeight', 'bold', 'ForegroundColor', [0.8 0.9 1], ...
        'BackgroundColor', c_card, ...
        'Callback', @(btn, ~) set_direction('reverse'));

    % Launch / Pause / Reset buttons
    S.btn_launch = uicontrol('Parent', ctrl_panel, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.05 0.79 0.90 0.065], ...
        'String', 'Launch Pulse', 'FontName', 'Segoe UI', 'FontSize', 11, ...
        'FontWeight', 'bold', 'ForegroundColor', [0.05 0.08 0.15], ...
        'BackgroundColor', c_cyan, ...
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

    % Sliders & Parameters
    % 1. Input Power
    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.65 0.65 0.035], ...
        'String', 'Laser Power (Pin):', 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'ForegroundColor', c_text, 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'left');
    S.lbl_pwr = uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.70 0.65 0.25 0.035], ...
        'String', '10.0 mW', 'FontName', 'Segoe UI', 'FontSize', 8.5, ...
        'FontWeight', 'bold', 'ForegroundColor', c_amber, 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'right');
    S.sld_pwr = uicontrol('Parent', ctrl_panel, 'Style', 'slider', ...
        'Units', 'normalized', 'Position', [0.05 0.61 0.90 0.035], ...
        'Min', 1.0, 'Max', 30.0, 'Value', 10.0, ...
        'BackgroundColor', c_card, ...
        'Callback', @(sld, ~) update_params());

    % 2. Insertion Loss
    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.55 0.65 0.035], ...
        'String', 'Insertion Loss (IL):', 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'ForegroundColor', c_text, 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'left');
    S.lbl_il = uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.70 0.55 0.25 0.035], ...
        'String', '0.50 dB', 'FontName', 'Segoe UI', 'FontSize', 8.5, ...
        'FontWeight', 'bold', 'ForegroundColor', c_amber, 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'right');
    S.sld_il = uicontrol('Parent', ctrl_panel, 'Style', 'slider', ...
        'Units', 'normalized', 'Position', [0.05 0.51 0.90 0.035], ...
        'Min', 0.1, 'Max', 3.0, 'Value', 0.5, ...
        'BackgroundColor', c_card, ...
        'Callback', @(sld, ~) update_params());

    % 3. Reverse Isolation
    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.45 0.65 0.035], ...
        'String', 'Reverse Isolation (ISO):', 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'ForegroundColor', c_text, 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'left');
    S.lbl_iso = uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.70 0.45 0.25 0.035], ...
        'String', '30.0 dB', 'FontName', 'Segoe UI', 'FontSize', 8.5, ...
        'FontWeight', 'bold', 'ForegroundColor', c_amber, 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'right');
    S.sld_iso = uicontrol('Parent', ctrl_panel, 'Style', 'slider', ...
        'Units', 'normalized', 'Position', [0.05 0.41 0.90 0.035], ...
        'Min', 15.0, 'Max', 50.0, 'Value', 30.0, ...
        'BackgroundColor', c_card, ...
        'Callback', @(sld, ~) update_params());

    % 4. Animation Speed
    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.35 0.65 0.035], ...
        'String', 'Animation Speed:', 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'ForegroundColor', c_text, 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'left');
    S.lbl_spd = uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.70 0.35 0.25 0.035], ...
        'String', '1.0x', 'FontName', 'Segoe UI', 'FontSize', 8.5, ...
        'FontWeight', 'bold', 'ForegroundColor', c_cyan, 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'right');
    S.sld_spd = uicontrol('Parent', ctrl_panel, 'Style', 'slider', ...
        'Units', 'normalized', 'Position', [0.05 0.31 0.90 0.035], ...
        'Min', 0.4, 'Max', 2.5, 'Value', 1.0, ...
        'BackgroundColor', c_card, ...
        'Callback', @(sld, ~) update_params());

    % Numerical Output Metrics Display Area
    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.24 0.90 0.035], ...
        'String', 'POWER & CONTRAST METRICS:', 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'FontWeight', 'bold', 'ForegroundColor', c_cyan, ...
        'BackgroundColor', c_panel, 'HorizontalAlignment', 'left');

    S.metrics_box = uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.03 0.90 0.20], ...
        'String', sprintf('Forward Pout : 8.913 mW\nReverse Pout : 0.010 mW\nContrast     : 29.50 dB\nEfficiency   : 89.1%%\nLeakage      : 0.100%%'), ...
        'FontName', 'Consolas', 'FontSize', 8.2, ...
        'ForegroundColor', [0.85 0.95 0.85], 'BackgroundColor', c_card, ...
        'HorizontalAlignment', 'left');

    % Draw static apparatus on canvas
    draw_schematic();

    % Store state in figure
    fig.UserData = S;

    % -------------------------------------------------------------
    % Nested functions for UI events & Animation
    % -------------------------------------------------------------

    function set_direction(dir_str)
        S.direction = dir_str;
        if strcmp(dir_str, 'forward')
            set(S.dir_btn_fwd, 'BackgroundColor', [0.05 0.55 0.35], 'ForegroundColor', [1 1 1]);
            set(S.dir_btn_rev, 'BackgroundColor', c_card, 'ForegroundColor', [0.8 0.9 1]);
            set(S.status_text, 'String', 'Direction: FORWARD (Laser Source -> Input Fiber -> Isolator -> Output Fiber).');
        else
            set(S.dir_btn_rev, 'BackgroundColor', [0.75 0.20 0.25], 'ForegroundColor', [1 1 1]);
            set(S.dir_btn_fwd, 'BackgroundColor', c_card, 'ForegroundColor', [0.8 0.9 1]);
            set(S.status_text, 'String', 'Direction: REVERSE (Output Reflector -> Backward Fiber -> Isolator -> Extinguished).');
        end
        draw_direction_arrows();
        fig.UserData = S;
    end

    function update_params()
        S.input_power = get(S.sld_pwr, 'Value');
        S.insertion_loss = get(S.sld_il, 'Value');
        S.isolation = get(S.sld_iso, 'Value');
        S.speed = get(S.sld_spd, 'Value');

        set(S.lbl_pwr, 'String', sprintf('%.1f mW', S.input_power));
        set(S.lbl_il, 'String', sprintf('%.2f dB', S.insertion_loss));
        set(S.lbl_iso, 'String', sprintf('%.1f dB', S.isolation));
        set(S.lbl_spd, 'String', sprintf('%.1fx', S.speed));

        % Calculate metrics
        p_fwd = S.input_power * 10^(-S.insertion_loss / 10);
        p_rev = S.input_power * 10^(-S.isolation / 10);
        contrast = S.isolation - S.insertion_loss;
        eff = (p_fwd / S.input_power) * 100;
        leak = (p_rev / S.input_power) * 100;

        set(S.metrics_box, 'String', sprintf(...
            'Forward Pout : %.3f mW\nReverse Pout : %.4f mW\nContrast     : %.2f dB\nEfficiency   : %.1f%%\nLeakage      : %.3f%%', ...
            p_fwd, p_rev, contrast, eff, leak));

        fig.UserData = S;
    end

    function draw_schematic()
        cla(ax);
        hold(ax, 'on');

        % 1. Optical Source (Left)
        draw_device_box(ax, 10, 30, 14, 18, [0.08 0.12 0.20], [0.2 0.6 0.9], 'LASER SOURCE', 'DFB 1550nm');
        % Diode icon
        plot(ax, [7 13], [30 30], 'Color', c_cyan, 'LineWidth', 2.5);
        plot(ax, [10 10], [25 35], 'Color', c_cyan, 'LineWidth', 2.0);
        patch(ax, [8 12 8], [26 30 34], c_blue, 'EdgeColor', c_cyan, 'FaceAlpha', 0.7);

        % 2. Input Fiber: x from 17 to 37, y = 30
        draw_fiber(ax, [17 37], [30 30], 4.5, [0.15 0.75 0.95], [0.16 0.22 0.32]);
        text(ax, 27, 34, 'Input Fiber Core', 'Color', c_subtext, 'FontSize', 8, 'HorizontalAlignment', 'center');

        % 3. Optical Isolator Assembly Housing: x from 37 to 67, y = 30
        draw_device_box(ax, 52, 30, 30, 24, [0.09 0.13 0.22], [0.35 0.65 0.95], 'OPTICAL ISOLATOR', 'Magneto-Optic Faraday Assembly');

        % Sub-components inside Isolator:
        % A. Polarizer 1 (0 deg - horizontal pass) at x = 42
        patch(ax, [41 43 43 41], [21 21 39 39], [0.15 0.22 0.32], 'EdgeColor', [0.4 0.7 1.0], 'LineWidth', 1.5);
        plot(ax, [39.5 44.5], [30 30], 'Color', [1 0.9 0.2], 'LineWidth', 2.5); % Horizontal pass axis indicator
        text(ax, 42, 18, sprintf('0° Polarizer\n(Input)'), 'Color', c_subtext, 'FontSize', 7.5, 'HorizontalAlignment', 'center');

        % B. Faraday Rotator Crystal at x = 52
        patch(ax, [47 57 57 47], [22 22 38 38], [0.20 0.12 0.30], 'EdgeColor', [0.8 0.4 1.0], 'LineWidth', 2.0);
        text(ax, 52, 30, sprintf('YIG Crystal\n+45° Rotator\nB ->'), 'Color', [0.95 0.7 1.0], 'FontSize', 7.5, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        % Magnetic field coil indicators
        plot(ax, [47 57], [37 37], 'r--', 'LineWidth', 1.2);
        plot(ax, [47 57], [23 23], 'r--', 'LineWidth', 1.2);

        % C. Analyzer Polarizer 2 (45 deg pass) at x = 62
        patch(ax, [61 63 63 61], [21 21 39 39], [0.15 0.22 0.32], 'EdgeColor', [0.4 0.7 1.0], 'LineWidth', 1.5);
        plot(ax, [60.5 63.5], [28 32], 'Color', [1 0.9 0.2], 'LineWidth', 2.5); % 45 deg pass axis indicator
        text(ax, 62, 18, sprintf('45° Analyzer\n(Output)'), 'Color', c_subtext, 'FontSize', 7.5, 'HorizontalAlignment', 'center');

        % 4. Output Fiber: x from 67 to 87, y = 30
        draw_fiber(ax, [67 87], [30 30], 4.5, [0.15 0.75 0.95], [0.16 0.22 0.32]);
        text(ax, 77, 34, 'Output Fiber Core', 'Color', c_subtext, 'FontSize', 8, 'HorizontalAlignment', 'center');

        % 5. Output Optical Power Meter / Reflector at x = 93
        draw_device_box(ax, 93, 30, 11, 18, [0.08 0.12 0.20], [0.2 0.8 0.4], 'POWER DETECTOR', 'Output Port');
        % Sensor target
        plot(ax, [93 93], [23 37], 'Color', c_green, 'LineWidth', 3.0);

        % Output Reflector indicator (clickable mirror)
        patch(ax, [88 89.5 89.5 88], [24 24 36 36], [0.7 0.8 0.9], 'EdgeColor', [1 1 1], 'LineWidth', 1.5);
        text(ax, 89, 40, 'Reflector/Facet', 'Color', [0.8 0.9 1.0], 'FontSize', 7, 'HorizontalAlignment', 'center');

        % Direction arrows
        draw_direction_arrows();
    end

    function draw_direction_arrows()
        % Delete existing arrows if present
        delete(findobj(ax, 'Tag', 'dir_arrow'));

        if strcmp(S.direction, 'forward')
            % Bright green forward arrows
            annotation_text = 'FORWARD: Transmission Allowed (IL = 0.5 dB)';
            text(ax, 52, 48, annotation_text, 'Color', c_green, 'FontSize', 10, ...
                'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Tag', 'dir_arrow');
            quiver(ax, 20, 44, 15, 0, 0, 'Color', c_green, 'LineWidth', 2.5, ...
                'MaxHeadSize', 2.0, 'Tag', 'dir_arrow');
            quiver(ax, 70, 44, 15, 0, 0, 'Color', c_green, 'LineWidth', 2.5, ...
                'MaxHeadSize', 2.0, 'Tag', 'dir_arrow');
        else
            % Bright red reverse arrows
            annotation_text = 'REVERSE: Backward Reflection Blocked (ISO >= 30 dB)';
            text(ax, 52, 48, annotation_text, 'Color', c_red, 'FontSize', 10, ...
                'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Tag', 'dir_arrow');
            quiver(ax, 85, 44, -15, 0, 0, 'Color', c_red, 'LineWidth', 2.5, ...
                'MaxHeadSize', 2.0, 'Tag', 'dir_arrow');
            quiver(ax, 45, 44, -15, 0, 0, 'Color', c_red, 'LineWidth', 2.5, ...
                'MaxHeadSize', 2.0, 'Tag', 'dir_arrow');
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
        set(S.status_text, 'String', 'Simulation reset. Ready for launch.');
        fig.UserData = S;
    end

    function clean_pulses()
        delete(findobj(ax, 'Tag', 'pulse_object'));
    end

    function start_animation()
        if S.is_running
            return;
        end

        S.is_running = true;
        S.is_paused = false;
        S.stop_requested = false;
        clean_pulses();

        p_in = S.input_power;
        il = S.insertion_loss;
        iso = S.isolation;
        spd = S.speed;

        p_fwd = p_in * 10^(-il / 10);
        p_rev = p_in * 10^(-iso / 10);

        if strcmp(S.direction, 'forward')
            run_forward_animation(p_in, p_fwd, il, spd);
        else
            run_reverse_animation(p_in, p_rev, iso, spd);
        end

        S.is_running = false;
        fig.UserData = S;
    end

    function run_forward_animation(p_in, p_fwd, il, spd)
        set(S.status_text, 'String', sprintf(...
            '1. [LASER GENERATION] Laser Diode emits coherent optical pulse at lambda = 1550 nm (Power: %.1f mW)...', p_in));

        % Create multi-layered luminous pulse
        pulse_core = plot(ax, 12, 30, 'o', 'MarkerSize', 11, ...
            'MarkerFaceColor', [1 1 1], 'MarkerEdgeColor', c_cyan, ...
            'LineWidth', 2.0, 'Tag', 'pulse_object');
        pulse_glow = plot(ax, 12, 30, 'o', 'MarkerSize', 22, ...
            'MarkerFaceColor', [0 0.8 1], 'MarkerEdgeColor', 'none', ...
            'Tag', 'pulse_object');
        pulse_tail = plot(ax, [12 12], [30 30], '-', 'LineWidth', 5.0, ...
            'Color', [c_cyan 0.5], 'Tag', 'pulse_object');

        x_path = linspace(12, 92, 160);
        dt = 0.025 / spd;

        for k = 1:length(x_path)
            if S.stop_requested || ~ishandle(ax), return; end
            while S.is_paused
                pause(0.08);
                if S.stop_requested, return; end
            end

            curr_x = x_path(k);
            tail_x = max(12, curr_x - 3.5);

            % Real-time physical stage explanations as pulse travels
            if curr_x >= 17 && curr_x < 37
                set(S.status_text, 'String', sprintf(...
                    '2. [INPUT FIBER] Pulse propagating through single-mode fiber core (Unpolarized/Random polarization). Pos: %.1f mm', curr_x));
            elseif curr_x >= 37 && curr_x < 44
                set(S.status_text, 'String', ...
                    '3. [INPUT POLARIZER] Passing 0° horizontal polarizer. Light is now linearly polarized at 0°.');
                set(pulse_core, 'MarkerEdgeColor', [1 0.9 0.2]);
            elseif curr_x >= 44 && curr_x < 58
                set(S.status_text, 'String', ...
                    '4. [FARADAY ROTATOR] Passing YIG crystal under magnetic field B. Polarization rotates non-reciprocally by +45°.');
                set(pulse_core, 'MarkerEdgeColor', [0.8 0.4 1.0]);
            elseif curr_x >= 58 && curr_x < 67
                set(S.status_text, 'String', sprintf(...
                    '5. [ANALYZER] Light arrives at 45° perfectly aligned with analyzer transmission axis! Transmission loss: %.2f dB.', il));
                set(pulse_core, 'MarkerEdgeColor', c_green);
            elseif curr_x >= 67 && curr_x < 88
                set(S.status_text, 'String', sprintf(...
                    '6. [OUTPUT FIBER] Pulse emerges cleanly into output fiber. Propagating toward detector with Power = %.3f mW.', p_fwd));
            elseif curr_x >= 88
                set(S.status_text, 'String', sprintf(...
                    '7. [DETECTION SUCCESS] Pulse absorbed at detector. FORWARD TRANSMISSION SUCCESSFUL! (Pout = %.3f mW, IL = %.2f dB).', p_fwd, il));
            end

            set(pulse_core, 'XData', curr_x);
            set(pulse_glow, 'XData', curr_x);
            set(pulse_tail, 'XData', [tail_x curr_x]);

            drawnow;
            pause(dt);
        end

        % Flash detector green on reception
        flash_detector(c_green);
    end

    function run_reverse_animation(p_in, p_rev, iso, spd)
        set(S.status_text, 'String', sprintf(...
            '1. [REVERSE LAUNCH] Backward reflected pulse (Fresnel reflection/connector return) launches at x = 88 mm (P_refl = %.1f mW)...', p_in));

        % Luminous reverse pulse (colored amber/red)
        pulse_core = plot(ax, 88, 30, 'o', 'MarkerSize', 11, ...
            'MarkerFaceColor', [1 0.8 0.8], 'MarkerEdgeColor', c_red, ...
            'LineWidth', 2.0, 'Tag', 'pulse_object');
        pulse_glow = plot(ax, 88, 30, 'o', 'MarkerSize', 22, ...
            'MarkerFaceColor', [1 0.2 0.3], 'MarkerEdgeColor', 'none', ...
            'Tag', 'pulse_object');
        pulse_tail = plot(ax, [88 88], [30 30], '-', 'LineWidth', 5.0, ...
            'Color', [c_red 0.5], 'Tag', 'pulse_object');

        x_path = linspace(88, 20, 160);
        dt = 0.025 / spd;

        for k = 1:length(x_path)
            if S.stop_requested || ~ishandle(ax), return; end
            while S.is_paused
                pause(0.08);
                if S.stop_requested, return; end
            end

            curr_x = x_path(k);
            tail_x = min(88, curr_x + 3.5);

            if curr_x <= 88 && curr_x > 67
                set(S.status_text, 'String', ...
                    '2. [BACKWARD FIBER] Reflected light travelling backward toward laser. Dangerous to optical cavity stability!');
            elseif curr_x <= 67 && curr_x > 58
                set(S.status_text, 'String', ...
                    '3. [ANALYZER ENTRY] Reverse light passes 45° analyzer and becomes linearly polarized at 45°.');
            elseif curr_x <= 58 && curr_x > 44
                set(S.status_text, 'String', ...
                    '4. [NON-RECIPROCAL FARADAY ROTATION] Faraday effect rotates by ANOTHER +45° in the same absolute direction! Polarization is now 90° (VERTICAL).');
            elseif curr_x <= 44 && curr_x > 40
                set(S.status_text, 'String', sprintf(...
                    '5. [BLOCKING ACTION] Light enters 0° horizontal polarizer polarized at 90°! cos^2(90°) = 0. LIGHT IS STRONGLY BLOCKED! (ISO = %.1f dB)', iso));

                % Dramatic visual extinction: pulse shrinks to near-zero size & dims
                set(pulse_core, 'MarkerSize', 3.0, 'MarkerFaceColor', [0.4 0.1 0.1], 'MarkerEdgeColor', [0.6 0 0]);
                set(pulse_glow, 'MarkerSize', 5.0, 'MarkerFaceColor', [0.3 0 0]);
                set(pulse_tail, 'LineWidth', 1.0, 'Color', [0.4 0 0]);
            elseif curr_x <= 40
                set(S.status_text, 'String', sprintf(...
                    '6. [LASER PROTECTED] Backward reflection suppressed! Residual leakage: %.4f mW. Laser cavity remains completely stable.', p_rev));
            end

            set(pulse_core, 'XData', curr_x);
            set(pulse_glow, 'XData', curr_x);
            set(pulse_tail, 'XData', [tail_x curr_x]);

            drawnow;
            pause(dt);
        end

        % Flash blocker red
        flash_blocker();
    end

    function flash_detector(flash_col)
        flash_patch = patch(ax, [90 96 96 90], [21 21 39 39], flash_col, ...
            'FaceAlpha', 0.6, 'EdgeColor', 'none', 'Tag', 'pulse_object');
        for i = 1:4
            pause(0.06);
            if ~ishandle(flash_patch), return; end
            set(flash_patch, 'FaceAlpha', 0.1);
            pause(0.06);
            set(flash_patch, 'FaceAlpha', 0.5);
        end
        delete(flash_patch);
    end

    function flash_blocker()
        flash_patch = patch(ax, [40 44 44 40], [20 20 40 40], c_red, ...
            'FaceAlpha', 0.7, 'EdgeColor', [1 0.5 0.5], 'LineWidth', 2.0, 'Tag', 'pulse_object');
        for i = 1:5
            pause(0.05);
            if ~ishandle(flash_patch), return; end
            set(flash_patch, 'FaceAlpha', 0.1);
            pause(0.05);
            set(flash_patch, 'FaceAlpha', 0.7);
        end
        delete(flash_patch);
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
