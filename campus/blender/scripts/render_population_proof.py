"""Neutral EEVEE contact proofs using the actual Godot-validated joint matrices."""
import bpy,json
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'renders/population'
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
def pt(v):return Vector((v[0],-v[2],v[1]))
def aim(o,target):o.rotation_euler=(pt(target)-o.location).to_track_quat('-Z','Y').to_euler()
def light(name,pos,target,power,size,color):
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.size=size;d.color=color
 o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.location=pt(pos);aim(o,target)
def box(name,pos,size,material):
 bpy.ops.mesh.primitive_cube_add();o=bpy.context.object;o.name=name;o.location=pt(pos);o.scale=(size[0]/2,size[2]/2,size[1]/2);o.data.materials.append(material)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);m=o.modifiers.new('proof edge','BEVEL');m.width=.012;m.segments=3
def mat(name,color):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85;return m
proofs=[('cyclist','ride','three_quarter'),('cyclist','push','three_quarter'),('bench_reader','read','three_quarter')]
for role,pose in [('photographer','photo'),('study_walk','read')]:
 for angle in ['front','three_quarter','side']:proofs.append((role,pose,angle))
for role,pose,angle in proofs:
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/source'/('ambient_'+role+'.blend')))
 transforms=json.loads((OUT/(role+'_'+pose+'_pose.json')).read_text(encoding='utf-8'))
 for name,tr in transforms.items():
  o=bpy.data.objects.get(name)
  if o is None:continue
  a=tr['basis'];p=tr['origin'];g=Matrix(((a[0][0],a[1][0],a[2][0],p[0]),(a[0][1],a[1][1],a[2][1],p[1]),(a[0][2],a[1][2],a[2][2],p[2]),(0,0,0,1)))
  o.matrix_basis=C@g@C.inverted()
 scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=96
 scene.render.resolution_x=1440;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
 scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX';scene.view_settings.look='None';scene.use_nodes=False
 world=bpy.data.worlds.new('Proof ambient');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.7,.75,.8,1);world.node_tree.nodes['Background'].inputs[1].default_value=.35;scene.world=world
 ground=mat('Proof ground',(.47,.47,.42));y=-.005 if role=='bench_reader' else 0
 box('PROOF Ground',(0,y-.05,0),(200,.1,200),ground)
 if role=='bench_reader':
  wood=mat('PROOF Bench',(.24,.20,.15));metal=mat('PROOF Bench metal',(.18,.24,.23))
  box('PROOF Seat',(0,.49,.05),(1.6,.08,.42),wood);box('PROOF Back',(0,.78,.29),(1.6,.31,.07),wood)
  for x in [-.62,.62]:box('PROOF Bench leg',(x,.20,.05),(.08,.56,.34),metal)
 light('Key',(-3,4,-3),(0,.8,0),500,3,(1,.91,.8));light('Fill',(2,2,-1),(0,.8,0),180,3,(.8,.88,1));light('Rim',(1,3,2),(0,.8,0),250,2,(1,.96,.89))
 d=bpy.data.cameras.new('Proof');d.type='ORTHO';d.ortho_scale=2.2 if role=='cyclist' else 2.05 if role=='bench_reader' else 1.98
 camera=bpy.data.objects.new('Proof',d);bpy.context.collection.objects.link(camera)
 if role in ['cyclist','bench_reader']:
  camera.location=pt((-3,1.85,-3.0) if role=='cyclist' else (-2.4,1.6,-3));aim(camera,(-.15,.83,0) if role=='cyclist' else (0,.62,-.03))
 else:
  camera.location=pt({'front':(0,1.15,-4),'three_quarter':(-2.5,1.3,-3.4),'side':(-4,1.1,0)}[angle]);aim(camera,(0,.77,0))
 scene.camera=camera
 suffix='_blender.png' if role in ['cyclist','bench_reader'] else '_'+angle+'_blender.png'
 scene.render.filepath=str(OUT/(role+'_'+pose+suffix));bpy.ops.render.render(write_still=True)
 print('AMBIENT_RENDER_OK',role,pose,flush=True)
