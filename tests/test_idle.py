import asyncio
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'contents/scripts'))
from panon.backend.client import run
from panon.backend.lyrics import MediaState


class IdleTests(unittest.IsolatedAsyncioTestCase):
    async def test_sleep_wake_and_model_delta(self):
        commands = asyncio.Queue()
        frames = []
        class Socket:
            async def __aenter__(self): return self
            async def __aexit__(self, *args): pass
            def __aiter__(self): return self
            async def __anext__(self): return await commands.get()
            async def send(self, message): frames.append(json.loads(message))
        async def inline(function, *args):
            await asyncio.sleep(.005)
            return function(*args)
        async def wait_until(predicate):
            async with asyncio.timeout(3):
                while not predicate(): await asyncio.sleep(.01)
        def activity(active, token='test'):
            commands.put_nowait(json.dumps(dict(action='activity', active=active, token=token, wallpaper=False)))
        capture = MagicMock(sample_rate=48000, frame_count=1600, monitor='test')
        capture.process.poll.return_value = None
        analyzer = MagicMock()
        analyzer.analyze.return_value = ([0] * 32, 0)
        state = MediaState()
        with patch('panon.backend.client.asyncio.to_thread', side_effect=inline), \
             patch('panon.backend.client.websockets.connect', return_value=Socket()), \
             patch('panon.backend.client.AudioCapture', return_value=capture), \
             patch('panon.backend.client.SpectrumAnalyzer', return_value=analyzer), \
             patch('panon.backend.client.read_mpris', return_value=state), \
             patch('panon.backend.client.read_wallpaper', return_value={}) as wallpaper:
            task = asyncio.create_task(run('ws://test', 30, 32, 82, token='test', audio_source='test'))
            try:
                await wait_until(lambda: len([f for f in frames if 'media' in f]) >= 3)
                active = [f['media']['lyricWindow'] for f in frames if 'media' in f]
                self.assertIn('entries', active[0])
                self.assertNotIn('entries', active[1])
                activity(False)
                await wait_until(lambda: any(f.get('idle') for f in frames))
                reads, analyses, walls = capture.read.call_count, analyzer.analyze.call_count, wallpaper.call_count
                await asyncio.sleep(.15)
                self.assertEqual(capture.read.call_count, reads)
                self.assertEqual(analyzer.analyze.call_count, analyses)
                self.assertEqual(wallpaper.call_count, walls)
                activity(True, 'wrong-token')
                await asyncio.sleep(.05)
                self.assertEqual(capture.read.call_count, reads)
                boundary = len(frames)
                activity(True)
                await wait_until(lambda: any('media' in f for f in frames[boundary:]))
                resumed = next(f for f in frames[boundary:] if 'media' in f)
                self.assertIn('entries', resumed['media']['lyricWindow'])
                self.assertGreater(capture.read.call_count, reads)
                self.assertEqual(wallpaper.call_count, walls)
            finally:
                task.cancel()
                with self.assertRaises(asyncio.CancelledError): await task


if __name__ == '__main__': unittest.main()
