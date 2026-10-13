"""Independent, repeatable Sakura Avenue kit. Never rebuilds existing campus assets.
All authored geometry is real 3D, meters; Y-up authoring converted to Blender Z-up.
"""
import bpy, math, random, json
from pathlib import Path
from collections import defaultdict
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'godot/assets'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
palette={
 'SakuraBark':(.24,.18,.15),'SakuraBarkLight':(.38,.28,.21),
 'SakuraBloomIvory':(.96,.83,.77),'SakuraBloomBlush':(.89,.60,.66),'SakuraBloomRose':(.70,.37,.47),
 'SakuraLeafCopper':(.51,.32,.13),'SakuraLeafSage':(.36,.47,.20),
 'SakuraLeafDark':(.12,.25,.13),'SakuraLeafOlive':(.28,.39,.13),
 'SakuraFlowerCream':(.91,.85,.60)}
M={}
for name,col in palette.items():
 m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True
 m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*col,1)
 m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
 m.use_backface_culling=False;M[name]=m
groups=defaultdict(lambda:[[],[]]);rng=random.Random(1958);stats={}
def v(p):return Vector(p)
def geo(points,faces,mat):
 verts,polys=groups[mat];n=len(verts)
 verts.extend((p[0],-p[2],p[1]) for p in points);polys.extend(tuple(n+i for i in f) for f in faces)
def axes(n):
 n=n.normalized();a=n.cross(v((0,1,0)))
 if a.length<.01:a=n.cross(v((1,0,0)))
 a.normalize();return a,n.cross(a).normalized()
def tube(a,b,r1,r2,mat='SakuraBark',sides=8):
 a,b=v(a),v(b);u,w=axes(b-a);pts=[]
 for p,r in [(a,r1),(b,r2)]:
  pts.extend(p+(u*math.cos(i*math.tau/sides)+w*math.sin(i*math.tau/sides))*r for i in range(sides))
 geo(pts,[(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)],mat)
def twig(points,r,radii=None):
 points=[v(p) for p in points];verts=[];sides=9
 for i,p in enumerate(points):
  tangent=points[min(i+1,len(points)-1)]-points[max(0,i-1)];u,w=axes(tangent)
  radius=radii[i] if radii else max(.006,r*(1-.90*i/(len(points)-1)))
  verts.extend(p+(u*math.cos(j*math.tau/sides)+w*math.sin(j*math.tau/sides))*radius for j in range(sides))
 geo(verts,[(i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j) for i in range(len(points)-1) for j in range(sides)],'SakuraBark')
def leaf(p,n,length,mat):
 u,w=axes(n);p=v(p);a=rng.random()*math.tau;u,w=u*math.cos(a)+w*math.sin(a),-u*math.sin(a)+w*math.cos(a)
 geo([p-u*length*.55,p-w*length*.22,p+u*length*.55,p+w*length*.22,p+v(n).normalized()*length*.10],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],mat)
def flower(p,n,r,mat):
 p=v(p);n=v(n).normalized();u,w=axes(n);rot=rng.random()*math.tau
 for i in range(5):
  a=rot+i*math.tau/5;d=u*math.cos(a)+w*math.sin(a);t=-u*math.sin(a)+w*math.cos(a)
  pts=[p+n*r*.14,p+d*r*.35-t*r*.22,p+d*r*.70-t*r*.35,p+d*r*.94-t*r*.24,p+d*r*1.0-t*r*.08,p+d*r*.88,p+d*r*1.0+t*r*.08,p+d*r*.94+t*r*.24,p+d*r*.70+t*r*.35,p+d*r*.35+t*r*.22]
  geo(pts,[(0,k,k+1) for k in range(1,9)],mat)
def bunch(center,rx,ry,rz,count):
 center=v(center)
 for _ in range(count):
  a=rng.uniform(0,math.tau);h=rng.uniform(-1,1);rad=rng.random()**.33;rr=math.sqrt(1-h*h)
  offset=v((rx*rr*math.cos(a),ry*h,rz*rr*math.sin(a)))*rad;p=center+offset
  n=(offset.normalized()+v((rng.uniform(-.6,.6),.4,rng.uniform(-.6,.6)))).normalized()
  color=rng.choices(['SakuraBloomIvory','SakuraBloomBlush','SakuraBloomRose'],[.48,.43,.09])[0]
  flower(p,n,rng.uniform(.065,.105),color)
  if rng.random()<.13:leaf(p+v((.05,-.05,.03)),n,rng.uniform(.16,.25),'SakuraLeafCopper' if rng.random()<.6 else 'SakuraLeafSage')
def export(name):
 objs=[];count=0
 for mat,(verts,faces) in groups.items():
  if not verts:continue
  mesh=bpy.data.meshes.new(name+'_'+mat);mesh.from_pydata(verts,[],faces);mesh.materials.append(M[mat]);mesh.update()
  obj=bpy.data.objects.new(name+'_'+mat,mesh);bpy.context.collection.objects.link(obj);objs.append(obj)
  for poly in mesh.polygons:poly.use_smooth=('Bark' in mat or 'Bloom' in mat)
  count+=sum(len(f)-2 for f in faces)
 bpy.ops.object.select_all(action='DESELECT')
 for obj in objs:obj.select_set(True)
 bpy.context.view_layer.objects.active=objs[0]
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT')
 stats[name]={'triangles':count,'materials':len(objs)}
 for obj in objs:obj.hide_set(True)
 groups.clear()

for variant in range(3):
 rng.seed(195809+variant*971)
 lean=v((rng.uniform(-.18,.18),0,rng.uniform(-.18,.18)))
 # Flared roots and a short trunk, with crown carried above head clearance.
 for j in range(6):
  a=j*math.tau/6;root=v((math.cos(a)*.66,.035,math.sin(a)*.66))
  tube(root,lean+v((0,.65,0)),.07,.16,sides=9)
 stem=[v((0,0,0)),lean*.3+v((0,.75,0)),lean+v((0,1.65,0)),lean*1.2+v((0,2.45,0))]
 # Continuous rings avoid seams between the trunk segments.
 twig(stem,.32,[.32,.29,.25,.205])
 for j in range(7):
  a=j*math.tau/7+rng.uniform(-.22,.22);d=v((math.cos(a),0,math.sin(a)));side=v((-d.z,0,d.x))
  length=rng.uniform(3.4,4.35);height=rng.uniform(5.0,6.4)
  start=stem[2]+v((0,rng.uniform(-.20,.45),0))
  mid=start+d*length*.44+v((0,1.65,0));end=d*length+v((0,height,0))
  twig([start,start.lerp(mid,.5)+side*.12,mid,mid.lerp(end,.5)+v((0,.20,0)),end],rng.uniform(.135,.195))
  for k in range(5):
   t=.35+k*.145;base=mid.lerp(end,t)
   endpoint=base+d*rng.uniform(.5,1.05)+side*((-1 if k%2 else 1)*rng.uniform(.45,1.15))+v((0,rng.uniform(.15,.75),0))
   twig([base,base.lerp(endpoint,.55)+v((0,.15,0)),endpoint],.045)
   bunch(endpoint,.65+rng.random()*.30,.36+rng.random()*.24,.70+rng.random()*.30,110)
   for l in range(3):
    tip=endpoint+v((rng.uniform(-.7,.7),rng.uniform(-.18,.48),rng.uniform(-.7,.7)))
    tube(endpoint,tip,.013,.004,sides=5)
  bunch(end+v((0,.25,0)),.9,.6,.9,115)
 # A few upright interior sprays break the repeated hollow crown-ring silhouette.
 for j in range(3):
  a=j*math.tau/3+variant*.43;end=v((math.cos(a)*1.9,rng.uniform(6.1,7.0),math.sin(a)*1.9))
  twig([stem[3],stem[3].lerp(end,.55)+v((.2,.3,0)),end],.095)
  bunch(end,1.1,.62,1.05,165)
  bunch(end-v((.0,.50,.0)),.8,.4,.8,65)
 export('sakura_tree_'+str(variant))

# Leafy understorey variations are compact and distinct from the canopy palette.
for variant in range(3):
 rng.seed(470+variant)
 for b in range(16):
  a=rng.random()*math.tau;length=rng.uniform(.3,.75);end=v((math.cos(a)*length,rng.uniform(.38,.85),math.sin(a)*length))
  tube((0,0,0),end,.014,.004,sides=5)
  for k in range(28):
   p=end+v((rng.uniform(-.25,.25),rng.uniform(-.2,.2),rng.uniform(-.25,.25)))
   leaf(p,v((rng.uniform(-1,1),rng.uniform(.3,1),rng.uniform(-1,1))),rng.uniform(.12,.22),['SakuraLeafDark','SakuraLeafOlive','SakuraLeafSage'][(k+variant)%3])
  if variant==2:
   for k in range(4):flower(end+v((rng.uniform(-.15,.15),.10,rng.uniform(-.15,.15))),(0,1,0),.038,'SakuraFlowerCream')
 export('sakura_shrub_'+str(variant))

rng.seed(613)
for i in range(34):
 a=rng.random()*math.tau;r=rng.uniform(.12,.48);h=rng.uniform(.23,.65);d=v((math.cos(a),0,math.sin(a)));t=v((-d.z,0,d.x))*.026
 base=d*rng.uniform(0,.08);mid=d*r*.42+v((0,h*.78,0));tip=d*r+v((0,h*.62,0))
 geo([base-t,base+t,mid+t,mid-t,tip],[(0,1,2,3),(3,2,4)],'SakuraLeafSage' if i%3 else 'SakuraLeafOlive')
export('sakura_grass')

# The editable Blender kit opens as a visible, spaced asset board. GLBs above
# were already exported at their local origin for instancing in either scene.
for index,name in enumerate(stats):
 collection=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(collection)
 for obj in list(bpy.context.scene.objects):
  if not obj.name.startswith(name+'_'):continue
  obj.hide_set(False);obj.location=(index%3*14,index//3*12,0)
  for old in list(obj.users_collection):old.objects.unlink(obj)
  collection.objects.link(obj)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/source/sakura_avenue_kit.blend'))
(OUT/'sakura_kit_manifest.json').write_text(json.dumps({'units':'meters','source':'original procedural geometry from official reference observations; no photo textures','assets':stats},indent=2))
print('SAKURA_KIT',stats)
