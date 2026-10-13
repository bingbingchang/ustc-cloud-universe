"""Neutral contact proofs; production Godot bone matrices, not invented poses.
Run only while the shared GPU is available. Requires wave2_mascot_contact.gd first.
"""
from pathlib import Path
import json, sys
import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'renders/wave2'
C = Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))

def pt(v):
    return Vector((v[0],-v[2],v[1]))

def aim(obj, target):
    obj.rotation_euler = (pt(target)-obj.location).to_track_quat('-Z','Y').to_euler()

def light(name, position, target, power, size, color):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size;data.color=color
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
    obj.location=pt(position);aim(obj,target)

for role, pose in [('meituan','order'),('meituan','open'),('doubao','point'),('leaf_cat','paw')]:
    if '--only-doubao' in sys.argv and role!='doubao':
        continue
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/source'/('wave2_'+role+'.blend')))
    transforms=json.loads((OUT/(role+'_'+pose+'_pose.json')).read_text(encoding='utf-8'))
    for name, tr in transforms.items():
        obj=bpy.data.objects.get(name)
        if obj is None:
            raise RuntimeError('Godot proof pivot missing from Blender: '+name)
        a=tr['basis'];p=tr['origin']
        matrix=Matrix(((a[0][0],a[1][0],a[2][0],p[0]),(a[0][1],a[1][1],a[2][1],p[1]),(a[0][2],a[1][2],a[2][2],p[2]),(0,0,0,1)))
        obj.matrix_basis=C@matrix@C.inverted()
    scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=80
    scene.render.resolution_x=1600;scene.render.resolution_y=1400;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX';scene.view_settings.look='None';scene.use_nodes=False
    world=bpy.data.worlds.new('Neutral proof ambient');world.use_nodes=True
    world.node_tree.nodes.clear()
    background=world.node_tree.nodes.new('ShaderNodeBackground')
    output=world.node_tree.nodes.new('ShaderNodeOutputWorld')
    world.node_tree.links.new(background.outputs['Background'],output.inputs['Surface'])
    background.inputs[0].default_value=(.70,.75,.80,1)
    background.inputs[1].default_value=.35;scene.world=world
    ground=bpy.data.materials.new('Proof ground');ground.use_nodes=True
    ground.node_tree.nodes.clear();bsdf=ground.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
    material_output=ground.node_tree.nodes.new('ShaderNodeOutputMaterial')
    ground.node_tree.links.new(bsdf.outputs['BSDF'],material_output.inputs['Surface'])
    bsdf.inputs['Base Color'].default_value=(.47,.47,.42,1)
    bsdf.inputs['Roughness'].default_value=.85
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.002));bpy.context.object.data.materials.append(ground)
    target=(.15,.74,0) if role=='meituan' else (0,.56,-.025) if role=='doubao' else (0,.25,-.08)
    light('Key',(-3,4,-3),target,500,3,(1,.91,.8));light('Fill',(2,2,-1),target,180,3,(.8,.88,1));light('Rim',(1,3,2),target,250,2,(1,.96,.89))
    data=bpy.data.cameras.new('Contact proof');data.type='ORTHO';data.ortho_scale=1.96 if role=='meituan' else 1.4 if role=='doubao' else .95
    camera=bpy.data.objects.new('Contact proof',data);bpy.context.collection.objects.link(camera)
    camera.location=pt((2.6,2.0,-3.6) if role=='meituan' else (-2.5,1.5,-3.4) if role=='doubao' else (1.3,.95,-1.8));aim(camera,target);scene.camera=camera
    scene.render.filepath=str(OUT/(role+'_'+pose+'_blender.png'));bpy.ops.render.render(write_still=True)
    print('MASCOT_CONTACT_PROOF',role,pose,flush=True)
