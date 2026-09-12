// Runs the installed system-Electron QQ Music package unchanged.
const { app } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const { fileURLToPath } = require('node:url');
const {resolveArchive, privateRuntime} = require('../common.cjs');
const archive = resolveArchive('qqmusic', ['/usr/lib/qqmusic/app.asar']);
const metadata = require(path.join(archive, 'package.json'));
const profile = require('./adapters.json')[metadata.version];
if (metadata.name !== 'qqmusic' || !profile) throw new Error('Unsupported QQ Music package; update adapter first');
if (!profile.testedRuntimeMajors.includes(Number(process.versions.electron.split('.')[0])))
  throw new Error('Unsupported QQ Music Electron major; select a tested runtime with --electron');
app.setName(metadata.name);
app.setVersion(metadata.version);
app.setPath('userData', path.join(app.getPath('appData'), metadata.name));
app.setAppPath(archive);
// Upstream uses relative loadFile paths; preserve the installed app root.
const directory = privateRuntime();
const target = path.join(directory, `qqmusic-${process.pid}.json`);
const scriptPath = path.join(__dirname, 'now-playing.js');
let owner;
function publish(track) {
  fs.writeFileSync(target + '.tmp', JSON.stringify({...track, version:1, provider:'qqmusic',
    pid:process.pid, updatedAt:Date.now()/1000}), {mode:0o600});
  fs.renameSync(target + '.tmp', target);
}
app.on('web-contents-created', (_event, contents) => {
  let busy = false;
  const timer = setInterval(async () => {
    if (busy || contents.isDestroyed()) return;
    busy = true;
    try {
      const url = new URL(contents.getURL());
      // Only the packaged main player, never login windows or remote webviews.
      if (url.protocol !== 'file:' || fileURLToPath(url) !== path.join(archive, 'index.html')) return;
      if (owner && owner !== contents) return;
      owner = contents;
      const script = `window.__panonQQProfile = ${JSON.stringify(profile)};\n` + fs.readFileSync(scriptPath, 'utf8');
      publish(await contents.executeJavaScript(script));
    } catch {
      if (owner === contents) publish({songId:null});
    } finally { busy = false; }
  }, 750);
  contents.once('destroyed', () => {
    clearInterval(timer);
    if (owner === contents) { owner = null; fs.rmSync(target, {force:true}); }
  });
});
app.on('will-quit', () => fs.rmSync(target, {force:true}));
require(path.join(archive, metadata.main));
