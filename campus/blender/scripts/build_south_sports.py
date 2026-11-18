"""Build only the new southern court equipment and mapped building exteriors."""
from pathlib import Path
import bpy,bmesh,json,math,sys
script=Path(__file__).resolve()
sys.path.insert(0,str(script.parent))
from mapped_landmark_details import MATERIALS, install_photo_materials
from science_exteriors import SCIENCE_MATERIALS
from sports_exteriors import SOUTH_PHOTO, SPORTS_MATERIALS, add_exterior
helpers=(script.parent/'build_north_teaching.py').read_text(encoding='utf-8').split('# Exact snapshot footprints')[0]
exec(compile(helpers,'campus_exterior_helpers','exec'),globals())
for name,col in [('SouthDormPlaster',(.69,.70,.65)),('HumanitiesWarmBrick',(.50,.24,.15)),
                 ('SportsHallIvory',(.70,.71,.65)),('SolarLabBrick',(.54,.26,.15)),
                 ('ServicePlaster',(.70,.67,.56)),('BalconyRail',(.40,.48,.44)),
                 ('CourtFrame',(.09,.27,.20)),('BasketBackboard',(.76,.81,.77)),
                 ('BasketRed',(.66,.18,.06)),('CourtNet',(.63,.67,.60))]:material(name,col)
for palette in (MATERIALS,SCIENCE_MATERIALS,SPORTS_MATERIALS):
    install_photo_materials(material,materials,palette)
data=json.loads((ROOT/'godot/data/south_sports.json').read_text(encoding='utf-8'))
manifest={'unit':'meter','placement':[0,0,0],'buildings':data['buildings'],'assets':{},'collision_solids':solids,
          'sources':data['sources'],'confidence':'Mapped outlines; GIS building color/massing and official balconies/tennis references. Unseen facade bays, storeys and doorway details approximated.'}

def tube(a,b,r,mat,n=8):
    a,b=Vector(a),Vector(b);u=(b-a).normalized();ref=Vector((0,1,0)) if abs(u.y)<.9 else Vector((1,0,0))
    v=u.cross(ref).normalized();w=u.cross(v).normalized()
    vs=[tuple(p+r*(v*math.cos(k*math.tau/n)+w*math.sin(k*math.tau/n))) for p in [a,b] for k in range(n)]
    geo(vs,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)],mat)

for b in data['buildings']:
    wid=b['osm_way'];asset='south_dorm364_365' if wid=='271959068' else ('south_badminton_hall' if wid=='271959067' else 'south_service_buildings')
    if signed_area(b["outline"])<0:
        b["outline"].reverse()
    wall='SouthDormPlaster' if wid=='271959068' else ('HumanitiesWarmBrick' if wid=='1135310336' else ('SolarLabBrick' if wid=='1135310342' else ('SportsHallIvory' if wid=='271959067' else 'ServicePlaster')))
    if wid in SOUTH_PHOTO:
        part='PhotoExterior'
        b['front_approach']=list(add_exterior(asset,b,geo,slab,edgebox,inscription,solids,facade))
        continue
    p=facade(b['outline'],b['levels'],b['height'],wall,pitch=3.15 if wid=='271959068' else 3.6)
    edges=[(a,c) for a,c in zip(p,p[1:]+p[:1]) if math.dist(a,c)>7 and abs(a[1]-c[1])<2]
    a,c=(min if wid in ['1135310342','271958264'] else max)(edges,key=lambda e:(e[0][1]+e[1][1])/2)
    approach=entry(a,c,3.4 if wid=='271958265' else 4.5,2,b['name'])
    b['front_approach']=list(approach)

asset='south_court_equipment';part='BasketballHoops'
for court in data['courts']:
    x,z=court['center'];w,l=court['width'],court['length']
    if court['sport']=='basketball':
        for side in [-1,1]:
            baseline=z+side*l/2;post=baseline+side*1.03;ring_z=baseline-side*1.15
            tube((x,.12,post),(x,3.80,post),.11,'CourtFrame',10)
            tube((x,3.60,post),(x,3.60,baseline-side*.64),.075,'CourtFrame')
            box((x,3.58,baseline-side*.72),(1.8,1.05,.075),'BasketBackboard')
            # Target rectangle on the front of the board.
            for xx in [-.295,.295]:box((x+xx,3.40,baseline-side*.775),(.026,.45,.01),'BasketRed')
            for yy in [3.175,3.625]:box((x,yy,baseline-side*.775),(.59,.026,.01),'BasketRed')
            for k in range(24):
                a=math.tau*k/24;b=math.tau*(k+1)/24
                tube((x+.225*math.cos(a),3.05,ring_z+.225*math.sin(a)),(x+.225*math.cos(b),3.05,ring_z+.225*math.sin(b)),.017,'BasketRed',6)
            for k in range(12):
                a=math.tau*k/12;tube((x+.225*math.cos(a),3.03,ring_z+.225*math.sin(a)),(x+.11*math.cos(a+.3),2.65,ring_z+.11*math.sin(a+.3)),.008,'CourtNet',4)
            poly=[[x-.15,post-.15],[x+.15,post-.15],[x+.15,post+.15],[x-.15,post+.15]]
            solids.append({'name':court['id']+'_hoop_'+str(side),'polygon':poly,'bottom':.1,'top':3.8})
    else:
        part='TennisPosts';a=court['heading']
        def p(dx,y,dz=0):return (x+dx*math.cos(a)+dz*math.sin(a),y,z-dx*math.sin(a)+dz*math.cos(a))
        for side in [-1,1]:
            q=p(side*(w/2+.91),.1);tube(q,p(side*(w/2+.91),1.20),.045,'CourtFrame')
            solids.append({'name':court['id']+'_net_post_'+str(side),'polygon':[[q[0]-.07,q[2]-.07],[q[0]+.07,q[2]-.07],[q[0]+.07,q[2]+.07],[q[0]-.07,q[2]+.07]],'bottom':.1,'top':1.2})
        for k in range(32):
            dx=-w/2-.8+k*(w+1.6)/31;y=.99+.16*abs(dx)/(w/2+.8)
            tube(p(dx,.18),p(dx,y),.007,'CourtNet',4)
        for k in range(6):tube(p(-w/2-.8,.18+k*.16),p(w/2+.8,.18+k*.16),.007,'CourtNet',4)
        tube(p(-w/2-.91,1.16),p(0,.99),.020,'CourtNet',6);tube(p(0,.99),p(w/2+.91,1.16),.020,'CourtNet',6)

for (asset,part,mat),(vs,fs) in batches.items():
    me=bpy.data.meshes.new(asset+'_'+part+'_'+mat);me.from_pydata(vs,[],fs);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new(asset+'_'+part+'_'+mat,me);bpy.context.collection.objects.link(ob);me.materials.append(materials[mat]);objects.setdefault(asset,[]).append(ob)
for asset,obs in objects.items():
    groups={}
    for ob in obs:
        if ob.type=='FONT':
            bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH');ob=bpy.context.view_layer.objects.active
        groups.setdefault(ob.data.materials[0].name,[]).append(ob)
    merged=[]
    for mat,group in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for ob in group:ob.select_set(True);bpy.context.view_layer.objects.active=ob
        if len(group)>1:bpy.ops.object.join()
        ob=bpy.context.view_layer.objects.active;ob.name=asset+'_'+mat;merged.append(ob)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in merged:ob.select_set(True)
    args.output_dir.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(args.output_dir/f'{asset}.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
    count=0
    for ob in merged:ob.data.calc_loop_triangles();count+=len(ob.data.loop_triangles)
    manifest['assets'][asset]={'file':asset+'.glb','surfaces':len(merged),'triangles':count};print('SOUTH_ASSET',asset,count)
(args.output_dir/'south_sports_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
if args.output_dir==ROOT/'godot/assets':
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/source/south_sports.blend'))
