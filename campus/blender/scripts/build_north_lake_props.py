"""Small authored pond-edge assets; no changes to accepted campus architecture.
Root at water surface for lily, and ground for rocks. Units meters.
"""
import bpy,bmesh,math,json,shutil,random
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[2]
helper=(Path(__file__).with_name('build_campus.py')).read_text(encoding='utf-8').split('# U-shape follows')[0]
helper=helper.replace("m.node_tree.nodes.get('Principled BSDF')","next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')")
exec(compile(helper,'lake_asset_helpers','exec'),globals())
for name,c in {'Leaf':(.24,.36,.15),'LeafLight':(.37,.46,.20),'LeafDark':(.15,.27,.15),'Stone':(.62,.59,.52)}.items():
 M[name].diffuse_color=(*c,1);next(n for n in M[name].node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value=(*c,1)
active='north_lily';random.seed(1910)
# Shallow radial plates with a narrow notch, raised center and bent irregular rim.
# Roots sit below the water; only 1 of 5 plates is mildly emergent. No flowers.
for index,(cx,cz,y,r,tilt) in enumerate([(-.42,-.24,.045,.46,.03),(.34,-.27,.07,.59,-.08),(.0,.38,.16,.53,.12),(.60,.47,.035,.34,-.10),(-.63,.47,.03,.31,.06)]):
 seg=36;rings=6;verts=[]
 for j in range(rings+1):
  t=j/rings
  for k in range(seg+1):
   a=.045+(math.tau-.09)*k/seg;shape=1+.038*math.sin(a*5+index)+.026*math.sin(a*9-index)
   rr=r*t*shape;xx=cx+rr*math.cos(a);zz=cz+rr*math.sin(a)
   yy=y+.055*(1-t)**2+.023*t**3*math.sin(a*5+.7*index)+tilt*(xx-cx)
   verts.append((xx,yy,zz))
 fs=[]
 for j in range(rings):
  for k in range(seg):fs.append((j*(seg+1)+k,j*(seg+1)+k+1,(j+1)*(seg+1)+k+1,(j+1)*(seg+1)+k))
 geo(verts,fs,'LeafLight' if index in [0,4] else 'Leaf')
 # Thin lower face preserves contact views; not a round green sphere.
 geo([(x,yy-.009,z) for x,yy,z in verts],[tuple(reversed(f)) for f in fs],'LeafDark')
 tube((cx-.055,-.38,cz),(cx-.018,y*.50,cz),.009,.007,'LeafDark',8)
 tube((cx-.018,y*.50,cz),(cx,y+.050,cz),.007,.005,'LeafDark',8)
 for q in range(10):
  a=q*math.tau/10
  p=(cx,y+.058,cz);qpt=(cx+r*.85*math.cos(a),y+.015+tilt*r*.85*math.cos(a),cz+r*.85*math.sin(a))
  tube(p,qpt,.0025,.0012,'LeafLight',5)
active='north_rock'
def weathered_rock(c,s,seed):
 seg=32;rings=18;v=[]
 for j in range(rings+1):
  t=math.pi*j/rings
  for k in range(seg):
   a=k*math.tau/seg
   bump=1+.12*math.sin(a*3+seed)*math.sin(t)**2+.07*math.sin(t*6+a*2)+.04*math.cos(a*7-t*3)
   neck=1-.12*math.exp(-((t-1.15)/.3)**2)*(1+math.sin(a*2))
   x=c[0]+s[0]*math.sin(t)*math.cos(a)*bump*neck
   z=c[2]+s[2]*math.sin(t)*math.sin(a)*bump
   y=c[1]+s[1]*math.cos(t)*(1+.07*math.sin(a*3+t))
   v.append((x,max(-.12,y),z))
 f=[]
 for j in range(rings):
  for k in range(seg):f.append((j*seg+k,j*seg+(k+1)%seg,(j+1)*seg+(k+1)%seg,(j+1)*seg+k))
 geo(v,f,'Stone')
weathered_rock((-.25,.47,0),(.55,.63,.40),2.7)
weathered_rock((.48,.30,.17),(.44,.46,.38),1.2)
weathered_rock((-.69,.14,.39),(.30,.27,.31),4.0)
report={'unit':'meter','sources':'Authored geometry; observed official USTC pavilion_4.jpg, 东区眼镜湖.jpg and the rock-bank photo named 东区一鉴亭.jpg; no photos used as textures.','assets':{}}
for (group,mat),(vs,fs) in groups.items():
 me=bpy.data.meshes.new(group+'_'+mat);me.from_pydata(vs,[],fs);me.materials.append(M[mat]);me.update()
 ob=bpy.data.objects.new(group+'_'+mat,me);bpy.context.collection.objects.link(ob);ob['asset_group']=group
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.00001);bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
 # Leaf plates are top only + explicit underside: normalize both independently.
 if group=='north_lily' and mat in ['Leaf','LeafLight']:
  bmesh.ops.reverse_faces(bm,faces=[f for f in bm.faces if len(f.verts)==4 and f.normal.z<0 and f.calc_area()>.0001])
 bm.to_mesh(me);bm.free()
 for p in me.polygons:p.use_smooth=True
for group in ['north_lily','north_rock']:
 objs=[o for o in bpy.context.scene.objects if o.get('asset_group')==group]
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 export=R/'blender/exports'/(group+'.glb');bpy.ops.export_scene.gltf(filepath=str(export),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_extras=True)
 shutil.copy2(export,R/'godot/assets'/export.name)
 vv=[v.co for o in objs for v in o.data.vertices];tri=0
 for o in objs:o.data.calc_loop_triangles();tri+=len(o.data.loop_triangles)
 mini=[min(v[k] for v in vv) for k in range(3)];maxi=[max(v[k] for v in vv) for k in range(3)]
 report['assets'][group]={'triangles':tri,'objects':len(objs),'bounds_min':[mini[0],mini[2],-maxi[1]],'bounds_max':[maxi[0],maxi[2],-mini[1]],'recommended_scale':[.8,1.25] if group=='north_lily' else [.7,1.45]}
bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender/source/north_lake_props.blend'))
(R/'godot/assets/north_lake_props_manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('NORTH_LAKE_PROPS_OK',json.dumps(report))
