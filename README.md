# Fiber Optic Isolator, Circulator, and WDM Simulation

An educational, reproducible simulation project covering three fiber-optic
systems. Python is the primary implementation; equivalent MATLAB scripts are
provided in [`MATLAB/`](MATLAB/). The models are idealized numerical examples,
not commercial component designs or experimentally validated measurements.

## Features

- **Isolator:** basic insertion-loss/isolation power equations and a Jones
  polarization model with a non-reciprocal Faraday rotator.
- **Circulator:** ideal three-port cyclic routing and a lossy/leaky power
  transfer matrix.
- **WDM:** configurable wavelength channels, complex-envelope multiplexing, fiber
  attenuation and second-order chromatic dispersion, and frequency-domain
  demultiplexing.
- Labeled plots, CSV result tables, and educational GIF animations are generated
  under `Results/`. The WDM animation shows the channel flow through transmitters,
  MUX, shared fiber, DEMUX, and receivers; a storyboard and final diagram frame
  are also saved for presentation. A second, fiber-only WDM wave animation is
  retained to focus on co-propagation inside the shared fiber.
- Python and MATLAB use the same illustrative system parameters.

## Requirements and setup (Windows)

Python 3.9 or newer is recommended. From the project root in PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r Python\requirements.txt
python -m Python.main
```

In VS Code, select `.venv\Scripts\python.exe` as the Python interpreter. If
PowerShell blocks activation, run the program directly with
`.venv\Scripts\python.exe -m Python.main`.

The run-all command interactively asks for simulation parameters. Press Enter
at a prompt to use its displayed default. It collects isolator power/loss and
polarization angles, circulator input power and loss/isolation, then WDM
channel count and each wavelength, fiber length/loss/dispersion, and modulation
frequency. The circulator remains a three-port cyclic device. WDM wavelengths
must be unique positive values; the run reports a clear validation error if
the requested channels exceed the simulation sample-rate bandwidth.

The simulations use NumPy and Matplotlib; Pillow enables GIF export. No SciPy,
special MATLAB toolbox, or commercial optical simulator is required.

## Project layout

```text
Python/
  common/                 Shared constants and plotting helpers
  isolator/               Basic and Jones-matrix isolator model
  circulator/             Three-port transfer-matrix model
  wdm/                    Complex-envelope WDM propagation model
  tests/                  Numerical regression tests
  main.py                 Generates outputs for all three systems
MATLAB/
  Isolator/ Circulator/ WDM/   MATLAB equivalents
  run_all.m                    Runs all MATLAB examples
Results/
  Graphs/ Animations/ Data/    Generated outputs
Documentation/                 Model derivations and assumptions
```

Run the numerical tests from the project root:

```powershell
python -m unittest discover -s Python\tests -v
```

## Model summary

### Isolator

The basic model uses input power \(P_\mathrm{in}\), insertion loss \(IL\), and
reverse isolation \(ISO\):

\[
P_\mathrm{forward}=P_\mathrm{in}10^{-IL/10},\qquad
P_\mathrm{reverse}=P_\mathrm{in}10^{-ISO/10}.
\]

The Jones model represents linear polarizers as projections and the Faraday
rotator as \(R(\phi)\). The rotation is non-reciprocal: it has the same signed
angle in either propagation direction. A forward input aligned at 0 degrees
rotates by 45 degrees and passes a 45-degree analyzer; reverse light undergoes
another 45-degree rotation and is rejected by the input polarizer. The
illustrative Jones result is lossless apart from polarization rejection; the
basic model separately represents insertion loss.

### Circulator

The ideal routing is port 1→2, 2→3, and 3→1. The transfer matrix is organized
as output rows by input columns. The detailed matrix assigns the requested
insertion loss to the routed output and the isolation level to each unwanted
output. It is a phenomenological port model, not a component-by-component
magneto-optic design.

### WDM

The four illustrative wavelengths are 1530, 1540, 1550, and 1560 nm. Their
optical-frequency offsets from a reference carrier are represented by sampled
complex envelopes. Propagation applies a power attenuation of 0.2 dB/km and
the second-order dispersion transfer function
\[
H(f)=\exp(-j\,2\pi^2\beta_2 L f^2).
\]
Ideal rectangular spectral masks separate the channels. The model omits noise,
nonlinear effects, realistic transmitter/receiver electronics, and filter
imperfections; therefore it does not predict commercial link performance.
Wavelength values are illustrative and are not asserted to follow a standard
channel grid.

Further equations, parameter values, and limitations are in
[`Documentation/Mathematical_Models.md`](Documentation/Mathematical_Models.md).
The development sequence is in [`Documentation/Development_Steps.md`](Documentation/Development_Steps.md).
The academic-style result summary and implementation comparison are in
[`Documentation/Simulation_Report.md`](Documentation/Simulation_Report.md).

## Reproducibility and interpretation

`python -m Python.main` prompts for values and creates PNG figures in `Results/Graphs/`, GIFs in
`Results/Animations/`, and numerical tables in `Results/Data/`. The GIFs are
schematic visualizations tied to each model; they do not represent measured
electromagnetic field propagation at literal optical carrier frequency.
MATLAB can be run with `run('MATLAB/run_all.m')` from the project root; it
prompts for equivalent parameters and also offers the defaults. If
MATLAB is unavailable, the Python implementation remains independently
executable.

## References

- G. P. Agrawal, *Fiber-Optic Communication Systems*, 4th ed., Wiley.
- B. E. A. Saleh and M. C. Teich, *Fundamentals of Photonics*, 2nd ed., Wiley.
- A. Yariv and P. Yeh, *Photonics: Optical Electronics in Modern Communications*, 6th ed., Oxford University Press.
