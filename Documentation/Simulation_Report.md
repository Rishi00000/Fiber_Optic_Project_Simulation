# Simulation Report

## Abstract

This project implements reproducible educational models for a fiber optic
isolator, a three-port optical circulator, and four-channel wavelength division
multiplexing (WDM). Python generates plots, numerical CSV tables, and animated
schematics. Equivalent MATLAB scripts use the same headline parameters and
equations. The results are deterministic model outputs, not experimental
measurements or predictions of a commercial link.

## Objectives

1. Calculate forward/reverse isolator power and show the polarization
   selectivity created by a non-reciprocal Faraday rotation.
2. Represent three-port circulator routing and finite insertion loss/isolation.
3. Generate four optical wavelength channels, combine them, model fiber loss
   and second-order dispersion, and separate the channel envelopes.
4. Compare the implementation equations across Python and MATLAB and make the
   assumptions inspectable.

## Method

The scalar isolator uses power ratios in dB. Its detailed polarization example
uses ideal Jones projections at 0 and 45 degrees and a 45-degree Faraday
rotation. The circulator is represented by a 3x3 transfer matrix whose rows are
outputs and columns are inputs. WDM channels use complex envelopes with optical
frequency centers derived from wavelength; the summed field is propagated by
an FFT-domain second-order dispersion response and a scalar attenuation factor.
The detailed equations and limitations are in
[`Mathematical_Models.md`](Mathematical_Models.md).

## Parameters and numerical results

| System | Illustrative parameters | Verified Python result |
|---|---|---|
| Isolator scalar | 10 mW input, 0.5 dB insertion loss, 30 dB reverse attenuation | 8.9125 mW forward; 0.0100 mW reverse; 30 dB reverse attenuation |
| Isolator Jones | 0° input polarizer, 45° Faraday rotation, 45° analyzer | 1 normalized forward transmission; 0 ideal reverse transmission |
| Circulator | 3 ports, 0.6 dB routed-path loss, 35 dB unwanted-port attenuation | Routed power transmission 0.87096; unwanted-port transmission 0.0003162 |
| WDM | 1530/1540/1550/1560 nm, 50 km, 0.2 dB/km, \(\beta_2=-21.7\) ps²/km | 10 dB fiber power loss (0.1 power factor); four separated output envelopes |

The Python regression suite currently passes all thirteen numerical tests. The
corresponding CSV tables and generated figures/GIFs are saved in `Results/`.
No physical measurements or laboratory calibration data were supplied.

## Python/MATLAB comparison

Both implementations prompt for model parameters and offer matching default
values. The MATLAB scripts use the same isolator input power, insertion-loss
and isolation values; the same circulator routing, insertion loss, and
unwanted-port attenuation; and the same WDM wavelengths, sample count/rate,
attenuation, dispersion coefficient, modulation, and frequency-domain channel
masks. The WDM FFT and
attenuation equations are implemented with each language's native FFT
conventions.

MATLAB and Octave were not installed in the development environment, so MATLAB
execution and a numerical output-to-output comparison could not be completed.
The listed comparison establishes matching model equations and settings, not
runtime validation. Run `MATLAB/run_all.m` in MATLAB to generate its outputs.

## Interpretation and limitations

The ideal Jones model predicts exactly zero reverse transmission; real
polarizers have finite extinction and real devices have reflections and other
losses. The circulator's matrix is a phenomenological port description, not a
component-level magneto-optic design. The WDM model omits noise, nonlinear
effects, polarization-mode dispersion, receiver noise, practical filter
imperfections, and transmitter/receiver electronics. The animation tracks are
schematic and are not literal optical-carrier field simulations.

Therefore, the simulations are suitable for illustrating equations and
parameter trends, but should not be used to select or certify physical
components or communication links.

## Reproduction

From the project root on Windows:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r Python\requirements.txt
python -m Python.main
python -m unittest discover -s Python\tests -v
```

In MATLAB, run `run('MATLAB/run_all.m')` from the project root. MATLAB runtime
availability is required to verify its scripts and animations.
