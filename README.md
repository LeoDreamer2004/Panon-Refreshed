# Panon-Refreshed

English | [简体中文](README.zh-CN.md)

Audio spectrum, rotating album artwork, synchronized lyrics and standard MPRIS
controls for KDE Plasma, with separate desktop and compact panel layouts.

**Plasma 6 only. Plasma 5 is unsupported.** Compatibility work targets Plasma 6
environments, not a Plasma 5 backport.

## Installation and dependencies

Linux and Plasma 6 are required, with Qt Quick/Controls/Layouts, Kirigami,
KCMUtils, Plasma5Support and the Qt WebSockets QML module.
Python 3.10+ needs the packages in `requirements.txt`; optional Japanese readings
use `requirements-readings.txt`. Prefer distribution packages, or select a
virtual environment's interpreter in the settings. Building dbus-python may
require D-Bus and GLib development packages. Panon-Refreshed does not require Intel MKL.

Audio capture requires `pactl`, `parec` and PulseAudio or PipeWire's PulseAudio
compatibility service. Audio failure does not disable media metadata/controls.
Qt5Compat GraphicalEffects is optional: without it wallpaper blur is omitted and
the album falls back to a circular Canvas mask.

```sh
kpackagetool6 --type Plasma/Applet --install .
# For an existing installation:
kpackagetool6 --type Plasma/Applet --upgrade .
```

Reload the widget after upgrading. Use **Check dependencies** in its settings,
or run `python3 -m panon.backend.doctor` from `contents/scripts`.

## Optional exact-ID lyrics integrations

- [NetEase web player](integrations/netease/README.md)
- [QQ Music system-Electron build](integrations/qqmusic/README.md)

Generic spectrum and MPRIS controls do not require a supported lyrics provider.
Lyrics never use title search or another platform's recording as a substitute.

Both installers accept `--app-path /absolute/path/app.asar`,
`--electron /path/to/electron` and `--dry-run`. Without explicit values, only
known layouts are checked; ambiguity is an error. Choices are saved in
`$XDG_CONFIG_HOME/panon/integrations/<provider>.json`; the menu entry records the
selected executable. Explicit paths do not imply compatibility with unknown
player builds or runtimes. QQ's tested version/module map is `adapters.json`.

Upstream files and original launchers are not modified. Move this project only
if you rerun its launcher installers. Fully exit and relaunch a player through
its Panon entry after updating bridge launch code.

## Verification status

Actual desktop verification: Arch Linux, Plasma 6.7.5, Qt 6.11.2, Python 3.14,
Wayland. The metadata minimum is a loading declaration, not proof that every
Plasma 6 minor release has been tested.
