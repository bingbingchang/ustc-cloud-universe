// Network, checksum and disk-cache work must progress without game frames.
(() => {
  // Optional local diagnostics: long tasks measure actual blocking, not throttled background frames.
  const diagnostics = {phase:'loading',maxTaskMs:0,over1000:0,over5000:0};
  if (window.PerformanceObserver) {
    try {
      new window.PerformanceObserver(list => {
        for (const entry of list.getEntries()) {
          diagnostics.maxTaskMs=Math.max(diagnostics.maxTaskMs,entry.duration);
          if(entry.duration>=1000)diagnostics.over1000++;
          if(entry.duration>=5000)diagnostics.over5000++;
          if(entry.duration>=750)console.warn('CAMPUS_LONG_TASK',JSON.stringify({...diagnostics,taskMs:Math.round(entry.duration)}));
        }
      }).observe({entryTypes:['longtask']});
    } catch { /* Other browsers retain normal loading. */ }
  }
  const cacheName = 'campus-verified-assets-v2', cacheLimit = 96 * 1024 * 1024;
  let running = 0;
  const queue = [];
  async function permit() {
    if (running >= 3) await new Promise(resolve => queue.push(resolve));
    running++;
  }
  function release() { running--; queue.shift()?.(); }
  const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
  async function valid(bytes, sha) {
    if (!sha) return true;
    const hash = await crypto.subtle.digest('SHA-256', bytes);
    return [...new Uint8Array(hash)].map(v => v.toString(16).padStart(2, '0')).join('') === sha;
  }
  async function cached(url, sha, maxBytes) {
    if (!sha || !window.caches) return null;
    try {
      const cache = await window.caches.open(cacheName), found = await cache.match(url);
      if (!found) return null;
      if (Number(found.headers.get('X-Campus-Bytes')) > maxBytes) { await cache.delete(url); return null; }
      const bytes = await found.arrayBuffer();
      if (bytes.byteLength <= maxBytes && await valid(bytes, sha)) return bytes;
      await cache.delete(url);
    } catch { /* Private browsing and quota restrictions must not prevent playing. */ }
    return null;
  }
  async function store(url, bytes, sha) {
    if (!sha || !window.caches) return;
    try {
      const cache = await window.caches.open(cacheName);
      await cache.put(url, new Response(bytes, {headers: {'X-Campus-Bytes': String(bytes.byteLength)}}));
      const keys = await cache.keys();
      let total = 0;
      for (let i = keys.length - 1; i >= 0; i--) {
        const entry = await cache.match(keys[i]);
        total += Number(entry?.headers.get('X-Campus-Bytes')) || 0;
        if (total > cacheLimit) await cache.delete(keys[i]);
      }
    } catch { /* Disk cache is optional and bounded. */ }
  }
  function notify(stage, text, progress = -1) {
    diagnostics.phase=stage;
    window.parent?.postMessage({type: 'campus-load', stage, text, progress}, window.location.origin);
  }
  window.CampusRegionFetch = {
    retryRequested: false,
    notify,
    download(url, maxBytes, complete, sha = '') {
      const state = {received: 0, attempt: 0, cached: false};
      (async () => {
        let acquired = false, code = 0;
        try {
          const target = new URL(url, window.location.origin);
          if (target.origin !== window.location.origin || !target.pathname.startsWith('/game/releases/')) {
            complete(0, null); return;
          }
          const hit = await cached(target.href, sha, maxBytes);
          if (hit) { state.received = hit.byteLength; state.cached = true; complete(200, hit); return; }
          await permit(); acquired = true;
          for (let attempt = 1; attempt <= 3; attempt++) {
            state.attempt = attempt; state.received = 0;
            const controller = new AbortController();
            const timer = setTimeout(() => controller.abort(), 45000);
            try {
              const response = await fetch(target.href, {signal: controller.signal, redirect: 'error', credentials: 'same-origin', cache: attempt > 1 ? 'reload' : 'default'});
              code = response.status;
              if (response.ok) {
                if (!response.body || Number(response.headers.get('Content-Length')) > maxBytes) { await response.body?.cancel(); controller.abort(); code = 413; break; }
                const reader = response.body.getReader(), chunks = [];
                while (true) {
                  const {value, done} = await reader.read();
                  if (done) break;
                  state.received += value.byteLength;
                  if (state.received > maxBytes) { await reader.cancel(); code = 413; break; }
                  chunks.push(value);
                }
                if (code === 413) break;
                const bytes = new Uint8Array(state.received);
                let offset = 0;
                for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
                if (await valid(bytes.buffer, sha)) {
                  complete(200, bytes.buffer);
                  void store(target.href, bytes.buffer, sha);
                  return;
                }
                code = 422;
              }
            } catch { code = 0; }
            finally { clearTimeout(timer); }
            if (code && code < 500 && ![408, 422, 429].includes(code)) break;
            if (attempt < 3) await wait(attempt * 750);
          }
          complete(code, null);
        } catch { complete(0, null); }
        finally { if (acquired) release(); }
      })();
      return state;
    },
  };
  window.addEventListener?.('online', () => { window.CampusRegionFetch.retryRequested = true; });
  window.addEventListener?.('message', event => {
    if (event.origin === window.location.origin && event.source === window.parent && event.data?.type === 'campus-retry')
      window.CampusRegionFetch.retryRequested = true;
  });
})();

