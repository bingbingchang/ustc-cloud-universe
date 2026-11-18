import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash,webcrypto} from 'node:crypto';
import {gzipSync} from 'node:zlib';
import vm from 'node:vm';
const source=readFileSync(new URL('../godot/web/engine_assets.js',import.meta.url),'utf8');
const origin='https://campus.test',key='releases/test/index.pck',url=origin+'/game/'+key;
const raw=Buffer.from('actual Godot engine package data '.repeat(200));
const compressed=gzipSync(raw),split=Math.floor(compressed.length/2),parts=[compressed.subarray(0,split),compressed.subarray(split)];
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
function fixture({failSecond=false,cacheDisabled=false}={}){
  const rows=new Map(),calls=[0,0],state={failSecond};
  const cache={async match(k){return rows.get(k)?.clone();},async put(k,v){rows.set(k,v);},async keys(){return [...rows.keys()];},async delete(k){return rows.delete(k);}};
  const spec={encoding:'gzip',parts:parts.map((data,i)=>({key:key+'.part00'+i,bytes:data.length,sha256:sha(data)}))};
  const window={location:{href:origin+'/game/releases/test/index.html',origin},DecompressionStream,ReadableStream,caches:{async open(){if(cacheDisabled)throw Error('storage denied');return cache;}},
    fetch:async(input,init)=>{
      if(input===url+'.parts.json')return Response.json(spec);
      const i=spec.parts.findIndex(p=>origin+'/game/'+p.key===input);
      if(i>=0){calls[i]++;if(i===1&&state.failSecond)throw Error('network interrupted');return new Response(parts[i]);}
      return Response.json({path:input,method:init?.method});
    }};
  vm.runInNewContext(source,{window,URL,crypto:webcrypto,Response,ReadableStream,DecompressionStream,Uint8Array,AbortSignal,setTimeout:(fn,ms)=>setTimeout(fn,ms<5000?0:ms)});
  return {window,calls,state,rows};
}
test('part streams decode the exact original engine bytes',async()=>{
  const f=fixture();assert.deepEqual(Buffer.from(await (await f.window.fetch(url)).arrayBuffer()),raw);assert.deepEqual(f.calls,[1,1]);
});
test('interrupted second part resumes from verified first part on re-entry',async()=>{
  const f=fixture({failSecond:true});
  await assert.rejects(async()=>await(await f.window.fetch(url)).arrayBuffer());assert.deepEqual(f.calls,[1,3]);
  f.state.failSecond=false;
  assert.deepEqual(Buffer.from(await(await f.window.fetch(url)).arrayBuffer()),raw);assert.deepEqual(f.calls,[1,4]);
});
test('corrupt cached data is rejected and fetched again',async()=>{
  const f=fixture();f.rows.set(url+'.part000',new Response('corrupt'));
  assert.deepEqual(Buffer.from(await(await f.window.fetch(url)).arrayBuffer()),raw);assert.equal(f.calls[0],1);
});
test('unavailable disk cache does not block the game',async()=>{
  const f=fixture({cacheDisabled:true});assert.deepEqual(Buffer.from(await(await f.window.fetch(url)).arrayBuffer()),raw);
});
test('chat POSTs are passed through once and are never cached',async()=>{
  const f=fixture();const reply=await f.window.fetch(origin+'/api/chat',{method:'POST',body:'hello'});
  assert.deepEqual(await reply.json(),{path:origin+'/api/chat',method:'POST'});assert.equal(f.rows.size,0);
});
