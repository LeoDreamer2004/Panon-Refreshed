// Optional Electron entry point. Loads the installed application unchanged.
const { app } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const {resolveArchive, privateRuntime} = require('../common.cjs');
const archive = resolveArchive('netease', [
  '/usr/lib/netease-cloud-music-web-player/app.asar',
  '/opt/netease-cloud-music-web-player/resources/app.asar'
]);
const metadata = require(path.join(archive, 'package.json'));
if (metadata.name !== 'netease-cloud-music-web-player') throw new Error('Unsupported player');
app.setName(metadata.name);
app.setVersion(metadata.version);
app.setPath('userData', path.join(app.getPath('appData'), metadata.name));
app.setAppPath(archive);
const directory = privateRuntime();
const target = path.join(directory, `netease-${process.pid}.json`);
const scriptPath = path.join(__dirname, 'now-playing.js');
let owner;
function publish(track) {
  const temporary = target + '.tmp';
  fs.writeFileSync(temporary, JSON.stringify({ version: 1, provider: 'netease',
    pid: process.pid, updatedAt: Date.now() / 1000, ...track }), { mode: 0o600 });
  fs.renameSync(temporary, target);
}
app.on('browser-window-created', (_event, window) => {
  if (owner) return;
  owner = window.webContents;
  let busy = false;
  const timer = setInterval(async () => {
    if (busy || owner.isDestroyed()) return;
    busy = true;
    try {
      const url = new URL(owner.getURL());
      if (url.protocol !== 'https:' || url.hostname !== 'music.163.com') {
        publish({ songId: null });
      } else {
        publish(await owner.executeJavaScript(fs.readFileSync(scriptPath, 'utf8')));
      }
    } catch { publish({ songId: null }); }
    finally { busy = false; }
  }, 750);
  window.once('closed', () => { clearInterval(timer); fs.rmSync(target, { force: true }); });
});
app.on('will-quit', () => fs.rmSync(target, { force: true }));
require(path.join(archive, metadata.main));
