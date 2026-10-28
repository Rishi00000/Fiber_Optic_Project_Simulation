"""Physical constants and common project paths."""

from pathlib import Path

C0_M_PER_S = 299_792_458.0
PROJECT_ROOT = Path(__file__).resolve().parents[2]
RESULTS_DIR = PROJECT_ROOT / "Results"
GRAPHS_DIR = RESULTS_DIR / "Graphs"
ANIMATIONS_DIR = RESULTS_DIR / "Animations"
DATA_DIR = RESULTS_DIR / "Data"
