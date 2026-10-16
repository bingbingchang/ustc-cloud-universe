"""Meter-scale skinned creatures and baked in-place actions; isolated asset builder.

Construction coordinates match Godot (+Y up, -Z forward), converted to Blender.
Every vertex is skinned. Limb poses solve two-bone IK before baking, including
backwards stance travel so the Godot actor can match its measured world speed.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector, Matrix

HERE = Path(__file__).resolve().parent
CAMPUS = HERE.parents[1]
OUT = CAMPUS/'godot'/'wildlife'/'assets'
SOURCE = HERE/'source'
PROOF = CAMPUS/'renders'/'wildlife'
for p in (OUT,SOURCE,PROOF): p.mkdir(parents=True,exist_ok=True)
TAU = math.tau
FPS = 30
M = {}
meshes=[]
rest={}
rig=None

def g(p): return Vector((p[0],-p[2],p[1]))
def v(p): return Vector(p)
def mix(a,b,t): return v(a).lerp(v(b),t)
def smooth(t): return max(0,min(1,t))**2*(3-2*max(0,min(1,t)))

def material(name,color,texture=None,rough=.7):
    m=bpy.data.materials.new('Wildlife_'+name);m.diffuse_color=(*color,1);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Roughness'].default_value=rough
    if texture:
        for kind,socket in [('albedo','Base Color'),('normal','Normal')]:
            n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(OUT/'textures'/f'{texture}_{kind}.png'),check_existing=True)
            if kind=='normal':
                n.image.colorspace_settings.name='Non-Color';normal=m.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.22
                m.node_tree.links.new(n.outputs['Color'],normal.inputs['Color']);m.node_tree.links.new(normal.outputs['Normal'],bs.inputs[socket])
            else: m.node_tree.links.new(n.outputs['Color'],bs.inputs[socket])
    M[name]=m;return m

def mesh(name,vertices,faces,uv,weights,mat):
    data=bpy.data.meshes.new(name);data.from_pydata([g(p) for p in vertices],[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);data.materials.append(M[mat])
    for poly in data.polygons:poly.use_smooth=True
    layer=data.uv_layers.new(name='UVMap')
    for poly in data.polygons:
        for li in poly.loop_indices:layer.data[li].uv=uv[data.loops[li].vertex_index]
    groups={}
    for i,w in enumerate(weights):
        for key,amount in w.items():
            if key not in groups:groups[key]=o.vertex_groups.new(name=key)
            if amount>0:groups[key].add([i],amount,'REPLACE')
    meshes.append(o);return o

def ellipsoid(name,center,scale,mat,bone,seg=24,rings=14):
    vertices=[];uv=[];weights=[];faces=[]
    for j in range(rings+1):
        phi=math.pi*j/rings
        for i in range(seg+1):
            theta=TAU*i/seg
            vertices.append((center[0]+scale[0]*math.sin(phi)*math.cos(theta),center[1]+scale[1]*math.cos(phi),center[2]+scale[2]*math.sin(phi)*math.sin(theta)))
            uv.append((i/seg,j/rings));weights.append({bone:1})
    for j in range(rings):
        for i in range(seg):
            a=j*(seg+1)+i;faces.append((a,a+1,a+seg+2,a+seg+1))
    return mesh(name,vertices,faces,uv,weights,mat)

def tube(name,points,radii,mat,bones,seg=20,sub=3):
    vertices=[];uv=[];weights=[];faces=[]
    for k in range((len(points)-1)*sub+1):
        a=min(k//sub,len(points)-2);t=(k-a*sub)/sub;p=mix(points[a],points[a+1],t)
        direction=(v(points[a+1])-v(points[a])).normalized()
        ref=Vector((1,0,0)) if abs(direction.x)<.8 else Vector((0,1,0))
        u=direction.cross(ref).normalized();w=direction.cross(u).normalized()
        radius=radii[a]*(1-t)+radii[a+1]*t
        ba=bones[min(a,len(bones)-1)];bb=bones[min(a+1,len(bones)-1)]
        for i in range(seg+1):
            q=p+radius*(u*math.cos(TAU*i/seg)+w*math.sin(TAU*i/seg));vertices.append(q)
            uv.append((k/((len(points)-1)*sub),i/seg))
            weights.append({ba:1} if ba==bb else {ba:1-t,bb:t})
    count=(len(points)-1)*sub+1
    for j in range(count-1):
        for i in range(seg):
            a=j*(seg+1)+i;faces.append((a,a+1,a+seg+2,a+seg+1))
    faces += [tuple(reversed(range(seg+1))),tuple((count-1)*(seg+1)+i for i in range(seg+1))]
    return mesh(name,vertices,faces,uv,weights,mat)

def body(name,sections,mat):
    vertices=[];uv=[];weights=[];faces=[];seg=48
    for j,(z,y,rx,ry) in enumerate(sections):
        q=j/(len(sections)-1)
        for i in range(seg+1):
            t=TAU*i/seg;vertices.append((rx*math.cos(t),y+ry*math.sin(t),z));uv.append((q,i/seg))
            weights.append({'Chest':1-q,'Hips':q})
    for j in range(len(sections)-1):
        for i in range(seg):
            a=j*(seg+1)+i;faces.append((a,a+1,a+seg+2,a+seg+1))
    faces += [tuple(reversed(range(seg+1))),tuple([(len(sections)-1)*(seg+1)+i for i in range(seg+1)])]
    return mesh(name,vertices,faces,uv,weights,mat)

def feather(name,start,end,width,mat,bone):
    # Curved overlapping vanes, with a slightly raised centre rather than cards.
    a=v(start);b=v(end);d=(b-a).normalized();side=d.cross(Vector((0,1,0)))
    if side.length<.01:side=Vector((1,0,0))
    side.normalize();normal=side.cross(d).normalized()
    vertices=[];uv=[];weights=[];faces=[]
    for j in range(9):
        t=j/8;mid=a.lerp(b,t);r=width*(math.sin(math.pi*(.06+.91*t))**.65)
        for i in range(5):
            s=i/4*2-1;vertices.append(mid+side*r*s+normal*width*.16*(1-s*s)*math.sin(math.pi*t))
            uv.append((i/4,t));weights.append({bone:1})
    for j in range(8):
        for i in range(4):
            k=j*5+i;faces.append((k,k+1,k+6,k+5))
    return mesh(name,vertices,faces,uv,weights,mat)

def bone(name,a,b,parent=None):
    eb=rig.data.edit_bones.new(name);eb.head=g(a);eb.tail=g(b)
    if parent:eb.parent=rig.data.edit_bones[parent]
    rest[name]=(v(a),v(b))
    return eb

def begin(name):
    global meshes,rest,rig,M
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for old in list(bpy.data.actions):bpy.data.actions.remove(old,do_unlink=True)
    for database in (bpy.data.meshes,bpy.data.armatures,bpy.data.materials,bpy.data.images):
        for old in list(database):
            if old.users==0:database.remove(old)
    meshes=[];rest={};M={}
    arm=bpy.data.armatures.new(name+'_Skeleton');rig=bpy.data.objects.new(name,arm);bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')

def end_bones():
    bpy.ops.object.mode_set(mode='OBJECT');rig.select_set(False)

def bind():
    for o in meshes:
        o.parent=rig;m=o.modifiers.new('Skin','ARMATURE');m.object=rig
    bpy.context.view_layer.objects.active=rig

def transform_bone(name,a=None,b=None,offset=None,rot=None):
    ra,rb=rest[name];a=ra.copy() if a is None else v(a);b=rb.copy() if b is None else v(b)
    if offset is not None:a+=v(offset);b+=v(offset)
    old=g(rb-ra).normalized();new=g(b-a).normalized()
    rotation=old.rotation_difference(new).to_matrix().to_4x4()
    mat=rotation@rig.data.bones[name].matrix_local.copy()
    mat.translation=g(a)
    if rot:
        from mathutils import Euler
        mat=Matrix.Translation(g(a))@Euler(rot,'XYZ').to_matrix().to_4x4()@Matrix.Translation(-g(a))@mat
    bpy.context.view_layer.update()
    rig.pose.bones[name].matrix=mat

def shift_bone(name,offset=(0,0,0),rot=None):transform_bone(name,offset=offset,rot=rot)

def follow_bone(name,parent):
    bpy.context.view_layer.update()
    rig.pose.bones[name].matrix=rig.pose.bones[parent].matrix@rig.data.bones[parent].matrix_local.inverted()@rig.data.bones[name].matrix_local

def reset_pose():
    for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()

def ik(a,target,l1,l2,bend):
    a=v(a);target=v(target);d=target-a;length=min(d.length,l1+l2-.0001);n=d.normalized()
    h=(l1*l1-l2*l2+length*length)/(2*length);height=math.sqrt(max(0,l1*l1-h*h))
    side=v(bend)-n*v(bend).dot(n);side.normalize()
    return a+n*h+side*height

def limb_pose(prefix,shoulder,foot,upper,lower,bend):
    wrist=v(foot)+Vector((0,.04,.019))
    elbow=ik(shoulder,wrist,upper,lower,bend)
    transform_bone(prefix+'_Upper',shoulder,elbow);transform_bone(prefix+'_Lower',elbow,wrist)
    transform_bone(prefix+'_Foot',wrist,foot)

def keyframe(frame):
    bpy.context.view_layer.update()
    for pb in rig.pose.bones:
        pb.rotation_mode='QUATERNION'
        for prop in ('location','rotation_quaternion','scale'):pb.keyframe_insert(prop,frame=frame,group=pb.name)

def action(name,duration,pose):
    reset_pose();act=bpy.data.actions.new(name);act.use_fake_user=True
    rig.animation_data_create();rig.animation_data.action=act
    count=round(duration*FPS)
    for frame in range(1,count+2):
        reset_pose();pose((frame-1)/count,(frame-1)/FPS);keyframe(frame)
    track=rig.animation_data.nla_tracks.new();track.name=name
    strip=track.strips.new(name,1,act);strip.name=name;strip.action_frame_start=1;strip.action_frame_end=count+1
    strip.frame_start=1;strip.frame_end=count+1;track.mute=True
    return dict(name=name,seconds=duration)

def cat_model():
    begin('WildlifeCat')
    bone('Root',(0,0,0),(0,.05,0))
    bone('Chest',(0,.285,-.15),(0,.285,-.22),'Root');bone('Hips',(0,.27,.14),(0,.27,.22),'Root')
    bone('Head',(0,.33,-.27),(0,.34,-.35),'Chest');bone('Jaw',(0,.309,-.326),(0,.302,-.38),'Head')
    for side in [-1,1]:
        label='L' if side<0 else 'R'
        bone('Ear'+label,(side*.042,.389,-.28),(side*.062,.445,-.275),'Head')
        for kind,z in [('Front',-.18),('Back',.16)]:
            prefix=kind+label;x=side*.06
            a=(x,.29,z);b=(x,.175,z+(.026 if kind=='Front' else -.055));c=(x,.065,z+(.005 if kind=='Front' else .045));d=(x,.025,z-.014)
            bone(prefix+'_Upper',a,b,'Chest' if kind=='Front' else 'Hips');bone(prefix+'_Lower',b,c,prefix+'_Upper');bone(prefix+'_Foot',c,d,prefix+'_Lower')
    tail=[(0,.275,.225),(.018,.25,.285),(.035,.22,.345),(.055,.195,.405),(.07,.18,.465),(.07,.175,.52),(.055,.18,.565)]
    for i in range(len(tail)-1):bone('Tail%d'%i,tail[i],tail[i+1],'Hips' if i==0 else 'Tail%d'%(i-1))
    end_bones()
    material('CatCoat',(1,1,1),'cat_coat');material('CatHead',(1,1,1),'cat_head');material('CatCream',(1,1,1),'cat_cream')
    material('Pink',(.60,.36,.35));material('Ink',(.018,.025,.023),rough=.65)
    material('Iris',(1,1,1),'cat_iris',.28);material('Whisker',(.69,.67,.60));material('EyeGlint',(.94,.94,.85),rough=.1)
    body('ContinuousTorso',[(-.26,.28,.014,.033),(-.235,.282,.05,.073),(-.20,.282,.071,.088),(-.145,.275,.075,.09),(-.075,.27,.072,.092),(0,.265,.074,.094),(.08,.265,.078,.09),(.15,.267,.075,.085),(.21,.265,.054,.075),(.25,.27,.012,.025)],'CatCoat')
    ellipsoid('Neck',(0,.306,-.243),(.052,.068,.068),'CatCoat','Chest')
    ellipsoid('Head',(0,.35,-.30),(.062,.063,.068),'CatHead','Head')
    ellipsoid('Chin',(0,.308,-.349),(.037,.019,.039),'CatCream','Jaw')
    for side in [-1,1]:
        label='L' if side<0 else 'R'
        ellipsoid('Muzzle'+label,(side*.022,.325,-.352),(.026,.022,.034),'CatCream','Head')
        ellipsoid('EyeRim'+label,(side*.036,.363,-.351),(.016,.011,.005),'Ink','Head')
        ellipsoid('Eye'+label,(side*.036,.364,-.356),(.013,.0085,.003),'Iris','Head')
        ellipsoid('Pupil'+label,(side*.036,.364,-.359),(.0018,.007,.0010),'Ink','Head',20,12)
        ellipsoid('Glint'+label,(side*.033,.367,-.360),(.0014,.0014,.0007),'EyeGlint','Head',12,8)
        # Ear wedge has a curved base and a thick, rounded apex.
        vertices=[(side*.018,.387,-.298),(side*.067,.379,-.27),(side*.061,.444,-.276),(side*.027,.39,-.25),(side*.068,.384,-.241),(side*.061,.442,-.257)]
        ear=mesh('Ear'+label,vertices,[(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(0,2,5,3)],[(0,0),(1,0),(.7,1),(0,0),(1,0),(.7,1)],[{'Ear'+label:1}]*6,'CatHead')
        bevel=ear.modifiers.new('Soft ear rim','BEVEL');bevel.width=.003;bevel.segments=3
        mesh('InnerEar'+label,[(side*.03,.394,-.299),(side*.061,.39,-.278),(side*.058,.430,-.278)],[(0,1,2)],[(0,0),(1,0),(.8,1)],[{'Ear'+label:1}]*3,'Pink')
        for kind,z in [('Front',-.18),('Back',.16)]:
            prefix=kind+label;aa,bb=rest[prefix+'_Upper'];cc=rest[prefix+'_Lower'][1]
            dd=rest[prefix+'_Foot'][1]
            tube(prefix+'_Leg',[aa,bb,cc,dd],[.028 if kind=='Front' else .045,.021,.012,.015],'CatCoat',[prefix+'_Upper',prefix+'_Lower',prefix+'_Foot',prefix+'_Foot'],24,6)
            ellipsoid(prefix+'_Paw',(side*.06,.025,z-.014),(.024,.022,.034),'CatCoat',prefix+'_Foot',24,14)
            for k in [-1,0,1]:
                ellipsoid(prefix+'_Toe%d'%k,(side*.06+k*.011,.023,z-.037),(.007,.011,.014),'CatCoat',prefix+'_Foot',12,8)
        for j in range(4):
            start=(side*.026,.319-j*.002,-.374)
            end=(side*(.094+j*.009),.316+(j-1)*.010,-.391+j*.002)
            tube('Whisker'+label+str(j),[start,mix(start,end,.5)+Vector((0,.002,-.002)),end],[.00048,.00035,.00010],'Whisker',['Head']*3,6,3)
    mesh('Nose',[(-.010,.337,-.385),(.010,.337,-.385),(0,.328,-.391),(0,.340,-.378)],[(0,1,2),(0,3,1),(1,3,2),(2,3,0)],[(0,0),(1,0),(.5,1),(.5,.5)],[{'Head':1}]*4,'Pink')
    tube('Mouth',[(0,.326,-.381),(0,.319,-.380),(-.01,.317,-.377)],[.0008,.0007,.0004],'Ink',['Jaw']*3,6,3)
    tube('Tail',tail,[.022,.021,.019,.017,.015,.012,.002],'CatCoat',['Tail%d'%min(i,5) for i in range(7)],24,5)
    bind()

def cat_pose(mode,u,t):
    sit=1 if mode=='sit' else (smooth(u) if mode=='sit_down' else (1-smooth(u) if mode=='stand_up' else 0))
    lie=1 if mode in ('lie','lick') else (smooth(u) if mode=='lie_down' else (1-smooth(u) if mode=='rise' else 0))
    chest=Vector((0,-.175*lie,0));hip=Vector((0,-.155*sit-.17*lie,.018*sit))
    chest+=Vector((0,-.025*sit,.11*sit))
    if mode in ('walk','trot'):
        chest.y-=.020 if mode=='walk' else .035;hip.y-=.015 if mode=='walk' else .025
    if mode=='stretch':
        stretch=math.sin(math.pi*u)**2;chest.y-=.125*stretch;hip.y+=.025*stretch;chest.z-=.045*stretch
    else:stretch=0
    breath=math.sin(TAU*u)*.0015
    chest.y+=breath;hip.y+=breath*.6
    shift_bone('Chest',chest);shift_bone('Hips',hip)
    head=chest+Vector((0,.035*sit+.034*lie,-.02*lie))
    yaw=math.sin(TAU*u)*.10 if mode in ('idle','observe') else 0
    if mode=='observe':yaw=math.sin(TAU*u)*.43
    shift_bone('Head',head,rot=(.12*lie,0,yaw));follow_bone('Jaw','Head')
    for side in [-1,1]:
        label='L' if side<0 else 'R'
        follow_bone('Ear'+label,'Head')
        from mathutils import Quaternion
        ear=rig.pose.bones['Ear'+label]
        ear.rotation_quaternion=ear.rotation_quaternion@Quaternion((0,1,0),side*(.12 if mode=='observe' else .025)*math.sin(TAU*u+.7))
        for kind,z in [('Front',-.18),('Back',.16)]:
            prefix=kind+label
            off=chest if kind=='Front' else hip
            shoulder=rest[prefix+'_Upper'][0]+off
            foot=Vector((side*.06,.022,z-.014))
            if kind=='Front':foot.z+=.03*sit
            if mode in ('walk','trot'):
                phase=(u+({'FrontL':0,'BackR':0,'FrontR':.50,'BackL':.50}[prefix] if mode=='trot' else {'FrontL':0,'BackL':.20,'FrontR':.50,'BackR':.70}[prefix]))%1
                duty=.64 if mode=='walk' else .52;stride=.16 if mode=='walk' else .235
                if phase<duty:foot.z+=stride*(phase/duty-.5)
                else:
                    q=(phase-duty)/(1-duty);foot.z+=stride*(.5-smooth(q));foot.y+=(.028 if mode=='walk' else .042)*math.sin(math.pi*q)
            if kind=='Back' and (sit or lie):foot.x=side*(.06+.025*max(sit,lie));foot.z+=.025*lie
            if kind=='Front' and lie:foot.z-=.07*lie
            if mode=='stretch' and kind=='Front':foot.z-=.11*stretch
            if mode=='lick' and prefix=='FrontR':foot=Vector((.04,.125,-.34));head+=Vector((.018,-.013,-.015));shift_bone('Head',head,rot=(-.35+math.sin(t*7)*.04,0,0))
            l1=(rest[prefix+'_Upper'][1]-rest[prefix+'_Upper'][0]).length;l2=(rest[prefix+'_Lower'][1]-rest[prefix+'_Lower'][0]).length
            limb_pose(prefix,shoulder,foot,l1,l2,(0,0,1 if kind=='Front' else -1))
    for i in range(6):
        offset=hip+Vector((math.sin(TAU*u+i*.43)*.012,0,0))
        shift_bone('Tail%d'%i,offset,rot=(0,.03*math.sin(TAU*u+i*.3),0))

def bird_bones(species):
    duck=species=='duck';scale=1 if duck else .24
    bone('Root',(0,0,0),(0,.045*scale,0))
    if duck:
        bone('Chest',(0,.215,-.09),(0,.255,-.13),'Root');bone('Hips',(0,.215,.10),(0,.215,.17),'Root')
        bone('Neck',(0,.265,-.15),(0,.365,-.17),'Chest');bone('Head',(0,.365,-.17),(0,.42,-.215),'Neck')
        bone('Tail',(0,.22,.205),(0,.235,.31),'Hips')
    else:
        bone('Chest',(0,.075,-.005),(0,.094,-.028),'Root');bone('Hips',(0,.072,.034),(0,.074,.06),'Root')
        bone('Head',(0,.107,-.025),(0,.126,-.043),'Chest');bone('Tail',(0,.073,.049),(0,.059,.104),'Hips')
    for side in [-1,1]:
        s='L' if side<0 else 'R'
        if duck:a=(side*.082,.25,-.067);b=(side*.102,.23,.085);c=(side*.089,.20,.225)
        else:a=(side*.027,.092,-.01);b=(side*.035,.085,.034);c=(side*.028,.063,.077)
        bone('Wing'+s,a,b,'Chest');bone('WingTip'+s,b,c,'Wing'+s)
        if duck:a=(side*.055,.18,.042);b=(side*.055,.085,.064);c=(side*.055,.012,.035)
        else:a=(side*.018,.061,.014);b=(side*.018,.030,.016);c=(side*.018,.005,.006)
        bone('Leg'+s,a,b,'Hips');bone('Foot'+s,b,c,'Leg'+s)

def bird_model(kind,sex='male'):
    duck=kind=='duck';begin('WildlifeMallard' if duck else 'WildlifeSparrow');bird_bones(kind);end_bones()
    material('Ink',(.022,.025,.022),rough=.32);material('Highlight',(.88,.85,.72),rough=.25)
    material('Cream',(1,1,1),'bird_cream');material('Orange',(.81,.36,.067));material('Blue',(.08,.15,.36),rough=.3)
    if duck:
        material('Body',(1,1,1),'duck_gray' if sex=='male' else 'duck_female')
        material('Breast',(1,1,1),'duck_brown' if sex=='male' else 'duck_female')
        material('Head',(1,1,1),'duck_green' if sex=='male' else 'duck_female_head',.32 if sex=='male' else .72)
        material('Bill',(.70,.59,.12) if sex=='male' else (.55,.38,.17),rough=.56)
        body('Torso',[(-.23,.24,.012,.024),(-.185,.235,.060,.078),(-.13,.23,.092,.099),(-.06,.219,.108,.113),(.025,.214,.111,.110),(.10,.215,.098,.095),(.17,.219,.076,.072),(.225,.227,.046,.035),(.27,.235,.007,.008)],'Body')
        ellipsoid('Breast',(0,.24,-.140),(.085,.090,.108),'Breast','Chest')
        tube('Neck',[(0,.267,-.153),(0,.305,-.17),(0,.356,-.169),(0,.393,-.184)],[.052,.038,.032,.041],'Head',['Neck','Neck','Head','Head'],32,6)
        if sex=='male':tube('WhiteCollar',[(0,.310,-.171),(0,.326,-.170)],[.0385,.0355],'Cream',['Neck','Neck'],32,3)
        ellipsoid('Head',(0,.412,-.198),(.048,.052,.063),'Head','Head')
        # Flattened bill: thick upper/lower surfaces, no paper triangle.
        body_bill=[(-.247,.399,.029,.010),(-.27,.396,.034,.008),(-.303,.392,.028,.006),(-.317,.392,.006,.003)]
        vertices=[];uv=[];faces=[]
        for j,(z,y,rx,ry) in enumerate(body_bill):
            for i in range(25):
                a=TAU*i/24;vertices.append((math.cos(a)*rx,y+math.sin(a)*ry,z));uv.append((j/3,i/24))
        for j in range(3):
            for i in range(24):
                a=j*25+i;faces.append((a,a+1,a+26,a+25))
        mesh('Bill',vertices,faces,uv,[{'Head':1}]*len(vertices),'Bill')
        for side in [-1,1]:
            s='L' if side<0 else 'R'
            ellipsoid('Eye'+s,(side*.041,.422,-.224),(.0068,.0074,.0068),'Ink','Head',20,14)
            ellipsoid('Glint'+s,(side*.044,.425,-.228),(.0015,.0015,.0015),'Highlight','Head',12,8)
            ellipsoid('Nostril'+s,(side*.019,.401,-.279),(.0034,.0017,.004),'Ink','Head',16,10)
            aa,bb=rest['Leg'+s];cc=rest['Foot'+s][1]
            tube('Leg'+s,[aa,bb,cc],[.012,.009,.006],'Orange',['Leg'+s,'Foot'+s,'Foot'+s],14,4)
            footverts=[(side*.055,.01,.047),(side*.055-.026,.009,-.007),(side*.055,.006,-.024),(side*.055+.026,.009,-.007),(side*.055,.014,.022)]
            mesh('WebFoot'+s,footverts,[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],[(.5,1),(0,0),(.5,0),(1,0),(.5,.5)],[{'Foot'+s:1}]*5,'Orange')
            for j in range(9):
                z=-.05+j*.021
                feather('WingVane'+s+str(j),(side*.086,.278-j*.004,z),(side*(.096-j*.002),.201-j*.001,z+.135),.022,'Body','Wing'+s)
            for j in range(4):
                feather('Speculum'+s+str(j),(side*.103,.221-j*.004,.080+j*.018),(side*.100,.200-j*.004,.157+j*.019),.013,'Blue','WingTip'+s)
            feather('WingBar'+s,(side*.109,.232,.062),(side*.107,.210,.127),.009,'Cream','Wing'+s)
        for j in range(7):feather('Tail'+str(j),((j-3)*.007,.238,.206),((j-3)*.012,.244,.308),.009,'Body','Tail')
    else:
        material('Body',(1,1,1),'sparrow_back');material('Head',(1,1,1),'sparrow_head');material('Foot',(.48,.32,.23))
        body('Torso',[(-.045,.083,.007,.014),(-.032,.083,.026,.033),(-.010,.078,.032,.038),(.016,.075,.032,.033),(.040,.075,.022,.022),(.061,.074,.007,.009)],'Body')
        ellipsoid('Breast',(0,.076,-.017),(.025,.034,.031),'Cream','Chest')
        ellipsoid('Head',(0,.117,-.031),(.025,.027,.030),'Head','Head')
        for side in [-1,1]:
            s='L' if side<0 else 'R'
            ellipsoid('Eye'+s,(side*.021,.122,-.048),(.0028,.0032,.0026),'Ink','Head')
            ellipsoid('Glint'+s,(side*.023,.123,-.049),(.0005,.0005,.0004),'Highlight','Head',12,8)
            aa,bb=rest['Leg'+s];cc=rest['Foot'+s][1]
            tube('Leg'+s,[aa,bb,cc],[.0025,.0018,.0012],'Foot',['Leg'+s,'Foot'+s,'Foot'+s],10,4)
            for j in [-1,0,1]:tube('Toe'+s+str(j),[cc,(side*.018+j*.005,.004,-.007),(side*.018+j*.007,.003,-.016)],[.0011,.00085,.0003],'Foot',['Foot'+s]*3,8,3)
            tube('BackToe'+s,[cc,(side*.018,.003,.028)],[.0011,.0004],'Foot',['Foot'+s]*2,8,3)
            for j in range(8):
                feather('Primary'+s+str(j),(side*.027,.101-j*.003,-.004+j*.006),(side*(.037-j*.0015),.071-j*.001,.066+j*.002),.0055,'Body','WingTip'+s if j>3 else 'Wing'+s)
            for j in range(4):feather('Covert'+s+str(j),(side*.029,.103-j*.005,-.008),(side*.040,.085-j*.003,.038),.006,'Body','Wing'+s)
            for z in [.012,.030]:feather('WhiteWingBar'+s+str(z),(side*.033,.098,z),(side*.039,.087,z+.018),.004,'Cream','Wing'+s)
        # Conical seed-eating bill; the upper and lower profiles meet at the tip.
        mesh('Beak',[(-.008,.112,-.057),(.008,.112,-.057),(0,.122,-.055),(0,.114,-.075),(0,.106,-.056)],[(0,2,3),(2,1,3),(1,4,3),(4,0,3)],[(0,0),(1,0),(.5,1),(.5,.5),(.5,0)],[{'Head':1}]*5,'Ink')
        for j in range(6):feather('Tail'+str(j),((j-2.5)*.003,.077,.046),((j-2.5)*.005,.060,.109),.004,'Body','Tail')
    bind()

def bird_pose(kind,mode,u,t):
    duck=kind=='duck';scale=1 if duck else .24
    bob=math.sin(TAU*u)*(.0015 if duck else .0007)
    root=Vector((0,bob,0))
    if mode=='hop':root.y+=math.sin(math.pi*u)*.030
    if mode=='takeoff':root.y-=math.sin(math.pi*u)*.008
    shift_bone('Chest',root);shift_bone('Hips',root);shift_bone('Tail',root,rot=(.02*math.sin(TAU*u),0,0))
    headrot=(0,0,0);headshift=root.copy()
    if mode=='observe':headrot=(0,0,math.sin(TAU*u)*.48)
    if mode=='peck':headrot=(.75*math.sin(math.pi*u)**2,0,0);headshift+=Vector((0,-.028*math.sin(math.pi*u)**2,-.015*math.sin(math.pi*u)**2))
    if mode=='preen':
        weight=math.sin(math.pi*u)**2
        headrot=(-.95*weight,0,-2.65*weight) if duck else (-.5*weight,0,-2.1*weight)
        headshift+=Vector((.014*weight if duck else .003*weight,0,.022*weight if duck else .006*weight))
    if duck:
        shift_bone('Neck',headshift,rot=headrot);follow_bone('Head','Neck')
    else:shift_bone('Head',headshift,rot=headrot)
    for side in [-1,1]:
        s='L' if side<0 else 'R'
        wingrot=(0,0,0)
        if mode in ('fly','takeoff','land'):
            strength=1 if mode=='fly' else smooth(u) if mode=='takeoff' else 1-smooth(u)
            wingrot=(.10*strength,side*math.sin(t*TAU*8)*.7*strength,side*1.25*strength)
        shift_bone('Wing'+s,root,rot=wingrot);follow_bone('WingTip'+s,'Wing'+s)
        legrot=(0,0,0);footrot=(0,0,0)
        if mode=='walk' and duck:
            phase=(u+(0 if side<0 else .5))%1;duty=.63;stride=.12
            foot=rest['Foot'+s][1].copy()
            if phase<duty:foot.z+=stride*(phase/duty-.5)
            else:
                q=(phase-duty)/(1-duty);foot.z+=stride*(.5-smooth(q));foot.y+=.025*math.sin(math.pi*q)
            a,b=rest['Leg'+s];c=rest['Foot'+s][1]
            knee=ik(a,foot,(b-a).length,(c-b).length,(0,0,1))
            transform_bone('Leg'+s,a,knee);transform_bone('Foot'+s,knee,foot)
            continue
        if mode=='walk':
            phase=(u+(0 if side<0 else .5))%1
            angle=math.sin(TAU*phase)*.32;legrot=(angle,0,0);footrot=(-angle*.6,0,0)
        elif mode=='swim':legrot=(math.sin(TAU*u+side*math.pi/2)*.42,0,0)
        elif mode in ('fly','takeoff'):legrot=(.55,0,0);footrot=(.3,0,0)
        shift_bone('Leg'+s,root,rot=legrot)
        if mode in ('fly','takeoff','swim'):follow_bone('Foot'+s,'Leg'+s)
        else:shift_bone('Foot'+s,root,rot=footrot)

def save_asset(name,clips):
    global meshes
    # Merge by material, retaining named vertex groups and a single skin modifier.
    merged=[]
    groups=[(mat,[o for o in meshes if o.data.materials[0]==mat]) for mat in M.values()]
    for mat,group in groups:
        if not group:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in group:o.select_set(True)
        bpy.context.view_layer.objects.active=group[0]
        bpy.ops.object.join();o=bpy.context.object;o.name=mat.name+'_Skin';merged.append(o)
    meshes=merged
    if name=='sparrow_tree':rig.scale=(.8,.8,.8)
    reset_pose()
    if name=='cat_tabby':
        # Union shoulder/hip/limb surfaces. Restore UVs and skin weights from the
        # original anatomical mesh after voxel remeshing; no detached limb caps.
        o=next(o for o in meshes if o.data.materials[0]==M['CatCoat'])
        original=o.copy();original.data=o.data.copy();original.name='ConstructionCoat';bpy.context.collection.objects.link(original)
        original.hide_render=True;original.hide_set(True)
        for modifier in list(original.modifiers):original.modifiers.remove(modifier)
        for modifier in list(o.modifiers):o.modifiers.remove(modifier)
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        remesh=o.modifiers.new('Anatomical surface union','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.0035;remesh.use_smooth_shade=True
        bpy.ops.object.modifier_apply(modifier=remesh.name)
        smoothing=o.modifiers.new('Surface relaxation','SMOOTH');smoothing.factor=.7;smoothing.iterations=3
        bpy.ops.object.modifier_apply(modifier=smoothing.name)
        transfer=o.modifiers.new('Restore skin and UV','DATA_TRANSFER');transfer.object=original
        transfer.use_vert_data=True;transfer.data_types_verts={'VGROUP_WEIGHTS'};transfer.vert_mapping='POLYINTERP_NEAREST'
        transfer.use_loop_data=True;transfer.data_types_loops={'UV'};transfer.loop_mapping='POLYINTERP_NEAREST'
        bpy.ops.object.datalayout_transfer(modifier=transfer.name)
        bpy.ops.object.modifier_apply(modifier=transfer.name)
        simplify=o.modifiers.new('Game topology','DECIMATE');simplify.ratio=.28
        bpy.ops.object.modifier_apply(modifier=simplify.name)
        modifier=o.modifiers.new('Skin','ARMATURE');modifier.object=rig
    rig.animation_data.action=None
    for track in rig.animation_data.nla_tracks:track.mute=False
    reset_pose();bpy.context.scene.render.fps=FPS
    bpy.context.scene.frame_set(0)
    for im in bpy.data.images:
        if im.source=='FILE':im.pack()
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,
        export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,
        export_skins=True,export_all_influences=False,export_yup=True,export_apply=False)
    for track in rig.animation_data.nla_tracks:track.mute=True
    rig.animation_data.action=bpy.data.actions.get('idle')
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    return dict(asset=name,bones=len(rest),triangles=triangles,clips=clips,
        meters=True,forward='-Z',up='+Y',root_motion=False,skin='armature',source=str(SOURCE/(name+'.blend')))

reports=[]
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
targets=args or ['cat','duck','sparrow']
if 'cat' in targets:
    cat_model();clips=[]
    for name,seconds in [('idle',4),('walk',.96),('trot',.56),('sit_down',1.2),('sit',4),('stand_up',1.1),('lie_down',1.5),('lie',4),('rise',1.2),('stretch',2.6),('lick',3),('observe',2.4)]:
        clips.append(action(name,seconds,lambda u,t,n=name:cat_pose(n,u,t)))
    reports.append(save_asset('cat_tabby',clips))
if 'duck' in targets:
    for sex in ['male','female']:
        bird_model('duck',sex);clips=[]
        for name,seconds in [('idle',4),('walk',.85),('swim',1.6),('enter_water',1.2),('exit_water',1.2),('preen',3.2),('rest',4),('observe',2.4)]:
            clips.append(action(name,seconds,lambda u,t,n=name:bird_pose('duck','walk' if n in ('enter_water','exit_water') else n,u,t)))
        reports.append(save_asset('mallard_'+sex,clips))
if 'sparrow' in targets:
    bird_model('sparrow');clips=[]
    for name,seconds in [('idle',3),('peck',.8),('hop',.28),('takeoff',.30),('fly',.5),('land',.40),('preen',2.4),('observe',1.8)]:
        clips.append(action(name,seconds,lambda u,t,n=name:bird_pose('sparrow',n,u,t)))
    reports.append(save_asset('sparrow_tree',clips))
manifest_path=OUT/'manifest.json'
prior=json.loads(manifest_path.read_text()) if manifest_path.exists() else {'assets':[]}
changed={a['asset'] for a in reports};prior['assets']=[a for a in prior['assets'] if a['asset'] not in changed]+reports
prior.update(dict(version=1,texture_origin='Original procedural brush textures; reference photos excluded',animation_fps=FPS))
manifest_path.write_text(json.dumps(prior,ensure_ascii=False,indent=2),encoding='utf-8')
print('WILDLIFE_BUILD_OK',[(a['asset'],a['triangles'],a['bones']) for a in reports])
