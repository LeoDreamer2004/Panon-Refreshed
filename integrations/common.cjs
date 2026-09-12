const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');

function configHome() {
  const value = process.env.XDG_CONFIG_HOME;
  return value && path.isAbsolute(value) ? value : path.join(os.homedir(), '.config');
}

function resolveArchive(provider, candidates) {
  const configPath = path.join(configHome(), 'panon', 'integrations', `${provider}.json`);
  let config = {};
  if (fs.existsSync(configPath)) config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  if (config.appPath) {
    if (!path.isAbsolute(config.appPath) || !fs.existsSync(config.appPath))
      throw new Error(`Invalid configured application path in ${configPath}`);
    return config.appPath;
  }
  const found = candidates.filter(candidate => fs.existsSync(candidate));
  if (found.length !== 1) throw new Error(`Run ${provider}/install-launcher.py --app-path PATH --electron PATH; found ${found.length} application candidates`);
  return found[0];
}

function privateRuntime() {
  const runtime = process.env.XDG_RUNTIME_DIR;
  if (!runtime || !path.isAbsolute(runtime)) throw new Error('XDG_RUNTIME_DIR is required for the optional player bridge');
  const info = fs.lstatSync(runtime);
  if (!info.isDirectory() || info.uid !== process.getuid() || (info.mode & 0o077))
    throw new Error('Unsafe XDG_RUNTIME_DIR');
  const directory = path.join(runtime, 'panon');
  fs.mkdirSync(directory, {recursive:true, mode:0o700});
  const child = fs.lstatSync(directory);
  if (!child.isDirectory() || child.uid !== process.getuid() || (child.mode & 0o077))
    throw new Error('Unsafe Panon runtime directory');
  return directory;
}
module.exports = {resolveArchive, privateRuntime};
