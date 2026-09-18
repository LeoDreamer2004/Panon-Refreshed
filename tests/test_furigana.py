import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "contents/scripts"))
from panon.backend.furigana import align, annotate, annotate_lines, reading_kana
from panon.backend.lyrics import LyricBundle, MediaState, _fetch_and_cache_lyrics, _read_lyric_cache, lyric_window
import tempfile


class FuriganaTests(unittest.TestCase):
    def test_seek_timestamps_are_seconds(self):
        model = lyric_window([(1.25, "first"), (65.3, "next")], [], 2)
        self.assertEqual([e["timestamp"] for e in model["entries"]], [1.25, 65.3])

    def test_syllabic_n(self):
        self.assertEqual(reading_kana("shi n a i"), "しんあい")
        self.assertEqual(reading_kana("kitto"), "きっと")
        self.assertEqual(reading_kana("キミ"), "きみ")

    def test_platform_overrides_dictionary(self):
        parts = annotate("君の運命を信じている", "ki mi no sa da me wo shi n ji te i ru")
        self.assertIn({"text": "運命", "reading": "さだめ", "source": "netease"}, parts)
        self.assertEqual("".join(p["text"] for p in parts), "君の運命を信じている")

    def test_real_netease_sample(self):
        text = "虹の橋が架かる　静かな雨上がり"
        parts = annotate(text, "ni ji no ha shi ga ka ka ru shi zu ka na a me a ga ri")
        self.assertEqual("".join(p["text"] for p in parts), text)
        self.assertTrue(all(p["source"] == "netease" for p in parts if p["reading"]))

    def test_fallback_and_okurigana(self):
        parts = annotate("信じている", "bad incompatible reading")
        self.assertIn({"text": "信", "reading": "しん", "source": "local"}, parts)

    def test_no_chinese_annotation(self):
        self.assertEqual(annotate_lines("月亮", [(0, "月亮代表我的心")], []), [[]])
        self.assertTrue(annotate_lines("First Song", [(0, "虹の橋")], [])[0])

    def test_timestamp_mismatch(self):
        parts = annotate_lines("うた", [(10, "運命")], [(20, "sa da me")])[0]
        self.assertTrue(all(p["source"] != "netease" for p in parts))

    def test_ambiguity_rejected(self):
        self.assertIsNone(align("甲の乙", "あのいのう"))
        self.assertIsNone(align("光る", "まったくちがう"))

    def test_cache_and_request(self):
        response = {"lrc": {"lyric": "[00:01]君の運命"},
                    "tlyric": {"lyric": "[00:01]你的命运"},
                    "romalrc": {"lyric": "[00:01]ki mi no sa da me"}}
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder) / "lyrics.json"
            with patch(
                "panon.backend.lyrics._request_netease", return_value=response
            ) as request:
                bundle = _fetch_and_cache_lyrics(MediaState(title="うた", provider="netease", song_id="1"), cache)
            self.assertEqual(request.call_args.args[1]["rv"], 0)
            self.assertEqual(request.call_args.args[1]["yv"], 0)
            self.assertEqual(bundle.readings, [(1., "ki mi no sa da me")])
            self.assertEqual(_read_lyric_cache(cache).readings, bundle.readings)


if __name__ == "__main__":
    unittest.main()
