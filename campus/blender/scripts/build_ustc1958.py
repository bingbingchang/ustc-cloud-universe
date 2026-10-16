"""Build the real USTC1958 from architect drawings; shared kit loaded once in Godot."""
import ast
import json
import math
import random
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector

CAMPUS=Path(__file__).resolve().parents[2]
ASSETS=CAMPUS/'godot/samples/ustc1958/assets'
TEXTURES=CAMPUS/'blender/ustc1958/textures'
RENDERS=CAMPUS/'renders/ustc1958'
for folder in (ASSETS,TEXTURES,RENDERS):folder.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.name='USTC1958_East_Campus';scene.unit_settings.system='METRIC'
visual=bpy.data.collections.new('01_USTC1958_BuildingAndSite');scene.collection.children.link(visual)
library=bpy.data.collections.new('02_SharedAssetLibrary');scene.collection.children.link(library)
layout=bpy.data.collections.new('03_LinkedLayoutInstances');scene.collection.children.link(layout)
collision=bpy.data.collections.new('04_CollisionProxies');scene.collection.children.link(collision)
stage=bpy.data.collections.new('05_PresentationOnly');scene.collection.children.link(stage)
rng=random.Random(19582026);M={};box_cache={};LEAF_COUNT=0;images={}

# Reuse the tested native Blender primitives and folded leaf construction.
helper=CAMPUS/'blender/scripts/build_cafe_courtyard.py'
names={'empty','linear','rgb','material','uv_project','mesh_object','box','cylinder','beam','curve_mesh','leaves'}
definitions=[n for n in ast.parse(helper.read_text(encoding='utf-8')).body if isinstance(n,ast.FunctionDef) and n.name in names]
exec(compile(ast.Module(body=definitions,type_ignores=[]),str(helper),'exec'),globals())
root=empty('USTC1958_Architecture')
shell=empty('01_MainHouse',root);roof=empty('02_StandingSeamRoofs',root)
addition=empty('03_CurvedNorthAddition',root);conference=empty('04_WestConference',root)
terrace=empty('05_TimberTerrace',root);details=empty('06_FramesSignsAndFixtures',root)
interior=empty('07_CafeInterior',root);landscape=empty('08_Landscape',root)
kit_root=empty('USTC1958_SharedKit',collection=library)
layout_root=empty('USTC1958_AssetInstances',collection=layout)
FLOOR=.34;DECK=.32;SOIL=.10
LEFT,RIGHT,FRONT,BACK=-9.75,9.75,-4.25,4.25
EAVE,RIDGE=3.27,4.95

def baked_texture(name,color,kind):
    n=768;yy,xx=np.mgrid[0:n,0:n]/n
    noise=np.random.default_rng(1958+len(images)).normal(0,1,(n,n))
    if kind=='wood':pattern=.010*np.sin(xx*math.tau*23+.7*np.sin(yy*math.tau*3))+.004*np.sin(xx*math.tau*71+yy*6)+noise*.002
    elif kind=='bark':pattern=.019*np.sin(xx*math.tau*21+np.sin(yy*math.tau*2))+.009*np.sin(xx*math.tau*57)+noise*.004
    elif kind=='leaf':
        vein=np.exp(-((xx-.5)/.017)**2)
        side=np.minimum(np.mod(yy*9+(xx-.5)*3,1),1-np.mod(yy*9+(xx-.5)*3,1))
        pattern=vein*.04+np.exp(-(side/.024)**2)*.019+noise*.002
    else:pattern=noise*(.009 if kind=='soil' else .004)
    pixels=np.ones((n,n,4),dtype=np.float32);pixels[:,:,:3]=np.clip(np.array(rgb(color))+pattern[:,:,None],.001,1)
    image=bpy.data.images.new(name,width=n,height=n,alpha=False);image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw=str(TEXTURES/(name+'.png'));image.file_format='PNG';image.save();image.pack();images[name]=image
    return name

for name,color,kind in [('DeckWood','8f8777','wood'),('InteriorWood','9e825d','wood'),('StoneGrain','c5c5b8','stone'),('SoilGrain','665747','soil'),('BarkGrain','766e61','bark'),('TrunkPaint','c8c7b9','stone'),('LeafVeins','91a46b','leaf'),('LawnGrain','788269','soil')]:baked_texture(name,color,kind)
for name,col,rough,metal,tex,alpha in [
 ('MetalRoof','c1c7c1',.71,.15,None,1),('Cladding','b8c0b8',.82,.05,None,1),('WhiteTrim','d4d6cb',.75,.04,None,1),
 ('Stone','c5c5b8',.91,0,'StoneGrain',1),('Concrete','a8aaa0',.91,0,None,1),('Wood','8f8777',.80,0,'DeckWood',1),
 ('WarmWood','9e825d',.76,0,'InteriorWood',1),('Iron','252c29',.53,.50,None,1),('Soil','665747',.95,0,'SoilGrain',1),
 ('Bark','766e61',.90,0,'BarkGrain',1),('Paint','c8c7b9',.90,0,'TrunkPaint',1),('Leaf','91a46b',.83,0,'LeafVeins',1),
 ('LeafDark','526846',.91,0,None,1),('Canvas','d6d0b8',.93,0,None,1),('Glass','b1c4c2',.13,0,None,.14),
 ('TubeGlass','c3d6d1',.18,0,None,.33),('InsideFloor','99998d',.60,0,None,1),('WarmPaper','d8c9a8',.9,0,None,1),
 ('Ceramic','d3cfc0',.31,0,None,1),('Coffee','49341e',.65,0,None,1),('Brass','99825a',.5,.6,None,1),
 ('Lamp','e5dfc7',.65,0,None,1),('Letters','dddcd0',.68,.10,None,1),('Studio','dedbd1',.95,0,None,1),('Lawn','788269',.95,0,'LawnGrain',1)]:
    material(name,col,rough,metal,image=tex,alpha=alpha)
M['Leaf'].use_backface_culling=False
M['Lamp'].node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value=(*rgb('e5d0a4'),1)
M['Lamp'].node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value=.45

def plane_volume(name,points,mat,parent,thickness=.06,wood_under=False):
    ob=mesh_object(name,points,[tuple(range(len(points)))],mat,parent)
    if wood_under:ob.data.materials.append(M['WarmWood'])
    solid=ob.modifiers.new('RealThickness','SOLIDIFY');solid.thickness=thickness;solid.offset=-1
    if wood_under:solid.material_offset=1
    bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=solid.name)
    return ob

def wall_segment(name,x0,x1,y0,y1,z0,z1,mat='Stone',parent=shell):
    return box(name,((x0+x1)/2,(y0+y1)/2,(z0+z1)/2),(x1-x0,y1-y0,z1-z0),mat,parent,.005)

def along_box(name,a,b,width,depth,mat,parent):
    a,b=Vector(a),Vector(b);ob=box(name,(a+b)/2,(width,depth,(b-a).length),mat,parent,.005)
    ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return ob

def outline_text(body,p,width,mat,parent,rotation):
    font=bpy.data.curves.new(body+'_OriginalText','FONT');font.body=body;font.align_x='CENTER';font.align_y='CENTER';font.size=1;font.extrude=.012;font.bevel_depth=.002;font.bevel_resolution=2;font.materials.append(M[mat])
    ob=bpy.data.objects.new(body+'_Sign',font);visual.objects.link(ob);ob.parent=parent;ob.location=p;ob.rotation_euler=rotation
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH');ob.select_set(False)
    xs=[v.co.x for v in ob.data.vertices];scale=width/(max(xs)-min(xs));ob.scale=(scale,scale,scale)
    return ob

# Floor plan proportions are traced from the published drawing, with an estimated length.
def north_y(x):
    t=(x-LEFT)/(RIGHT-LEFT)
    # Flat at west, then an S-shaped northward expansion that avoids existing trees.
    s=max(0,min(1,(t-.17)/.71));return BACK+.05+3.62*(s*s*(3-2*s))

box('Site_Lawn',(0,1,-.15),(33,23,.50),'Lawn',landscape,.025)
box('MainFloor',((LEFT+RIGHT)/2,0,FLOOR-.10),(RIGHT-LEFT,8.5,.20),'InsideFloor',shell,.008)
xs=np.linspace(LEFT,RIGHT,81)
outline=[(LEFT,BACK,FLOOR),(RIGHT,BACK,FLOOR)]+[(float(x),north_y(float(x)),FLOOR) for x in reversed(xs)]
plane_volume('NorthExtensionFloor',outline,'InsideFloor',addition,.18)
box('WestConferenceFloor',(-11.45,.20,FLOOR-.10),(3.40,5.30,.20),'InsideFloor',conference,.007)

bay_edges=np.linspace(LEFT,RIGHT,7)
door_x=float((bay_edges[3]+bay_edges[4])/2)
window_bottom,window_top=1.05,2.69
DOOR_LEAVES=[]
for i in range(6):
    left,right=float(bay_edges[i]+.19),float(bay_edges[i+1]-.19)
    center=(left+right)/2
    if i!=3:
        wall_segment('SouthLowWall',left,right,FRONT-.09,FRONT+.09,FLOOR,window_bottom-.045)
        box('Window_Sill',(center,FRONT-.15,window_bottom-.03),(right-left+.11,.31,.07),'Iron',details,.011)
        frame=empty('SouthWindow_'+str(i),details,(center,FRONT-.105,0))
        width=right-left
        for x in (-width/2,width/2):box('Window_Jamb',(x,0,1.87),(.052,.075,1.69),'Iron',frame,.007)
        for z in (window_bottom,window_top):box('Window_Rail',(0,0,z),(width,.075,.052),'Iron',frame,.006)
        box('Window_Transom',(0,0,2.17),(width,.075,.045),'Iron',frame,.005)
        box('Glass_Lower',(0,.015,1.60),(width-.055,.010,1.09),'Glass',frame,0)
        open_leaf=empty('TopHingedWindow_'+str(i),frame,(0,0,window_top))
        open_leaf.rotation_euler.x=-math.radians(24 if i==5 else (16 if i==1 else 0))
        height=window_top-2.19
        for x in (-width/2,width/2):box('TopWindow_Stile',(x,0,-height/2),(.048,.075,height),'Iron',open_leaf,.005)
        for z in (0,-height):box('TopWindow_Rail',(0,0,z),(width,.075,.048),'Iron',open_leaf,.005)
        box('Glass_Top',(0,.015,-height/2),(width-.05,.010,height-.05),'Glass',open_leaf,0)
        for sx in (-1,1):
            beam('Window_HingePin',(sx*(width/2-.05),-.02,window_top-.012),(sx*(width/2-.20),-.02,window_top-.012),.01,'Iron',frame)
            if i in (1,5):beam('Window_Support',(sx*(width/2-.13),0,2.22),(sx*(width/2-.13),-.16,2.30),.008,'Iron',frame)
    else:
        # Open double doorway; the central 1.6m passage stays clear.
        for x in (door_x-1.02,door_x+1.02):box('Door_Jamb',(x,FRONT-.13,1.50),(.075,.10,2.35),'Iron',details,.006)
        box('Door_Header',(door_x,FRONT-.13,2.69),(2.11,.10,.06),'Iron',details,.007)
        box('Door_Threshold',(door_x,FRONT-.13,.35),(2.11,.35,.025),'Concrete',details,.005)
        for side in (-1,1):
            hinge_x=door_x+side*1.0
            leaf=empty('EntryDoor_'+str(side),details,(hinge_x,FRONT-.13,FLOOR));leaf.rotation_euler.z=side*math.radians(79)
            center_x=-side*.46
            for x in (0,-side*.92):box('Door_Stile',(x,0,1.15),(.045,.058,2.30),'Iron',leaf,.005)
            for z in (.03,2.28):box('Door_Rail',(center_x,0,z),(.96,.058,.055),'Iron',leaf,.006)
            box('Glass_EntryDoor',(center_x,.01,1.15),(.875,.010,2.20),'Glass',leaf,0)
            beam('Door_Pull',(center_x-side*.33,-.05,.85),(center_x-side*.33,-.05,1.20),.012,'Iron',leaf)
            DOOR_LEAVES.append((hinge_x,leaf.rotation_euler.z,center_x))
        for x0,x1 in ((left,door_x-1.06),(door_x+1.06,right)):
            box('Glass_DoorSidelight',((x0+x1)/2,FRONT-.09,1.49),(x1-x0,.010,2.28),'Glass',details,0)
    wall_segment('SouthHeader',left,right,FRONT-.09,FRONT+.09,window_top+.03,EAVE)
for x in bay_edges:
    box('SouthSquarePost',(float(x),FRONT-.05,(FLOOR+EAVE)/2),(.36,.32,EAVE-FLOOR),'Stone',shell,.010)
    for z in (1.45,2.35):box('PostJoint',(float(x),FRONT-.215,z),(.355,.004,.009),'Concrete',details,.001)
    box('WallLamp',(float(x),FRONT-.233,1.89),(.095,.055,.24),'Iron',details,.01)
    box('WallLamp_LowerGlow',(float(x),FRONT-.239,1.764),(.066,.047,.013),'Lamp',details,.003)

# Main metal roof and lower curved-addition roof are separate, correctly low volumes.
for y0,y1,z0,z1 in [(FRONT-.27,0,EAVE,RIDGE),(0,BACK+.05,RIDGE,EAVE)]:
    plane_volume('MainMetalRoof',[(LEFT-.22,y0,z0),(RIGHT+.22,y0,z0),(RIGHT+.22,y1,z1),(LEFT-.22,y1,z1)],'MetalRoof',roof,.065,True)
    for x in np.arange(LEFT-.15,RIGHT+.20,.41):along_box('StandingSeam_Main',(float(x),y0,z0+.014),(float(x),y1,z1+.014),.024,.023,'WhiteTrim',roof)
for y,z in ((FRONT-.29,EAVE),(0,RIDGE),(BACK+.055,EAVE)):
    box('MainRoof_LongTrim',(0,y,z+.015),(20.0,.073,.045),'WhiteTrim',roof,.006)
box('SouthCorrugatedFascia',(0,FRONT-.25,EAVE-.22),(19.94,.065,.49),'Cladding',roof,.007)
for x in np.arange(LEFT-.20,RIGHT+.21,.104):box('FasciaRib',(float(x),FRONT-.292,EAVE-.22),(.031,.033,.49),'WhiteTrim',roof,.004)
for side in (-1,1):
    x=side*(RIGHT+.105)
    points=[(x,FRONT,FLOOR),(x,BACK,FLOOR),(x,BACK,EAVE),(x,0,RIDGE-.055),(x,FRONT,EAVE)]
    if side<0:points.reverse()
    if side>0:plane_volume('EastMainGable',points,'Cladding',shell,.16)
    else:
        wall_segment('WestWall_South',x-.08,x+.08,FRONT,-1.77,FLOOR,EAVE)
        wall_segment('WestWall_North',x-.08,x+.08,1.77,BACK,FLOOR,EAVE)
        plane_volume('WestUpperGable',[(x,FRONT,EAVE),(x,0,RIDGE-.055),(x,BACK,EAVE)],'Stone',shell,.16)
    if side>0:
        for y in np.arange(FRONT+.02,BACK,.107):
            height=EAVE+(RIDGE-EAVE)*(1-abs(float(y))/BACK)
            box('GableRib',(x+.095,float(y),(FLOOR+height)/2),(.033,.032,height-FLOOR),'WhiteTrim',details,.004)
outline_text('USTC',(RIGHT+.22,-.05,2.07),5.70,'Letters',details,(math.pi/2,0,math.pi/2))
outline_text('1958',(RIGHT+.22,-.05,4.16),1.56,'Letters',details,(math.pi/2,0,math.pi/2))

curve_points=[(float(x),north_y(float(x)),EAVE) for x in xs]
for side_band in (0,1):
    points=[]
    for x in xs:
        x=float(x);back=north_y(x);width=back-BACK;mid=(back+BACK)/2;peak=EAVE+width*.36
        if side_band==0:points.extend(((x,BACK,EAVE),(x,mid,peak)))
        else:points.extend(((x,mid,peak),(x,back,EAVE)))
    ob=mesh_object('NorthMetalRoof_'+str(side_band),points,[(i*2,i*2+2,i*2+3,i*2+1) for i in range(len(xs)-1)],'MetalRoof',roof)
    solid=ob.modifiers.new('RoofThickness','SOLIDIFY');solid.thickness=.055;solid.offset=-1;ob.data.materials.append(M['WarmWood']);solid.material_offset=1
    bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=solid.name)
for x in np.arange(LEFT,RIGHT+.01,.41):
    x=float(x);back=north_y(x);mid=(BACK+back)/2;peak=EAVE+(back-BACK)*.36
    if back-BACK>.15:
        along_box('StandingSeam_North',(x,BACK,EAVE+.014),(x,mid,peak+.014),.024,.020,'WhiteTrim',roof)
        along_box('StandingSeam_North',(x,mid,peak+.014),(x,back,EAVE+.014),.024,.020,'WhiteTrim',roof)
for a,b in zip(curve_points,curve_points[1:]):along_box('CurvedRoofEdge',a,b,.05,.055,'WhiteTrim',roof)

# Hollow translucent tubes reuse one mesh. Curved wall follows the floor-plan S shape.
def tube_template():
    n=16;verts=[]
    for radius,z in ((.044,0),(.044,EAVE-FLOOR),(.036,0),(.036,EAVE-FLOOR)):
        verts.extend((radius*math.cos(j*math.tau/n),radius*math.sin(j*math.tau/n),z) for j in range(n))
    faces=[]
    for j in range(n):
        k=(j+1)%n
        faces.extend([(j,k,n+k,n+j),(2*n+j,3*n+j,3*n+k,2*n+k),(n+j,n+k,3*n+k,3*n+j),(j,2*n+j,2*n+k,k)])
    ob=mesh_object('Tube_Template',verts,faces,'TubeGlass',addition)
    for poly in ob.data.polygons:poly.use_smooth=poly.index%4<2
    mesh=ob.data;bpy.data.objects.remove(ob,do_unlink=True);return mesh
tube_mesh=tube_template()
for i,x in enumerate(np.arange(LEFT,RIGHT+.01,.089)):
    ob=bpy.data.objects.new('NorthTube_'+str(i),tube_mesh);visual.objects.link(ob);ob.parent=addition;ob.location=(float(x),north_y(float(x)),FLOOR)
for x in np.linspace(LEFT,RIGHT,10):box('NorthFacade_Post',(float(x),north_y(float(x)),(FLOOR+EAVE)/2),(.05,.06,EAVE-FLOOR),'Iron',addition,.005)
back=north_y(RIGHT);mid=(BACK+back)/2;peak=EAVE+(back-BACK)*.36
plane_volume('Glass_EastNorthGable',[(RIGHT+.035,BACK,FLOOR),(RIGHT+.035,back,FLOOR),(RIGHT+.035,back,EAVE),(RIGHT+.035,mid,peak),(RIGHT+.035,BACK,EAVE)],'Glass',addition,.010)
for a,b in [((RIGHT,BACK,EAVE),(RIGHT,mid,peak)),((RIGHT,mid,peak),(RIGHT,back,EAVE))]:along_box('NorthGableFrame',a,b,.062,.06,'Iron',addition)
for y in np.linspace(BACK,back,4):box('NorthGable_Mullion',(RIGHT+.06,float(y),(FLOOR+EAVE)/2),(.065,.045,EAVE-FLOOR),'Iron',addition,.006)

# West conference-room addition has a true glazed gable and a connecting opening.
for y0,y1,z0,z1 in [(-2.45,.20,EAVE,4.38),(.20,2.85,4.38,EAVE)]:
    plane_volume('ConferenceMetalRoof',[(-13.18,y0,z0),(-9.53,y0,z0),(-9.53,y1,z1),(-13.18,y1,z1)],'MetalRoof',roof,.06,True)
    for x in np.arange(-13.1,-9.5,.4):along_box('ConferenceRoofSeam',(float(x),y0,z0+.01),(float(x),y1,z1+.01),.022,.02,'WhiteTrim',roof)
for y in (-2.43,2.83):
    box('Glass_ConferenceSide',(-11.45,y,1.79),(3.39,.012,2.90),'Glass',conference,0)
    for x in (-13.15,-11.5,-9.75):box('ConferenceSideFrame',(x,y,1.79),(.055,.068,2.90),'Iron',conference,.006)
    for z in (FLOOR,EAVE):box('ConferenceSideRail',(-11.45,y,z),(3.44,.065,.065),'Iron',conference,.006)
points=[(-13.15,-2.45,FLOOR),(-13.15,2.85,FLOOR),(-13.15,2.85,EAVE),(-13.15,.2,4.38),(-13.15,-2.45,EAVE)]
plane_volume('Glass_WestConference',list(reversed(points)),'Glass',conference,.012)
for y in np.linspace(-2.45,2.85,6):box('ConferenceFoldFrame',(-13.18,float(y),1.79),(.065,.045,2.90),'Iron',conference,.006)
for a,b in [((-13.18,-2.45,EAVE),(-13.18,.2,4.38)),((-13.18,.2,4.38),(-13.18,2.85,EAVE))]:along_box('ConferenceGableFrame',a,b,.075,.06,'Iron',conference)
for y in (-1.76,1.76):box('InteriorConferenceJamb',(-9.79,y,1.80),(.08,.075,2.91),'Iron',conference,.006)
box('InteriorConferenceLintel',(-9.79,0,3.15),(.08,3.6,.07),'Iron',conference,.005)

# Interior references: visible black structure, rings, counter and movable timber pods.
for x in bay_edges:
    for y in (-3.92,3.95):box('SteelPortalPost',(float(x),y,1.82),(.075,.085,2.96),'Iron',interior,.006)
    along_box('RoofPortal_Rafter',(float(x),-3.92,3.14),(float(x),0,4.73),.075,.095,'Iron',interior)
    along_box('RoofPortal_Rafter',(float(x),0,4.73),(float(x),3.95,3.14),.075,.095,'Iron',interior)
    box('PortalTie',(float(x),0,3.12),(.075,7.89,.085),'Iron',interior,.006)
def ring(name,p,radius,parent):
    verts=[];faces=[];n,m=48,8
    for i in range(n):
        a=i*math.tau/n
        for j in range(m):
            b=j*math.tau/m;r=radius+.021*math.cos(b)
            verts.append((p[0]+r*math.cos(a),p[1]+r*math.sin(a),p[2]+.021*math.sin(b)))
    for i in range(n):
        for j in range(m):faces.append((i*m+j,((i+1)%n)*m+j,((i+1)%n)*m+(j+1)%m,i*m+(j+1)%m))
    ob=mesh_object(name,verts,faces,'Lamp',parent)
    for poly in ob.data.polygons:poly.use_smooth=True
for x in (-7.9,-4.7,-1.5,1.7,4.9,8.1):
    ring('RingPendant',(x,0,2.82),.59,interior)
    for y in (-.36,.36):beam('PendantCable',(x,y,2.83),(x,y,3.11),.004,'Iron',interior)
box('CounterBody',(6.45,-2.61,.91),(5.76,.74,1.14),'WhiteTrim',interior,.015)
box('CounterBlackTop',(6.45,-2.61,1.505),(5.9,.85,.055),'Iron',interior,.013)
box('CounterReturn',(8.75,-1.68,.91),(.80,1.95,1.14),'WhiteTrim',interior,.012)
box('CounterReturnTop',(8.75,-1.68,1.505),(.87,2.0,.055),'Iron',interior,.01)
for x in np.arange(3.72,9.20,.145):box('CounterRib',(float(x),-3.003,.91),(.055,.035,1.09),'WhiteTrim',interior,.009)
box('EspressoMachine',(6.60,-2.61,1.75),(.85,.46,.43),'Iron',interior,.035)
box('EspressoMachinePanel',(6.6,-2.865,1.76),(.77,.025,.28),'Concrete',interior,.008)
for x in (6.4,6.78):beam('EspressoHead',(x,-2.91,1.75),(x,-2.91,1.60),.026,'Iron',interior)
for x in (4.2,4.6):
    cylinder('CoffeeJar',(x,-2.53,1.73),.09,.42,'Coffee',interior)
    cylinder('CoffeeJarLid',(x,-2.53,1.95),.096,.027,'Iron',interior)
for z in (1.70,2.32):
    box('ServiceShelf',(8.4,3.9,z),(2.0,.32,.045),'WarmWood',interior,.005)
    for x in np.linspace(7.65,9.15,8):cylinder('ShelfCup',(float(x),3.91,z+.07),.053,.12,'Ceramic',interior,20)
for x0,y0 in [(-2.3,-2.0),(2.0,2.70)]:
    for x in (x0-.8625,x0+.8625):box('MeetingPodSide',(x,y0,1.38),(.075,1.88,2.08),'WarmWood',interior,.008)
    box('MeetingPodBack',(x0,y0+.9025,1.38),(1.65,.075,2.08),'WarmWood',interior,.008)
    box('MeetingPodRoof',(x0,y0,2.3875),(1.80,1.88,.065),'WarmWood',interior,.008)
    box('MeetingPodFloor',(x0,y0,FLOOR+.0325),(1.8,1.88,.065),'WarmWood',interior,.008)
    box('Glass_PodFront',(x0,y0-.94,1.38),(1.65,.012,1.97),'Glass',interior,0)
    box('PodDeskTop',(x0,y0-.28,FLOOR+.75),(1.38,.45,.045),'WarmWood',interior,.008)
    for x in (x0-.58,x0+.58):box('PodDeskLeg',(x,y0-.28,FLOOR+.385),(.045,.36,.70),'Iron',interior,.005)
    box('PodBenchSeat',(x0,y0+.60,FLOOR+.44),(1.50,.47,.08),'Iron',interior,.02)
    box('PodBenchBase',(x0,y0+.60,FLOOR+.20),(1.44,.40,.40),'WarmWood',interior,.008)
    box('PodBenchBack',(x0,y0+.805,FLOOR+.63),(1.5,.065,.38),'Iron',interior,.012)
    for z in (FLOOR+.03,FLOOR+2.065):box('PodFrontRail',(x0,y0-.955,z),(1.78,.045,.06),'Iron',interior,.006)
    for x in (x0-.87,x0+.87):box('PodMetalFrame',(x,y0-.985,1.38),(.06,.045,2.12),'Iron',interior,.007)
    for x in (x0-.72,x0+.72):
        for y in (y0-.72,y0+.72):cylinder('PodWheel',(x,y,FLOOR+.043),.043,.06,'Iron',interior,14)

# Terrace planks are shared. Split the few boards that cross the real tree cutouts.
TREE_LAYOUT=[('Tree_A',(5.1,-6.35,SOIL),.25,1.0),('Tree_B',(11.15,-4.50,SOIL),-.22,.97),('Tree_C',(-11.85,-5.1,SOIL),.48,.93),('Tree_B',(-13.8,3.7,SOIL),.8,.96),('Tree_C',(-4.3,9.7,SOIL),-.35,.94),('Tree_A',(3.8,10.1,SOIL),.62,1.02),('Tree_B',(11.5,8.6,SOIL),.35,.95)]
holes=[(5.1,-6.35,.48),(-11.85,-5.1,.46)]
def timber_area(x0,x1,y0,y1):
    for x in np.arange(x0+.11,x1,.22):
        intervals=[(y0,y1)]
        for tx,ty,r in holes:
            dx=abs(float(x)-tx)
            if dx<r+.11:
                gap=math.sqrt(max(0,(r+.11)**2-dx*dx));cut0,cut1=ty-gap,ty+gap
                intervals=[piece for a,b in intervals for piece in ((a,min(b,cut0)),(max(a,cut1),b)) if piece[1]-piece[0]>.045]
        for a,b in intervals:
            box('DeckPlank',(float(x),(a+b)/2,DECK-.025),(.212,b-a-.006,.05),'Wood',terrace,.006)
            if abs(b-a-(y1-y0))<.01:
                for y in (a+.10,b-.10):cylinder('DeckScrew',(float(x),y,DECK+.0015),.005,.003,'Iron',terrace,10)
timber_area(-11.1,10.55,-7.52,-4.36)
timber_area(-14.05,-11.11,-7.0,-3.20)
timber_area(10.56,12.55,-6.55,-3.35)
box('TerraceFrontFascia',(-.28,-7.55,.21),(21.5,.07,.22),'Wood',terrace,.009)
for y,z,depth in [(-7.93,.17,.40),(-7.71,.25,.40)]:box('EntryLowStep',(door_x,y,z-.045),(2.46,depth,.09),'Concrete',terrace,.008)
for row in range(5):
    for col in range(4):box('ApproachPaver',(door_x-.93+col*.62,-10.3+row*.47,.105),(.61,.46,.025),'Stone',landscape,.006)
def tree_bench(x,y):
    parent=empty('TreeIntegratedBench',terrace,(x,y,DECK))
    # The inner square is a real opening, never covered by the seat boards.
    for side in (-1,1):
        for j in range(5):
            v=.58+j*.088
            box('TreeBench_Seat',(0,side*v,.423),(1.86,.08,.044),'Wood',parent,.007)
            box('TreeBench_Seat',(side*v,0,.423),(.08,1.04,.044),'Wood',parent,.007)
        box('TreeBenchOuterWall',(0,side*.96,.21),(1.95,.045,.42),'Wood',parent,.008)
        box('TreeBenchInnerWall',(0,side*.545,.21),(1.12,.045,.42),'Wood',parent,.008)
        box('TreeBenchOuterWall',(side*.96,0,.21),(.045,1.90,.42),'Wood',parent,.008)
        box('TreeBenchInnerWall',(side*.545,0,.21),(.045,1.12,.42),'Wood',parent,.008)
    return parent
for x,y in [(5.1,-6.35),(11.15,-4.5),(-11.85,-5.1)]:tree_bench(x,y)

# Build once, then linked-copy or instance these reusable assets.
PROTOTYPES={};INSTANCES=[];CHAIRS=[]
def finish_prototype(parent):
    for ob in [parent]+list(parent.children_recursive):
        for collection in list(ob.users_collection):collection.objects.unlink(ob)
        library.objects.link(ob)
    PROTOTYPES[parent.name]=parent
    return parent

def clone_layout(asset,name,p,angle=0,scale=1):
    original=PROTOTYPES[asset]
    def clone(src,parent):
        ob=src.copy();ob.data=src.data;layout.objects.link(ob);ob.parent=parent
        if src!=original:ob.name=name+'_'+src.name
        for child in src.children:clone(child,ob)
        return ob
    copy=clone(original,layout_root);copy.name=name;copy.location=p;copy.rotation_euler.z=angle;copy.scale=(scale,scale,scale)
    INSTANCES.append({'asset':asset,'name':name,'position':[p[0],p[2],-p[1]],'yaw':angle,'scale':scale})
    return copy

chair=empty('Chair_BlackMetal',kit_root)
for sx in (-1,1):
    for sy in (-1,1):beam('ChairLeg',(sx*.22,sy*.23,0),(sx*.19,sy*.19,.46),.018,'Iron',chair)
    curve_mesh('ChairBackFrame',[(sx*.19,.19,.36),(sx*.22,.23,.70),(sx*.20,.18,.91)],[.02]*3,'Iron',chair)
    curve_mesh('ChairArm',[(sx*.21,-.21,.45),(sx*.24,-.15,.68),(sx*.24,.15,.69),(sx*.21,.23,.61)],[.017]*4,'Iron',chair)
curve_mesh('ChairBackTop',[(-.20,.18,.91),(0,.21,.94),(.20,.18,.91)],[.02]*3,'Iron',chair)
for k in range(8):
    x=-.18+k*.0515;curve_mesh('ChairBackSlat',[(x,.205,.48),(x,.235,.70),(x,.198,.895)],[.008]*3,'Iron',chair)
for k in range(7):box('ChairSeatSlat',(0,-.17+k*.057,.447),(.42,.046,.026),'Iron',chair,.004)
finish_prototype(chair)
table=empty('Table_RoundDark',kit_root)
cylinder('TableFoot',(0,0,.018),.29,.036,'Iron',table,40)
cylinder('TableStem',(0,0,.36),.041,.685,'Iron',table,24)
cylinder('TableTop',(0,0,.738),.48,.045,'Iron',table,64)
for x,y in ((-.15,.12),):
    cylinder('Saucer',(x,y,.771),.079,.012,'Ceramic',table,28)
    cylinder('Cup',(x,y,.815),.045,.080,'Ceramic',table,24)
    cylinder('CoffeeSurface',(x,y,.857),.036,.002,'Coffee',table,24)
finish_prototype(table)
umbrella=empty('Umbrella_Ivory',kit_root)
cylinder('UmbrellaBase',(0,0,.022),.28,.044,'Iron',umbrella)
cylinder('UmbrellaPole',(0,0,1.37),.032,2.74,'WarmWood',umbrella)
verts=[(0,0,2.79)];n=32
for ring_id in (1,2,3):
    t=ring_id/3
    for j in range(n):
        a=j*math.tau/n;verts.append((1.58*t*math.cos(a),1.58*t*math.sin(a),2.79-.39*t*t-.07*t))
faces=[(0,1+j,1+(j+1)%n) for j in range(n)]+[(1+r*n+j,1+r*n+(j+1)%n,1+(r+1)*n+(j+1)%n,1+(r+1)*n+j) for r in range(2) for j in range(n)]
cloth=mesh_object('UmbrellaFabric',verts,faces,'Canvas',umbrella);cloth.data.materials.append(M['Canvas'])
sol=cloth.modifiers.new('CanvasThickness','SOLIDIFY');sol.thickness=.007;bpy.context.view_layer.objects.active=cloth;bpy.ops.object.modifier_apply(modifier=sol.name)
for j in range(8):
    a=j*math.tau/8;curve_mesh('UmbrellaRib',[(0,0,2.77),(.85*math.cos(a),.85*math.sin(a),2.60),(1.57*math.cos(a),1.57*math.sin(a),2.32)],[.008]*3,'WarmWood',umbrella)
finish_prototype(umbrella)

def records(center,count,radius,size,vertical=.7):
    out=[]
    for _ in range(count):
        a=rng.uniform(0,math.tau);h=rng.uniform(-.95,.95);r=radius*rng.random()**.36;s=math.sqrt(1-h*h)
        p=(center[0]+r*math.cos(a)*s,center[1]+r*math.sin(a)*s,center[2]+r*h*vertical)
        tone=rng.uniform(.66,1.0)
        out.append((p,rng.uniform(size*.77,size*1.14),rng.uniform(0,math.tau),rng.uniform(-1.15,1.15),(tone*.94,tone,tone*.84)))
    return out

planter=empty('Planter_SquareConcrete',kit_root)
for x in (-.34,.34):box('PlanterSide',(x,0,.34),(.10,.74,.68),'Stone',planter,.017)
for y in (-.32,.32):box('PlanterSide',(0,y,.34),(.58,.10,.68),'Stone',planter,.015)
box('PlanterBottom',(0,0,.055),(.63,.63,.08),'Stone',planter,.01)
box('PlanterSoil',(0,0,.60),(.56,.54,.025),'Soil',planter,.005)
for j in range(14):
    a=j*2.399;end=Vector((math.cos(a)*.29,math.sin(a)*.28,rng.uniform(1.0,1.48)))
    curve_mesh('PlanterStem',[(0,0,.59),end*.52+Vector((0,0,.26)),end],[.009,.006,.002],'Bark',planter)
    leaves('PlanterLeafSpray',records(end,19,.20,.18),planter)
finish_prototype(planter)
for variant in range(2):
    bush=empty('Shrub_'+str(variant),kit_root)
    for j in range(12):
        a=j*2.399;end=(math.cos(a)*.39,math.sin(a)*.34,rng.uniform(.30,.63))
        curve_mesh('ShrubStem',[(0,0,.0),(end[0]*.5,end[1]*.5,end[2]*.6),end],[.006,.004,.001],'LeafDark',bush)
        leaves('ShrubLeaves',records(end,27,.25,.16),bush)
    finish_prototype(bush)

def mature_tree(variant,height):
    rng.seed(1958+variant*971)
    parent=empty('Tree_'+chr(65+variant),kit_root);sources=[]
    lean=[Vector((.28,-.17,0)),Vector((-.48,.23,0)),Vector((.14,.42,0))][variant]
    sources.append(curve_mesh('TreeTrunkSource',[(0,0,-.07),lean*.2+Vector((0,0,.70)),lean*.6+Vector((0,0,1.8)),lean+Vector((0,0,3.25)),lean*1.1+Vector((0,0,3.7))],[.39,.32,.25,.185,.14],'Bark',parent))
    for j in range(7):
        a=j*math.tau/7+.3
        sources.append(curve_mesh('TreeRootSource',[(0,0,.45),(.36*math.cos(a),.36*math.sin(a),.11),(.81*math.cos(a),.70*math.sin(a),-.035)],[.17,.083,.012],'Bark',parent))
    for j in range(7):
        a=j*math.tau/7+variant*.57
        reach=rng.uniform(2.4,3.55);start=lean*.8+Vector((0,0,2.75+rng.uniform(-.16,.34)))
        end=Vector((math.cos(a)*reach,math.sin(a)*reach,height-rng.uniform(.75,1.4)))
        mid=start.lerp(end,.56)+Vector((.1,-.06,.19))
        sources.append(curve_mesh('PrimaryBranchSource',[start,start.lerp(mid,.5),mid,end],[.14,.115,.065,.017],'Bark',parent))
        for k in range(3):
            origin=mid.lerp(end,.35+k*.29);az=a+(-1 if k%2 else 1)*rng.uniform(.7,1.2)
            tip=origin+Vector((math.cos(az)*.88,math.sin(az)*.88,rng.uniform(.14,.55)))
            curve_mesh('TreeSecondary',[origin,origin.lerp(tip,.55)+Vector((0,0,.05)),tip],[.033,.020,.003],'Bark',parent)
            leaves(f'CrownClump_{variant}_{j}_{k}',records(tip,220,.85,.245),parent)
    for j in range(6):
        a=j*math.tau/6+variant*.35
        start=lean+Vector((0,0,3.3));end=Vector((math.cos(a)*1.6,math.sin(a)*1.65,height-rng.uniform(.05,.63)))
        sources.append(curve_mesh('UprightLeaderSource',[start,start.lerp(end,.55)+Vector((0,0,.1)),end],[.09,.05,.007],'Bark',parent))
        leaves(f'CrownClump_{variant}_top_{j}',records(end,190,.92,.23),parent)
        leaves(f'CrownClump_{variant}_inner_{j}',records(start.lerp(end,.75),140,.77,.24),parent)
    bpy.ops.object.select_all(action='DESELECT');copies=[]
    for src in sources:
        ob=src.copy();ob.data=src.data.copy();visual.objects.link(ob);ob.select_set(True);copies.append(ob)
        src['construction_source']=True;src.hide_render=True;src.hide_set(True)
    bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();fused=copies[0];fused.name='ContinuousTreeScaffold'
    mod=fused.modifiers.new('OrganicJunctions','REMESH');mod.mode='VOXEL';mod.voxel_size=.045;mod.use_smooth_shade=True;mod.use_remove_disconnected=False;bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=fused.modifiers.new('GentleSmoothing','SMOOTH');mod.factor=.23;mod.iterations=2;bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=fused.modifiers.new('TreeSurfaceBudget','DECIMATE');mod.ratio=.62;bpy.ops.object.modifier_apply(modifier=mod.name)
    fused.data.materials.clear();fused.data.materials.append(M['Bark']);fused.data.materials.append(M['Paint']);uv_project(fused.data,2)
    for poly in fused.data.polygons:
        a=math.atan2(poly.center.y,poly.center.x);edge=1.33+.07*math.sin(a*7+variant)+.03*math.sin(a*13)
        poly.material_index=1 if poly.center.z<edge else 0;poly.use_smooth=True
    for src in sources:bpy.data.objects.remove(src,do_unlink=True)
    finish_prototype(parent)
for variant,height in enumerate((8.7,8.2,9.0)):mature_tree(variant,height)

TABLE_LAYOUT=[(-8.0,-6.12),(-4.2,-6.15),(-.9,-6.2),(8.15,-6.43)]
for i,(x,y) in enumerate(TABLE_LAYOUT):
    clone_layout('Table_RoundDark','OutdoorTable_'+str(i),(x,y,DECK))
    for j,a in enumerate((0,math.pi)):
        p=(x+math.cos(a)*.96,y+math.sin(a)*.96,DECK);name='OutdoorChair_'+str(i)+'_'+str(j)
        clone_layout('Chair_BlackMetal',name,p,a-math.pi/2);CHAIRS.append({'name':name,'table':'OutdoorTable_'+str(i)})
for i,(x,y) in enumerate([(-8.0,-6.12),(-4.2,-6.15)]):clone_layout('Umbrella_Ivory','OutdoorUmbrella_'+str(i),(x,y,DECK))
for i,(asset,p,a,s) in enumerate(TREE_LAYOUT):clone_layout(asset,'MatureTree_'+str(i),p,a,s)
PLANTERS=[(-9.7,-5.1),(-.04,-4.65),(3.29,-4.68),(9.15,-5.32),(12.10,-2.15),(-13.5,-2.95)]
for i,(x,y) in enumerate(PLANTERS):clone_layout('Planter_SquareConcrete','Planter_'+str(i),(x,y,DECK if y<FRONT else SOIL))
# Interior furniture uses the same reusable chair/table geometry with no duplicate mesh data.
for i,(x,y) in enumerate([(-6.7,-2.5),(-3.8,2.5),(-6.7,2.5),(5.4,6.25)]):
    clone_layout('Table_RoundDark','InsideTable_'+str(i),(x,y,FLOOR))
    for j,a in enumerate((0,math.pi)):clone_layout('Chair_BlackMetal','InsideChair_'+str(i)+'_'+str(j),(x+math.cos(a)*.92,y+math.sin(a)*.92,FLOOR),a-math.pi/2)
box('ConferenceTableTop',(-11.4,.20,1.09),(2.10,.84,.055),'WarmWood',interior,.008)
for x in (-12.23,-10.57):
    for y in (-.11,.51):box('ConferenceTableLeg',(x,y,.69),(.055,.055,.70),'Iron',interior,.005)
for i,(x,y,a) in enumerate([(-11.98,-.66,math.pi),(-10.9,-.66,math.pi),(-11.98,1.06,0),(-10.9,1.06,0)]):clone_layout('Chair_BlackMetal','ConferenceChair_'+str(i),(x,y,FLOOR),a)
rng.seed(19582026)
for i in range(46):
    if i<24:x=rng.uniform(-14.0,14.0);y=rng.uniform(-9.2,-8.2)
    else:x=rng.uniform(-13.8,14.0);y=rng.uniform(8.8,10.7)
    if abs(x-door_x)<1.6 and y<FRONT:continue
    clone_layout('Shrub_'+str(i%2),'GroundShrub_'+str(i),(x,y,SOIL),rng.uniform(0,math.tau),rng.uniform(.85,1.4))
# Fine grasses are combined, while shrubs and trees remain reusable kit instances.
grass_v=[];grass_f=[]
for i in range(130):
    x=rng.uniform(-14.5,14.5);y=rng.choice((rng.uniform(-9.2,-8.0),rng.uniform(8.6,10.8)))
    if abs(x-door_x)<1.55 and y<0:continue
    for j in range(7):
        a=rng.uniform(0,math.tau);h=rng.uniform(.12,.33);reach=rng.uniform(.05,.15);off=len(grass_v)
        for t in np.linspace(0,1,5):
            mid=Vector((x+math.cos(a)*reach*t*t,y+math.sin(a)*reach*t*t,SOIL+h*math.sin(t*1.4)));side=Vector((-math.sin(a),math.cos(a),0))*.007*(1-t*.94)
            grass_v.extend((mid-side,mid+side))
        grass_f.extend((off+k*2,off+k*2+1,off+k*2+3,off+k*2+2) for k in range(4))
mesh_object('FineBorderGrasses',grass_v,grass_f,'LeafDark',landscape)

# Coarse collision solids preserve openings; individual glass tubes/leaves are never colliders.
cr=empty('USTC1958_Collision',collection=collision)
def solid(name,p,size,angle=0):
    ob=box(name+'-colonly',p,size,'Iron',cr,0,rotation=(0,0,angle),collection=collision);ob.hide_render=True;ob.hide_set(True);ob.display_type='WIRE';return ob
solid('Ground',(0,1,SOIL-.10),(33,23,.20))
solid('HouseFloor',(0,0,FLOOR-.10),(19.5,8.5,.20))
solid('ConferenceFloor',(-11.45,.20,FLOOR-.10),(3.40,5.30,.20))
for i,x in enumerate(np.linspace(LEFT+.25,RIGHT-.25,39)):
    back=north_y(float(x));solid('NorthFloor_'+str(i),(float(x),(BACK+back)/2,FLOOR-.1),(.51,back-BACK+.02,.20))
for name,p,size in [('MainDeck',(-.275,-5.94,DECK-.1),(21.65,3.18,.20)),('WestDeck',(-12.58,-5.1,DECK-.1),(2.96,3.80,.20)),('EastDeck',(11.56,-4.95,DECK-.1),(2.0,3.2,.20))]:solid(name,p,size)
for y,z in [(-7.93,.17),(-7.71,.25)]:solid('EntryStep',(door_x,y,z-.05),(2.46,.40,.10))
for i in range(6):
    if i!=3:solid('SouthWall_'+str(i),((float(bay_edges[i])+float(bay_edges[i+1]))/2,FRONT,1.80),(3.25,.20,2.92))
for x in bay_edges:solid('Post',(float(x),FRONT,1.80),(.36,.34,2.92))
solid('EastWall',(RIGHT,0,1.80),(.2,8.5,2.92))
solid('WestWallSouth',(LEFT,(FRONT-1.77)/2,1.80),(.20,-1.77-FRONT,2.92))
solid('WestWallNorth',(LEFT,(1.77+BACK)/2,1.80),(.20,BACK-1.77,2.92))
for i,(a,b) in enumerate(zip(curve_points[::4],curve_points[4::4])):
    a,b=Vector(a),Vector(b);p=(a+b)/2;p.z=1.8;angle=math.atan2(b.y-a.y,b.x-a.x);solid('NorthWall_'+str(i),p,((b-a).length+.02,.10,2.92),angle)
solid('NorthEastGlass',(RIGHT,(BACK+north_y(RIGHT))/2,1.80),(.13,north_y(RIGHT)-BACK,2.92))
for y in (-2.45,2.85):solid('ConferenceSide',(-11.45,y,1.80),(3.45,.12,2.92))
solid('ConferenceWest',(-13.15,.20,1.80),(.12,5.30,2.92))
for i,(x,a,cx) in enumerate(DOOR_LEAVES):solid('OpenDoor_'+str(i),(x+cx*math.cos(a),FRONT-.13+cx*math.sin(a),FLOOR+1.15),(.96,.07,2.30),a)
for item in INSTANCES:
    p=item['position'];x,y,z=p[0],-p[2],p[1]
    if item['asset']=='Table_RoundDark':solid(item['name'],(x,y,z+.38),(.88,.88,.76))
    elif item['asset']=='Chair_BlackMetal':solid(item['name'],(x,y,z+.47),(.48,.48,.94),item['yaw'])
    elif item['asset'].startswith('Tree_'):solid(item['name'],(x,y,SOIL+1.1),(.75,.75,2.20))
    elif item['asset']=='Planter_SquareConcrete':solid(item['name'],(x,y,z+.34),(.74,.74,.68))
for x,y in [(5.1,-6.35),(11.15,-4.5),(-11.85,-5.1)]:
    for side in (-1,1):
        solid('TreeBenchSide',(x+side*.75,y,DECK+.22),(.45,1.92,.44))
        solid('TreeBenchSide',(x,y+side*.75,DECK+.22),(1.08,.45,.44))
for x,y in [(-2.3,-2.0),(2.0,2.70)]:solid('MeetingPod',(x,y,1.38),(1.8,1.88,2.08))
solid('Counter',(6.45,-2.61,.94),(5.9,.85,1.20))
solid('CounterReturn',(8.75,-1.68,.94),(.87,2.0,1.2))
solid('ConferenceTable',(-11.4,.20,.72),(2.10,.84,.77))

# Export three independent pieces plus the kit. Prototype meshes are shared by every layout copy.
def export_col(collection,path):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in collection.objects:ob.hide_set(False);ob.select_set(True)
    node_tree=M['Leaf'].node_tree;socket=node_tree.nodes['Principled BSDF'].inputs['Base Color'];old=socket.links[0].from_socket
    tex=next(n for n in node_tree.nodes if n.type=='TEX_IMAGE');node_tree.links.new(tex.outputs['Color'],socket)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_cameras=False,export_lights=False,export_materials='EXPORT',export_vertex_color='ACTIVE')
    node_tree.links.new(old,socket)
    for ob in collection.objects:ob.select_set(False)
export_col(visual,ASSETS/'ustc1958_building_site.glb')
export_col(library,ASSETS/'ustc1958_shared_library.glb')
export_col(collision,ASSETS/'ustc1958_collision.glb')
for ob in collision.objects:ob.hide_set(True)
library.hide_render=True
library.hide_viewport=True
sr=empty('PREVIEW_ONLY_Presentation',collection=stage)
box('PresentationPlinth',(0,1,-.43),(33.14,23.14,.06),'Concrete',sr,.018,collection=stage)
box('StudioFloor',(0,0,-.485),(2400,2400,.04),'Studio',sr,0,collection=stage)
export_col(stage,ASSETS/'presentation_stage.glb')
world=bpy.data.worlds.new('NeutralDaylight');world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.76,.79,.73,1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=.65;scene.world=world
def aim(ob,target):ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
for name,power,p,color in [('Sun',2.25,(-15,-16,22),(1,.93,.82)),('Fill',.22,(16,8,15),(.87,.94,1))]:
    ob=bpy.data.objects.new(name,bpy.data.lights.new(name,'SUN'));stage.objects.link(ob);ob.data.energy=power;ob.data.color=color;ob.data.angle=.095;ob.location=p;aim(ob,(0,0,2))
for x in (-6,-1,4,8):
    ob=bpy.data.objects.new('InteriorFill',bpy.data.lights.new('InteriorFill','AREA'));stage.objects.link(ob);ob.location=(x,0,2.98);ob.data.energy=50;ob.data.size=2.8;ob.data.color=(1,.79,.51)
camera=bpy.data.objects.new('USTC1958_ReviewCamera',bpy.data.cameras.new('USTC1958_ReviewCamera'));stage.objects.link(camera);camera.location=(31,-35,22);camera.data.type='ORTHO';camera.data.ortho_scale=40;aim(camera,(-.5,1,2.3));scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
preferences=bpy.context.preferences.addons['cycles'].preferences;preferences.compute_device_type='OPTIX';preferences.get_devices()
for device in preferences.devices:device.use=device.type=='OPTIX'
scene.cycles.device='GPU';scene.render.resolution_x=1800;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.40;scene.render.image_settings.file_format='PNG';scene.render.filepath=str(RENDERS/'blender_overview.png')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
blend=CAMPUS/'blender/source/ustc1958_east.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend))
def stats(collection):
    meshes=[ob for ob in collection.objects if ob.type=='MESH'];unique={ob.data for ob in meshes};total=0
    for mesh in unique:mesh.calc_loop_triangles();total+=len(mesh.loop_triangles)
    return {'mesh_instances':len(meshes),'unique_meshes':len(unique),'unique_triangles':total}
report={'scene':'USTC1958 East Campus','length_basis':'19.5m main length is a modeling estimate based on existing site footprint; drawing proportions traced; not a survey','main_size_m':[19.5,8.5],'north_curve_max_y':north_y(RIGHT),'eave_m':EAVE,'main_ridge_m':RIDGE,'north_ridge_max_m':EAVE+(north_y(RIGHT)-BACK)*.36,'door_x':door_x,'floor_y_godot':FLOOR,'deck_y_godot':DECK,'instances':INSTANCES,'chair_checks':CHAIRS,'building':stats(visual),'shared_library':stats(library),'blender_linked_layout':stats(layout),'kit_assets':list(PROTOTYPES),'collision_shapes':sum(ob.type=='MESH' for ob in collision.objects),'packed_images':len(images),'prototype_leaves':LEAF_COUNT,'blend':str(blend),'sources':'references/ustc1958/sources.json and design/design_brief.json','door_state':'open double entry; interior and west conference room walkable'}
(ASSETS/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(RENDERS/'build.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.render.render(write_still=True)
print(json.dumps({k:report[k] for k in ('building','shared_library','blender_linked_layout','collision_shapes','prototype_leaves')},indent=2))
