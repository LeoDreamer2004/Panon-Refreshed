# Panon-Refreshed — local repair history

[English documentation](README.md) | [简体中文文档](README.zh-CN.md)

For current installation, portability settings and support boundaries, see
[README.md](README.md). This file records the history of the local repair.

## Exact NetEase integration

QQ Music using system Electron is also supported through its optional
[QQ Music bridge](integrations/qqmusic/README.md), using exact current-track IDs
and lyrics retrieved by the player itself.

Lyrics now require a verified platform song ID instead of title search.
Use the optional [NetEase launch bridge](integrations/netease/README.md) to
start the installed web player with Panon integration. No system player files
are modified. Other players keep generic MPRIS controls and spectrum support,
but do not trigger title-based lyric searches.

This local variant keeps Panon's package identity but replaces the obsolete
shader frontend and audio bridge with:

- a Qt 6 Canvas spectrum renderer;
- seven Qt 6-native visual themes, without the obsolete runtime GLSL path;
- a `parec` capture process that follows PipeWire's current default sink;
- a Python 3.14-compatible asyncio backend;
- a single Plasma 6 KCM configuration page.
- a compact panel view with MPRIS-synchronized NetEase Cloud Music lyrics.

The panel spectrum defaults to 160 px, independently of lyric availability.
Long lines scroll left once, with timing derived from the lyric duration.
NetEase lyrics are cached under `~/.cache/panon/lyrics` by exact song ID;
QQ lyrics and translations are read from the optional player bridge.

## Active implementation

The backend uses `client.py` (capture/FFT/WebSocket), `lyrics.py`
(MPRIS/lyrics/artwork), `control.py` (standard MPRIS commands),
`wallpaper.py`, `paths.py`, `doctor.py`, `furigana.py` (optional readings),
and `netease_bridge.py` (shared provider-record validation).
The settings pages are `ConfigGeneral.qml` (appearance), `ConfigServices.qml`
(backend) and `ConfigIntegrations.qml` (music integrations), under `contents/ui/config`.
Legacy audio backends, bundled SoundCard, GLSL effects/builders, texture queues,
and their obsolete settings pages have been removed. The seven current Canvas
themes are retained in `Spectrum.qml`.

Python must be able to import NumPy, websockets, dbus-python and Pillow in the
desktop session; pykakasi and jaconv are optional Japanese-reading dependencies.
Panon does not require Intel MKL and does not override `LD_LIBRARY_PATH`.
An MKL-linked NumPy installation must have its runtime libraries configured by
the local system independently of Panon. Shell-only `.zshrc` settings are not a
reliable way to configure desktop applications.

The original installed source was copied before these edits. Install with:

```sh
kpackagetool6 --type Plasma/Applet --upgrade .
```
