const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const script = fs.readFileSync(path.join(__dirname, '../integrations/netease/now-playing.js'), 'utf8');
function props(id, title='song') {
  return {resourceType:'track', resourceName:title, onlineResourceId:id,
    curPlaying:{resourceType:'track', localTrack:{}, trackId:id,
      track:{id, name:title, artists:[{name:'artist'}], album:{name:'album'}, duration:100000}}};
}
function node(properties) {
  const root = {stateNode:{}}; root.stateNode.current = root;
  return {__reactInternalInstance$test:{memoizedProps:properties, return:root}};
}
function read(nodes, title='song') {
  return vm.runInNewContext(script, {navigator:{mediaSession:{metadata:{title, artist:'artist', album:'album'}}},
    document:{querySelectorAll(selector){assert.equal(selector, '#page_pc_mini_bar, #btn_pc_minibar_play'); return nodes;}}});
}
assert.equal(read([node(props('123'))]).songId, '123');
// Same title can refer to a different recording: use the actual ID each time.
assert.equal(read([node(props('456'))]).songId, '456');
assert.equal(read([node(props('123','previous'))]).songId, null);
assert.equal(read([]).songId, null);
assert.equal(read([node(props('123')),node(props('456'))]).songId, null);
const podcast = props('123'); podcast.resourceType = 'radio';
assert.equal(read([node(podcast)]).songId, null);
const local = props('123'); local.curPlaying.localTrack = {path:'/music/file.mp3'};
assert.equal(read([node(local)]).songId, null);
const stale = node(props('123'));
const active = node(props('456'));
stale.__reactInternalInstance$test.return.stateNode.current = active.__reactInternalInstance$test.return;
stale.__reactInternalInstance$test.alternate = active.__reactInternalInstance$test;
assert.equal(read([stale]).songId, '456');
console.log('Page adapter: exact ID, same titles, stale React tree, mismatches, unsupported media OK');
