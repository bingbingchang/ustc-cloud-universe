import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {webcrypto,createHash} from 'node:crypto';
const source=readFileSync(new URL('../godot/web/region_fetch.js',import.meta.url),'utf8');
function runtime(fetch,caches){
  const window={location:{origin:'https://campus.test'},caches};
  const quickTimer=(fn,ms)=>setTimeout(fn,ms<5000?0:ms);
  vm.runInNewContext(source,{window,fetch,URL,AbortController,setTimeout:quickTimer,clearTimeout,Uint8Array,Response,crypto:webcrypto});
  return window.CampusRegionFetch;
}
async function download(fetch,url='https://campus.test/game/releases/test/region.scn',limit=32,sha='',api){
  api=api||runtime(fetch);
  return await new Promise(resolve=>api.download(url,limit,(code,buffer)=>resolve({code,buffer}),sha));
}
test('complete bytes arrive without a game animation-frame poll',async()=>{
  const result=await download(async()=>new Response(new Uint8Array([1,2,3])));
  assert.equal(result.code,200);assert.deepEqual([...new Uint8Array(result.buffer)],[1,2,3]);
});
test('other origins are rejected before contacting them',async()=>{
  const result=await download(()=>{throw Error('must not fetch');},'https://other.test/game/releases/a.scn');
  assert.equal(result.code,0);
});
test('oversized streamed bytes are rejected',async()=>{
  const result=await download(async()=>new Response(new Uint8Array(33)));
  assert.equal(result.code,413);assert.equal(result.buffer,null);
});
test('HTTP failure is preserved and can be retried by the zone loader',async()=>{
  const result=await download(async()=>new Response(null,{status:503}));
  assert.equal(result.code,503);assert.equal(result.buffer,null);
});

test('transient failure retries automatically without requesting game frames',async()=>{
  let calls=0;
  const result=await download(async()=>++calls===1?new Response(null,{status:503}):new Response('ok'));
  assert.equal(result.code,200);assert.equal(calls,2);
});

test('corrupt content is never accepted and retry obtains checksum-correct bytes',async()=>{
  let calls=0;const sha=createHash('sha256').update('good').digest('hex');
  const result=await download(async()=>new Response(++calls===1?'bad':'good'),undefined,32,sha);
  assert.equal(result.code,200);assert.equal(calls,2);
});

test('verified cached data allows a second visit during network outage',async()=>{
  const rows=new Map();let writes=0,calls=0;
  const cache={async match(key){return rows.get(key)?.clone();},async put(key,value){rows.set(key,value);writes++;},async keys(){return [...rows.keys()];},async delete(key){return rows.delete(key);}};
  const api=runtime(async()=>{calls++;return new Response('cached');},{async open(){return cache;}});
  const sha=createHash('sha256').update('cached').digest('hex');
  assert.equal((await download(null,undefined,32,sha,api)).code,200);
  while(!writes)await new Promise(resolve=>setImmediate(resolve));
  assert.equal((await download(null,undefined,32,sha,api)).code,200);
  assert.equal(calls,1);
});

test('parallel requests remain bounded while all jobs complete',async()=>{
  let active=0,peak=0;
  const api=runtime(async()=>{active++;peak=Math.max(peak,active);await new Promise(resolve=>setTimeout(resolve,5));active--;return new Response('ok');});
  const results=await Promise.all(Array.from({length:12},(_,i)=>download(null,'https://campus.test/game/releases/test/'+i+'.res',32,'',api)));
  assert.equal(results.filter(r=>r.code===200).length,12);assert.equal(peak,3);
});

test('missing assets and persistent network failures finish with a bounded attempt count',async()=>{
  let calls=0;
  assert.equal((await download(async()=>{calls++;return new Response(null,{status:404});})).code,404);
  assert.equal(calls,1);calls=0;
  assert.equal((await download(async()=>{calls++;throw Error('offline');})).code,0);
  assert.equal(calls,3);
});
