"""New Huangshan Road north gate only; old north gate is never reused.
Reference: USTC news description and two geolocated 2022 photographs.
Run Blender -b --python build_north_gate.py -- --proof.
"""
from pathlib import Path
import bpy,bmesh,math,json,random,sys
from mathutils import Vector

SCRIPT=Path(__file__).resolve()
prefix=(SCRIPT.parent/'build_north_teaching.py').read_text(encoding='utf-8').split('# Exact snapshot footprints')[0]
exec(compile(prefix,'north_teaching_geometry_helpers','exec'),globals())
asset,part='NewNorthGate','Gate'
GATE=(111.927,-71.737)
# The OSM college-ring road leaves the gate eastward along z~-71.5. Keep its
# 6m asphalt and 1.5m sidewalks clear by placing entry fixtures on its north edge.
# The gate node remains fixed; only side equipment and fence returns are offset.
FIXTURE_NORTH_OFFSET=6.75
random.seed(2022)
for name,color,rough,metal in [
    ('GateSteel',(.49,.52,.50),.45,.62),('GateGlass',(.20,.31,.32),.28,.28),
    ('GateDarkGlass',(.14,.22,.23),.38,.18),('GateGreyStone',(.40,.395,.34),.99,0),
    ('GateStoneLetter',(.29,.12,.09),.88,0),('GateCanopy',(.33,.36,.33),.68,.25),
    ('GateVineGreen',(.21,.32,.12),.95,0),('GateVineLight',(.30,.39,.18),.95,0),
    ('GateVineStem',(.25,.20,.15),.96,0),('GateBarrierWhite',(.72,.74,.69),.69,0),
    ('GateBarrierRed',(.55,.11,.075),.64,0),
]:material(name,color,rough,metal)

def prism_collision(name,poly,bottom,top):
    solids.append({'name':name,'type':'polygon_prism','polygon':poly,'bottom':bottom,'top':top})
def rect_collision(name,x,z,w,d,h):
    prism_collision(name,[[x-w/2,z-d/2],[x+w/2,z-d/2],[x+w/2,z+d/2],[x-w/2,z+d/2]],.08,h)
def ellipse(cx,cz,rx,rz,n=24):
    return [[cx+rx*math.cos(i*math.tau/n),cz+rz*math.sin(i*math.tau/n)] for i in range(n)]

# Cylindrical stainless/glass guard booth and layered flat roof are visible in
# the 2022 north-gate photograph. It stands outside the playable central road.
cx,cz=GATE[0]+8.2,GATE[1]-.2
part='GuardBooth'
poly=ellipse(cx,cz,1.23,1.12)
slab(poly,.08,.24,'GateSteel');slab(poly,.24,.99,'GateSteel')
slab(poly,.99,2.54,'GateDarkGlass');slab(poly,2.54,2.72,'GateSteel')
slab(ellipse(cx,cz,1.40,1.28),2.73,2.86,'GateSteel')
slab(ellipse(cx,cz,1.35,1.23),2.88,2.98,'GateBarrierWhite')
slab(ellipse(cx,cz,1.43,1.30),2.99,3.08,'GateSteel')
for i in range(16):
    t=math.tau*i/16
    box((cx+1.24*math.cos(t),1.75,cz+1.13*math.sin(t)),(.055,1.56,.055),'GateSteel')
# Dark framed door on its southern face.
box((cx,1.42,cz+1.124),(.75,2.36,.06),'WindowRubber')
box((cx,1.43,cz+1.164),(.63,2.22,.035),'GateGlass')
box((cx+.23,1.34,cz+1.20),(.03,.34,.035),'EntryHandle')
prism_collision('NewNorthGate_guard_booth',poly,.08,3.08)

# Electric gate is represented folded to one side. No rail or barrier spans
# the central 7m vehicle route or the western pedestrian gap.
part='RetractedGate'
mx,mz=GATE[0]+5.8,GATE[1]
box((mx,.76,mz),(.58,1.37,.70),'GateSteel')
box((mx,1.18,mz+.355),(.32,.25,.025),'GateDarkGlass')
rect_collision('NewNorthGate_gate_motor',mx,mz,.60,.72,1.47)
for i in range(7):
    x=GATE[0]+6.2+i*.17
    box((x,.72,mz),(.032,1.22,.67),'GateSteel')
    box((x,.47,mz+.42),(.045,.04,.83),'GateSteel')
    box((x,1.12,mz+.42),(.045,.04,.83),'GateSteel')
rect_collision('NewNorthGate_folded_gate',GATE[0]+6.71,mz+.20,1.29,1.03,1.4)
# Raised entry barrier arm, as found at practical contemporary campus entries.
box((GATE[0]+5.30,2.19,mz+.68),(.105,3.78,.11),'GateBarrierWhite')
for y in [.7,1.6,2.5,3.4]: box((GATE[0]+5.30,y,mz+.68),(.11,.32,.115),'GateBarrierRed')
rect_collision('NewNorthGate_raised_barrier_base',GATE[0]+5.30,mz+.68,.32,.34,.70)

# The university name is carved into a low broad irregular stone, rather than
# invented as an arch. Photo2 shows a sloping crown with creeping vines.
part='NameStone'
sx,sz=GATE[0]+16.25,GATE[1]+1.45
outline=[[-4.0,-.87],[-4.14,.18],[-3.05,1.06],[-.9,1.22],[2.8,1.08],[4.03,.48],[4.06,-.42],[2.43,-1.05],[-.60,-1.20]]
poly=[[sx+x,sz+z] for x,z in outline]
vs=[]
for x,z in outline:
    # Taper broad stone towards an uneven top and flatten its photographed face.
    vs.append((sx+x,.13,sz+z))
for i,(x,z) in enumerate(outline):
    y=[2.38,2.10,3.03,4.05,3.96,3.14,3.15,3.88,3.76][i]
    vs.append((sx+x*.88,y,sz+z*.82))
n=len(outline)
fs=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
geo(vs,fs,'GateGreyStone')
prism_collision('NewNorthGate_name_stone',poly,.08,4.06)
inscription('中国科学技术大学',(sx,1.76,sz-1.21),.67,'GateStoneLetter',heading=math.pi)
inscription('University of Science and Technology of China',(sx,1.11,sz-1.215),.175,'GateStoneLetter',heading=math.pi)
# Disconnected low-poly ivy leaves, concentrated along crown and sides; these
# are gate details, not replacements for the surrounding tree landscape.
for i in range(96):
    x=random.uniform(-3.65,3.65); y=random.uniform(.7,3.6)
    if abs(x)<2.9 and 1.0<y<2.35: continue
    z=sz-1.24+(abs(x)/4)*.18; size=random.uniform(.09,.18)
    geo([(sx+x-size,y,z),(sx+x,y+size*.82,z-.025),(sx+x+size,y,z),
         (sx+x,y-size,z+.015),(sx+x,y,z-.045)],
        [(0,1,4),(1,2,4),(2,3,4),(3,0,4)],'GateVineGreen' if i%3 else 'GateVineLight')
for x in [-3.35,-2.7,2.75,3.15]:
    box((sx+x,1.7,sz-1.20),(.018,2.65,.025),'GateVineStem')

# Fence returns outside both passage areas.
part='FenceReturns'
for x0,x1 in [(GATE[0]-20,GATE[0]-8),(GATE[0]+22,GATE[0]+29)]:
    box(((x0+x1)/2,.56,GATE[1]),(x1-x0,.97,.24),'EntryStone')
    box(((x0+x1)/2,1.28,GATE[1]),(x1-x0,.065,.085),'GateSteel')
    for i in range(int(x1-x0)+1):
        box((x0+i,1.14,GATE[1]),(.07,1.55,.08),'GateSteel')
    rect_collision('NewNorthGate_fence_return_'+str(int(x0)),(x0+x1)/2,GATE[1],x1-x0,.24,1.85)

for (asset,part,mat),(vs,fs) in batches.items():
    # Batch coordinates are already Blender (x,-z,y), so north offset raises Y.
    vs=[(x,y+FIXTURE_NORTH_OFFSET,z) for x,y,z in vs]
    me=bpy.data.meshes.new(asset+'_'+part+'_'+mat);me.from_pydata(vs,[],fs);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new(asset+'_'+part+'_'+mat,me);bpy.context.collection.objects.link(ob);me.materials.append(materials[mat])
    objects.setdefault(asset,[]).append(ob)
for ob in objects['NewNorthGate']:
    if ob.type=='FONT':ob.location.y+=FIXTURE_NORTH_OFFSET
for solid in solids:
    solid['polygon']=[[x,z-FIXTURE_NORTH_OFFSET] for x,z in solid['polygon']]
converted=[]
for ob in objects['NewNorthGate']:
    if ob.type=='FONT':
        bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
        bpy.ops.object.convert(target='MESH');ob=bpy.context.view_layer.objects.active
    converted.append(ob)
matgroups={}
for ob in converted:matgroups.setdefault(ob.data.materials[0].name,[]).append(ob)
combined=[]
for mat,obs in sorted(matgroups.items()):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs:ob.select_set(True);bpy.context.view_layer.objects.active=ob
    if len(obs)>1:bpy.ops.object.join()
    ob=bpy.context.view_layer.objects.active;ob.name='NewNorthGate_'+mat;combined.append(ob)
bpy.ops.object.select_all(action='DESELECT')
for ob in combined:ob.select_set(True)
dest=ROOT/'godot/assets/north_gate.glb'
bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_extras=True)
verts=[ob.matrix_world@v.co for ob in combined for v in ob.data.vertices]
triangles=0
for ob in combined:ob.data.calc_loop_triangles();triangles+=len(ob.data.loop_triangles)
lo=[min(v[i] for v in verts) for i in range(3)];hi=[max(v[i] for v in verts) for i in range(3)]
gate_record={'name':'东区新北门（黄山路）','osm_node_id':2755623225,'center':list(GATE),
             'placement':[0,0,0],'central_open_route_width_m':7.0,
             'fixture_north_offset_m':FIXTURE_NORTH_OFFSET,
             'eastward_ring_road_clear_width_m':9.0,
             'western_pedestrian_gap_x':[GATE[0]-7.8,GATE[0]-3.6],
             'confidence':'Known electric gate, cylindrical guard booth and broad rough vine-covered name stone from photographs. Individual dimensions and side-object positions approximated. Side fixtures lie north of the mapped college-ring road, leaving its 6m road plus 1.5m sidewalks clear; original gate node is unchanged.'}
sources=[{'url':'https://news.ustc.edu.cn/info/1056/68537.htm','claim':'New Huangshan north gate is electric gate and university name stone; separate from old north arch'},
         {'url':'https://commons.wikimedia.org/wiki/File:The_North_Gate_of_East_University_of_Science_and_Technology_of_China_1.jpg',
          'local':'references/buildings/new_northgate_2022.jpg','photographer':'深鸣','date':'2022-09-10',
          'observed':'Cylindrical metallic guard booth with horizontal layered roof, practical entry equipment, large rough stone; photo used for shape reference only'},
         {'url':'https://commons.wikimedia.org/wiki/File:The_North_Gate_of_East_University_of_Science_and_Technology_of_China_2.jpg',
          'local':'references/buildings/new_northgate_inside_2022.jpg','photographer':'深鸣','date':'2022-09-10',
          'observed':'Vine-covered stone, reddish Chinese inscription and small English line; photo used for shape reference only'}]
mp=ROOT/'godot/assets/north_teaching_manifest.json'
manifest=json.loads(mp.read_text(encoding='utf-8'))
manifest['gates']=[gate_record]
manifest['collision_solids']=[s for s in manifest['collision_solids'] if not s['name'].startswith('NewNorthGate_')]+solids
manifest['observed_sources']=[s for s in manifest['observed_sources'] if 'New Huangshan' not in s.get('claim','') and 'new_northgate' not in s.get('local','')]+sources
manifest['assets']['north_gate.glb']={'file':'godot/assets/north_gate.glb','buildings':['NewNorthGate'],
                                   'objects':len(combined),'triangles':triangles,
                                   'bounds_min':[lo[0],lo[2],-hi[1]],'bounds_max':[hi[0],hi[2],-lo[1]]}
mp.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/source/north_gate.blend'))
print('NORTH_GATE_OK',json.dumps(manifest['assets']['north_gate.glb']))
if '--proof' in sys.argv:
    scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1200;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX';world=bpy.data.worlds.new('Gate proof sky');world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.65,.76,.83,1);bg.inputs[1].default_value=.65;scene.world=world
    ld=bpy.data.lights.new('Gate sun','SUN');ld.energy=2.8;ld.angle=.08;sun=bpy.data.objects.new('Gate sun',ld)
    bpy.context.collection.objects.link(sun);sun.rotation_euler=(.45,-.25,-.4)
    bpy.ops.mesh.primitive_plane_add(size=160,location=(GATE[0],-GATE[1],.04));bpy.context.object.data.materials.append(materials['EntryStone'])
    cd=bpy.data.cameras.new('Gate proof');co=bpy.data.objects.new('Gate proof',cd);bpy.context.collection.objects.link(co);scene.camera=co
    co.location=pt((GATE[0]-4,7,GATE[1]-31));co.rotation_euler=(Vector(pt((GATE[0]+7,1.8,GATE[1])))-co.location).to_track_quat('-Z','Y').to_euler();cd.lens=37
    out=ROOT/'renders/north_teaching_extension';out.mkdir(parents=True,exist_ok=True);scene.render.filepath=str(out/'05_new_north_gate.png');bpy.ops.render.render(write_still=True)
    print('NORTH_GATE_PROOF_OK')
