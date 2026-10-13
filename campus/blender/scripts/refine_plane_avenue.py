"""Blend stem/root/scaffold junctions in Blender while retaining construction meshes."""
import json
import runpy
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

CAMPUS = Path(__file__).resolve().parents[2]
SOURCE = CAMPUS / 'blender/avenue_study'
OUTPUT = CAMPUS / 'renders/plane_avenue'
OUTPUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
helper = runpy.run_path(str(CAMPUS/'references/threejs_road/original/campus_plane_tree_sample/blender/import_sample.py'))
visual = bpy.data.collections.new('Avenue_Editable_Visual')
bpy.context.scene.collection.children.link(visual)
created = helper['import_to_collection'](SOURCE/'assets/plane_avenue_master.glb', visual)
collision = bpy.data.collections.new('Avenue_Collision_Proxies')
bpy.context.scene.collection.children.link(collision)
for ob in helper['import_to_collection'](SOURCE/'assets/plane_avenue_collision.glb', collision):
    ob.hide_render = True
    ob.hide_set(True)
    ob.display_type = 'WIRE'

def refine_scaffold(tree):
    originals = [o for o in tree.children_recursive if o.type=='MESH' and
                 o.name.startswith(('Trunk_', 'Root_', 'Branch_Primary_'))]
    points, faces, source_uvs, face_materials, materials = [], [], [], [], []
    # Cache the original texture coordinates before remeshing. Textures remain unchanged.
    for ob in originals:
        ob.data.calc_loop_triangles()
        uv = ob.data.uv_layers.active.data
        for tri in ob.data.loop_triangles:
            base = len(points)
            points.extend(ob.matrix_world @ ob.data.vertices[v].co for v in tri.vertices)
            faces.append((base,base+1,base+2))
            source_uvs.append([Vector((uv[l].uv.x,uv[l].uv.y,0)) for l in tri.loops])
            material=ob.data.materials[tri.material_index]
            if material not in materials:
                materials.append(material)
            face_materials.append(materials.index(material))
    nearest = BVHTree.FromPolygons(points,faces,all_triangles=True)
    bpy.ops.object.select_all(action='DESELECT')
    copies=[]
    for ob in originals:
        duplicate=ob.copy()
        duplicate.data=ob.data.copy()
        # The source tubes have an open bottom and duplicate vertices along the UV seam.
        # Make the volume closed before voxel union; UV transfer still uses the originals.
        topology=bmesh.new()
        topology.from_mesh(duplicate.data)
        bmesh.ops.remove_doubles(topology,verts=list(topology.verts),dist=.00001)
        boundary=[edge for edge in topology.edges if edge.is_boundary]
        bmesh.ops.holes_fill(topology,edges=boundary,sides=0)
        bmesh.ops.recalc_face_normals(topology,faces=list(topology.faces))
        topology.to_mesh(duplicate.data)
        topology.free()
        duplicate.parent=None
        duplicate.matrix_world=ob.matrix_world.copy()
        visual.objects.link(duplicate)
        duplicate.select_set(True)
        copies.append(duplicate)
    bpy.context.view_layer.objects.active=copies[0]
    bpy.ops.object.join()
    fused=copies[0]
    fused.name='ContinuousScaffold_'+tree.name.removeprefix('PlaneTree_')
    remesh=fused.modifiers.new('Organic_Junctions','REMESH')
    remesh.mode='VOXEL'
    remesh.voxel_size=.065
    remesh.use_smooth_shade=True
    remesh.use_remove_disconnected=False
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth=fused.modifiers.new('Gentle_Surface_Smoothing','SMOOTH')
    smooth.factor=.22
    smooth.iterations=2
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    decimate=fused.modifiers.new('Scaffold_Surface_Budget','DECIMATE')
    decimate.ratio=.75
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    mesh=fused.data
    mesh.materials.clear()
    for material in materials:
        mesh.materials.append(material)
    while mesh.uv_layers:
        mesh.uv_layers.remove(mesh.uv_layers[0])
    target_uv=mesh.uv_layers.new(name='Transferred_Original_UV').data
    for attr in list(mesh.color_attributes):
        mesh.color_attributes.remove(attr)
    colors=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
    mesh.color_attributes.active_color=colors
    for vertex in mesh.vertices:
        height=(fused.matrix_world @ vertex.co).z-.135
        ao=.86+.14*max(0,min(1,height/.8))
        colors.data[vertex.index].color=(ao,ao,ao,1)
    for polygon in mesh.polygons:
        center=fused.matrix_world @ polygon.center
        hit=nearest.find_nearest(center)
        triangle=hit[2]
        a,b,c=(points[v] for v in faces[triangle])
        u,v,w=source_uvs[triangle]
        polygon.material_index=face_materials[triangle]
        polygon.use_smooth=True
        for loop_index in polygon.loop_indices:
            p=fused.matrix_world @ mesh.vertices[mesh.loops[loop_index].vertex_index].co
            coordinate=barycentric_transform(p,a,b,c,u,v,w)
            target_uv[loop_index].uv=(coordinate.x,coordinate.y)
    matrix=fused.matrix_world.copy()
    fused.parent=tree
    fused.matrix_world=matrix
    fused['refinement']='Voxel union of original roots, trunk and primary scaffolds; original UVs projected back.'
    for ob in originals:
        ob['construction_source']=True
        ob.hide_render=True
        ob.hide_set(True)
    mesh.calc_loop_triangles()
    return {'tree':tree.name,'construction_meshes':len(originals),'refined_triangles':len(mesh.loop_triangles)}

trees=[o for o in created if o.name.startswith('PlaneTree_') and o.type=='EMPTY']
report={'trees':[refine_scaffold(tree) for tree in trees]}
runtime=[o for o in visual.objects if not o.get('construction_source')]
for ob in bpy.context.selected_objects:
    ob.select_set(False)
for ob in runtime:
    ob.select_set(True)
target=CAMPUS/'godot/samples/plane_avenue/assets/plane_avenue.glb'
target.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,
                          export_cameras=False,export_lights=False)
report['runtime_meshes']=sum(o.type=='MESH' for o in runtime)
report['packed_images']=sum(bool(i.packed_file) for i in bpy.data.images)
report['refined_glb']=str(target)
report['design']=json.loads((SOURCE/'manifest.json').read_text(encoding='utf-8'))

scene=bpy.context.scene
scene.name='Plane_Avenue_50m'
scene.unit_settings.system='METRIC'
stage=bpy.data.collections.new('Presentation_Only')
scene.collection.children.link(stage)
helper['import_to_collection'](SOURCE/'preview/presentation_stage.glb',stage)
def aim(ob,target):
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new('Soft_Studio')
world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.70,.74,.68,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.65
scene.world=world
for name,power,position,tint in [('Warm_Sun',2.1,(-12,-12.5,23),(1,.94,.80)),('Cool_Fill',.22,(10,9,8),(.84,.89,.95))]:
    data=bpy.data.lights.new(name,'SUN')
    data.energy=power
    data.color=tint
    data.angle=.07
    light=bpy.data.objects.new(name,data)
    stage.objects.link(light)
    light.location=position
    aim(light,(0,0,3.5))
camera=bpy.data.objects.new('Avenue_Review_Camera',bpy.data.cameras.new('Avenue_Review_Camera'))
stage.objects.link(camera)
camera.data.lens=44
camera.location=(34,-46,32)
aim(camera,(0,0,4.8))
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
preferences=bpy.context.preferences.addons['cycles'].preferences
preferences.compute_device_type='OPTIX'
preferences.get_devices()
for device in preferences.devices:
    device.use=device.type=='OPTIX'
scene.cycles.device='GPU'
scene.render.resolution_x,scene.render.resolution_y=1600,1000
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.view_settings.exposure=.35
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUTPUT/'blender_overview.png')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA'
blend=CAMPUS/'blender/source/plane_avenue_50m.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
report['blend']=str(blend)
(OUTPUT/'build.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.render.render(write_still=True)
