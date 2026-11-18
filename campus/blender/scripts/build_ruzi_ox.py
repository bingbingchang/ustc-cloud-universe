"""Ruzi Ox and globe from the USTC GIS photographs, in local sculpture metres."""

from pathlib import Path
import bpy
from mathutils import Vector

prefix=(Path(__file__).parent/"build_north_teaching.py").read_text(encoding="utf-8").split("# Exact snapshot footprints")[0]
exec(compile(prefix,"campus_metric_export","exec"),globals())

material("PhotoRuziStone",(.455,.44,.384),.85,0)
material("PhotoRuziGranite",(.31,.308,.274),.87,0)
stone=materials["PhotoRuziStone"]
asset="RuziOx"


def rounded(name, center, scale, angle=0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=14,location=pt(center))
    obj=bpy.context.object
    obj.name=name
    obj.scale=(scale[0],scale[2],scale[1])
    obj.rotation_euler.y=angle
    obj.data.materials.append(stone)
    for polygon in obj.data.polygons:
        polygon.use_smooth=True
    return obj


def between(name, a, b, width, depth):
    direction=Vector(pt(b))-Vector(pt(a))
    c=tuple((u+v)*.5 for u,v in zip(a,b))
    obj=rounded(name,c,(width,direction.length*.64,depth))
    obj.rotation_euler=direction.to_track_quat("Z","Y").to_euler()
    return obj


body=[
    rounded("Torso",(.02,1.40,.04),(1.47,.42,.65),-.045),
    rounded("Shoulder",(-.86,1.48,.06),(.69,.52,.65),.08),
    rounded("Haunch",(.99,1.40,.04),(.64,.46,.57)),
    between("Bent neck",(-.76,1.64,0),(-1.54,1.33,.12),.43,.46),
    between("Head",(-1.49,1.50,.09),(-1.98,1.30,.21),.40,.36),
    rounded("Broad muzzle",(-2.02,1.26,.24),(.33,.235,.39),-.14),
    between("Front folded leg",(-.80,1.27,.34),(-1.65,1.06,.63),.25,.25),
    between("Front hoof",(-1.65,1.06,.63),(-1.89,1.05,.64),.22,.23),
    between("Rear folded leg",(.76,1.40,.36),(1.32,1.10,.66),.36,.29),
    between("Rear hoof", (1.31,1.10,.66),(.83,1.045,.83),.18,.20),
    between("Tail", (1.48,1.32,-.13),(1.63,1.10,.34),.12,.10),
]
for side in (-1,1):
    z=.095+side*.32
    body.append(between("Ear",(-1.53,1.62,z),(-1.43,1.64,z+side*.26),.114,.11))
    tip=(-1.68,1.86,z+side*.135)
    body.append(between("Horn",(-1.56,1.61,z),tip,.123,.12))
    body.append(between("Horn tip",tip,(-1.78,1.94,z+side*.17),.077,.071))
body.append(rounded("Folded opposite leg",(.25,1.16,-.35),(.72,.21,.25)))

bpy.ops.object.select_all(action="DESELECT")
for obj in body:
    obj.select_set(True)
bpy.context.view_layer.objects.active=body[0]
bpy.ops.object.join()
sculpt=bpy.context.object
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
union=sculpt.modifiers.new("Continuous carved stone","REMESH")
union.mode="VOXEL"
union.voxel_size=.033
union.use_smooth_shade=True
bpy.ops.object.modifier_apply(modifier=union.name)
soften=sculpt.modifiers.new("Stone carving relief","SMOOTH")
soften.factor=.75
soften.iterations=4
bpy.ops.object.modifier_apply(modifier=soften.name)
sculpt.name="RuziOxCarving"
globe=rounded("Celestial sphere",(.23,2.18,-.16),(.91,.91,.91))

part="Plinth"
box((0,.045,0),(5.04,.09,3.22),"PhotoRuziGranite")
box((0,.449,0),(4.76,.79,2.96),"PhotoRuziGranite")
box((0,.874,0),(4.94,.166,3.09),"PhotoRuziStone")
for x in range(11):
    for side in (-1,1):
        box((-2.17+x*.435,.45,side*1.482),(.048,.70,.028),"PhotoRuziStone")
for z in range(7):
    for side in (-1,1):
        box((side*2.379,.45,-1.30+z*.433),(.025,.70,.047),"PhotoRuziStone")

bpy.ops.object.select_all(action="DESELECT")
sculpt.select_set(True)
globe.select_set(True)
for (_asset, _part, finish),(verts,faces) in batches.items():
    mesh=bpy.data.meshes.new(finish)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(finish,mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(materials[finish])
    obj.select_set(True)
args.output_dir.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(args.output_dir/"ruzi_ox.glb"),export_format="GLB",use_selection=True,export_yup=True)
