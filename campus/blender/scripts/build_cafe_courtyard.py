"""Reference-led courtyard authored directly with native Blender geometry, in meters."""
import json
import math
import random
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector

CAMPUS = Path(__file__).resolve().parents[2]
BRIEF = json.loads((CAMPUS/'references/cafe_courtyard/brief.json').read_text(encoding='utf-8'))
ASSETS = CAMPUS/'godot/samples/cafe_courtyard/assets'
TEXTURES = CAMPUS/'blender/cafe_courtyard/textures'
RENDERS = CAMPUS/'renders/cafe_courtyard'
for folder in (ASSETS,TEXTURES,RENDERS):
    folder.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.name='Campus_Cafe_Courtyard'
scene.unit_settings.system='METRIC'
rng=random.Random(BRIEF['seed'])
visual=bpy.data.collections.new('Cafe_Editable_Visual')
scene.collection.children.link(visual)
collision=bpy.data.collections.new('Cafe_Collision_Proxies')
scene.collection.children.link(collision)
stage=bpy.data.collections.new('Presentation_Only')
scene.collection.children.link(stage)

def empty(name,parent=None,position=(0,0,0),collection=visual):
    ob=bpy.data.objects.new(name,None)
    collection.objects.link(ob)
    ob.parent=parent
    ob.location=position
    return ob

root=empty('CampusCafe_14x12m')
root['workflow']='Native Blender creation; no Three.js geometry stage'
building=empty('01_CafeBuilding',root)
roof=empty('02_IndividualRoofTiles',root)
courtyard=empty('03_CourtyardPaving',root)
furniture=empty('04_OutdoorFurniture',root)
plants=empty('05_Planting',root)
interior=empty('06_VisibleCafeInterior',building)
small=empty('07_FacadeDetails',building)
GROUND=BRIEF['ground_m']
H=BRIEF['wall_top_m']
RIDGE=BRIEF['roof_ridge_m']
W=BRIEF['building_width_m']
DEPTH=BRIEF['building_depth_m']
FRONT=BRIEF['front_y_m']
BACK=FRONT+DEPTH
MID=(FRONT+BACK)/2

def linear(value):
    return value/12.92 if value<=.04045 else ((value+.055)/1.055)**2.4

def rgb(hexcode):
    return tuple(linear(int(hexcode[i:i+2],16)/255) for i in (0,2,4))

def texture(name,kind):
    n=512
    yy,xx=np.mgrid[0:n,0:n]/n
    noise=np.random.default_rng(BRIEF['seed']+len(bpy.data.images)).normal(0,1,(n,n))
    if kind=='wood':
        pattern=.055*np.sin(yy*math.tau*28+np.sin(xx*math.tau*3)*.65)+.022*np.sin(yy*math.tau*91+xx*12)+noise*.008
        base=np.array([.55,.385,.235])
    elif kind=='roof':
        pattern=.024*np.sin(xx*math.tau*9)*np.cos(yy*math.tau*7)+noise*.016
        base=np.array([.62,.385,.26])
    elif kind=='plaster':
        pattern=noise*.008+.009*np.sin(xx*math.tau*6)*np.sin(yy*math.tau*5)
        base=np.array([.84,.803,.705])
    elif kind=='paver':
        pattern=noise*.013+.018*np.sin(xx*math.tau*4)*np.cos(yy*math.tau*3)
        base=np.array([.665,.646,.586])
    elif kind=='soil':
        pattern=noise*.018
        base=np.array([.34,.285,.205])
    elif kind=='bark':
        pattern=.035*np.sin(xx*math.tau*23+np.sin(yy*14))+.018*np.sin(xx*math.tau*61)+noise*.013
        base=np.array([.43,.399,.329])
    elif kind=='leaf':
        veins=np.exp(-((xx-.5)/.022)**2)
        side=np.minimum(np.mod(yy*9+(xx-.5)*3,1),1-np.mod(yy*9+(xx-.5)*3,1))
        pattern=veins*.07+np.exp(-(side/.033)**2)*.032+noise*.006
        base=np.array([.61,.68,.42])
    else:
        pattern=noise*.006+.008*np.sin(xx*math.tau*115)+.008*np.sin(yy*math.tau*115)
        base=np.array([.86,.83,.72])
    pixels=np.ones((n,n,4),dtype=np.float32)
    pixels[:,:,:3]=np.clip(base+pattern[:,:,None],0,1)
    image=bpy.data.images.new(name,width=n,height=n,alpha=False)
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw=str(TEXTURES/(name+'.png'))
    image.file_format='PNG'
    image.save()
    image.pack()
    return image

images={kind:texture('Cafe_'+kind,kind) for kind in ('wood','roof','plaster','paver','soil','bark','leaf','canvas')}
M={}
def material(name,color='ffffff',rough=.8,metal=0,image=None,factor=1,alpha=1):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF')
    mat.diffuse_color=(*rgb(color),alpha)
    bsdf.inputs['Base Color'].default_value=(*rgb(color),alpha)
    bsdf.inputs['Roughness'].default_value=rough
    bsdf.inputs['Metallic'].default_value=metal
    if image:
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image=images[image]
        mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
        # Use slight image variations, rather than procedural shaders in the GLB.
        bsdf.inputs['Base Color'].default_value=(factor,factor,factor,1)
    if alpha<1:
        bsdf.inputs['Alpha'].default_value=alpha
        mat.surface_render_method='DITHERED'
        mat.use_backface_culling=True
    M[name]=mat
    return mat

for kind in ('wood','roof','plaster','paver','soil','bark','canvas'):
    material(kind.title(),image=kind,rough=.87 if kind not in ('wood','canvas') else .73)
for i,color in enumerate(('a99f8c','bdb7a4','c5bea9','aaa99d','b5ad98')):
    material('Paver_'+str(i),color,.92)
for i,color in enumerate(('a36d4d','b77f59','996448','ad7757')):
    material('Tile_'+str(i),color,.88)
    image=bpy.data.images.new('Cafe_ClayVariant_'+str(i),width=512,height=512,alpha=False)
    pixels=np.array(images['roof'].pixels[:],dtype=np.float32).reshape(512,512,4)
    pixels[:,:,:3]*=(.86,1.05,.94,1.0)[i]
    image.pixels.foreach_set(pixels.ravel());image.filepath_raw=str(TEXTURES/(image.name+'.png'));image.file_format='PNG';image.save();image.pack()
    tex=M['Tile_'+str(i)].node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
    M['Tile_'+str(i)].node_tree.links.new(tex.outputs['Color'],M['Tile_'+str(i)].node_tree.nodes['Principled BSDF'].inputs['Base Color'])
material('Sage','708072',.73)
material('SageDark','56665c',.82)
material('Ivory','dcd4bc',.84)
material('Iron','303c38',.6,.5)
material('Brass','a88a52',.43,.72)
material('Glass','a1b2ae',.13,alpha=.20)
material('Grout','858477',.95)
material('Stone','b3ad98',.92)
material('PotClay','b57850',.92)
material('Leaf',image='leaf',rough=.82)
material('LeafDark','68764a',.88)
material('Petal','eee5c9',.9)
material('Pollen','c3a15e',.87)
material('Coffee','4a2f1e',.63)
material('Ceramic','e0d6bc',.3)
material('SignText','3a4842',.82)
material('Paper','e7dcc0',.87)
material('Studio','e8e2d5',.94)

def uv_project(mesh,scale=1):
    uv=mesh.uv_layers.new(name='UVMap')
    for poly in mesh.polygons:
        axis=max(range(3),key=lambda k:abs(poly.normal[k]))
        axes=[k for k in range(3) if k!=axis]
        for loop in poly.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co
            uv.data[loop].uv=(p[axes[0]]*scale,p[axes[1]]*scale)

def mesh_object(name,verts,faces,mat,parent,collection=visual,uv=True):
    mesh=bpy.data.meshes.new(name+'_Geometry')
    mesh.from_pydata(verts,[],faces)
    mesh.materials.append(M[mat])
    mesh.update()
    if uv:uv_project(mesh)
    ob=bpy.data.objects.new(name,mesh)
    collection.objects.link(ob)
    ob.parent=parent
    return ob

box_cache={}
def box(name,p,size,mat,parent,bevel=.008,rotation=(0,0,0),collection=visual):
    key=(tuple(size),mat,bevel)
    if key in box_cache:
        ob=bpy.data.objects.new(name,box_cache[key])
        collection.objects.link(ob)
        ob.parent=parent
    else:
        x,y,z=(a/2 for a in size)
        verts=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
        faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        ob=mesh_object(name,verts,faces,mat,parent,collection)
        if bevel:
            bpy.context.view_layer.objects.active=ob
            ob.select_set(True)
            mod=ob.modifiers.new('Small_Real_Bevel','BEVEL')
            mod.width=bevel
            mod.segments=2
            bpy.ops.object.modifier_apply(modifier=mod.name)
            ob.select_set(False)
        box_cache[key]=ob.data
    ob.location=p
    ob.rotation_euler=rotation
    return ob

def cylinder(name,p,radius,depth,mat,parent,vertices=32):
    verts=[]
    for z in (-depth/2,depth/2):
        verts.extend((radius*math.cos(i*math.tau/vertices),radius*math.sin(i*math.tau/vertices),z) for i in range(vertices))
    faces=[tuple(reversed(range(vertices))),tuple(range(vertices,2*vertices))]
    faces.extend((i,(i+1)%vertices,(i+1)%vertices+vertices,i+vertices) for i in range(vertices))
    ob=mesh_object(name,verts,faces,mat,parent)
    ob.location=p
    for poly in ob.data.polygons:
        poly.use_smooth=poly.index>=2
    return ob

def beam(name,a,b,radius,mat,parent):
    a,b=Vector(a),Vector(b)
    ob=cylinder(name,(a+b)/2,radius,(b-a).length,mat,parent,12)
    ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return ob

def curve_mesh(name,points,radii,mat,parent):
    data=bpy.data.curves.new(name+'_EditableCurve','CURVE')
    data.dimensions='3D'
    data.resolution_u=7
    data.bevel_resolution=2
    data.bevel_depth=1
    data.use_fill_caps=True
    spline=data.splines.new('BEZIER')
    spline.bezier_points.add(len(points)-1)
    for point,p,r in zip(spline.bezier_points,points,radii):
        point.co=p
        point.radius=r
        point.handle_left_type=point.handle_right_type='AUTO'
    data.materials.append(M[mat])
    ob=bpy.data.objects.new(name,data)
    visual.objects.link(ob)
    ob.parent=parent
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active=ob
    bpy.ops.object.convert(target='MESH')
    uv_project(ob.data,2)
    ob.select_set(False)
    for poly in ob.data.polygons:poly.use_smooth=True
    return ob

# Independent soil base and paving leave two real planted tree beds.
box('Earth_Substrate',(0,0,-.13),(14,12,.62),'Soil',courtyard,.035)
box('Courtyard_GroutFoundation',(0,-1.8,.184),(12.8,6.4,.10),'Grout',courtyard,.009)
for row in range(15):
    y=-4.8+row*.4
    for column in range(25):
        x=-6+column*.5
        if (x<-4.55 and -.95<y<1.3) or (x>4.55 and -2.3<y<.1):
            continue
        box(f'Paver_{row:02}_{column:02}',(x,y,.224),(.492,.392,.032),'Paver_'+str(rng.randrange(5)),courtyard,.007)
box('Cafe_Floor',(0,MID,.17),(W,DEPTH,.14),'Paver',building,.012)
for x,y,depth in [(-5.35,.25,2.2),(5.35,-1.10,2.4)]:
    box('TreeBed_Soil',(x,y,.21),(1.75,depth,.06),'Soil',plants,.008)
    box('TreeBed_InnerCurb',(math.copysign(4.47,x),y,.28),(.12,depth,.08),'Stone',plants,.009)
for side in (-1,1):
    box('SideGarden_Soil',(side*5.5,2.6,.175),(3,5.5,.12),'Soil',plants,.015)
    for j in range(14):
        y=-4.65+j*.765
        box(f'BoundaryWall_{side}_{j}',(side*6.68,y,.77),(.22,.782,1.10),'Plaster',courtyard,.013)
        box(f'BoundaryCap_{side}_{j}',(side*6.68,y,1.345),(.32,.79,.07),'Stone',courtyard,.014)
    for j in range(10):
        x=side*(1.2+j*.55)
        box('FrontBed_Edging',(x,-5.65,.285),(.543,.18,.27),'Stone',courtyard,.014)
    box('FrontFlowerBed',(side*3.9,-5.22,.16),(5.8,.7,.12),'Soil',plants,.018)
    box('EntrySide_Edging',(side*.94,-5.24,.28),(.13,.82,.25),'Stone',courtyard,.01)
box('RearGardenWall',(0,5.7,.80),(13.5,.22,1.16),'Plaster',courtyard,.015)
for row in range(3):
    for col in range(4):
        box('Entry_Paver',(-.75+col*.5,-5.85+row*.4,.224),(.492,.392,.032),'Paver_'+str((row+col)%5),courtyard,.007)

# Actual front openings: glass panes and closed wooden door are separate objects.
def front_piece(name,x0,x1,z0,z1):
    box(name,((x0+x1)/2,FRONT,(z0+z1)/2),(x1-x0,.18,z1-z0),'Plaster',building,.006)
openings=[(-2.88,-.8,.89,2.62),(-.55,.55,GROUND,GROUND+BRIEF['door_height_m']),(.8,2.88,.89,2.62)]
cursor=-W/2
for i,(left,right,bottom,top) in enumerate(openings):
    front_piece('Front_Pier_'+str(i),cursor,left,GROUND,H)
    if bottom>GROUND:front_piece('Window_Plinth_'+str(i),left,right,GROUND,bottom)
    front_piece('Opening_Lintel_'+str(i),left,right,top,H)
    cursor=right
front_piece('Front_RightPier',cursor,W/2,GROUND,H)
box('BackWall',(0,BACK,(GROUND+H)/2),(W,.18,H-GROUND),'Plaster',building,.008)
box('WestWall',(-W/2,MID,(GROUND+H)/2),(.18,DEPTH,H-GROUND),'Plaster',building,.008)
# A real side window, with wall pieces above/below and at both ends.
for y0,y1,z0,z1 in [(FRONT,2,GROUND,H),(4.6,BACK,GROUND,H),(2,4.6,GROUND,.92),(2,4.6,2.62,H)]:
    box('EastWallSegment',(W/2,(y0+y1)/2,(z0+z1)/2),(.18,y1-y0,z1-z0),'Plaster',building,.006)
for side in (-1,1):
    x=side*W/2
    tri=[(x,FRONT,H),(x,BACK,H),(x,MID,RIDGE-.12)]
    ob=mesh_object('Gable_'+str(side),tri,[(0,1,2) if side>0 else (2,1,0)],'Plaster',building)
    solid=ob.modifiers.new('GableThickness','SOLIDIFY');solid.thickness=.15
    bpy.context.view_layer.objects.active=ob
    bpy.ops.object.modifier_apply(modifier=solid.name)

def front_window(index,left,right):
    win=empty('FrontWindow_'+str(index),building)
    mid=(left+right)/2
    width=right-left
    for x in (left,right):box('Window_Jamb',(x,.891,1.755),(.075,.12,1.805),'Sage',win,.01)
    for z in (.89,2.62):box('Window_Rail',(mid,.883,z),(width+.09,.13,.075),'Sage',win,.01)
    box('Window_Mullion',(mid,.883,1.755),(.049,.13,1.66),'Sage',win,.008)
    box('Window_Transom',(mid,.879,2.18),(width,.12,.04),'Sage',win,.006)
    box('Window_Sill',(mid,.837,.852),(width+.22,.29,.08),'Stone',win,.012)
    box('Glass_Front_'+str(index),(mid,.92,1.755),(width-.06,.013,1.65),'Glass',win,0)
front_window(1,-2.88,-.8)
front_window(2,.8,2.88)
sidewin=empty('EastWindow',building)
for y in (2,4.6):box('Window_SideJamb',(3.46,y,1.77),(.13,.075,1.8),'Sage',sidewin,.008)
for z in (.92,2.62):box('Window_SideRail',(3.46,3.3,z),(.13,2.7,.075),'Sage',sidewin,.008)
for y in (2.86,3.73):box('Window_SideMullion',(3.46,y,1.77),(.13,.04,1.65),'Sage',sidewin,.005)
box('Glass_East',(3.42,3.3,1.77),(.013,2.56,1.64),'Glass',sidewin,0)
door=empty('EntryDoor',building)
for x in (-.58,.58):box('Door_Jamb',(x,.887,1.36),(.085,.17,2.3),'SageDark',door,.008)
box('Door_Lintel',(0,.879,2.475),(1.25,.17,.085),'SageDark',door,.008)
box('Door_Threshold',(0,.88,.245),(1.25,.28,.025),'Stone',door,.006)
box('Door_LowerPanel',(0,.886,.79),(1.065,.065,1.07),'Sage',door,.012)
for x in (-.51,.51):box('Door_GlassStile',(x,.884,1.85),(.045,.065,1.1),'Sage',door,.006)
box('Door_TopRail',(0,.884,2.42),(1.08,.07,.07),'Sage',door,.006)
box('Glass_Door',(0,.901,1.85),(.98,.012,1.02),'Glass',door,0)
for x in (-.25,.25):box('Door_RaisedPanel',(x,.847,.79),(.36,.019,.80),'SageDark',door,.005)
beam('Door_Handle',(.39,.795,1.1),(.39,.795,1.38),.014,'Brass',door)
for z in (1.1,1.38):beam('Door_HandleMount',(.39,.79,z),(.39,.85,z),.008,'Brass',door)
box('Doormat',(0,.53,.25),(1.17,.57,.016),'Canvas',small,.005)

# Roof: gently curved clay tiles with thickness, shared native meshes and ridge caps.
roof_half=(DEPTH+.68)/2
edge_front=MID-roof_half
edge_back=MID+roof_half
slope=(RIDGE-H)/roof_half
alpha=math.atan(slope)
for side in (-1,1):
    yy=MID+side*roof_half
    verts=[(-3.64,MID,RIDGE),(3.64,MID,RIDGE),(3.64,yy,H),(-3.64,yy,H)]
    ob=mesh_object('Roof_Underlay_'+str(side),verts,[(0,3,2,1) if side<0 else (0,1,2,3)],'Roof',roof)
    sol=ob.modifiers.new('RoofBoardThickness','SOLIDIFY');sol.thickness=.085;sol.offset=-1
    bpy.context.view_layer.objects.active=ob
    bpy.ops.object.modifier_apply(modifier=sol.name)
tile_meshes=[]
for variant in range(4):
    vertices=[]
    for y in (-.225,-.075,.075,.225):
        for j in range(9):
            t=-1+j/4
            vertices.append((t*.127,y,.045*(1-t*t)))
    faces=[(row*9+j,row*9+j+1,(row+1)*9+j+1,(row+1)*9+j) for row in range(3) for j in range(8)]
    ob=mesh_object('Tile_Template',vertices,faces,'Tile_'+str(variant),roof)
    solid=ob.modifiers.new('ClayThickness','SOLIDIFY');solid.thickness=.017
    bpy.context.view_layer.objects.active=ob
    bpy.ops.object.modifier_apply(modifier=solid.name)
    for poly in ob.data.polygons:poly.use_smooth=True
    tile_meshes.append(ob.data)
    bpy.data.objects.remove(ob,do_unlink=True)
for side in (-1,1):
    for row in range(8):
        distance=.10+row*.325
        y=(edge_front+distance) if side<0 else (edge_back-distance)
        z=H+distance*slope+.037
        for column in range(29):
            ob=bpy.data.objects.new(f'RoofTile_{side}_{row:02}_{column:02}',tile_meshes[rng.randrange(4)])
            visual.objects.link(ob);ob.parent=roof
            ob.location=(-3.50+column*.25,y,z+rng.uniform(-.002,.002))
            ob.rotation_euler.x=alpha if side<0 else -alpha
for i in range(29):
    cap=cylinder('RidgeCap_'+str(i),(-3.50+i*.25,MID,RIDGE+.075),.105,.245,'Roof',roof,20)
    cap.rotation_euler.y=math.pi/2
for side in (-1,1):
    for end in (-1,1):
        beam('Gable_Fascia',(side*3.64,MID,RIDGE),(side*3.64,MID+end*roof_half,H),.055,'SageDark',roof)
beam('Front_RainGutter',(-3.65,edge_front-.045,H-.015),(3.65,edge_front-.045,H-.015),.046,'SageDark',small)
curve_mesh('Rain_Downpipe',[(3.25,edge_front-.05,H-.02),(3.25,edge_front-.05,2.95),(3.25,.84,2.72),(3.25,.84,.29)], [.037]*4,'SageDark',small)

# Curved fabric panels and a rounded scallop along the front edge.
awning=empty('StripedAwning',building)
for strip in range(20):
    x0=-3.1+strip*.31
    x1=x0+.307
    verts=[]
    for j in range(9):
        t=j/8
        y=.82-1.18*t
        z=2.91-.31*t-.045*math.sin(t*math.pi)
        verts.extend(((x0,y,z),(x1,y,z)))
    faces=[(j*2,j*2+1,j*2+3,j*2+2) for j in range(8)]
    mat='Canvas' if strip%2==0 else 'Sage'
    panel=mesh_object('AwningStripe_'+str(strip),verts,faces,mat,awning)
    solid=panel.modifiers.new('FabricThickness','SOLIDIFY');solid.thickness=.008
    bpy.context.view_layer.objects.active=panel;bpy.ops.object.modifier_apply(modifier=solid.name)
    # A shallow valance, with a smooth curved lower edge.
    verts=[]
    for j in range(9):
        u=j/8
        x=x0+(x1-x0)*u
        verts.extend(((x,-.365,2.60),(x,-.365,2.43-.025*math.sin(math.pi*u))))
    mesh_object('AwningValance_'+str(strip),verts,[(j*2,j*2+1,j*2+3,j*2+2) for j in range(8)],mat,awning)
for x in (-2.95,2.95):
    beam('AwningSupport',(x,.79,2.72),(x,-.34,2.58),.018,'Iron',awning)
    beam('AwningBrace',(x,.79,2.36),(x,-.30,2.58),.014,'Iron',awning)
box('Coffee_SignBacking',(0,.882,3.135),(1.55,.065,.275),'Ivory',small,.012)
for x in (-.78,.78):box('Sign_Border',(x,.842,3.135),(.025,.025,.30),'SageDark',small,.003)
for z in (2.99,3.28):box('Sign_Border',(0,.842,z),(1.58,.025,.025),'SageDark',small,.003)
font=bpy.data.curves.new('COFFEE_Lettering','FONT');font.body='C O F F E E';font.size=.185;font.align_x='CENTER';font.align_y='CENTER';font.extrude=.0015
font.materials.append(M['SignText'])
sign=bpy.data.objects.new('COFFEE_EditableText',font);visual.objects.link(sign);sign.parent=small;sign.location=(0,.822,3.13);sign.rotation_euler=(math.pi/2,0,0)
bpy.context.view_layer.objects.active=sign;sign.select_set(True);bpy.ops.object.convert(target='MESH');sign.select_set(False)
for x in (-1.42,1.42):
    curve_mesh('WallLamp_Arm',[(x,.87,3.13),(x,.67,3.24),(x,.54,3.12)],[.014]*3,'Iron',small)
    # A bell-shaped shade with a modeled light disk.
    shade=mesh_object('WallLamp_Shade',[(x+r*math.cos(j*math.tau/24),.54+r*math.sin(j*math.tau/24),z) for r,z in ((.038,3.14),(.115,3.04)) for j in range(24)],[(j,(j+1)%24,(j+1)%24+24,j+24) for j in range(24)],'Iron',small)
    cylinder('WallLamp_Diffuser',(x,.54,3.039),.084,.008,'Ivory',small)

# Interior is actual geometry, visible through front and side glazing.
box('Counter_Body',(0,3.15,.70),(5.0,.66,.92),'Wood',interior,.014)
box('Counter_Top',(0,3.15,1.183),(5.12,.79,.057),'Wood',interior,.012)
for x in (-2.3,-1.55,-.8,0,.8,1.55,2.3):box('Counter_PanelBatten',(x,2.812,.70),(.035,.025,.88),'SageDark',interior,.004)
for z in (1.70,2.29):
    box('Rear_Shelf',(0,5.02,z),(5.4,.32,.045),'Wood',interior,.007)
    for x in (-2.1,2.1):beam('ShelfBracket',(x,5.06,z-.23),(x,4.9,z-.028),.012,'Iron',interior)
box('EspressoMachine',(1.35,3.13,1.38),(.65,.44,.33),'Iron',interior,.03)
box('EspressoMachine_Fascia',(1.35,2.9,1.40),(.57,.026,.23),'Brass',interior,.009)
for x in (1.15,1.52):beam('CoffeeSpout',(x,2.865,1.39),(x,2.865,1.30),.012,'Iron',interior)
for x in (-.75,-.4):
    cylinder('CoffeeJar',(x,3.18,1.38),.07,.32,'Coffee',interior)
    cylinder('JarLid',(x,3.18,1.55),.073,.025,'Brass',interior)
for level,z in enumerate((1.73,2.32)):
    for i in range(10):
        x=-2.23+i*.49
        cylinder('Shelf_Cup',(x,4.98,z+.067),.048,.115,'Ceramic',interior,20)
        if i%3==0:box('CoffeePackage',(x+.13,4.98,z+.095),(.09,.12,.18),'Paper',interior,.005)
for x in (-1.95,1.95):
    beam('Pendant_Cord',(x,2.05,H-.06),(x,2.05,2.49),.005,'Iron',interior)
    cylinder('Pendant_Shade',(x,2.05,2.47),.12,.055,'Brass',interior)
    cylinder('Pendant_Diffuser',(x,2.05,2.438),.092,.01,'Ivory',interior)

CHAIRS=[]
TABLES=[(-2.75,-1.75,[math.radians(a) for a in (20,145,260)]),(2.6,-1.55,[math.radians(a) for a in (20,140,270)]),(3.10,-3.90,[0,math.pi])]
def chair(index,x,y,angle):
    ob=empty('Chair_'+str(index),furniture,(x,y,GROUND));ob.rotation_euler.z=angle-math.pi/2
    for k in range(5):box('Chair_SeatSlat',(0,-.175+k*.0875,.431),(.43,.078,.038),'Wood',ob,.007)
    for sx in (-1,1):
        for sy in (-1,1):beam('Chair_Leg',(sx*.215,sy*.205,0),(sx*.175,sy*.165,.435),.017,'Iron',ob)
        beam('Chair_SideRail',(sx*.175,-.165,.36),(sx*.175,.18,.36),.014,'Iron',ob)
        beam('Chair_BackPost',(sx*.18,.17,.36),(sx*.18,.25,.87),.016,'Iron',ob)
    for k in range(3):box('Chair_BackSlat',(0,.203+k*.014,.60+k*.115),(.44,.036,.088),'Wood',ob,.006,rotation=(-.10,0,0))
    beam('Chair_FrontBrace',(-.18,-.17,.32),(.18,-.17,.32),.013,'Iron',ob)
    CHAIRS.append({'id':ob.name,'position_blender':[x,y,GROUND],'angle_rad':angle-math.pi/2,'table_index':index//10})
    return ob

def round_table(index,x,y):
    table=empty('CafeTable_'+str(index),furniture,(x,y,GROUND))
    cylinder('Table_PedestalFoot',(0,0,.020),.245,.04,'Iron',table,40)
    cylinder('Table_PedestalStem',(0,0,.258),.039,.46,'Iron',table,20)
    cylinder('Table_UnderTop',(0,0,.465),.42,.02,'Iron',table,48)
    # Each top is made of clipped circular boards with narrow real joints.
    r=.56
    for j in range(11):
        y0=-r+j*(2*r/11)+.0025
        y1=-r+(j+1)*(2*r/11)-.0025
        outline=[]
        for t in np.linspace(y0,y1,5):outline.append((math.sqrt(max(0,r*r-t*t)),t))
        for t in np.linspace(y1,y0,5):outline.append((-math.sqrt(max(0,r*r-t*t)),t))
        vertices=[(xx,yy,zz) for zz in (.474,.50) for xx,yy in outline]
        n=len(outline);faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)]
        mesh_object('Table_TopBoard',vertices,faces,'Wood',table)
    for sx in (-1,1):beam('Table_UnderBrace',(0,0,.31),(sx*.32,0,.46),.02,'Iron',table)
    return table

for i,(x,y,angles) in enumerate(TABLES):
    table=round_table(i,x,y)
    for j,a in enumerate(angles):chair(i*10+j,x+math.cos(a)*.96,y+math.sin(a)*.96,a)
    cylinder('Table_Saucer',(x-.21,y+.11,.754),.088,.014,'Ceramic',furniture)
    cylinder('Table_CoffeeCup',(x-.21,y+.11,.803),.051,.083,'Ceramic',furniture)
    cylinder('Table_CoffeeSurface',(x-.21,y+.11,.845),.043,.003,'Coffee',furniture)
    beam('Cup_Handle',(x-.158,y+.11,.791),(x-.135,y+.11,.825),.009,'Ceramic',furniture)

# Leaf meshes use a tapered oval outline, a folded midrib and baked vein texture.
LEAF_COUNT=0
def leaves(name,records,parent):
    global LEAF_COUNT
    verts=[];faces=[];colors=[];uvs=[]
    outline=[(-.04,-.5),(-.24,-.27),(-.29,0),(-.20,.28),(0,.54),(.20,.28),(.29,0),(.24,-.27),(.04,-.5)]
    base=np.array([(0,0,.035)]+[(u,v,.07*(u*u+v*v)) for u,v in outline])
    for p,size,angle,tilt,tone in records:
        ca,sa=math.cos(angle),math.sin(angle);ct,st=math.cos(tilt),math.sin(tilt)
        rotation=np.array([[ca,-sa*ct,sa*st],[sa,ca*ct,-ca*st],[0,st,ct]])
        points=(base*size)@rotation.T+np.array(p)
        offset=len(verts);verts.extend(points)
        faces.extend((offset,offset+k+1,offset+(k+1)%len(outline)+1) for k in range(len(outline)))
        colors.extend([(*tone,1)]*len(base));uvs.extend([(.5,.5)]+[(u/.6+.5,(v+.5)/1.04) for u,v in outline])
    ob=mesh_object(name,verts,faces,'Leaf',parent,uv=False)
    uv=ob.data.uv_layers.new(name='LeafVeinUV')
    for loop in ob.data.loops:uv.data[loop.index].uv=uvs[loop.vertex_index]
    attr=ob.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
    ob.data.color_attributes.active_color=attr
    attr.data.foreach_set('color',np.array(colors,dtype=np.float32).ravel())
    # Blender preview uses the same multiplicative vertex colors as Godot.
    mat=M['Leaf']
    if not mat.node_tree.nodes.get('LeafVertexColor'):
        color_node=mat.node_tree.nodes.new('ShaderNodeVertexColor');color_node.name='LeafVertexColor';color_node.layer_name='Color'
        mix=mat.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1
        tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE')
        mat.node_tree.links.new(tex.outputs['Color'],mix.inputs[1]);mat.node_tree.links.new(color_node.outputs['Color'],mix.inputs[2]);mat.node_tree.links.new(mix.outputs[0],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    LEAF_COUNT+=len(records)
    return ob

def foliage_records(center,count,radius,size):
    records=[]
    for _ in range(count):
        a=rng.uniform(0,math.tau);h=rng.uniform(-.95,.95);r=radius*rng.random()**.38
        spread=math.sqrt(1-h*h)
        p=(center[0]+r*math.cos(a)*spread,center[1]+r*math.sin(a)*spread,center[2]+r*h*.65)
        tone=rng.uniform(.67,1.05)
        records.append((p,rng.uniform(size*.75,size*1.15),rng.uniform(0,math.tau),rng.uniform(-.8,.8),(tone*.96,tone,tone*.92)))
    return records

def tree(index,x,y,height):
    parent=empty('CourtyardTree_'+str(index),plants,(x,y,GROUND))
    sign=(-1 if index==1 else 1)
    originals=[]
    originals.append(curve_mesh('Tree_Trunk_Source',[(0,0,-.04),(.08*sign,.03,.55),(-.05*sign,.08,1.45),(.15*sign,-.06,2.10)],[.21,.17,.115,.075],'Bark',parent))
    for k in range(5):
        a=k*math.tau/5+.3
        originals.append(curve_mesh('Tree_Root_Source',[(0,0,.27),(.23*math.cos(a),.23*math.sin(a),.06),(.43*math.cos(a),.43*math.sin(a),-.04)],[.09,.045,.006],'Bark',parent))
    for branch in range(7):
        a=branch*math.tau/7+index*.41
        reach=rng.uniform(1.15,1.65)
        z=height-rng.uniform(.45,.9)
        tip=Vector((math.cos(a)*reach,math.sin(a)*reach,z))
        start=Vector((.08*sign,.04,1.42+rng.uniform(-.10,.24)))
        mid=start.lerp(tip,.53)+Vector((0,0,.17))
        branch_ob=curve_mesh('Tree_Primary_Source',[start,mid,tip],[.075,.046,.012],'Bark',parent)
        originals.append(branch_ob)
        for twig in range(4):
            t=.45+twig*.16
            origin=mid.lerp(tip,t)
            side=a+(-1 if twig%2 else 1)*rng.uniform(.65,1.2)
            end=origin+Vector((math.cos(side)*.61,math.sin(side)*.61,rng.uniform(.08,.42)))
            curve_mesh('Tree_Secondary',[origin,origin.lerp(end,.55)+Vector((0,0,.08)),end],[.025,.014,.0025],'Bark',parent)
            leaves(f'CrownClump_{index}_{branch}_{twig}',foliage_records(end,145,.54,.19),parent)
        leaves(f'CrownClump_{index}_{branch}_tip',foliage_records(tip,130,.59,.20),parent)
    for lead in range(5):
        a=lead*math.tau/5+index*.3
        end=Vector((math.cos(a)*rng.uniform(.3,.8),math.sin(a)*rng.uniform(.3,.8),height-rng.uniform(.06,.35)))
        start=Vector((.1*sign,.02,1.95))
        originals.append(curve_mesh('Tree_UprightLeader_Source',[start,start.lerp(end,.5)+Vector((0,0,.15)),end],[.055,.032,.004],'Bark',parent))
        leaves(f'CrownClump_{index}_leader_{lead}',foliage_records(end,130,.47,.19),parent)
        leaves(f'CrownClump_{index}_interior_{lead}',foliage_records(start.lerp(end,.74),105,.44,.19),parent)
    # Fuse major junctions; retain the original editable construction meshes in .blend.
    bpy.ops.object.select_all(action='DESELECT')
    copies=[]
    for original in originals:
        copy=original.copy();copy.data=original.data.copy();visual.objects.link(copy);copy.select_set(True);copies.append(copy)
        original['construction_source']=True;original.hide_render=True;original.hide_set(True)
    bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join()
    fused=copies[0];fused.name='ContinuousCourtyardTrunk_'+str(index)
    remesh=fused.modifiers.new('ContinuousBranchJunctions','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.027;remesh.use_smooth_shade=True;remesh.use_remove_disconnected=False
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth=fused.modifiers.new('SoftOrganicSurface','SMOOTH');smooth.factor=.23;smooth.iterations=2;bpy.ops.object.modifier_apply(modifier=smooth.name)
    uv_project(fused.data,2)
    fused.select_set(False)
tree(1,-5.35,.25,4.8)
tree(2,5.35,-1.10,4.4)
for side in (-1,1):
    for j in range(5):
        y=-3.9+j*1.66
        x=side*6.46
        points=[(x,y,.22),(x,y+.09,.52),(x,y-.10,.90),(x,y+.19,1.17)]
        curve_mesh('BoundaryClimber',points,[.012,.008,.005,.002],'LeafDark',plants)
        records=[]
        for k in range(28):
            z=rng.uniform(.33,1.21)
            records.append(((x+rng.uniform(-.02,.02),y+rng.uniform(-.22,.22),z),rng.uniform(.11,.18),rng.uniform(0,math.tau),rng.uniform(-.9,.9),(.72,.85,.67)))
        leaves('BoundaryClimberLeaves',records,plants)
    for j in range(9):
        y=.7+j*.5;x=side*rng.uniform(4.2,6.05)
        leaves('SideGardenSpray',foliage_records((x,y,.48),65,.25,.115),plants)

def pot(index,x,y,radius=.23,height=.40,base=GROUND,leafy=True):
    parent=empty('TerracottaPot_'+str(index),plants,(x,y,base))
    n=32
    profile=[(radius*.65,0),(radius*.74,.025),(radius*.94,height-.035),(radius,height-.022),(radius,height),(radius*.83,height),(radius*.82,height-.08),(0,height-.085)]
    verts=[(r*math.cos(k*math.tau/n),r*math.sin(k*math.tau/n),z) for r,z in profile for k in range(n)]
    faces=[(row*n+k,row*n+(k+1)%n,(row+1)*n+(k+1)%n,(row+1)*n+k) for row in range(len(profile)-1) for k in range(n)]
    ob=mesh_object('Pot_WithInnerRim',verts,faces,'PotClay',parent)
    for poly in ob.data.polygons:poly.use_smooth=True
    cylinder('Pot_Soil',(0,0,height-.075),radius*.82,.012,'Soil',parent)
    records=[]
    for k in range(12 if leafy else 6):
        a=k*math.tau/(12 if leafy else 6)+rng.uniform(-.15,.15)
        reach=radius*rng.uniform(.6,1.45)
        top=height+rng.uniform(.16,.52)*(radius/.23)
        origin=(0,0,height-.05)
        tip=(math.cos(a)*reach,math.sin(a)*reach,top)
        curve_mesh('Plant_Stem',[origin,(tip[0]*.55,tip[1]*.55,top-.12),tip],[.007,.005,.002],'LeafDark',parent)
        for j in range(4):
            f=.45+j*.17
            p=(tip[0]*f,tip[1]*f,height+(top-height)*f)
            records.append((p,rng.uniform(.11,.20)*(radius/.23),a+(j%2)*math.pi/2,rng.uniform(-.6,.5),(.90,.96,.84)))
    leaves('PotLeaves_'+str(index),records,parent)
POTS=[(-.92,.61,.22,.39),(.93,.61,.22,.39),(-3.0,.25,.23,.42),(3.0,.24,.26,.46),(-4.15,1.3,.24,.42),(4.22,1.75,.23,.42)]
for i,(x,y,r,h) in enumerate(POTS):pot(i,x,y,r,h)
for i,(x,y,_) in enumerate(TABLES):pot('Table_'+str(i),x+.08,y-.01,.074,.105,GROUND+.5,False)

# Irregular grasses and small real flowers at the front and around the tree roots.
for i in range(48):
    side=-1 if i<24 else 1
    x=side*rng.uniform(1.22,6.35);y=rng.uniform(-5.5,-4.99)
    records=foliage_records((x,y,.39),35,rng.uniform(.15,.24),.10)
    leaves('BorderLeafSpray_'+str(i),records,plants)
    if i%2==0:
        for flower in range(5):
            fx=x+rng.uniform(-.14,.14);fy=y+rng.uniform(-.12,.12);fz=rng.uniform(.39,.58)
            beam('FlowerStem',(fx,fy,.21),(fx,fy,fz),.003,'LeafDark',plants)
            petal=[];faces=[]
            for k in range(5):
                a=k*math.tau/5;u=Vector((math.cos(a),math.sin(a),0));v=Vector((-math.sin(a),math.cos(a),0));p=Vector((fx,fy,fz))
                offset=len(petal);petal.extend([p,p+u*.032-v*.018,p+u*.046,p+u*.032+v*.018]);faces.append(tuple(range(offset,offset+4)))
            mesh_object('TinyCreamFlower',petal,faces,'Petal',plants)
            cylinder('FlowerCenter',(fx,fy,fz+.002),.009,.004,'Pollen',plants,10)
grass_vertices=[];grass_faces=[]
for cx,cy in [(-5.35,.25),(5.35,-1.10)]+[(s*rng.uniform(1.3,6.3),rng.uniform(-5.45,-5.1)) for s in (-1,1) for _ in range(16)]:
    for j in range(22):
        a=rng.uniform(0,math.tau);length=rng.uniform(.17,.39);reach=rng.uniform(.09,.22)
        origin=Vector((cx+rng.uniform(-.19,.19),cy+rng.uniform(-.16,.16),.235 if cy>-4 else .22))
        direction=Vector((math.cos(a),math.sin(a),0));side=Vector((-math.sin(a),math.cos(a),0))*.008
        off=len(grass_vertices)
        for t in np.linspace(0,1,5):
            mid=origin+direction*reach*t*t+Vector((0,0,length*math.sin(t*1.35)))
            grass_vertices.extend((mid-side*(1-t*.92),mid+side*(1-t*.92)))
        grass_faces.extend((off+k*2,off+k*2+1,off+k*2+3,off+k*2+2) for k in range(4))
mesh_object('CurvedBorderGrasses',grass_vertices,grass_faces,'LeafDark',plants)

# A quiet wall-side bench, facing into the courtyard.
bench=empty('GardenBench',furniture,(-6.1,2.35,GROUND));bench.rotation_euler.z=math.pi/2
for i in range(4):box('BenchSeatSlat',(0,-.15+i*.10,.429),(1.52,.088,.038),'Wood',bench,.009)
for x in (-.58,.58):
    for y in (-.18,.18):beam('BenchLeg',(x,y,0),(x,y,.435),.025,'Iron',bench)
    beam('BenchBackPost',(x,.17,.38),(x,.24,.92),.022,'Iron',bench)
for i in range(3):box('BenchBackSlat',(0,.20+i*.018,.64+i*.12),(1.52,.045,.085),'Wood',bench,.009)

# Collision stays independent: broad ground, walls, table posts, chairs and trunks.
cr=empty('Cafe_Collision',collection=collision)
def solid(name,p,size):
    ob=box(name+'-colonly',p,size,'Iron',cr,0,collection=collision)
    ob.hide_render=True;ob.hide_set(True);ob.display_type='WIRE'
    return ob
solid('CourtyardFloor',(0,-1.8,.13),(12.8,6.4,.22))
solid('EntryFloor',(0,-5.42,.13),(1.9,1.56,.22))
solid('CafeFloor',(0,MID,.13),(W,DEPTH,.22))
solid('GardenFloor',(0,2.5,.12),(14,6,.22))
solid('CafeClosedFacade',(0,FRONT,1.72),(W,.20,2.96))
solid('CafeRearWall',(0,BACK,1.72),(W,.20,2.96))
for side in (-1,1):
    solid('CafeSideWall_'+str(side),(side*W/2,MID,1.72),(.20,DEPTH,2.96))
    solid('BoundaryWall_'+str(side),(side*6.68,.30,.77),(.24,10.70,1.10))
solid('RearGardenWall',(0,5.7,.80),(13.5,.24,1.16))
for i,(x,y,r,h) in enumerate(POTS):solid('Pot_'+str(i),(x,y,GROUND+h/2),(r*1.9,r*1.9,h))
for i,(x,y,_) in enumerate(TABLES):solid('Table_'+str(i),(x,y,.61),(.85,.85,.75))
for item in CHAIRS:
    x,y,_=item['position_blender']
    ob=solid(item['id'],(x,y,.67),(.47,.47,.86));ob.rotation_euler.z=item['angle_rad']
for i,(x,y) in enumerate([(-5.35,.25),(5.35,-1.10)]):solid('Trunk_'+str(i),(x,y,1.27),(.46,.46,2.08))
solid('GardenBench',(-6.1,2.35,.70),(.48,1.6,.92))
for side in (-1,1):solid('FrontBedEdge_'+str(side),(side*3.9,-5.65,.285),(5.8,.18,.27))

def export_collection(collection,path,omit_sources=False):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in collection.objects:
        if omit_sources and ob.get('construction_source'):continue
        hidden=ob.hide_get();ob.hide_set(False);ob.select_set(True);ob['was_hidden']=hidden
    # Standard GLB stores texture and COLOR_0 separately; Blender's preview mixes them.
    leaf_tree=M['Leaf'].node_tree
    base_socket=leaf_tree.nodes['Principled BSDF'].inputs['Base Color']
    source_socket=base_socket.links[0].from_socket
    if omit_sources:
        tex=next(n for n in leaf_tree.nodes if n.type=='TEX_IMAGE')
        leaf_tree.links.new(tex.outputs['Color'],base_socket)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_cameras=False,export_lights=False,export_materials='EXPORT',export_vertex_color='ACTIVE')
    if omit_sources:leaf_tree.links.new(source_socket,base_socket)
    for ob in collection.objects:
        ob.select_set(False)
        if 'was_hidden' in ob:ob.hide_set(ob['was_hidden']);del ob['was_hidden']
export_collection(visual,ASSETS/'cafe_courtyard.glb',True)
export_collection(collision,ASSETS/'cafe_courtyard_collision.glb')

# Presentation assets, lights and cameras do not enter the model GLB.
sr=empty('PREVIEW_ONLY_Presentation',collection=stage)
box('ThinCutStonePlinth',(0,0,-.48),(14.12,12.12,.10),'Stone',sr,.025,collection=stage)
box('StudioFloor',(0,0,-.555),(200,200,.04),'Studio',sr,0,collection=stage)
export_collection(stage,ASSETS/'presentation_stage.glb')
world=bpy.data.worlds.new('WarmNeutralStudio');world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.73,.75,.70,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.50
scene.world=world
def aim(ob,target):ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
for name,power,location,color in [('WarmSun',2.1,(-8,-10,17),(1,.91,.78)),('CoolFill',.18,(8,5,10),(.86,.92,1))]:
    light=bpy.data.objects.new(name,bpy.data.lights.new(name,'SUN'));stage.objects.link(light);light.data.energy=power;light.data.color=color;light.data.angle=.10;light.location=location;aim(light,(0,0,1.0))
for x in (-1.95,1.95):
    light=bpy.data.objects.new('InteriorWarmFill',bpy.data.lights.new('InteriorWarmFill','AREA'));stage.objects.link(light);light.location=(x,2.3,2.73);light.data.energy=35;light.data.color=(1,.73,.42);light.data.shape='DISK';light.data.size=1.3
camera=bpy.data.objects.new('Cafe_ReviewCamera',bpy.data.cameras.new('Cafe_ReviewCamera'));stage.objects.link(camera)
camera.location=(16,-21,17);camera.data.type='ORTHO';camera.data.ortho_scale=21;aim(camera,(0,0,1.20));scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
preferences=bpy.context.preferences.addons['cycles'].preferences;preferences.compute_device_type='OPTIX';preferences.get_devices()
for device in preferences.devices:device.use=device.type=='OPTIX'
scene.cycles.device='GPU'
scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.35
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(RENDERS/'blender_overview.png')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
blend=CAMPUS/'blender/source/cafe_courtyard.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
meshes=[o for o in visual.objects if o.type=='MESH' and not o.get('construction_source')]
triangles=0
for ob in meshes:ob.data.calc_loop_triangles();triangles+=len(ob.data.loop_triangles)
report={'brief':BRIEF,'authoring':'native Blender bpy mesh/curve/text geometry','blend':str(blend),'visual_meshes':len(meshes),'triangles':triangles,'packed_images':sum(bool(i.packed_file) for i in bpy.data.images),'trees':2,'tables':3,'chairs':CHAIRS,'leaves':LEAF_COUNT,'collision_shapes':sum(o.type=='MESH' for o in collision.objects),'roof_tiles':464,'door_status':'closed modeled door; courtyard walkthrough only'}
(ASSETS/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(RENDERS/'build.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.render.render(write_still=True)
print(json.dumps({k:report[k] for k in ('visual_meshes','triangles','packed_images','trees','tables','leaves','collision_shapes')},indent=2))
