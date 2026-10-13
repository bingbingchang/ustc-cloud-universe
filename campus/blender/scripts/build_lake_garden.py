"""Independent Yijian garden kit: low-cost reusable geometry, authored Y up."""
import bpy, math, random, json
from pathlib import Path
from collections import defaultdict
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'godot/assets'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
palette={'LakeBark':(.29,.24,.17),'LakeWillow':(.38,.53,.21),'LakeWillowLight':(.56,.65,.28),'LakeLeaf':(.23,.46,.24),'LakeLeafLight':(.40,.58,.29),'LakeVein':(.51,.63,.30),'LakePetal':(.95,.87,.79),'LakePink':(.88,.65,.73),'LakePollen':(.76,.57,.18),'LakeReed':(.34,.45,.19),'LakeStone':(.42,.46,.37),'LakePlum':(.36,.20,.25)}
M={}
for name,col in palette.items():
 m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*col,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9;M[name]=m
groups=defaultdict(lambda:[[],[]]);rng=random.Random(195806);stats={};all_objs=[]
def V(p):return Vector(p)
def geo(points,faces,mat):
 vs,fs=groups[mat];n=len(vs);vs.extend((p[0],-p[2],p[1]) for p in points);fs.extend(tuple(n+i for i in f) for f in faces)
def axes(t):
 t=t.normalized();a=t.cross(V((0,1,0)))
 if a.length<.01:a=t.cross(V((1,0,0)))
 a.normalize();return a,t.cross(a).normalized()
def twig(points,r,mat='LakeBark',sides=7):
 points=list(map(V,points));vs=[]
 for i,p in enumerate(points):
  a,b=axes(points[min(i+1,len(points)-1)]-points[max(0,i-1)]);rad=max(.005,r*(1-.88*i/(len(points)-1)))
  vs.extend(p+(a*math.cos(j*math.tau/sides)+b*math.sin(j*math.tau/sides))*rad for j in range(sides))
 geo(vs,[(i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j) for i in range(len(points)-1) for j in range(sides)],mat)
def leaf(p,length,width,mat='LakeWillow'):
 p=V(p);ang=rng.uniform(0,math.tau);a=V((math.cos(ang),-.55,math.sin(ang))).normalized()*length;b=V((-math.sin(ang),0,math.cos(ang)))*width
 geo([p-a*.3,p+b,p+a,p-b,p+V((0,width*.25,0))],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],mat)
def pad(p,r,mat='LakeLeaf'):
 p=V(p);n=28;vs=[p+V((0,-.04,0))]
 for ring in [.48,1.0]:
  for j in range(n):
   a=.17+j/(n-1)*(math.tau-.34);wave=math.sin(a*5)*.03
   vs.append(p+V((math.cos(a)*r*ring,r*(.15*ring*ring+wave),math.sin(a)*r*ring)))
 fs=[(0,1+j,2+j) for j in range(n-1)]+[(1+j,1+n+j,2+n+j,2+j) for j in range(n-1)]
 geo(vs,[tuple(reversed(f)) for f in fs],mat)
 for j in range(0,n-1,4):
  a=.17+j/(n-1)*(math.tau-.34);end=p+V((math.cos(a)*r*.91,r*.14,math.sin(a)*r*.91));twig([p+V((0,-.027,0)),p.lerp(end,.48),end],.006,'LakeVein',3)
def blossom(p,r):
 p=V(p)
 for ring in range(3):
  for j in range(9):
   a=j*math.tau/9+ring*.28;u=V((math.cos(a),0,math.sin(a)));w=V((-math.sin(a),0,math.cos(a)));rr=r*(1-ring*.19)
   pts=[];fs=[]
   for k in range(9):
    t=k/8;wid=max(.012,math.sin(math.pi*t)**.65)*rr*.32
    center=p+u*rr*t+V((0,rr*(.15*t+(.30+ring*.24)*t*t),0))
    pts.extend([center-w*wid,center+V((0,rr*.07*math.sin(math.pi*t),0)),center+w*wid])
   for k in range(8):
    for side in range(2):
     ix=k*3+side;fs.append((ix,ix+3,ix+4,ix+1))
   geo(pts,fs,'LakePetal' if ring%2==0 else 'LakePink')
 for j in range(8):
  a=j*math.tau/8;scale=r/.31;twig([p+V((math.cos(a)*.025,0,math.sin(a)*.025))*scale,p+V((math.cos(a)*.04,.17,math.sin(a)*.04))*scale],.015*scale,'LakePollen',5)
def export(name):
 objs=[];count=0
 for mat,(vs,fs) in groups.items():
  mesh=bpy.data.meshes.new(name+mat);mesh.from_pydata(vs,[],fs);mesh.materials.append(M[mat]);mesh.update()
  obj=bpy.data.objects.new(name+'_'+mat,mesh);bpy.context.collection.objects.link(obj);objs.append(obj)
  for poly in mesh.polygons:poly.use_smooth=True
  count+=sum(len(f)-2 for f in fs)
 bpy.ops.object.select_all(action='DESELECT')
 for obj in objs:obj.select_set(True)
 bpy.context.view_layer.objects.active=objs[0]
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True)
 stats[name]={'triangles':count,'materials':len(objs)};all_objs.append(objs)
 for obj in objs:obj.hide_set(True)
 groups.clear()
for variant in range(2):
 rng.seed(195802+variant*47)
 twig([(0,0,0),(.15,1.9,.08),(-.18,3.9,.06),(.25,5.4,0)],.30)
 for j in range(6):
  a=j*math.tau/6;twig([(math.cos(a)*.52,.025,math.sin(a)*.52),(0,.8,0)],.075)
 for j in range(13):
  a=j*math.tau/13;d=V((math.cos(a),0,math.sin(a)));tip=d*rng.uniform(2.6,3.8)+V((0,rng.uniform(5.6,6.8),0))
  start=V((0,3.1+rng.random()*1.1,0));twig([start,start.lerp(tip,.52)+V((0,.35,0)),tip],.105)
  for k in range(12):
   anchor=start.lerp(tip,.25+k*.060)+V((rng.uniform(-.4,.4),.4,rng.uniform(-.4,.4)));drop=rng.uniform(1.6,3.2)
   strand=[anchor+d*(t*.32)+V((math.sin(t*2+k)*.13,-drop*t,math.cos(t*2)*.14)) for t in [0,.25,.5,.75,1]]
   twig(strand,.014,'LakeReed',4)
   for n in range(23):
    t=n/23;p=anchor+d*(t*.32)+V((math.sin(t*2+k)*.13,-drop*t,math.cos(t*2)*.14))
    leaf(p,rng.uniform(.22,.38),rng.uniform(.04,.066),'LakeWillowLight' if (j+n)%4==0 else 'LakeWillow')
 export('lake_willow_'+str(variant))
for variant in range(4):
 rng.seed(843+variant)
 for j in range(3):
  a=j*math.tau/3;h=rng.uniform(.13,.75);p=V((math.cos(a)*.48,h,math.sin(a)*.48));twig([(p.x,0,p.z),p],.014,'LakeReed',5);pad(p,rng.uniform(.38,.57),'LakeLeaf' if j%2 else 'LakeLeafLight')
 if variant==3:
  p=V((.15,.88,.13));twig([(.15,0,.13),p],.015,'LakeReed',6);blossom(p,.31)
 export('lake_lotus_'+str(variant))
for variant in range(2):
 rng.seed(741+variant)
 for j in range(23):
  p=V((rng.uniform(-.35,.35),0,rng.uniform(-.35,.35)));a=rng.uniform(0,math.tau);d=V((math.cos(a),0,math.sin(a)));h=rng.uniform(.45,1.05);w=.025 if variant==0 else .047
  t=V((-d.z,0,d.x))*w
  geo([p-t,p+t,p+d*.16+V((0,h*.65,0))+t,p+d*.16+V((0,h*.65,0))-t,p+d*.36+V((0,h,0))],[(0,1,2,3),(3,2,4)],'LakeReed' if j%3 else 'LakeWillowLight')
  if variant and j%5==0:blossom(p+d*.2+V((0,h*.85,0)),.10)
 export('lake_reeds_'+str(variant))
# Irregular low shoreline stones, not a new walkable retaining wall.
rng.seed(730)
for j in range(3):
 cx=(j-1)*.48;vs=[];n=9
 for ring,y,r in [(0,0,.53),(1,.27,.48),(2,.48,.21)]:
  for k in range(n):
   a=k*math.tau/n;rad=r*rng.uniform(.8,1.15);vs.append(V((cx+math.cos(a)*rad,y+rng.uniform(-.04,.04),math.sin(a)*rad*.75)))
 fs=[(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(2) for j in range(n)]+[tuple(range(2*n,3*n))]
 geo(vs,fs,'LakeStone')
export('lake_shore_stones')
for i,objs in enumerate(all_objs):
 for obj in objs:obj.hide_set(False);obj.location=(i%4*9,i//4*9,0)
(ROOT/'blender/source').mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/source/yijian_garden_kit.blend'))
(OUT/'lake_kit_manifest.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
print('LAKE_KIT',json.dumps(stats))
