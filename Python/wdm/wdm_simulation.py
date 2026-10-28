"""Four-channel WDM simulation using complex envelopes and FFT propagation."""

import csv

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FuncAnimation, PillowWriter
from PIL import Image

from Python.common.optical_constants import (
    ANIMATIONS_DIR,
    C0_M_PER_S,
    DATA_DIR,
    GRAPHS_DIR,
)
from Python.common.plotting_utils import prepare_output_dirs, save_figure


CHANNEL_WAVELENGTHS_NM = np.array([1530.0, 1540.0, 1550.0, 1560.0])
FIBER_LENGTH_KM = 50.0
ATTENUATION_DB_PER_KM = 0.2
BETA2_PS2_PER_KM = -21.7


def simulate_wdm(
    sample_count=4096,
    sample_rate_hz=16e12,
    fiber_length_km=FIBER_LENGTH_KM,
    attenuation_db_per_km=ATTENUATION_DB_PER_KM,
    beta2_ps2_per_km=BETA2_PS2_PER_KM,
    wavelengths_nm=None,
    modulation_hz=18e9,
):
    """Generate, multiplex, propagate, and ideally demultiplex optical envelopes."""
    wavelengths_nm = (
        CHANNEL_WAVELENGTHS_NM.copy()
        if wavelengths_nm is None
        else np.asarray(wavelengths_nm, dtype=float)
    )
    if wavelengths_nm.ndim != 1 or len(wavelengths_nm) == 0:
        raise ValueError("Provide at least one wavelength.")
    if not np.all(np.isfinite(wavelengths_nm)) or np.any(wavelengths_nm <= 0):
        raise ValueError("Wavelengths must be finite positive values.")
    if len(np.unique(wavelengths_nm)) != len(wavelengths_nm):
        raise ValueError("Wavelengths must be unique.")
    if sample_count < 2:
        raise ValueError("sample_count must be at least 2.")
    if not np.isfinite(sample_rate_hz) or sample_rate_hz <= 0:
        raise ValueError("sample_rate_hz must be finite and positive.")
    if not np.isfinite(fiber_length_km) or fiber_length_km < 0:
        raise ValueError("fiber_length_km must be finite and non-negative.")
    if not np.isfinite(attenuation_db_per_km) or attenuation_db_per_km < 0:
        raise ValueError("Fiber length and attenuation must be non-negative.")
    if not np.isfinite(beta2_ps2_per_km):
        raise ValueError("beta2_ps2_per_km must be finite.")
    if not np.isfinite(modulation_hz) or modulation_hz < 0:
        raise ValueError("Modulation frequency must be non-negative.")

    wavelengths_m = wavelengths_nm * 1e-9
    optical_frequencies_hz = C0_M_PER_S / wavelengths_m
    reference_frequency_hz = float(np.mean(optical_frequencies_hz))
    offsets_hz = optical_frequencies_hz - reference_frequency_hz
    time_s = np.arange(sample_count) / sample_rate_hz
    channel_fields = np.array([
        np.exp(2j * np.pi * offset * time_s)
        * (1.0 + 0.25 * np.cos(2.0 * np.pi * modulation_hz * time_s))
        for offset in offsets_hz
    ])
    multiplexed = np.sum(channel_fields, axis=0)

    frequency_offset_hz = np.fft.fftfreq(sample_count, d=1.0 / sample_rate_hz)
    if np.max(np.abs(offsets_hz)) + modulation_hz >= sample_rate_hz / 2.0:
        raise ValueError(
            "Channel offsets and modulation exceed the sample rate's Nyquist limit."
        )
    spacing_hz = (
        float(np.min(np.diff(np.sort(offsets_hz))))
        if len(offsets_hz) > 1
        else sample_rate_hz
    )
    channel_width_hz = 0.45 * spacing_hz
    if modulation_hz >= channel_width_hz:
        raise ValueError(
            "Modulation frequency must fit inside the WDM channel filter bandwidth."
        )
    beta2_s2_per_m = beta2_ps2_per_km * 1e-24 / 1000.0
    length_m = fiber_length_km * 1000.0
    dispersion_phase = np.exp(-1j * 2.0 * np.pi**2 * beta2_s2_per_m
                              * length_m * frequency_offset_hz**2)
    power_attenuation = 10.0 ** (-attenuation_db_per_km * fiber_length_km / 10.0)
    field_attenuation = np.sqrt(power_attenuation)
    transmitted = np.fft.ifft(np.fft.fft(multiplexed) * dispersion_phase) * field_attenuation

    spectrum = np.fft.fft(transmitted)
    channel_outputs = []
    for offset in offsets_hz:
        mask = np.abs(frequency_offset_hz - offset) <= channel_width_hz
        channel_outputs.append(np.fft.ifft(spectrum * mask))
    return {
        "time_s": time_s,
        "wavelengths_nm": wavelengths_nm.copy(),
        "optical_frequencies_hz": optical_frequencies_hz,
        "offsets_hz": offsets_hz,
        "channel_fields": channel_fields,
        "multiplexed": multiplexed,
        "transmitted": transmitted,
        "channel_outputs": np.array(channel_outputs),
        "sample_rate_hz": sample_rate_hz,
        "fiber_length_km": fiber_length_km,
        "power_attenuation": power_attenuation,
        "attenuation_db_per_km": attenuation_db_per_km,
        "beta2_ps2_per_km": beta2_ps2_per_km,
        "modulation_hz": modulation_hz,
    }


def run(
    wavelengths_nm=None,
    fiber_length_km=FIBER_LENGTH_KM,
    attenuation_db_per_km=ATTENUATION_DB_PER_KM,
    beta2_ps2_per_km=BETA2_PS2_PER_KM,
    modulation_hz=18e9,
):
    prepare_output_dirs()
    result = simulate_wdm(
        fiber_length_km=fiber_length_km,
        attenuation_db_per_km=attenuation_db_per_km,
        beta2_ps2_per_km=beta2_ps2_per_km,
        wavelengths_nm=wavelengths_nm,
        modulation_hz=modulation_hz,
    )
    time_ps = result["time_s"] * 1e12
    figure, axes = plt.subplots(2, 2, figsize=(12, 8))
    for index, channel in enumerate(result["channel_fields"]):
        axes[0, 0].plot(time_ps[:300], channel.real[:300], label=f"{result['wavelengths_nm'][index]:.0f} nm")
    axes[0, 0].set(title="Individual channel envelopes", xlabel="Time (ps)", ylabel="Normalized field")
    axes[0, 0].legend(ncol=2, fontsize=8)
    axes[0, 1].plot(time_ps[:300], result["multiplexed"].real[:300], color="#5b4b8a")
    axes[0, 1].set(title="Multiplexed field", xlabel="Time (ps)", ylabel="Real envelope")

    spectrum = np.abs(np.fft.fft(result["transmitted"])) ** 2
    offsets_ghz = np.fft.fftfreq(len(spectrum), d=1.0 / result["sample_rate_hz"]) / 1e9
    order = np.argsort(offsets_ghz)
    axes[1, 0].plot(offsets_ghz[order], 10.0 * np.log10(spectrum[order] + 1e-15))
    axes[1, 0].set(title="Output spectrum (baseband around optical carrier)",
                   xlabel="Offset from reference carrier (GHz)", ylabel="Relative power (dB)")
    spectrum_limit_ghz = (
        np.max(np.abs(result["offsets_hz"])) + result["modulation_hz"]
    ) / 1e9 + 50.0
    axes[1, 0].set_xlim(-spectrum_limit_ghz, spectrum_limit_ghz)

    for index, channel in enumerate(result["channel_outputs"]):
        axes[1, 1].plot(time_ps[:300], channel.real[:300],
                        label=f"{result['wavelengths_nm'][index]:.0f} nm")
    axes[1, 1].set(title="Demultiplexed channel outputs", xlabel="Time (ps)", ylabel="Real envelope")
    axes[1, 1].legend(ncol=2, fontsize=8)
    figure.suptitle(
        f"{len(result['wavelengths_nm'])}-channel WDM: complex-envelope transmission"
    )
    save_figure(figure, "wdm_signals_and_spectrum.png")

    figure, axis = plt.subplots(figsize=(8, 4.5))
    for field, label, color in (
        (result["multiplexed"], "Before fiber", "#177e89"),
        (result["transmitted"], f"After {fiber_length_km:g} km fiber", "#d1495b"),
    ):
        power_spectrum = np.abs(np.fft.fft(field)) ** 2
        axis.plot(offsets_ghz[order],
                  10.0 * np.log10(power_spectrum[order] + 1e-15),
                  label=label, color=color, alpha=0.85)
    axis.set(title=f"WDM optical spectrum before and after {fiber_length_km:g} km of fiber",
             xlabel="Offset from reference optical carrier (GHz)", ylabel="Relative power (dB)")
    axis.set_xlim(-spectrum_limit_ghz, spectrum_limit_ghz)
    axis.grid(alpha=0.2)
    axis.legend()
    save_figure(figure, "wdm_spectrum_before_after.png")

    max_length_km = max(100.0, fiber_length_km)
    lengths_km = np.linspace(0.0, max_length_km, 101)
    powers_dbm = -attenuation_db_per_km * lengths_km
    figure, axis = plt.subplots(figsize=(7, 4.5))
    axis.plot(lengths_km, powers_dbm, color="#177e89")
    axis.scatter([fiber_length_km], [-attenuation_db_per_km * fiber_length_km], color="#d1495b", zorder=3)
    axis.set(title="WDM power attenuation versus fiber length",
             xlabel="Fiber length (km)",
             ylabel="Relative power (dB)")
    axis.grid(alpha=0.25)
    save_figure(figure, "wdm_power_vs_distance.png")

    with (DATA_DIR / "wdm_results.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow([
            "channel",
            "wavelength_nm",
            "optical_frequency_thz",
            "fiber_length_km",
            "attenuation_db_per_km",
            "beta2_ps2_per_km",
            "fiber_output_power_fraction",
        ])
        channel_input_power = np.mean(np.abs(result["channel_fields"]) ** 2, axis=1)
        for index, wavelength in enumerate(result["wavelengths_nm"]):
            output_power = channel_input_power[index] * result["power_attenuation"]
            writer.writerow([index + 1, wavelength,
                             result["optical_frequencies_hz"][index] / 1e12,
                             fiber_length_km, attenuation_db_per_km,
                             beta2_ps2_per_km, output_power])
    create_animation(result)
    create_fiber_animation(result)
    return result


def create_animation(result=None):
    if result is None:
        result = simulate_wdm(sample_count=512)
    wavelengths = result["wavelengths_nm"]
    channel_count = len(wavelengths)
    colors = plt.get_cmap("tab10")(np.linspace(0, 1, channel_count))
    lane_y = np.arange(channel_count, 0, -1, dtype=float)
    center_y = (channel_count + 1.0) / 2.0
    bundle_spacing = min(0.16, max(0.06, 0.48 / channel_count))
    bundle_offsets = (
        np.arange(channel_count) - (channel_count - 1) / 2.0
    ) * bundle_spacing
    x_transmitter = (0.25, 1.25)
    x_mux = (2.70, 3.35)
    x_fiber = (3.35, 6.65)
    x_demux = (6.65, 7.30)
    x_receiver = (8.75, 9.75)
    route_lines = []

    figure_height = max(4.5, 1.0 + 0.72 * channel_count)
    figure, axis = plt.subplots(figsize=(12, figure_height))
    axis.set_xlim(0.0, 10.0)
    axis.set_ylim(0.0, channel_count + 1.0)
    axis.axis("off")
    axis.set_title("Wavelength Division Multiplexing (WDM)", fontsize=17, pad=18)

    axis.text(0.75, channel_count + 0.45, "TRANSMITTERS", ha="center",
              va="center", fontsize=11, weight="bold")
    axis.text(9.25, channel_count + 0.45, "RECEIVERS", ha="center",
              va="center", fontsize=11, weight="bold")
    axis.text(3.02, channel_count + 0.45, "MUX", ha="center",
              va="center", fontsize=12, weight="bold")
    axis.text(6.98, channel_count + 0.45, "DEMUX", ha="center",
              va="center", fontsize=12, weight="bold")

    axis.add_patch(plt.Rectangle(
        (x_fiber[0], center_y - 0.36),
        x_fiber[1] - x_fiber[0],
        0.72,
        facecolor="#e8eef5",
        edgecolor="#607d9b",
        linewidth=1.5,
        zorder=0,
    ))
    axis.text(
        (x_fiber[0] + x_fiber[1]) / 2.0,
        center_y + 0.5,
        f"ONE FIBER  |  {result['fiber_length_km']:g} km",
        ha="center",
        va="bottom",
        fontsize=9,
        color="#34495e",
        weight="bold",
    )

    mux_polygon = np.array([
        [x_mux[0], lane_y[0] + 0.35],
        [x_mux[1], center_y + 0.30],
        [x_mux[1], center_y - 0.30],
        [x_mux[0], lane_y[-1] - 0.35],
    ])
    demux_polygon = np.array([
        [x_demux[0], center_y + 0.30],
        [x_demux[1], lane_y[0] + 0.35],
        [x_demux[1], lane_y[-1] - 0.35],
        [x_demux[0], center_y - 0.30],
    ])
    axis.add_patch(plt.Polygon(
        mux_polygon, closed=True, facecolor="#b9e8ed",
        edgecolor="#236b78", linewidth=2, zorder=2
    ))
    axis.add_patch(plt.Polygon(
        demux_polygon, closed=True, facecolor="#b9e8ed",
        edgecolor="#236b78", linewidth=2, zorder=2
    ))

    for index, (wavelength, color, y) in enumerate(zip(wavelengths, colors, lane_y)):
        axis.add_patch(plt.Rectangle(
            (x_transmitter[0], y - 0.20), 0.9, 0.4,
            facecolor="#f4f6f8", edgecolor="#34495e", linewidth=1.2, zorder=3
        ))
        axis.text(x_transmitter[0] + 0.45, y,
                  f"TX {index + 1}\n{wavelength:g} nm",
                  ha="center", va="center", fontsize=8, zorder=4)
        axis.add_patch(plt.Rectangle(
            (x_receiver[0], y - 0.20), 0.9, 0.4,
            facecolor="#f4f6f8", edgecolor="#34495e", linewidth=1.2, zorder=3
        ))
        axis.text(x_receiver[0] + 0.45, y,
                  f"RX {index + 1}\n{wavelength:g} nm",
                  ha="center", va="center", fontsize=8, zorder=4)

        route_x = [
            x_transmitter[1],
            x_mux[0],
            x_mux[1],
            x_fiber[1],
            x_demux[1],
            x_receiver[0],
        ]
        route_y = [
            y,
            y,
            center_y + bundle_offsets[index],
            center_y + bundle_offsets[index],
            y,
            y,
        ]
        route_lines.append((np.asarray(route_x), np.asarray(route_y)))
        axis.plot(route_x, route_y, color=color, alpha=0.20, linewidth=2.4, zorder=1)
        axis.plot(
            [x_fiber[0], x_fiber[1]],
            [center_y + bundle_offsets[index]] * 2,
            color=color,
            alpha=0.35,
            linewidth=1.5,
            zorder=2,
        )

    flow_y = 0.28
    axis.annotate(
        "", xy=(x_receiver[1], flow_y), xytext=(x_transmitter[0], flow_y),
        arrowprops={"arrowstyle": "->", "color": "#566573", "lw": 1.5},
    )
    axis.text(5.0, flow_y + 0.05, "SIGNAL FLOW", ha="center", va="bottom",
              fontsize=9, color="#566573", weight="bold")
    stage_text = axis.text(
        5.0, 0.64, "",
        ha="center", va="center", fontsize=10, color="#1f4e79", weight="bold"
    )
    active_lines = [
        axis.plot([], [], color=color, linewidth=3.0, zorder=5)[0]
        for color in colors
    ]

    def update(frame):
        progress = frame / 119.0
        if progress < 0.22:
            stage = "1/5  Transmitters -> MUX"
        elif progress < 0.34:
            stage = "2/5  MUX combines channels"
        elif progress < 0.70:
            stage = "3/5  Together in shared fiber"
        elif progress < 0.82:
            stage = "4/5  DEMUX separates wavelengths"
        else:
            stage = "5/5  Channels -> receivers"
        stage_text.set_text(stage)

        for index, ((route_x, route_y), line) in enumerate(zip(route_lines, active_lines)):
            path_lengths = np.hypot(np.diff(route_x), np.diff(route_y))
            cumulative = np.concatenate(([0.0], np.cumsum(path_lengths)))
            total_length = cumulative[-1]
            traveled = progress * total_length
            sample_distances = np.linspace(0.0, traveled, max(2, int(160 * progress)))
            sample_x = np.interp(sample_distances, cumulative, route_x)
            sample_y = np.interp(sample_distances, cumulative, route_y)
            line.set_data(sample_x, sample_y)
        return (*active_lines, stage_text)

    animation = FuncAnimation(
        figure, update, frames=120, interval=55, blit=True, repeat=True
    )
    prepare_output_dirs()
    animation_path = ANIMATIONS_DIR / "wdm_co_propagation.gif"
    animation.save(animation_path, writer=PillowWriter(fps=20))
    plt.close(figure)
    with Image.open(animation_path) as saved_animation:
        frame_indices = [0, 30, 55, 85, 105, saved_animation.n_frames - 1]
        thumbnails = []
        for frame_index in frame_indices:
            saved_animation.seek(frame_index)
            thumbnail = saved_animation.convert("RGB")
            thumbnail.thumbnail((600, 225))
            thumbnails.append(thumbnail.copy())

        storyboard = Image.new("RGB", (1800, 450), "white")
        for index, thumbnail in enumerate(thumbnails):
            x_position = (index % 3) * 600
            y_position = (index // 3) * 225
            storyboard.paste(thumbnail, (x_position, y_position))
        storyboard.save(GRAPHS_DIR / "wdm_animation_storyboard.png")

        saved_animation.seek(saved_animation.n_frames - 1)
        saved_animation.convert("RGB").save(
            GRAPHS_DIR / "wdm_system_diagram.png"
        )


def create_fiber_animation(result=None):
    """Create the original co-propagating wave view as a separate GIF."""
    if result is None:
        result = simulate_wdm(sample_count=512)
    wavelengths = result["wavelengths_nm"]
    channel_count = len(wavelengths)
    fiber_length_km = result["fiber_length_km"]
    distance_km = np.linspace(0.0, fiber_length_km, 400)
    colors = plt.get_cmap("tab10")(np.linspace(0, 1, channel_count))

    figure, axis = plt.subplots(figsize=(9, 4))
    lines = [
        axis.plot([], [], color=color, linewidth=1.6,
                  label=f"{wavelength:g} nm")[0]
        for color, wavelength in zip(colors, wavelengths)
    ]
    axis.set(
        xlim=(0.0, max(fiber_length_km, 1e-9)),
        ylim=(-1.5, 1.5),
        xlabel="Distance along the shared fiber (km)",
        ylabel="Illustrative field oscillation",
    )
    axis.set_title("WDM channels co-propagating through one fiber")
    axis.legend(ncol=min(channel_count, 4), fontsize=8, loc="upper right")
    status = axis.text(
        0.02, 0.92, "", transform=axis.transAxes, ha="left", va="top",
        fontsize=9, color="#34495e",
    )

    def update(frame):
        progress = frame / 59.0
        distance_traveled = fiber_length_km * progress
        for index, line in enumerate(lines):
            wavelength_nm = wavelengths[index]
            phase_scale_km = 10.0 + index * 1.7
            phase_shift = distance_traveled / (50.0 + index * 2.0)
            phase = 2.0 * np.pi * (
                distance_km / phase_scale_km - phase_shift
            )
            attenuation_db = (
                result["attenuation_db_per_km"] * distance_traveled
            )
            amplitude = 10.0 ** (-attenuation_db / 20.0)
            line.set_data(distance_km, amplitude * np.sin(phase))
        status.set_text(
            f"All {channel_count} channels travel together | "
            f"distance: {distance_traveled:.1f} km"
        )
        return (*lines, status)

    animation = FuncAnimation(
        figure, update, frames=60, interval=50, blit=True, repeat=True
    )
    prepare_output_dirs()
    animation_path = ANIMATIONS_DIR / "wdm_fiber_propagation.gif"
    animation.save(animation_path, writer=PillowWriter(fps=20))
    plt.close(figure)
    return animation_path


if __name__ == "__main__":
    print("Attenuation after 50 km:", run()["power_attenuation"])
