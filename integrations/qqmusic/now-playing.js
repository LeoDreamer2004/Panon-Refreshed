(() => {
  const meta = navigator.mediaSession?.metadata;
  if (!meta?.title) return {songId:null};
  const scope = typeof global === 'object' ? global : window;
  const chunks = scope.webpackChunkqqmusic;
  if (!Array.isArray(chunks)) return {songId:null};
  const profile = window.__panonQQProfile;
  if (!profile || !Number.isInteger(profile.playerModule) || !Number.isInteger(profile.apiModule)) return {songId:null};
  if (window.__panonQQ?.version !== 2) {
    let loader;
    chunks.push([['panon-readonly-adapter-v1'], {}, require => { loader = require; }]);
    if (!loader || !loader.m?.[profile.playerModule]?.toString().includes('currentSong')
        || !loader.m?.[profile.apiModule]?.toString().includes('ufetch')) return {songId:null};
    Object.defineProperty(window, '__panonQQ', {value:{version:2, loader, cache:new Map()}, configurable:true});
  }
  const state = window.__panonQQ;
  const player = state.loader(profile.playerModule).Z.getInstance();
  const song = player?.currentSong;
  const id = String(song?.id || '');
  if (!/^[1-9]\d{0,19}$/.test(id) || song.title !== meta.title
      || song.singer?.[0]?.name !== meta.artist) return {songId:null};
  const album = song.album?.name || song.track?.album?.name || '';
  if (album !== meta.album) return {songId:null};
  let cached = state.cache.get(id);
  if (!cached || (cached.error && Date.now() - cached.at > 15000 && cached.attempts < 3)) {
    cached = {ready:false, at:Date.now(), attempts:(cached?.attempts || 0)+1};
    state.cache.set(id, cached);
    while (state.cache.size > 8) state.cache.delete(state.cache.keys().next().value);
    // Use the app's existing authenticated read API. Never export credentials.
    Promise.resolve(state.loader(profile.apiModule).D({getLyric:{method:'get_song_detail',
      module:'music.pf_song_detail_svr', param:{song_id:Number(id)}}})).then(response => {
      if (response?.code !== 0 || response.getLyric?.code !== 0) throw new Error('Lyric lookup failed');
      const info = response.getLyric.data?.info || [];
      const lyric = info.find(item => item.type === 'lyric')?.content?.[0]?.value || '';
      if (typeof lyric !== 'string' || lyric.length > 300000) throw new Error('Invalid lyric');
      cached.lyric = lyric;
      cached.ready = true;
    }).catch(() => { cached.error = true; });
  }
  // Translation is independent: an unavailable endpoint must not hide the original.
  if (!cached.translation || (cached.translation.error
      && Date.now() - cached.translation.at > 15000 && cached.translation.attempts < 3)) {
    const translation = {at:Date.now(), attempts:(cached.translation?.attempts || 0)+1, text:''};
    cached.translation = translation;
    Promise.resolve().then(() => state.loader(profile.apiModule).D({getTranslation:{
      module:'music.musichallSong.PlayLyricInfo', method:'GetPlayLyricInfo',
      param:{songID:Number(id), songMID:String(song.mid || ''), crypt:0, qrc:0, roma:0, trans:1}
    }})).then(response => {
      const result = response?.getTranslation;
      if (response?.code !== 0 || result?.code !== 0) throw new Error('Translation lookup failed');
      const data = result.data;
      if (!data || (data.songID != null && String(data.songID) !== id)) throw new Error('Wrong translation ID');
      const encoded = data.trans || '';
      if (typeof encoded !== 'string' || encoded.length > 400000) throw new Error('Invalid translation');
      const text = encoded ? new TextDecoder('utf-8', {fatal:true}).decode(
        Uint8Array.from(atob(encoded), char => char.charCodeAt(0))) : '';
      if (text.length > 300000 || (text && !/\[\d+:\d+(?:\.\d+)?\]/.test(text))) throw new Error('Invalid translation LRC');
      translation.text = text;
    }).catch(() => { translation.error = true; });
  }
  return {songId:id, songMid:String(song.mid || ''), title:meta.title, artist:meta.artist,
    album:meta.album, lyricsReady:cached.ready, lyric:cached.ready ? cached.lyric : '',
    translation:cached.translation?.text || '',
    source:'Player.currentSong', duration:Number(player.audio?.duration) || 0};
})()
