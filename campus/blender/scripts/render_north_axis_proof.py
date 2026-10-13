"""Render existing north-axis source without exporting/replacing production GLBs."""
import bpy,math,textwrap
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(R/'blender/source/north_axis_architecture.blend'))
M={m.name:m for m in bpy.data.materials}
asset_objects={}
for o in bpy.context.scene.objects:
 if o.get('asset_group'):asset_objects.setdefault(o['asset_group'],[]).append(o)
def pt(p):return(p[0],-p[2],p[1])
out=R/'renders/north_axis'
script=(Path(__file__).with_name('build_north_axis.py')).read_text(encoding='utf-8').split("if '--proof' in sys.argv:\n",1)[1]
exec(compile(textwrap.dedent(script),'north_axis_proof_only','exec'),globals())
