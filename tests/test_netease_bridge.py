import json
from dataclasses import replace
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "contents/scripts"))
from panon.backend.netease_bridge import read_track, read_record
from panon.backend.lyrics import MediaState, _cache_path, _fetch_lyrics, _fetch_and_cache_lyrics, _read_lyric_cache


class BridgeTests(unittest.TestCase):
    def test_qqmusic_separate_provider_and_embedded_lyrics(self):
        self.file = self.file.with_name("qqmusic-42.json")
        self.data.update(provider="qqmusic", lyricsReady=True, lyric="[00:01]exact QQ lyric", translation="[00:01]中文翻译")
        self.write()
        record = read_record(42, "song", "artist", "album", provider="qqmusic", runtime=self.tmp.name, now=101)
        self.assertEqual(record["songId"], "123")
        self.assertIsNone(self.read())
        with patch("panon.backend.lyrics._request_netease", side_effect=AssertionError("Wrong provider")):
            state = MediaState(provider="qqmusic", song_id="123", title="song",
                               lyrics_ready=True, embedded_lyrics=record["lyric"], embedded_translation=record["translation"])
            self.assertEqual(_fetch_lyrics(state).lines, [(1., "exact QQ lyric")])
            self.assertEqual(_fetch_lyrics(state).translations, [(1., "中文翻译")])
            translated_identity = state.identity
            state = replace(state, embedded_translation="")
            self.assertNotEqual(translated_identity, state.identity)
            self.assertEqual(_fetch_lyrics(MediaState(provider="qqmusic", song_id="123", title="song")).lines, [])

    def test_invalid_qq_translation(self):
        self.file = self.file.with_name("qqmusic-42.json")
        for value in (None, {}, "a" * 300001):
            self.data.update(provider="qqmusic", translation=value)
            self.write()
            self.assertIsNone(read_record(42, "song", "artist", "album", provider="qqmusic", runtime=self.tmp.name, now=101))

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.file = Path(self.tmp.name) / "panon/netease-42.json"
        self.file.parent.mkdir()
        self.data = dict(version=1, provider="netease", pid=42, updatedAt=100,
                         songId="123", title="song", artist="artist", album="album")

    def write(self):
        self.file.write_text(json.dumps(self.data))
        self.file.chmod(0o600)

    def read(self, **kwargs):
        return read_track(42, "song", "artist", "album", runtime=self.tmp.name, now=101, **kwargs)

    def test_valid(self):
        self.write()
        self.assertEqual(self.read(), "123")

    def test_invalid_identity_and_staleness(self):
        for field, value in [("pid", 43), ("provider", "other"), ("title", "other"),
                             ("artist", "other"), ("album", "other"), ("updatedAt", 90),
                             ("updatedAt", 102), ("songId", None), ("songId", "../123")]:
            with self.subTest(field=field, value=value):
                saved = self.data[field]
                self.data[field] = value
                self.write()
                self.assertIsNone(self.read())
                self.data[field] = saved

    def test_unsafe_file(self):
        self.write()
        self.file.chmod(0o644)
        self.assertIsNone(self.read())
        target = self.file.with_suffix(".real")
        self.file.rename(target)
        self.file.symlink_to(target)
        self.assertIsNone(self.read())

    def test_no_id_never_searches(self):
        with patch(
            "panon.backend.lyrics.urllib.request.urlopen", side_effect=AssertionError("Network forbidden without ID")
        ):
            self.assertEqual(_fetch_lyrics(MediaState(title="song")).lines, [])

    def test_exact_route_no_alternate_recordings(self):
        with patch("panon.backend.lyrics._request_netease", return_value={"lrc":{"lyric":"[00:01]exact"}}) as request:
            bundle = _fetch_and_cache_lyrics(MediaState(title="song", provider="netease", song_id="123"), self.file)
            self.assertEqual(bundle.lines, [(1., "exact")])
            self.assertEqual(request.call_args.args[1]["id"], 123)
            self.assertTrue(all(url.endswith("/api/song/lyric") for url in request.call_args.args[0]))
            self.assertEqual(request.call_count, 1)

    def test_same_title_different_id_has_separate_cache(self):
        a = MediaState(title="same", provider="netease", song_id="123")
        b = MediaState(title="same", provider="netease", song_id="456")
        self.assertNotEqual(_cache_path(a), _cache_path(b))
        self.assertNotEqual(a.identity, b.identity)

    def test_instrumental_requires_explicit_flag_and_no_lyrics(self):
        state = MediaState(title="song", provider="netease", song_id="123")
        for response, expected in [
            ({"pureMusic": True}, True),
            ({"nolyric": True}, True),
            ({"pureMusic": False, "uncollected": True}, False),
            ({}, False),
            ({"pureMusic": "true"}, False),
            ({"pureMusic": True, "lrc": {"lyric": "[00:01]actual lyric"}}, False),
        ]:
            with self.subTest(response=response), patch(
                "panon.backend.lyrics._request_netease", return_value=response
            ):
                bundle = _fetch_and_cache_lyrics(state, self.file)
                self.assertEqual(bundle.instrumental, expected)
                self.assertEqual(_read_lyric_cache(self.file).instrumental, expected)

    def test_only_old_empty_cache_needs_refresh(self):
        payload = dict(lines=[], provider_version=5, checked_at=100, instrumental=False)
        self.file.write_text(json.dumps(payload))
        with patch("panon.backend.lyrics.time.time", return_value=101):
            self.assertIsNone(_read_lyric_cache(self.file))
            payload.update(provider_version=6, instrumental=True)
            self.file.write_text(json.dumps(payload))
            self.assertTrue(_read_lyric_cache(self.file).instrumental)
            payload.update(provider_version=5, lines=[[1, "existing lyric"]], instrumental=False)
            self.file.write_text(json.dumps(payload))
            self.assertEqual(_read_lyric_cache(self.file).lines, [(1., "existing lyric")])


if __name__ == "__main__":
    unittest.main()
