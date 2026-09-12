"""Best-effort static wallpaper description for one Plasma screen."""
import configparser
import re
from pathlib import Path
from urllib.parse import urlparse, unquote
import dbus
from .paths import config_home

SUPPORTED = {"org.kde.image", "org.kde.slideshow"}


def describe(values):
    if str(values.get("wallpaperPlugin", "")) not in SUPPORTED or values.get("Blur", False):
        return {}
    image = str(values.get("Image", "")).strip()
    parsed = urlparse(image)
    if parsed.scheme not in ("", "file") or parsed.fragment:
        return {}
    path = Path(unquote(parsed.path)).expanduser()
    if not path.is_absolute() or not path.is_file():
        return {}
    mode = int(values.get("FillMode", 2))
    if mode not in (0, 1, 2, 6):
        return {}
    color = values.get("Color", "#000000")
    if isinstance(color, (tuple, list, dbus.Struct)) and color:
        color = f"#{int(color[0]) & 0xffffff:06x}"
    if not re.fullmatch(r"#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?", str(color)):
        color = "#000000"
    return dict(url=path.as_uri(), fillMode=mode, color=str(color))


def read_wallpaper(screen=0):
    if not isinstance(screen, int) or screen < 0:
        return {}
    try:
        bus = dbus.SessionBus()
        shell = dbus.Interface(bus.get_object("org.kde.plasmashell", "/PlasmaShell"), "org.kde.PlasmaShell")
        # An unsupported *live* wallpaper must not fall back to a stale image.
        return describe(shell.wallpaper(dbus.UInt32(screen), timeout=2))
    except (dbus.DBusException, TypeError, ValueError, OSError):
        pass
    parser = configparser.RawConfigParser(interpolation=None, strict=False)
    try:
        parser.read(config_home() / "plasma-org.kde.plasma.desktop-appletsrc", encoding="utf-8")
        matches = [s for s in parser.sections() if re.fullmatch(r"Containments\]\[\d+", s)
                   and parser.get(s, "plugin", fallback="") in ("org.kde.folder", "org.kde.plasma.folder", "org.kde.desktop")
                   and parser.getint(s, "lastScreen", fallback=-1) == screen]
        # Multiple activities cannot be resolved safely from saved config alone.
        if len(matches) != 1:
            return {}
        section = matches[0]
        plugin = parser.get(section, "wallpaperplugin", fallback="")
        group = f"{section}][Wallpaper][{plugin}][General"
        return describe(dict(wallpaperPlugin=plugin, Image=parser.get(group, "Image", fallback=""),
                             FillMode=parser.getint(group, "FillMode", fallback=2),
                             Blur=parser.getboolean(group, "Blur", fallback=False),
                             Color=parser.get(group, "Color", fallback="#000000")))
    except (ValueError, OSError, configparser.Error):
        return {}
