import asyncio
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'contents/scripts'))
sys.path.insert(0, str(ROOT / 'integrations'))
from panon.backend.paths import xdg_path
from panon.backend.lyrics import MediaState, select_player
from panon.backend.client import default_monitor, run
from panon.backend.control import execute_command
from panon.backend.wallpaper import describe, read_wallpaper
from install_common import quote


class PortabilityTests(unittest.TestCase):
    def test_xdg_defaults_and_override(self):
        for value in ('', 'relative', '/tmp/panon-cache'):
            with self.subTest(value=value), patch.dict(os.environ, XDG_CACHE_HOME=value):
                expected = Path(value) if value.startswith('/') else Path.home() / '.cache'
                self.assertEqual(xdg_path('XDG_CACHE_HOME', '.cache'), expected)

    def test_sticky_player_and_explicit_choice(self):
        a = MediaState(service='a', playing=True)
        b = MediaState(service='b', playing=True)
        self.assertEqual(select_player([a,b], current='b'), b)
        self.assertEqual(select_player([a,b], preferred='a', current='b'), a)
        self.assertEqual(select_player([b,a]), a)
        self.assertFalse(select_player([]).service)

    def test_monitor_not_inferred_from_name(self):
        for key in ('monitor_source_name', 'monitor_source'):
            with patch('panon.backend.client.subprocess.check_output', side_effect=['speaker\n', json.dumps([{'name':'speaker',key:'special-monitor'}])]):
                self.assertEqual(default_monitor(), 'special-monitor')

    def test_monitor_numeric_index(self):
        with patch('panon.backend.client.subprocess.check_output', side_effect=['speaker', '[{"name":"speaker","monitor_source":17}]', '[{"index":17,"name":"actual"}]']):
            self.assertEqual(default_monitor(), 'actual')

    def test_unknown_monitor_does_not_guess(self):
        with patch('panon.backend.client.subprocess.check_output', side_effect=['speaker','[]']):
            with self.assertRaises(RuntimeError): default_monitor()

    def test_wallpaper_supported_static_only(self):
        with tempfile.NamedTemporaryFile(suffix='.png') as file:
            values = dict(wallpaperPlugin='org.kde.image', Image=file.name, FillMode=1)
            self.assertEqual(describe(values)['fillMode'], 1)
            self.assertFalse(describe({**values, 'wallpaperPlugin':'video'}))
            self.assertFalse(describe({**values, 'Blur':True}))
            self.assertFalse(describe({**values, 'FillMode':99}))
            self.assertFalse(describe({**values, 'Image':'https://example.com/a.png'}))

    def test_wallpaper_screen_forwarded(self):
        shell = MagicMock()
        shell.wallpaper.return_value = {'wallpaperPlugin':'unsupported'}
        with patch('panon.backend.wallpaper.dbus.SessionBus'), patch('panon.backend.wallpaper.dbus.Interface', return_value=shell):
            self.assertEqual(read_wallpaper(3), {})
            self.assertEqual(int(shell.wallpaper.call_args.args[0]), 3)

    def test_desktop_argument_escaping(self):
        self.assertEqual(quote('/tmp/a b'), '"/tmp/a b"')
        self.assertIn('%%', quote('100%'))
        self.assertIn('\\\\$', quote('$x'))
        with self.assertRaises(ValueError): quote('a\nb')

    def test_commands_reject_wrong_instance_before_dbus(self):
        state = MediaState(service='org.mpris.MediaPlayer2.test', owner=':1.2')
        with patch('panon.backend.control.dbus.SessionBus') as bus:
            self.assertFalse(execute_command(state, dict(service=state.service, owner=':1.3', action='next')))
            bus.assert_not_called()

    def test_seek_checks_track_and_uses_microseconds(self):
        state = MediaState(service='org.mpris.MediaPlayer2.test', owner=':1.2', track_id='/track/1', duration=90)
        bus = MagicMock(); bus.get_name_owner.return_value = ':1.2'
        props = MagicMock(); player = MagicMock()
        props.GetAll.return_value = dict(CanControl=True, CanSeek=True, Metadata={'mpris:trackid':'/track/1'})
        cmd = dict(service=state.service, owner=state.owner, trackId=state.track_id, action='seek', position=12.5)
        with patch('panon.backend.control.dbus.SessionBus', return_value=bus), patch('panon.backend.control.dbus.Interface', side_effect=lambda obj, iface: props if iface.endswith('Properties') else player):
            self.assertFalse(execute_command(state, {**cmd,'trackId':'/track/old'}))
            self.assertFalse(execute_command(state, {**cmd,'position':float('nan')}))
            self.assertTrue(execute_command(state, cmd))
            self.assertEqual(int(player.SetPosition.call_args.args[1]), 12500000)
            self.assertFalse(execute_command(state, {**cmd,'action':'OpenUri'}))


class AudioFailureTest(unittest.IsolatedAsyncioTestCase):
    async def test_missing_audio_still_publishes_media(self):
        received = asyncio.Event()
        frames = []
        class Socket:
            async def __aenter__(self): return self
            async def __aexit__(self, *args): pass
            def __aiter__(self): return self
            async def __anext__(self):
                await asyncio.Future()
            async def send(self, message):
                data = json.loads(message)
                if 'media' in data:
                    frames.append(data)
                    if data['media']['title']: received.set()
        state = MediaState(service='test',title='still playing',playing=True,playback_status='Playing')
        async def inline(function, *args):
            await asyncio.sleep(0)
            return function(*args)
        with patch('panon.backend.client.asyncio.to_thread', side_effect=inline), patch('panon.backend.client.websockets.connect', return_value=Socket()), patch('panon.backend.client.default_monitor', side_effect=FileNotFoundError('pactl missing')), patch('panon.backend.client.read_mpris', return_value=state), patch('panon.backend.client.read_wallpaper', return_value={}):
            task = asyncio.create_task(run('ws://127.0.0.1', 20, 32, 82))
            try:
                await asyncio.wait_for(received.wait(), 3)
                self.assertEqual(frames[-1]['media']['title'], 'still playing')
                self.assertEqual(max(frames[-1]['bands']), 0)
                self.assertIn('pactl missing', frames[-1]['audioError'])
            finally:
                task.cancel()
                with self.assertRaises(asyncio.CancelledError): await task


if __name__ == '__main__': unittest.main()
