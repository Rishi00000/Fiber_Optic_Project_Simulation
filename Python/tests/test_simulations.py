import unittest

import numpy as np

from Python.circulator.circulator_simulation import ROUTES, route_power, transmission_matrix
from Python.isolator.isolator_simulation import basic_model, jones_transmission
from Python.wdm.wdm_simulation import simulate_wdm


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


class WdmTests(unittest.TestCase):
    def test_channels_are_separated_and_attenuated(self):
        result = simulate_wdm(sample_count=2048, sample_rate_hz=16e12)
        self.assertEqual(len(result["channel_outputs"]), 4)
        self.assertEqual(result["wavelengths_nm"].tolist(), [1530.0, 1540.0, 1550.0, 1560.0])
        self.assertAlmostEqual(result["power_attenuation"], 0.1)
        self.assertTrue(np.all(np.isfinite(result["transmitted"])))


if __name__ == "__main__":
    unittest.main()
