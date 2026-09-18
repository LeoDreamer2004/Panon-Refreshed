"""MPRIS metadata and NetEase Cloud Music lyric support."""

from __future__ import annotations

import fcntl
import hashlib
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from bisect import bisect_right
from dataclasses import asdict, dataclass, field
from io import BytesIO
from pathlib import Path

import dbus
from PIL import Image
from .furigana import annotate_lines
from .netease_bridge import read_record
from .paths import cache_home


PLAYER_INTERFACE = "org.mpris.MediaPlayer2.Player"
PROPERTIES_INTERFACE = "org.freedesktop.DBus.Properties"
MPRIS_PREFIX = "org.mpris.MediaPlayer2."
# The public web host frequently returns a JSON 405 under light concurrent
# use. NetEase's interface host exposes the same response schema and is much
# more reliable for exact-ID lyric requests.
LYRIC_URLS = (
    "https://interface.music.163.com/api/song/lyric",
    "https://music.163.com/api/song/lyric",
)
HTTP_HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) Panon-Plasma6/6.1",
    "Referer": "https://music.163.com/",
}
TIMESTAMP = re.compile(r"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]")
_ARTWORK_CACHE: dict[str, str] = {}


class TemporaryAPIError(RuntimeError):
    """A transient upstream condition that is safe to retry."""


@dataclass(frozen=True)
class MediaState:
    service: str = ""
    owner: str = ""
    track_id: str = ""
    can_seek: bool = False
    can_next: bool = False
    can_previous: bool = False
    can_play_pause: bool = False
    provider: str = ""
    song_id: str = ""
    embedded_lyrics: str = ""
    embedded_translation: str = ""
    lyrics_ready: bool = False
    title: str = ""
    artist: str = ""
    album: str = ""
    art_url: str = ""
    duration: float = 0.0
    position: float = 0.0
    playing: bool = False
    playback_status: str = ""

    @property
    def identity(self) -> str:
        translation_revision = hashlib.sha256(self.embedded_translation.encode()).hexdigest()[:16]
        return "\x1f".join((self.service, self.provider, self.song_id, str(self.lyrics_ready), translation_revision, self.title, self.artist, f"{self.duration:.1f}"))


@dataclass
class LyricBundle:
    lines: list[tuple[float, str]]
    translations: list[tuple[float, str]]
    readings: list[tuple[float, str]] = field(default_factory=list)
    ruby: list = field(default_factory=list)
    instrumental: bool = False
    words: list = field(default_factory=list)
    timeline: list = field(default_factory=list)


def parse_yrc(source: str, *, with_timeline=False):
    """Return synchronized lines and absolute word times (milliseconds -> seconds)."""
    rows = []
    timeline = []
    for raw in source.splitlines():
        header = re.match(r"^\[(\d+),(\d+)\]", raw)
        if not header:
            continue
        words = []
        for match in re.finditer(r"\((\d+),(\d+),\d+\)([^\r\n]*?)(?=\(\d+,\d+,\d+\)|$)", raw[header.end():]):
            start, duration, text = match.groups()
            words.append({"text": text, "start": int(start) / 1000,
                          "duration": int(duration) / 1000})
        text = "".join(word["text"] for word in words)
        timeline.append({"start": int(header[1]) / 1000,
                         "end": max([(int(header[1]) + int(header[2])) / 1000]
                                    + [word["start"] + word["duration"] for word in words]),
                         "blank": not bool(text.strip())})
        if text.strip():
            rows.append((int(header[1]) / 1000, text, words))
    rows.sort(key=lambda row: row[0])
    result = ([(start, text) for start, text, _ in rows], [words for _, _, words in rows])
    return (*result, sorted(timeline, key=lambda entry: entry["start"])) if with_timeline else result


def lrc_timeline(source: str):
    events = parse_lrc(source, keep_empty=True)
    return [{"start": start, "end": events[i + 1][0] if i + 1 < len(events) else None,
             "blank": not bool(text)} for i, (start, text) in enumerate(events)]


def playback_lyric_timing(entries, index, position, duration):
    """Visible lines can be held during silence without extending their timing."""
    if not 0 <= index < len(entries):
        return {"position": position, "start": 0, "end": 0, "inGap": True}
    entry = entries[index]
    next_start = entries[index + 1]["timestamp"] if index + 1 < len(entries) else duration
    end = entry.get("end")
    if end is None:
        end = next_start
    return {"position": position, "start": entry["timestamp"], "end": end,
            "nextStart": next_start, "inGap": position >= end}




def cache_local_artwork(art_url: str) -> str:
    """Persist short-lived MPRIS file URLs and return a stable URL."""
    if not art_url:
        return ""
    cached_url = _ARTWORK_CACHE.get(art_url, "")
    if cached_url:
        cached_path = Path(urllib.parse.unquote(urllib.parse.urlparse(cached_url).path))
        if cached_path.is_file():
            return cached_url

    parsed = urllib.parse.urlparse(art_url)
    if parsed.scheme not in ("", "file"):
        return art_url
    source_path = Path(urllib.parse.unquote(parsed.path if parsed.scheme else art_url))
    try:
        data = source_path.read_bytes()
        if not data or len(data) > 16 * 1024 * 1024:
            return art_url
        with Image.open(BytesIO(data)) as image:
            extension = (image.format or "png").casefold()
        if extension == "jpeg":
            extension = "jpg"
        digest = hashlib.sha256(data).hexdigest()[:24]
        cached_path = cache_home() / "panon" / "artwork" / f"{digest}.{extension}"
        if not cached_path.is_file():
            cached_path.parent.mkdir(parents=True, exist_ok=True)
            cached_path.write_bytes(data)
        stable_url = cached_path.as_uri()
        _ARTWORK_CACHE[art_url] = stable_url
        return stable_url
    except (OSError, ValueError):
        return art_url


def read_mpris(preferred: str = "", current: str = "") -> MediaState:
    """Read the active MPRIS player, preferring one that is playing."""
    bus = dbus.SessionBus()
    candidates: list[MediaState] = []

    for name in bus.list_names():
        service = str(name)
        if not service.startswith(MPRIS_PREFIX):
            continue
        try:
            obj = bus.get_object(service, "/org/mpris/MediaPlayer2")
            props = dbus.Interface(obj, PROPERTIES_INTERFACE)
            capabilities = props.GetAll(PLAYER_INTERFACE)
            metadata = props.Get(PLAYER_INTERFACE, "Metadata")
            status = str(props.Get(PLAYER_INTERFACE, "PlaybackStatus"))
            position = int(props.Get(PLAYER_INTERFACE, "Position")) / 1_000_000.0
            artists = metadata.get("xesam:artist", [])
            if isinstance(artists, str):
                artists = [artists]
            title = str(metadata.get("xesam:title", ""))
            artist = " / ".join(str(artist) for artist in artists)
            album = str(metadata.get("xesam:album", ""))
            provider, song_id = "", ""
            record = None
            player_identity = str(props.Get("org.mpris.MediaPlayer2", "Identity"))
            if player_identity in ("netease-cloud-music-web-player", "qqmusic"):
                provider = "netease" if player_identity == "netease-cloud-music-web-player" else "qqmusic"
                pid = int(bus.call_blocking("org.freedesktop.DBus", "/org/freedesktop/DBus",
                                           "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", (service,)))
                record = read_record(pid, title, artist, album, provider=provider)
                song_id = str(record["songId"]) if record else ""
            candidates.append(
                MediaState(
                    service=service,
                    owner=str(bus.get_name_owner(service)),
                    track_id=str(metadata.get("mpris:trackid", "")),
                    can_seek=bool(capabilities.get("CanControl", False) and capabilities.get("CanSeek", False)),
                    can_next=bool(capabilities.get("CanControl", False) and capabilities.get("CanGoNext", False)),
                    can_previous=bool(capabilities.get("CanControl", False) and capabilities.get("CanGoPrevious", False)),
                    can_play_pause=bool(capabilities.get("CanControl", False) and capabilities.get("CanPause" if status == "Playing" else "CanPlay", False)),
                    provider=provider,
                    song_id=song_id,
                    embedded_lyrics=(record or {}).get("lyric", ""),
                    embedded_translation=(record or {}).get("translation", ""),
                    lyrics_ready=(record or {}).get("lyricsReady") is True,
                    title=str(metadata.get("xesam:title", "")),
                    artist=" / ".join(str(artist) for artist in artists),
                    album=str(metadata.get("xesam:album", "")),
                    art_url=cache_local_artwork(str(metadata.get("mpris:artUrl", ""))),
                    duration=int(metadata.get("mpris:length", 0)) / 1_000_000.0,
                    position=max(0.0, position),
                    playing=status == "Playing",
                    playback_status=status,
                )
            )
        except (dbus.DBusException, TypeError, ValueError):
            continue

    if not candidates:
        return MediaState()
    return select_player(candidates, preferred, current)


def select_player(candidates, preferred="", current=""):
    if not candidates:
        return MediaState()
    ordered = sorted(candidates, key=lambda state: state.service)
    return (next((s for s in ordered if s.service == preferred), None)
            or next((s for s in ordered if s.service == current and s.playing), None)
            or next((s for s in ordered if s.playing), None)
            or next((s for s in ordered if s.service == current), None) or ordered[0])


def _request_json(url: str, parameters: dict[str, object]) -> dict:
    query = urllib.parse.urlencode(parameters)
    request = urllib.request.Request(f"{url}?{query}", headers=HTTP_HEADERS)
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                payload = json.load(response)
            if payload.get("code") in (405, 429):
                raise TemporaryAPIError(payload.get("message") or payload.get("msg") or "rate limited")
            return payload
        except (TemporaryAPIError, urllib.error.HTTPError) as error:
            retryable = isinstance(error, TemporaryAPIError) or error.code in (405, 429)
            if not retryable or attempt == 2:
                raise
            time.sleep(1.5 * (attempt + 1))
    raise TemporaryAPIError("NetEase request retry limit reached")


def _request_netease(urls: tuple[str, ...], parameters: dict[str, object]) -> dict:
    last_error: Exception | None = None
    for url in urls:
        try:
            return _request_json(url, parameters)
        except Exception as error:
            last_error = error
    if last_error is not None:
        raise last_error
    raise TemporaryAPIError("No NetEase endpoint configured")




def parse_lrc(source: str, *, keep_empty=False) -> list[tuple[float, str]]:
    offset = 0.0
    parsed: list[tuple[float, str]] = []
    for raw_line in source.splitlines():
        if raw_line.startswith("[offset:"):
            try:
                offset = float(raw_line[8:-1]) / 1000.0
            except ValueError:
                pass
            continue
        matches = list(TIMESTAMP.finditer(raw_line))
        if not matches:
            continue
        text = TIMESTAMP.sub("", raw_line).strip()
        if not text and not keep_empty:
            continue
        for match in matches:
            fraction = (match.group(3) or "0")
            milliseconds = int(fraction.ljust(3, "0")[:3]) / 1000.0
            timestamp = int(match.group(1)) * 60 + int(match.group(2)) + milliseconds
            parsed.append((max(0.0, timestamp + offset), text))
    parsed.sort(key=lambda item: item[0])
    return parsed


def _cache_path(state: MediaState) -> Path:
    identity = f"{state.provider}:{state.song_id}" if state.song_id else state.identity
    digest = hashlib.sha256(identity.encode()).hexdigest()[:24]
    return cache_home() / "panon" / "lyrics" / f"{digest}-exact-v1.json"


def _read_lyric_cache(cache: Path) -> LyricBundle | None:
    try:
        payload = json.loads(cache.read_text(encoding="utf-8"))
        if int(payload.get("provider_version", 0)) < 9:
            return None
        lines = [
            (float(timestamp), str(text))
            for timestamp, text in payload["lines"]
            if str(text).strip()
        ]
        translations = [
            (float(timestamp), str(text).strip())
            for timestamp, text in payload.get("translations", [])
            if str(text).strip()
        ]
        if not lines:
            if time.time() - float(payload.get("checked_at", 0)) > 1800:
                return None
        readings = [(float(t), str(s)) for t, s in payload.get("readings", [])]
        return LyricBundle(
            lines, translations, readings, instrumental=payload.get("instrumental") is True,
            words=payload.get("words", []), timeline=payload.get("timeline", []))
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError):
        return None


def _fetch_and_cache_lyrics(
    state: MediaState, cache: Path
) -> LyricBundle:
    if state.provider != "netease" or not re.fullmatch(r"[1-9]\d{0,19}", state.song_id):
        return LyricBundle([], [])
    song_id = int(state.song_id)
    source = "netease"
    # Exact route only: never substitute a similarly named recording.
    response = _request_netease(tuple(url + "/v1" for url in LYRIC_URLS), {
        "id": song_id, "cp": "false", "lv": 0, "kv": 0, "tv": 0,
        "rv": 0, "yv": 0, "ytv": 0, "yrv": 0})
    if response.get("code", 200) != 200:
        raise TemporaryAPIError(f"NetEase lyrics returned code {response.get('code')}")
    lines = parse_lrc((response.get("lrc") or {}).get("lyric", ""))
    timeline = lrc_timeline((response.get("lrc") or {}).get("lyric", ""))
    translations = parse_lrc((response.get("tlyric") or {}).get("lyric", ""))
    readings = parse_lrc((response.get("romalrc") or {}).get("lyric", ""))
    timed_lines, words, timed_events = parse_yrc((response.get("yrc") or {}).get("lyric", ""), with_timeline=True)
    if timed_lines:
        lines = timed_lines
        timeline = timed_events
        translations = parse_lrc((response.get("ytlrc") or {}).get("lyric", "")) or translations
        readings = parse_lrc((response.get("yromalrc") or {}).get("lyric", "")) or readings
    instrumental = response.get("pureMusic") is True
    if instrumental:
        lines, translations, readings, words, timeline = [], [], [], [], []

    try:
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(
            json.dumps(
                {
                    "song_id": song_id,
                    "source": source,
                    "provider_version": 9,
                    "timeline": timeline,
                    "words": words,
                    "checked_at": time.time(),
                    "media": asdict(state),
                    "lines": lines,
                    "translations": translations,
                    "readings": readings,
                    "instrumental": instrumental,
                },
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )
    except OSError:
        pass
    return LyricBundle(lines, translations, readings, instrumental=instrumental, words=words, timeline=timeline)


def fetch_lyrics(state: MediaState) -> LyricBundle:
    bundle = _fetch_lyrics(state)
    bundle.ruby = annotate_lines(state.title, bundle.lines, bundle.readings)
    return bundle


def _fetch_lyrics(state: MediaState) -> LyricBundle:
    """Resolve a track against NetEase and return timestamped lyrics."""
    if state.provider == "qqmusic":
        return LyricBundle(parse_lrc(state.embedded_lyrics), parse_lrc(state.embedded_translation),
                           timeline=lrc_timeline(state.embedded_lyrics)) if state.song_id and state.lyrics_ready else LyricBundle([], [])
    if not state.title or state.provider != "netease" or not state.song_id:
        return LyricBundle([], [])
    cache = _cache_path(state)
    cached = _read_lyric_cache(cache)
    if cached is not None:
        return cached

    # Panel and desktop instances run in separate processes. A per-track file
    # lock ensures that only one of them queries NetEase; the other consumes
    # the newly written cache entry after acquiring the lock.
    try:
        cache.parent.mkdir(parents=True, exist_ok=True)
        with cache.with_suffix(".lock").open("a+", encoding="utf-8") as lock_file:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
            cached = _read_lyric_cache(cache)
            if cached is not None:
                return cached
            return _fetch_and_cache_lyrics(state, cache)
    except OSError:
        return _fetch_and_cache_lyrics(state, cache)


def line_at(lines: list[tuple[float, str]], position: float) -> str:
    if not lines:
        return ""
    index = bisect_right([timestamp for timestamp, _ in lines], position) - 1
    return lines[index][1] if index >= 0 else ""


def lyric_index_at(lines: list[tuple[float, str]], position: float) -> int:
    if not lines:
        return -1
    return bisect_right([timestamp for timestamp, _ in lines], position) - 1


def lyric_context(
    lines: list[tuple[float, str]], position: float
) -> tuple[str, str, str]:
    """Return the previous, current and next non-empty lyric lines."""
    if not lines:
        return "", "", ""
    index = bisect_right([timestamp for timestamp, _ in lines], position) - 1
    if index < 0:
        return "", "", lines[0][1]
    return (
        lines[index - 1][1] if index > 0 else "",
        lines[index][1],
        lines[index + 1][1] if index + 1 < len(lines) else "",
    )


def lyric_window(
    lines: list[tuple[float, str]],
    translations: list[tuple[float, str]],
    position: float,
) -> dict[str, object]:
    """Build a complete variable-height lyric model and its active index."""
    if not lines:
        return {"hasTranslation": False, "entries": [], "currentIndex": -1}

    translation_times = [timestamp for timestamp, _ in translations]

    def translation_at(timestamp: float) -> str:
        if not translations:
            return ""
        index = bisect_right(translation_times, timestamp + 0.35) - 1
        if index >= 0 and abs(translations[index][0] - timestamp) <= 0.7:
            return translations[index][1]
        return ""

    has_translation = any(translation_at(timestamp) for timestamp, _ in lines)
    index = bisect_right([timestamp for timestamp, _ in lines], position) - 1

    def entry(line_index: int) -> dict[str, object]:
        timestamp, text = lines[line_index]
        return {"text": text, "translation": translation_at(timestamp), "timestamp": timestamp}

    return {
        "hasTranslation": has_translation,
        "entries": [entry(i) for i in range(len(lines))],
        "currentIndex": index,
    }


FALLBACK_PALETTE = ["#8b5cf6", "#22d3ee", "#f472b6"]


def _artwork_image(art_url: str) -> Image.Image | None:
    if not art_url:
        return None
    parsed = urllib.parse.urlparse(art_url)
    if parsed.scheme in ("", "file"):
        path = Path(urllib.parse.unquote(parsed.path if parsed.scheme else art_url))
        return Image.open(path)
    if parsed.scheme in ("http", "https"):
        request = urllib.request.Request(art_url, headers=HTTP_HEADERS)
        with urllib.request.urlopen(request, timeout=10) as response:
            return Image.open(BytesIO(response.read(12 * 1024 * 1024)))
    return None


def extract_palette(art_url: str, count: int = 3) -> list[str]:
    """Extract a compact, vivid palette from MPRIS cover artwork."""
    try:
        source = _artwork_image(art_url)
        if source is None:
            return FALLBACK_PALETTE.copy()
        with source:
            image = source.convert("RGB")
            image.thumbnail((96, 96))
            quantized = image.quantize(colors=16, method=Image.Quantize.MEDIANCUT)
            palette = quantized.getpalette() or []
            ranked: list[tuple[float, tuple[int, int, int]]] = []
            for frequency, palette_index in quantized.getcolors() or []:
                offset = palette_index * 3
                red, green, blue = palette[offset : offset + 3]
                brightest = max(red, green, blue)
                darkest = min(red, green, blue)
                saturation = (brightest - darkest) / max(1, brightest)
                luminance = (red * 0.2126 + green * 0.7152 + blue * 0.0722) / 255
                if luminance < 0.055 or luminance > 0.96:
                    continue
                score = frequency * (0.55 + saturation) * (0.65 + min(luminance, 0.72))
                ranked.append((score, (red, green, blue)))
            ranked.sort(reverse=True)

            selected: list[tuple[int, int, int]] = []
            for _, color in ranked:
                if all(sum((a - b) ** 2 for a, b in zip(color, old)) > 42**2 for old in selected):
                    selected.append(color)
                if len(selected) == count:
                    break
            if not selected:
                return FALLBACK_PALETTE.copy()
            while len(selected) < count:
                selected.append(selected[-1])
            return ["#%02x%02x%02x" % color for color in selected]
    except (OSError, ValueError, urllib.error.URLError):
        return FALLBACK_PALETTE.copy()


if __name__ == "__main__":
    state = read_mpris()
    bundle = fetch_lyrics(state)
    print(
        json.dumps(
            {
                "media": asdict(state),
                "line": line_at(bundle.lines, state.position),
                "translation": line_at(bundle.translations, state.position),
                "palette": extract_palette(state.art_url),
            },
            ensure_ascii=False,
        )
    )
