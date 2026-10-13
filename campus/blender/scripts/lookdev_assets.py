"""LookDev geometry upgrade. Executed in the asset builder context, meters."""
# Warmer neutral palette, no emissive orange bricks / acid green foliage.
for name,col in {'Brick':(.36,.22,.16),'BrickWarm':(.41,.28,.21),'Leaf':(.22,.32,.13),'LeafLight':(.33,.43,.19),'LeafDark':(.11,.22,.13),'Trunk':(.27,.25,.20),'BarkLight':(.56,.54,.45),'Stone':(.62,.59,.52),'Frame':(.58,.60,.55),'Glass':(.10,.14,.13),'GlassLight':(.13,.16,.15),'PavilionRoof':(.37,.19,.13)}.items():
 M[name].diffuse_color=(*col,1);M[name].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*col,1)
active='Architecture'
# North wall is now segmented around actual recessed windows; keep map footprint.
for lev in range(4):
 y=2.5+lev*4.05
 for x in range(-60,61,4):
  if lev==0 and abs(x)<6:continue
  box((x,y,168.17),(2.23,2.82,.46),'Brick')
for lo,hi in [(0,1.10),(3.90,5.15),(7.95,9.20),(12.0,13.25),(16.05,17)]:
 box((0,(lo+hi)/2,168.17),(124,hi-lo,.46),'Brick')
for x in [-61.55,61.55]:
 box((x,8.5,167.94),(.90,17,.55),'BrickWarm')
for y,d,h in [(16.62,.72,.22),(16.92,.9,.20),(17.15,1.04,.17)]:
 box((0,y,167.91),(125,h,d),'Stone')
for x in range(-58,59,4):
 for lev in range(4):
  y=2.5+lev*4.05
  if lev==0 and abs(x)<6:continue
  # Deep jambs, over-sill lintel, darker cavity. No invented ornament.
  for dx in [-.88,.88]:box((x+dx,y,168.06),(.14,2.82,.42),'BrickWarm')
  box((x,y+1.42,168.03),(1.96,.20,.42),'BrickWarm')
  box((x,y-1.43,167.93),(2.04,.14,.64),'Stone')
  # Fine lower glazing division introduces a believable construction hierarchy.
  box((x,y-.72,168.12),(1.55,.035,.065),'Frame')
  # Interior variation belongs behind glazing, not an opaque exterior sticker.
# Entrance structure, shadowed soffit, real handrail and landing.
box((0,4.53,166.95),(11.5,.09,2.45),'Dark')
for x in [-5.6,5.6]:
 box((x,2.4,166.75),(.24,4.7,.24),'Stone')
 for z in [164.4,165.2,166]:tube((x,.25,z),(x,1.16,z),.022,.022,'Metal',12)
 tube((x,1.16,164.3),(x,1.16,166.3),.027,.027,'Metal',12)
# Low curb/drain rhythm anchors avenue; orderly tree pits, no scatter clutter.
active='SiteDetail'
# Existing expert-building silhouette seen behind the pond. Roof pitch estimated
# from the official pavilion photo; footprint is unchanged and remains OSM based.
for x0,x1,z0,z1,ridge in [(30.5,89,14.8,36.6,15.0),(44.0,60.2,33.0,54.9,14.4)]:
 if x1-x0>z1-z0:
  v=[(x0,12.60,z0),(x1,12.60,z0),(x1,12.60,z1),(x0,12.60,z1),(x0,ridge,(z0+z1)/2),(x1,ridge,(z0+z1)/2)]
 else:
  v=[(x0,12.60,z0),(x1,12.60,z0),(x1,12.60,z1),(x0,12.60,z1),((x0+x1)/2,ridge,z0),((x0+x1)/2,ridge,z1)]
 if x1-x0>z1-z0:geo(v,[(0,1,5,4),(4,5,2,3),(0,4,3),(1,2,5)],'Roof')
 else:geo(v,[(0,4,5,3),(4,1,2,5),(0,1,4),(3,5,2)],'Roof')
expert=next(b for b in site['background'] if b['osm_id']=='270537516')
poly=expert['outline'][:-1]
for a,b in zip(poly,poly[1:]+poly[:1]):
 length=math.dist(a,b);ux=(b[0]-a[0])/length;uz=(b[1]-a[1])/length
 for y in [3.4,6.7,10.0,12.6]:beam(a,b,.25,.12,y,'Stone')
 for lev in range(4):
  for i in range(int(length/3.4)):
   t=(i+.5)/max(1,int(length/3.4));xx=a[0]+(b[0]-a[0])*t;zz=a[1]+(b[1]-a[1])*t;yy=lev*3.3+2
   for off in [-.08,.08]:
    cx=xx-uz*off;cz=zz+ux*off
    p=(cx-ux*.80,cz-uz*.80);q=(cx+ux*.80,cz+uz*.80)
    for y in [yy-.94,yy+.94]:beam(p,q,.13,.085,y,'Frame')
    for x,z in [p,q]:tube((x,yy-.94,z),(x,yy+.94,z),.035,.035,'Frame',8)
for side in [-1,1]:
 for i in range(147):
  z=2+i
  box((side*4.25,.075,z),(.22,.15,.975),'Stone')
 for z in [24,48,72,96,120,144]:
  box((side*4.05,.067,z),(.28,.02,.86),'Dark')
  for dz in range(8):box((side*4.05,.085,z-.36+dz*.1),(.28,.018,.026),'Metal')
 for i in range(19):
  z=6+i*7.45;x=side*7.15
  for dx in [-.82,.82]:box((x+dx,.045,z),(.10,.11,1.75),'Stone')
  for dz in [-.82,.82]:box((x,.045,z+dz),(1.55,.11,.10),'Stone')
for i in range(8):
 x=-31+i*1.9
 tube((x,.05,164.1),(x,.78,164.1),.027,.027,'Metal',12)
 tube((x,.78,164.1),(x+.75,.78,164.1),.027,.027,'Metal',12)
 tube((x+.75,.78,164.1),(x+.75,.05,164.1),.027,.027,'Metal',12)
# Lighting hardware with neck, reflector, diffuser and base collar.
active='Lamp'
tube((0,.02,0),(0,.35,0),.12,.08,'Metal',20)
box((.68,4.69,0),(.41,.04,.26),'Plaster')
box((.68,4.83,0),(.50,.035,.35),'Metal')
for x in [.48,.88]:tube((x,4.70,-.12),(x,4.81,-.12),.009,.009,'Metal',8)
# Pavilion reference: warm columns, pale soffit, curved tile courses and red caps.
active='Architecture';groups.pop(('Architecture','PavilionRoof'),None)
col=(.53,.40,.23);m=bpy.data.materials.new('PavilionColumn');m.diffuse_color=(*col,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*col,1);M['PavilionColumn']=m
col=(.65,.61,.51);m=bpy.data.materials.new('Soffit');m.diffuse_color=(*col,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*col,1);M['Soffit']=m
def rv(t,a,k):
 r=4.65*t;h=6.35-3.4*t+1.15*t**4+.55*t**5*abs(2*k-1)**4
 return Vector((px+r*math.cos(a),h,pz+r*math.sin(a)))
for side in range(6):
 a=side*math.tau/6;b=(side+1)*math.tau/6
 for j in range(24):
  for k in range(20):
   q=[rv(j/24,a+(b-a)*k/20,k/20),rv(j/24,a+(b-a)*(k+1)/20,(k+1)/20),rv((j+1)/24,a+(b-a)*(k+1)/20,(k+1)/20),rv((j+1)/24,a+(b-a)*k/20,k/20)]
   geo(q,[(0,1,2,3)],'PavilionRoof')
   if j>15:geo([v-Vector((0,.13,0)) for v in q],[(3,2,1,0)],'Soffit')
 for k in range(19):
  u=(k+.5)/19;ang=a+(b-a)*u
  for j in range(5,24):
   p=rv(j/24,ang,u)+Vector((0,.033,0));q=rv((j+1)/24,ang,u)+Vector((0,.033,0))
   tube(p,q,.058,.058,'PavilionRoof',10)
  end=rv(1,ang,u);tube(end+Vector((0,.03,0)),end+Vector((0,.03,0))+Vector((math.cos(ang),0,math.sin(ang)))*.10,.075,.075,'PavilionRoof',12)
 # Stronger corner ridge, individually segmented, elegant upturn.
 for j in range(24):tube(rv(j/24,a,0)+Vector((0,.09,0)),rv((j+1)/24,a,0)+Vector((0,.09,0)),.075,.075,'PavilionRoof',12)
 x=px+3*math.cos(a);z=pz+3*math.sin(a)
 tube((x,base,z),(x,4.3,z),.147,.128,'PavilionColumn',24)
 # Timber seat rail around five sides; west bridge entrance remains open.
 if side not in [2,3]:
  xx=px+3*math.cos(b);zz=pz+3*math.sin(b)
  tube((x,1.23,z),(xx,1.23,zz),.065,.065,'Wood',12)
  for t in [.2,.4,.6,.8]:
   cx=x+(xx-x)*t;cz=z+(zz-z)*t;tube((cx,.40,cz),(cx,1.23,cz),.025,.025,'Wood',8)
tube((px,6.2,pz),(px,6.58,pz),.22,.15,'PavilionRoof',24)
ellipsoid((px,6.64,pz),(.20,.23,.20),'PavilionRoof',20,12)
# Remove every faceted canopy shell, rebuild complete branch structures.
for key in list(groups):
 if key[0].startswith('Tree') or key[0] in ['Lotus','Grass']:del groups[key]
def curve_branch(points,radius,mat='Trunk',sides=12):
 if radius>.02:
  smooth=[]
  for j in range(len(points)-1):
   p0=Vector(points[max(j-1,0)]);p1=Vector(points[j]);p2=Vector(points[j+1]);p3=Vector(points[min(j+2,len(points)-1)])
   for k in range(4):
    t=k/4;smooth.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
  smooth.append(Vector(points[-1]));vs=[]
  for j,p in enumerate(smooth):
   axis=(smooth[min(j+1,len(smooth)-1)]-smooth[max(j-1,0)]).normalized();u=axis.cross(Vector((0,1,0)))
   if u.length<.01:u=axis.cross(Vector((1,0,0)))
   u.normalize();v=axis.cross(u);r=max(.004,radius*(1-j/(len(smooth)-1))**1.2)
   for k in range(sides):vs.append(p+(u*math.cos(k*math.tau/sides)+v*math.sin(k*math.tau/sides))*r)
  geo(vs,[(j*sides+k,j*sides+(k+1)%sides,(j+1)*sides+(k+1)%sides,(j+1)*sides+k) for j in range(len(smooth)-1) for k in range(sides)],mat)
  return
 for j in range(len(points)-1):
  t=j/(len(points)-1);u=(j+1)/(len(points)-1)
  tube(points[j],points[j+1],max(.005,radius*(1-t)**1.2),max(.004,radius*(1-u)**1.2),mat,sides)
def leaf(center,direction,length,width,mat):
 # Curved blade with raised midrib; geometry is small enough to read as leaf sprays.
 u=Vector(direction).normalized();w=u.cross(Vector((0,1,0)))
 if w.length<.05:w=Vector((1,0,0))
 w.normalize();w*=width;c=Vector(center);u*=length
 vs=[]
 for i in range(12):
  a=i*math.tau/12;along=math.cos(a);across=math.sin(a)
  vs.append(c+u*along+w*across+Vector((0,abs(along)*length*.045,0)))
 vs.append(c+Vector((0,length*.14,0)))
 geo(vs,[(i,(i+1)%12,12) for i in range(12)],mat)
for species in range(3):
 for individual in range(3):
  active='Tree'+str(species)+('' if individual==0 else ['','b','c'][individual]);random.seed(6100+species*51+individual*197)
  height=[8.2,12.8,10.2][species]*random.uniform(.94,1.06);spread=[3.9,5.0,3.8][species]
  lean=Vector((random.uniform(-.75,.75),0,random.uniform(-.65,.65)))
  trunk=[Vector((0,0,0)),lean*.2+Vector((0,1.8,0)),lean*.6+Vector((0,height*.33,0)),lean+Vector((0,height*.60,0))]
  radius=[.25,.38,.25][species];curve_branch(trunk,radius,sides=18)
  # Plane-tree root flare and mottled light bark, cherry keeps a dark sinuous trunk.
  for i in range(6):
   a=i*math.tau/6;curve_branch([Vector((math.cos(a)*.68,.04,math.sin(a)*.68)),Vector((math.cos(a)*.20,.35,math.sin(a)*.20)),Vector((0,.8,0))],radius*.30,sides=10)
  if species==1:tube((0,0,0),trunk[1]*.72,radius*1.015,radius*.68,'BarkLight',18)
  for b in range(8 if species!=2 else 10):
   ang=b*2.399+random.uniform(-.48,.48);rad=spread*random.uniform(.48,1);yy=height*random.uniform(.46,.87)
   start=trunk[2]+Vector((0,b*.095,0));end=Vector((math.cos(ang)*rad,yy,math.sin(ang)*rad))
   elbow=start.lerp(end,.48)+Vector((0,.6,0));curve_branch([start,elbow,end],radius*.47,sides=12)
   for j in range(4):
    aa=ang+(j-1.5)*.52;origin=elbow.lerp(end,.55)
    top=end+Vector((math.cos(aa)*random.uniform(.25,1.4),random.uniform(-.35,1.85),math.sin(aa)*random.uniform(.25,1.4)))
    curve_branch([origin,origin.lerp(top,.6)+Vector((0,.25,0)),top],.037,sides=8)
    for twig in range(7):
     a=random.uniform(0,math.tau);s=top+Vector((math.cos(a)*random.uniform(.25,1.25),random.uniform(-.4,.6),math.sin(a)*random.uniform(.25,1.25)))
     e=s+Vector((math.cos(a)*.7,(-1.6 if species==2 else .35),math.sin(a)*.7))
     curve_branch([top,s,e],.009,sides=5)
     for k in range(16):
      t=k/16;c=s.lerp(e,t)+Vector((random.uniform(-.32,.32),random.uniform(-.20,.25),random.uniform(-.32,.32)))
      la=a+(1 if k%2 else -1)*random.uniform(.7,1.8)
      length=[.15,.23,.20][species]*random.uniform(.7,1.25);width=length*[.46,.73,.20][species]
      direction=Vector((math.cos(la),random.uniform(-.4,.65),math.sin(la)))
      mat=random.choices(['Leaf','LeafLight','LeafDark'],[.60,.23,.17])[0]
      leaf(c,direction,length,width,mat)
active='Shrub';random.seed(629)
for i in range(460):
 a=random.uniform(0,math.tau);r=random.random()**.4
 c=Vector((math.cos(a)*r*1.2,.12+(1-r*.5)*random.uniform(.35,.95),math.sin(a)*r*.9))
 leaf(c,Vector((math.cos(a),random.uniform(.1,.8),math.sin(a))),random.uniform(.06,.13),.04,random.choice(['Leaf','Leaf','LeafLight']))
# Lotus gets radial curvature, not an umbrella polygon.
active='Lotus'
tube((0,-.3,0),(.03,.13,0),.008,.008,'LeafDark',8)
vs=[];segments=36;rings=5
for j in range(rings+1):
 r=j/rings*.30
 for i in range(segments):
  a=i*math.tau/segments;vs.append((r*math.cos(a),.19-.065*(j/rings)**.65+.016*math.sin(a*7)*(j/rings)**3,r*math.sin(a)))
geo(vs,[(j*segments+i,j*segments+(i+1)%segments,(j+1)*segments+(i+1)%segments,(j+1)*segments+i) for j in range(rings) for i in range(segments)],'Leaf')
active='Grass';random.seed(80)
for i in range(25):
 a=random.uniform(0,math.tau);x=random.uniform(-.2,.2);z=random.uniform(-.2,.2);h=random.uniform(.10,.28);w=random.uniform(.008,.016)
 v=[(x-w,0,z),(x+w,0,z),(x+math.cos(a)*.04+w,h*.6,z+math.sin(a)*.04),(x+math.cos(a)*.09,h,z+math.sin(a)*.09),(x+math.cos(a)*.04-w,h*.6,z+math.sin(a)*.04)]
 geo(v,[(0,1,2,4),(4,2,3)],'Leaf' if i%3 else 'LeafLight')
