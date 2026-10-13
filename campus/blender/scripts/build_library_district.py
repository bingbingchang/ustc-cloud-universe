"""Independent OSM-footprint library/Teaching 2 exteriors in absolute campus metres."""
from pathlib import Path
import json,math,sys,bpy,bmesh
script=Path(__file__).resolve()
helpers=(script.parent/'build_north_teaching.py').read_text(encoding='utf-8').split('# Exact snapshot footprints')[0]
exec(compile(helpers,'existing_campus_geometry_helpers','exec'),globals())
for name,col in [('LibraryTerracotta',(.60,.28,.17)),('LibraryIvory',(.73,.73,.65)),
                 ('OldLibraryPlaster',(.65,.65,.55)),('OldLibraryRedDoor',(.36,.16,.12)),
                 ('Teaching2Brick',(.58,.30,.19)),('CollegePlaster',(.64,.57,.45)),('CanteenPlaster',(.59,.61,.55))]:
    material(name,col)
data=json.loads((ROOT/'godot/data/library_district.json').read_text(encoding='utf-8'))
manifest={'unit':'meter','placement':[0,0,0],'coordinate_system':'Absolute Godot +X east,+Y up,+Z south',
          'buildings':data['buildings'],'collision_solids':solids,'assets':{},
          'sources':[{'local':'references/library_district/library_osm_overlay.jpg','use':'Ground footprints and road adjacency'},
           {'local':'references/buildings/东区图书馆2.jpg','use':'New library terracotta cladding, pale recessed portal and raised entrance'},
           {'local':'references/buildings/teaching_second.jpg','use':'Teaching 2 red brick, dark narrow window frames and tree-lined side'},
           {'url':'https://www.teach.ustc.edu.cn/service/svc-resource/12388.html','use':'Teaching 2 has eight floors'},
           {'url':'https://lib.ustc.edu.cn/本馆概况/东区图书馆简介/','use':'East library has six floors'}],
          'confidence':'Mapped ground plans and library/Teaching 2 floor counts; other heights, entrances and unsighted facade bays are approximate. No interior access.'}
configs=[('284161540','south_old_library','OldLibraryPlaster',4,14.2),
         ('284161541','south_library','LibraryTerracotta',6,22.0),
         ('271958257','south_teaching2','Teaching2Brick',8,28.5),
         ('1135310337','south_young_college','CollegePlaster',4,14.5),
         ('284161542','south_canteen','CanteenPlaster',3,12.5)]
for wid,asset_name,wall,levels,height in configs:
    asset=asset_name;part='Structure'
    b=next(b for b in data['buildings'] if b['osm_way']==wid)
    p=facade(b['outline'],levels,height,wall,pitch=3.6)
    if wid=='284161540':
        # Old-library approach is the mapped axis at x≈0, ending at the north recess.
        a,bp=next((a,bp) for a,bp in zip(p,p[1:]+p[:1]) if min(a[0],bp[0])<0<max(a[0],bp[0]) and 367<a[1]<373)
        approach=entry(a,bp,9.0,3,'办公楼 · 老图书馆')
        inscription('老图书馆',(approach[0],5.1,approach[2]-4.42),.72,'LetterGold',heading=math.pi)
    elif wid=='284161541':
        # South entrance faces the open forecourt and Ruziniu Road; the north joins the old wing.
        center=(2.1,430.0);part='LibraryPortal'
        box((center[0],7.4,center[1]+.36),(18.5,14.8,.65),'LibraryIvory')
        box((center[0],7.0,center[1]+.76),(13.5,11.8,.25),'WindowReveal')
        box((center[0],7.0,center[1]+.92),(12.9,11.3,.18),'WindowGlass')
        for x in [-6.0,-3.0,0,3.0,6.0]:box((center[0]+x,7.0,center[1]+1.06),(.07,11.4,.12),'WindowAluminium')
        for y in [4.0,7.0,10.0,12.5]:box((center[0],y,center[1]+1.06),(12.9,.07,.12),'WindowAluminium')
        for x in [-7.0,7.0]:box((center[0]+x,7.15,center[1]+1.15),(1.0,12.1,1.1),'LibraryIvory')
        for z in [431.1,431.7,432.3]:box((center[0],13.2,z),(14.6,.18,.15),'WindowAluminium')
        inscription('图 书 馆',(center[0],14.1,center[1]+.735),1.2,'LetterGold')
        # Low outer tread rises to an exterior landing at the second-floor portal.
        for k in range(20):
            top=.16*(20-k);z0=430.6;z1=431.1+k*.28
            box((center[0],top/2,(z0+z1)/2),(10.2,top,z1-z0),'EntryStone')
            solids.append({'name':asset+'_entry_step_'+str(k),'type':'polygon_prism',
               'polygon':[[center[0]-5.1,z0],[center[0]+5.1,z0],[center[0]+5.1,z1],[center[0]-5.1,z1]],'bottom':0,'top':top})
        for side in [-1,1]:
            for k in range(11):
                z=431.0+k*.55;y=3.8-(z-431.0)*.55
                box((center[0]+side*5.28,y-.40,z),(.07,.8,.07),'WindowAluminium')
            # Continuous sloping handrail represented by a mesh box along its axis.
            start=Vector(pt((center[0]+side*5.28,4.1,430.9)));end=Vector(pt((center[0]+side*5.28,1.0,436.4)))
            bpy.ops.mesh.primitive_cube_add(size=1,location=(start+end)/2);ob=bpy.context.object
            ob.rotation_euler=(end-start).to_track_quat('Z','Y').to_euler();ob.scale=(.055,.055,(end-start).length);ob.data.materials.append(materials['WindowAluminium']);objects.setdefault(asset,[]).append(ob)
        approach=(center[0],.1,437.2)
    elif wid=='271958257':
        # The known red-brick building has a south court reachable from the west path.
        a,bp=max(zip(p,p[1:]+p[:1]),key=lambda ab:(ab[0][1]+ab[1][1])*.5 if math.dist(*ab)>12 else -1000)
        approach=entry(a,bp,8.0,3,'第二教学楼')
    else:
        candidates=[(a,bp) for a,bp in zip(p,p[1:]+p[:1]) if math.dist(a,bp)>9 and abs(a[1]-bp[1])<2]
        a,bp=min(candidates,key=lambda ab:(ab[0][1]+ab[1][1])*.5)
        approach=entry(a,bp,5.0,3,'少年班学院' if wid=='1135310337' else '东区学生食堂')
    manifest['buildings'][[b['osm_way'] for b in manifest['buildings']].index(wid)]['front_approach']=list(approach)

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
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets'/f'{asset}.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
    count=0
    for ob in merged:ob.data.calc_loop_triangles();count+=len(ob.data.loop_triangles)
    manifest['assets'][asset]={'file':asset+'.glb','surfaces':len(merged),'triangles':count}
    print('LIBRARY_ASSET',asset,count)
(ROOT/'godot/assets/library_district_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/source/library_district.blend'))
