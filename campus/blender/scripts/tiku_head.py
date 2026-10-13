"""Reference-led facial construction. Executed by build_tiku; coordinates are metres."""
def newmat(key,c,rough=.85):
 m=bpy.data.materials.new('Tiku'+key);m.diffuse_color=(*c,1);m.use_nodes=True
 m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1)
 m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=rough;M[key]=m
newmat('Face',(.72,.51,.34))
tex=M['Face'].node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(R/'godot/assets/textures/tiku_face_albedo.png'))
M['Face'].node_tree.links.new(tex.outputs['Color'],M['Face'].node_tree.nodes['Principled BSDF'].inputs['Base Color'])
# Shader-built pupils sit on the facial surface; Godot uses the same UV formula.
nt=M['Face'].node_tree;uvnode=nt.nodes.new('ShaderNodeTexCoord');sep=nt.nodes.new('ShaderNodeSeparateXYZ');nt.links.new(uvnode.outputs['UV'],sep.inputs[0])
def scalar(op,a,b):
 n=nt.nodes.new('ShaderNodeMath');n.operation=op
 for i,v in enumerate((a,b)):
  if isinstance(v,(int,float)):n.inputs[i].default_value=v
  else:nt.links.new(v,n.inputs[i])
 return n.outputs[0]
masks=[]
for cx in [.308,.713]:
 dx=scalar('DIVIDE',scalar('SUBTRACT',sep.outputs['X'],cx),.019)
 dy=scalar('DIVIDE',scalar('SUBTRACT',sep.outputs['Y'],.605),.023)
 masks.append(scalar('LESS_THAN',scalar('ADD',scalar('MULTIPLY',dx,dx),scalar('MULTIPLY',dy,dy)),1))
rgb=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(tex.outputs['Color'],rgb.inputs[0]);eyemask=scalar('GREATER_THAN',rgb.outputs['Blue'],.47)
mix=nt.nodes.new('ShaderNodeMixRGB');mix.blend_type='MIX';nt.links.new(scalar('MULTIPLY',scalar('MAXIMUM',masks[0],masks[1]),eyemask),mix.inputs[0]);nt.links.new(tex.outputs['Color'],mix.inputs[1]);mix.inputs[2].default_value=(.023,.027,.026,1);nt.links.new(mix.outputs[0],nt.nodes['Principled BSDF'].inputs['Base Color'])
newmat('EarInner',(.54,.34,.24));newmat('HairGrain',(.042,.043,.043));newmat('Iris',(.045,.038,.030))
# Skin at the rear matches the painting's edge, in linear space.
M['Skin'].diffuse_color=(.72,.51,.34,1);M['Skin'].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.72,.51,.34,1)
head=node('Tiku_Head',root,(0,.57,-.015))
profile=[(0,.031,.045,-.018),(.010,.042,.054,-.016),(.025,.051,.061,-.011),(.045,.065,.067,-.005),(.065,.080,.070,0),(.083,.086,.073,.003),(.11,.087,.078,.006),(.14,.097,.080,.005),(.168,.100,.082,.004),(.19,.098,.083,.004),(.225,.096,.082,.006),(.255,.092,.078,.007),(.28,.079,.068,.008),(.299,.054,.050,.007),(.309,.012,.012,.004)]
def cross(y,a,extra=0):
 for i in range(len(profile)-1):
  p,q=profile[i:i+2]
  if y<=q[0]:
   t=max(0,(y-p[0])/(q[0]-p[0]));a0=profile[max(0,i-1)];a3=profile[min(len(profile)-1,i+2)];dt=q[0]-p[0]
   values=[]
   for k in [1,2,3]:
    m0=(q[k]-a0[k])/(q[0]-a0[0])*dt;m1=(a3[k]-p[k])/(a3[0]-p[0])*dt
    values.append((2*t**3-3*t*t+1)*p[k]+(t**3-2*t*t+t)*m0+(-2*t**3+3*t*t)*q[k]+(t**3-t*t)*m1)
   w,d,z=values;break
 else:w,d,z=profile[-1][1:]
 s,c=math.sin(a),math.cos(a)
 x=(w+extra)*s;zz=z-(d+extra)*math.copysign(abs(c)**.55,c)
 # Lift the eye planes and eyebrows; keep a gently hollow cheek beneath.
 if c>.2:
  zz-=.005*math.exp(-((abs(x)-.047)/.030)**2-((y-.18)/.018)**2)
  zz-=.002*math.exp(-((abs(x)-.051)/.041)**2-((y-.205)/.013)**2)
  # Continuous nose bridge, tip and alar volumes, sharing head topology and UV.
  zz-=.022*math.exp(-(x/.010)**2-((y-.147)/.027)**2)
  zz-=.032*math.exp(-(x/.013)**2-((y-.120)/.009)**2)
  zz-=.014*math.exp(-((abs(x)-.016)/.007)**2-((y-.114)/.007)**2)
  zz-=.003*math.exp(-(x/.029)**4-((y-.077)/.004)**2)
 return (x,y,zz)
verts=[];rows=129;seg=160
for j in range(rows):
 y=.309*j/(rows-1)
 for i in range(seg):verts.append(cross(y,i*math.tau/seg))
faces=[]
for j in range(rows-1):
 for i in range(seg):faces.append((j*seg+i,j*seg+(i+1)%seg,(j+1)*seg+(i+1)%seg,(j+1)*seg+i))
me=bpy.data.meshes.new('JawCheekForeheadPlanes');me.from_pydata([pt(v) for v in verts],[],faces);me.materials.append(M['Face']);me.materials.append(M['Skin'])
o=bpy.data.objects.new('IdentityHead',me);bpy.context.collection.objects.link(o);o.parent=head
uv=me.uv_layers.new(name='FaceProjection')
for poly in me.polygons:
 # Front projection has clean constant color outside the features.
 poly.material_index=0 if sum(verts[v][2] for v in poly.vertices)/len(poly.vertices)<.01 else 1
 poly.use_smooth=True
 for li in poly.loop_indices:
  x,y,z=verts[me.loops[li].vertex_index];uv.data[li].uv=(x/.238+.5,y/.300)
bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
def face_uv(obj):
 uv=obj.data.uv_layers.new(name='FaceProjection')
 for poly in obj.data.polygons:
  for li in poly.loop_indices:
   v=obj.data.vertices[obj.data.loops[li].vertex_index].co
   uv.data[li].uv=(v.x/.238+.5,v.z/.300)
 return obj
# A fitted buzz cut wraps temples and occiput; the hairline varies around the skull.
hv=[];hf=[];hrows=80
for j in range(hrows):
 t=j/(hrows-1)
 for i in range(seg):
  a=i*math.tau/seg;c=math.cos(a);s=abs(math.sin(a))
  lower=.102+.146*max(0,min(1,(c+.22)/.92))
  # Receded corners and very short sideburns.
  if c>.4:lower=.245+.013*math.exp(-((s-.68)/.18)**2)
  lower+=.00035*math.sin(i*2.3)
  y=lower+(.3095-lower)*t;v=cross(min(y,.309),a,.004)
  hv.append((v[0],y,v[2]))
for j in range(hrows-1):
 for i in range(seg):hf.append((j*seg+i,j*seg+(i+1)%seg,(j+1)*seg+(i+1)%seg,(j+1)*seg+i))
hv.append((0,.312,.004))
for i in range(seg):hf.append(((hrows-1)*seg+i,(hrows-1)*seg+(i+1)%seg,len(hv)-1))
hm=bpy.data.meshes.new('CloseCropTopology');hm.from_pydata([pt(v) for v in hv],[],hf);hm.materials.append(M['Hair']);ho=bpy.data.objects.new('FittedBuzzcut',hm);bpy.context.collection.objects.link(ho);ho.parent=head
for f in hm.polygons:f.use_smooth=True
bm=bmesh.new();bm.from_mesh(hm);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(hm);bm.free()
cap=ho.modifiers.new('Hairline sealed shell','SOLIDIFY');cap.thickness=.0015
for i in range(260):
 a=random.uniform(-math.pi,math.pi);y=random.uniform(.258,.302)
 p=cross(y,a,.0043);q=cross(min(.307,y+.0016),a+.004,.0043)
 rod('CloseCropGrain',head,p,q,.00016,'HairGrain')
for side in [-1,1]:
 suffix='L' if side<0 else 'R'
 ball('Ear',head,(side*.104,.157,.005),(.016,.033,.019),'Skin')
 ball('EarConcha',head,(side*.108,.157,-.010),(.008,.022,.004),'EarInner')
 rod('Antihelix',head,(side*.11,.14,-.014),(side*.11,.168,-.014),.0025,'Skin')
 eye=node('Tiku_Eye'+suffix,head,(side*.0476,.179,-.082))
 pupil=node('Tiku_Pupil'+suffix,eye,(.006,0,-.005))
 # Fine rounded rectangle, width/height 1.65; upper frame hugs the brow.
 cx=side*.048;cy=.174;w=.040;h=.022;r=.008
 points=[]
 for x,y,start in [(w-r,h-r,0),(-w+r,h-r,90),(-w+r,-h+r,180),(w-r,-h+r,270)]:
  for k in range(9):
   a=math.radians(start+k*90/8);points.append((x+r*math.cos(a),y+r*math.sin(a)))
 # Clockwise rounded corners in a continuous counterclockwise path.
 for i,(x,y) in enumerate(points):
  nx,ny=points[(i+1)%len(points)];rod('RectangleFrame',head,(cx+x,cy+y,-.101),(cx+nx,cy+ny,-.101),.00155,'Ink')
 rod('TempleArm',head,(side*.092,.190,-.101),(side*.109,.178,.018),.0018,'Ink')
rod('GlassesBridge',head,(-.009,.188,-.102),(.009,.188,-.102),.00155,'Ink')
