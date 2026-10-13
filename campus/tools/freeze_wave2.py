"""Keep the accepted scene production assets and camera evidence immutable."""
from pathlib import Path
import hashlib, json, shutil
root=Path(__file__).resolve().parents[1]
out=root/'benchmarks/accepted_v0_5';out.mkdir(parents=True,exist_ok=True)
target=out/'manifest.json'
if not target.exists():
    paths=sorted((root/'godot/assets').glob('*.glb'))
    paths+=sorted((root/'godot/shaders').glob('*.gdshader'))
    data={'version':'accepted_v0_5','scope':'Existing GLBs and shader sources before wave2; old actors retained',
          'frozen_sha256':{p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}
    for name in ['01_world.png','02_tiku_preserved.png','09_tiku_uniform_preserved.png','capture_report.json']:
        shutil.copy2(root/'renders/population'/name,out/name)
    target.write_text(json.dumps(data,indent=2),encoding='utf-8')
print(target)
