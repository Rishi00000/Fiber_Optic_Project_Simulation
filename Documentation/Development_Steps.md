# Project Development Steps

The repository follows this sequence. The steps are also useful for reproducing
the work in a fresh Windows environment.

1. **Prepare the environment:** create a local `.venv`, install
   `Python/requirements.txt`, and select that interpreter in VS Code.
2. **Create the structure:** keep Python, MATLAB, documentation, and generated
   results in separate folders.
3. **Implement and verify the basic isolator:** calculate forward power from
   insertion loss and reverse power from isolation; compare the results with
   the expected dB equations.
4. **Add the isolator polarization model:** use Jones vectors and a
   non-reciprocal 45-degree Faraday rotation to demonstrate forward passage and
   reverse rejection; generate its graph and animation.
5. **Implement the circulator:** define 1→2→3→1 routing, form a port transfer
   matrix, and visualize the port power and signal paths.
6. **Implement WDM:** create four wavelength channels, combine their complex
   envelopes, propagate through an attenuating and dispersive fiber, and
   separate them with ideal spectral filters.
7. **Mirror the models in MATLAB:** use the same parameters and standard MATLAB
   functionality; compare outputs where both runtimes are available.
8. **Run validation:** execute Python regression tests, verify finite output,
   expected routing, power attenuation, and polarization behavior.
9. **Generate deliverables:** run the Python and MATLAB entry points to create
   graphs, CSV tables, and animations in `Results/`.
10. **Document limitations:** distinguish idealized assumptions from real
    hardware behavior; do not describe computed outputs as experimental
    validation.
