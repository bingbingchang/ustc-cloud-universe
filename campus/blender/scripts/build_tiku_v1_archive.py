"""Tiku boy 01: reference-led adult proportions, facial landmarks and named rigid rig."""
from pathlib import Path
exec((Path(__file__).with_name('build_life.py')).read_text(encoding='utf-8').split('for index,kind in enumerate')[0])
import random,bmesh
random.seed(81)
for key,c in {'Skin':(.70,.56,.43),'Hair':(.024,.027,.027),'Ink':(.035,.041,.044),'Navy':(.29,.42,.60),'Cream':(.86,.86,.78),'Trouser':(.13,.15,.17),'Shoe':(.085,.098,.11),'Sole':(.30,.32,.31),'Page':(.87,.84,.74),'Cover':(.16,.24,.30)}.items():
 M[key].diffuse_color=(*c,1);M[key].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1)

def loft(name,parent,rings,mat,segments=32):
 verts=[]
 for y,w,d,z in rings:
  for i in range(segments):
   a=i*math.tau/segments;verts.append(pt((w*math.sin(a),y,z-d*math.cos(a))))
 faces=[]
 for j in range(len(rings)-1):
  for i in range(segments):
   a=j*segments+i;b=j*segments+(i+1)%segments;faces.append((a,b,b+segments,a+segments))
 faces.extend([tuple(reversed(range(segments))),tuple((len(rings)-1)*segments+i for i in range(segments))])
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.materials.append(M[mat]);o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.parent=parent
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
 if name in ['AngularAdultFace','Nose','Buzzcut']:
  sub=o.modifiers.new('Refined silhouette','SUBSURF');sub.levels=2;sub.render_levels=2
 for f in me.polygons:f.use_smooth=True
 return o

root=node('TikuBoy01');torso=node('Tiku_Torso',root)
loft('Sweater',torso,[(.03,.13,.08,.01),(.075,.132,.078,.01),(.22,.14,.085,0),(.39,.165,.085,0),(.47,.155,.064,0),(.51,.062,.055,0)],'Navy')
cube('RibbedHem',torso,(0,.048,.005),(.27,.05,.165),'Navy',.015)
rod('Neck',torso,(0,.46,0),(0,.59,0),.045,'Skin')
loft('CollarBand',torso,[(.495,.059,.059,0),(.522,.048,.048,0)],'Cream')
for side in [-1,1]:
 triangle('WhiteCollar',torso,[(side*.008,.49,-.070),(side*.057,.535,-.026),(side*.112,.435,-.084)],'Cream')
 triangle('WhiteCollarFold',torso,[(side*.008,.49,-.070),(side*.112,.435,-.084),(side*.045,.423,-.086)],'Cream')
 suffix='L' if side<0 else 'R'
 arm=node('Tiku_Arm'+suffix,root,(side*.175,.46,0))
 ball('ShoulderSeam',arm,(0,-.025,0),(.066,.068,.064),'Navy')
 loft('Sleeve',arm,[(0,.067,.065,0),(-.10,.06,.060,0),(-.25,.047,.047,0),(-.29,.042,.042,0)],'Navy')
 fore=node('Tiku_Fore'+suffix,arm,(0,-.29,0))
 ball('ElbowSeam',fore,(0,0,0),(.043,.043,.043),'Navy')
 loft('SleeveFore',fore,[(0,.044,.044,0),(-.13,.042,.043,0),(-.24,.032,.034,0)],'Navy')
 cube('Cuff',fore,(0,-.237,0),(.069,.035,.07),'Navy',.01)
 ball('Hand',fore,(0,-.280,-.003),(.033,.055,.020),'Skin')
 for j in range(4):rod('Finger',fore,(-.020+j*.012,-.302,-.013),(-.018+j*.011,-.335,-.014),.006,'Skin')
 ball('Thumb',fore,(-side*.032,-.277,-.007),(.013,.027,.016),'Skin')
 leg=node('Tiku_Leg'+suffix,root,(side*.082,0,0))
 loft('TrouserThigh',leg,[(.03,.080,.075,0),(-.12,.075,.067,0),(-.32,.059,.057,0),(-.43,.056,.052,0)],'Trouser')
 knee=node('Tiku_Knee'+suffix,leg,(0,-.43,0))
 ball('KneeFold',knee,(0,0,0),(.055,.055,.052),'Trouser')
 loft('TrouserShin',knee,[(0,.055,.054,0),(-.24,.047,.048,0),(-.39,.048,.047,0)],'Trouser')
 cube('Shoe',knee,(0,-.410,-.045),(.125,.09,.24),'Shoe',.025)
 cube('Sole',knee,(0,-.452,-.045),(.126,.024,.24),'Sole',.012)
 for j in range(3):rod('Laces',knee,(-.035,-.366,-.04-j*.018),(.035,-.366,-.04-j*.018),.0028,'Sole')
head=node('Tiku_Head',root,(0,.57,-.015))
loft('AngularAdultFace',head,[(0,.029,.043,-.020),(.020,.049,.065,-.019),(.055,.068,.076,-.01),(.105,.081,.082,0),(.16,.090,.083,.004),(.215,.091,.080,.008),(.267,.079,.074,.008),(.296,.046,.05,.005),(.303,.005,.009,0)],'Skin')
loft('Buzzcut',head,[(.252,.087,.077,.008),(.273,.080,.071,.008),(.292,.065,.058,.005),(.308,.038,.037,0),(.313,.006,.007,0)],'Hair')
for i in range(0):
 a=random.uniform(0,math.tau);y=random.uniform(.232,.296);r=.091*math.sqrt(max(.1,1-((y-.23)/.086)**2));x=r*math.sin(a);z=.007-r*.89*math.cos(a)
 rod('HairStroke',head,(x,y,z),(x*.99,y+.006,z*.99),.0013,'Hair')
for side in [-1,1]:
 ball('Ear',head,(side*.09,.145,.007),(.020,.038,.018),'Skin')
 rod('EarFold',head,(side*.099,.129,-.008),(side*.101,.166,-.008),.002,'Trouser')
 # Lens is intentionally clear/open so the sideways eyes remain visible.
 eye=node('Tiku_Eye'+('L' if side<0 else 'R'),head,(side*.045,.166,-.077))
 ball('NarrowEyeWhite',eye,(0,0,-.004),(.026,.0065,.006),'Cream')
 pupil=node('Tiku_Pupil'+('L' if side<0 else 'R'),eye,(.006,0,-.010))
 ball('Pupil',pupil,(0,0,0),(.0042,.0055,.002),'Ink')
 rod('UpperLid',eye,(-.026,.004,-.008),(.026,.003,-.008),.0022,'Ink')
 rod('LowerLid',eye,(-.022,-.004,-.007),(.022,-.004,-.007),.0012,'Skin')
 for j in range(6):rod('Brow',head,(side*.047-.024+j*.008,.190+math.sin(j*.5)*.004,-.077),(side*.047-.029+j*.008,.195+math.sin(j*.5)*.004,-.076),.0017,'Hair')
 cx=side*.045
 points=[(-.039,.018),(-.031,.023),(.027,.023),(.039,.015),(.032,-.031),(.019,-.038),(-.022,-.038),(-.034,-.028)]
 for i,(x,y) in enumerate(points):
  nx,ny=points[(i+1)%len(points)];rod('RectangularGlasses',head,(cx+x,.17+y,-.092),(cx+nx,.17+ny,-.092),.0026,'Ink');ball('FrameJoint',head,(cx+x,.17+y,-.092),(.0026,.0026,.0026),'Ink')
 rod('TempleArm',head,(side*.084,.186,-.088),(side*.096,.174,.031),.003,'Ink')
rod('GlassesBridge',head,(-.009,.185,-.093),(.009,.185,-.093),.003,'Ink')
# Explicit nose bridge, wings and thin restrained mouth.
loft('Nose',head,[(.092,.012,.008,-.084),(.103,.019,.018,-.086),(.117,.011,.021,-.086),(.158,.008,.005,-.080)],'Skin',16)
for side in [-1,1]:
 rod('Nostril',head,(side*.010,.098,-.103),(side*.018,.102,-.099),.0013,'Trouser')
 for j in range(7):
  x=side*(.006+j*.0037);y=.080-abs(x)*.10
  rod('Moustache',head,(x,y+random.uniform(-.001,.001),-.084),(x+side*.002,y+random.uniform(.003,.006),-.083),.00055,'Hair')
rod('MouthLeft',head,(-.025,.064,-.083),(0,.066,-.087),.0015,'Trouser')
rod('MouthRight',head,(0,.066,-.087),(.025,.063,-.083),.0015,'Trouser')
for j in range(10):
 x=-.021+j*.0046;rod('ChinStubble',head,(x,.024,-.068),(x+.001,.028,-.070),.0007,'Hair')
book=node('Tiku_Book',root,(0,.105,-.29));cube('HardCover',book,(0,0,0),(.32,.020,.25),'Cover',.005);cube('Paper',book,(0,.015,0),(.31,.012,.24),'Page',.003)
for side in [-1,1]:
 for j in range(7):rod('Notes',book,(side*.078-.062,.024,-.097+j*.028),(side*.078+.054,.024,-.097+j*.028),.0007,'Cover')
page=node('Tiku_Page',book);cube('TurningPage',page,(.076,.026,0),(.148,.0015,.23),'Page',.0005)
pen=node('Tiku_Pen',root);rod('Pen',pen,(0,0,0),(.022,.13,.022),.004,'Ink');rod('PenTip',pen,(0,0,0),(.004,.023,.004),.0012,'Metal')
# Fuse same-pivot cloth pieces to remove overlapping shoulder/elbow caps.
for pivot in [root]+[o for o in root.children_recursive if o.type=='EMPTY']:
 for key in ['Navy','Trouser']:
  group=[o for o in pivot.children if o.type=='MESH' and o.data.materials and o.data.materials[0]==M[key]]
  if not group:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0];bpy.ops.object.convert(target='MESH');bpy.ops.object.join();obj=bpy.context.object
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  voxel=obj.modifiers.new('Continuous cloth volume','REMESH');voxel.mode='VOXEL';voxel.voxel_size=.003;voxel.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=voxel.name)
  smooth=obj.modifiers.new('Cloth polish','SMOOTH');smooth.factor=.6;smooth.iterations=3;bpy.ops.object.modifier_apply(modifier=smooth.name)
  dec=obj.modifiers.new('Realtime cloth','DECIMATE');dec.ratio=.40;bpy.ops.object.modifier_apply(modifier=dec.name)
  for f in obj.data.polygons:f.use_smooth=True
export(root,'tiku_boy1.glb')
bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender/source/tiku_boy1.blend'))
print('TIKU_ASSET_OK')
