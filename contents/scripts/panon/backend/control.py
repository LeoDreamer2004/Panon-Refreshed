"""Whitelisted MPRIS commands bound to the displayed player and track."""
import math
import dbus
from .lyrics import PLAYER_INTERFACE, PROPERTIES_INTERFACE


def execute_command(state, command):
    if not isinstance(command, dict) or not state.service or not state.owner:
        return False
    if command.get("service") != state.service or command.get("owner") != state.owner:
        return False
    bus = dbus.SessionBus()
    if str(bus.get_name_owner(state.service)) != state.owner:
        return False
    obj = bus.get_object(state.owner, "/org/mpris/MediaPlayer2")
    props = dbus.Interface(obj, PROPERTIES_INTERFACE)
    caps = props.GetAll(PLAYER_INTERFACE)
    if not caps.get("CanControl", False):
        return False
    player = dbus.Interface(obj, PLAYER_INTERFACE)
    action = command.get("action")
    if action == "seek":
        track = str(caps.get("Metadata", {}).get("mpris:trackid", ""))
        if not caps.get("CanSeek") or not track.startswith("/") or track != state.track_id or command.get("trackId") != track:
            return False
        position = command.get("position")
        if isinstance(position, bool) or not isinstance(position, (int, float)) or not math.isfinite(position):
            return False
        position = max(0, min(position, state.duration)) if state.duration > 0 else max(0, position)
        player.SetPosition(dbus.ObjectPath(track), dbus.Int64(round(position * 1000000)), timeout=2)
        return True
    allowed = {"next": ("CanGoNext", "Next"), "previous": ("CanGoPrevious", "Previous"),
               "playPause": ("CanPause" if caps.get("PlaybackStatus") == "Playing" else "CanPlay", "PlayPause")}
    if action not in allowed:
        return False
    capability, method = allowed[action]
    if not caps.get(capability):
        return False
    getattr(player, method)(timeout=2)
    return True
