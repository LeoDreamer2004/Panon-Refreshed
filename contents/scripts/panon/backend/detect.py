"""Read-only discovery for configuration buttons; never execute player launchers."""
import argparse
import json
from pathlib import Path
import re
import shlex
import shutil
import struct
import subprocess
import sys
from .paths import config_home


def selection(candidates, preferred=""):
    unique = {item['value']: item for item in candidates if item.get('value')}
    values = list(unique.values())
    selected = preferred if preferred in unique else (values[0]['value'] if len(values) == 1 else '')
    return dict(candidates=values, selected=selected)


def detect_python():
    return selection([dict(value=sys.executable, label=f'Python {sys.version.split()[0]} — {sys.executable}')])


def pactl(*arguments):
    return subprocess.check_output(['pactl', *arguments], text=True, timeout=3)


def detect_audio():
    sources = json.loads(pactl('--format=json', 'list', 'sources'))
    sinks = json.loads(pactl('--format=json', 'list', 'sinks'))
    default = pactl('get-default-sink').strip()
    preferred = ''
    monitors = set()
    for sink in sinks:
        monitor = sink.get('monitor_source_name') or sink.get('monitor_source')
        if isinstance(monitor, int):
            monitor = next((s['name'] for s in sources if s.get('index') == monitor), '')
        if monitor:
            monitors.add(monitor)
            if sink.get('name') == default:
                preferred = monitor
    candidates = [dict(value=s['name'], label=s.get('description') or s['name'])
                  for s in sources if s.get('name') in monitors]
    return selection(candidates, preferred)


def detect_services():
    import dbus
    bus = dbus.SessionBus()
    candidates = []
    playing = []
    for name in sorted(bus.list_names()):
        service = str(name)
        if not service.startswith('org.mpris.MediaPlayer2.'):
            continue
        try:
            props = dbus.Interface(bus.get_object(service, '/org/mpris/MediaPlayer2'), 'org.freedesktop.DBus.Properties')
            identity = str(props.Get('org.mpris.MediaPlayer2', 'Identity', timeout=2))
            status = str(props.Get('org.mpris.MediaPlayer2.Player', 'PlaybackStatus', timeout=2))
            candidates.append(dict(value=service, label=f'{identity} — {service}'))
            if status == 'Playing': playing.append(service)
        except dbus.DBusException:
            continue
    return selection(candidates, playing[0] if len(playing) == 1 else '')


def asar_metadata(archive):
    """Read only a bounded package.json from the ASAR header/index."""
    with Path(archive).open('rb') as stream:
        prefix = stream.read(16)
        if len(prefix) != 16: raise ValueError('Invalid ASAR header')
        size_pickle, header_size, _, json_size = struct.unpack('<4I', prefix)
        if size_pickle != 4 or not 0 < json_size <= 16 * 1024 * 1024 or header_size < json_size + 8:
            raise ValueError('Invalid ASAR index size')
        header = json.loads(stream.read(json_size))
        entry = header['files']['package.json']
        if entry.get('unpacked') or entry.get('link'):
            raise ValueError('External package metadata is not auto-detected')
        size, offset = int(entry['size']), int(entry['offset'])
        if not 0 < size <= 1024 * 1024 or offset < 0:
            raise ValueError('Invalid package metadata size')
        stream.seek(8 + header_size + offset)
        return json.loads(stream.read(size))


def launcher_hints(executable):
    """Recognize only a literal exec Electron app.asar line. Never eval a shell."""
    if not executable: return []
    path = Path(executable)
    try:
        if path.stat().st_size > 65536: return []
        text = path.read_text()
    except (OSError, UnicodeError):
        return []
    found = []
    for line in text.splitlines():
        try:
            words = shlex.split(line, comments=True)
        except ValueError:
            continue
        if len(words) < 3 or words[0] != 'exec': continue
        if not re.fullmatch(r'electron\d*', Path(words[1]).name): continue
        runtime = shutil.which(words[1])
        if not runtime: continue
        for word in words[2:]:
            if Path(word).is_absolute() and word.endswith('/app.asar') and not any(c in word for c in '$`\n'):
                found.append((word, runtime))
    return found


def detect_player(provider, selected_path=''):
    name = 'netease-cloud-music-web-player' if provider == 'netease' else 'qqmusic'
    known = ([f'/usr/lib/{name}/app.asar', f'/opt/{name}/resources/app.asar']
             if provider == 'netease' else ['/usr/lib/qqmusic/app.asar'])
    hints = launcher_hints(shutil.which(name))
    paths = list(known) + [p for p, _ in hints]
    config = config_home() / 'panon/integrations' / f'{provider}.json'
    configured = {}
    try:
        configured = json.loads(config.read_text())
        if configured.get('managedBy') == 'panon' and configured.get('appPath'):
            paths.append(configured['appPath'])
    except (ValueError, OSError):
        pass
    if selected_path:
        paths.append(selected_path)
    candidates = []
    for path in dict.fromkeys(paths):
        if not Path(path).is_absolute() or not Path(path).is_file(): continue
        try:
            metadata = asar_metadata(path)
        except (OSError, ValueError, KeyError, TypeError):
            continue
        if metadata.get('name') != name: continue
        if provider == 'qqmusic' and metadata.get('version') != '1.1.8': continue
        runtimes = [r for p, r in hints if Path(p) == Path(path)]
        if configured.get('managedBy') == 'panon' and configured.get('appPath') == path and configured.get('electron'):
            runtime = shutil.which(configured['electron'])
            if runtime: runtimes.insert(0, runtime)
        # This QQ adapter is explicitly tested against major 43 only.
        if provider == 'qqmusic':
            runtime = shutil.which('electron43')
            if runtime: runtimes = [runtime]
        if provider == 'netease' and not runtimes and path in known:
            runtime = shutil.which('electron')
            if runtime: runtimes = [runtime]
        candidates.append(dict(value=path, label=f"{name} {metadata.get('version', '')} — {path}",
                               electron=runtimes[0] if len(set(runtimes)) == 1 else ''))
    return selection(candidates, selected_path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('kind', choices=['python', 'audio', 'services', 'netease', 'qqmusic'])
    parser.add_argument('--app-path', default='')
    args = parser.parse_args()
    try:
        result = {'python': detect_python, 'audio': detect_audio, 'services': detect_services}.get(args.kind)
        result = result() if result else detect_player(args.kind, args.app_path)
    except Exception as error:
        result = dict(candidates=[], selected='', error=str(error))
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__': main()
