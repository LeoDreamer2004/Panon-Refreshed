(() => {
  // Read only the committed React component behind the persistent play bar.
  // Never use browsed URLs, search results, recommendations or playlists.
  const metadata = navigator.mediaSession?.metadata;
  const empty = {songId: null};
  if (!metadata?.title) return empty;
  const nodes = document.querySelectorAll('#page_pc_mini_bar, #btn_pc_minibar_play');
  const candidates = new Map();
  for (const node of nodes) {
    const key = Object.keys(node).find(k => k.startsWith('__reactFiber$') || k.startsWith('__reactInternalInstance$'));
    let fiber = node[key];
    if (!fiber) continue;
    let tree = fiber;
    for (let i = 0; tree.return && i < 100; i++) tree = tree.return;
    // A DOM fiber may point to the previous render. Use the committed tree.
    if (tree.stateNode?.current && tree.stateNode.current !== tree) fiber = fiber.alternate;
    for (let i = 0; fiber && i < 12; i++, fiber = fiber.return) {
      const props = fiber.memoizedProps || {};
      const playing = props.curPlaying;
      const track = playing?.track;
      if (props.resourceType !== 'track' || playing?.resourceType !== 'track'
          || Object.keys(playing.localTrack || {}).length || !track) continue;
      const id = String(track.id || '');
      if (!/^[1-9]\d{0,19}$/.test(id) || String(playing.trackId) !== id || String(props.onlineResourceId) !== id) continue;
      const title = track.name;
      const artist = (track.artists || []).map(a => a.name).join('/');
      const album = track.album?.name;
      if (title !== metadata.title || props.resourceName !== title
          || artist !== metadata.artist || album !== metadata.album) continue;
      candidates.set(id, {songId: id, title, artist, album,
        duration: Number(track.duration) / 1000, source: 'playbar.curPlaying.track'});
    }
  }
  return candidates.size === 1 ? [...candidates.values()][0] : empty;
})()
