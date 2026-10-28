"""Run all fiber optic simulations and generate project outputs."""

from Python.circulator.circulator_simulation import run as run_circulator
from Python.common.interactive import (
    prompt_float,
    prompt_positive_integer,
    prompt_wavelengths,
)
from Python.isolator.isolator_simulation import run as run_isolator
from Python.wdm.wdm_simulation import run as run_wdm, simulate_wdm


DEFAULT_WAVELENGTHS_NM = [1530.0, 1540.0, 1550.0, 1560.0]


def collect_parameters():
    print("Enter simulation parameters. Press Enter to accept each default.\n")

    print("ISOLATOR")
    isolator = {
        "input_power_mw": prompt_float("Input power (mW)", 10.0, minimum=1e-12),
        "insertion_loss_db": prompt_float("Insertion loss (dB)", 0.5, minimum=0.0),
        "isolation_db": prompt_float("Reverse isolation (dB)", 30.0, minimum=0.0),
        "input_angle_deg": prompt_float("Input polarizer angle (degrees)", 0.0),
        "faraday_angle_deg": prompt_float("Faraday rotation (degrees)", 45.0),
        "analyzer_angle_deg": prompt_float("Output analyzer angle (degrees)", 45.0),
    }

    print("\nCIRCULATOR (three ports; cyclic routing 1 -> 2 -> 3 -> 1)")
    circulator = {
        "input_power_mw": prompt_float("Input power per port (mW)", 1.0, minimum=0.0),
        "insertion_loss_db": prompt_float("Routed-path insertion loss (dB)", 0.6, minimum=0.0),
        "isolation_db": prompt_float("Unwanted-port attenuation (dB)", 35.0, minimum=0.0),
    }

    print("\nWDM")
    while True:
        channel_count = prompt_positive_integer("Number of wavelength channels", 4)
        wavelengths_nm = prompt_wavelengths(channel_count, DEFAULT_WAVELENGTHS_NM)
        wdm = {
            "wavelengths_nm": wavelengths_nm,
            "fiber_length_km": prompt_float("Fiber length (km)", 50.0, minimum=1e-9),
            "attenuation_db_per_km": prompt_float(
                "Fiber attenuation (dB/km)", 0.2, minimum=0.0
            ),
            "beta2_ps2_per_km": prompt_float("Dispersion beta2 (ps^2/km)", -21.7),
            "modulation_hz": prompt_float(
                "Modulation frequency (GHz)", 18.0, minimum=0.0
            ) * 1e9,
        }
        try:
            simulate_wdm(**wdm)
        except ValueError as error:
            print(f"Those WDM settings cannot be simulated: {error}")
            print("Please enter the WDM settings again.")
            continue
        break
    return isolator, circulator, wdm


def main():
    isolator_parameters, circulator_parameters, wdm_parameters = collect_parameters()

    print("\nRunning simulations and generating outputs...")
    print("Selected isolator parameters:", isolator_parameters)
    print("Selected circulator parameters:", circulator_parameters)
    print("Selected WDM parameters:", wdm_parameters)
    print("Isolator:", run_isolator(**isolator_parameters))
    print("Circulator power transmission matrix:")
    circulator_matrix = run_circulator(**circulator_parameters)
    print(abs(circulator_matrix) ** 2)
    wdm_result = run_wdm(**wdm_parameters)
    print(
        "WDM channels:",
        len(wdm_result["wavelengths_nm"]),
        "wavelengths (nm):",
        wdm_result["wavelengths_nm"].tolist(),
    )
    print("WDM output power transmission:", wdm_result["power_attenuation"])
    print("Simulation complete. See Results/Graphs, Results/Animations, and Results/Data.")


if __name__ == "__main__":
    main()
