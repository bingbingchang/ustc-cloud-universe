"""Independent OSM-footprint library/Teaching 2 exteriors in absolute campus metres."""
from pathlib import Path
import json,os,sys,bpy,bmesh
script=Path(__file__).resolve()
sys.path.insert(0,str(script.parent))
from mapped_landmark_details import MATERIALS, install_photo_materials
from library_exteriors import FRONTS, LIBRARY_MATERIALS, build_library_front
from visit_exteriors import MATERIALS as VISIT_MATERIALS

helpers=(script.parent/'build_north_teaching.py').read_text(encoding='utf-8').split('# Exact snapshot footprints')[0]
exec(compile(helpers,'existing_campus_geometry_helpers','exec'),globals())
for name,col in [('LibraryTerracotta',(.60,.28,.17)),('LibraryIvory',(.73,.73,.65)),
                 ('OldLibraryPlaster',(.65,.65,.55)),('OldLibraryRedDoor',(.36,.16,.12)),
                 ('Teaching2Brick',(.58,.30,.19)),('CollegePlaster',(.64,.57,.45)),('CampusCanteenWall',(.36,.16,.143))]:
    material(name,col)
install_photo_materials(material,materials,MATERIALS | LIBRARY_MATERIALS | VISIT_MATERIALS)
data=json.loads((ROOT/'godot/data/library_district.json').read_text(encoding='utf-8'))
manifest={'unit':'meter','placement':[0,0,0],'coordinate_system':'Absolute Godot +X east,+Y up,+Z south',
          'buildings':data['buildings'],'collision_solids':solids,'assets':{},
          'sources':[{'local':'references/library_district/library_osm_overlay.jpg','use':'Ground footprints and road adjacency'},
           {'local':'references/buildings/东区图书馆2.jpg','use':'New library terracotta cladding, pale recessed portal and raised entrance'},
           {'local':'references/buildings/teaching_second.jpg','use':'Teaching 2 red brick, dark narrow window frames and tree-lined side'},
           {'url':'https://www.teach.ustc.edu.cn/service/svc-resource/12388.html','use':'Teaching 2 has eight floors'},
           {'url':'https://lib.ustc.edu.cn/本馆概况/东区图书馆简介/','use':'East library has six floors'}],
          'confidence':'Mapped footprints and library/Teaching 2 floor counts. Heights, unphotographed bays and playable vestibule measurements remain approximate.'}
configs=[('284161540','south_old_library','Teaching2Brick',4,14.2),
         ('284161541','south_library','LibraryTerracotta',6,22.0),
         ('271958257','south_teaching2','FacultyPalePanel',8,28.5),
         ('1135310337','south_young_college','Teaching2Brick',4,14.5),
         ('284161542','south_canteen','CampusCanteenWall',3,12.5)]
selected = set(filter(None,os.environ.get('CAMPUS_BUILD_LIBRARY','').split(',')))
unknown = selected - {wid for wid,*_ in configs}
if unknown:
    raise ValueError(f'Unknown library district IDs: {sorted(unknown)}')
if selected:
    manifest = json.loads((ROOT/'godot/assets/library_district_manifest.json').read_text(encoding='utf-8'))
    previous_solids = manifest['collision_solids']

for wid,asset_name,wall,levels,height in configs:
    if selected and wid not in selected:
        continue
    asset = asset_name
    b = next(b for b in data['buildings'] if b['osm_way']==wid)
    oriented = b['outline']
    if signed_area(oriented) < 0:
        raise ValueError(f'Expected positive polygon winding for {wid}')
    edge, photo = FRONTS[wid]
    wings = (14,15,17,18,19) if wid=="284161541" else ()
    p = facade(oriented,levels,height,wall,pitch=3.6,entry_edge=edge,detail_edges=wings,
               interior_storeys=asset == "south_teaching2")
    part = 'PhotoEntrance'
    approach = build_library_front(wid,asset,p,geo,slab,edgebox,inscription,solids)
    registered = next(item for item in manifest['buildings'] if item['osm_way']==wid)
    registered['front_approach'] = [round(v,3) for v in approach]
    registered['gis_photo_point'] = photo

if selected:
    order = dict.fromkeys(name for row in previous_solids for _,name,*_ in configs
                          if row['name'].startswith(name+'_'))
    active = {name for wid,name,*_ in configs if wid in selected}
    manifest['collision_solids'] = [
        row for name in order
        for row in (solids if name in active else previous_solids)
        if row['name'].startswith(name+'_')
    ]
    manifest['confidence'] = 'Mapped footprints and library/Teaching 2 floor counts. Heights, unphotographed bays and playable vestibule measurements remain approximate.'

args.output_dir.mkdir(parents=True, exist_ok=True)
for (asset,part,mat),(vs,fs) in batches.items():
    me=bpy.data.meshes.new(asset+'_'+part+'_'+mat);me.from_pydata(vs,[],fs);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new(asset+'_'+part+'_'+mat,me);bpy.context.collection.objects.link(ob);me.materials.append(materials[mat]);objects.setdefault(asset,[]).append(ob)
for asset,obs in objects.items():
    converted=[]
    for ob in obs:
        if ob.type=='FONT':
            bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH');ob=bpy.context.view_layer.objects.active
        converted.append(ob)
    groups={}
    for ob in converted:groups.setdefault(ob.data.materials[0].name,[]).append(ob)
    merged=[]
    for mat,group in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for ob in group:ob.select_set(True);bpy.context.view_layer.objects.active=ob
        if len(group)>1:bpy.ops.object.join()
        ob=bpy.context.view_layer.objects.active;ob.name=asset+'_'+mat;merged.append(ob)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in merged:ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(args.output_dir/f'{asset}.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
    count=0
    for ob in merged:ob.data.calc_loop_triangles();count+=len(ob.data.loop_triangles)
    manifest['assets'][asset]={'file':asset+'.glb','surfaces':len(merged),'triangles':count}
    print('LIBRARY_ASSET',asset,count)
(args.output_dir/'library_district_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
if not selected and args.output_dir == ROOT/'godot/assets':
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/source/library_district.blend'))
