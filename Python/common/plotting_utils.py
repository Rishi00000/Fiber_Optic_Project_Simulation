"""Small helpers shared by simulation plotting code."""

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt

from .optical_constants import ANIMATIONS_DIR, DATA_DIR, GRAPHS_DIR


def prepare_output_dirs():
    for path in (GRAPHS_DIR, ANIMATIONS_DIR, DATA_DIR):
        path.mkdir(parents=True, exist_ok=True)


def save_figure(figure, filename):
    prepare_output_dirs()
    target = GRAPHS_DIR / filename
    figure.savefig(target, dpi=160, bbox_inches="tight")
    plt.close(figure)
    return target
