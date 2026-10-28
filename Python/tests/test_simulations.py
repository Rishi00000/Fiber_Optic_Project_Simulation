import unittest
from contextlib import redirect_stdout
from io import StringIO
from unittest.mock import patch

import numpy as np

from Python.circulator.circulator_simulation import ROUTES, route_power, transmission_matrix
from Python.main import collect_parameters
from Python.isolator.isolator_simulation import basic_model, jones_transmission
from Python.wdm.wdm_simulation import simulate_wdm


class InteractiveInputTests(unittest.TestCase):
    def test_enter_accepts_all_default_parameters(self):
        with patch("builtins.input", side_effect=[""] * 18):
            with redirect_stdout(StringIO()):
                isolator, circulator, wdm = collect_parameters()
        self.assertEqual(isolator["input_power_mw"], 10.0)
        self.assertEqual(circulator["insertion_loss_db"], 0.6)
        self.assertEqual(wdm["wavelengths_nm"], [1530.0, 1540.0, 1550.0, 1560.0])

    def test_custom_wdm_channel_count_and_values_are_collected(self):
        answers = [
            "12", "1", "35", "0", "30", "30",
            "2", "1.2", "28",
            "2", "1535", "1555", "25", "0.3", "-20", "12",
        ]
        with patch("builtins.input", side_effect=answers):
            with redirect_stdout(StringIO()):
                isolator, circulator, wdm = collect_parameters()
        self.assertEqual(isolator["input_power_mw"], 12.0)
        self.assertEqual(circulator["input_power_mw"], 2.0)
        self.assertEqual(wdm["wavelengths_nm"], [1535.0, 1555.0])
        self.assertEqual(wdm["fiber_length_km"], 25.0)

    def test_invalid_wdm_filter_settings_are_reprompted(self):
        answers = (
            [""] * 9
            + ["2", "1550", "1550.1", "50", "0.2", "-21.7", "20"]
            + ["1", "1530", "50", "0.2", "-21.7", "18"]
        )
        output = StringIO()
        with patch("builtins.input", side_effect=answers):
            with redirect_stdout(output):
                _, _, wdm = collect_parameters()
        self.assertIn("channel filter bandwidth", output.getvalue())
        self.assertEqual(wdm["wavelengths_nm"], [1530.0])


class IsolatorTests(unittest.TestCase):
    def test_basic_power_model(self):
        result = basic_model()
        self.assertAlmostEqual(result["forward_power_mw"], 10.0 * 10.0 ** (-0.5 / 10.0))
        self.assertAlmostEqual(result["reverse_power_mw"], 0.01)
        self.assertAlmostEqual(result["isolation_db"], 30.0)

    def test_jones_model_passes_forward_and_blocks_reverse(self):
        forward, reverse = jones_transmission(0.0, 45.0, 45.0)
        self.assertAlmostEqual(forward, 1.0)
        self.assertLess(reverse, 1e-12)

    def test_jones_model_uses_selected_angles(self):
        forward, _ = jones_transmission(0.0, 30.0, 30.0)
        self.assertAlmostEqual(forward, 1.0)


class CirculatorTests(unittest.TestCase):
    def test_cyclic_routes_and_loss(self):
        matrix = transmission_matrix()
        self.assertEqual(ROUTES, {0: 1, 1: 2, 2: 0})
        for input_port, output_port in ROUTES.items():
            powers = route_power(input_port, matrix=matrix)
            self.assertEqual(int(np.argmax(powers)), output_port)
            self.assertAlmostEqual(powers[output_port], 10.0 ** (-0.6 / 10.0))

    def test_invalid_input_port_is_reported(self):
        with self.assertRaises(ValueError):
            route_power(3)

    def test_custom_loss_parameters_change_matrix(self):
        matrix = transmission_matrix(insertion_loss_db=3.0, isolation_db=20.0)
        self.assertAlmostEqual(abs(matrix[1, 0]) ** 2, 10.0 ** (-3.0 / 10.0))
        self.assertAlmostEqual(abs(matrix[0, 0]) ** 2, 10.0 ** (-20.0 / 10.0))


class WdmTests(unittest.TestCase):
    def test_channels_are_separated_and_attenuated(self):
        result = simulate_wdm(sample_count=2048, sample_rate_hz=16e12)
        self.assertEqual(len(result["channel_outputs"]), 4)
        self.assertEqual(result["wavelengths_nm"].tolist(), [1530.0, 1540.0, 1550.0, 1560.0])
        self.assertAlmostEqual(result["power_attenuation"], 0.1)
        self.assertTrue(np.all(np.isfinite(result["transmitted"])))

    def test_channel_count_and_fiber_parameters_are_configurable(self):
        result = simulate_wdm(
            sample_count=2048,
            sample_rate_hz=16e12,
            wavelengths_nm=[1535.0, 1555.0],
            fiber_length_km=25.0,
            attenuation_db_per_km=0.4,
        )
        self.assertEqual(len(result["channel_outputs"]), 2)
        self.assertEqual(result["wavelengths_nm"].tolist(), [1535.0, 1555.0])
        self.assertAlmostEqual(result["power_attenuation"], 0.1)

    def test_duplicate_wavelengths_are_rejected(self):
        with self.assertRaises(ValueError):
            simulate_wdm(wavelengths_nm=[1550.0, 1550.0])

    def test_modulation_must_fit_demultiplexer_channel_bandwidth(self):
        with self.assertRaisesRegex(ValueError, "channel filter bandwidth"):
            simulate_wdm(
                wavelengths_nm=[1550.0, 1550.1],
                modulation_hz=20e9,
            )


if __name__ == "__main__":
    unittest.main()
