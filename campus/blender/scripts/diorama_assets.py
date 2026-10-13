"""Authored diorama variants, leaving the previous LookDev assets available."""
for key,col in {'Bloom':(.76,.45,.46),'BloomLight':(.83,.64,.61),'BloomShade':(.56,.28,.36),'DioLeaf':(.27,.40,.16),'DioLeafLight':(.45,.56,.25),'DioLeafShade':(.14,.28,.18)}.items():
 m=bpy.data.materials.new(key);m.diffuse_color=(*col,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*col,1);M[key]=m
# Select only the existing first teaching building, without relocating any wall.
for (group,mat),(vs,fs) in list(groups.items()):
 if group not in ['Architecture','SiteDetail']:continue
 selected=[f for f in fs if all(-79.9<vs[i][0]<79.9 and 118<-vs[i][1]<238 for i in f)]
 if selected:
  ids=sorted({i for f in selected for i in f});mapping={v:k for k,v in enumerate(ids)}
  groups[('Dio'+group,mat)]=([vs[i] for i in ids],[tuple(mapping[i] for i in f) for f in selected])

def crown(c,s,mat,seed):
 # A continuous sculpted, lobed volume, not a low-resolution sphere or leaf cloud.
 phase=seed*.713;vs=[];rings=16;segs=32
 for j in range(rings+1):
  t=math.pi*j/rings
  for k in range(segs):
   a=math.tau*k/segs
   lobes=1+.095*math.sin(3*a+phase)*math.sin(t)**2+.065*math.cos(5*a-phase+t*3)*math.sin(t)+.055*math.sin(t*5+phase)
   vs.append((c[0]+s[0]*math.sin(t)*math.cos(a)*lobes,c[1]+s[1]*math.cos(t)*(1+.045*math.sin(a*3+t)*math.sin(t)),c[2]+s[2]*math.sin(t)*math.sin(a)*lobes))
 geo(vs,[(j*segs+k,j*segs+(k+1)%segs,(j+1)*segs+(k+1)%segs,(j+1)*segs+k) for j in range(rings) for k in range(segs)],mat)
for species in range(3):
 for individual in range(3):
  active=f'DioTree{species}{individual}';random.seed(845+species*47+individual*129)
  h=[7.4,12.4,9.2][species];spread=[3.6,4.4,2.8][species]
  lean=Vector((random.uniform(-.45,.45),0,random.uniform(-.4,.4)))
  trunk=[Vector((0,0,0)),lean*.3+Vector((0,h*.20,0)),lean+Vector((0,h*.43,0)),lean*.7+Vector((0,h*.78,0))]
  curve_branch(trunk,[.28,.41,.30][species],sides=18)
  for j in range(5):
   a=j*math.tau/5;curve_branch([Vector((math.cos(a)*.65,.05,math.sin(a)*.65)),Vector((math.cos(a)*.20,.35,math.sin(a)*.20)),Vector((0,.7,0))],.09,sides=10)
  colors=['Bloom','BloomLight','BloomShade'] if species==0 else ['DioLeaf','DioLeafLight','DioLeafShade']
  count=[7,9,8][species]
  for j in range(count):
   a=j*2.399+random.uniform(-.35,.35);r=spread*random.uniform(.55,1);yy=h*(.67+.22*j/count)+random.uniform(-.4,.4)
   end=Vector((r*math.cos(a),yy,r*math.sin(a)))
   start=trunk[2]+Vector((0,j*.16,0));elbow=start.lerp(end,.50)+Vector((0,.4,0))
   curve_branch([start,elbow,end],.15 if species==1 else .12,sides=14)
   shape=Vector(([1.8,2.05,1.50][species], [1.12,1.28,1.65][species],[1.5,1.65,1.25][species]))*random.uniform(.86,1.15)
   crown(end,shape,colors[0],j+individual)
   for q in range(3):
    aa=a+q*2.1;off=Vector((math.cos(aa)*shape.x*.65,shape.y*.55+random.uniform(-.15,.30),math.sin(aa)*shape.z*.6))
    tip=end+off
    curve_branch([elbow,end,tip],.038,sides=8)
    crown(tip,shape*random.uniform(.36,.55),colors[1] if q!=1 else colors[0],j*3+q)
   for q in range(3):
    aa=a+q*2;tip=end+Vector((math.cos(aa)*shape.x*.88,-shape.y*.12,math.sin(aa)*shape.z*.86))
    crown(tip,shape*random.uniform(.16,.28),colors[1] if q else colors[2],j+q*5)
   if species==0 and j%2==0:
    crown(end+Vector((.3,-.5,.5)),Vector((.42,.20,.35)),'DioLeafLight',j)
  crown(lean+Vector((0,h*.98,0)),Vector((spread*.50,.9 if species==0 else 1.25,spread*.45)),colors[1],31+individual)
active='DioShrub';random.seed(113)
for j in range(7):
 a=j*2.39;r=.6 if j else 0
 crown(Vector((math.cos(a)*r,.38+random.uniform(0,.22),math.sin(a)*r*.7)),Vector((.57,.36,.48)),['DioLeaf','DioLeafLight'][j%2],j)
active='DioBase'
box((0,-1.7,178),(160,3.2,120),'Stone')
box((0,-3.7,178),(161.0,.8,121.0),'Wood')
# Roof parapets and rear-facing joinery are meso details, not a new footprint.
active='DioArchitecture'
edge=[(-62,168.4),(62,168.4),(62,222),(48,222),(48,184),(15.5,184),(15.5,189.3),(-15.5,189.3),(-15.5,184),(-48,184),(-48,222),(-62,222),(-62,168.4)]
for a,b in zip(edge,edge[1:]):beam(a,b,.30,.40,17.69,'Stone')
# North block rear, projected stair core, and wing ends: coherent rear joinery.
for z,xxs in [(184.22,[x for x in range(-58,59,4) if abs(x)>18]),(189.42,range(-12,13,4)),(222.20,[-59,-55,-51,51,55,59])]:
 for x in xxs:
  for level in range(4):
   y=2.5+level*4.05
   box((x,y,z),(1.52,2.6,.045),'Glass')
   for dx in [-.83,.83]:box((x+dx,y,z+.06),(.13,2.85,.22),'BrickWarm')
   for dx in [-.76,0,.76]:box((x+dx,y,z+.10),(.055,2.65,.065),'Frame')
   for dy in [-1.3,.35,1.3]:box((x,y+dy,z+.10),(1.58,.055,.065),'Frame')
   box((x,y-1.4,z+.16),(1.95,.16,.44),'Stone')
# Life pass: correct the original reversed stair treads, then add measured-scale details.
key=('DioArchitecture','Stone')
vs,fs=groups[key]
fs[:]=[f for f in fs if not all(abs(vs[i][0])<6.2 and 164.0<-vs[i][1]<166.4 and vs[i][2]<.76 for i in f)]
active='DioArchitecture'
for i in range(4):
 h=.12*(i+1);box((0,h/2,165.0+i*.45),(12,h,.48),'Stone')
box((0,.24,166.85),(12,.48,.75),'Stone')
# A slim entry surround, clean base-course and a readable canopy soffit.
for x in [-4.55,4.55]:box((x,2.44,167.30),(.16,4.12,.28),'Frame')
for x in [-3,0,3]:box((x,4.57,166.85),(1.15,.045,.25),'Frame')
for x in range(-60,61,8):
 if abs(x)>7:box((x,.44,167.90),(7.95,.68,.17),'BrickWarm')
active='DioSiteDetail'
# Paired planting beds emphasize the entrance without blocking the central route.
for x in [-10.2,10.2]:
 box((x,.16,166.4),(4.3,.32,1.50),'Stone')
 box((x,.33,166.4),(4.05,.08,1.22),'Trunk')
 for j in range(7):
  c=Vector((x-1.7+j*.55,.64,166.4));crown(c,Vector((.47,.30,.44)),'DioLeaf',j)
  for k in range(3):
   a=k*2.39+j;crown(c+Vector((math.cos(a)*.17,.23,math.sin(a)*.22)),Vector((.065,.035,.060)),'BloomLight',k+j)
# A notebook garden / pause pocket; clustered detail, not uniform scatter.
for x,z in [(-21.6,146.3),(-13.3,147.5),(23.4,151.3),(27.2,151.3),(-32,224),(32,224)]:
 for j in range(3):
  a=j*2.39;crown(Vector((x+math.cos(a)*.40,.36,z+math.sin(a)*.33)),Vector((.55,.32,.48)),'DioLeaf' if j%2 else 'DioLeafLight',j)
 ellipsoid((x-.7,.17,z+.2),(.42,.25,.31),'Stone',18,10)
# Tree basins: recessed soil and small growth instead of empty green squares.
for side in [-1,1]:
 for i in range(4):
  x=side*7.15;z=123+i*7.45
  box((x,.014,z),(1.45,.025,1.45),'Trunk')
# Courtyard edges and drains emphasize the existing path organization.
for x in [-37.2,37.2]:
 for z in range(190,210):box((x,.09,z),(.20,.17,.96),'Stone')
for z in [183.85,210.2]:
 for x in range(-37,38):
  if abs(x)>4:box((x,.09,z),(.96,.17,.20),'Stone')
for x,z in [(-26,150.5),(26,150.5),(-38,164.8),(38,164.8),(5,187),(5,208)]:
 box((x,.065,z),(.75,.05,.32),'Dark')
 for i in range(8):box((x-.32+i*.09,.10,z),(.032,.025,.32),'Metal')
# Quiet paving inlays and rear bench pads, using the same restrained stone palette.
for x in [-32,-17,17,32]:
 box((x,.025,147),(3.0,.05,2.2),'Stone')
for x in [-27,27]:box((x,.035,218.8),(4.5,.07,2.5),'Stone')
# A few shore stones follow the existing pond edge, with no invented pond expansion.
for pond in site['ponds']:
 for i,(x,z) in enumerate(pond['outline']):
  if 119<z<138 and abs(x)<77:
   ellipsoid((x,.08,z),(.40,.19,.29),'Stone',18,10)
