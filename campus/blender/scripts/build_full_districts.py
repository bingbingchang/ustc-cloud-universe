"""Mapped exterior assets for the east housing, central life and southern science districts."""
from pathlib import Path
import bpy,bmesh,json,math
script=Path(__file__).resolve()
exec(compile((script.parent/'build_north_teaching.py').read_text(encoding='utf-8').split('# Exact snapshot footprints')[0],'campus_exterior_helpers','exec'),globals())
for name,col in [('HousingIvory',(.70,.71,.66)),('HousingWarm',(.63,.60,.51)),('HousingGrey',(.60,.64,.62)),('CampusBrick',(.52,.25,.16)),
                 ('WhiteTrim',(.78,.78,.72)),('RoofTile',(.27,.30,.29)),('LabSilver',(.59,.64,.64)),('LabBlue',(.25,.37,.45)),
                 ('ServiceWarm',(.64,.62,.53)),('KindergartenPale',(.74,.72,.59)),('KindergartenBlue',(.30,.53,.61)),
                 ('KindergartenRose',(.68,.40,.38))]:material(name,col)
data=json.loads((ROOT/'godot/data/full_districts.json').read_text(encoding='utf-8'))
manifest={'unit':'meter','placement':[0,0,0],'districts':{},'assets':{},'collision_solids':solids,'sources':data['sources']}

def roof(poly,h,whole=False):
    global part
    part='PitchedRoof'
    if whole:
        a,b=max(zip(poly,poly[1:]+poly[:1]),key=lambda e:math.dist(*e));length=math.dist(a,b)
        ux,uz=(b[0]-a[0])/length,(b[1]-a[1])/length;nx,nz=uz,-ux
        depth=max(-(q[0]-a[0])*nx-(q[1]-a[1])*nz for q in poly)
        if depth>length:depth=length
        # Two sloped planes, vertical gable ends, grey ridges; no courtyard infill.
        def q(s,d,y):return (a[0]+ux*s-nx*d,h+y,a[1]+uz*s-nz*d)
        rise=min(4,depth*.22)
        geo([q(-.5,-.55,.2),q(length+.5,-.55,.2),q(length+.5,depth/2,rise),q(-.5,depth/2,rise),
             q(-.5,depth+.55,.2),q(length+.5,depth+.55,.2)],[(0,1,2,3),(3,2,5,4),(0,3,4),(1,5,2)],'RoofTile')
        for k in range(int(length/1.2)+1):
            s=k*length/max(1,int(length/1.2));geo([q(s-.025,-.55,.23),q(s+.025,-.55,.23),q(s+.025,depth/2,rise+.025),q(s-.025,depth/2,rise+.025),q(s-.025,depth+.55,.23),q(s+.025,depth+.55,.23)],[(0,1,2,3),(3,2,5,4)],'FacultyRoof')
    else:
        for a,b in zip(poly,poly[1:]+poly[:1]):
            length=math.dist(a,b)
            if length<13:continue
            ux,uz=(b[0]-a[0])/length,(b[1]-a[1])/length;nx,nz=uz,-ux;depth=6.0
            def q(s,d,y):return (a[0]+ux*s-nx*d,h+y,a[1]+uz*s-nz*d)
            geo([q(0,-.35,.2),q(length,-.35,.2),q(length,depth/2,1.6),q(0,depth/2,1.6),q(0,depth,.2),q(length,depth,.2)],[(0,1,2,3),(3,2,5,4),(0,3,4),(1,5,2)],'RoofTile')

for d in data['districts']:
    manifest['districts'][d['id']]={'buildings':d['buildings'],'assets':[]}
    for index,b in enumerate(d['buildings']):
        asset='mapped_'+b['osm_way'];manifest['districts'][d['id']]['assets'].append(asset)
        p=b['outline'];s=b['style'];h=b['height'];levels=b['levels']
        if s=='west_gate':
            # West entrance is an open archway on its access road, not a building prism.
            cx=sum(v[0] for v in p)/len(p);cz=sum(v[1] for v in p)/len(p);part='Gate'
            for z in [cz-7.5,cz+7.5]:
                box((cx,2.7,z),(1.15,5.4,1.15),'WhiteTrim');solids.append({'name':asset+'_pier','polygon':[[cx-.575,z-.575],[cx+.575,z-.575],[cx+.575,z+.575],[cx-.575,z+.575]],'bottom':.0,'top':5.4})
            box((cx,5.5,cz),(1.25,.7,16.2),'WhiteTrim');inscription('中国科学技术大学',(cx-.65,5.5,cz),.55,'LetterGold',heading=-math.pi/2)
            b['front_approach']=[cx+4.5,.1,cz];continue
        wall='HousingIvory';pitch=3.6;curtain=[]
        if s=='residential':
            wall=['HousingIvory','HousingWarm','HousingGrey'][index%3]
            if b['name'] in ['62#','59#','60#','61#','65#','64#']:wall='CampusBrick'
            pitch=3.1
        elif s in ['heritage','auditorium']:wall='CampusBrick';pitch=3.7
        elif s in ['research_tower','research_glass']:
            wall='LabSilver';pitch=3.7
            curtain=[i for i,(a,c) in enumerate(zip(p,p[1:]+p[:1])) if math.dist(a,c)>10 and abs(a[1]-c[1])<2] if s=='research_glass' else []
        elif s=='service':wall='ServiceWarm';pitch=4.5
        elif s=='kindergarten':wall='KindergartenPale';pitch=2.8
        elif s=='hospital':wall='HousingIvory';pitch=3.0
        elif s=='student_activity':wall='CampusBrick';pitch=3.4;curtain=[i for i,(a,c) in enumerate(zip(p,p[1:]+p[:1])) if abs(a[0]-c[0])<2 and math.dist(a,c)>12]
        elif b['name'] in ['物理楼','化学与材料科学学院','计算小楼','单分子科学楼']:wall='HousingIvory'
        else:wall='ServiceWarm'
        p=facade(p,levels,h,wall,pitch,curtain)
        if 'entry_edge' in b:
            a,c=p[b['entry_edge']],p[(b['entry_edge']+1)%len(p)]
            width=min(5.2,max(2.4,math.dist(a,c)*.55));b['front_approach']=list(entry(a,c,width,1,b['name'] if b['name']!='校内附属建筑' else ''))
        part='FacadeAccents'
        for a,c in zip(p,p[1:]+p[:1]):
            length=math.dist(a,c)
            if length<8:continue
            if s=='residential' and abs(a[1]-c[1])<2:
                # Shallow exterior balconies and ledges distinguish the housing strips.
                for floor in range(1,levels):
                    y=.26+floor*(h-.5)/levels
                    for k in range(max(1,int(length/7))):
                        mid=(k+.5)*length/max(1,int(length/7));w=2.35
                        edgebox(a,c,mid-w/2,mid+w/2,y,y+.11,0,.65,wall)
                        edgebox(a,c,mid-w/2,mid+w/2,y+.66,y+.96,.58,.66,'WhiteTrim')
            if s in ['research_tower','research_glass']:
                for k in range(max(1,int(length/5))):
                    mid=(k+.5)*length/max(1,int(length/5));edgebox(a,c,mid-.09,mid+.09,.35,h-.2,.02,.18,'WhiteTrim')
                edgebox(a,c,0,length,h-1.3,h-.3,.02,.08,'LabBlue')
            if s=='kindergarten':
                for floor in range(levels):edgebox(a,c,0,length,.4+floor*3.4,.7+floor*3.4,.02,.07,'KindergartenBlue' if floor%2 else 'KindergartenRose')
            if s=='heritage':
                edgebox(a,c,0,length,.3,1.0,0,.10,'WhiteTrim');edgebox(a,c,0,length,h-.8,h-.55,0,.16,'WhiteTrim')
        if s in ['auditorium','heritage']:roof(p,h,whole=s=='auditorium' or len(p)==4)
        else:
            part='RoofEquipment';cx=sum(v[0] for v in p)/len(p);cz=sum(v[1] for v in p)/len(p)
            # Small mapped roof equipment stays within actual wings.
            a,c=max(zip(p,p[1:]+p[:1]),key=lambda e:math.dist(*e));l=math.dist(a,c);nx,nz=(c[1]-a[1])/l,-(c[0]-a[0])/l
            cx,cz=(a[0]+c[0])/2-nx*3,(a[1]+c[1])/2-nz*3
            box((cx,h+1,cz),(4,1.2,3),'FacultyDarkPanel');box((cx,h+1.68,cz),(4.2,.14,3.2),'FacultyRoof')
        print('MAPPED_BUILDING',asset,s,levels)

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
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets'/f'{asset}.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
    count=0
    for ob in merged:ob.data.calc_loop_triangles();count+=len(ob.data.loop_triangles)
    manifest['assets'][asset]={'file':asset+'.glb','surfaces':len(merged),'triangles':count}
(ROOT/'godot/assets/full_districts_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/source/full_districts.blend'))
print('FULL_ASSETS',len(manifest['assets']),sum(a['triangles'] for a in manifest['assets'].values()))
