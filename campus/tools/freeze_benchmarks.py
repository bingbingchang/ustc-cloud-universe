"""Freeze accepted evidence once. Never regenerate the accepted character here."""
from pathlib import Path
import hashlib, json, shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'benchmarks/accepted_v0_4'
OUT.mkdir(parents=True, exist_ok=True)
manifest = OUT / 'manifest.json'
if manifest.exists():
    print('Accepted benchmark already frozen:', manifest)
else:
    sources = [
        ('renders/tiku_identity/01_front.png', 'tiku_front.png', 'accepted character / actual Godot'),
        ('renders/tiku_identity/08_study.png', 'tiku_study.png', 'accepted character / actual Godot'),
        ('renders/tiku_identity/15_roadside_thinking.png', 'tiku_roadside.png', 'accepted uniform variant / actual Godot'),
        ('renders/life/hero_01.png', 'environment_ortho.png', 'historical environment baseline, predates final hero'),
        ('renders/life/photo_spots.json', 'photo_spots.json', 'fixed existing camera definitions'),
    ]
    images = []
    for source, dest, scope in sources:
        p = ROOT / source
        if not p.exists():
            raise FileNotFoundError(p)
        shutil.copy2(p, OUT / dest)
        images.append(dict(source=source, file=dest, scope=scope))
    frozen = [
        'godot/assets/tiku_boy1.glb', 'godot/assets/tiku_boy1_uniform.glb',
        'blender/scripts/build_tiku.py', 'blender/scripts/tiku_head.py',
        'godot/scripts/tiku_actor.gd', 'godot/shaders/tiku_face.gdshader',
        'godot/shaders/tiku_cloth.gdshader', 'godot/assets/textures/tiku_face_albedo.png',
    ]
    hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in frozen}
    manifest.write_text(json.dumps(dict(version='accepted_v0_4', scope='User accepted Tiku; expansion must preserve these files', images=images, frozen_sha256=hashes), ensure_ascii=False, indent=2), encoding='utf-8')
    print('Frozen:', manifest)
