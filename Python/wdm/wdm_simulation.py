"""Four-channel WDM simulation using complex envelopes and FFT propagation."""

import csv

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FuncAnimation, PillowWriter

from Python.common.optical_constants import ANIMATIONS_DIR, C0_M_PER_S, DATA_DIR
from Python.common.plotting_utils import prepare_output_dirs, save_figure


CHANNEL_WAVELENGTHS_NM = np.array([1530.0, 1540.0, 1550.0, 1560.0])
FIBER_LENGTH_KM = 50.0
ATTENUATION_DB_PER_KM = 0.2
BETA2_PS2_PER_KM = -21.7


def simulate_wdm(sample_count=4096, sample_rate_hz=16e12, fiber_length_km=FIBER_LENGTH_KM):
    """Generate, multiplex, propagate, and ideally demultiplex four optical envelopes."""
    wavelengths_m = CHANNEL_WAVELENGTHS_NM * 1e-9
    optical_frequencies_hz = C0_M_PER_S / wavelengths_m
    reference_frequency_hz = float(np.mean(optical_frequencies_hz))
    offsets_hz = optical_frequencies_hz - reference_frequency_hz
    time_s = np.arange(sample_count) / sample_rate_hz
    modulation_hz = 18e9
    channel_fields = np.array([
        np.exp(2j * np.pi * offset * time_s)
        * (1.0 + 0.25 * np.cos(2.0 * np.pi * modulation_hz * time_s))
        for offset in offsets_hz
    ])
    multiplexed = np.sum(channel_fields, axis=0)

    frequency_offset_hz = np.fft.fftfreq(sample_count, d=1.0 / sample_rate_hz)
    beta2_s2_per_m = BETA2_PS2_PER_KM * 1e-24 / 1000.0
    length_m = fiber_length_km * 1000.0
    dispersion_phase = np.exp(-1j * 2.0 * np.pi**2 * beta2_s2_per_m
                              * length_m * frequency_offset_hz**2)
    power_attenuation = 10.0 ** (-ATTENUATION_DB_PER_KM * fiber_length_km / 10.0)
    field_attenuation = np.sqrt(power_attenuation)
    transmitted = np.fft.ifft(np.fft.fft(multiplexed) * dispersion_phase) * field_attenuation

    spacing_hz = float(np.min(np.diff(np.sort(offsets_hz))))
    channel_width_hz = 0.45 * spacing_hz
    spectrum = np.fft.fft(transmitted)
    channel_outputs = []
    for offset in offsets_hz:
        mask = np.abs(frequency_offset_hz - offset) <= channel_width_hz
        channel_outputs.append(np.fft.ifft(spectrum * mask))
    return {
        "time_s": time_s,
        "wavelengths_nm": CHANNEL_WAVELENGTHS_NM.copy(),
        "optical_frequencies_hz": optical_frequencies_hz,
        "offsets_hz": offsets_hz,
        "channel_fields": channel_fields,
        "multiplexed": multiplexed,
        "transmitted": transmitted,
        "channel_outputs": np.array(channel_outputs),
        "sample_rate_hz": sample_rate_hz,
        "fiber_length_km": fiber_length_km,
        "power_attenuation": power_attenuation,
    }


def run():
    prepare_output_dirs()
    result = simulate_wdm()
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
    axes[1, 0].set_xlim(-2500, 2500)

    for index, channel in enumerate(result["channel_outputs"]):
        axes[1, 1].plot(time_ps[:300], channel.real[:300],
                        label=f"{result['wavelengths_nm'][index]:.0f} nm")
    axes[1, 1].set(title="Demultiplexed channel outputs", xlabel="Time (ps)", ylabel="Real envelope")
    axes[1, 1].legend(ncol=2, fontsize=8)
    figure.suptitle("Four-channel WDM: complex-envelope transmission through fiber")
    save_figure(figure, "wdm_signals_and_spectrum.png")

    figure, axis = plt.subplots(figsize=(8, 4.5))
    for field, label, color in (
        (result["multiplexed"], "Before fiber", "#177e89"),
        (result["transmitted"], "After 50 km fiber", "#d1495b"),
    ):
        power_spectrum = np.abs(np.fft.fft(field)) ** 2
        axis.plot(offsets_ghz[order],
                  10.0 * np.log10(power_spectrum[order] + 1e-15),
                  label=label, color=color, alpha=0.85)
    axis.set(title="WDM optical spectrum before and after the fiber",
             xlabel="Offset from reference optical carrier (GHz)", ylabel="Relative power (dB)")
    axis.set_xlim(-2500, 2500)
    axis.grid(alpha=0.2)
    axis.legend()
    save_figure(figure, "wdm_spectrum_before_after.png")

    lengths_km = np.linspace(0.0, 100.0, 101)
    powers_dbm = -ATTENUATION_DB_PER_KM * lengths_km
    figure, axis = plt.subplots(figsize=(7, 4.5))
    axis.plot(lengths_km, powers_dbm, color="#177e89")
    axis.scatter([FIBER_LENGTH_KM], [-ATTENUATION_DB_PER_KM * FIBER_LENGTH_KM], color="#d1495b", zorder=3)
    axis.set(title="WDM power attenuation versus fiber length", xlabel="Fiber length (km)",
             ylabel="Relative power (dB)")
    axis.grid(alpha=0.25)
    save_figure(figure, "wdm_power_vs_distance.png")

    with (DATA_DIR / "wdm_results.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["channel", "wavelength_nm", "optical_frequency_thz", "fiber_output_power_fraction"])
        channel_input_power = np.mean(np.abs(result["channel_fields"]) ** 2, axis=1)
        for index, wavelength in enumerate(result["wavelengths_nm"]):
            output_power = channel_input_power[index] * result["power_attenuation"]
            writer.writerow([index + 1, wavelength,
                             result["optical_frequencies_hz"][index] / 1e12, output_power])
    create_animation(result)
    return result


def create_animation(result=None):
    if result is None:
        result = simulate_wdm(sample_count=512)
    figure, axis = plt.subplots(figsize=(8, 3.4))
    z = np.linspace(0.0, 50.0, 300)
    colors = ["#d1495b", "#f4a261", "#177e89", "#6a4c93"]
    lines = [axis.plot([], [], color=color, linewidth=1.4, label=f"{wavelength:.0f} nm")[0]
             for color, wavelength in zip(colors, result["wavelengths_nm"])]
    axis.set(xlim=(0, 50), ylim=(-1.5, 1.5), xlabel="Distance along common fiber (km)",
             ylabel="Illustrative field oscillation")
    axis.set_title("Four wavelength channels co-propagating in one fiber")
    axis.legend(ncol=4, fontsize=8, loc="upper right")

    def update(frame):
        distance = 50.0 * frame / 59.0
        for index, line in enumerate(lines):
            phase = 2.0 * np.pi * (z / (10.0 + index * 1.7) - distance / (50.0 + index * 2.0))
            line.set_data(z, np.sin(phase))
        return lines

    animation = FuncAnimation(figure, update, frames=60, interval=50, blit=True)
    prepare_output_dirs()
    animation.save(ANIMATIONS_DIR / "wdm_co_propagation.gif", writer=PillowWriter(fps=20))
    plt.close(figure)


if __name__ == "__main__":
    print("Attenuation after 50 km:", run()["power_attenuation"])
