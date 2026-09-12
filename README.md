# panon-refreshed

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
require D-Bus and GLib development packages. Panon does not require Intel MKL.

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

## Advanced settings

Settings are split into **Appearance** (including font auto-detection),
**Backend** (interpreter/dependency checks, audio source and MPRIS service), and
**Music integrations** (NetEase/QQ application/runtime paths). The integration
page begins with .desktop creation and player restart instructions. Auto-detect
buttons fill a unique or unambiguous current candidate; multiple candidates are
shown for selection, and failed detection leaves existing values unchanged.
Player detection reads bounded ASAR metadata and literal launcher paths without
executing player scripts. It does not automatically start a player or install a
menu entry. Use the explicit integration-launcher button to apply those choices.
Normal widget settings are saved with Apply. Clearing the audio source or MPRIS
service restores dynamic following instead of pinning the detected current value.

- Python interpreter: executable name or absolute path, not a shell command.
- Audio source: explicit PulseAudio source name; empty follows the actual
  monitor of the default output, without assuming a `.monitor` name.
- Preferred MPRIS service: full service name; empty keeps the current playing
  source when possible, then chooses another playing source.
- Lyrics font: installed family name; empty detects Japanese-capable fonts
  and ultimately falls back to the system font.

The backend owns player selection, position and controls. Commands are bound
to the displayed service and unique owner; seeking also verifies the current
track ID. Seconds are converted to microseconds only at the D-Bus boundary.

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
its Panon entry after updating bridge launch code. Sandbox disabling is opt-in.
Flatpak/AppImage bridges are not currently supported.

## Paths and graceful fallback

Absolute, nonempty XDG_CONFIG_HOME/XDG_CACHE_HOME/XDG_DATA_HOME values are honored;
otherwise the standard home-directory defaults apply. Changing the cache root
starts a fresh cache without deleting the old one. The bridges require a private
XDG_RUNTIME_DIR and validate file permissions, ownership, PID and freshness.

The widget sends its Plasma screen ID and samples wallpaper with screen-local
logical coordinates. Static image/slideshow wallpapers with stretch, fit, crop
or centered padding are supported on a best-effort basis. Dynamic wallpapers,
unresolved image packages, ambiguous saved activity settings and blurred
wallpaper filling fall back to the cover-color background. No screen capture
permission is requested.

WebSockets bind to loopback on an automatic port. A per-launch nonce gates the
connection and whitelisted commands; it is not isolation from other processes
already running as the same user. Messages have size limits. Failed backend
processes retry with bounded backoff; unresponsive connections disable controls.

## Verification status

Actual desktop verification: Arch Linux, Plasma 6.7.5, Qt 6.11.2, Python 3.14,
Wayland. The metadata minimum is a loading declaration, not proof that every
Plasma 6 minor release has been tested.

A Python 3.10–3.14 GitHub Actions matrix is provided, but has not yet run on
GitHub. Cross-distribution desktops, X11, mixed-DPI multi-monitor setups and
software rendering still need real verification before broad support claims.

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
node tests/test_netease_page.cjs
node tests/test_qqmusic_page.cjs
node tests/test_qml_utils.cjs
# Requires a live audio/desktop session with audible playback:
python3 tests/test_backend_e2e.py --spectrum-only
```

Original Panon author attribution is retained in `metadata.json`.
Logo source and license notices accompany the SVGs in `contents/images`.
