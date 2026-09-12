"""Synthetic audio regressions; no sound device or network required."""
import sys
import time
import unittest
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "contents/scripts"))
from panon.backend.client import SpectrumAnalyzer


def tone(analyzer, frequency, seconds=0.5):
    count = analyzer.frame_count
    for i in range(int(np.ceil(seconds * analyzer.sample_rate / count))):
        t = (np.arange(count) + i * count) / analyzer.sample_rate
        values, level = analyzer.analyze((0.5 * np.sin(2 * np.pi * frequency * t)).astype(np.float32))
    return np.array(values)


class SpectrumTests(unittest.TestCase):
    def test_every_log_band_receives_its_tone(self):
        for fps in (20, 30, 60):
            analyzer = SpectrumAnalyzer(48000, 48000 // fps, 64, 82)
            centers = np.sqrt(analyzer.edges[:-1] * analyzer.edges[1:])
            for index, frequency in enumerate(centers):
                analyzer.reset()
                values = tone(analyzer, frequency)
                self.assertGreater(values[index], 0.7, (fps, index, frequency, values[index]))
                self.assertLessEqual(abs(int(np.argmax(values)) - index), 1)

    def test_silence_and_reset(self):
        analyzer = SpectrumAnalyzer(48000, 1600, 64, 82)
        self.assertEqual(analyzer.analyze(np.zeros(1600))[0], [0.] * 64)
        tone(analyzer, 80)
        analyzer.reset()
        self.assertEqual(analyzer.analyze(np.zeros(1600))[0], [0.] * 64)
        self.assertEqual(analyzer.analyze(np.array([]))[1], 0)

    def test_fft_resolution_independent_of_fps(self):
        a = SpectrumAnalyzer(48000, 800, 64, 82)
        b = SpectrumAnalyzer(48000, 2400, 64, 82)
        self.assertEqual(list(a.windows), list(b.windows))
        self.assertEqual(max(a.windows), 16384)
        self.assertEqual(min(a.windows), 1024)

    def test_supported_band_counts(self):
        for bands in (8, 32, 64, 128):
            analyzer = SpectrumAnalyzer(48000, 800, bands, 82)
            values, level = analyzer.analyze(np.random.default_rng(3).normal(0, .1, 800))
            self.assertEqual(len(values), bands)
            self.assertTrue(np.isfinite(values).all())
            self.assertGreater(level, 0)

    def test_treble_responds_faster_than_bass(self):
        response_frames = []
        for frequency in (50, 5000):
            analyzer = SpectrumAnalyzer(48000, 800, 64, 82)
            index = int(np.searchsorted(analyzer.edges, frequency) - 1)
            for frame in range(30):
                t = (np.arange(800) + frame * 800) / 48000
                values, _ = analyzer.analyze(0.5 * np.sin(2 * np.pi * frequency * t))
                if values[index] >= 0.7:
                    response_frames.append(frame + 1)
                    break
            else:
                self.fail("Tone failed to settle within half a second")
        self.assertLess(response_frames[1], response_frames[0])
        self.assertLessEqual(response_frames[1], 2)


if __name__ == "__main__":
    started = time.perf_counter()
    result = unittest.main(exit=False).result
    if not result.wasSuccessful():
        sys.exit(1)
    analyzer = SpectrumAnalyzer(48000, 800, 64, 82)
    samples = np.random.default_rng(1).normal(0, .1, 800).astype(np.float32)
    started = time.perf_counter()
    for _ in range(1000):
        analyzer.analyze(samples)
    print(f"Mean analysis time: {(time.perf_counter() - started):.3f} ms/frame (1000 frames)")
