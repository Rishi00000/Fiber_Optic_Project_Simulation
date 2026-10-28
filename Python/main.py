"""Run all fiber optic simulations and generate project outputs."""

from Python.circulator.circulator_simulation import run as run_circulator
from Python.isolator.isolator_simulation import run as run_isolator
from Python.wdm.wdm_simulation import run as run_wdm


def main():
    print("Isolator:", run_isolator())
    print("Circulator power transmission matrix:")
    print(abs(run_circulator()) ** 2)
    print("WDM attenuation factor:", run_wdm()["power_attenuation"])


if __name__ == "__main__":
    main()
