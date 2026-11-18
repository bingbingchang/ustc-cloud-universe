// Resume large engine downloads at verified part boundaries; never hold the full PCK twice.
(() => {
  // Touch-event support alone is also reported by some desktop browsers.
  // Only a coarse primary pointer should redirect Godot input to a mobile keyboard.
  window.CampusMobileKeyboard = Boolean(window.navigator?.maxTouchPoints > 0 && window.matchMedia?.('(pointer:coarse)').matches);
  if (!window.DecompressionStream || !window.ReadableStream) return;
  const originalFetch = window.fetch.bind(window), cacheName = 'campus-engine-parts-v1';
  const digest = async bytes => [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))].map(v => v.toString(16).padStart(2, '0')).join('');
  const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
  let trimQueue = Promise.resolve();
  async function store(cache, url, bytes) {
    if (!cache) return;
    try {
      await cache.put(url, new Response(bytes, {headers: {'X-Campus-Bytes': String(bytes.byteLength)}}));
      trimQueue = trimQueue.then(async () => {
        let total = 0;const keys = await cache.keys();
        for (let i = keys.length - 1; i >= 0; i--) {
          const response = await cache.match(keys[i]);total += Number(response?.headers.get('X-Campus-Bytes')) || 0;
          if (total > 160 * 1024 * 1024) await cache.delete(keys[i]);
        }
      }).catch(() => undefined);
    } catch { /* Private browsing and storage quota failures retain network play. */ }
  }
  window.fetch = async function(input, init) {
    const target = new URL(typeof input === 'string' ? input : input.url, window.location.href);
    if (target.origin !== window.location.origin || !/^\/game\/releases\/[^/]+\/index\.(pck|wasm)$/.test(target.pathname) || (init?.method && init.method !== 'GET'))
      return originalFetch(input, init);
    const description = await originalFetch(target.href + '.parts.json', {credentials: 'same-origin', signal: init?.signal});
    if (description.status === 404) return originalFetch(input, init); // Older deployments have no part checksums.
    if (!description.ok) throw Error('Engine manifest unavailable: ' + description.status);
    const spec = await description.json();
    if (!Array.isArray(spec.parts) || !spec.parts.length || spec.parts.length > 64 || !spec.parts.every(p => /^[0-9a-f]{64}$/.test(p.sha256) && Number.isSafeInteger(p.bytes) && p.bytes > 0 && p.bytes <= 16 * 1024 * 1024 && p.key.startsWith(target.pathname.slice(6) + '.part') && !p.key.includes('..')))
      return originalFetch(input, init);
    let cache;
    try {cache = await window.caches?.open(cacheName);} catch { /* Optional cache. */ }
    let cancelled = false;
    async function part(index) {
      const expected = spec.parts[index], url = new URL('/game/' + expected.key, target).href;
      if (cache) {
        try {
          const hit = await cache.match(url);
          if (hit) {
            const bytes = await hit.arrayBuffer();
            if (bytes.byteLength === expected.bytes && await digest(bytes) === expected.sha256) return new Uint8Array(bytes);
            await cache.delete(url);
          }
        } catch {cache = undefined;}
      }
      for (let attempt = 0; attempt < 3; attempt++) {
        if (cancelled || init?.signal?.aborted) throw Error('Engine download cancelled');
        try {
          const response = await originalFetch(url, {credentials: 'same-origin', signal: init?.signal || AbortSignal.timeout(60000), cache: attempt ? 'reload' : 'default'});
          if (!response.ok) throw Error('Engine part unavailable');
          const bytes = await response.arrayBuffer();
          if (bytes.byteLength !== expected.bytes || await digest(bytes) !== expected.sha256) throw Error('Engine part checksum mismatch');
          // Keep a completed part before advancing, so an immediate interruption can resume it.
          await store(cache, url, bytes);return new Uint8Array(bytes);
        } catch (error) {if (attempt === 2) throw error;await pause((attempt + 1) * 750);}
      }
    }
    let next = 0;
    const stream = new ReadableStream({
      async pull(controller) {
        try {
          if (next >= spec.parts.length) {controller.close();return;}
          controller.enqueue(await part(next++));
        } catch (error) {controller.error(error);}
      },
      cancel() {cancelled = true;},
    }, {highWaterMark: 0});
    const body = spec.encoding === 'gzip' ? stream.pipeThrough(new DecompressionStream('gzip')) : stream;
    return new Response(body, {headers: {'Content-Type': target.pathname.endsWith('.wasm') ? 'application/wasm' : 'application/octet-stream'}});
  };
})();
