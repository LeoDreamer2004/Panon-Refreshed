import json
from pathlib import Path
import re
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'contents/scripts'))
from panon.backend.detect import selection, asar_metadata, launcher_hints, detect_audio, detect_player


class DetectionTests(unittest.TestCase):
    def test_multiple_candidates_are_not_guessed(self):
        result = selection([dict(value='a'), dict(value='b')])
        self.assertEqual(result['selected'], '')
        self.assertEqual(selection(result['candidates'], 'b')['selected'], 'b')
        self.assertEqual(selection([dict(value='a'), dict(value='a')])['selected'], 'a')

    def test_asar_reads_metadata_without_executing(self):
        metadata = json.dumps(dict(name='qqmusic',version='1.1.8')).encode()
        index = json.dumps({'files':{'package.json':{'size':len(metadata),'offset':'0'}}}).encode()
        with tempfile.NamedTemporaryFile() as file:
            file.write(struct.pack('<4I', 4, len(index)+8, len(index)+4, len(index)) + index + metadata)
            file.flush()
            self.assertEqual(asar_metadata(file.name)['name'], 'qqmusic')

    def test_invalid_asar_is_bounded(self):
        with tempfile.NamedTemporaryFile() as file:
            file.write(struct.pack('<4I',4,0xffffffff,0xffffffff,0xffffffff))
            file.flush()
            with self.assertRaises(ValueError): asar_metadata(file.name)

    def test_literal_launcher_only(self):
        with tempfile.NamedTemporaryFile(mode='w') as file:
            file.write('exec /usr/bin/electron43 "/opt/test app/app.asar" "$@"\n')
            file.write('exec electron "$(touch /tmp/should-not-exist)/app.asar"\n')
            file.write('exec "$RUNTIME" /opt/other/app.asar\n')
            file.flush()
            with patch('panon.backend.detect.shutil.which', side_effect=lambda x: x):
                self.assertEqual(launcher_hints(file.name), [('/opt/test app/app.asar','/usr/bin/electron43')])

    def test_audio_prefers_current_monitor_not_microphone(self):
        responses = ['[{"name":"mic"},{"name":"custom","description":"Speaker monitor"}]',
                     '[{"name":"speaker","monitor_source":"custom"}]', 'speaker']
        with patch('panon.backend.detect.pactl', side_effect=responses):
            result = detect_audio()
        self.assertEqual(result['selected'], 'custom')
        self.assertEqual(len(result['candidates']), 1)

    def test_wrong_player_package_is_rejected(self):
        with patch('panon.backend.detect.launcher_hints', return_value=[]), patch('panon.backend.detect.shutil.which', return_value=None), patch('panon.backend.detect.Path.is_file', return_value=True), patch('panon.backend.detect.asar_metadata', return_value={'name':'unrelated','version':'1.1.8'}):
            self.assertEqual(detect_player('qqmusic')['candidates'], [])

    def test_settings_pages_accept_all_schema_values(self):
        schema = ET.parse(ROOT / 'contents/config/main.xml')
        names = [entry.attrib['name'] for entry in schema.iter() if entry.tag.endswith('entry')]
        for page in ('ConfigGeneral.qml','ConfigServices.qml','ConfigIntegrations.qml'):
            text = (ROOT / 'contents/ui/config' / page).read_text()
            properties = set(re.findall(r'property\s+\w+\s+(cfg_\w+)', text))
            for name in names:
                self.assertIn('cfg_' + name, properties, page)
                self.assertIn('cfg_' + name + 'Default', properties, page)


if __name__ == '__main__': unittest.main()
