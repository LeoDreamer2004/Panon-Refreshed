"""Opt-in live audio smoke test: active -> hidden -> active, no playback controls."""
import asyncio
import json
import os
import sys
from pathlib import Path
import websockets


async def main():
    frames = []
    failures = []
    done = asyncio.Event()
    async def handler(socket):
        hello = json.loads(await socket.recv())
        assert hello == {'hello': 'idle-smoke'}
        async def collect():
            async for message in socket:
                frames.append((asyncio.get_running_loop().time(), json.loads(message)))
        reader = asyncio.create_task(collect())
        try:
            phases = []
            for active in (True, False, True):
                start = asyncio.get_running_loop().time()
                await socket.send(json.dumps(dict(token='idle-smoke', action='activity', active=active, wallpaper=False)))
                await asyncio.sleep(3)
                data = [f for t, f in frames if t >= start + .5]
                spectra = sum('bands' in f for f in data)
                idle = sum(f.get('idle') is True for f in data)
                phases.append(spectra)
                print(f'active={active}: spectrum frames={spectra}, idle heartbeats={idle}', flush=True)
            assert phases[0] > 0 and phases[1] == 0 and phases[2] > 0
        except Exception as error:
            failures.append(error)
        finally:
            reader.cancel()
            await asyncio.gather(reader, return_exceptions=True)
            done.set()
    async with websockets.serve(handler, '127.0.0.1', 0) as server:
        port = server.sockets[0].getsockname()[1]
        env = dict(os.environ)
        env.pop('LD_LIBRARY_PATH', None)
        process = await asyncio.create_subprocess_exec(
            sys.executable, '-B', '-m', 'panon.backend.client', f'ws://127.0.0.1:{port}',
            '--fps=30', '--bands=64', '--token=idle-smoke',
            cwd=Path(__file__).resolve().parents[1] / 'contents/scripts', env=env,
            stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)
        try:
            await asyncio.wait_for(done.wait(), 30)
            if failures:
                raise failures[0]
        finally:
            if process.returncode is None: process.terminate()
            await process.wait()


if __name__ == '__main__': asyncio.run(main())
