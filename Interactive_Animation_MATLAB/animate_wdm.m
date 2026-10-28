function fig = animate_wdm(parent_fig, parent_panel, on_back_cb)
% ANIMATE_WDM Interactive Animated Simulation of Wavelength Division Multiplexing.
% Features:
% - 4 Distinct wavelength channels (1530nm, 1540nm, 1550nm, 1560nm) in optical C-band.
% - Multi-stage staged animation:
%     Stage 1: Transmitters generate colored optical pulses.
%     Stage 2: Pulses travel along separate input fibers.
%     Stage 3: Optical Multiplexer (MUX) combines channels into a single fiber core.
%     Stage 4: Co-propagation through shared fiber with distance-dependent attenuation & chromatic dispersion.
%     Stage 5: Optical Demultiplexer (DEMUX) separates channels by wavelength.
%     Stage 6: Individual pulses travel along branch fibers into dedicated receivers.
% - Interactive channel toggles, fiber length control (10 to 80 km), speed slider.
% - Full play/pause/resume/reset controls.

    addpath(fullfile(fileparts(mfilename('fullpath')), 'helpers'));

    standalone = (nargin < 1 || isempty(parent_fig));
    if nargin < 3, on_back_cb = []; end

    if standalone
        scr = get(0, 'ScreenSize');
        fig_w = min(1140, max(750, round(scr(3) * 0.92)));
        fig_h = min(580, max(460, round(scr(4) * 0.74)));
        fig_x = max(15, round((scr(3) - fig_w) / 2));
        fig_y = max(45, round((scr(4) - fig_h) / 2));

        fig = figure('Name', 'Module C: WDM Fiber Optic Simulation', ...
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
    S.active_channels = [true, true, true, true];
    S.fiber_length_km = 50.0;
    S.attenuation_rate = 0.20; % dB/km
    S.dispersion_d = 17.0;     % ps/(nm*km)
    S.speed = 1.0;
    S.standalone = standalone;

    % Palette
    c_bg      = [0.06 0.08 0.13];
    c_panel   = [0.10 0.13 0.20];
    c_card    = [0.13 0.17 0.26];
    c_border  = [0.22 0.32 0.48];
    c_text    = [0.92 0.95 0.98];
    c_subtext = [0.65 0.75 0.88];

    % Wavelength channel colors
    c_ch = [
        0.00 0.90 1.00;   % Ch 1: 1530 nm (Cyan)
        0.00 0.92 0.45;   % Ch 2: 1540 nm (Green)
        1.00 0.82 0.15;   % Ch 3: 1550 nm (Amber/Gold)
        1.00 0.25 0.45    % Ch 4: 1560 nm (Red/Magenta)
    ];

    % Header Panel
    uicontrol('Parent', main_container, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.02 0.93 0.75 0.055], ...
        'String', 'WAVELENGTH DIVISION MULTIPLEXING (WDM): MULTI-CHANNEL FIBER LINK', ...
        'FontName', 'Segoe UI', 'FontSize', 13, 'FontWeight', 'bold', ...
        'ForegroundColor', [0.00 0.90 1.00], 'BackgroundColor', c_bg, ...
        'HorizontalAlignment', 'left');

    uicontrol('Parent', main_container, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.02 0.89 0.75 0.035], ...
        'String', 'Visualizes multiplexing 4 optical channels (1530-1560 nm), co-propagation in shared fiber, and demultiplexing to receivers.', ...
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
        'Title', ' WDM CONTROLS & LINK STATUS ', ...
        'FontName', 'Segoe UI', 'FontSize', 11, 'FontWeight', 'bold', ...
        'ForegroundColor', [0.00 0.90 1.00]);

    % Status & Explanation Panel (Bottom Left)
    status_panel = uipanel('Parent', main_container, ...
        'Units', 'normalized', 'Position', [0.02 0.02 0.70 0.23], ...
        'BackgroundColor', c_panel, 'BorderColor', c_border, ...
        'HighlightColor', c_border, ...
        'Title', ' PHYSICAL PROPAGATION STAGE ', ...
        'FontName', 'Segoe UI', 'FontSize', 10, 'FontWeight', 'bold', ...
        'ForegroundColor', [0.00 0.90 1.00]);

    S.status_text = uicontrol('Parent', status_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.02 0.04 0.96 0.88], ...
        'String', 'Ready. Select active channels, adjust fiber distance, and press "Transmit WDM Channels" to animate.', ...
        'FontName', 'Consolas', 'FontSize', 8.8, ...
        'ForegroundColor', [0.88 0.94 1.00], 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'left');

    % Controls in Right Panel
    % Channel Toggles
    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.94 0.90 0.035], ...
        'String', 'TRANSMIT CHANNELS:', 'FontName', 'Segoe UI', ...
        'FontSize', 9, 'FontWeight', 'bold', 'ForegroundColor', [0.00 0.90 1.00], ...
        'BackgroundColor', c_panel, 'HorizontalAlignment', 'left');

    S.chk_ch1 = uicontrol('Parent', ctrl_panel, 'Style', 'checkbox', ...
        'Units', 'normalized', 'Position', [0.05 0.89 0.43 0.045], ...
        'String', 'Ch 1: 1530nm', 'Value', 1, 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'ForegroundColor', c_ch(1, :), 'BackgroundColor', c_panel, ...
        'Callback', @(chk, ~) update_channels());

    S.chk_ch2 = uicontrol('Parent', ctrl_panel, 'Style', 'checkbox', ...
        'Units', 'normalized', 'Position', [0.52 0.89 0.43 0.045], ...
        'String', 'Ch 2: 1540nm', 'Value', 1, 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'ForegroundColor', c_ch(2, :), 'BackgroundColor', c_panel, ...
        'Callback', @(chk, ~) update_channels());

    S.chk_ch3 = uicontrol('Parent', ctrl_panel, 'Style', 'checkbox', ...
        'Units', 'normalized', 'Position', [0.05 0.84 0.43 0.045], ...
        'String', 'Ch 3: 1550nm', 'Value', 1, 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'ForegroundColor', c_ch(3, :), 'BackgroundColor', c_panel, ...
        'Callback', @(chk, ~) update_channels());

    S.chk_ch4 = uicontrol('Parent', ctrl_panel, 'Style', 'checkbox', ...
        'Units', 'normalized', 'Position', [0.52 0.84 0.43 0.045], ...
        'String', 'Ch 4: 1560nm', 'Value', 1, 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'ForegroundColor', c_ch(4, :), 'BackgroundColor', c_panel, ...
        'Callback', @(chk, ~) update_channels());

    % Launch, Pause, Reset
    S.btn_launch = uicontrol('Parent', ctrl_panel, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.05 0.75 0.90 0.065], ...
        'String', 'Transmit WDM Channels', 'FontName', 'Segoe UI', 'FontSize', 11, ...
        'FontWeight', 'bold', 'ForegroundColor', [0.05 0.08 0.15], ...
        'BackgroundColor', [0.00 0.90 1.00], ...
        'Callback', @(btn, ~) start_animation());

    S.btn_pause = uicontrol('Parent', ctrl_panel, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.05 0.68 0.43 0.055], ...
        'String', 'Pause', 'FontName', 'Segoe UI', 'FontSize', 9.5, ...
        'ForegroundColor', [1 1 1], 'BackgroundColor', [0.35 0.45 0.55], ...
        'Callback', @(btn, ~) toggle_pause());

    S.btn_reset = uicontrol('Parent', ctrl_panel, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.52 0.68 0.43 0.055], ...
        'String', 'Reset', 'FontName', 'Segoe UI', 'FontSize', 9.5, ...
        'ForegroundColor', [1 1 1], 'BackgroundColor', [0.45 0.20 0.25], ...
        'Callback', @(btn, ~) reset_animation());

    % Sliders: Fiber Distance and Animation Speed
    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.61 0.65 0.035], ...
        'String', 'Fiber Link Length:', 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'ForegroundColor', c_text, 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'left');
    S.lbl_dist = uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.70 0.61 0.25 0.035], ...
        'String', '50.0 km', 'FontName', 'Segoe UI', 'FontSize', 8.5, ...
        'FontWeight', 'bold', 'ForegroundColor', [1.00 0.82 0.15], 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'right');
    S.sld_dist = uicontrol('Parent', ctrl_panel, 'Style', 'slider', ...
        'Units', 'normalized', 'Position', [0.05 0.57 0.90 0.035], ...
        'Min', 10.0, 'Max', 100.0, 'Value', 50.0, ...
        'BackgroundColor', c_card, ...
        'Callback', @(sld, ~) update_params());

    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.50 0.65 0.035], ...
        'String', 'Animation Speed:', 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'ForegroundColor', c_text, 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'left');
    S.lbl_spd = uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.70 0.50 0.25 0.035], ...
        'String', '1.0x', 'FontName', 'Segoe UI', 'FontSize', 8.5, ...
        'FontWeight', 'bold', 'ForegroundColor', [0.00 0.90 1.00], 'BackgroundColor', c_panel, ...
        'HorizontalAlignment', 'right');
    S.sld_spd = uicontrol('Parent', ctrl_panel, 'Style', 'slider', ...
        'Units', 'normalized', 'Position', [0.05 0.46 0.90 0.035], ...
        'Min', 0.4, 'Max', 2.5, 'Value', 1.0, ...
        'BackgroundColor', c_card, ...
        'Callback', @(sld, ~) update_params());

    % Optical Link Budget & Attenuation Display
    uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.39 0.90 0.035], ...
        'String', 'LINK BUDGET & DISPERSION:', 'FontName', 'Segoe UI', ...
        'FontSize', 8.5, 'FontWeight', 'bold', 'ForegroundColor', [0.00 0.90 1.00], ...
        'BackgroundColor', c_panel, 'HorizontalAlignment', 'left');

    S.link_metrics_box = uicontrol('Parent', ctrl_panel, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.05 0.03 0.90 0.35], ...
        'String', sprintf('Link Length : 50.0 km\nTotal Loss  : 10.0 dB\nP_out / P_in: 10.00%%\nDispersion  : +850 ps/nm\n\n[Active Channels]\nCh1 (1530nm): ONLINE\nCh2 (1540nm): ONLINE\nCh3 (1550nm): ONLINE\nCh4 (1560nm): ONLINE\n\nCapacity    : 4 x 10 Gbps\nSpectral Eff: High'), ...
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

    function update_channels()
        S.active_channels(1) = (get(S.chk_ch1, 'Value') == 1);
        S.active_channels(2) = (get(S.chk_ch2, 'Value') == 1);
        S.active_channels(3) = (get(S.chk_ch3, 'Value') == 1);
        S.active_channels(4) = (get(S.chk_ch4, 'Value') == 1);
        update_metrics();
        draw_schematic();
        fig.UserData = S;
    end

    function update_params()
        S.fiber_length_km = get(S.sld_dist, 'Value');
        S.speed = get(S.sld_spd, 'Value');
        set(S.lbl_dist, 'String', sprintf('%.1f km', S.fiber_length_km));
        set(S.lbl_spd, 'String', sprintf('%.1fx', S.speed));
        update_metrics();
        fig.UserData = S;
    end

    function update_metrics()
        L = S.fiber_length_km;
        loss_db = L * S.attenuation_rate;
        p_ratio = 10^(-loss_db / 10) * 100;
        total_disp = L * S.dispersion_d;

        ch_status = cell(4, 1);
        for m = 1:4
            if S.active_channels(m)
                ch_status{m} = 'ONLINE';
            else
                ch_status{m} = 'DISABLED';
            end
        end

        set(S.link_metrics_box, 'String', sprintf(...
            'Link Length : %.1f km\nTotal Loss  : %.2f dB\nP_out / P_in: %.2f%%\nDispersion  : +%.0f ps/nm\n\n[Active Channels]\nCh1 (1530nm): %s\nCh2 (1540nm): %s\nCh3 (1550nm): %s\nCh4 (1560nm): %s\n\nTotal Throughput: %d Gbps', ...
            L, loss_db, p_ratio, total_disp, ...
            ch_status{1}, ch_status{2}, ch_status{3}, ch_status{4}, ...
            sum(S.active_channels) * 10));
    end

    function draw_schematic()
        cla(ax);
        hold(ax, 'on');

        % Y coordinates for the 4 transmitter/receiver tiers
        y_tiers = [52, 40, 28, 16];
        wl_names = {'1530nm', '1540nm', '1550nm', '1560nm'};

        % 1. Transmitters (TX1 - TX4) on Left: x in [4, 12]
        for m = 1:4
            y_m = y_tiers(m);
            if S.active_channels(m)
                tx_col = c_ch(m, :);
                tx_alpha = 1.0;
            else
                tx_col = [0.3 0.35 0.4];
                tx_alpha = 0.4;
            end
            draw_device_box(ax, 8, y_m, 8, 8, [0.08 0.12 0.20], tx_col, sprintf('TX %d', m), wl_names{m});
        end

        % 2. Branch Input Fibers: from x = 12 to MUX input at x = 24
        % MUX is located at x = 27, center y = 34, height = 44
        mux_x_in = 24;
        mux_y_in = [44, 38, 30, 24];
        for m = 1:4
            draw_fiber(ax, [12 mux_x_in], [y_tiers(m) mux_y_in(m)], 3.0, c_ch(m, :), [0.16 0.22 0.32]);
        end

        % 3. Optical Multiplexer (MUX): Trapezoid at x in [24, 30]
        patch(ax, [24 30 30 24], [18 29 39 50], [0.12 0.18 0.28], ...
            'EdgeColor', [0.35 0.65 0.95], 'LineWidth', 2.0);
        text(ax, 27, 34, sprintf('WDM\nMUX'), 'Color', c_text, 'FontSize', 9, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'center');

        % 4. Shared Optical Transmission Fiber: from x = 30 to x = 70 at y = 34
        % Thick composite core representing co-propagation
        draw_fiber(ax, [30 70], [34 34], 7.0, [0.8 0.85 0.95], [0.18 0.26 0.38]);
        % Distance and technology label
        text(ax, 50, 40, sprintf('Single Shared Optical Fiber (L = %.0f km)', S.fiber_length_km), ...
            'Color', [0.8 0.9 1], 'FontSize', 9, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        text(ax, 50, 29, 'Multi-Wavelength Simultaneous Co-Propagation (C-Band)', ...
            'Color', c_subtext, 'FontSize', 7.5, 'FontAngle', 'italic', 'HorizontalAlignment', 'center');

        % 5. Optical Demultiplexer (DEMUX): Trapezoid at x in [70, 76]
        patch(ax, [70 76 76 70], [29 18 50 39], [0.12 0.18 0.28], ...
            'EdgeColor', [0.35 0.65 0.95], 'LineWidth', 2.0);
        text(ax, 73, 34, sprintf('WDM\nDEMUX'), 'Color', c_text, 'FontSize', 9, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'center');

        % 6. Branch Output Fibers: from DEMUX output at x = 76 to RX at x = 88
        demux_x_out = 76;
        demux_y_out = [44, 38, 30, 24];
        for m = 1:4
            draw_fiber(ax, [demux_x_out 88], [demux_y_out(m) y_tiers(m)], 3.0, c_ch(m, :), [0.16 0.22 0.32]);
        end

        % 7. Receivers (RX1 - RX4) on Right: x in [88, 96]
        for m = 1:4
            y_m = y_tiers(m);
            if S.active_channels(m)
                rx_col = c_ch(m, :);
            else
                rx_col = [0.3 0.35 0.4];
            end
            draw_device_box(ax, 92, y_m, 8, 8, [0.08 0.12 0.20], rx_col, sprintf('RX %d', m), wl_names{m});
        end

        % Explanatory caption on false colors
        text(ax, 50, 4, '*Note: Colors are graphical representations of distinct infrared wavelengths (1530-1560 nm) in the telecom C-band.', ...
            'Color', [0.55 0.65 0.75], 'FontSize', 7.5, 'HorizontalAlignment', 'center');
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
        set(S.status_text, 'String', 'Simulation reset. Ready for next WDM transmission.');
        fig.UserData = S;
    end

    function clean_pulses()
        delete(findobj(ax, 'Tag', 'wdm_pulse'));
    end

    function start_animation()
        if S.is_running, return; end
        if ~any(S.active_channels)
            set(S.status_text, 'String', 'Please enable at least one channel to simulate transmission.');
            return;
        end

        S.is_running = true;
        S.is_paused = false;
        S.stop_requested = false;
        clean_pulses();

        spd = S.speed;
        y_tiers = [52, 40, 28, 16];
        mux_y_in = [44, 38, 30, 24];
        demux_y_out = [44, 38, 30, 24];

        % STAGE 1 & 2: Launch pulses from Transmitters -> travel down branch fibers -> arrive at MUX
        set(S.status_text, 'String', '1. [INDEPENDENT CHANNEL EMISSION] Laser Transmitters generate optical pulses at assigned wavelengths (1530-1560 nm)...');

        pulses = cell(4, 1);
        for m = 1:4
            if S.active_channels(m)
                pulses{m} = plot(ax, 12, y_tiers(m), 'o', 'MarkerSize', 9, ...
                    'MarkerFaceColor', c_ch(m, :), 'MarkerEdgeColor', [1 1 1], ...
                    'LineWidth', 1.5, 'Tag', 'wdm_pulse');
            end
        end

        n_steps_in = 35;
        dt = 0.024 / spd;

        for k = 1:n_steps_in
            if S.stop_requested || ~ishandle(ax), return; end
            while S.is_paused
                pause(0.08);
                if S.stop_requested, return; end
            end

            t_frac = k / n_steps_in;
            for m = 1:4
                if S.active_channels(m)
                    x_pos = 12 + t_frac * (24 - 12);
                    y_pos = y_tiers(m) + t_frac * (mux_y_in(m) - y_tiers(m));
                    set(pulses{m}, 'XData', x_pos, 'YData', y_pos);
                end
            end
            drawnow;
            pause(dt);
        end

        % STAGE 3: Multiplexing inside MUX
        set(S.status_text, 'String', '2. [WDM MULTIPLEXING] Pulses enter Optical Multiplexer (Arrayed Waveguide Grating / Thin Film Filter) and are coupled into a single fiber...');
        flash_element(27, 34, 6, 20, [0.3 0.7 1.0]);

        % STAGE 4: Co-propagation along shared fiber (x = 30 to 70 at y = 34)
        set(S.status_text, 'String', sprintf(...
            '3. [CO-PROPAGATION IN SHARED FIBER] All %d wavelength channels travel simultaneously through the single fiber core over %.0f km...', ...
            sum(S.active_channels), S.fiber_length_km));

        n_steps_fiber = 65;
        % Stagger the pulses slightly to demonstrate chromatic dispersion delay (longer wavelengths travel at slightly different group velocities)
        for k = 1:n_steps_fiber
            if S.stop_requested || ~ishandle(ax), return; end
            while S.is_paused
                pause(0.08);
                if S.stop_requested, return; end
            end

            t_frac = k / n_steps_fiber;
            center_x = 30 + t_frac * 40;

            for m = 1:4
                if S.active_channels(m)
                    % Dispersion offset in space (relative delay)
                    disp_offset = (m - 2.5) * 1.2 * (t_frac);
                    % Slight vertical separation inside thick core so user sees all active channels
                    y_offset = (m - 2.5) * 1.4;
                    set(pulses{m}, 'XData', center_x + disp_offset, 'YData', 34 + y_offset);

                    % Simulate attenuation: shrink marker size slightly as distance increases
                    loss_factor = 1.0 - 0.25 * t_frac;
                    set(pulses{m}, 'MarkerSize', max(5, 9 * loss_factor));
                end
            end
            drawnow;
            pause(dt);
        end

        % STAGE 5: Demultiplexing inside DEMUX
        set(S.status_text, 'String', '4. [WDM DEMULTIPLEXING] Multi-wavelength composite light arrives at DEMUX. Prismatic / diffraction grating separates light by wavelength...');
        flash_element(73, 34, 6, 20, [0.8 0.4 1.0]);

        % STAGE 6: Propagation along output fibers into Receivers
        set(S.status_text, 'String', '5. [CHANNEL SEPARATION & DETECTION] Separated wavelengths travel to dedicated receivers (RX 1 to RX 4)...');

        n_steps_out = 35;
        for k = 1:n_steps_out
            if S.stop_requested || ~ishandle(ax), return; end
            while S.is_paused
                pause(0.08);
                if S.stop_requested, return; end
            end

            t_frac = k / n_steps_out;
            for m = 1:4
                if S.active_channels(m)
                    x_pos = 76 + t_frac * (88 - 76);
                    y_pos = demux_y_out(m) + t_frac * (y_tiers(m) - demux_y_out(m));
                    set(pulses{m}, 'XData', x_pos, 'YData', y_pos);
                end
            end
            drawnow;
            pause(dt);
        end

        % Flash active receivers
        for m = 1:4
            if S.active_channels(m)
                flash_element(92, y_tiers(m), 7, 7, c_ch(m, :));
            end
        end

        loss_db = S.fiber_length_km * S.attenuation_rate;
        p_ratio = 10^(-loss_db / 10) * 100;
        set(S.status_text, 'String', sprintf(...
            '6. [TRANSMISSION SUCCESSFUL] All active channels demultiplexed without crosstalk! Received Power = %.1f%% (-%.1f dB over %.0f km).', ...
            p_ratio, loss_db, S.fiber_length_km));

        S.is_running = false;
        fig.UserData = S;
    end

    function flash_element(x, y, w, h, col)
        flash = patch(ax, [x-w/2 x+w/2 x+w/2 x-w/2], [y-h/2 y-h/2 y+h/2 y+h/2], col, ...
            'FaceAlpha', 0.6, 'EdgeColor', [1 1 1], 'LineWidth', 2.0, 'Tag', 'wdm_pulse');
        for i = 1:3
            pause(0.05);
            if ~ishandle(flash), return; end
            set(flash, 'FaceAlpha', 0.1);
            pause(0.05);
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
