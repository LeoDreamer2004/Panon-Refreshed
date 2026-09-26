"""PipeWire/PulseAudio spectrum backend for the Plasma 6 Panon widget."""

from __future__ import annotations

import argparse
import asyncio
import json
import math
import subprocess
import sys
from dataclasses import dataclass

import numpy as np
import websockets

from .lyrics import (
    FALLBACK_PALETTE,
    LyricBundle,
    MediaState,
    extract_palette,
    fetch_lyrics,
    lyric_context,
    lyric_index_at,
    lyric_window,
    playback_lyric_timing,
    read_mpris,
)
from .control import execute_command
from .wallpaper import read_wallpaper


def default_monitor() -> str:
    """Return the monitor source belonging to the current default sink."""
    sink = subprocess.check_output(
        ["pactl", "get-default-sink"], text=True, timeout=2
    ).strip()
    if not sink:
        raise RuntimeError("PipeWire did not report a default output device")
    sinks = json.loads(subprocess.check_output(["pactl", "--format=json", "list", "sinks"], text=True, timeout=2))
    for item in sinks:
        if item.get("name") != sink:
            continue
        monitor = item.get("monitor_source_name") or item.get("monitor_source")
        if isinstance(monitor, str) and monitor:
            return monitor
        if isinstance(monitor, int):
            sources = json.loads(subprocess.check_output(["pactl", "--format=json", "list", "sources"], text=True, timeout=2))
            for source in sources:
                if source.get("index") == monitor and source.get("name"):
                    return str(source["name"])
    raise RuntimeError("Default output has no monitor source")


@dataclass
class AudioCapture:
    fps: int
    sample_rate: int = 48_000
    channels: int = 2
    process: subprocess.Popen[bytes] | None = None
    monitor: str = ""

    @property
    def frame_count(self) -> int:
        return self.sample_rate // self.fps

    @property
    def byte_count(self) -> int:
        return self.frame_count * self.channels * 2

    def start(self, monitor: str) -> None:
        self.stop()
        self.monitor = monitor
        self.process = subprocess.Popen(
            [
                "parec",
                f"--device={monitor}",
                "--raw",
                "--format=s16le",
                f"--rate={self.sample_rate}",
                f"--channels={self.channels}",
                f"--latency-msec={max(10, round(1000 / self.fps))}",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    def stop(self) -> None:
        if self.process is None:
            return
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=1)
        self.process = None

    def read(self) -> np.ndarray:
        if self.process is None or self.process.stdout is None:
            raise RuntimeError("audio capture is not running")
        data = self.process.stdout.read(self.byte_count)
        if len(data) != self.byte_count:
            detail = ""
            if self.process.stderr is not None:
                detail = self.process.stderr.read().decode(errors="replace").strip()
            raise RuntimeError(detail or "audio capture ended unexpectedly")
        samples = np.frombuffer(data, dtype="<i2").reshape(-1, self.channels)
        return samples.astype(np.float32).mean(axis=1) / 32768.0


class SpectrumAnalyzer:
    def __init__(self, sample_rate: int, frame_count: int, bands: int, decay: int):
        self.sample_rate = sample_rate
        self.frame_count = frame_count
        self.bands = bands
        self.edges = np.geomspace(45.0, min(18_000.0, sample_rate / 2), bands + 1)
        # Choose a resolution per logarithmic band, independently of display
        # FPS. At 48 kHz/64 bands this spans 1024..16384 samples (21..341 ms).
        # Long bass windows overlap between frames; treble stays responsive.
        sizes = np.clip(2 ** np.ceil(np.log2(sample_rate / np.diff(self.edges))),
                        1024, 16384).astype(int)
        self.history = np.zeros(int(max(sizes)), dtype=np.float32)
        self.windows = {int(n): np.hanning(int(n)).astype(np.float32) for n in sizes}
        self.band_maps = []
        for i, n in enumerate(sizes):
            frequencies = np.fft.rfftfreq(n, 1.0 / sample_rate)
            low, high = self.edges[i:i + 2]
            first, last = np.searchsorted(frequencies, (low, high))
            # Evaluate both band boundaries as well as all interior bins.
            # Interpolation covers narrow bands even at the maximum FFT size;
            # it doesn't pretend to create additional independent resolution.
            points = np.concatenate(([low], frequencies[first:last], [high]))
            offsets = np.clip(points * n / sample_rate, 0, len(frequencies) - 1)
            left = np.floor(offsets).astype(int)
            right = np.minimum(left + 1, len(frequencies) - 1)
            self.band_maps.append((int(n), left, right, offsets - left))
        self.previous = np.zeros(bands, dtype=np.float32)
        self.decay = min(0.97, max(0.2, decay / 100.0))

    def analyze(self, samples: np.ndarray) -> tuple[list[float], float]:
        if len(samples) == 0:
            return [round(float(value), 4) for value in self.previous], 0.0
        level = float(np.sqrt(np.mean(np.square(samples), dtype=np.float64)))
        count = min(len(samples), len(self.history))
        if count < len(self.history):
            self.history[:-count] = self.history[count:]
        self.history[-count:] = samples[-count:]
        magnitudes = {
            n: np.abs(np.fft.rfft(self.history[-n:] * window)) * (2.0 / n)
            for n, window in self.windows.items()
        }
        values = np.zeros(self.bands, dtype=np.float32)

        for index, (n, left, right, fraction) in enumerate(self.band_maps):
            magnitude = magnitudes[n]
            band_value = float(np.max(magnitude[left] * (1 - fraction) + magnitude[right] * fraction))
            decibels = 20.0 * math.log10(max(band_value, 1e-7))
            values[index] = np.clip((decibels + 72.0) / 72.0, 0.0, 1.0)

        self.previous = np.maximum(values, self.previous * self.decay)
        return [round(float(value), 4) for value in self.previous], level

    def reset(self) -> None:
        self.history.fill(0)
        self.previous.fill(0)


async def run(url: str, fps: int, bands: int, decay: int, *, token="", audio_source="", preferred_player="") -> None:
    capture = AudioCapture(fps=fps)
    analyzer = SpectrumAnalyzer(capture.sample_rate, capture.frame_count, bands, decay)
    frame = 0
    media = MediaState()
    media_read_at = 0.0
    lyric_lines: list[tuple[float, str]] = []
    translated_lines: list[tuple[float, str]] = []
    lyric_model: dict[str, object] = {
        "hasTranslation": False,
        "entries": [],
        "currentIndex": -1,
        "modelId": "",
    }
    palette = FALLBACK_PALETTE.copy()
    poll_task: asyncio.Task[MediaState] | None = None
    lyric_task: asyncio.Task[tuple[str, LyricBundle, bool]] | None = None
    palette_task: asyncio.Task[tuple[str, str, list[str]]] | None = None
    next_media_poll = 0.0
    next_lyric_retry = 0.0
    lyric_retry_count = 0
    lyrics_resolved = True
    next_palette_retry = 0.0
    palette_retry_count = 0
    palette_pending = True
    wallpaper_url = ""
    next_wallpaper_poll = 0.0
    wallpaper = {}
    screen_id = -1
    command_task = None
    visual_active = True
    wants_wallpaper = True
    wake = asyncio.Event()
    sent_model_id = None

    async def receive_commands(websocket):
        nonlocal next_media_poll, screen_id, next_wallpaper_poll, visual_active, wants_wallpaper, sent_model_id
        async for message in websocket:
            try:
                command = json.loads(message)
                if not isinstance(command, dict) or not token or command.get("token") != token:
                    continue
                if command.get("action") == "activity":
                    if type(command.get("active")) is bool:
                        visual_active = command["active"]
                        wants_wallpaper = command.get("wallpaper") is True
                        next_media_poll = next_wallpaper_poll = 0
                        if visual_active:
                            sent_model_id = None
                        wake.set()
                    continue
                if command.get("action") == "screen":
                    screen = command.get("screen")
                    if type(screen) is int and -1 <= screen <= 128 and screen != screen_id:
                        screen_id = screen
                        next_wallpaper_poll = 0
                    continue
                await asyncio.to_thread(execute_command, media, command)
                next_media_poll = 0.0
                wake.set()
            except Exception as error:
                print(f"Media command rejected: {error}", file=sys.stderr)

    async def load_lyrics(
        state: MediaState,
    ) -> tuple[str, LyricBundle, bool]:
        try:
            return state.identity, await asyncio.to_thread(fetch_lyrics, state), True
        except Exception as error:
            print(f"NetEase lyric lookup failed: {error}", file=sys.stderr)
            return state.identity, LyricBundle([], []), False

    async def load_palette(state: MediaState) -> tuple[str, str, list[str]]:
        try:
            colors = await asyncio.to_thread(extract_palette, state.art_url)
            return state.identity, state.art_url, colors
        except Exception as error:
            print(f"Cover palette extraction failed: {error}", file=sys.stderr)
            return state.identity, state.art_url, FALLBACK_PALETTE.copy()

    try:
        async with websockets.connect(url, open_timeout=5, max_size=8192, max_queue=8) as websocket:
            if token:
                await websocket.send(json.dumps({"hello": token}))
            command_task = asyncio.create_task(receive_commands(websocket))
            while True:
                now = asyncio.get_running_loop().time()
                if visual_active and wants_wallpaper and now >= next_wallpaper_poll:
                    wallpaper = await asyncio.to_thread(read_wallpaper, screen_id)
                    wallpaper_url = wallpaper.get("url", "")
                    next_wallpaper_poll = now + 1.0
                if poll_task is None and now >= next_media_poll:
                    poll_task = asyncio.create_task(asyncio.to_thread(read_mpris, preferred_player, media.service))
                    next_media_poll = now + (0.25 if visual_active else 2.0)

                if poll_task is not None and poll_task.done():
                    try:
                        updated_media = poll_task.result()
                        track_changed = updated_media.identity != media.identity
                        artwork_changed = updated_media.art_url != media.art_url
                        if track_changed:
                            lyric_lines = []
                            translated_lines = []
                            lyric_model = {
                                "hasTranslation": False,
                                "entries": [],
                                "currentIndex": -1,
                                "modelId": f"{updated_media.identity}\x1e0\x1e0",
                            }
                            lyrics_resolved = not bool(updated_media.title)
                            lyric_retry_count = 0
                            next_lyric_retry = now + 0.8
                            if lyric_task is not None and not lyric_task.done():
                                lyric_task.cancel()
                            lyric_task = None
                        if track_changed or artwork_changed:
                            # Hold the previous palette while the next cover loads.
                            palette_pending = True
                            palette_retry_count = 0
                            next_palette_retry = now
                            if palette_task is not None and not palette_task.done():
                                palette_task.cancel()
                            palette_task = None
                        media = updated_media
                        media_read_at = now
                    except Exception as error:
                        print(f"MPRIS lookup failed: {error}", file=sys.stderr)
                    poll_task = None

                if lyric_task is not None and lyric_task.done():
                    try:
                        identity, loaded_bundle, succeeded = lyric_task.result()
                        if identity == media.identity:
                            if succeeded:
                                lyric_lines = loaded_bundle.lines
                                translated_lines = loaded_bundle.translations
                                lyric_model = lyric_window(
                                    lyric_lines, translated_lines, 0.0
                                )
                                for entry, ruby in zip(lyric_model["entries"], loaded_bundle.ruby):
                                    entry["ruby"] = ruby
                                for entry, words in zip(lyric_model["entries"], loaded_bundle.words):
                                    entry["words"] = words
                                events = [event for event in loaded_bundle.timeline if not event["blank"]]
                                for entry, event in zip(lyric_model["entries"], events):
                                    entry["end"] = event["end"]
                                lyric_model["hasFurigana"] = any(
                                    part.get("reading") for line in loaded_bundle.ruby for part in line
                                )
                                lyric_model["instrumental"] = loaded_bundle.instrumental
                                lyric_model["modelId"] = (
                                    f"{media.identity}\x1e{len(lyric_lines)}"
                                    f"\x1e{len(translated_lines)}"
                                    f"\x1eresolved:{loaded_bundle.instrumental}"
                                )
                                lyrics_resolved = True
                            else:
                                next_lyric_retry = now + 5.0 * lyric_retry_count
                    except asyncio.CancelledError:
                        pass
                    lyric_task = None

                # Wait briefly after a track change so quickly skipped songs do
                # not issue requests. Transient failures are retried without
                # blocking audio capture or the QML renderer.
                if (
                    visual_active and lyric_task is None
                    and media.title
                    and not lyrics_resolved
                    and lyric_retry_count < 3
                    and now >= next_lyric_retry
                ):
                    lyric_retry_count += 1
                    lyric_task = asyncio.create_task(load_lyrics(media))

                if palette_task is not None and palette_task.done():
                    try:
                        identity, art_url, loaded_palette = palette_task.result()
                        if identity == media.identity and art_url == media.art_url:
                            palette_pending = loaded_palette == FALLBACK_PALETTE
                            if not palette_pending:
                                palette = loaded_palette
                            if loaded_palette == FALLBACK_PALETTE and art_url:
                                next_palette_retry = now + 1.5
                    except asyncio.CancelledError:
                        pass
                    palette_task = None

                # Some MPRIS players publish the cover URL before its temporary
                # file is ready. Retry only the artwork extraction, never the
                # lyric network request, and stop after a few attempts.
                if (
                    visual_active and wants_wallpaper and palette_task is None
                    and media.art_url
                    and palette_pending
                    and palette_retry_count < 6
                    and now >= next_palette_retry
                ):
                    palette_retry_count += 1
                    next_palette_retry = now + 1.5
                    palette_task = asyncio.create_task(load_palette(media))

                audio_error = ""
                if not visual_active:
                    capture.stop()
                    analyzer.reset()
                    await websocket.send(json.dumps({"idle": True}))
                    try:
                        await asyncio.wait_for(wake.wait(), timeout=2.0)
                    except asyncio.TimeoutError:
                        pass
                    wake.clear()
                    continue
                try:
                    if (
                        capture.process is None
                        or capture.process.poll() is not None
                        or frame % fps == 0
                    ):
                        monitor = audio_source or await asyncio.to_thread(default_monitor)
                        if monitor != capture.monitor or capture.process is None or capture.process.poll() is not None:
                            capture.start(monitor)
                            analyzer.reset()
                    samples = await asyncio.to_thread(capture.read)
                except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                    capture.stop()
                    frame = 0
                    audio_error = str(error)
                    analyzer.reset()
                    samples = np.zeros(capture.frame_count, dtype=np.float32)
                    await asyncio.sleep(0.5)

                values, level = analyzer.analyze(samples)
                position = media.position
                if media.playing and media_read_at:
                    position += max(0.0, now - media_read_at)
                previous_lyric, current_lyric, next_lyric = lyric_context(
                    lyric_lines, position
                )
                visible_lyrics = dict(lyric_model)
                visible_lyrics["currentIndex"] = lyric_index_at(
                    lyric_lines, position
                )
                line_index = visible_lyrics["currentIndex"]
                visible_lyrics["timing"] = playback_lyric_timing(
                    lyric_model["entries"], line_index, position, media.duration)
                model_id = lyric_model.get("modelId", "")
                if sent_model_id == model_id:
                    visible_lyrics = {key: visible_lyrics[key] for key in ("modelId", "currentIndex", "timing")}
                else:
                    sent_model_id = model_id
                await websocket.send(
                    json.dumps(
                        {
                            "bands": values,
                            "level": level,
                            "audioError": audio_error,
                            "media": {
                                "service": media.service,
                                "owner": media.owner,
                                "trackId": media.track_id,
                                "position": position,
                                "duration": media.duration,
                                "canSeek": media.can_seek,
                                "canGoNext": media.can_next,
                                "canGoPrevious": media.can_previous,
                                "canPlayPause": media.can_play_pause,
                                "provider": media.provider,
                                "title": media.title,
                                "artist": media.artist,
                                "artUrl": media.art_url,
                                "colors": palette,
                                "playing": media.playing,
                                "active": bool(
                                    media.title and media.playback_status != "Stopped"
                                ),
                                "wallpaperUrl": wallpaper_url,
                                "wallpaper": wallpaper,
                                "lyricsAvailable": bool(lyric_lines),
                                "previousLyric": previous_lyric,
                                "lyric": current_lyric,
                                "nextLyric": next_lyric,
                                "lyricWindow": visible_lyrics,
                            },
                        },
                        ensure_ascii=False,
                    )
                )
                frame += 1
    finally:
        capture.stop()
        tasks = [task for task in (command_task, poll_task, lyric_task, palette_task) if task is not None]
        for task in tasks:
            task.cancel()
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--bands", type=int, default=64)
    parser.add_argument("--decay", type=int, default=82)
    parser.add_argument("--token", default="")
    parser.add_argument("--audio-source", default="")
    parser.add_argument("--preferred-player", default="")
    args = parser.parse_args()
    args.fps = min(60, max(5, args.fps))
    args.bands = min(128, max(8, args.bands))
    return args


def main() -> None:
    args = parse_args()
    try:
        asyncio.run(run(args.url, args.fps, args.bands, args.decay, token=args.token,
                        audio_source=args.audio_source, preferred_player=args.preferred_player))
    except KeyboardInterrupt:
        pass
    except Exception as error:
        print(f"Panon backend failed: {error}", file=sys.stderr)
        raise


if __name__ == "__main__":
    main()
