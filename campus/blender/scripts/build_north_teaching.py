"""Independent north-campus exterior assets from OSM footprints and observed references.

Absolute Godot metres: east X, up Y, south Z; Blender=(X,-Z,Y).
Run D:/productivity/blender.exe -b --python build_north_teaching.py -- --proof
Does not rebuild or modify accepted campus assets, roads, layouts, or gameplay.
"""
from pathlib import Path
import bpy, bmesh, math, json, sys, xml.etree.ElementTree as ET
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'
materials, batches, objects = {}, {}, {}
asset, part = 'Teaching5', 'Structure'
solids = []

def material(name, color, rough=.8, metal=0):
    m=bpy.data.materials.new(name); m.use_nodes=True; m.diffuse_color=(*color,1)
    b=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value=(*color,1)
    b.inputs['Roughness'].default_value=rough; b.inputs['Metallic'].default_value=metal
    materials[name]=m

for name, col, rough, metal in [
    ('Teaching5IvoryTile',(.69,.715,.68),.78,0),
    ('Teaching5TileJoint',(.51,.555,.53),.91,0),
    ('FacultyPalePanel',(.65,.67,.63),.82,0),
    ('FacultyWarmPanel',(.64,.615,.55),.83,0),
    ('FacultyDarkPanel',(.33,.365,.35),.76,0),
    ('FacultyRoof',(.32,.345,.31),.93,0),
    ('EntryStone',(.58,.59,.54),.87,0),
    ('WindowReveal',(.16,.20,.19),.88,0),
    ('WindowGlass',(.145,.225,.23),.27,.18),
    ('WindowGlassLight',(.215,.29,.29),.28,.13),
    ('WindowAluminium',(.56,.61,.59),.36,.55),
    ('WindowRubber',(.12,.16,.15),.63,0),
    ('LetterGold',(.58,.45,.16),.40,.65),
    ('WayfindingBlue',(.055,.19,.34),.7,0),
    ('WayfindingWhite',(.81,.825,.78),.78,0),
    ('EntryHandle',(.58,.62,.6),.30,.72),
]: material(name,col,rough,metal)

def pt(p): return p[0],-p[2],p[1]

def geo(vs,fs,mat):
    v,f=batches.setdefault((asset,part,mat),([],[])); start=len(v)
    v.extend(pt(p) for p in vs); f.extend(tuple(start+i for i in face) for face in fs)

def box(c,s,mat):
    x,y,z=c; dx,dy,dz=[a/2 for a in s]
    geo([(x+a*dx,y+b*dy,z+d*dz) for a,b,d in
         [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
          (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]],
        [(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],mat)

def signed_area(poly):
    return sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1]))/2

def slab(poly,bottom,top,mat):
    n=len(poly); v=[(x,y,z) for y in [bottom,top] for x,z in poly]
    polyv=[Vector(pt((x,top,z))) for x,z in poly]
    triangles=tessellate_polygon([polyv]); topfs=[]
    for tri in triangles:
        idx=[i if isinstance(i,int) else min(range(n),key=lambda j:(polyv[j]-i).length) for i in tri]
        topfs.append(tuple(i+n for i in idx))
    fs=topfs+[tuple(reversed(tuple(i-n for i in f))) for f in topfs]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    geo(v,fs,mat)

def edgebox(a,b,start,end,y0,y1,d0,d1,mat):
    """Box in facade basis; depth positive outside, negative inside building."""
    dx,dz=b[0]-a[0],b[1]-a[1]; length=math.hypot(dx,dz)
    ux,uz=dx/length,dz/length; nx,nz=uz,-ux
    v=[(a[0]+ux*s+nx*d,y,a[1]+uz*s+nz*d)
       for d,y,s in [(d0,y0,start),(d0,y0,end),(d0,y1,end),(d0,y1,start),
                     (d1,y0,start),(d1,y0,end),(d1,y1,end),(d1,y1,start)]]
    geo(v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],mat)

def inscription(body,p,size,mat,heading=0,vertical=False):
    cv=bpy.data.curves.new('Inscription '+body,'FONT'); cv.body=body; cv.size=size
    cv.align_x='CENTER'; cv.align_y='CENTER'; cv.extrude=.008; cv.resolution_u=3
    cv.font=bpy.data.fonts.load('C:/Windows/Fonts/simkai.ttf' if any(ord(c)>255 for c in body) else 'C:/Windows/Fonts/arial.ttf')
    ob=bpy.data.objects.new(asset+'_Letter_'+body,cv); bpy.context.collection.objects.link(ob)
    ob.location=pt(p); ob.rotation_euler=(math.pi/2,0,heading)
    cv.materials.append(materials[mat]); ob['asset']=asset; ob['part']='Signage'
    objects.setdefault(asset,[]).append(ob)
    return ob

def facade(poly,levels,height,wall,pitch=3.8,curtain_edges=()):
    global part
    if signed_area(poly)<0: poly=list(reversed(poly))
    storey=(height-.5)/levels; base=.26
    part='Structure'
    slab(poly,.08,.26,'EntryStone')
    # Physical floor plates and facade piers create actual 22cm window reveals.
    # Glazing is opaque exterior glass because interiors belong to a later pass.
    for floor in range(levels+1):
        y=base+storey*floor
        slab(poly,y,y+.15,'FacultyRoof' if floor==levels else wall)
    part='Facade'
    for e,(a,b) in enumerate(zip(poly,poly[1:]+poly[:1])):
        length=math.dist(a,b)
        if length<1.5:
            edgebox(a,b,0,length,base,height,-.36,.015,wall); continue
        curtain=e in curtain_edges
        if curtain:
            edgebox(a,b,0,length,.30,height-.15,-.25,-.21,'WindowGlassLight')
            for k in range(math.ceil(length/1.38)+1):
                s=min(k*1.38,length)
                edgebox(a,b,max(0,s-.035),min(length,s+.035),.28,height-.12,-.23,.03,'WindowAluminium')
            for floor in range(levels):
                y=base+floor*storey
                for yy,w in [(y+.15,.105),(y+storey*.56,.04)]:
                    edgebox(a,b,0,length,yy,yy+w,-.22,.03,'WindowAluminium')
            continue
        if length<3.2:
            edgebox(a,b,0,length,base,height,-.36,.015,wall); continue
        count=max(1,int(length/pitch)); bay=length/count
        for floor in range(levels):
            y=base+floor*storey
            winbot=y+(1.05 if floor else .84); wintop=y+storey-.56
            edgebox(a,b,0,length,y+.15,winbot,-.36,.015,wall)
            edgebox(a,b,0,length,wintop,y+storey,-.36,.015,wall)
            edgebox(a,b,0,length,y+storey-.08,y+storey+.05,-.40,.11,'Teaching5TileJoint' if asset=='Teaching5' else 'FacultyDarkPanel')
            for k in range(count):
                s0=k*bay; s1=(k+1)*bay; pier=min(.66,bay*.22)
                lo,hi=s0+pier/2,s1-pier/2
                edgebox(a,b,s0,lo,winbot,wintop,-.36,.015,wall)
                edgebox(a,b,hi,s1,winbot,wintop,-.36,.015,wall)
                edgebox(a,b,lo,hi,winbot,wintop,-.245,-.217,'WindowGlassLight' if (k+floor)%7==0 else 'WindowGlass')
                frame='WindowAluminium' if asset=='Teaching5' else 'WindowRubber'
                for s in [lo,(lo+hi)/2,hi]:
                    edgebox(a,b,s-.027,s+.027,winbot,wintop,-.27,-.17,frame)
                edgebox(a,b,lo,hi,winbot,winbot+.065,-.28,.055,'WindowAluminium')
                edgebox(a,b,lo,hi,wintop-.065,wintop,-.28,-.16,frame)
                # Top-hung ventilation transom and return depth are readable on foot.
                edgebox(a,b,lo,hi,wintop-.53,wintop-.49,-.265,-.16,frame)
                for s in [lo,hi]:
                    edgebox(a,b,s-.035,s+.035,winbot,wintop,-.26,.018,'WindowReveal')
        part='Roof'
        edgebox(a,b,0,length,height-.34,height+.40,-.32,.01,wall)
        edgebox(a,b,0,length,height+.38,height+.49,-.38,.09,'Teaching5TileJoint')
        part='Facade'
    solids.append({'name':asset+'_closed_exterior','type':'polygon_prism','polygon':poly,'bottom':.08,'top':height+.5})
    return poly

def entry(a,b,width=8.2,steps=3,caption=''):
    global part
    part='Entrance'
    length=math.dist(a,b); mid=length/2; ux=(b[0]-a[0])/length; uz=(b[1]-a[1])/length
    nx,nz=uz,-ux
    def p(s,y,d): return (a[0]+ux*s+nx*d,y,a[1]+uz*s+nz*d)
    edgebox(a,b,mid-width/2,mid+width/2,.25,4.02,-.31,.10,'WindowReveal')
    edgebox(a,b,mid-width/2+.13,mid+width/2-.13,.43,3.79,-.18,.14,'WindowGlass')
    for s in [mid-width/2,mid-width/4,mid,mid+width/4,mid+width/2]:
        edgebox(a,b,s-.045,s+.045,.40,3.92,-.04,.22,'WindowAluminium')
    edgebox(a,b,mid-width/2,mid+width/2,2.62,2.70,-.02,.23,'WindowAluminium')
    for s in [mid-.16,mid+.16]:
        edgebox(a,b,s-.022,s+.022,1.14,1.86,.20,.27,'EntryHandle')
    edgebox(a,b,mid-width/2-.7,mid+width/2+.7,4.00,4.14,0,2.45,'WindowAluminium')
    edgebox(a,b,mid-width/2-.62,mid+width/2+.62,4.10,4.16,.15,2.38,'WindowGlassLight')
    for k in range(6):
        s=mid-width/2+width*k/5
        edgebox(a,b,s-.055,s+.055,3.79,4.04,.05,2.35,'WindowAluminium')
    for k in range(steps):
        top=.16*(steps-k); d0=.02; d1=1.0+k*.43
        edgebox(a,b,mid-width/2-.72,mid+width/2+.72,.07,top,d0,d1,'EntryStone')
        ps=[p(s,0,d) for s,d in [(mid-width/2-.72,d0),(mid+width/2+.72,d0),
                                 (mid+width/2+.72,d1),(mid-width/2-.72,d1)]]
        solids.append({'name':asset+'_entry_step_'+str(k),'type':'polygon_prism',
                       'polygon':[[v[0],v[2]] for v in ps],'bottom':.07,'top':top})
    if caption:
        edgebox(a,b,mid-width/2,mid+width/2,4.30,4.92,.06,.17,'FacultyDarkPanel')
        inscription(caption,p(mid,4.62,.19),.48,'WayfindingWhite',heading=math.atan2(nx,nz))
    return p(mid,.1,4.5)

# Exact snapshot footprints transformed using the existing site's tangent plane.
site=json.loads((ROOT/'godot/assets/site.json').read_text(encoding='utf-8'))
origin=site['origin_wgs84']; angle=site['south_rotation_radians']
doc=ET.parse(ROOT/'renders/coverage/osm_east_full.xml').getroot()
nodes={n.get('id'):n for n in doc.findall('node')}; ways={w.get('id'):w for w in doc.findall('way')}
def footprint(id):
    pts=[]
    for nd in ways[str(id)].findall('nd'):
        n=nodes[nd.get('ref')]; x=(float(n.get('lon'))-origin[0])*94500; z=(origin[1]-float(n.get('lat')))*111195
        pts.append([round(x*math.cos(angle)-z*math.sin(angle),3),round(x*math.sin(angle)+z*math.cos(angle),3)])
    if pts[0]==pts[-1]: pts=pts[:-1]
    if signed_area(pts)<0: pts.reverse()
    return pts

definitions=[
    ('Teaching5',265575547,'第五教学楼（王璞楼）',5,21.30,'Teaching5IvoryTile',3.55),
    ('TeachingAdministration',270537512,'教学行政楼（地空学院）',16,63.80,'FacultyPalePanel',3.5),
    ('ManagementResearch',270537513,'管理科学教学科研楼',16,64.40,'FacultyWarmPanel',3.55),
    ('ManagementMBA',270537514,'管理学院MBA中心',4,16.10,'FacultyPalePanel',3.6),
]
building_records=[]
for asset,id,name,floors,height,wall,pitch in definitions:
    poly=footprint(id)
    curtain=[]
    # Observed west-facing entrance curtain wall on teaching five's bent end.
    if asset=='Teaching5':
        for e,(a,b) in enumerate(zip(poly,poly[1:]+poly[:1])):
            if min(a[0],b[0])<180 and 10<math.dist(a,b)<16: curtain.append(e)
    facade(poly,floors,height,wall,pitch,curtain)
    if asset=='Teaching5':
        a,b=[208.627,6.633],[190.045,5.615]
        spawn=entry(a,b,11.8,3)
        # White tile wall and gold vertical inscription observed in Baidu Maps photograph.
        part='Entrance'
        edgebox(a,b,13.15,17.9,.27,height-.18,-.38,.20,wall)
        ux,uz=(b[0]-a[0])/math.dist(a,b),(b[1]-a[1])/math.dist(a,b)
        for s in [13.15,15.53,17.9]: edgebox(a,b,s-.01,s+.01,.28,height-.18,.20,.208,'Teaching5TileJoint')
        for y in range(1,21,2): edgebox(a,b,13.15,17.9,y,y+.015,.20,.208,'Teaching5TileJoint')
        for char,y in zip('王璞楼',[12.3,10.0,7.7]):
            s=15.50; p=(a[0]+ux*s+uz*.22,y,a[1]+uz*s-ux*.22)
            inscription(char,p,1.18,'LetterGold',heading=math.atan2(uz,-ux))
        part='Roof'
        for x,z,w,d in [(194.5,-8,8,6),(242,-7,8,7),(271,-3,7,5)]:
            box((x,height+.82,z),(w,1.65,d),'Teaching5IvoryTile')
            box((x,height+1.68,z),(w+.25,.13,d+.25),'FacultyRoof')
    elif asset=='TeachingAdministration':
        spawn=entry([178.569,-39.486],[160.820,-43.921],9.8,3,'教学行政楼')
    elif asset=='ManagementResearch':
        spawn=entry([297.553,-34.144],[281.716,-32.593],9.6,3,'管理科研楼')
    else:
        spawn=entry([234.387,-36.983],[229.679,-38.014],3.8,2,'MBA 中心')
    if asset!='Teaching5':
        part='Roof'
        cx=sum(p[0] for p in poly)/len(poly); cz=sum(p[1] for p in poly)/len(poly)
        box((cx,height+1.4,cz-2.4),(13,2.8,7),'FacultyDarkPanel')
        box((cx,height+2.87,cz-2.4),(13.35,.18,7.4),'FacultyRoof')
        for i in range(5):
            box((cx-15.5+i*6.5,height+.54,cz),(2.8,.85,2.8),'WindowAluminium')
        for e,(a,b) in enumerate(zip(poly,poly[1:]+poly[:1])):
            if math.dist(a,b)>15:
                edgebox(a,b,0,math.dist(a,b),height-1.28,height-.98,-.38,.085,'FacultyDarkPanel')
    building_records.append({'asset':asset,'name':name,'osm_way_id':id,'polygon':poly,
                             'levels':floors,'roof_height_m':height,'front_approach':list(spawn),
                             'footprint_area_m2':round(abs(signed_area(poly)),2)})

# Merge disconnected detail by material and building, keeping nearby buildings
# individually cullable. Each asset has 8-12 surfaces instead of per-window nodes.
for (asset,part,mat),(vs,fs) in batches.items():
    me=bpy.data.meshes.new(asset+'_'+part+'_'+mat); me.from_pydata(vs,[],fs); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=bm.faces); bm.to_mesh(me); bm.free()
    ob=bpy.data.objects.new(asset+'_'+part+'_'+mat,me); bpy.context.collection.objects.link(ob)
    me.materials.append(materials[mat]); ob['asset']=asset; ob['part']=part
    objects.setdefault(asset,[]).append(ob)
for asset in objects:
    converted=[]
    for ob in objects[asset]:
        if ob.type=='FONT':
            bpy.ops.object.select_all(action='DESELECT');ob.select_set(True)
            bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH')
            ob=bpy.context.view_layer.objects.active
        converted.append(ob)
    material_objects={}
    for ob in converted:material_objects.setdefault(ob.data.materials[0].name,[]).append(ob)
    combined=[]
    for mat,obs in sorted(material_objects.items()):
        bpy.ops.object.select_all(action='DESELECT')
        for ob in obs:
            ob.select_set(True); bpy.context.view_layer.objects.active=ob
        if len(obs)>1: bpy.ops.object.join()
        ob=bpy.context.view_layer.objects.active; ob.name=asset+'_'+mat; combined.append(ob)
    objects[asset]=combined

manifest={
    'unit':'meter','coordinate_system':'Absolute Godot +X east,+Y up,+Z south; Blender=(x,-z,y)',
    'placement':[0,0,0],'origin_wgs84':origin,'south_rotation_radians':angle,
    'source_osm':'renders/coverage/osm_east_full.xml','buildings':building_records,
    'observed_sources':[
        {'url':'https://www.teach.ustc.edu.cn/service/svc-resource/12388.html','claim':'Teaching five has five floors'},
        {'url':'https://en.ustc.edu.cn/Dictionary.htm','claim':'第五教学楼（王璞楼） landmark name'},
        {'url':'https://map.baidu.com/place/9d869de78b9635fd344aae90',
         'image':'https://taojin-his.cdn.bcebos.com/30adcbef76094b3656895f55a9cc7cd98d109d6b.jpg',
         'local':'references/buildings/teaching5_front.jpg',
         'observed':'White tile wall, full-height fine aluminium curtain entry, vertical gold 王璞楼, glass canopy, three steps'},
        {'local':'references/maps/east_campus.png','claim':'Teaching administrative and management buildings north of teaching five; new north gate northwest'},
        {'local':'references/road_network/north_roads_satellite.jpg','claim':'Roof outlines, paired long high blocks, segmented teaching five roof'},
        {'url':'https://ess.ustc.edu.cn/main.htm','claim':'Earth/Space faculty address is teaching administration building'},
        {'url':'https://essetc.ustc.edu.cn/zxgk/list.htm','claim':'Laboratories at teaching administration floors 8 and 16'},
        {'url':'https://faculty.ustc.edu.cn/caichen/zh_CN/article/1021455/content/5480.htm','claim':'Management research room 1607 establishes at least 16 floors'},
        {'url':'https://www.ezhujianpt.com/project/list_0_0_121013_1213_36.html',
         'claim':'2019 facade renovation listing: teaching administration 16 floors,63.8m; management research 16 floors,64.4m'}
    ],
    'confidence':'Plan polygons and relative placement from OSM, corroborated by official campus plan and public satellite imagery. Teaching-five entry treatment photographed. Teaching-five height21.3m estimated from5 floors. Faculty exact facade bay sizes, panel tone, roofs and entry arrangement are exterior modelling approximations; MBA4-floor height is estimated. No fabricated college name attached to an unrelated building.',
    'collision_solids':solids,'assets':{},
}
for filename,names in [('north_teaching5.glb',['Teaching5']),
                       ('north_faculty_blocks.glb',['TeachingAdministration','ManagementResearch','ManagementMBA'])]:
    obs=[ob for a in names for ob in objects[a]]
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs: ob.select_set(True)
    dest=ROOT/'godot/assets'/filename
    bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,
                              export_apply=True,export_yup=True,export_extras=True)
    verts=[ob.matrix_world@v.co for ob in obs for v in ob.data.vertices]
    triangles=0
    for ob in obs: ob.data.calc_loop_triangles(); triangles+=len(ob.data.loop_triangles)
    lo=[min(v[i] for v in verts) for i in range(3)]; hi=[max(v[i] for v in verts) for i in range(3)]
    manifest['assets'][filename]={'file':'godot/assets/'+filename,'buildings':names,
                                'objects':len(obs),'triangles':triangles,
                                'bounds_min':[lo[0],lo[2],-hi[1]],'bounds_max':[hi[0],hi[2],-lo[1]]}
(ROOT/'godot/assets/north_teaching_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/source/north_teaching_extension.blend'))
print('NORTH_TEACHING_OK',json.dumps(manifest['assets'],ensure_ascii=False))

if '--proof' in sys.argv:
    scene=bpy.context.scene; scene.render.engine='BLENDER_EEVEE'
    scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='AgX'
    world=bpy.data.worlds.new('North proof daylight');world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.65,.76,.85,1);bg.inputs[1].default_value=.65
    scene.world=world
    ld=bpy.data.lights.new('North proof sun','SUN');ld.energy=2.5;ld.angle=.08
    sun=bpy.data.objects.new('North proof sun',ld);bpy.context.collection.objects.link(sun);sun.rotation_euler=(.43,-.23,-.4)
    bpy.ops.mesh.primitive_plane_add(size=500,location=(220,20,.04));ground=bpy.context.object
    ground.data.materials.append(materials['EntryStone'])
    cd=bpy.data.cameras.new('North proof camera');camera=bpy.data.objects.new('North proof camera',cd)
    bpy.context.collection.objects.link(camera);scene.camera=camera
    out=ROOT/'renders/north_teaching_extension';out.mkdir(parents=True,exist_ok=True)
    for filename,pos,target,lens,show in [
        ('01_teaching5',(145,45,95),(224,10,-4),44,['Teaching5']),
        ('02_entry',(183,5.4,35),(199,7.6,5.8),40,['Teaching5']),
        ('03_faculty',(160,80,120),(230,26,-44),40,['TeachingAdministration','ManagementResearch','ManagementMBA']),
        ('04_all',(112,125,155),(237,18,-24),38,list(objects)),
    ]:
        for a,obs in objects.items():
            for ob in obs: ob.hide_render=a not in show
        camera.location=pt(pos);camera.rotation_euler=(Vector(pt(target))-camera.location).to_track_quat('-Z','Y').to_euler();cd.lens=lens
        scene.render.filepath=str(out/(filename+'.png'));bpy.ops.render.render(write_still=True)
    print('NORTH_TEACHING_PROOFS_OK')
