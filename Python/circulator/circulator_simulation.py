"""Ideal and lossy three-port fiber optic circulator simulations."""

import csv

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FuncAnimation, PillowWriter

from Python.common.optical_constants import ANIMATIONS_DIR, DATA_DIR
from Python.common.plotting_utils import prepare_output_dirs, save_figure


ROUTES = {0: 1, 1: 2, 2: 0}


def transmission_matrix(insertion_loss_db=0.6, isolation_db=35.0):
    """Return a power-normalized 3x3 matrix; rows are outputs, columns inputs."""
    matrix = np.zeros((3, 3), dtype=complex)
    desired_power = 10.0 ** (-insertion_loss_db / 10.0)
    leakage_power = 10.0 ** (-isolation_db / 10.0)
    for input_port, output_port in ROUTES.items():
        matrix[output_port, input_port] = np.sqrt(desired_power)
        for other_output in range(3):
            if other_output != output_port:
                matrix[other_output, input_port] = np.sqrt(leakage_power)
    return matrix


def route_power(input_port, input_power_mw=1.0, matrix=None):
    if input_port not in ROUTES:
        raise ValueError("input_port must be 0, 1, or 2")
    matrix = transmission_matrix() if matrix is None else matrix
    return input_power_mw * np.abs(matrix[:, input_port]) ** 2


def run():
    prepare_output_dirs()
    matrix = transmission_matrix()
    figure, axes = plt.subplots(1, 2, figsize=(10, 4.2))
    image = axes[0].imshow(np.abs(matrix) ** 2, cmap="viridis", vmin=0, vmax=1)
    axes[0].set(xticks=range(3), yticks=range(3),
                xticklabels=["P1", "P2", "P3"], yticklabels=["P1", "P2", "P3"],
                xlabel="Input port", ylabel="Output port", title="Port transmission (power)")
    for row in range(3):
        for column in range(3):
            axes[0].text(column, row, f"{abs(matrix[row, column]) ** 2:.3f}",
                         ha="center", va="center", color="white")
    figure.colorbar(image, ax=axes[0], label="Power transmission")
    axes[1].axis("off")
    positions = np.array([[0.5, 0.88], [0.15, 0.2], [0.85, 0.2]])
    for index, (x, y) in enumerate(positions):
        axes[1].plot(x, y, "o", color="#177e89", markersize=18)
        axes[1].text(x, y, f"P{index + 1}", color="white", ha="center", va="center", weight="bold")
    for source, target in ROUTES.items():
        start, end = positions[source], positions[target]
        axes[1].annotate("", xy=end, xytext=start,
                         arrowprops={"arrowstyle": "->", "lw": 2.5, "color": "#d1495b",
                                     "connectionstyle": "arc3,rad=0.15"})
    axes[1].set_title("Ideal cyclic routing: 1 → 2 → 3 → 1")
    axes[1].set_xlim(0, 1)
    axes[1].set_ylim(0, 1)
    figure.suptitle("Three-port fiber optic circulator")
    save_figure(figure, "circulator_transmission.png")

    with (DATA_DIR / "circulator_results.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["output_port", "input_port", "power_transmission"])
        for row in range(3):
            for column in range(3):
                writer.writerow([row + 1, column + 1, abs(matrix[row, column]) ** 2])
    create_animation(positions)
    return matrix


def create_animation(positions=None):
    positions = np.array([[0.5, 0.88], [0.15, 0.2], [0.85, 0.2]]) if positions is None else positions
    figure, axis = plt.subplots(figsize=(5.5, 5))
    axis.set(xlim=(0, 1), ylim=(0, 1), xticks=[], yticks=[])
    axis.set_title("Circulator routes signals from each input port")
    for index, (x, y) in enumerate(positions):
        axis.plot(x, y, "o", color="#177e89", markersize=24)
        axis.text(x, y, f"P{index + 1}", color="white", ha="center", va="center", weight="bold")
    for source, target in ROUTES.items():
        start, end = positions[source], positions[target]
        axis.annotate("", xy=end, xytext=start,
                      arrowprops={"arrowstyle": "->", "lw": 2, "color": "#555555",
                                  "connectionstyle": "arc3,rad=0.15"})
    dots = [axis.plot([], [], "o", color=color, markersize=11)[0]
            for color in ("#d1495b", "#f4a261", "#6a4c93")]
    status = axis.text(0.5, 0.04, "", ha="center")

    def update(frame):
        for signal_index, dot in enumerate(dots):
            source = signal_index
            target = ROUTES[source]
            progress = ((frame / 90.0) + signal_index / 3.0) % 1.0
            start, end = positions[source], positions[target]
            point = (1.0 - progress) * start + progress * end
            dot.set_data([point[0]], [point[1]])
        status.set_text("Simultaneous routing: P1→P2, P2→P3, P3→P1")
        return (*dots, status)

    animation = FuncAnimation(figure, update, frames=90, interval=45, blit=True)
    prepare_output_dirs()
    animation.save(ANIMATIONS_DIR / "circulator_routing.gif", writer=PillowWriter(fps=20))
    plt.close(figure)


if __name__ == "__main__":
    print(run())
