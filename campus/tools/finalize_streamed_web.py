"""Create reproducible HTTP-compressed engine assets and a private upload list."""
import gzip
import hashlib
import json
import shutil
import os
from pathlib import Path

import argparse
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args=parser.parse_args()
BUILD=args.output.resolve()
PROJECT=Path(__file__).resolve().parents[1]/'godot'
for name,expected in json.loads((BUILD/'input-sha256.json').read_text(encoding='utf-8')).items():
    actual=hashlib.sha256((PROJECT/name.removeprefix('res://')).read_bytes()).hexdigest()
    if actual!=expected:raise SystemExit('Source changed during Web export; rebuild before publishing: '+name)
info=json.loads((BUILD/'current.json').read_text(encoding='utf-8'))
release=BUILD/'releases'/info['release']
html=release/'index.html'
page=html.read_text(encoding='utf-8')
shutil.copy2(PROJECT/'web/engine_assets.js',release/'engine-assets.js')
if '<script src="engine-assets.js"></script>' not in page:
    page=page.replace('<script src="index.js"></script>','<script src="engine-assets.js"></script>\n<script src="index.js"></script>')
if 'GODOT_CONFIG.experimentalVK = window.CampusMobileKeyboard' not in page:
    page=page.replace('const engine = new Engine(GODOT_CONFIG);','GODOT_CONFIG.experimentalVK = window.CampusMobileKeyboard === true;\nconst engine = new Engine(GODOT_CONFIG);')
if "type:'campus-load'" not in page:
    page=page.replace("'onProgress': function (current, total) {", "'onProgress': function (current, total) {\n window.parent.postMessage({type:'campus-load',stage:'engine',text:total>0?'正在下载游戏 '+Math.round(current/Math.max(total,1)*100)+'%':'正在准备游戏引擎…',progress:total>0?current/total:-1},window.location.origin);")
    page=page.replace('function displayFailureNotice(err) {', "function displayFailureNotice(err) {\n window.parent.postMessage({type:'campus-load',stage:'engine-error',text:'游戏初始化失败，请检查网络后重新进入。',progress:-1},window.location.origin);")
assert "type:'campus-load'" in page, 'Engine progress integration missing'
html.write_text(page,encoding='utf-8')
regions=json.loads((PROJECT/'web/regions.json').read_text(encoding='utf-8'))
compressed=BUILD/'compressed'/info['release'];compressed.mkdir(parents=True,exist_ok=True)
entries=[]
for path in sorted(release.rglob('*')):
    if not path.is_file():continue
    relative=path.relative_to(release).as_posix()
    source=path;encoding=None
    if path.suffix in ('.wasm','.pck','.js','.html'):
        source=compressed/(relative+'.gz');source.parent.mkdir(parents=True,exist_ok=True)
        with path.open('rb') as incoming, source.open('wb') as output:
            with gzip.GzipFile(fileobj=output,mode='wb',filename='',mtime=0,compresslevel=6) as zipped:
                shutil.copyfileobj(incoming,zipped)
        encoding='gzip'
    entries.append({'key':f"releases/{info['release']}/{relative}",'file':str(source.resolve()),'encoding':encoding,
                    'bytes':source.stat().st_size,'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
(BUILD/'upload-manifest.json').write_text(json.dumps({'release':info['release'],'entries':entries},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'files':len(entries),'total_bytes':sum(row['bytes'] for row in entries),
                  'largest':max(row['bytes'] for row in entries),'initial_engine_bytes':sum(row['bytes'] for row in entries if '/regions/' not in row['key'])}))
