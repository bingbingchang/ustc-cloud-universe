"""Adapt existing Poly by Google meshes; preserve their geometry and base colour.

Source models are static. This file adds meter scale, a small skin rig and
campus locomotion/idle clips. It does not generate animal geometry.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix
HERE=Path(__file__).resolve().parent
CAMPUS=HERE.parents[1]
OUT=CAMPUS/'godot'/'wildlife'/'assets'
SOURCE=HERE/'source'
FPS=30

def clamp(t):return max(0,min(1,t))

def prepare(name,source,length):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(HERE/'third_party'/source))
    obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
    lo=Vector(tuple(min(v.co[i] for v in obj.data.vertices) for i in range(3)))
    hi=Vector(tuple(max(v.co[i] for v in obj.data.vertices) for i in range(3)))
    scale=length/(hi.y-lo.y)
    # Both selected artists' meshes face Blender -Y. Campus assets face +Y.
    for v in obj.data.vertices:
        v.co=Vector((-v.co.x*scale, -(v.co.y-(hi.y+lo.y)*.5)*scale,(v.co.z-lo.z)*scale))
    obj.name=name+'_Skin'
    if name=='hedgehog':
        # The artist's silhouette stays intact; quill strokes add readable back
        # detail to the originally plain colour patch. Head and paws keep theirs.
        oldmat=obj.data.materials[0]
        oldtex=next(n.image for n in oldmat.node_tree.nodes if n.type=='TEX_IMAGE')
        pixels=list(oldtex.pixels);w,h=oldtex.size
        coat=bpy.data.materials.new('Hedgehog_Quills');coat.use_nodes=True
        bs=coat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.85
        for kind in ['albedo','normal']:
            tex=coat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(OUT/'textures'/('hedgehog_quills_'+kind+'.png')))
            if kind=='albedo':coat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
            else:
                tex.image.colorspace_settings.name='Non-Color';normal=coat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.3
                coat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);coat.node_tree.links.new(normal.outputs['Normal'],bs.inputs['Normal'])
        obj.data.materials.append(coat);uv=obj.data.uv_layers.active
        for p in obj.data.polygons:
            t=uv.data[p.loop_start].uv
            ix=min(w-1,max(0,int(t.x*w)));iy=min(h-1,max(0,int(t.y*h)))
            r,g,b=pixels[(iy*w+ix)*4:(iy*w+ix)*4+3]
            if r>g*1.08 and g>b*1.08:
                p.material_index=1
                for li in p.loop_indices:
                    co=obj.data.vertices[obj.data.loops[li].vertex_index].co
                    uv.data[li].uv=(co.x/.11+.5,co.y/.24+.5)
    # Smooth normals retain the supplied artist silhouette and topology.
    for p in obj.data.polygons:p.use_smooth=True
    obj.data.update()
    print('BOUNDS',name,[(round(min(v.co[i] for v in obj.data.vertices),4),round(max(v.co[i] for v in obj.data.vertices),4)) for i in range(3)])
    arm=bpy.data.armatures.new(name+'_Rig');rig=bpy.data.objects.new(name+'_Rig',arm);bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True);obj.select_set(False);bpy.ops.object.mode_set(mode='EDIT')
    if name=='squirrel_gray':
        root_z=.085;front_y=.087;back_y=-.011;leg_x=.022;head_y=.081;tail_y=-.063;tail_z=.06
    else:
        root_z=.045;front_y=.080;back_y=-.052;leg_x=.034;head_y=.077;tail_y=-.095;tail_z=.04
    def bone(n,a,b,parent=None):
        e=arm.edit_bones.new(n);e.head=a;e.tail=b
        if parent:e.parent=arm.edit_bones[parent]
    bone('Root',(0,0,root_z),(0,0,root_z+.035))
    bone('Head',(0,head_y,root_z),(0,head_y+.035,root_z),'Root')
    if name=='squirrel_gray':bone('Tail',(0,tail_y,tail_z),(0,tail_y-.07,tail_z+.035),'Root')
    for label,y in [('Front',front_y),('Back',back_y)]:
        for side in [-1,1]:
            bone(label+('L' if side<0 else 'R'),(side*leg_x,y,.047 if name=='squirrel_gray' else .028),(side*leg_x,y,.006),'Root')
    bpy.ops.object.mode_set(mode='OBJECT')
    groups={b.name:obj.vertex_groups.new(name=b.name) for b in arm.bones}
    for vertex in obj.data.vertices:
        x,y,z=vertex.co
        tail=clamp((-y-.064)/.028) if name=='squirrel_gray' else 0
        head=clamp((y-head_y+.005)/.025)*(1-tail)
        low=clamp((.049-z)/.021) if name=='squirrel_gray' else clamp((.032-z)/.012)
        label='Front' if y>(front_y+back_y)*.5 else 'Back'
        side='L' if x<0 else 'R'
        # A low nose is still part of the head: never classify it as a paw.
        weights={'Tail':tail,'Head':head*(1-tail),label+side:low*(1-head)*(1-tail),'Root':(1-head)*(1-low)*(1-tail)}
        weights={k:w for k,w in weights.items() if k in groups and w>.0001}
        total=sum(weights.values())
        for k,w in weights.items():groups[k].add([vertex.index],w/total,'REPLACE')
    mod=obj.modifiers.new('Skin','ARMATURE');mod.object=rig;obj.parent=rig
    rig.animation_data_create()
    rig['asset_author']='Poly by Google'
    rig['asset_source']='https://poly.pizza/m/2WqY_AFEn-M' if name=='squirrel_gray' else 'https://poly.pizza/m/8UNni5IvK_c'
    rig['asset_license']='CC BY 3.0 https://creativecommons.org/licenses/by/3.0/'
    rig['asset_changes']='Meter scale, skin rig and campus clips; hedgehog back texture added' if name=='hedgehog' else 'Meter scale, skin rig and campus clips'
    clips=[]
    modes=[('idle',3.5),('walk',.85 if name=='squirrel_gray' else 1.25),('sniff',2.4),('observe',2.4)]
    if name=='squirrel_gray':modes += [('trot',.52),('forage',3.0),('jump',.55)]
    else:modes += [('hide',2.0)]
    for mode,duration in modes:
        action=bpy.data.actions.new(mode);rig.animation_data.action=action
        count=round(duration*FPS)
        for frame in range(count+1):
            u=frame/count;t=u*duration
            for b in rig.pose.bones:b.location=(0,0,0);b.rotation_mode='XYZ';b.rotation_euler=(0,0,0)
            root=rig.pose.bones['Root'];head=rig.pose.bones['Head']
            if mode in ['walk','trot']:
                duty=.63 if mode=='walk' else .5
                stride=.056 if name=='squirrel_gray' else .027
                for label in ['Front','Back']:
                    for s in ['L','R']:
                        phase=(u+(.5 if s=='R' else 0)+(.5 if label=='Back' else 0))%1
                        leg=rig.pose.bones[label+s]
                        if phase<duty:dy=stride*(.5-phase/duty);lift=0
                        else:
                            swing=(phase-duty)/(1-duty);dy=stride*(swing-.5);lift=math.sin(math.pi*swing)*(.010 if name=='squirrel_gray' else .004)
                        leg.location=leg.bone.matrix_local.to_3x3().inverted()@Vector((0,dy,lift))
                if name=='squirrel_gray':rig.pose.bones['Tail'].rotation_euler.z=math.sin(math.tau*u)*.09
            elif mode in ['sniff','forage']:
                head.rotation_euler.x=.12+math.sin(math.tau*u)*.08
                head.rotation_euler.z=math.sin(math.tau*u*2)*.08
            elif mode=='observe':head.rotation_euler.z=math.sin(math.tau*u)*.28
            elif mode=='hide':head.rotation_euler.x=.23*math.sin(math.pi*u)**2
            elif mode=='jump':
                head.rotation_euler.x=-.10*math.sin(math.pi*u)
                for label in ['Front','Back']:
                    for s in ['L','R']:rig.pose.bones[label+s].rotation_euler.x=math.sin(math.pi*u)*.25
            else:
                head.rotation_euler.z=math.sin(math.tau*u)*.025
                if name=='squirrel_gray':rig.pose.bones['Tail'].rotation_euler.z=math.sin(math.tau*u)*.06
            for b in rig.pose.bones:
                b.keyframe_insert('location',frame=frame);b.keyframe_insert('rotation_euler',frame=frame)
        rig.animation_data.action=None
        track=rig.animation_data.nla_tracks.new();track.name=mode;track.strips.new(mode,0,action)
        clips.append(dict(name=mode,seconds=duration,origin='Added campus clips on the supplied static mesh'))
    for im in bpy.data.images:
        if im.source=='FILE':im.pack()
    bpy.context.scene.render.fps=FPS
    bpy.context.scene.frame_set(0)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True,export_extras=True)
    for track in rig.animation_data.nla_tracks:track.mute=True
    rig.animation_data.action=bpy.data.actions.get('idle');bpy.context.scene.frame_set(0)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    return dict(asset=name,source=str(SOURCE/(name+'.blend')),bones=len(arm.bones),triangles=sum(len(p.vertices)-2 for p in obj.data.polygons),clips=clips,meters=True,forward='-Z',up='+Y',root_motion=False,skin='armature',mesh_origin='Poly by Google; existing mesh, unchanged topology',original_file=source,source_page=rig['asset_source'],license=rig['asset_license'],changes=rig['asset_changes'])

reports=[prepare('squirrel_gray','squirrel_e.glb',.36),prepare('hedgehog','hedgehog_google.glb',.24)]
p=OUT/'manifest.json';data=json.loads(p.read_text());changed={r['asset'] for r in reports};data['assets']=[r for r in data['assets'] if r['asset'] not in changed]+reports;data['texture_origin']='First batch original brush textures; second batch reused Poly by Google base colours and added hedgehog quill textures';p.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
print('OPEN_ANIMALS_PREPARED',[(r['asset'],r['triangles']) for r in reports])
