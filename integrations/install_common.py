"""Install an opt-in launcher; paths are data, never executable shell snippets."""
import argparse
import json
import os
from pathlib import Path
import shutil


def xdg(name, fallback):
    value = os.environ.get(name, "")
    return Path(value) if value and Path(value).is_absolute() else Path.home() / fallback


def quote(argument):
    if any(c in argument for c in "\n\r\0"):
        raise ValueError("Invalid newline/NUL in launcher argument")
    # Desktop entries have a string-escape layer before Exec tokenization.
    escaped = ''.join('\\' + c if c in '\\"`$' else c for c in argument)
    return '"' + escaped.replace('\\', '\\\\').replace('%', '%%') + '"'


def install(provider, script):
    parser = argparse.ArgumentParser()
    parser.add_argument('--app-path', type=Path)
    parser.add_argument('--electron')
    parser.add_argument('--no-sandbox', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    config_file = xdg('XDG_CONFIG_HOME', '.config') / 'panon/integrations' / f'{provider}.json'
    config = json.loads(config_file.read_text()) if config_file.exists() else {}
    if config and config.get('managedBy') != 'panon':
        raise SystemExit(f'Refusing to replace unrelated config: {config_file}')
    candidates = {'netease': ['/usr/lib/netease-cloud-music-web-player/app.asar', '/opt/netease-cloud-music-web-player/resources/app.asar'],
                  'qqmusic': ['/usr/lib/qqmusic/app.asar']}[provider]
    app_path = args.app_path or (Path(config['appPath']) if config.get('appPath') else None)
    if app_path is None:
        found = [Path(p) for p in candidates if Path(p).is_file()]
        if len(found) != 1:
            raise SystemExit('Specify --app-path; no unique supported installation was found')
        app_path = found[0]
    app_path = app_path.expanduser().absolute()
    if not app_path.is_file() or app_path.name != 'app.asar':
        raise SystemExit('Expected an existing app.asar; sandboxed packages need separate adapters')
    executable = args.electron or config.get('electron') or ('electron43' if provider == 'qqmusic' else 'electron')
    electron = shutil.which(executable)
    if not electron:
        raise SystemExit('Electron runtime not found; specify --electron for the runtime supported by your player')
    if '=' in electron:
        raise SystemExit('Desktop Exec executable paths cannot contain =')
    title = 'NetEase' if provider == 'netease' else 'QQ Music'
    marker = f'# Managed by Panon {title} integration'
    target = xdg('XDG_DATA_HOME', '.local/share') / 'applications' / f'panon-{provider}.desktop'
    if target.exists() and marker not in target.read_text():
        raise SystemExit(f'Refusing to replace unrelated launcher: {target}')
    name = '网易云音乐' if provider == 'netease' else 'QQ音乐'
    icon = 'netease-cloud-music' if provider == 'netease' else 'qqmusic'
    entry = Path(script).resolve().with_name('launch.cjs')
    command = f'{quote(electron)} {quote(str(entry))}' + (' --no-sandbox' if args.no_sandbox else '')
    content = f'{marker}\n[Desktop Entry]\nType=Application\nName={title} (Panon)\nName[zh_CN]={name}（Panon 集成）\nExec={command}\nIcon={icon}\nTerminal=false\nCategories=AudioVideo;Audio;Music;Player;\n'
    settings = dict(managedBy='panon', appPath=str(app_path), electron=electron)
    if args.dry_run:
        print(json.dumps(settings, ensure_ascii=False, indent=2))
        print(content)
        return
    config_file.parent.mkdir(parents=True, exist_ok=True)
    config_file.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + '\n')
    config_file.chmod(0o600)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)
    print(target)
