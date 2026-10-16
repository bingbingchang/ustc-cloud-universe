"""Render downloaded artist meshes as-is for selecting the second batch."""
import bpy,json,sys,math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
OUT=HERE.parents[1]/'renders'/'wildlife'
OUT.mkdir(exist_ok=True,parents=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
report=[]
for index,name in enumerate(['squirrel_a','squirrel_d','squirrel_e','hedgehog_google','hedgehog_quaternius']):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(HERE/'third_party'/(name+'.glb')))
    objects=list(set(bpy.data.objects)-before)
    for o in objects:
        if o.animation_data:
            o.animation_data.action=None
            for track in o.animation_data.nla_tracks:track.mute=True
    meshes=[o for o in objects if o.type=='MESH']
    pts=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
    lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
    report.append(dict(name=name,bounds=[list(lo),list(hi)],meshes=[dict(name=o.name,vertices=len(o.data.vertices),materials=[m.name for m in o.data.materials]) for o in meshes],bones=[b.name for o in objects if o.type=='ARMATURE' for b in o.data.bones]))
    parent=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(parent)
    for o in objects:
        if o.parent is None:o.parent=parent
    scale=1.15/max(hi-lo)
    parent.scale=(scale,)*3
    parent.location=Vector(((index%3-1)*1.65,(index//3)*-1.8,0))-Vector(((lo.x+hi.x)*.5,(lo.y+hi.y)*.5,lo.z))*scale
    bpy.ops.object.text_add(location=((index%3-1)*1.65-.55,(index//3)*-1.8-.72,.01),rotation=(0,0,0))
    text=bpy.context.object;text.data.body=name;text.data.size=.12
    text.data.align_x='LEFT'
    mat=bpy.data.materials.get('Label') or bpy.data.materials.new('Label');mat.diffuse_color=(.06,.08,.08,1);text.data.materials.append(mat)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.008))
ground=bpy.context.object;mat=bpy.data.materials.new('Ground');mat.diffuse_color=(.65,.69,.60,1);ground.data.materials.append(mat)
def light(loc,power,size):
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,-.8,.4))-o.location).to_track_quat('-Z','Y').to_euler()
light((1,-4,7),1300,6);light((-4,2,5),900,6)
bpy.ops.object.camera_add(location=(4,-7,6));cam=bpy.context.object;cam.rotation_euler=(Vector((0,-.9,.4))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=6.7
s=bpy.context.scene;s.camera=cam;s.render.engine='CYCLES';s.cycles.samples=20;s.cycles.use_denoising=True;s.world.color=(.5,.5,.5);s.render.resolution_x=1600;s.render.resolution_y=1000;s.render.resolution_percentage=100;s.view_settings.view_transform='AgX';s.render.filepath=str(OUT/'open_asset_candidates.png');bpy.ops.render.render(write_still=True)
(OUT/'open_asset_inspection.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
