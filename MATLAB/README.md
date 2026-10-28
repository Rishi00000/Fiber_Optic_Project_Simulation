# MATLAB fiber-optics models

## Run

From MATLAB, change the current folder to the project root and run:

```matlab
run('MATLAB/run_all.m')
```

The runner interactively prompts for isolator parameters, circulator input
power/loss/isolation, WDM channel count and wavelengths, and fiber parameters.
Press Enter to accept the shown default. The circulator remains a three-port
cyclic model. To run a component script alone, run `isolator_model.m`,
`circulator_model.m`, or `wdm_model.m` from its respective directory; those
scripts use the documented example defaults. The scripts create project-level
output folders and save labeled PNG plots, CSV data, and educational GIF
animations. They use base MATLAB plotting, `getframe`, and `imwrite`
functionality only.

The WDM animation shows five stages of the full channel route: separate
transmitters, MUX combining, shared-fiber propagation, DEMUX separation, and
the corresponding receivers.

## Model conventions and assumptions

- **Isolator:** Power is in mW. The scalar model uses 0.5 dB forward insertion
  loss and 30 dB reverse attenuation relative to the input, yielding 0.01 mW
  reverse output for the 10 mW example. The ideal Jones model uses an input
  polarizer at 0 degrees, a +45 degree non-reciprocal Faraday rotation, and an
  analyzer at +45 degrees; its polarization-only forward/reverse transmissions
  are 1 and 0.
- **Circulator:** Transfer matrix entries are power ratios; rows identify
  output ports and columns identify input ports. The ideal mapping is
  1 to 2, 2 to 3, and 3 to 1. The illustrative lossy matrix assumes 0.6 dB
  insertion loss on the routed paths and -35 dB coupling to each unintended
  output. These are explicit model assumptions, not device specifications.
- **WDM:** The interactive runner accepts a channel count and unique
  wavelengths (defaults: 1530, 1540, 1550, and 1560 nm). It propagates sampled
  complex envelopes using the same modulation, 50 km fiber, 0.2 dB/km
  attenuation, and \(\beta_2=-21.7\) ps²/km dispersion parameters as Python.
  An ideal frequency-mask demultiplexer separates the channels. Channel
  values that exceed the simulation's sampling bandwidth are rejected.
