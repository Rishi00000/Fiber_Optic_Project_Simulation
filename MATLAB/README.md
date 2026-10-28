# MATLAB fiber-optics models

## Run

From MATLAB, change the current folder to this `MATLAB` directory and run:

```matlab
run_all
```

Alternatively, run `isolator_model.m`, `circulator_model.m`, or `wdm_model.m`
from their respective subdirectories. The scripts create project-level output
folders and save labeled PNG plots, CSV data, and educational GIF animations.
They use base MATLAB plotting, `getframe`, and `imwrite` functionality only.

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
- **WDM:** Channels are at 1530, 1540, 1550, and 1560 nm. The model propagates
  sampled complex pulse envelopes (not the rapidly oscillating optical
  carriers), using 1 mW peak Gaussian pulses, 50 km of fiber, 0.2 dB/km
  attenuation, and constant 17 ps/(nm km) dispersion referenced to 1550 nm.
  Group delay is relative to that reference wavelength. Multiplexing is
  represented as the four channel envelopes together; distinct-channel
  powers are summed for the combined trace, and ideal demultiplexing selects
  each channel without crosstalk.
