"""Independent north-campus exterior assets from OSM footprints and observed references.

Absolute Godot metres: east X, up Y, south Z; Blender=(X,-Z,Y).
Run D:/productivity/blender.exe -b --python build_north_teaching.py -- --proof
Does not rebuild or modify accepted campus assets, roads, layouts, or gameplay.
"""
from pathlib import Path
from argparse import ArgumentParser
import bpy, bmesh, math, json, sys, xml.etree.ElementTree as ET
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

sys.path.insert(0,str(Path(__file__).resolve().parent))
from visit_exteriors import VISITS, door_spans

ROOT = Path(__file__).resolve().parents[2]
parser = ArgumentParser()
parser.add_argument('--teaching5-only', action='store_true')
parser.add_argument('--output-dir', type=Path, default=ROOT/'godot/assets')
parser.add_argument('--proof', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
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
    ('Teaching5EntryIvory',(.76,.735,.65),.86,0),
    ('Teaching5EntrySilver',(.48,.51,.50),.38,.55),
    ('Teaching5EntryBeam',(.30,.32,.32),.64,.20),
    ('Teaching5EntryPane',(.54,.62,.66),.18,.19),
    ('Teaching5EntryDoorPane',(.56,.64,.63),.19,.17),
    ('Teaching5EntryBlue',(.025,.24,.59),.48,0),
    ('Teaching5EntryGold',(.83,.51,.12),.35,.65),
    ('Teaching5EntryAtrium',(.39,.43,.44),.88,0),
    ('Teaching5EntryLanding',(.56,.55,.51),.86,0),
    ('Teaching5EntryDarkStone',(.16,.15,.14),.65,0),
    ('Teaching5EntryInterior',(.55,.54,.46),.82,0),
    ('Teaching5EntryInteriorShadow',(.095,.10,.09),.88,0),
    ('Teaching5EntryPaverJoint',(.34,.34,.31),.89,0),
    ('PhotoFacultyTerracotta',(.43,.153,.079),.87,0),
    ('PhotoFacultyGrey',(.355,.372,.367),.83,0),
    ('PhotoFacultyGlass',(.105,.22,.252),.21,.28),
    ('PhotoFacultyFrame',(.29,.321,.308),.43,.46),
    ('PhotoFacultyLightStone',(.52,.505,.462),.79,0),
    ('PhotoFacultyPaving',(.39,.389,.366),.85,0),
    ('PhotoWhiteLetters',(.74,.743,.70),.70,.06),
    ('PhotoDoorStripe',(.033,.19,.52),.51,0),
    ('PhotoDoorPull',(.47,.064,.044),.42,.21),
    ('PhotoVisitGlass',(.35,.46,.45),.23,.18),
]: material(name,col,rough,metal)

for name, alpha in [('Teaching5EntryPane', .31), ('Teaching5EntryDoorPane', .28), ('PhotoVisitGlass', .26)]:
    m = materials[name]
    m.diffuse_color[3] = alpha
    next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED').inputs['Alpha'].default_value = alpha
    m.surface_render_method = 'BLENDED'

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

def edgebox_around_opening(a,b,s0,s1,y0,y1,d0,d1,finish,opening):
    if not opening:
        edgebox(a,b,s0,s1,y0,y1,d0,d1,finish)
        return
    left,right,sill,head = opening
    lo,hi = max(s0,left),min(s1,right)
    low,high = max(y0,sill),min(y1,head)
    if hi <= lo or high <= low:
        edgebox(a,b,s0,s1,y0,y1,d0,d1,finish)
        return
    for x0,x1,height0,height1 in ((s0,s1,y0,low),(s0,s1,high,y1),(s0,lo,low,high),(hi,s1,low,high)):
        if x1-x0 > .00001 and height1-height0 > .00001:
            edgebox(a,b,x0,x1,height0,height1,d0,d1,finish)


def facade(poly,levels,height,wall,pitch=3.8,curtain_edges=(),blank_edges=(),entry_edge=-1,detail_edges=(),
           interior_storeys=False, ground_portal=None):
    global part
    if signed_area(poly)<0: poly=list(reversed(poly))
    storey=(height-.5)/levels; base=.26
    part='Structure'
    # Physical floor plates and facade piers create actual 22cm window reveals.
    visit = VISITS.get(asset)
    foundation_top = min(.26,visit["floor"]-.012) if interior_storeys and visit else .26
    slab(poly,.08,foundation_top,'EntryStone')
    for floor in range(levels+1):
        if interior_storeys and floor < levels:
            continue
        y=base+storey*floor
        if visit and visit["floor"]+.05 < y+.15 and y < visit["floor"]+visit["height"]:
            continue
        slab(poly,y,y+.15,'FacultyRoof' if floor==levels else wall)
    part='Facade'
    for e,(a,b) in enumerate(zip(poly,poly[1:]+poly[:1])):
        length=math.dist(a,b)
        opening = None
        if ground_portal and e == ground_portal[0]:
            wing = ground_portal[1]*.25
            opening = (length*.5-wing+.016, length*.5+wing-.016, .425, 2.66)

        def wall_member(s0,s1,y0,y1,d0,d1,finish):
            edgebox_around_opening(a,b,s0,s1,y0,y1,d0,d1,finish,opening)

        if e == entry_edge or e in detail_edges:
            continue
        if foundation_top < .26:
            wall_member(0,length,foundation_top,.26,-.16,.018,'EntryStone')
        if e in blank_edges:
            if e == 0:
                # Four pairs of narrow recessed openings near the outer side of the left wing.
                slots = [(length*.59,length*.59+.20),(length*.68,length*.68+.20)]
                band_start = base
                for story in range(4):
                    low = 2.45 + story*4.08
                    high = low+1.62
                    wall_member(0,length,band_start,low,-.36,.018,'Teaching5EntryIvory')
                    spans = [0,*[edge for slot in slots for edge in slot],length]
                    for start,end in zip(spans[::2],spans[1::2]):
                        wall_member(start,end,low,high,-.36,.018,'Teaching5EntryIvory')
                    for start,end in slots:
                        wall_member(start,end,low,high,-.31,-.29,'Teaching5EntryInteriorShadow')
                    band_start = high
                wall_member(0,length,band_start,height,-.36,.018,'Teaching5EntryIvory')
            else:
                wall_member(0,length,base,height,-.36,.018,'Teaching5EntryIvory')
            wall_member(0,length,height-.05,height+.39,-.33,.025,'Teaching5EntryIvory')
            wall_member(0,length,height+.37,height+.50,-.39,.085,'Teaching5EntrySilver')
            continue
        if length<1.5:
            wall_member(0,length,base,height,-.36,.015,wall); continue
        curtain=e in curtain_edges
        if curtain:
            wall_member(0,length,.30,height-.15,-.25,-.21,'WindowGlassLight')
            for k in range(math.ceil(length/1.38)+1):
                s=min(k*1.38,length)
                wall_member(max(0,s-.035),min(length,s+.035),.28,height-.12,-.23,.03,'WindowAluminium')
            for floor in range(levels):
                y=base+floor*storey
                for yy,w in [(y+.15,.105),(y+storey*.56,.04)]:
                    wall_member(0,length,yy,yy+w,-.22,.03,'WindowAluminium')
            continue
        if length<3.2:
            wall_member(0,length,base,height,-.36,.015,wall); continue
        count=max(1,int(length/pitch)); bay=length/count
        for floor in range(levels):
            y=base+floor*storey
            winbot=y+(1.05 if floor else .84); wintop=y+storey-.56
            wall_member(0,length,y+.15,winbot,-.36,.015,wall)
            wall_member(0,length,wintop,y+storey,-.36,.015,wall)
            wall_member(0,length,y+storey-.08,y+storey+.05,-.40,.11,'Teaching5TileJoint' if asset=='Teaching5' else 'FacultyDarkPanel')
            for k in range(count):
                s0=k*bay; s1=(k+1)*bay; pier=min(.66,bay*.22)
                lo,hi=s0+pier/2,s1-pier/2
                wall_member(s0,lo,winbot,wintop,-.36,.015,wall)
                wall_member(hi,s1,winbot,wintop,-.36,.015,wall)
                wall_member(lo,hi,winbot,wintop,-.245,-.217,'WindowGlassLight' if (k+floor)%7==0 else 'WindowGlass')
                frame='WindowAluminium' if asset=='Teaching5' else 'WindowRubber'
                for s in [lo,(lo+hi)/2,hi]:
                    wall_member(s-.027,s+.027,winbot,wintop,-.27,-.17,frame)
                wall_member(lo,hi,winbot,winbot+.065,-.28,.055,'WindowAluminium')
                wall_member(lo,hi,wintop-.065,wintop,-.28,-.16,frame)
                # Top-hung ventilation transom and return depth are readable on foot.
                wall_member(lo,hi,wintop-.53,wintop-.49,-.265,-.16,frame)
                for s in [lo,hi]:
                    wall_member(s-.035,s+.035,winbot,wintop,-.26,.018,'WindowReveal')
        part='Roof'
        wall_member(0,length,height-.34,height+.40,-.32,.01,wall)
        wall_member(0,length,height+.38,height+.49,-.38,.09,'Teaching5TileJoint')
        part='Facade'
    solids.append({'name':asset+'_closed_exterior','type':'polygon_prism','polygon':poly,'bottom':.08,'top':height+.5})
    return poly

def ensure_door_glass():
    from mapped_landmark_details import MATERIALS, install_photo_materials
    if "PhotoDoorGlass" not in materials:
        install_photo_materials(material,materials,{"DoorGlass":MATERIALS["DoorGlass"]})

def entry(a,b,width=8.2,steps=3,caption=''):
    global part
    part='Entrance'
    ensure_door_glass()
    length=math.dist(a,b); mid=length/2; ux=(b[0]-a[0])/length; uz=(b[1]-a[1])/length
    nx,nz=uz,-ux
    def p(s,y,d): return (a[0]+ux*s+nx*d,y,a[1]+uz*s+nz*d)
    edgebox(a,b,mid-width/2,mid+width/2,.25,4.02,-2.25,-2.18,'WindowReveal')
    edgebox(a,b,mid-width/2,mid+width/2,.32,.43,-2.18,-.04,'EntryStone')
    for start,end in ((mid-width/2+.13,mid-width/4),(mid+width/4,mid+width/2-.13)):
        edgebox(a,b,start,end,.43,3.79,-.18,.14,'WindowGlass')
    edgebox(a,b,mid-width/4,mid+width/4,.43,2.66,-.03,.14,'PhotoDoorGlass')
    edgebox(a,b,mid-width/4,mid+width/4,2.66,3.79,-.18,.14,'WindowGlass')
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

def teaching5_front(poly, height, levels):
    """The west curtain wall, rising main steps and adjoining ramp."""
    global part
    a, b = poly[24], poly[0]
    assert a == [190.435, -1.403] and b == [178.797, -9.129], (a, b)
    length = math.dist(a, b)
    ux, uz = (b[0]-a[0])/length, (b[1]-a[1])/length
    nx, nz = uz, -ux
    def point(s, y, d):
        return (a[0]+ux*s+nx*d, y, a[1]+uz*s+nz*d)
    def trim(s0,s1,y0,y1,d0,d1,mat):
        edgebox(a,b,s0,s1,y0,y1,d0,d1,'Teaching5Entry'+mat)
    def pane(s0,s1,y0,y1,depth,mat):
        geo([point(s1,y0,depth),point(s0,y0,depth),point(s0,y1,depth),point(s1,y1,depth)],
            [(0,1,2,3)],'Teaching5Entry'+mat)
    def walk_surface(name, s0,s1,d0,d1,bottom,top):
        solids.append({'name':'Teaching5_main_'+name,'type':'polygon_prism',
                       'polygon':[[x,z] for x,_,z in (point(s,0,d) for s,d in
                         [(s0,d0),(s1,d0),(s1,d1),(s0,d1)])], 'bottom':bottom,'top':top})
    def ramp_member(s0,s1,d0,d1,y0,y1,size,finish,collision=None):
        corners=[(s0,d0,y0),(s1,d0,y0),(s1,d1,y1),(s0,d1,y1)]
        vertices=[point(s,y+dy,d) for dy in (-size,0) for s,d,y in corners]
        if finish:
            geo(vertices,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],
                'Teaching5Entry'+finish)
        if collision:
            solids.append({'name':'Teaching5_main_'+collision,'type':'sloped_prism',
                'polygon':[[x,z] for s,d,y in corners for x,_,z in [point(s,0,d)]],
                'bottom':min(y0,y1)-size,'top':max(y0,y1),
                'top_heights':[y for _,_,y in corners]})
    part = 'MainEntrance'
    visit = VISITS[asset]
    steps_end = length-2.30
    trim(0,length,.08,.48,-.45,.06,'Landing')
    for index, (depth, top) in enumerate([(1.02,.48),(1.46,.32),(1.90,.16)]):
        trim(.28,steps_end,.07,top,.05,depth,'Landing')
        walk_surface('step_'+str(index),.28,steps_end,.05,depth,.07,top)
        trim(.29,steps_end-.02,top-.018,top,depth-.043,depth+.013,'Silver')
    trim(steps_end,length-.21,.08,.48,-.03,.96,'Landing')
    walk_surface('ramp_landing',steps_end,length-.21,-.03,.96,.08,.48)
    ramp_member(steps_end,length-.21,.96,5.03,.48,.125,.13,'Landing','ramp')
    for side in (steps_end+.08,length-.29):
        slope_begin=1.04 if side<length-.4 else .96
        slope_top=.48-(slope_begin-.96)*(.48-.125)/(5.03-.96)
        for rail in (.22,.59,.89):
            ramp_member(side-.018,side+.018,slope_begin,5.01,slope_top+rail,.125+rail,.042,'Silver')
            if side>length-.4:
                trim(side-.018,side+.018,.48+rail-.042,.48+rail,.13,.96,'Silver')
        for depth in (slope_begin,2.36,3.68,4.99):
            bottom=.48-(depth-.96)*(.48-.125)/(5.03-.96)
            trim(side-.026,side+.026,bottom,bottom+.95,depth-.028,depth+.028,'Silver')
        ramp_member(side-.028,side+.028,slope_begin,5.01,slope_top+.90,1.015,.96,None,
                    'ramp_edge_'+str(round(side,2)))
        if side>length-.4:
            walk_surface('outer_ramp_guard',side-.028,side+.028,.13,.96,.48,1.39)
    trim(.20,length-.20,.00,.125,1.90,7.15,'Landing')
    walk_surface('forecourt',.20,length-.20,1.90,7.15,-.07,.125)
    for k in range(1,11):
        s=.20+k*(length-.40)/11
        trim(s-.010,s+.010,.125,.128,1.93,7.14,'PaverJoint')
    for d in (2.78,3.67,4.56,5.45,6.34):
        trim(.21,length-.21,.125,.128,d-.009,d+.009,'PaverJoint')
    # Glazed roof and fascia above the ground floor. Upper bays remain behind it.
    trim(-.42,length+.42,4.18,4.37,2.30,2.42,'Silver')
    trim(-.42,length+.42,4.22,4.39,-.08,.11,'Silver')
    for s in [-.42,length+.30]:
        trim(s,s+.12,4.18,4.37,.10,2.30,'Silver')
    trim(-.29,length+.29,4.33,4.36,.11,2.30,'Pane')
    for s in [.08,1.83,3.58,5.33,7.08,8.83,10.58,12.33,length-.08]:
        trim(s-.041,s+.041,4.08,4.42,.06,2.36,'Beam')
    # Nine narrow aluminium bays, broad horizontal floor beams and thin crossbars.
    bay = length/9
    roof = height-.18
    pane(.028,length-.028,4.46,roof,-.054,'Pane')
    for i in range(10):
        s = bay*i
        trim(s-.038,s+.038,4.39,roof,-.11,.025,'Silver')
    for floor in range(1, levels):
        y = .26+(height-.5)/levels*floor
        trim(.015,length-.015,y-.08,y+.19,-.15,.055,'Beam')
        trim(.035,length-.035,y-.071,y+.12,-1.90,-.18,'Interior')
        for dy in [1.22,2.53]:
            trim(.022,length-.022,y+dy-.025,y+dy+.025,-.085,.012,'Silver')
        # A real return wall and a slender rail behind the glass create parallax.
        trim(.10,length-.10,y+.24,y+1.15,-3.1,-3.02,'Atrium')
        for rail in [.48,.72,.97,1.12]:
            trim(.13,length-.13,y+rail-.018,y+rail+.018,-.60,-.56,'Silver')
        for s in [.20,2.4,4.7,7.0,9.4,11.7,length-.20]:
            trim(s-.018,s+.018,y+.18,y+1.14,-.605,-.550,'Silver')
    trim(.01,length-.01,4.42,roof,-3.28,-3.13,'Atrium')
    for s in [.03,length-.20]:
        trim(s,s+.17,.48,roof,-3.25,-.18,'Interior')
    trim(.01,length-.01,.48,.51,-3.25,-.18,'Landing')
    trim(.10,length-.10,.50,4.42,-visit["depth"]-.14,-visit["depth"]-.10,'InteriorShadow')
    trim(.02,length-.02,roof,roof+.16,-.12,.04,'Silver')
    trim(0,length,roof+.15,roof+.37,-.27,.01,'Ivory')
    for i in range(36):
        s = length*i/35
        trim(s-.010,s+.010,roof+.35,roof+1.03,-.22,-.19,'Silver')
    for y in [roof+.42,roof+1.03]:
        trim(0,length,y-.016,y+.016,-.24,-.17,'Silver')
    # Glazed transom and four central door leaves with silver pull bars.
    pane(.08,length-.08,2.93,4.17,-.058,'DoorPane')
    trim(.06,length-.06,2.85,2.94,-.10,.065,'Silver')
    trim(.06,length-.06,4.115,4.18,-.10,.065,'Silver')
    spans = list(door_spans(visit,length))
    joints = sorted([0,length,.14*length,.27*length,.73*length,.86*length,
                     *[edge for first,last,_ in spans for edge in (first,last)]])
    for s in joints:
        trim(s-.033,s+.033,.485,4.17,-.09,.061,'Silver')
    for s,end in zip(joints,joints[1:]):
        opening = next((door for a,b,door in spans if a==s and b==end),None)
        if opening:
            edgebox(a,b,s+.036,end-.036,.50,.48+opening["height"]-.024,-.071,-.028,'PhotoVisitGlass')
        elif end-s>.075:
            pane(s+.035,end-.035,.49,2.85,-.052,'DoorPane')
            inset = (end-s)*.15
            trim(s+inset,end-inset,1.45,1.52,-.026,.002,'Blue')
    # Right wing as seen from the forecourt. Letters follow this return face.
    right_a, right_b = poly[23], poly[24]
    span = math.dist(right_a,right_b)
    ru, rv = (right_b[0]-right_a[0])/span,(right_b[1]-right_a[1])/span
    for char, y in zip('王璞楼',[12.0,9.85,7.70]):
        s = span*.56
        d = .055
        p = (right_a[0]+ru*s+rv*d,y,right_a[1]+rv*s-ru*d)
        inscription(char,p,1.07,'Teaching5EntryGold',heading=math.atan2(rv,-ru))
    for s, width, material_name in [(span*.68,.72,'Teaching5EntryDarkStone'),(span*.45,.66,'Teaching5EntryBlue')]:
        edgebox(right_a,right_b,s-width/2,s+width/2,2.00,2.40,.026,.060,material_name)
    for chapter,s,y,size,mat in [
        ("第五教学楼",span*.45,2.24,.13,"PhotoWhiteLetters"),
        ("Fifth Teaching Building",span*.45,2.11,.043,"PhotoWhiteLetters"),
    ]:
        inscription(chapter,(right_a[0]+ru*s+rv*.071,y,right_a[1]+rv*s-ru*.071),
                    size,mat,heading=math.atan2(rv,-ru))
    return point(length/2,.125,6.6)

def faculty_front(poly,asset_name,levels,height,pitch):
    from mapped_landmark_details import Exterior
    ensure_door_glass()

    admin=asset_name=="TeachingAdministration"
    edges=(4,5,6,len(poly)-1) if admin else (4,5,6,7,len(poly)-1)
    facade(poly,levels,height,"PhotoFacultyGrey",pitch,detail_edges=edges)
    sides=[Exterior(asset_name,a,b,geo,slab,edgebox,inscription,solids)
           for a,b in zip(poly,poly[1:]+poly[:1])]
    front=sides[4 if admin else 5]
    for e in edges:
        side=sides[e]
        w=side.length
        if w<5:
            side.member(0,w,.25,height,-.31,.026,"FacultyGrey")
            continue
        keep_reveal = height-2.1
        top_of_podium=7.5
        glass_start=w*.13 if admin else w*.18
        glass_end=w*.79 if admin else w*.91
        side.member(0,glass_start,top_of_podium,keep_reveal,-.60,.055,"FacultyGrey")
        side.member(glass_end,w,top_of_podium,keep_reveal,-.60,.055,"FacultyGrey")
        side.member(0,w,keep_reveal,height+.12,-.60,.24,"FacultyGrey")
        side.glazed_opening(glass_start,glass_end,top_of_podium,keep_reveal,-.28,
                           max(2,round((glass_end-glass_start)/3.05)),"FacultyGlass",frame="FacultyFrame")
        n=max(1,round((glass_end-glass_start)/3.10))
        for k in range(n+1):
            s=glass_start+k*(glass_end-glass_start)/n
            side.member(s-.19,s+.19,top_of_podium,keep_reveal,-.25,.16,"FacultyTerracotta")
        for i in range(1,levels-1):
            y=top_of_podium+(keep_reveal-top_of_podium)*i/(levels-1)
            side.member(glass_start,glass_end,y-.56,y+.37,-.40,.20,"FacultyTerracotta")
            side.member(glass_start,glass_end,y+.95,y+.991,-.256,-.185,"FacultyFrame")
        for s in (.38,w-.41):
            side.member(s-.35,s+.35,top_of_podium,height-.03,-.34,.112,"FacultyGrey")
        side.member(0,w,top_of_podium-.16,top_of_podium+.36,-.38,.38,"FacultyGrey")
        low = 4.16 if side is front else .35
        side.glazed_opening(.22,w-.20,low,top_of_podium-.30,-.23,
                           max(2,round(w/2.3)),"FacultyGlass",
                           cross=None if side is front else 3.77,frame="FacultyFrame")
    w=front.length
    a,b=.9,w-.88
    eave=3.32 if admin else 3.75
    front.member(a,b,4.12,4.79,-.31,eave,"FacultyGrey")
    front.member(a-.06,b+.06,4.57,4.84,-.31,eave+.09,"FacultyLightStone")
    for i,s in enumerate((a+.42,b-.47)):
        front.member(s-.31,s+.31,.59,4.13,eave-.68,eave-.04,"FacultyLightStone",f"portico_{i}")
    front.approach_steps(a-.18,b+.18,-.05,eave+.10,.14,3,.15,.38,"FacultyLightStone")
    front.member(a-1,b+1,.045,.126,eave+.86,eave+5.72,"FacultyPaving","paved_apron")
    front.member(0,w,.35,.59,-.25,.03,"FacultyGrey")
    for low,high in ((0,a+.80),(b-.76,w)):
        front.member(low,high,.59,4.16,-.23,.016,"FacultyGrey")
    front.member(a+.80,b-.76,.46,.59,-2.7,-.05,"FacultyLightStone")
    front.member(a+.80,b-.76,.59,4.16,-2.78,-2.70,"FacultyGrey")
    front.glazed_opening(a+.80,b-.76,.59,4.16,-.031,7,"FacultyGlass",
                         doors=((a+b)*.5,),cross=3.2,frame="FacultyFrame")
    front.nameplate("教学行政楼" if admin else "管理科学教学科研楼",(a+b)*.5,4.65,eave+.093,.33,"WhiteLetters")
    return front.at((a+b)*.5,.14,eave+2.55)

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
    if asset == 'Teaching5':
        facade(poly,floors,height,wall,pitch,curtain,blank_edges=(0,23),entry_edge=24,
               interior_storeys=True,ground_portal=(22,11.8))
    elif asset not in ('TeachingAdministration','ManagementResearch'):
        facade(poly,floors,height,wall,pitch,curtain,ground_portal=(2,3.8))
    if asset=='Teaching5':
        a,b=[208.627,6.633],[190.045,5.615]
        entry(a,b,11.8,3)
        spawn=teaching5_front(poly,height,floors)
        part='Roof'
        for x,z,w,d in [(194.5,-8,8,6),(242,-7,8,7),(271,-3,7,5)]:
            box((x,height+.82,z),(w,1.65,d),'Teaching5IvoryTile')
            box((x,height+1.68,z),(w+.25,.13,d+.25),'FacultyRoof')
    elif asset in ('TeachingAdministration','ManagementResearch'):
        if str(Path(__file__).resolve().parent) not in sys.path:
            sys.path.insert(0,str(Path(__file__).resolve().parent))
        spawn=faculty_front(poly,asset,floors,height,pitch)
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
exports = [('north_teaching5.glb',['Teaching5'])]
args.output_dir.mkdir(parents=True, exist_ok=True)
manifest_path = args.output_dir/'north_teaching_manifest.json'
previous = json.loads((ROOT/'godot/assets/north_teaching_manifest.json').read_text(encoding='utf-8'))
if args.teaching5_only:
    previous['buildings'] = [building_records[0] if b['asset']=='Teaching5' else b for b in previous['buildings']]
    previous['collision_solids'] = [s for s in previous['collision_solids'] if not s['name'].startswith('Teaching5_')]
    previous['collision_solids'][:0] = [s for s in solids if s['name'].startswith('Teaching5_')]
    manifest = previous
else:
    exports.append(('north_faculty_blocks.glb',['TeachingAdministration','ManagementResearch','ManagementMBA']))
    manifest['collision_solids'].extend(s for s in previous['collision_solids'] if s['name'].startswith('NewNorthGate_'))
    if 'gates' in previous:
        manifest['gates']=previous['gates']
        manifest['assets']['north_gate.glb']=previous['assets']['north_gate.glb']
        manifest['observed_sources'].extend(s for s in previous['observed_sources'] if 'New Huangshan' in s.get('claim','') or 'new_northgate' in s.get('local',''))
for filename,names in exports:
    obs=[ob for a in names for ob in objects[a]]
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs: ob.select_set(True)
    dest=args.output_dir/filename
    bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,
                              export_apply=True,export_yup=True,export_extras=True)
    verts=[ob.matrix_world@v.co for ob in obs for v in ob.data.vertices]
    triangles=0
    for ob in obs: ob.data.calc_loop_triangles(); triangles+=len(ob.data.loop_triangles)
    lo=[min(v[i] for v in verts) for i in range(3)]; hi=[max(v[i] for v in verts) for i in range(3)]
    manifest['assets'][filename]={'file':'godot/assets/'+filename,'buildings':names,
                                'objects':len(obs),'triangles':triangles,
                                'bounds_min':[lo[0],lo[2],-hi[1]],'bounds_max':[hi[0],hi[2],-lo[1]]}
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
if not args.teaching5_only and args.output_dir == ROOT/'godot/assets':
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/source/north_teaching_extension.blend'))
print('NORTH_TEACHING_OK',json.dumps(manifest['assets'],ensure_ascii=False))

if args.proof:
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
