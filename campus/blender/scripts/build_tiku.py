"""Tiku boy 01: reference-led adult proportions, facial landmarks and named rigid rig."""
from pathlib import Path
exec((Path(__file__).with_name('build_life.py')).read_text(encoding='utf-8').split('for index,kind in enumerate')[0])
import random,bmesh,sys
UNIFORM='--uniform' in sys.argv
random.seed(81)
for key,c in {'Skin':(.70,.56,.43),'Hair':(.024,.027,.027),'Ink':(.035,.041,.044),'Navy':(.29,.42,.60),'Cream':(.86,.86,.78),'Trouser':(.13,.15,.17),'Shoe':(.085,.098,.11),'Sole':(.30,.32,.31),'Page':(.87,.84,.74),'Cover':(.16,.24,.30)}.items():
 M[key].diffuse_color=(*c,1);M[key].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1)
if UNIFORM:
 M['Navy'].diffuse_color=(.085,.19,.38,1);M['Navy'].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.085,.19,.38,1)
 M['Navy'].name='TikuUniformBlue'
else:M['Navy'].name='TikuSweater'

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
 if UNIFORM and name in ['Sleeve','SleeveFore','ElbowSeam']:me.materials[0]=M['Cream']
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
 if name in ['Nose']:
  sub=o.modifiers.new('Refined silhouette','SUBSURF');sub.levels=2;sub.render_levels=2
 for f in me.polygons:f.use_smooth=True
 return o

root=node('TikuBoy01');torso=node('Tiku_Torso',root)
if not UNIFORM:
 loft('Sweater',torso,[(.03,.13,.074,.01),(.065,.132,.076,.01),(.095,.143,.081,.008),(.15,.143,.078,.004),(.22,.14,.075,0),(.32,.153,.081,0),(.39,.166,.078,0),(.425,.166,.068,0),(.465,.135,.057,0),(.493,.052,.040,0)],'Navy',48)
else:
 jacket=loft('UniformJacket',torso,[(.03,.134,.079,.01),(.07,.138,.082,.01),(.11,.150,.088,.006),(.23,.15,.086,0),(.30,.16,.087,0),(.322,.164,.087,0),(.330,.165,.087,0),(.355,.166,.085,0),(.425,.168,.069,0),(.465,.135,.060,0),(.493,.052,.043,0)],'Navy',64)
 jacket.data.materials.append(M['Cream'])
 for v in jacket.data.vertices:
  y=v.co.z
  if .30<=y<=.355:v.co.z+=abs(v.co.x)*.31*max(0,min(1,v.co.y/.02))
 for f in jacket.data.polygons:
  row=f.index//64
  if row>=7 or row==5:f.material_index=1
 rod('WhiteZip',torso,(0,.067,-.090),(0,.487,-.064),.003,'Cream')
 cube('ZipPull',torso,(0,.471,-.070),(.012,.018,.005),'Metal',.002)
 for side in [-1,1]:
  rod('PocketWelt',torso,(side*.081,.12,-.077),(side*.122,.20,-.061),.003,'Navy')
cube('RibbedHem',torso,(0,.048,.005),(.27,.05,.165),'Navy',.015)
rod('Neck',torso,(0,.46,0),(0,.592,0),.041,'Skin')
loft('CollarBand',torso,[(.489,.051,.048,0),(.516,.046,.047,0)],'Cream',64)
for side in [-1,1]:
 cm=bpy.data.meshes.new('CollarFold');cm.from_pydata([pt(v) for v in [(side*.003,.471,-.067),(side*.037,.516,-.026),(side*.083,.453,-.067)]],[],[(0,1,2)]);cm.materials.append(M['Cream']);cm.update()
 if cm.polygons[0].normal.y<0:cm.polygons[0].flip()
 co=bpy.data.objects.new('WhiteCollar',cm);bpy.context.collection.objects.link(co);co.parent=torso
 solid=co.modifiers.new('Folded cotton thickness','SOLIDIFY');solid.thickness=.0015
 suffix='L' if side<0 else 'R'
 arm=node('Tiku_Arm'+suffix,root,(side*.159,.441,0))
 loft('Sleeve',arm,[(.028,.006,.006,0),(.020,.036,.038,0),(0,.055,.057,0),(-.05,.061,.060,0),(-.12,.055,.055,0),(-.19,.048,.047,0),(-.235,.046,.046,.002),(-.26,.049,.049,.004),(-.29,.041,.041,0)],'Navy',40)
 if UNIFORM:
  loft('BlueSleeveBand',arm,[(-.10,.058,.058,0),(-.123,.056,.056,0)],'Navy',40)
  loft('BlueSleeveFineBand',arm,[(-.144,.054,.054,0),(-.154,.053,.053,0)],'Navy',40)
 fore=node('Tiku_Fore'+suffix,arm,(0,-.29,0))
 ball('ElbowSeam',fore,(0,0,0),(.043,.043,.043),'Cream' if UNIFORM else 'Navy')
 loft('SleeveFore',fore,[(0,.044,.044,0),(-.04,.049,.047,0),(-.10,.042,.041,0),(-.145,.040,.043,.002),(-.19,.042,.040,0),(-.22,.036,.038,0),(-.24,.032,.034,0)],'Navy',40)
 cube('Cuff',fore,(0,-.237,0),(.069,.035,.07),'Navy',.01)
 hand=node('Tiku_Hand'+suffix,fore,(0,-.280,0))
 ball('Palm',hand,(0,0,0),(.027,.031,.016),'Skin')
 for j in range(4):
  x=-.017+j*.011
  if side>0:
   rod('FingerBase',hand,(x,-.022,-.001),(x,-.039,-.010),.005,'Skin')
   rod('BentFinger',hand,(x,-.039,-.010),(x,-.034,-.029),.0046,'Skin')
  else:
   rod('FingerBase',hand,(x,-.023,0),(x,-.041,-.003),.005,'Skin')
   rod('FingerTip',hand,(x,-.041,-.003),(x,-.051,-.009),.0047,'Skin')
 rod('Thumb',hand,(-side*.026,.007,-.001),(-side*.030,-.013,-.017),.009,'Skin')
 rod('ThumbTip',hand,(-side*.030,-.013,-.017),(-side*.015,-.024,-.027),.007,'Skin')
 leg=node('Tiku_Leg'+suffix,root,(side*.082,0,0))
 loft('TrouserThigh',leg,[(.03,.080,.075,0),(-.12,.075,.067,0),(-.32,.059,.057,0),(-.43,.056,.052,0)],'Trouser')
 knee=node('Tiku_Knee'+suffix,leg,(0,-.43,0))
 ball('KneeFold',knee,(0,0,0),(.055,.055,.052),'Trouser')
 loft('TrouserShin',knee,[(0,.055,.054,0),(-.24,.047,.048,0),(-.39,.048,.047,0)],'Trouser')
 if UNIFORM:
  rod('TrackStripeThigh',leg,(side*.081,-.025,0),(side*.058,-.42,0),.0027,'Cream')
  rod('TrackStripeShin',knee,(side*.056,-.02,0),(side*.049,-.39,0),.0027,'Cream')
 cube('Shoe',knee,(0,-.410,-.045),(.125,.09,.24),'Shoe',.025)
 cube('Sole',knee,(0,-.452,-.045),(.126,.024,.24),'Sole',.012)
 for j in range(3):rod('Laces',knee,(-.035,-.366,-.04-j*.018),(.035,-.366,-.04-j*.018),.0028,'Sole')
exec(Path(__file__).with_name('tiku_head.py').read_text(encoding='utf-8'))
book=node('Tiku_Book',root,(0,.105,-.29));cube('HardCover',book,(0,0,0),(.32,.020,.25),'Cover',.005);cube('Paper',book,(0,.015,0),(.31,.012,.24),'Page',.003)
for side in [-1,1]:
 for j in range(7):rod('Notes',book,(side*.078-.062,.024,-.097+j*.028),(side*.078+.054,.024,-.097+j*.028),.0007,'Cover')
page=node('Tiku_Page',book);cube('TurningPage',page,(.076,.026,0),(.148,.0015,.23),'Page',.0005)
if UNIFORM:
 # Replace the open exercise book with a closed textbook for the armpit carry.
 for ob in list(book.children):
  if ob.type=='MESH':bpy.data.objects.remove(ob,do_unlink=True)
 cube('TextbookPaperBlock',book,(0,0,0),(.228,.023,.163),'Page',.002)
 for y in [-.015,.015]:cube('TextbookCover',book,(0,y,0),(.237,.004,.174),'Cover',.002)
 cube('TextbookSpine',book,(-.116,0,0),(.006,.033,.174),'Cover',.002)
 for j in range(3):cube('TextbookTitleBar',book,(-.036+j*.023,.0176,-.033),(.009,.001,.047),'Cream',.0002)
pen=node('Tiku_Pen',root);rod('Pen',pen,(0,0,0),(.022,.13,.022),.004,'Ink');rod('PenTip',pen,(0,0,0),(.004,.023,.004),.0012,'Metal')
# Fuse same-pivot cloth pieces to remove overlapping shoulder/elbow caps.
for pivot in [root]+[o for o in root.children_recursive if o.type=='EMPTY']:
 for key in ['Navy','Trouser']:
  group=[o for o in pivot.children if o.type=='MESH' and o.data.materials and o.data.materials[0]==M[key] and len(o.data.materials)==1]
  if not group:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0];bpy.ops.object.convert(target='MESH');bpy.ops.object.join();obj=bpy.context.object
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  voxel=obj.modifiers.new('Continuous cloth volume','REMESH');voxel.mode='VOXEL';voxel.voxel_size=.003;voxel.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=voxel.name)
  smooth=obj.modifiers.new('Cloth polish','SMOOTH');smooth.factor=.6;smooth.iterations=3;bpy.ops.object.modifier_apply(modifier=smooth.name)
  dec=obj.modifiers.new('Realtime cloth','DECIMATE');dec.ratio=.40;bpy.ops.object.modifier_apply(modifier=dec.name)
  for f in obj.data.polygons:f.use_smooth=True
asset='tiku_boy1_uniform' if UNIFORM else 'tiku_boy1'
export(root,asset+'.glb')
bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender/source'/(asset+'.blend')))
print('TIKU_ASSET_OK')
