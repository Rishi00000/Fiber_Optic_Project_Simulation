"""Validated console prompts shared by the interactive Python runner."""

import math


def prompt_float(label, default, minimum=None):
    while True:
        raw_value = input(f"{label} [{default}]: ").strip()
        if not raw_value:
            return float(default)
        try:
            value = float(raw_value)
        except ValueError:
            print("Enter a numeric value.")
            continue
        if not math.isfinite(value):
            print("Enter a finite numeric value.")
            continue
        if minimum is not None and value < minimum:
            print(f"Enter a value greater than or equal to {minimum}.")
            continue
        return value


def prompt_positive_integer(label, default):
    while True:
        raw_value = input(f"{label} [{default}]: ").strip()
        if not raw_value:
            return int(default)
        try:
            value = int(raw_value)
        except ValueError:
            print("Enter a whole number.")
            continue
        if value < 1:
            print("Enter a value of at least 1.")
            continue
        return value


def prompt_wavelengths(channel_count, defaults):
    wavelengths = []
    for channel_index in range(channel_count):
        default = defaults[channel_index] if channel_index < len(defaults) else (
            defaults[-1] + 10.0 * (channel_index + 1 - len(defaults))
        )
        while True:
            wavelength = prompt_float(
                f"Channel {channel_index + 1} wavelength (nm)", default, minimum=0.0
            )
            if wavelength == 0.0:
                print("Wavelength must be greater than zero.")
            elif wavelength in wavelengths:
                print("Wavelengths must be unique.")
            else:
                wavelengths.append(wavelength)
                break
    return wavelengths
