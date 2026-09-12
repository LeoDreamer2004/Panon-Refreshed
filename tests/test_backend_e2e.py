"""Receive one real spectrum frame from the Panon backend."""

from __future__ import annotations

import asyncio
import json
import os
import subprocess
import sys
from pathlib import Path

from websockets.asyncio.server import serve


async def main() -> None:
    plugin_root = Path(__file__).resolve().parents[1]
    scripts = plugin_root / "contents" / "scripts"
    received: asyncio.Future[dict] = asyncio.get_running_loop().create_future()
    spectrum_only = "--spectrum-only" in sys.argv

    async def handler(websocket) -> None:
        async for message in websocket:
            payload = json.loads(message)
            media = payload.get("media", {})
            if (spectrum_only and payload.get("bands")) or (media.get("lyricsAvailable") and media.get("lyric")):
                if not received.done():
                    received.set_result(payload)
                return

    async with serve(handler, "127.0.0.1", 0) as server:
        port = server.sockets[0].getsockname()[1]
        environment = os.environ.copy()
        # Test the same ordinary interpreter startup used by the widget.
        environment.pop("LD_LIBRARY_PATH", None)
        process = await asyncio.create_subprocess_exec(
            sys.executable,
            "-m",
            "panon.backend.client",
            f"ws://127.0.0.1:{port}",
            "--fps=20",
            "--bands=32",
            "--decay=82",
            cwd=scripts,
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        try:
            payload = await asyncio.wait_for(received, timeout=20)
            bands = payload["bands"]
            assert len(bands) == 32
            assert max(bands) > 0.05
            assert payload["level"] > 0.0008
            print(
                "backend OK:",
                f"bands={len(bands)}",
                f"peak={max(bands):.4f}",
                f"level={payload['level']:.6f}",
                f"lyric={payload.get('media', {}).get('lyric', '')!r}",
            )
        finally:
            process.terminate()
            await process.wait()
            stderr = (await process.stderr.read()).decode(errors="replace").strip()
            if stderr:
                print(stderr, file=sys.stderr)


if __name__ == "__main__":
    asyncio.run(main())
