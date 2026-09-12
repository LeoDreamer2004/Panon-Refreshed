const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const {execFileSync} = require('node:child_process');
const path = require('node:path');
const scope = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../contents/ui/utils.js'), 'utf8'), scope);
for (const value of ["/tmp/space path", "/tmp/quote' dollar$ tick` slash\\", "/tmp/百分号%"]){
  const quoted = scope.shellQuote(value);
  assert.equal(execFileSync('/bin/sh', ['-c', 'printf %s ' + quoted], {encoding:'utf8'}), value);
  assert.equal(scope.localPath('file://' + encodeURI(value)), value);
}
assert.throws(() => scope.localPath('https://example.com'));
assert.match(scope.chdir_scripts_root('file:///tmp/a%20b'), / && $/);
console.log('QML paths: shell metacharacters, Unicode, URL decoding and failure gating OK');
