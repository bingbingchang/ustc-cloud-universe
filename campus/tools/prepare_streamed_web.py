"""Prepare only game runtime resources, never backend .env/models/references."""
import hashlib
import json
import shutil
import os
from pathlib import Path

import argparse
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--templates', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args=parser.parse_args()
PROJECT=Path(__file__).resolve().parents[1]/'godot'
TOOLCHAIN=args.templates.resolve()
OUTPUT=args.output.resolve()
OUTPUT.mkdir(parents=True,exist_ok=True)
manifest=json.loads((PROJECT/'web/regions.json').read_text(encoding='utf-8'))
if manifest.get('terrain_enabled'):
    assert manifest['terrain_sha256']==hashlib.sha256((PROJECT/'data/terrain_height.json').read_bytes()).hexdigest(), 'Terrain changed after region bake; rebake first'
selected={'res://scenes/campus_web.tscn','res://web/regions.json','res://assets/ambient_study_walk.glb'}
selected.add('res://web/region_fetch.js')
selected.add('res://web/engine_assets.js')
selected.add('res://web/text_input.js')
# Bundle spawn-area meshes to avoid hundreds of tiny network round trips.
bootstrap={path for region in ('global','0_0','-1_0') for path in manifest['regions'][region].get('shared',[])}
for path,spec in manifest.get('shared',{}).items():spec['bundled']=path in bootstrap
selected.update(bootstrap)
selected.update(manifest.get('dependencies',[]))
for folder,pattern in [('scripts','*.gd'),('shaders','*'),('assets/textures','*'),('assets/fonts','*'),('assets/music','*.mp3'),('web/npc_animations','*.res'),('data','*.json')]:
    selected.update('res://'+p.relative_to(PROJECT).as_posix() for p in (PROJECT/folder).glob(pattern) if p.is_file() and not p.name.endswith('.import'))
selected.update('res://'+p.relative_to(PROJECT).as_posix() for p in (PROJECT/'assets').glob('npc_*.glb'))
selected.update('res://'+p.relative_to(PROJECT).as_posix() for p in PROJECT.rglob('*.json') if '.godot' not in p.relative_to(PROJECT).parts)
source_hashes={name:hashlib.sha256((PROJECT/name.removeprefix('res://')).read_bytes()).hexdigest()
               for name in sorted(selected|{'res://project.godot'}) if name!='res://web/regions.json'}
normalized={key:value for key,value in manifest.items() if key!='release'}
fingerprint=hashlib.sha256(json.dumps({'resources':source_hashes,'regions':normalized},sort_keys=True).encode()).hexdigest()
manifest['release']='r'+fingerprint[:20]
(PROJECT/'web/regions.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
source_hashes['res://web/regions.json']=hashlib.sha256((PROJECT/'web/regions.json').read_bytes()).hexdigest()
release=OUTPUT/'releases'/manifest['release']
(OUTPUT/'current.json').write_text(json.dumps({'release':manifest['release']}),encoding='utf-8')
(OUTPUT/'input-sha256.json').write_text(json.dumps(source_hashes,indent=2),encoding='utf-8')
(release/'regions').mkdir(parents=True,exist_ok=True)
for key,spec in list(manifest['regions'].items()) + [(Path(key).stem,spec) for key,spec in manifest.get('shared',{}).items()]:
    if spec.get('bundled'):continue
    path=PROJECT/spec['scene'].removeprefix('res://')
    assert hashlib.sha256(path.read_bytes()).hexdigest()==spec['sha256']
    folder='shared' if path.suffix=='.res' else 'regions'
    destination=release/folder/f"{key}.{spec['sha256'][:12]}{path.suffix}"
    destination.parent.mkdir(parents=True,exist_ok=True)
    if destination.exists():continue
    previous=next((OUTPUT/'releases').glob('*/'+folder+'/'+destination.name),None)
    if previous is not None:os.link(previous,destination)
    else:shutil.copy2(path,destination)
presets=PROJECT/'export_presets.cfg'
original=presets.read_text(encoding='utf-8').split('[preset.1]')[0].rstrip()
original=original.replace('exclude_filter=""','exclude_filter="web/*,samples/*,tests/*"')
quote=lambda value:json.dumps(str(value).replace('\\','/'),ensure_ascii=False)
web=f'''

[preset.1]
name="Web Streamed"
platform="Web"
runnable=true
advanced_options=true
dedicated_server=false
custom_features=""
export_filter="resources"
export_files=PackedStringArray({', '.join(map(quote,sorted(selected)))})
include_filter="*.json,*.txt,*.js"
exclude_filter=""
export_path={quote(release/'index.html')}
script_export_mode=1

[preset.1.options]
custom_template/debug={quote(TOOLCHAIN/'web_nothreads_debug.zip')}
custom_template/release={quote(TOOLCHAIN/'web_nothreads_release.zip')}
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
html/export_icon=false
html/custom_html_shell=""
html/head_include="<meta name=\\"viewport\\" content=\\"width=device-width,initial-scale=1,viewport-fit=cover,user-scalable=no\\">"
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=true
progressive_web_app/enabled=false
'''
presets.write_text(original+web,encoding='utf-8')
print(json.dumps({'release':manifest['release'],'output':str(release),'explicit_resources':len(selected),'zones':len(manifest['regions'])},ensure_ascii=False))
