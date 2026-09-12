"""Read the optional player bridge. Never infer a song ID from a song title."""
import json
import os
import re
import stat
import time
from pathlib import Path


def read_record(pid, title, artist, album, *, provider="netease", runtime=None, now=None):
    if provider not in ("netease", "qqmusic"):
        return None
    directory = runtime or os.environ.get("XDG_RUNTIME_DIR", "")
    if not directory or not isinstance(pid, int) or pid <= 0:
        return None
    path = Path(directory) / "panon" / f"{provider}-{pid}.json"
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(fd) as stream:
            info = os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
                return None
            if info.st_size > 1500000:
                return None
            data = json.loads(stream.read(1500001))
        if not isinstance(data, dict):
            return None
        age = (time.time() if now is None else now) - float(data["updatedAt"])
        if data.get("version") != 1 or data.get("provider") != provider or data.get("pid") != pid:
            return None
        if not 0 <= age <= 5 or not re.fullmatch(r"[1-9]\d{0,19}", str(data.get("songId", ""))):
            return None
        # Bridge and MPRIS update separately. Reject stale records at transitions.
        if not title or data.get("title") != title or data.get("artist") != artist or data.get("album") != album:
            return None
        if provider == "qqmusic" and any(
            not isinstance(data.get(field, ""), str) or len(data.get(field, "")) > 300000
            for field in ("lyric", "translation")
        ):
            return None
        return data
    except (OSError, ValueError, TypeError, KeyError):
        return None


def read_track(pid, title, artist, album, **kwargs):
    record = read_record(pid, title, artist, album, **kwargs)
    return str(record["songId"]) if record else None
