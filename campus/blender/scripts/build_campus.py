"""USTC north-axis hero assets. Pure authored geometry, meters, deterministic.
World helper uses Godot (east,up,south), stored as Blender (east,-south,up).
Reference photographs are never used as textures.
"""
import bpy, math, random, json, shutil
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[2]
random.seed(1958)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system='METRIC'
site=json.loads((R/'godot/assets/site.json').read_text(encoding='utf-8'))
M={}
colors={'Brick':(.55,.235,.14),'BrickWarm':(.63,.285,.18),'Stone':(.73,.69,.56),'Plaster':(.81,.79,.66),'Roof':(.26,.29,.27),'Glass':(.17,.29,.34),'GlassLight':(.32,.43,.46),'Frame':(.68,.69,.62),'Dark':(.075,.10,.10),'Wood':(.27,.19,.11),'PavilionRoof':(.49,.16,.095),'Trunk':(.32,.29,.22),'BarkLight':(.58,.57,.43),'Leaf':(.27,.45,.15),'LeafLight':(.39,.56,.21),'LeafDark':(.18,.33,.13),'Metal':(.19,.26,.24),'Letter':(.28,.12,.10)}
for name,c in colors.items():
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*c,1);bs.inputs['Roughness'].default_value=.84 if 'Glass' not in name else .24
 M[name]=m
groups={}
active='Architecture'
def pt(p):return (p[0],-p[2],p[1])
def geo(verts,faces,mat):
 key=(active,mat)
 v,f=groups.setdefault(key,([],[]));n=len(v);v.extend(pt(p) for p in verts);f.extend(tuple(n+i for i in face) for face in faces)
def box(c,s,mat):
 x,y,z=c;a,b,d=[t/2 for t in s]
 v=[(x+dx*a,y+dy*b,z+dz*d) for dx,dy,dz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
 geo(v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],mat)
def tube(a,b,r1,r2,mat,n=8):
 a=Vector(a);b=Vector(b);w=(b-a).normalized();u=w.cross(Vector((0,1,0)))
 if u.length<.01:u=w.cross(Vector((1,0,0)))
 u.normalize();v=w.cross(u);vs=[]
 for p,r in [(a,r1),(b,r2)]:
  for i in range(n):vs.append(p+r*(math.cos(i*math.tau/n)*u+math.sin(i*math.tau/n)*v))
 fs=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 geo(vs,fs,mat)
def ellipsoid(c,s,mat,seg=9,rings=5):
 v=[]
 for j in range(rings+1):
  t=math.pi*j/rings
  for i in range(seg):
   p=i*math.tau/seg;v.append((c[0]+s[0]*math.sin(t)*math.cos(p),c[1]+s[1]*math.cos(t),c[2]+s[2]*math.sin(t)*math.sin(p)))
 faces=[]
 for j in range(rings):
  for i in range(seg):faces.append((j*seg+i,j*seg+(i+1)%seg,(j+1)*seg+(i+1)%seg,(j+1)*seg+i))
 geo(v,faces,mat)
def text(body,p,size,mat,rot=(math.pi/2,0,math.pi)):
 cv=bpy.data.curves.new('Inscription','FONT');cv.body=body;cv.size=size;cv.align_x='CENTER';cv.extrude=.007
 try:cv.font=bpy.data.fonts.load('C:/Windows/Fonts/msyh.ttc')
 except Exception:pass
 o=bpy.data.objects.new('Inscription_'+body,cv);bpy.context.collection.objects.link(o);o.location=pt(p);o.rotation_euler=rot;cv.materials.append(M[mat])
 o['asset_group']=active
def window(x,y,z,w=1.7,h=2.45,side=0):
 # Front/back panels are shallow inset dark reveals with glass and projecting sills.
 if side==0:
  if z<168.0 and z>167.0:
   # Actual setback behind front masonry (north body starts at z168.4).
   z=168.27
  box((x,y,z),(w+.20,h+.20,.12),'Dark');box((x,y,z-.075),(w,h,.045),'Glass' if random.random()<.65 else 'GlassLight')
  for dx in [-w/2,0,w/2]:box((x+dx,y,z-.115),(.055,h+.1,.06),'Frame')
  for dy in [-h/2,.35,h/2]:box((x,y+dy,z-.115),(w+.1,.055,.06),'Frame')
  box((x,y-h/2-.11,z-.22),(w+.34,.13,.4),'Stone')
 else:
  box((x,y,z),(.12,h+.20,w+.20),'Dark');box((x+side*.08,y,z),(.05,h,w),'Glass')
  for dz in [-w/2,0,w/2]:box((x+side*.12,y,z+dz),(.06,h+.1,.06),'Frame')
  for dy in [-h/2,.35,h/2]:box((x+side*.12,y+dy,z),(.06,.06,w+.1),'Frame')
  box((x+side*.2,y-h/2-.11,z),(.38,.13,w+.34),'Stone')
# U-shape follows the actual map macro dimensions, simplified sub-meter recesses.
hallparts=[((0,8.5,176.2),(124,17,15.6)),((-55,8.5,201),(14,17,42)),((55,8.5,201),(14,17,42)),((0,8.5,183.8),(31,17,11))]
for c,s in hallparts:
 box(c,s,'Brick');box((c[0],.6,c[2]),(s[0]+.35,1.2,s[2]+.35),'Stone')
 box((c[0],17.06,c[2]),(s[0]+.8,.40,s[2]+.8),'Stone')
 box((c[0],17.42,c[2]),(s[0]+.18,.32,s[2]+.18),'Roof')
 for y in [4.25,8.35,12.45]:box((c[0],y,c[2]),(s[0]+.08,.10,s[2]+.08),'BrickWarm')
for level in range(4):
 y=2.5+level*4.05
 for x in range(-58,59,4):
  if level==0 and abs(x)<6:continue
  window(x,y,167.94,w=1.52,h=2.6)
  if abs(x)>18:window(x,y,184.1,w=1.52,h=2.6)
 for z in range(189,220,4):
  for side in [-1,1]:window(side*62.07,y,z,w=1.6,h=2.6,side=side);window(side*47.94,y,z,w=1.6,h=2.6,side=-side)
# Central entrance, no invented monumental pediment.
box((0,2.3,167.8),(9,4.4,.35),'Dark')
for x in [-3,-1,1,3]:
 box((x,2.2,167.48),(1.8,4,.08),'Glass');box((x+.9,2.2,167.35),(.09,4.1,.1),'Frame')
box((0,4.8,166.9),(12,.38,3),'Stone');box((0,5.55,167.86),(11.5,.96,.14),'BrickWarm')
text('第 一 教 学 楼',(0,5.14,167.65),.64,'Stone')
for i in range(4):box((0,.09*(i+1),166-i*.46),(12-i*.12,.18*(i+1),.5),'Stone')
# Gate: low pale portal with open side bays, foliage is added in Godot.
for x in [-9.5,-5.6,5.6,9.5]:
 box((x,2.9,0),(1.1,5.8,1.65),'Plaster');box((x,.18,0),(1.45,.36,1.95),'Stone')
 for y in [1,2,3,4,5]:box((x,y,-.83),(1.1,.018,.015),'Stone')
box((0,5.85,0),(21,1.1,1.75),'Plaster');box((0,6.44,0),(21.35,.17,2.03),'Stone')
text('中 国 科 学 技 术 大 学',(0,5.56,-.895),.70,'Letter')
# Back inscription faces campus.
text('中 国 科 学 技 术 大 学',(0,5.56,.895),.70,'Letter',rot=(math.pi/2,0,0))
# Pavilion at measured east-pool position, sixfold raised roof with curved ribs.
px,pz=site['pavilion']; base=.38
tube((px,-.45,pz),(px,base,pz),4.2,4.2,'Stone',6)
for i in range(6):
 a=i*math.tau/6; x=px+3*math.cos(a);z=pz+3*math.sin(a)
 tube((x,base,z),(x,4.3,z),.14,.12,'Stone',10)
 b=(i+1)*math.tau/6;tube((x,4.1,z),(px+3*math.cos(b),4.1,pz+3*math.sin(b)),.13,.13,'Wood')
 # roof wedge grid: convex ridge, low middle, uplift at outer eave
 for j in range(8):
  for k in range(8):
   def roofv(j,k):
    t=j/8;r=4.65*t;ang=a+(b-a)*k/8
    h=6.35-3.4*t+1.15*t**4 +.55*t**5*abs(2*k/8-1)**4
    return (px+r*math.cos(ang),h,pz+r*math.sin(ang))
   geo([roofv(j,k),roofv(j,k+1),roofv(j+1,k+1),roofv(j+1,k)],[(0,1,2,3)],'PavilionRoof')
 # ribs accentuate radial construction
 for k in range(9):
  ang=a+(b-a)*k/8
  last=(px,6.37,pz)
  for j in range(1,10):
   t=j/9;h=6.35-3.4*t+1.15*t**4+.55*t**5*abs(2*k/8-1)**4
   v=(px+4.65*t*math.cos(ang),h+.04,pz+4.65*t*math.sin(ang));tube(last,v,.045,.045,'PavilionRoof',5);last=v
tube((px,6.2,pz),(px,6.9,pz),.30,.15,'PavilionRoof',8)
text('一 鉴 亭',(px,3.53,pz-2.68),.39,'Letter')
# Folded pedestrian bridge, 2m wide, connected north bank and west bank.
bridge=[(12,64),(22,69),(29,78),(px,pz)]
def beam(a,b,width,h,y,mat):
 dx=b[0]-a[0];dz=b[1]-a[1];l=math.hypot(dx,dz);u=(-dz/l*width/2,dx/l*width/2)
 pts=[(a[0]+u[0],y-h/2,a[1]+u[1]),(b[0]+u[0],y-h/2,b[1]+u[1]),(b[0]-u[0],y-h/2,b[1]-u[1]),(a[0]-u[0],y-h/2,a[1]-u[1])]
 pts+=[(x,yy+h,z) for x,yy,z in pts];geo(pts,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],mat)
for a,b in zip(bridge,bridge[1:]):
 beam(a,b,2.6,.26,.30,'Stone');dx=b[0]-a[0];dz=b[1]-a[1];l=math.hypot(dx,dz)
 for side in [-1,1]:
  u=(-dz/l*1.18*side,dx/l*1.18*side);aa=(a[0]+u[0],a[1]+u[1]);bb=(b[0]+u[0],b[1]+u[1])
  beam(aa,bb,.16,.14,1.13,'Plaster')
  for i in range(int(l/2)+1):
   t=i/max(int(l/2),1);x=aa[0]+dx*t;z=aa[1]+dz*t;box((x,.74,z),(.16,.88,.16),'Stone')
site['bridge']=bridge
(R/'godot/assets/site.json').write_text(json.dumps(site,ensure_ascii=False,indent=2),encoding='utf-8')
# Background footprints are real OSM, architecture treatment intentionally coarse.
active='Background'
for it in site['background']:
 x,z=it['center'];w,d=it['size'];h=it['height']
 if w<4 or d<4:continue
 mat='Stone' if z<65 else 'Plaster'
 poly=it['outline'][:-1];n=len(poly)
 vs=[(p[0],0,p[1]) for p in poly]+[(p[0],h,p[1]) for p in poly]
 geo(vs,[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]+[tuple(range(n-1,-1,-1))],mat)
 geo([(p[0],h+.05,p[1]) for p in poly],[tuple(range(n))],'Roof')
 for a,b in zip(poly,poly[1:]+poly[:1]):
  length=math.dist(a,b);ux=(b[0]-a[0])/length;uz=(b[1]-a[1])/length
  beam(a,b,.25,.25,h+.12,'Stone')
  for lev in range(max(1,round(h/3.3))):
   for i in range(int(length/3.4)):
    t=(i+.5)/max(1,int(length/3.4));xx=a[0]+(b[0]-a[0])*t;zz=a[1]+(b[1]-a[1])*t;yy=lev*3.3+2
    # Double outward offsets make surfaces valid independent of footprint winding.
    for off in [-.045,.045]:
     cx=xx-uz*off;cz=zz+ux*off
     verts=[(cx-ux*.74,yy-.92,cz-uz*.74),(cx+ux*.74,yy-.92,cz+uz*.74),(cx+ux*.74,yy+.92,cz+uz*.74),(cx-ux*.74,yy+.92,cz-uz*.74)]
     geo(verts,[(0,1,2,3)],'Glass')
     tube((cx-uz*.02,yy-.92,cz+ux*.02),(cx-uz*.02,yy+.92,cz+ux*.02),.026,.026,'Frame',4)
# Bench local asset.
active='Bench'
for x in [-.75,.75]:
 box((x,.24,0),(.10,.48,.55),'Metal');box((x,.65,.23),(.08,.8,.08),'Metal')
for z in [-.21,-.07,.07,.21]:box((0,.49,z),(1.85,.08,.11),'Wood')
for y in [.7,.87,1.04]:box((0,y,.27),(1.85,.12,.08),'Wood')
# Streetlight local asset.
active='Lamp'
tube((0,0,0),(0,4.8,0),.07,.045,'Metal');tube((0,4.8,0),(.70,4.8,0),.05,.05,'Metal');box((.68,4.76,0),(.48,.12,.32),'Stone')
box((0,.12,0),(.25,.24,.25),'Metal')
# Bicycle: actual thin frames and wheels, proper human scale.
active='Bicycle'
for x in [-.62,.62]:
 for i in range(24):
  a=i*math.tau/24;b=(i+1)*math.tau/24
  p=(x+.34*math.cos(a),.38+.34*math.sin(a),0);q=(x+.34*math.cos(b),.38+.34*math.sin(b),0)
  tube(p,q,.026,.026,'Dark',5)
  if i%3==0:tube((x,.38,0),p,.005,.005,'Frame',4)
for a,b in [((-.62,.38,0),(-.17,.89,0)),((-.17,.89,0),(.06,.38,0)),((.06,.38,0),(-.62,.38,0)),((-.17,.89,0),(.43,.91,0)),((.43,.91,0),(.06,.38,0)),((.43,.91,0),(.62,.38,0)),((.43,.91,0),(.4,1.1,0)),((-.17,.89,0),(-.19,1.02,0))]:tube(a,b,.025,.025,'Metal')
box((-.19,1.04,0),(.28,.065,.17),'Dark');tube((.4,1.1,-.22),(.4,1.1,.22),.025,.025,'Dark');box((.02,.24,.20),(.17,.055,.10),'Dark')
# Three authored branching canopies, clustered leaf sprays. No downloaded foliage.
for variant in range(3):
 active='Tree'+str(variant);random.seed(1958+variant)
 height=[8,12,9][variant];spread=[3.5,4.8,4.1][variant]
 tube((0,0,0),(.22,height*.59,.16),.27 if variant!=1 else .37,.10,'Trunk',9)
 tube((0,0,0),(.02,1.35,.02),.285 if variant!=1 else .38,.24 if variant!=1 else .33,'BarkLight',9)
 clusters=[]
 for b in range(11):
  a=b*2.399;rad=spread*random.uniform(.45,1);y=height*random.uniform(.57,.91)
  end=(rad*math.cos(a),y,rad*math.sin(a));start=(.1,height*.36+b*.12,.08)
  elbow=tuple(start[j]+(end[j]-start[j])*.57 for j in range(3));elbow=(elbow[0],elbow[1]+.5,elbow[2])
  tube(start,elbow,.13,.065,'Trunk');tube(elbow,end,.065,.016,'Trunk',6)
  clusters.append((end,(spread*.49,1.25,spread*.47)))
 clusters.append(((0,height*.91,0),(spread*.57,1.6,spread*.54)))
 for ci,(c,s) in enumerate(clusters):
  # A small irregular volume gives continuous canopy shading, leaf sprays break silhouette.
  ellipsoid(c,(s[0]*.67,s[1]*.68,s[2]*.67),'LeafDark',8,4)
  for j in range(240):
   a=random.random()*math.tau;y=random.uniform(-1,1);r=math.sqrt(max(0,1-y*y));v=Vector((r*math.cos(a),y,r*math.sin(a)))
   center=Vector(c)+Vector((v.x*s[0],v.y*s[1],v.z*s[2]))*random.uniform(.55,1.1)
   # leaf clusters are articulated small bent silhouettes, smooth normals upward in Godot
   size=random.uniform(.09,.235);ang=random.random()*math.tau
   u=Vector((math.cos(ang),.25,math.sin(ang)))*size;w=Vector((-math.sin(ang),.16,math.cos(ang)))*size*.60
   vs=[center-u,center-u*.45+w*.8,center+u*.45+w*.8,center+u,center+u*.45-w*.8,center-u*.45-w*.8,center+Vector((0,size*.10,0))]
   geo(vs,[(i,(i+1)%6,6) for i in range(6)],random.choices(['Leaf','LeafLight','LeafDark'],[.52,.33,.15])[0])
# Small stone, tuft and lotus for MultiMesh placement.
active='Rock';random.seed(52);ellipsoid((0,.32,0),(.7,.58,.5),'Stone',7,4)
active='Lotus'
tube((0,-.3,0),(.03,.30,0),.009,.009,'LeafDark',5)
v=[(.03,.38,0)]+[(.40*math.cos(i*math.tau/14),.30+.04*math.sin(i*2.2),.40*math.sin(i*math.tau/14)) for i in range(14)]
geo(v,[(0,i+1,(i+1)%14+1) for i in range(14)],'Leaf')
active='Grass';random.seed(52)
for i in range(7):
 a=i*2.399;x=random.uniform(-.18,.18);z=random.uniform(-.18,.18);h=random.uniform(.20,.46)
 geo([(x-.035,0,z),(x+.035,0,z),(x+.12*math.cos(a),h,z+.12*math.sin(a))],[(0,2,1)],'Leaf')
# LookDev overrides preserve surveyed layout and rebuild only visual assets.
exec((Path(__file__).parent/'lookdev_assets.py').read_text(encoding='utf-8'))
exec((Path(__file__).parent/'diorama_assets.py').read_text(encoding='utf-8-sig'))
# Material-batched objects mean GLB stays small and render calls remain bounded.
asset_objects={}
for (group,mat),(vs,fs) in groups.items():
 mesh=bpy.data.meshes.new(group+'_'+mat);mesh.from_pydata(vs,[],fs);mesh.materials.append(M[mat]);mesh.update()
 o=bpy.data.objects.new(group+'_'+mat,mesh);bpy.context.collection.objects.link(o);o['asset_group']=group
 # Fix winding and normalize, including double sided foliage.
 import bmesh
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
 if mat in ['PavilionRoof','Soffit'] or group.startswith(('DioTree','DioShrub')) or (group=='DioSiteDetail' and mat.startswith(('DioLeaf','Bloom'))):
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.0001);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
 if (group=='DioSiteDetail' and mat.startswith(('DioLeaf','Bloom'))) or group.startswith(('Tree','DioTree','DioShrub')) or group in ['Lotus','Rock'] or mat in ['PavilionRoof','Soffit']:
  for polygon in mesh.polygons:polygon.use_smooth=True
 if group in ['Architecture','Bench','Lamp','SiteDetail','DioArchitecture','DioSiteDetail','DioBase'] and mat in ['Stone','Plaster','Frame','Wood','Metal']:
  bevel=o.modifiers.new('Light catching manufactured edges','BEVEL');bevel.width=.065 if group.startswith('Dio') else .018;bevel.segments=3;bevel.limit_method='ANGLE'
  normal=o.modifiers.new('Face weighted normals','WEIGHTED_NORMAL');normal.keep_sharp=True
 asset_objects.setdefault(group,[]).append(o)
for o in bpy.context.scene.objects:
 if o.type=='FONT':asset_objects.setdefault(o['asset_group'],[]).append(o)
for group,objs in asset_objects.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 path=R/'blender/exports'/f'{group.lower()}.glb'
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_extras=True)
 shutil.copy2(path,R/'godot/assets'/path.name)
old_collection=bpy.data.collections.new('LookDev_01');bpy.context.scene.collection.children.link(old_collection)
dio_collection=bpy.data.collections.new('Diorama_02');bpy.context.scene.collection.children.link(dio_collection)
shared_collection=bpy.data.collections.new('Shared_Props');bpy.context.scene.collection.children.link(shared_collection)
for o in list(bpy.context.scene.objects):
 group=o.get('asset_group','')
 col=dio_collection if group.startswith('Dio') else shared_collection if group in ['Bench','Lamp','Bicycle','Grass'] else old_collection
 for prior in list(o.users_collection):prior.objects.unlink(o)
 col.objects.link(o)
dio_collection.hide_viewport=True;dio_collection.hide_render=True
bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender/source/ustc_north_axis.blend'))
dio_collection.hide_viewport=False;dio_collection.hide_render=False;old_collection.hide_viewport=True;old_collection.hide_render=True
bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender/source/ustc_diorama.blend'))
report={g:{'objects':len(os),'vertices':sum(len(o.data.vertices) for o in os if o.type=='MESH')} for g,os in asset_objects.items()}
(R/'renders/asset_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('CAMPUS_ASSETS_OK',json.dumps(report))
