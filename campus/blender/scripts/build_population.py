"""Build only two original ambient actors. Does not re-export existing cast."""
from pathlib import Path
import json
import math
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
HELPERS = Path(__file__).with_name('build_life.py').read_text(encoding='utf-8').split('for index,kind in enumerate')[0]


def loft(name, parent, rows, mat, segments=24):
    vertices = []
    for y,w,d,z in rows:
        for i in range(segments):
            a=i*math.tau/segments
            vertices.append(pt((w*math.sin(a),y,z-d*math.copysign(abs(math.cos(a))**.72,math.cos(a)))))
    faces=[]
    for j in range(len(rows)-1):
        for i in range(segments):
            a=j*segments+i;b=j*segments+(i+1)%segments
            faces.append((a,b,b+segments,a+segments))
    faces.extend([tuple(reversed(range(segments))),tuple((len(rows)-1)*segments+i for i in range(segments))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.materials.append(M[mat])
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.parent=parent
    for f in mesh.polygons:f.use_smooth=True
    return obj


def soft_ring(name,parent,pos,radius,width,mat,segments=48,sides=6):
    # Wheels lie in the Godot YZ plane and turn around the X axle.
    verts=[];faces=[]
    for i in range(segments):
        a=i*math.tau/segments
        for j in range(sides):
            b=j*math.tau/sides;rr=radius+math.cos(b)*width
            verts.append(pt((pos[0]+math.sin(b)*width,pos[1]+math.cos(a)*rr,pos[2]+math.sin(a)*rr)))
    for i in range(segments):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,((i+1)%segments)*sides+(j+1)%sides,((i+1)%segments)*sides+j))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(M[mat])
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.parent=parent
    for f in mesh.polygons:f.use_smooth=True
    return obj


def face(human,role):
    reader=role=='bench_reader';long_hair=role=='study_walk';photo=role=='photographer'
    head=node('Ambient_Head',human,(0,.46,-.01))
    profile=[(0,.036,.043,-.013),(.025,.054,.059,-.008),(.065,.072,.065,0),(.115,.083,.073,.003),(.17,.086,.075,.003),(.225,.084,.072,.004),(.27,.068,.060,.005),(.29,.033,.035,.004),(.298,.005,.008,0)]
    loft('AdultFace',head,profile,'Skin',32)
    def cross(y,a,extra=.004):
        for p,q in zip(profile[:-1],profile[1:]):
            if y<=q[0]:
                t=max(0,(y-p[0])/(q[0]-p[0]));w=p[1]+(q[1]-p[1])*t;d=p[2]+(q[2]-p[2])*t;z=p[3]+(q[3]-p[3])*t;break
        else:w,d,z=profile[-1][1:]
        c=math.cos(a)
        if y>.29:
            cap=math.sqrt(max(0.0,1.0-((y-.29)/.022)**2))
            return (math.sin(a)*(.033+extra)*cap,y,.004-math.copysign(abs(c)**.72,c)*(.035+extra)*cap)
        return (math.sin(a)*(w+extra),y,z-math.copysign(abs(c)**.72,c)*(d+extra))
    verts=[];faces=[];n=48;rings=30
    for j in range(rings):
        t=j/(rings-1)
        for i in range(n):
            a=i*math.tau/n;front=max(0,math.cos(a))
            low=(.025 if long_hair else .05 if reader else .11)+front*(.205 if long_hair else .18 if reader else .13)
            if front>.5:low+=.008*math.sin(a*2.0)
            verts.append(pt(cross(low+(.307-low)*t,a,.011)))
    for j in range(rings-1):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    verts.append(pt((0,.312,.004)));cap=len(verts)-1
    for i in range(n):faces.append(((rings-1)*n+i,(rings-1)*n+(i+1)%n,cap))
    mesh=bpy.data.meshes.new('OriginalShortHair');mesh.from_pydata(verts,[],faces);mesh.materials.append(M['Hair'])
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new('EarLengthHair' if reader else 'ShortSidePartHair',mesh);bpy.context.collection.objects.link(obj);obj.parent=head
    for f in mesh.polygons:f.use_smooth=True
    if photo:
        ball('LowPonytail',head,(0,.112,.096),(.043,.091,.043),'Hair')
        ball('PonytailTip',head,(.003,.035,.105),(.025,.043,.027),'Hair')
        rod('SimpleHairTie',head,(-.029,.163,.093),(.029,.163,.093),.005,'ClothDark')
    elif long_hair:
        for side in [-1,1]:
            strand=loft('ShoulderLengthHair',head,[(-.033,.023,.030,.050),(.025,.031,.042,.045),(.090,.031,.043,.038),(.145,.021,.030,.022)],'Hair',20)
            strand.location.x=side*.076
    for s in [-1,1]:
        ball('Ear',head,(s*.086,.135,.003),(.013,.026,.015),'Skin')
        eye=node('Ambient_Eye'+('L' if s<0 else 'R'),head,(s*.039,.168,-.074))
        # A shallow almond eye, no large spheres or highlight dots.
        v=[(-.020,0,-.002),(-.010,.005,-.004),(.009,.004,-.004),(.020,-.001,-.002),(.006,-.004,-.004),(-.011,-.004,-.004)]
        me=bpy.data.meshes.new('AlmondEye');me.from_pydata([pt(p) for p in v],[],[(0,1,2,3,4,5)]);me.materials.append(M['Cream'])
        ob=bpy.data.objects.new('AlmondEye',me);bpy.context.collection.objects.link(ob);ob.parent=eye
        for a,b in zip(v[:3],v[1:4]):rod('ThinUpperLid',eye,a,b,.0011,'Ink')
        pupil=node('Ambient_Pupil'+('L' if s<0 else 'R'),eye,(0,0,-.005))
        ball('Pupil',pupil,(0,0,0),(.0038,.004,.0016),'Ink')
        rod('Brow',head,(s*.039-.018,.195,-.073),(s*.039+.019,.197,-.073),.0015,'Hair')
    ball('NoseBridge',head,(0,.129,-.077),(.009,.022,.010),'Skin')
    ball('NoseTip',head,(0,.112,-.087),(.012,.011,.012),'Skin')
    rod('RestrainedMouth',head,(-.016,.074,-.069),(.016,.074,-.069),.0011,'Lip')
    if role=='cyclist':
        for j in range(4):rod('SidePartStrand',head,(-.028+j*.020,.251,-.060),(-.008+j*.017,.272,-.046),.0020,'HairHighlight')
    return head


def human_asset(root,role):
    reader=role=='bench_reader'
    human=node('Ambient_Human',root,(0,.63,0) if reader else (0,.92,.16) if role=='cyclist' else (0,.731,0))
    torso=node('Ambient_Torso',human)
    loft('QuietClothTorso',torso,[(.015,.12,.071,.005),(.06,.127,.076,.004),(.12,.136,.073,0),(.23,.134,.073,0),(.31,.148,.073,0),(.355,.151,.065,0),(.40,.12,.052,0),(.438,.045,.037,0)],'Cloth',32)
    loft('Hem',torso,[(.02,.121,.075,.005),(.045,.126,.078,.005)],'ClothDark',32)
    rod('Neck',torso,(0,.405,0),(0,.50,0),.038,'Skin')
    loft('SoftNeckband',torso,[(.420,.046,.043,0),(.446,.042,.040,0)],'Cream',24)
    if not reader:
        rod('JacketZip',torso,(0,.05,-.080),(0,.42,-.05),.0018,'Cream')
        for s in [-1,1]:rod('PocketWelt',torso,(s*.064,.1,-.069),(s*.110,.17,-.053),.0023,'ClothDark')
    else:ball('SeatedTrouserPelvis',human,(0,-.032,.034),(.132,.067,.085),'Trouser')
    for side in [-1,1]:
        tag='L' if side<0 else 'R'
        arm=node('Ambient_Arm'+tag,human,(side*.148,.35,0))
        loft('Sleeve',arm,[(.02,.036,.040,0),(0,.051,.051,0),(-.05,.056,.053,0),(-.14,.048,.047,0),(-.245,.038,.040,0),(-.28,.037,.037,0)],'Cloth')
        fore=node('Ambient_Fore'+tag,arm,(0,-.28,0))
        ball('ElbowTransition',fore,(0,0,0),(.038,.037,.038),'Cloth')
        loft('ForeSleeve',fore,[(0,.036,.037,0),(-.04,.042,.041,0),(-.16,.032,.036,0),(-.225,.026,.028,0)],'Cloth')
        loft('Cuff',fore,[(-.208,.028,.030,0),(-.233,.028,.030,0)],'ClothDark')
        hand=node('Ambient_Hand'+tag,fore,(0,-.27,0))
        ball('Palm',hand,(0,0,0),(.022,.028,.015),'Skin')
        for j in range(3):
            x=-.012+j*.011
            rod('Finger',hand,(x,-.019,-.006),(x,-.030,-.013),.0048,'Skin')
        ball('Thumb',hand,(-side*.021,-.006,-.009),(.009,.015,.010),'Skin')
        leg=node('Ambient_Leg'+tag,human,(side*.073,0,0))
        up=.42 if reader else .36;down=.50 if reader else .34
        loft('TrouserThigh',leg,[(y*up/.36,w,d,z) for y,w,d,z in [(.016,.072,.066,0),(-.08,.069,.061,0),(-.22,.053,.050,0),(-.36,.046,.045,0)]],'Trouser')
        knee=node('Ambient_Knee'+tag,leg,(0,-up,0))
        ball('Knee',knee,(0,0,0),(.046,.045,.045),'Trouser')
        loft('TrouserShin',knee,[(y*down/.34,w,d,z) for y,w,d,z in [(0,.046,.045,0),(-.17,.039,.041,0),(-.31,.038,.038,0),(-.34,.038,.038,0)]],'Trouser')
        foot=node('Ambient_Foot'+tag,knee,(0,-down,0))
        cube('OrdinaryShoe',foot,(0,-.023,-.043),(.094,.063,.185),'Shoe',.018)
        cube('ShoeSole',foot,(0,-.056,-.043),(.097,.016,.190),'Sole',.009)
    face(human,role)
    if reader or role=='study_walk':
        book=node('Ambient_Book',human,(0,.025,-.28))
        cube('BookCover',book,(0,0,0),(.28,.018,.22),'Cover',.004)
        cube('BookPages',book,(0,.013,0),(.274,.011,.212),'Page',.002)
        for side in [-1,1]:
            for j in range(6):rod('BookLines',book,(side*.067-.048,.020,-.081+j*.026),(side*.067+.048,.020,-.081+j*.026),.0005,'Cover')
        page=node('Ambient_Page',book)
        cube('TurningPage',page,(.067,.022,0),(.13,.0012,.204),'Page',.0002)
    elif role=='photographer':
        phone=node('Ambient_Phone',human,(0,.14,-.25))
        cube('PhoneBody',phone,(0,0,0),(.074,.137,.011),'Ink',.005)
        cube('PhoneScreen',phone,(0,0,.0062),(.063,.121,.0012),'Screen',.003)
        # Front here means the back of the phone, facing the photographed scene.
        ball('PhoneCamera',phone,(-.023,.046,-.0065),(.007,.007,.002),'Metal')
        rod('PhoneCameraTrim',phone,(-.026,.040,-.007),(-.026,.052,-.007),.002,'Shoe')
    return human


def bicycle(root):
    bike=node('Ambient_Bike',root)
    wheel_y=.35
    for label,z in [('Front',-.55),('Rear',.55)]:
        wheel=node('Ambient_Wheel'+label,bike,(0,wheel_y,z))
        soft_ring('Tyre',wheel,(0,0,0),.318,.022,'Rubber')
        soft_ring('Rim',wheel,(0,0,0),.294,.008,'Metal',48,6)
        rod('Axle',wheel,(-.057,0,0),(.057,0,0),.017,'Metal')
        for i in range(12):
            a=i*math.tau/12
            rod('Spoke',wheel,((-.016 if i%2 else .016),0,0),(0,math.cos(a)*.288,math.sin(a)*.288),.0015,'Metal')
    bb=(0,.38,.10);seat=(0,.78,.20);head=(0,.82,-.38);rear=(0,.35,.55)
    for a,b in [(bb,seat),(seat,head),(head,bb),(seat,rear),(bb,rear)]:rod('FrameTube',bike,a,b,.014,'BikePaint')
    for s in [-1,1]:
        rod('RearStay',bike,(s*.035,.38,.10),(s*.04,.35,.55),.008,'BikePaint')
        rod('Fork',bike,(s*.017,.82,-.38),(s*.044,.35,-.55),.010,'BikePaint')
        rod('SeatStay',bike,(s*.013,.78,.20),(s*.04,.35,.55),.008,'BikePaint')
    rod('SeatPost',bike,seat,(0,.884,.20),.014,'Metal')
    cube('Saddle',bike,(0,.897,.19),(.165,.040,.22),'Shoe',.020)
    rod('Stem',bike,head,(0,1.005,-.40),.014,'Metal')
    rod('Handlebar',bike,(-.25,1.04,-.43),(.25,1.04,-.43),.012,'Metal')
    rod('StemJoin',bike,(0,1.005,-.40),(0,1.04,-.43),.011,'Metal')
    for s in [-1,1]:
        rod('Grip',bike,(s*.18,1.04,-.43),(s*.28,1.04,-.43),.016,'Rubber')
        rod('BrakeLever',bike,(s*.18,1.027,-.447),(s*.25,1.025,-.471),.004,'Metal')
    soft_ring('ChainRing',bike,(-.045,.38,.10),.077,.006,'Metal',28,5)
    for y in [.32,.44]:rod('Chain',bike,(-.045,y,.10),(-.045,.35+(y-.38)*.5,.55),.0025,'Metal')
    crank=node('Ambient_Crank',bike,bb)
    rod('CrankL',crank,(-.065,0,0),(-.10,-.16,0),.012,'Metal')
    rod('CrankR',crank,(.065,0,0),(.10,.16,0),.012,'Metal')
    for s in [-1,1]:
        pedal=node('Ambient_Pedal'+('L' if s<0 else 'R'),crank,(s*.13,s*.16,0))
        cube('FlatPedal',pedal,(0,0,0),(.10,.018,.075),'Rubber',.003)
    # Small coherent campus-bike details, no decorative clutter.
    cube('RearRack',bike,(0,.74,.50),(.19,.025,.25),'Metal',.006)
    for s in [-1,1]:rod('RackSupport',bike,(s*.085,.74,.59),(s*.05,.35,.55),.005,'Metal')
    ball('Bell',bike,(.12,1.06,-.427),(.024,.014,.024),'Metal')
    cube('RearReflector',bike,(0,.68,.66),(.044,.026,.008),'Reflector',.003)


def material(key,name,color,rough=.82):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=rough;M[key]=m


report={}
for role in ['cyclist','bench_reader','photographer','study_walk']:
    exec(HELPERS,globals())
    reader=role=='bench_reader'
    hair=(.09,.060,.043) if reader else (.067,.048,.041) if role=='photographer' else (.044,.037,.033) if role=='study_walk' else (.033,.039,.038)
    for key,color in {'Skin':(.66,.46,.31),'Cream':(.78,.76,.65),'Hair':hair,'Ink':(.043,.048,.045),'Trouser':(.25,.26,.23) if reader else (.24,.225,.20) if role=='photographer' else (.13,.16,.17),'Shoe':(.13,.15,.14),'Sole':(.37,.40,.36),'Page':(.82,.80,.69),'Cover':(.24,.30,.26),'Metal':(.32,.38,.38)}.items():
        M[key].diffuse_color=(*color,1);M[key].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
    cloth={'cyclist':(.22,.34,.38),'bench_reader':(.32,.41,.34),'photographer':(.47,.34,.32),'study_walk':(.24,.39,.35)}[role]
    material('Cloth','AmbientCloth',cloth)
    material('ClothDark','AmbientClothTrim',tuple(x*.78 for x in cloth))
    material('Lip','AmbientMutedLip',(.33,.20,.16))
    material('HairHighlight','AmbientHairSoftHighlight',(.058,.066,.062))
    material('Rubber','AmbientBicycleRubber',(.045,.052,.048))
    material('BikePaint','AmbientBicyclePaint',(.085,.19,.20),.55)
    material('Reflector','AmbientReflector',(.42,.13,.095),.55)
    material('Screen','AmbientPhoneScreen',(.23,.31,.33),.34)
    # campus.asset_material caches by resource_name: keep these palettes isolated
    # from existing LifeSkin/LifeHair/LifeTrouser and from the other ambient role.
    prefix={'cyclist':'AmbientCyclist','bench_reader':'AmbientReader','photographer':'AmbientPhotographer','study_walk':'AmbientStudyWalk'}[role]
    for key,m in M.items():m.name=prefix+key
    root=node(prefix)
    human_asset(root,role)
    if role=='cyclist':bicycle(root)
    # Reduce smooth primitive overhead before the shared export join pass.
    for obj in list(root.children_recursive):
        if obj.type!='MESH':continue
        for modifier in list(obj.modifiers):
            if modifier.type=='BEVEL':modifier.segments=3
        for f in obj.data.polygons:f.use_smooth=True
    export(root,'ambient_'+role+'.glb')
    bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();triangles=0;meshes=0
    for obj in root.children_recursive:
        if obj.type=='MESH':
            e=obj.evaluated_get(dg);me=e.to_mesh();me.calc_loop_triangles();triangles+=len(me.loop_triangles);meshes+=1;e.to_mesh_clear()
    if triangles>=40000:raise RuntimeError(f'{role} exceeds triangle budget: {triangles}')
    source=ROOT/'blender/source'/('ambient_'+role+'.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    report[role]={'triangles':triangles,'mesh_nodes':meshes,'glb':'godot/assets/ambient_'+role+'.glb','source':str(source),'units':'metres','forward':'-Z','root':'bench placement; feet -0.005 m' if reader else 'ground','material_prefix':prefix}
    print('AMBIENT_ASSET_OK',role,triangles,flush=True)
out=ROOT/'renders/population';out.mkdir(parents=True,exist_ok=True)
(out/'asset_manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
