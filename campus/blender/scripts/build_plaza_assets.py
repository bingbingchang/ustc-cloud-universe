"""Independent, photographed plaza landmarks. Does not read or rebuild the campus.

Coordinates are Godot (x, up, z), local ground origin, front -Z. Blender=(x,-z,y).
Run D:/productivity/blender.exe -b --python build_plaza_assets.py [-- --proof]
Photographs are shape references, never used as textures.
"""
from pathlib import Path
import bpy, bmesh, math, json, sys
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'
M, groups = {}, {}
active = 'CafeStructure'
ASSET = 'Cafe'

def material(name, color, roughness=.8, metallic=0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*color, 1)
    bs = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = roughness
    bs.inputs['Metallic'].default_value = metallic
    M[name] = m

for name, color, rough, metal in [
    ('NorthGateIvory', (.69,.68,.61), .82, 0),
    ('NorthSoffit', (.62,.64,.58), .8, 0),
    ('NorthJoint', (.39,.42,.38), .85, 0),
    ('NorthCourtWood', (.29,.23,.17), .80, 0),
    ('Stone', (.60,.60,.54), .9, 0),
    ('Frame', (.10,.14,.13), .60, .15),
    ('Glass', (.10,.18,.18), .20, .22),
    ('GlassLight', (.18,.28,.27), .28, .1),
    ('Metal', (.10,.135,.12), .65, .42),
    ('Wood', (.32,.235,.16), .82, 0),
    ('Trunk', (.20,.18,.12), .95, 0),
    ('Leaf', (.25,.35,.15), .9, 0),
    ('LeafLight', (.34,.43,.19), .9, 0),
    ('PlazaCanvas', (.66,.62,.48), .9, 0),
    ('PlazaBronze', (.31,.29,.20), .57, .62),
    ('PlazaBronzeDetail', (.22,.215,.155), .65, .5),
    ('PlazaBronzeHighlight', (.35,.33,.235), .53, .65),
    ('PlazaGranite', (.36,.355,.32), .83, 0),
    ('Letter', (.32,.30,.22), .8, 0),
]:
    material(name, color, rough, metal)

def pt(p):
    return p[0], -p[2], p[1]

def geo(verts, faces, mat):
    key = (ASSET, active, mat)
    vs, fs = groups.setdefault(key, ([], []))
    n = len(vs)
    vs.extend(pt(p) for p in verts)
    fs.extend(tuple(n+i for i in face) for face in faces)

def box(c, s, mat):
    x,y,z = c
    a,b,d = (t/2 for t in s)
    v = [(x+dx*a,y+dy*b,z+dz*d) for dx,dy,dz in
         [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
          (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    geo(v, [(0,3,2,1),(4,5,6,7),(0,1,5,4),
            (3,7,6,2),(0,4,7,3),(1,2,6,5)], mat)

def tube(a,b,r1,r2,mat,n=12):
    a,b = Vector(a),Vector(b)
    w = (b-a).normalized()
    u = w.cross(Vector((0,1,0)))
    if u.length < .01:
        u = w.cross(Vector((1,0,0)))
    u.normalize()
    v = w.cross(u)
    vs = [p+r*(math.cos(i*math.tau/n)*u+math.sin(i*math.tau/n)*v)
          for p,r in [(a,r1),(b,r2)] for i in range(n)]
    fs = [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    geo(vs,fs,mat)

def ellipsoid(c,s,mat,seg=20,rings=12):
    vs = []
    for j in range(rings+1):
        t = math.pi*j/rings
        for i in range(seg):
            p = math.tau*i/seg
            vs.append((c[0]+s[0]*math.sin(t)*math.cos(p),
                       c[1]+s[1]*math.cos(t),
                       c[2]+s[2]*math.sin(t)*math.sin(p)))
    geo(vs,[(j*seg+i,j*seg+(i+1)%seg,(j+1)*seg+(i+1)%seg,
             (j+1)*seg+i) for j in range(rings) for i in range(seg)],mat)

def sweep(points,radius,mat,n=10):
    ps = [Vector(p) for p in points]
    rr = radius if isinstance(radius,list) else [radius]*len(ps)
    vs = []
    for j,p in enumerate(ps):
        w = (ps[min(j+1,len(ps)-1)]-ps[max(0,j-1)]).normalized()
        u = w.cross(Vector((0,1,0)))
        if u.length < .01:
            u = w.cross(Vector((1,0,0)))
        u.normalize()
        v = w.cross(u)
        for i in range(n):
            vs.append(p+rr[j]*(math.cos(i*math.tau/n)*u+math.sin(i*math.tau/n)*v))
    fs = [tuple(range(n-1,-1,-1)),tuple((len(ps)-1)*n+k for k in range(n))]
    fs += [(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i)
           for j in range(len(ps)-1) for i in range(n)]
    geo(vs,fs,mat)

def profile(rings,mat,n=32):
    # (height, half-width, half-depth, center-x, center-z)
    vs = []
    for y,rx,rz,cx,cz in rings:
        vs += [(cx+rx*math.cos(i*math.tau/n),y,cz+rz*math.sin(i*math.tau/n))
               for i in range(n)]
    fs = [tuple(range(n-1,-1,-1)),tuple((len(rings)-1)*n+i for i in range(n))]
    fs += [(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i)
           for j in range(len(rings)-1) for i in range(n)]
    geo(vs,fs,mat)

def inscription(body,p,size,mat,rotation=(math.pi/2,0,math.pi)):
    cv = bpy.data.curves.new('Plaza inscription','FONT')
    cv.body,cv.size,cv.align_x,cv.extrude = body,size,'CENTER',.004
    cv.resolution_u = 4
    cv.space_character = 1.05
    font = 'C:/Windows/Fonts/simkai.ttf' if any(ord(c)>255 for c in body) else 'C:/Windows/Fonts/arial.ttf'
    cv.font = bpy.data.fonts.load(font)
    ob = bpy.data.objects.new(ASSET+'_Inscription_'+body,cv)
    bpy.context.collection.objects.link(ob)
    ob.location,ob.rotation_euler = pt(p),rotation
    cv.materials.append(M[mat])
    ob['asset'] = ASSET
    ob['asset_group'] = active
    return ob

# Cafe is a one-storey, low pale ribbed pavilion, observed in the official
# admissions photo. Its curtain windows and white square posts are retained.
# The 19 x 9 m building envelope comes from the supplied OSM footprint estimate.
ASSET,active = 'Cafe','CafeStructure'
box((0,.11,0),(19.2,.22,9.2),'Stone')
box((0,1.64,0),(19,3.06,9),'NorthSoffit')
# Window dark reveals are exterior overlays onto the opaque shell; this pass
# is an exterior landmark, so there is no false playable interior doorway.
for x,width in [(-5.6,3.55),(-1.6,3.55),(2.45,3.7)]:
    box((x,2.01,-4.51),(width,2.03,.06),'Frame')
    box((x,2.02,-4.56),(width-.12,1.88,.055),'Glass')
    box((x,2.02,-4.59),(width-.25,.045,.035),'Frame')
    box((x,1.91,-4.61),(.055,1.95,.045),'Frame')
    box((x,1.015,-4.63),(width+.12,.105,.25),'Frame')
    # Clear dark panes, soft reflection band, fine interior light shapes.
    box((x,2.53,-4.60),(width-.20,.07,.022),'GlassLight')
    for dx in [-.7,.7]:
        tube((x+dx,2.68,-4.635),(x+dx+.30,2.68,-4.635),.022,.022,'PlazaCanvas',12)
# Entry left, a glass door beneath the continuous fascia.
box((-8.2,1.51,-4.55),(1.12,2.55,.08),'Frame')
box((-8.2,1.52,-4.61),(.99,2.39,.035),'Glass')
for x in [-8.73,-7.68]:
    box((x,1.51,-4.65),(.045,2.5,.035),'Frame')
box((-7.86,1.47,-4.70),(.025,.32,.045),'Metal')
for x in [-9.08,-7.56,-3.57,.42,4.52]:
    box((x,1.70,-4.70),(.31,3.18,.42),'NorthGateIvory')
    box((x,.17,-4.72),(.37,.20,.48),'Stone')
    box((x,2.04,-4.93),(.09,.21,.035),'Metal')
# Broad fascia, deep soffit, short rearward roof and a fine edge cap.
box((0,3.33,0),(19.35,.61,9.35),'NorthSoffit')
box((0,3.65,0),(19.55,.08,9.56),'NorthGateIvory')
box((0,3.04,-4.71),(19.42,.12,.50),'NorthGateIvory')
box((0,3.64,.16),(19.15,.07,8.90),'NorthJoint')
active = 'CafeCladding'
# Thin light corrugations, consistent with the photographed metal facade.
for i in range(119):
    x = -9.38+i*.159
    for z in [-4.715,4.705]:
        box((x,3.34,z),(.025,.55,.043),'NorthGateIvory')
    box((x,1.64,4.515),(.026,2.98,.045),'NorthGateIvory')
for side in [-1,1]:
    for i in range(58):
        z = -4.40+i*.155
        box((side*9.515,1.64,z),(.045,2.98,.026),'NorthGateIvory')
        box((side*9.72,3.34,z),(.035,.55,.025),'NorthGateIvory')
for i in range(28):
    x = 4.76+i*.16
    box((x,1.64,-4.516),(.025,2.96,.05),'NorthGateIvory')
# Small rear windows keep the building's four-sided mass readable.
for x in [-5.8,-1.9,2.0]:
    box((x,1.93,4.55),(2.6,1.20,.055),'Frame')
    box((x,1.93,4.60),(2.48,1.08,.04),'Glass')
    box((x,1.93,4.635),(.04,1.1,.028),'Frame')
active = 'CafeSigns'
inscription('USTC',(6.90,1.60,-4.56),.91,'Frame')
inscription('1958',(6.90,.90,-4.56),.46,'Frame')
inscription('COFFEE',(-5.6,2.65,-4.65),.22,'PlazaCanvas')
# Right flank letters echo the oversize outline U seen in the official photo.
inscription('USTC',(9.57,1.56,0),1.18,'Frame',rotation=(math.pi/2,0,math.pi/2))
inscription('1958',(9.57,.84,0),.54,'Frame',rotation=(math.pi/2,0,math.pi/2))

# Restrained timber apron and garden furniture. These make the photo's outdoor
# coffee court legible at player scale without adding a whole landscape layer.
active = 'CafeTerrace'
box((-1.4,.07,-5.59),(17.1,.14,2.12),'NorthCourtWood')
for i in range(54):
    x = -9.79+i*.316
    box((x,.148,-5.59),(.007,.009,2.06),'NorthJoint')
box((-5.6,.043,-6.89),(5.4,.086,.46),'Wood')
box((-5.6,.025,-7.24),(5.4,.05,.27),'Wood')

def chair(x,z,a):
    def p(lx,y,lz):
        return x+lx*math.cos(a)+lz*math.sin(a),y,z-lx*math.sin(a)+lz*math.cos(a)
    # Black outdoor frame, continuous rounded back and slim slatted seat.
    for lx in [-.23,.23]:
        for lz in [-.23,.23]:
            tube(p(lx,.15,lz),p(lx,.58,lz),.018,.018,'Metal',8)
        sweep([p(lx,.48,-.21),p(lx,.72,-.26),p(lx,.90,-.25),p(lx,1.0,-.18)],.021,'Metal',8)
        sweep([p(lx,.53,.20),p(lx,.77,.14),p(lx,.77,-.20)],.018,'Metal',8)
    sweep([p(-.23,1.0,-.18),p(0,1.035,-.20),p(.23,1.0,-.18)],.023,'Metal',8)
    for i in range(7):
        lx = -.195+i*.065
        tube(p(lx,.62,-.245),p(lx,.973,-.205),.012,.012,'Metal',6)
    for i in range(7):
        lz = -.185+i*.061
        aa,bb = p(-.22,.57,lz),p(.22,.57,lz)
        tube(aa,bb,.022,.022,'NorthCourtWood',6)

def cafe_table(x,z):
    tube((x,.15,z),(x,.93,z),.035,.035,'Metal',16)
    tube((x,.15,z),(x,.18,z),.32,.32,'Metal',24)
    tube((x,.93,z),(x,.985,z),.51,.51,'Metal',32)
    # One small cup supports close views with almost no rendering cost.
    tube((x-.10,.986,z),(x-.10,1.075,z),.033,.040,'NorthGateIvory',12)
    tube((x-.10,1.075,z),(x-.10,1.079,z),.031,.031,'Trunk',12)

active = 'CafeFurniture'
for x,z in [(-5.3,-5.9),(.1,-5.85),(5.3,-5.9)]:
    cafe_table(x,z)
    for dx,a in [(-.87,math.pi/2),(.87,-math.pi/2)]:
        chair(x+dx,z,a)

def umbrella(x,z,r=1.56):
    tube((x,.14,z),(x,2.64,z),.036,.029,'Wood',12)
    tube((x,.145,z),(x,.22,z),.34,.24,'Metal',16)
    n=12
    center=(x,2.62,z)
    verts=[center]
    # Three rings produce the softly bowed cloth of a garden sunshade.
    for ring in range(1,4):
        t=ring/3
        for k in range(n):
            a=k*math.tau/n
            yy=2.62-.34*t*t-.08*t
            verts.append((x+math.cos(a)*r*t,yy,z+math.sin(a)*r*t))
    fs=[(0,1+k,1+(k+1)%n) for k in range(n)]
    fs += [(1+j*n+k,1+j*n+(k+1)%n,1+(j+1)*n+(k+1)%n,1+(j+1)*n+k)
           for j in range(2) for k in range(n)]
    geo(verts,fs,'PlazaCanvas')
    for k in range(n):
        a=k*math.tau/n
        sweep([center,(x+math.cos(a)*r*.5,2.50,z+math.sin(a)*r*.5),
               (x+math.cos(a)*r,2.2,z+math.sin(a)*r)],.013,'Wood',6)
    tube((x,2.61,z),(x,2.72,z),.065,.025,'Wood',12)

for x in [-5.3,5.3]:
    umbrella(x,-5.9)

active = 'CafePlanters'
for x,z in [(-9.45,-5.65),(3.95,-4.96),(8.3,-5.44)]:
    box((x,.45,z),(1.0,.64,.74),'NorthSoffit')
    box((x,.779,z),(.86,.045,.61),'Trunk')
    for j in range(5):
        a=j*2.399
        c=(x+math.cos(a)*.28,1.02+.13*math.sin(j),z+math.sin(a)*.21)
        tube((x,.80,z),c,.025,.010,'Trunk',6)
        ellipsoid(c,(.36,.29,.28),'Leaf' if j%2 else 'LeafLight',12,7)

# Monument: the official newspaper photograph shows a full standing bronze
# figure with crossed arms and Zhongshan jacket. Do not substitute a bust.
# Portrait/detail proportions and the conservative pedestal height are estimated.
ASSET,active = 'Monument','MonumentBase'
box((0,.09,0),(2.7,.18,2.18),'PlazaGranite')
box((0,.24,0),(2.38,.14,1.95),'Stone')
box((0,.67,0),(1.77,.74,1.45),'PlazaGranite')
box((0,1.09,0),(1.97,.10,1.64),'Stone')
box((0,1.155,0),(1.86,.055,1.55),'PlazaGranite')
active = 'MonumentInscription'
inscription('郭沫若像',(0,.66,-.729),.30,'Stone')

active = 'MonumentFigure'
B = 'PlazaBronze'
# Shoes, softly creased straight trousers and the flared jacket hem.
for side in [-1,1]:
    x = side*.20
    ellipsoid((x,1.245,-.07),(.17,.086,.29),B,24,14)
    profile([(1.27,.145,.14,x,.02),(1.43,.14,.14,x,.06),
             (1.66,.17,.16,x,.075),(1.91,.18,.18,x,.04),
             (2.13,.19,.185,x*.84,.01)],B,28)
profile([(1.98,.42,.23,0,0),(2.11,.395,.24,0,0),
         (2.33,.37,.225,0,0),(2.56,.41,.235,0,0),
         (2.73,.47,.23,0,.01),(2.83,.42,.205,0,.02),
         (2.91,.21,.145,0,.015)],B,36)
# Thick sleeves, the foreground arm and its tucked hand observed in the photo.
for side in [-1,1]:
    sweep([(side*.40,2.74,.01),(side*.48,2.59,-.05),
           (side*.48,2.35,-.13)], [.16,.155,.145],B,20)
    ellipsoid((side*.47,2.35,-.13),(.145,.145,.16),B,20,12)
sweep([(-.48,2.35,-.14),(-.28,2.31,-.30),(.03,2.34,-.35),
       (.29,2.40,-.34)],[.145,.143,.125,.10],B,20)
sweep([(.48,2.37,-.15),(.29,2.46,-.31),(.01,2.48,-.37),
       (-.27,2.46,-.32)],[.14,.135,.115,.09],B,20)
ellipsoid((.31,2.42,-.325),(.12,.07,.07),B,20,12)
ellipsoid((-.29,2.455,-.30),(.115,.065,.067),B,20,12)
# Neck and calm broad face; modelled masses, not an asserted exact scan.
tube((0,2.89,.015),(0,3.07,.005),.115,.115,B,24)
ellipsoid((0,3.285,.005),(.225,.30,.218),B,32,20)
ellipsoid((0,3.115,-.079),(.168,.145,.148),B,28,16)
ellipsoid((0,3.17,-.157),(.16,.098,.075),B,28,16)
for side in [-1,1]:
    ellipsoid((side*.130,3.25,-.142),(.065,.088,.049),B,24,14)
    ellipsoid((side*.222,3.265,.017),(.041,.078,.041),B,20,12)
# Broad forehead, projecting nose and a quiet closed mouth.
ellipsoid((0,3.40,-.118),(.185,.126,.10),B,28,16)
sweep([(0,3.33,-.196),(0,3.235,-.245),(0,3.205,-.238)],
      [.028,.039,.043],B,14)
ellipsoid((0,3.145,-.219),(.080,.018,.013),B,24,10)
ellipsoid((0,3.123,-.218),(.073,.016,.014),B,24,10)

active = 'MonumentFineDetail'
for side in [-1,1]:
    # Lower eyelids and restrained brows provide silhouette and grazing light.
    sweep([(side*.035,3.30,-.208),(side*.082,3.314,-.218),
           (side*.131,3.30,-.197)],.011,'PlazaBronzeDetail',8)
    sweep([(side*.033,3.341,-.195),(side*.086,3.357,-.205),
           (side*.143,3.34,-.18)],.014,B,8)
    ellipsoid((side*.08,3.308,-.217),(.038,.010,.012),'PlazaBronzeDetail',16,8)
    # Collar points and narrow shoulder seams from the observed suit.
    geo([(side*.04,2.95,-.12),(side*.16,2.91,-.17),
         (side*.21,2.82,-.20),(side*.07,2.83,-.24)],[(0,1,2,3)],'PlazaBronzeHighlight')
    sweep([(side*.22,2.87,-.08),(side*.36,2.82,-.16),
           (side*.47,2.73,-.07)],.005,'PlazaBronzeDetail',6)
    sweep([(side*.19,1.39,-.08),(side*.18,1.68,-.087),
           (side*.17,1.93,-.135)],.008,'PlazaBronzeHighlight',6)
# Short sculpted hair, higher receding forehead as seen in the photograph.
hair_verts = []
hair_segments,hair_rings = 32,9
for j in range(hair_rings+1):
    for i in range(hair_segments):
        a = i*math.tau/hair_segments
        # A continuous short-hair cap, receding at the forehead, lower at back.
        limit = 1.33+.54*math.sin(a)
        t = limit*j/hair_rings
        hair_verts.append((.229*math.sin(t)*math.cos(a),
                           3.285+.304*math.cos(t),
                           .005+.222*math.sin(t)*math.sin(a)))
geo(hair_verts,[(j*hair_segments+i,j*hair_segments+(i+1)%hair_segments,
                (j+1)*hair_segments+(i+1)%hair_segments,(j+1)*hair_segments+i)
               for j in range(hair_rings) for i in range(hair_segments)],'PlazaBronzeDetail')
sweep([(-.067,3.145,-.235),(0,3.14,-.243),(.067,3.145,-.235)],
      .004,'PlazaBronzeDetail',6)
for y in [2.73,2.60,2.18,2.05]:
    ellipsoid((0,y,-.236),(.014,.014,.009),'PlazaBronzeHighlight',12,8)
sweep([(0,2.78,-.217),(0,2.64,-.237),(0,2.57,-.236)],.005,'PlazaBronzeDetail',6)
sweep([(0,2.27,-.236),(0,2.16,-.246),(0,1.99,-.237)],.005,'PlazaBronzeDetail',6)
# Lightly incised lower jacket pockets; upper pockets are covered by the arms.
for side in [-1,1]:
    x = side*.245
    sweep([(x-side*.08,2.16,-.23),(x+side*.08,2.16,-.23)],.005,'PlazaBronzeDetail',6)
    sweep([(x-side*.08,2.16,-.23),(x-side*.09,2.04,-.215),
           (x+side*.09,2.04,-.215),(x+side*.08,2.16,-.23)],.004,'PlazaBronzeDetail',6)

# Material batches keep the runtime draw count small. Statue masses are remeshed
# once and decimated into a continuous sculptural shape rather than loose spheres.
asset_objects = {'Cafe': [], 'Monument': []}
for (asset,group,mat),(vs,fs) in groups.items():
    me = bpy.data.meshes.new(group+'_'+mat)
    me.from_pydata(vs,[],fs)
    me.materials.append(M[mat])
    me.update()
    ob = bpy.data.objects.new(group+'_'+mat,me)
    bpy.context.collection.objects.link(ob)
    ob['asset'],ob['asset_group'] = asset,group
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.00002)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    if group == 'MonumentFigure':
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        mod = ob.modifiers.new('Continuous bronze sculpt', 'REMESH')
        mod.mode = 'VOXEL'
        mod.voxel_size = .014
        mod.use_smooth_shade = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        smooth = ob.modifiers.new('Sculpt polish', 'SMOOTH')
        smooth.factor,smooth.iterations = .35,3
        bpy.ops.object.modifier_apply(modifier=smooth.name)
        dec = ob.modifiers.new('Game sculpture', 'DECIMATE')
        dec.ratio = .12
        bpy.ops.object.modifier_apply(modifier=dec.name)
        ob.data.validate(clean_customdata=True)
        ob.data.update()
        ob.select_set(False)
    if group in ['MonumentFigure','MonumentFineDetail','CafeFurniture','CafePlanters']:
        for face in ob.data.polygons:
            face.use_smooth = True
    if group in ['CafeStructure','MonumentBase'] and mat not in ['Glass','GlassLight','Frame']:
        bev = ob.modifiers.new('Soft masonry edges','BEVEL')
        bev.width,bev.segments,bev.limit_method = .017,2,'ANGLE'
        normal = ob.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
        normal.keep_sharp = True
    asset_objects[asset].append(ob)
for ob in bpy.context.scene.objects:
    if ob.type == 'FONT':
        asset_objects[ob['asset']].append(ob)

# Combine equal materials after applying the few edge modifiers. This retains
# the authored pieces in the manifest and reduces 30 cafe surfaces to 14 draws.
asset_parts = {}
for asset,objs in list(asset_objects.items()):
    asset_parts[asset] = sorted(set(ob['asset_group'] for ob in objs))
    buckets = {}
    for ob in objs:
        bpy.ops.object.select_all(action='DESELECT')
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        if ob.type == 'FONT':
            bpy.ops.object.convert(target='MESH')
        for mod in list(ob.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        buckets.setdefault(ob.data.materials[0].name,[]).append(ob)
    combined = []
    for mat,obs in buckets.items():
        parts = sorted(set(ob['asset_group'] for ob in obs))
        bpy.ops.object.select_all(action='DESELECT')
        for ob in obs:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        if len(obs)>1:
            bpy.ops.object.join()
        ob = bpy.context.object
        ob.name = asset+'_'+mat
        ob['asset'] = asset
        ob['asset_group'] = ','.join(parts)
        ob.data.validate(clean_customdata=True)
        ob.data.update()
        combined.append(ob)
    asset_objects[asset] = combined
    collection = bpy.data.collections.new(asset+' local origin')
    bpy.context.scene.collection.children.link(collection)
    for ob in combined:
        for col in list(ob.users_collection):
            col.objects.unlink(ob)
        collection.objects.link(ob)

manifest = {
    'units':'meters',
    'coordinates':'Godot (X,up,Z); Blender=(X,-Z,up); ground origin; forward -Z',
    'observed_sources':[
        {'url':'https://zsb.ustc.edu.cn/xysj/list.htm','image':'https://zsb.ustc.edu.cn/_upload/article/images/af/ec/10b4e11e4f87959e1539bb3a0c45/11163d90-726c-4891-93e3-7d0751155dac.jpg','features':'Low pale vertical rib cladding, glass frontage, square posts, black window frames, wooden deck, black terrace furniture'},
        {'url':'https://zgkdb.ustc.edu.cn/ndetail/6404','image':'https://zgkdb.ustc.edu.cn/uploadfile/2020/1106/20201106024547590.jpg','features':'Coffee pavilion shape and northwest plaza position'},
        {'url':'https://zgkdb.ustc.edu.cn/ndetail/7454','image':'https://zgkdb.ustc.edu.cn/uploadfile/2022/0614/20220614042440279.jpg','features':'Standing full-length bronze, crossed arms, Zhongshan jacket and trousers'},
        {'url':'https://metalisotopes.ustc.edu.cn/news/MgCuFePbSiV.html','image':'https://metalisotopes.ustc.edu.cn/media/images/wwy/201104/small_IMG_2348%2820201104-210723%29.JPG','features':'Standing statue over stepped paved forecourt'},
        {'url':'https://m.baike.ustc.edu.cn/wiki/detail?id=394','features':'Monument at north of Guo plaza, facing south'},
        {'local':'references/buildings/东区1958咖啡.jpg','features':'Outdoor umbrellas, dark chairs, small round tables, garden setting'},
        {'local':'references/buildings/东区郭沫若广场.jpg','features':'Broad formal plaza and central water channel; parent scene handles landscape'}
    ],
    'confidence':'Observed facade type and statue pose high. Cafe 19 x 9 m footprint supplied from OSM approximation. Heights, exact facade bay spacings, statue portrait and pedestal estimated; first exterior/game-ready pass.',
    'assets':{},
}
for asset,filename in [('Cafe','plaza_cafe.glb'),('Monument','plaza_guo_monument.glb')]:
    objs = asset_objects[asset]
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objs:
        ob.select_set(True)
    path = ROOT/'godot/assets'/filename
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                             export_apply=True,export_yup=True,export_extras=True)
    deps = bpy.context.evaluated_depsgraph_get()
    verts, triangles = [],0
    for ob in objs:
        ev = ob.evaluated_get(deps)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        triangles += len(me.loop_triangles)
        verts += [ob.matrix_world@v.co for v in me.vertices]
        ev.to_mesh_clear()
    mini = [min(v[k] for v in verts) for k in range(3)]
    maxi = [max(v[k] for v in verts) for k in range(3)]
    manifest['assets'][asset] = {
        'file':'godot/assets/'+filename,
        'triangles':triangles,
        'objects':len(objs),
        'bounds_min':[mini[0],mini[2],-maxi[1]],
        'bounds_max':[maxi[0],maxi[2],-mini[1]],
        'parts':asset_parts[asset]
    }
manifest['assets']['Cafe'].update({
    'building_envelope':[19,3.70,9],
    'collision_suggestion':[
        {'type':'box','center':[0,1.80,0],'size':[19,3.60,9],'purpose':'Exterior-only building shell; entry is currently closed'},
        {'type':'box','center':[-1.4,.07,-5.59],'size':[17.1,.14,2.12],'purpose':'Walkable low wood apron'},
        {'type':'box','center':[-5.6,.043,-6.89],'size':[5.4,.086,.46],'purpose':'Low step'}],
    'optional_collisions':'Use single cylinders for each patio table and planter boxes; umbrellas and chair slats do not need individual physics shapes',
})
manifest['assets']['Monument'].update({
    'collision_suggestion':[
        {'type':'box','center':[0,.09,0],'size':[2.7,.18,2.18]},
        {'type':'box','center':[0,.67,0],'size':[1.77,.94,1.45]},
        {'type':'cylinder','center':[0,2.4,0],'radius':.54,'height':2.5}],
    'placement':'Rotate Y by PI in Godot to face geographic south; asset authored forward -Z',
})
mp = ROOT/'godot/assets/plaza_landmarks_manifest.json'
mp.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
source = ROOT/'blender/source/plaza_landmarks.blend'
source.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source))
print('PLAZA_LANDMARKS_OK',json.dumps(manifest['assets'],ensure_ascii=False))

if '--proof' in sys.argv:
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x,scene.render.resolution_y = 1500,1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'AgX'
    world = bpy.data.worlds.new('Plaza proof spring sky')
    world.use_nodes = True
    background = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    background.inputs[0].default_value = (.66,.74,.80,1)
    background.inputs[1].default_value = .7
    scene.world = world
    ld = bpy.data.lights.new('Plaza proof sun','SUN')
    ld.energy,ld.angle = 2,.12
    light = bpy.data.objects.new('Plaza proof sun',ld)
    bpy.context.collection.objects.link(light)
    light.rotation_euler = (.5,-.3,-.4)
    ad = bpy.data.lights.new('Plaza soft front','AREA')
    ad.energy,ad.size = 5000,12
    ao = bpy.data.objects.new('Plaza soft front',ad)
    bpy.context.collection.objects.link(ao)
    ao.location = pt((0,12,-16))
    ao.rotation_euler = (Vector(pt((0,1,0)))-ao.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.mesh.primitive_plane_add(size=200)
    ground = bpy.context.object
    ground.name = 'Proof ground only'
    ground.location.z = -.005
    ground.data.materials.append(M['Stone'])
    cd = bpy.data.cameras.new('Plaza proof camera')
    co = bpy.data.objects.new('Plaza proof camera',cd)
    bpy.context.collection.objects.link(co)
    scene.camera = co
    cd.lens = 52
    out = ROOT/'renders/plaza_expansion/assets'
    out.mkdir(parents=True,exist_ok=True)
    for asset,p,target in [('Cafe',(22,10,-26),(0,1.6,-1.5)),
                           ('Monument',(4.8,3.6,-7.5),(0,2,0))]:
        for key,obs in asset_objects.items():
            for ob in obs:
                ob.hide_render = key != asset
        co.location = pt(p)
        co.rotation_euler = (Vector(pt(target))-co.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath = str(out/(asset.lower()+'_blender.png'))
        bpy.ops.render.render(write_still=True)
    print('PLAZA_PROOFS_OK')
