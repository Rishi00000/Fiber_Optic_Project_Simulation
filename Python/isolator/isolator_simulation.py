"""Basic and Jones-matrix fiber optic isolator simulations."""

import csv

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FuncAnimation, PillowWriter

from Python.common.optical_constants import ANIMATIONS_DIR, DATA_DIR
from Python.common.plotting_utils import prepare_output_dirs, save_figure


def basic_model(input_power_mw=10.0, insertion_loss_db=0.5, isolation_db=30.0):
    """Return idealized forward/reverse power and device metrics."""
    if not np.isfinite(input_power_mw) or input_power_mw <= 0:
        raise ValueError("input_power_mw must be a finite positive value.")
    if not np.isfinite(insertion_loss_db) or insertion_loss_db < 0:
        raise ValueError("insertion_loss_db must be finite and non-negative.")
    if not np.isfinite(isolation_db) or isolation_db < 0:
        raise ValueError("isolation_db must be finite and non-negative.")
    forward_mw = input_power_mw * 10.0 ** (-insertion_loss_db / 10.0)
    reverse_mw = input_power_mw * 10.0 ** (-isolation_db / 10.0)
    return {
        "input_power_mw": input_power_mw,
        "forward_power_mw": forward_mw,
        "reverse_power_mw": reverse_mw,
        "insertion_loss_db": insertion_loss_db,
        "isolation_db": 10.0 * np.log10(input_power_mw / reverse_mw),
        "forward_reverse_contrast_db": 10.0 * np.log10(forward_mw / reverse_mw),
    }


def rotation_matrix(angle_rad):
    cosine, sine = np.cos(angle_rad), np.sin(angle_rad)
    return np.array([[cosine, -sine], [sine, cosine]], dtype=complex)


def faraday_rotation_angle_deg(verdet_constant_rad_per_t_m, magnetic_field_t, interaction_length_m):
    """Compute Faraday rotation φ=VBL, returned in degrees."""
    angle_rad = verdet_constant_rad_per_t_m * magnetic_field_t * interaction_length_m
    return float(np.rad2deg(angle_rad))


def jones_transmission(input_angle_deg, faraday_angle_deg, analyzer_angle_deg):
    """Calculate normalized forward/reverse powers through polarizer/rotator/analyzer.

    The Faraday rotation has the same signed rotation in either propagation
    direction. Losses other than polarization rejection are excluded.
    """
    if not np.all(np.isfinite([input_angle_deg, faraday_angle_deg, analyzer_angle_deg])):
        raise ValueError("Polarization angles must be finite.")
    input_angle = np.deg2rad(input_angle_deg)
    faraday_angle = np.deg2rad(faraday_angle_deg)
    analyzer_angle = np.deg2rad(analyzer_angle_deg)
    input_state = np.array([np.cos(input_angle), np.sin(input_angle)], dtype=complex)
    analyzer = np.array([np.cos(analyzer_angle), np.sin(analyzer_angle)], dtype=complex)
    forward_field = np.vdot(analyzer, rotation_matrix(faraday_angle) @ input_state)
    reverse_input = analyzer
    reverse_output = np.vdot(input_state, rotation_matrix(faraday_angle) @ reverse_input)
    return float(abs(forward_field) ** 2), float(abs(reverse_output) ** 2)


def run(
    input_power_mw=10.0,
    insertion_loss_db=0.5,
    isolation_db=30.0,
    input_angle_deg=0.0,
    faraday_angle_deg=45.0,
    analyzer_angle_deg=45.0,
):
    prepare_output_dirs()
    basic = basic_model(input_power_mw, insertion_loss_db, isolation_db)
    angle_deg = np.linspace(0.0, 180.0, 721)
    forward = np.zeros_like(angle_deg)
    reverse = np.zeros_like(angle_deg)
    for index, angle in enumerate(angle_deg):
        forward[index], reverse[index] = jones_transmission(
            input_angle_deg, angle, analyzer_angle_deg
        )

    figure, axes = plt.subplots(1, 2, figsize=(11, 4.5))
    axes[0].bar(
        ["Forward", "Reverse"],
        [basic["forward_power_mw"], basic["reverse_power_mw"]],
        color=["#177e89", "#d1495b"],
    )
    axes[0].set_ylabel("Output power (mW)")
    axes[0].set_title("Basic power model")
    axes[0].grid(axis="y", alpha=0.25)
    axes[1].plot(angle_deg, 10.0 * np.log10(np.maximum(forward, 1e-12)), label="Forward")
    axes[1].plot(angle_deg, 10.0 * np.log10(np.maximum(reverse, 1e-12)), label="Reverse")
    axes[1].axvline(
        np.mod(faraday_angle_deg, 180.0),
        color="gray",
        linestyle="--",
        linewidth=1,
    )
    axes[1].set(
        xlabel="Faraday rotation (degrees; polarization repeats every 180°)",
        ylabel="Normalized power (dB)",
    )
    axes[1].set_title(f"Jones model with {analyzer_angle_deg:g}° analyzer")
    axes[1].set_ylim(-80, 2)
    axes[1].grid(alpha=0.25)
    axes[1].legend()
    figure.suptitle("Fiber optic isolator")
    save_figure(figure, "isolator_transmission.png")

    with (DATA_DIR / "isolator_results.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["metric", "value", "unit"])
        writer.writerow(["input_power", basic["input_power_mw"], "mW"])
        writer.writerow(["forward_power", basic["forward_power_mw"], "mW"])
        writer.writerow(["reverse_power", basic["reverse_power_mw"], "mW"])
        writer.writerow(["insertion_loss", basic["insertion_loss_db"], "dB"])
        writer.writerow(["isolation", basic["isolation_db"], "dB"])
        writer.writerow(["forward_reverse_contrast", basic["forward_reverse_contrast_db"], "dB"])
        forward_jones, reverse_jones = jones_transmission(
            input_angle_deg, faraday_angle_deg, analyzer_angle_deg
        )
        writer.writerow(["input_polarizer_angle", input_angle_deg, "degrees"])
        writer.writerow(["faraday_rotation_angle", faraday_angle_deg, "degrees"])
        writer.writerow(["analyzer_angle", analyzer_angle_deg, "degrees"])
        writer.writerow(["jones_forward_at_selected_angles", forward_jones, "fraction"])
        writer.writerow(["jones_reverse_at_selected_angles", reverse_jones, "fraction"])

    create_animation(input_angle_deg, faraday_angle_deg, analyzer_angle_deg)
    return basic


def create_animation(input_angle_deg=0.0, faraday_angle_deg=45.0, analyzer_angle_deg=45.0):
    figure, axis = plt.subplots(figsize=(9, 3.2))
    axis.set(xlim=(-0.1, 1.1), ylim=(-0.42, 0.48), yticks=[], xticks=[])
    axis.set_title("Isolator: forward transmission and reverse polarization rejection")
    components = [(0.15, "Input\npolarizer"), (0.50, "Faraday\nrotator"), (0.85, "Analyzer")]
    for x, label in components:
        axis.axvline(x, ymin=0.25, ymax=0.76, color="#555555", linewidth=4)
        axis.text(x, 0.34, label, ha="center", va="bottom", fontsize=9)
    axis.annotate("", xy=(0.5, -0.07), xytext=(0.15, -0.07),
                  arrowprops={"arrowstyle": "->", "color": "#177e89", "lw": 2})
    axis.annotate("", xy=(0.15, -0.20), xytext=(0.85, -0.20),
                  arrowprops={"arrowstyle": "->", "color": "#d1495b", "lw": 2})
    forward_dot, = axis.plot([], [], "o", color="#177e89", markersize=12)
    reverse_dot, = axis.plot([], [], "o", color="#d1495b", markersize=12)
    polarization, = axis.plot([], [], color="#177e89", linewidth=2)
    status = axis.text(0.5, -0.36, "", ha="center", fontsize=10)

    def update(frame):
        phase = frame / 59.0
        forward_x = 0.15 + 0.70 * phase
        reverse_x = 0.85 - 0.70 * phase
        forward_dot.set_data([forward_x], [-0.07])
        reverse_position = reverse_x if reverse_x >= 0.50 else 0.50
        reverse_dot.set_data([reverse_position], [-0.20])
        rotation_progress = min(1.0, max(0.0, (forward_x - 0.15) / 0.35))
        angle = np.deg2rad(input_angle_deg + rotation_progress * faraday_angle_deg)
        polarization.set_data([0.5, 0.5 + 0.11 * np.cos(angle)],
                              [0.08, 0.08 + 0.11 * np.sin(angle)])
        status.set_text(
            f"Forward: {input_angle_deg:g}° + {faraday_angle_deg:g}° rotation; "
            f"analyzer: {analyzer_angle_deg:g}°"
        )
        return forward_dot, reverse_dot, polarization, status

    animation = FuncAnimation(figure, update, frames=60, interval=50, blit=True)
    prepare_output_dirs()
    animation.save(ANIMATIONS_DIR / "isolator_propagation.gif", writer=PillowWriter(fps=20))
    plt.close(figure)


if __name__ == "__main__":
    print(run())
