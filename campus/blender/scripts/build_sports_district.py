"""Independent mapped dormitory, grandstand and football-equipment assets."""
from pathlib import Path
import json,math,bpy,bmesh
script=Path(__file__).resolve()
helpers=(script.parent/'build_north_teaching.py').read_text(encoding='utf-8').split('# Exact snapshot footprints')[0]
exec(compile(helpers,'campus_exterior_helpers','exec'),globals())
for name,col in [('DormCream',(.74,.71,.61)),('DormPale',(.72,.73,.66)),
                 ('DormOchre',(.68,.64,.51)),('StandConcrete',(.57,.61,.59)),
                 ('StandTrim',(.63,.48,.17)),('SeatMutedGold',(.60,.53,.25)),
                 ('SportsSteel',(.55,.62,.60)),('GoalWhite',(.83,.85,.79)),
                 ('NetCord',(.59,.65,.58)),('AirConditioner',(.62,.65,.61))]:material(name,col)
data=json.loads((ROOT/'godot/data/sports_district.json').read_text(encoding='utf-8'))
manifest={'unit':'meter','placement':[0,0,0],'buildings':data['buildings'],
          'assets':{},'collision_solids':solids,'sources':data['sources'],
          'confidence':'Mapped building outlines; official historic field/grandstand photographs and satellite proportions. Current entrance details and unseen facades approximated.'}

def tube(a,b,r,mat,n=8):
    a,b=Vector(a),Vector(b);u=(b-a).normalized()
    ref=Vector((0,1,0)) if abs(u.y)<.9 else Vector((1,0,0))
    v=u.cross(ref).normalized();w=u.cross(v).normalized()
    vs=[tuple(p+r*(v*math.cos(k*math.tau/n)+w*math.sin(k*math.tau/n))) for p in [a,b] for k in range(n)]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)]
    geo(vs,fs,mat)

for i,b in enumerate(data['buildings']):
    asset='sports_dorms' if i<4 else 'sports_teaching_office'
    wall=['DormCream','DormPale','DormOchre','DormCream','DormPale'][i]
    p=facade(b['outline'],b['levels'],b['height'],wall,pitch=3.1 if i<4 else 3.7)
    edges=[(a,bp) for a,bp in zip(p,p[1:]+p[:1]) if math.dist(a,bp)>12 and abs(a[1]-bp[1])<2]
    a,bp=max(edges,key=lambda e:(e[0][1]+e[1][1])*.5)
    approach=entry(a,bp,4.2,3,b['name'])
    b['front_approach']=list(approach)
    if i<4:
        # Window appliances and sheltered entrances break the long dormitory facades.
        part='DormDetails'
        for a,bp in edges:
            length=math.dist(a,bp);count=max(1,int(length/3.1))
            for k in range(1,count,2):
                for floor in range(1,b['levels']):
                    s=k*length/count+.42;y=.26+floor*(b['height']-.5)/b['levels']+1.25
                    edgebox(a,bp,s,s+.76,y,y+.51,.12,.46,'AirConditioner')
                    for row in range(4):edgebox(a,bp,s+.05,s+.70,y+.08+row*.095,y+.104+row*.095,.465,.475,'WindowReveal')
        # Rooftop stair enclosure is proportional to the observed dormitory roof masses.
        x=sum(q[0] for q in b['outline'])/len(b['outline']);z=sum(q[1] for q in b['outline'])/len(b['outline'])
        box((x,b['height']+1.3,z),(5.5,2.6,4.2),wall)

asset='sports_grandstand';part='Tiers'
for z0,z1 in [(394.8,445.4),(471.5,523.7)]:
    for k in range(12):
        east=-274.3-k*.54;west=-280.95;top=.10+(k+1)*.18
        poly=[[west,z0],[east,z0],[east,z1],[west,z1]]
        slab(poly,.08,top,'StandConcrete')
        solids.append({'name':f'grandstand_tier_{z0}_{k}','polygon':poly,'bottom':.08,'top':top})
        box((east-.18,top+.025,(z0+z1)/2),(.16,.05,z1-z0-.3),'StandTrim')
    for z in [z0,z1]:
        for k in range(0,12,2):
            x=-274.3-k*.54;y=.10+(k+1)*.18
            tube((x,y,z),(x,y+1.0,z),.035,'SportsSteel')
        tube((-274.3,1.44,z),(-280.4,3.6,z),.045,'SportsSteel')
    for z in range(math.ceil(z0),int(z1),4):tube((-280.88,2.42,z),(-280.88,3.4,z),.034,'SportsSteel')
    tube((-280.88,3.4,z0),(-280.88,3.4,z1),.045,'SportsSteel')
part='Pavilion'
poly=[[-286.1,446],[-277.9,446],[-277.9,471],[-286.1,471]]
slab(poly,.08,2.75,'StandConcrete')
solids.append({'name':'stand_podium','polygon':poly,'bottom':.08,'top':2.75})
house=[[-285.9,450],[-279.3,450],[-279.3,467],[-285.9,467]]
slab(house,2.75,7.6,'DormPale')
solids.append({'name':'grandstand_pavilion','polygon':house,'bottom':2.75,'top':7.6})
box((-278.99,4.5,458.5),(.20,3.0,12.9),'WindowGlass')
for z in range(452,466,3):box((-278.84,4.5,z),(.06,3.05,.065),'SportsSteel')
box((-282.4,7.7,458.5),(10.3,.30,26.9),'StandTrim')
box((-282.4,7.93,458.5),(10.6,.18,27.2),'DormCream')
for z in [449,468]:
    for k in range(17):
        east=-272.8-k*.29;top=(k+1)*.16
        q=[[-277.9,z-1],[east,z-1],[east,z+1],[-277.9,z+1]]
        slab(q,.08,top,'StandConcrete');solids.append({'name':f'stand_stair_{z}_{k}','polygon':q,'bottom':.08,'top':top})

asset='sports_equipment';part='Goals'
cx,cz=data['track']['center']
for end in [-1,1]:
    z=cz+end*52.5;back=z+end*2.0
    for side in [-1,1]:
        x=cx+side*3.66
        tube((x,.11,z),(x,2.55,z),.06,'GoalWhite',12)
        tube((x,2.55,z),(x,.11,back),.035,'SportsSteel')
        tube((x,.11,z),(x,.11,back),.035,'SportsSteel')
        solids.append({'name':f'goal_post_{end}_{side}','polygon':[[x-.065,z-.065],[x+.065,z-.065],[x+.065,z+.065],[x-.065,z+.065]],'bottom':.10,'top':2.55})
    tube((cx-3.66,2.55,z),(cx+3.66,2.55,z),.06,'GoalWhite',12)
    tube((cx-3.66,.11,back),(cx+3.66,.11,back),.035,'SportsSteel')
    for k in range(38):
        x=cx-3.66+k*7.32/37
        tube((x,2.50,z),(x,.14,back),.007,'NetCord',4)
    for k in range(13):
        t=k/12;y=.14+2.36*t;zz=back+(z-back)*t
        tube((cx-3.66,y,zz),(cx+3.66,y,zz),.007,'NetCord',4)
    for side in [-1,1]:
        for k in range(10):
            t=k/9;zz=z+(back-z)*t;y=2.50*(1-t)
            tube((cx+side*3.66,.14,zz),(cx+side*3.66,max(.15,y),zz),.007,'NetCord',4)

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
    print('SPORTS_ASSET',asset,count)
(ROOT/'godot/assets/sports_district_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/source/sports_district.blend'))
