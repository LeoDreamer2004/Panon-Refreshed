import sys
import unittest
import tempfile
from unittest.mock import patch
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "contents/scripts"))
from panon.backend.lyrics import parse_yrc, parse_lrc, lrc_timeline, playback_lyric_timing, MediaState, _fetch_and_cache_lyrics, _read_lyric_cache


class YrcTests(unittest.TestCase):
    def test_fetch_prefers_yrc_and_roundtrips_cache(self):
        payload = {'code': 200, 'lrc': {'lyric': '[00:01]old'},
                   'yrc': {'lyric': '[1200,900](1200,300,0)君(1500,600,0)の夢'},
                   'ytlrc': {'lyric': '[00:01.200]你的梦'}}
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder) / 'lyric.json'
            with patch('panon.backend.lyrics._request_netease', return_value=payload):
                result = _fetch_and_cache_lyrics(MediaState(provider='netease', song_id='1'), cache)
            self.assertEqual(result.lines, [(1.2, '君の夢')])
            self.assertEqual(result.translations, [(1.2, '你的梦')])
            self.assertEqual(_read_lyric_cache(cache).words, result.words)
            self.assertEqual(_read_lyric_cache(cache).timeline, result.timeline)

    def test_yrc_keeps_blank_intervals_and_empty_word(self):
        lines, words, timeline = parse_yrc(
            '[1000,3000](1000,500,0)君(1500,1500,0)(3000,1000,0)の夢\n'
            '[4000,6000]\n[10000,1000](10000,1000,0)空', with_timeline=True)
        self.assertEqual(lines, [(1, '君の夢'), (10, '空')])
        self.assertEqual(words[0][1], {'text': '', 'start': 1.5, 'duration': 1.5})
        self.assertEqual(timeline[1], {'start': 4, 'end': 10, 'blank': True})
        self.assertEqual(words[0][2]['start'], 3)

    def test_lrc_blank_closes_previous_line_without_displaying_it(self):
        source = '[00:01]first\n[00:03]\n[00:10]next'
        self.assertEqual(parse_lrc(source), [(1, 'first'), (10, 'next')])
        timeline = lrc_timeline(source)
        self.assertEqual(timeline[0]['end'], 3)
        self.assertTrue(timeline[1]['blank'])

    def test_silence_does_not_extend_scroll_duration_and_seek_recomputes(self):
        entries = [{'timestamp': 1, 'end': 3}, {'timestamp': 10, 'end': 12}]
        gap = playback_lyric_timing(entries, 0, 6, 15)
        self.assertEqual(gap['end'], 3)
        self.assertEqual(gap['nextStart'], 10)
        self.assertTrue(gap['inGap'])
        self.assertFalse(playback_lyric_timing(entries, 0, 2, 15)['inGap'])
        self.assertTrue(playback_lyric_timing(entries, 1, 14, 15)['inGap'])
        self.assertTrue(playback_lyric_timing(entries, -1, 0, 15)['inGap'])

    def test_millisecond_timing_and_text(self):
        lines, words = parse_yrc('[1200,900](1200,300,0)君(1500,600,0)の夢')
        self.assertEqual(lines, [(1.2, '君の夢')])
        self.assertEqual(words[0][1], {'text': 'の夢', 'start': 1.5, 'duration': 0.6})

    def test_metadata_empty_and_invalid(self):
        self.assertEqual(parse_yrc('{"t":0,"c":[]}\n[00:01]abc\n[0,1](0,1,0)  '), ([], []))

    def test_order_zero_duration_and_spaces(self):
        lines, words = parse_yrc('[2000,0](2000,0,0)夢\n[1000,500](1000,500,0)One last kiss')
        self.assertEqual(lines, [(1.0, 'One last kiss'), (2.0, '夢')])
        self.assertEqual(words[1][0]['duration'], 0)


if __name__ == '__main__':
    unittest.main()
