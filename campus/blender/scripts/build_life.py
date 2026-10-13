"""Original articulated campus miniatures and shared props. No third-party/IP assets."""
import bpy, math
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system='METRIC'
M={}
for name,c in {'Skin':(.82,.60,.44),'Hair':(.055,.040,.036),'Ink':(.022,.033,.038),'Cream':(.81,.76,.64),'Navy':(.12,.23,.29),'Mint':(.29,.44,.38),'Rust':(.57,.28,.19),'Trouser':(.13,.17,.20),'Shoe':(.15,.16,.15),'Sole':(.68,.66,.57),'Page':(.89,.85,.72),'Cover':(.28,.44,.46),'Metal':(.20,.29,.30),'Wood':(.36,.25,.15),'Stone':(.61,.60,.51),'Blush':(.78,.32,.29),'CatCream':(.82,.75,.57),'CatOrange':(.61,.36,.16),'BirdBrown':(.28,.22,.16),'BirdCream':(.67,.59,.43),'Leaf':(.24,.36,.16),'Flower':(.82,.62,.54)}.items():
 m=bpy.data.materials.new('Life'+name);m.diffuse_color=(*c,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.82;M[name]=m

def pt(p):return (p[0],-p[2],p[1])
def node(name,parent=None,pos=(0,0,0)):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=parent;o.location=pt(pos);return o

def finish(o,name,parent,pos,mat):
 o.name=name;o.parent=parent;o.location=pt(pos);o.data.materials.append(M[mat]);return o

def ball(name,parent,pos,size,mat):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12)
 o=bpy.context.object;o.scale=(size[0],size[2],size[1]);finish(o,name,parent,pos,mat)
 for p in o.data.polygons:p.use_smooth=True
 return o

def cube(name,parent,pos,size,mat,bevel=.025):
 bpy.ops.mesh.primitive_cube_add();o=bpy.context.object;o.scale=(size[0]/2,size[2]/2,size[1]/2)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);finish(o,name,parent,pos,mat)
 for face in o.data.polygons:face.use_smooth=True
 b=o.modifiers.new('Soft manufactured edge','BEVEL');b.width=bevel;b.segments=5
 n=o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');n.keep_sharp=True;return o

def rod(name,parent,a,b,r,mat):
 a=Vector(pt(a));b=Vector(pt(b));d=b-a
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=d.length);o=bpy.context.object;o.name=name;o.parent=parent;o.location=(a+b)/2;o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y');o.data.materials.append(M[mat])
 for p in o.data.polygons:p.use_smooth=True
 return o

def triangle(name,parent,verts,mat):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([pt(v) for v in verts],[],[(0,1,2),(2,1,0)]);mesh.materials.append(M[mat]);o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.parent=parent;return o

def ring(name,parent,pos,r,mat):
 for i in range(24):
  a=i*math.tau/24;b=(i+1)*math.tau/24
  rod(name,parent,(pos[0]+r*math.cos(a),pos[1]+r*math.sin(a),pos[2]),(pos[0]+r*math.cos(b),pos[1]+r*math.sin(b),pos[2]),.007,mat)

def export(root,file):
 # Join only meshes attached to the same animated pivot and using the same material.
 for pivot in [root]+[o for o in root.children_recursive if o.type=='EMPTY']:
  groups={}
  for ch in list(pivot.children):
   if ch.type=='MESH':groups.setdefault(ch.data.materials[0].name,[]).append(ch)
  for group in groups.values():
   if len(group)<2:continue
   bpy.ops.object.select_all(action='DESELECT')
   for o in group:o.select_set(True)
   bpy.context.view_layer.objects.active=group[0];bpy.ops.object.convert(target='MESH');bpy.ops.object.join()
 bpy.ops.object.select_all(action='DESELECT')
 for o in [root]+list(root.children_recursive):o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(R/'godot/assets'/file),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)

for index,kind in enumerate(['solver','reader','photo']):
 name='Student'+kind.capitalize();root=node(name)
 shirt=['Navy','Mint','Rust'][index]
 torso=node(name+'_Torso',root)
 cube(name+'Shirt',torso,(0,.91,0),(.45,.59,.28),shirt,.10)
 cube(name+'Hem',torso,(0,.61,0),(.43,.09,.28),shirt,.022)
 ball(name+'Neck',torso,(0,1.22,0),(.085,.10,.075),'Skin')
 for side in [-1,1]:
  suffix='L' if side<0 else 'R'
  arm=node(name+'_Arm'+suffix,root,(side*.25,1.08,0))
  ball(name+'Sleeve',arm,(0,-.12,0),(.088,.19,.087),shirt)
  fore=node(name+'_Fore'+suffix,arm,(0,-.29,0))
  ball(name+'Forearm',fore,(0,-.105,0),(.060,.14,.059),'Skin')
  ball(name+'Hand',fore,(0,-.255,0),(.063,.070,.048),'Skin')
  leg=node(name+'_Leg'+suffix,root,(side*.115,.58,0))
  cube(name+'Thigh',leg,(0,-.14,0),(.16,.31,.18),'Trouser',.065)
  knee=node(name+'_Knee'+suffix,leg,(0,-.28,0))
  cube(name+'Shin',knee,(0,-.115,0),(.13,.28,.145),'Trouser',.05)
  cube(name+'Shoe',knee,(0,-.24,-.055),(.17,.12,.29),'Shoe',.048)
  cube(name+'Sole',knee,(0,-.288,-.055),(.17,.025,.29),'Sole',.009)
 head=node(name+'_Head',root,(0,1.20,0))
 ball(name+'Head',head,(0,.235,0),(.245,.265,.215),'Skin')
 for side in [-1,1]:
  ball(name+'Ear',head,(side*.244,.21,.015),(.044,.073,.032),'Skin')
  ball(name+'Eye',head,(side*.087,.26,-.203),(.025,.039,.014),'Ink')
  ball(name+'EyeLight',head,(side*.081,.274,-.218),(.008,.011,.005),'Cream')
  rod(name+'Brow',head,(side*.085-.032,.328,-.204),(side*.085+.029,.332,-.204),.009,'Hair')
  ball(name+'Cheek',head,(side*.151,.19,-.184),(.035,.017,.009),'Blush')
 ball(name+'Nose',head,(0,.207,-.222),(.022,.027,.024),'Skin')
 rod(name+'Mouth',head,(-.025,.14,-.205),(.025,.14,-.205),.006,'Hair')
 ball(name+'HairCap',head,(0,.40,.015),(.255,.147,.223),'Hair')
 for j in range(5):
  ball(name+'Fringe',head,(-.19+j*.088,.38-abs(j-2)*.018,-.146),(.072,.088,.074),'Hair')
 if kind=='reader':
  for side in [-1,1]:ball(name+'Bob',head,(side*.215,.15,.04),(.08,.25,.17),'Hair')
  ball(name+'BobBack',head,(0,.19,.17),(.245,.25,.06),'Hair')
 if kind=='solver':
  for side in [-1,1]:ring(name+'Glasses',head,(side*.091,.258,-.230),.075,'Metal')
  rod(name+'GlassesBridge',head,(-.016,.26,-.23),(.016,.26,-.23),.007,'Metal')
  for side in [-1,1]:rod(name+'GlassesArm',head,(side*.168,.265,-.22),(side*.23,.26,0),.006,'Metal')
 if kind in ['solver','reader']:
  book=node(name+'_Book',root,(0,.81,-.43) if kind=='solver' else (0,.97,-.37))
  cube(name+'Cover',book,(0,0,0),(.43,.035,.29),'Cover',.009)
  cube(name+'Pages',book,(0,.023,0),(.41,.022,.275),'Page',.005)
  for side in [-1,1]:
   for j in range(5):rod(name+'Writing',book,(side*.11-.075,.039,-.095+j*.043),(side*.11+.065,.039,-.095+j*.043),.0018,'Cover')
  page=node(name+'_Page',book)
  cube(name+'TurnPage',page,(.1,.043,0),(.195,.003,.266),'Page',.001)
 if kind=='solver':
  pen=node(name+'_Pen',root,(.14,.86,-.45));rod(name+'Pen',pen,(0,-.055,0),(.025,.075,.025),.009,'Rust')
 if kind=='photo':
  phone=node(name+'_Phone',root,(0,1.35,-.50))
  cube(name+'Phone',phone,(0,0,0),(.16,.255,.022),'Ink',.015)
  cube(name+'Screen',phone,(0,0,.013),(.14,.22,.004),'Cover',.008)
  ball(name+'Lens',phone,(-.045,.08,-.018),(.017,.017,.005),'Sole')
 export(root,'student_'+kind+'.glb')
 # Keep source variants next to each other for editing; exports already retain origin.
 root.location.x=index*2.0

root=node('CampusCat')
ball('CatLoaf',root,(0,.19,.02),(.20,.19,.36),'CatCream')
ball('CatPatch',root,(.055,.28,.11),(.17,.10,.21),'CatOrange')
head=node('Cat_Head',root,(0,.29,-.28))
ball('CatFace',head,(0,0,0),(.16,.145,.14),'CatCream')
for side in [-1,1]:
 verts=[(side*.08,.075,-.035),(side*.16,.065,-.035),(side*.135,.24,-.01),(side*.08,.075,.045),(side*.16,.065,.045),(side*.135,.24,.02)]
 mesh=bpy.data.meshes.new('EarVolume');mesh.from_pydata([pt(v) for v in verts],[],[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)]);mesh.materials.append(M['CatOrange']);ear=bpy.data.objects.new('CatEar',mesh);bpy.context.collection.objects.link(ear);ear.parent=head
 bevel=ear.modifiers.new('Ear soft edge','BEVEL');bevel.width=.007;bevel.segments=3
 triangle('CatInnerEar',head,[(side*.097,.092,-.028),(side*.15,.082,-.028),(side*.131,.199,-.028)],'Blush')
 rod('CatSleepEye',head,(side*.060-.025,.01,-.129),(side*.060+.025,.005,-.137),.005,'Ink')
 for j in range(2):rod('Whisker',head,(side*.06,-.045,-.14),(side*.21,-.036+j*.035,-.14),.002,'Cream')
ball('CatNose',head,(0,-.035,-.142),(.016,.012,.012),'Blush')
for side in [-1,1]:
 paw=node('Cat_Paw'+('L' if side<0 else 'R'),root,(side*.105,.075,-.28));ball('CatPaw',paw,(0,0,-.055),(.065,.058,.105),'CatCream')
tail=node('Cat_Tail',root,(0,.17,.27))
for i in range(14):
 a=i/14*math.pi*1.4;b=(i+1)/14*math.pi*1.4
 rod('CatTail',tail,(.23*math.sin(a),-.025*a,.18*math.cos(a)),(.23*math.sin(b),-.025*b,.18*math.cos(b)),.035,'CatOrange')
export(root,'campus_cat.glb');root.location.x=6
root=node('CampusSparrow')
ball('BirdBody',root,(0,.13,.015),(.075,.095,.12),'BirdBrown')
ball('BirdBreast',root,(0,.12,-.045),(.063,.075,.070),'BirdCream')
ball('BirdHead',root,(0,.235,-.048),(.065,.065,.063),'BirdBrown')
for side in [-1,1]:
 ball('BirdEye',root,(side*.044,.25,-.088),(.009,.010,.009),'Ink')
 rod('BirdFoot',root,(side*.031,.07,.01),(side*.031,.01,-.014),.004,'Rust')
 rod('BirdToe',root,(side*.031,.01,-.014),(side*.031,.01,-.053),.003,'Rust')
 wing=node('Bird_Wing'+('L' if side<0 else 'R'),root,(side*.07,.16,.01));ball('Wing',wing,(side*.027,0,.03),(.04,.075,.1),'BirdBrown')
triangle('Beak',root,[(-.027,.23,-.1),(.027,.23,-.1),(0,.216,-.167)],'Rust')
cube('BirdTail',root,(0,.16,.16),(.065,.025,.15),'BirdBrown',.008)
export(root,'campus_sparrow.glb');root.location.x=7
root=node('StudyDesk')
cube('DeskTop',root,(0,.77,0),(1.05,.085,.56),'Wood',.035)
for x in [-.40,.40]:
 for z in [-.17,.17]:cube('DeskLeg',root,(x,.36,z),(.05,.72,.05),'Metal',.012)
export(root,'study_desk.glb');root.location.x=8
root=node('Bulletin')
for x in [-1.06,1.06]:cube('Post',root,(x,1.20,0),(.09,2.4,.10),'Metal',.025)
cube('Frame',root,(0,1.65,0),(2.5,1.4,.17),'Metal',.05)
cube('Board',root,(0,1.65,-.095),(2.30,1.20,.05),'Wood',.025)
cube('Cap',root,(0,2.42,0),(2.72,.11,.45),'Metal',.035)
for x in [-.69,0,.69]:
 cube('Poster',root,(x,1.67,-.132),(.58,.91,.017),'Page',.008)
 cube('PosterTitle',root,(x,1.97,-.145),(.44,.045,.009),'Cover',.003)
 for j in range(5):cube('PosterLine',root,(x,1.74-j*.10,-.145),(.39 if j%2 else .44,.018,.007),'Cover',.002)
export(root,'bulletin.glb');root.location.x=10
root=node('CampusBin')
cube('BinBody',root,(0,.45,0),(.55,.90,.45),'Metal',.06)
cube('BinTop',root,(0,.94,0),(.60,.11,.50),'Wood',.045)
cube('BinOpening',root,(0,.76,-.231),(.35,.16,.01),'Ink',.025)
for i in range(5):cube('BinSlat',root,(-.20+i*.10,.40,-.239),(.062,.43,.03),'Wood',.02)
export(root,'campus_bin.glb');root.location.x=12
root=node('BookBag')
cube('Bag',root,(0,.27,0),(.33,.47,.19),'Navy',.075)
cube('Pocket',root,(0,.21,-.105),(.25,.19,.04),'Cover',.035)
rod('Handle',root,(-.07,.50,0),(.07,.50,0),.014,'Metal')
export(root,'book_bag.glb');root.location.x=14
bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender/source/campus_life.blend'))
print('CAMPUS_LIFE_ASSETS_OK')

