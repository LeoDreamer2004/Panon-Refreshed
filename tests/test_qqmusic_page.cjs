const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const script = fs.readFileSync(path.join(__dirname, '../integrations/qqmusic/now-playing.js'), 'utf8');
async function main() {
  const player = {currentSong:{id:123, mid:'mid123', title:'same', singer:[{name:'artist'}], album:{name:'album'}}, audio:{duration:60}};
  const meta = {title:'same', artist:'artist', album:'album'};
  let calls = 0;
  let translationCalls = 0;
  let failTranslation = false;
  let encodedTranslation = Buffer.from('[00:01]中文翻译').toString('base64');
  const loader = id => id === 35229 ? {Z:{getInstance:()=>player}} : {D:async query => {
    if (query.getTranslation) {
      translationCalls++;
      assert.equal(query.getTranslation.module, 'music.musichallSong.PlayLyricInfo');
      assert.equal(query.getTranslation.param.trans, 1);
      if (failTranslation) throw new Error('Offline');
      return {code:0, getTranslation:{code:0, data:{songID:query.getTranslation.param.songID, trans:encodedTranslation}}};
    }
    calls++;
    return {code:0, getLyric:{code:0, data:{info:[{type:'lyric',content:[{value:`[00:01]ID ${query.getLyric.param.song_id}`}]}]}}};
  }};
  loader.m = {35229:function currentSong(){}, 32590:function ufetch(){}};
  const chunks = []; chunks.push = chunk => chunk[2](loader);
  const profile = require('../integrations/qqmusic/adapters.json')['1.1.8'];
  assert.deepEqual(profile.testedRuntimeMajors, [44]);
  const context = vm.createContext({TextDecoder, atob, navigator:{mediaSession:{metadata:meta}}, window:{__panonQQProfile:profile}, global:{webpackChunkqqmusic:chunks}});
  const read = () => vm.runInContext(script, context);
  assert.equal(read().lyricsReady, false);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(read().lyric, '[00:01]ID 123');
  assert.equal(calls, 1);
  assert.equal(read().translation, '[00:01]中文翻译');
  assert.equal(translationCalls, 1);
  player.currentSong = {...player.currentSong, id:456, mid:'mid456'};
  assert.equal(read().songId, '456');
  assert.equal(read().lyric, '');
  assert.equal(read().translation, '');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(read().lyric, '[00:01]ID 456');
  assert.equal(calls, 2);
  for (const [id, encoded, fail] of [[789, '', false], [790, '%%%bad', false], [791, '', true]]) {
    player.currentSong = {...player.currentSong, id};
    encodedTranslation = encoded;
    failTranslation = fail;
    read();
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(read().lyric, `[00:01]ID ${id}`);
    assert.equal(read().translation, '');
    assert.equal(read().lyricsReady, true);
  }
  meta.title = 'not yet synchronized';
  assert.equal(read().songId, null);
  console.log('QQ page adapter: exact ID, async lyrics, per-track cache, same-title switch and stale metadata OK');
}
main().catch(error => {console.error(error); process.exitCode=1;});
