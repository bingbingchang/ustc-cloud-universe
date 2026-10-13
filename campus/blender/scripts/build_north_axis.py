"""Independent researched north-axis architecture; never rebuild accepted hall assets.
All authored geometry uses Godot (east, up, south), converted with pt=(x,-z,y).
Run Blender -b --python build_north_axis.py [-- --proof].
"""
from pathlib import Path
import sys, math, random, json, shutil
import bpy, bmesh
from mathutils import Vector
SCRIPT=Path(__file__).resolve()
R=SCRIPT.parents[2]
# Only deterministic mesh helpers/material definitions, before any building/export code.
helper=(SCRIPT.parent/'build_campus.py').read_text(encoding='utf-8').split('# U-shape follows')[0]
helper=helper.replace("m.node_tree.nodes.get('Principled BSDF')","next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')")
exec(compile(helper,'build_campus_helper_prefix','exec'),globals())
random.seed(1958)
for name,col in {'Brick':(.36,.22,.16),'BrickWarm':(.41,.28,.21),'Leaf':(.22,.32,.13),'LeafLight':(.33,.43,.19),'LeafDark':(.11,.22,.13),'Trunk':(.27,.25,.20),'BarkLight':(.56,.54,.45),'Stone':(.62,.59,.52),'Frame':(.58,.60,.55),'Glass':(.10,.14,.13),'GlassLight':(.13,.16,.15),'PavilionRoof':(.37,.19,.13)}.items():
 M[name].diffuse_color=(*col,1);next(n for n in M[name].node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value=(*col,1)
for name,col,rough in [('NorthGateIvory',(.69,.66,.56),.82),('NorthJoint',(.36,.37,.33),.93),('NorthRoofTile',(.30,.32,.30),.76),('NorthTileWarm',(.42,.215,.155),.8),('NorthColumn',(.56,.44,.27),.78),('NorthSoffit',(.66,.63,.54),.85),('NorthCourtWood',(.28,.205,.14),.80),('NorthExpertBrick',(.43,.275,.205),.86),('NorthBrickPale',(.57,.47,.34),.86),('NorthBackgroundPlaster',(.56,.57,.50),.85),('NorthGateLetter',(.25,.09,.065),.77)]:
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*col,1)
 bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(*col,1);bs.inputs['Roughness'].default_value=rough;M[name]=m
# Canonical coordinates are copied from the verified OSM geometry and replaced by
# north_axis_layout.json when present. Never use the old site.json hand-drawn bridge.
PAV=[42.501,80.789]
PAV_OUTLINE=[[38.832,77.761],[38.502,82.185],[41.705,85.223],[46.031,83.383],[46.521,78.591],[43.025,76.044]]
BRIDGES=[
 {'id':'east_north','width':2.6,'points':[[28.635,65.950],[34.350,67.971],[36.413,70.165],[40.320,71.405],[42.539,74.046],[43.025,76.044]]},
 {'id':'east_east','width':2.6,'points':[[68.840,75.640],[60.468,75.573],[59.275,76.320],[57.330,78.383],[52.296,78.799],[46.521,78.591]]},
 {'id':'west_main','width':2.6,'points':[[-17.199,106.686],[-22.275,107.411],[-27.471,108.841],[-35.098,110.480],[-41.351,112.110],[-42.268,113.736],[-43.024,116.367],[-42.672,119.783],[-43.758,124.307],[-41.926,133.286]]},
 {'id':'west_short','width':2.0,'points':[[-41.351,112.110],[-44.877,109.840]]}]
DECK=.34
layout_path=R/'godot/data/north_axis_layout.json'
layout=json.loads(layout_path.read_text(encoding='utf-8')) if layout_path.exists() else {}
if layout:
 PAV=layout['pavilion']['center'];PAV_OUTLINE=layout['pavilion']['polygon'];DECK=layout['pavilion']['top']
 BRIDGES=[dict(b) for b in layout['bridges']]
solids=[]
manifest={'unit':'meter','coordinate_system':'Godot +X east,+Y up,+Z south; Blender=(x,-z,y)', 'source_site':'godot/assets/site.json', 'layout_source':'godot/data/north_axis_layout.json; OSM corroborated with official photographs', 'pavilion_outline':PAV_OUTLINE,'pavilion_center':PAV,'deck_top':DECK,'bridges':BRIDGES,'collision_solids':solids,'groups':{},'observed_sources':['https://zgkdb.ustc.edu.cn/ndetail/3705','https://djyszw.ustc.edu.cn/info/1041/3325.htm','https://zsb.ustc.edu.cn/2024/0310/c35540a631898/page.htm','https://news.ustc.edu.cn/info/1056/94500.htm'],'confidence':'OSM footprints and adjacency medium; photographed architecture character high; heights, joinery, expert facade/roof subdivision are estimated'}

def solid_box(name,c,s):solids.append({'name':name,'type':'box','center':list(c),'size':list(s)})
def solid_cylinder(name,c,r,h):solids.append({'name':name,'type':'cylinder','center':list(c),'radius':r,'height':h})
def beam(a,b,width,h,y,mat,collide=None):
 dx=b[0]-a[0];dz=b[1]-a[1];l=math.hypot(dx,dz)
 if l<1e-6:return
 if collide:
  solids.append({'name':collide,'type':'beam','a':list(a),'b':list(b),'width':width,'height':h,'y':y});return
 u=(-dz/l*width/2,dx/l*width/2)
 vs=[(a[0]+u[0],y-h/2,a[1]+u[1]),(b[0]+u[0],y-h/2,b[1]+u[1]),(b[0]-u[0],y-h/2,b[1]-u[1]),(a[0]-u[0],y-h/2,a[1]-u[1])]
 vs += [(x,yy+h,z) for x,yy,z in vs]
 geo(vs,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],mat)
 if collide:solids.append({'name':collide,'type':'beam','a':list(a),'b':list(b),'width':width,'height':h,'y':y})

def slab(poly,bottom,top,mat):
 n=len(poly);vs=[(x,bottom,z) for x,z in poly]+[(x,top,z) for x,z in poly]
 # Polygon triangulation preserves concave expert footprint.
 topvs=[Vector(pt((x,top,z))) for x,z in poly]
 from mathutils.geometry import tessellate_polygon
 tris=tessellate_polygon([topvs]);fs=[]
 for tri in tris:fs.append(tuple(n+(v if isinstance(v,int) else min(range(n),key=lambda j:(topvs[j]-v).length)) for v in tri))
 fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 geo(vs,fs,mat)

def leaf_spray(c,size,angle,mat):
 c=Vector(c);u=Vector((math.cos(angle),.18,math.sin(angle)))*size;v=Vector((-math.sin(angle),.08,math.cos(angle)))*size*.45
 pts=[c-u,c-u*.4+v,c+u*.55+v*.72,c+u,c+u*.55-v*.72,c-u*.4-v,c+Vector((0,size*.12,0))]
 geo(pts,[(i,(i+1)%6,6) for i in range(6)],mat)

def sweep(points,r,mat,n=10,taper=0):
 pts=[Vector(p) for p in points];vs=[]
 for i,p in enumerate(pts):
  tangent=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
  u=tangent.cross(Vector((0,1,0)))
  if u.length<.01:u=tangent.cross(Vector((1,0,0)))
  u.normalize();v=tangent.cross(u);rr=r*(1-taper*i/max(1,len(pts)-1))
  for k in range(n):vs.append(p+rr*(math.cos(k*math.tau/n)*u+math.sin(k*math.tau/n)*v))
 fs=[tuple(range(n-1,-1,-1)),tuple((len(pts)-1)*n+k for k in range(n))]
 fs += [(j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k) for j in range(len(pts)-1) for k in range(n)]
 geo(vs,fs,mat)
def curve_tube(points,r,mat,n=10):
 ps=[Vector(p) for p in points];smooth=[]
 for i in range(len(ps)-1):
  a,b,c,d=ps[max(0,i-1)],ps[i],ps[i+1],ps[min(len(ps)-1,i+2)]
  for j in range(8):
   t=j/8;smooth.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
 smooth.append(ps[-1]);sweep(smooth,r,mat,n,.5)

# OLD NORTH GATE: four posts / three open bays, pale concrete and red lettering.
active='NorthGate'
gcx,gcz=-1.0,2.65
for idx,x in enumerate([-11.175,-5.1,3.1,9.175]):
 # Actual horizontal joints are thin recesses, not black drawn outlines.
 for j in range(6):
  low=.08+j*.855;box((x,low+.423,gcz),(1.35,.846,1.9),'NorthGateIvory')
 box((x,.07,gcz),(1.43,.14,2.02),'Stone')
 solid_box('NorthGatePost'+str(idx),(x,2.60,gcz),(1.35,5.20,1.9))
box((gcx,5.73,gcz),(21.7,1.16,2.2),'NorthGateIvory')
box((gcx,6.355,gcz),(21.96,.09,2.40),'Stone')
box((gcx,6.46,gcz),(22.04,.12,2.46),'NorthGateIvory')
box((gcx,5.14,gcz),(21.56,.08,2.06),'NorthSoffit')
for j in range(69):box((gcx-10.50+j*.31,5.085,gcz),(.048,.055,1.95),'NorthGateIvory')
# Two narrow cornice bands echo the reference; no invented pediment or ornament.
for off in [-1,1]:
 box((gcx,6.22,gcz+off*1.13),(21.84,.065,.065),'Stone')
 text('中国科学技术大学',(gcx,5.40,gcz+off*1.112),.88,'NorthGateLetter',rot=(math.pi/2,0,math.pi if off<0 else 0))
 for ob in bpy.context.scene.objects:
  if ob.type=='FONT':
   try:ob.data.font=bpy.data.fonts.load('C:/Windows/Fonts/simkai.ttf')
   except Exception:pass
   ob.data.space_character=1.5
solid_box('NorthGateHeader',(gcx,5.80,gcz),(21.96,1.45,2.4))
# Historic wisteria: woody structure wraps outer piers and drapes across the header.
active='NorthGateVine'
for side in [-1,1]:
 xx=gcx+side*9.7
 points=[(xx,.02,gcz+.8),(xx+side*.25,1.3,gcz+.90),(xx-side*.30,2.65,gcz+.97),(xx+side*.2,4.1,gcz+.99),(xx-side*.15,5.50,gcz+1.0),(xx-side*1.0,6.52,gcz+.5)]
 curve_tube(points,.115,'Trunk',14)
 for k in range(4):
  endx=gcx+side*(7-k*2.0);pts=[points[-2],points[-1],(endx,6.60+.12*math.sin(k),gcz+.35*math.cos(k)),(endx-side*1.4,6.63,gcz-.40)]
  curve_tube(pts,.055,'Trunk',10)
random.seed(562)
for j in range(38):
 x=gcx-10.5+j*21/37;hang=.2+.7*(.5+.5*math.sin(j*.93))
 center=Vector((x,6.53,gcz+.15*math.cos(j)))
 ellipsoid((x,6.70,gcz),(.69,.29,.88),'LeafDark',16,8)
 # Loose compound leaves make a flatter vine canopy rather than random tree balls.
 for k in range(130):
  a=random.random()*math.tau;r=random.random()**.5
  c=center+Vector((math.cos(a)*.74*r,random.uniform(-.24,.66)-max(0,math.sin(a))*.22,math.sin(a)*1.25*r))
  leaf_spray(c,random.uniform(.12,.21),a,['Leaf','LeafLight','LeafDark'][k%3])
 if j%3==0:
  pts=[(x,6.58,gcz+1.04),(x+.12,6.20,gcz+1.20),(x+.08,6.5-hang,gcz+1.22)];curve_tube(pts,.015,'Trunk',7)
  for k in range(12):
   t=k/11;c=Vector(pts[0]).lerp(Vector(pts[-1]),t);leaf_spray(c,random.uniform(.09,.16),k*2.4,'Leaf')

# YIJIAN PAVILION: exact OSM hexagon; restrained pale columns, wood benches,
# continuous swept terracotta roof with rolled tile channels and blunt crown.
active='NorthPavilion'
px,pz=PAV
slab(PAV_OUTLINE,-.35,DECK-.008,'Stone')
inner=[(px+(x-px)*.96,pz+(z-pz)*.96) for x,z in PAV_OUTLINE]
slab(inner,DECK-.008,DECK,'NorthSoffit')
colpts=[(px+(x-px)*.70,pz+(z-pz)*.70) for x,z in PAV_OUTLINE]
for i,(x,z) in enumerate(colpts):
 tube((x,DECK,z),(x,3.83,z),.165,.145,'NorthColumn',24)
 tube((x,DECK,z),(x,DECK+.13,z),.19,.18,'Stone',24)
 solid_cylinder('YijianColumn'+str(i),(x,(DECK+3.83)/2,z),.17,3.83-DECK)
 a=colpts[i];b=colpts[(i+1)%6]
 beam(a,b,.32,.29,3.84,'NorthSoffit')
 beam(a,b,.17,.09,3.61,'NorthCourtWood')
 dx,dz=b[0]-a[0],b[1]-a[1]
 # Simple rectangular Chinese garden bracket rhythm observed in close reference.
 for t in [.16,.84]:
  c=(a[0]+dx*t,a[1]+dz*t)
  beam((c[0]-dx*.07,c[1]-dz*.07),(c[0]+dx*.07,c[1]+dz*.07),.095,.10,3.45,'NorthCourtWood')
  tube((c[0],3.41,c[1]),(c[0],3.62,c[1]),.042,.042,'NorthCourtWood',8)
 # Both bridge junctions at northern/eastern vertices stay unblocked.
 if i in [0,1,2]:
  beam(a,b,.45,.12,.84,'NorthCourtWood')
  beam(a,b,.10,.11,1.37,'NorthCourtWood')
  for q in range(9):
   t=(q+.5)/9;xx=a[0]+dx*t;zz=a[1]+dz*t
   tube((xx,.9,zz),(xx+dx*.025,1.33,zz+dz*.025),.030,.027,'NorthCourtWood',10)
  beam(a,b,.42,.95,.84,'NorthCourtWood',collide='YijianBenchBarrier'+str(i))
# Roof is a tessellated curved sheet over the irregular six-sided plan.
def rv(side,t,k,lift=0):
 a=PAV_OUTLINE[side];b=PAV_OUTLINE[(side+1)%6]
 x=(a[0]*(1-k)+b[0]*k-px)*1.13;z=(a[1]*(1-k)+b[1]*k-pz)*1.13
 h=6.44-3.94*t+1.62*t**4+.88*t**5*abs(2*k-1)**3
 return (px+x*t,h+lift,pz+z*t)
for side in range(6):
 for j in range(22):
  for k in range(24):
   coords=[rv(side,j/22,k/24),rv(side,j/22,(k+1)/24),rv(side,(j+1)/22,(k+1)/24),rv(side,(j+1)/22,k/24)]
   active='NorthPavilionRoofSurface';geo(coords,[(0,1,2,3)],'PavilionRoof')
   active='NorthPavilionRoofSoffit';geo([(x,y-.12,z) for x,y,z in coords],[(3,2,1,0)],'NorthSoffit')
   active='NorthPavilion'
 # Fewer, continuous broad rolled channels read cleanly at real-world scale.
 for k in range(19):
  q=k/18
  sweep([rv(side,j/24,q,.026) for j in range(4,25)],.041,'NorthTileWarm' if k%4==0 else 'PavilionRoof',8)
  ellipsoid(rv(side,1,q,.012),(.055,.058,.055),'NorthTileWarm' if k%4==0 else 'PavilionRoof',12,7)
 sweep([rv(side,j/32,0,.07) for j in range(33)],.071,'NorthTileWarm',10)
 # The fascia follows the true six-edge curve, no floating flat strip.
 sweep([rv(side,1,k/24,-.042) for k in range(25)],.058,'PavilionRoof',10)
tube((px,6.34,pz),(px,6.50,pz),.16,.17,'PavilionRoof',24)
tube((px,6.49,pz),(px,7.12,pz),.23,.27,'NorthTileWarm',24)
tube((px,7.10,pz),(px,7.15,pz),.285,.285,'PavilionRoof',24)
# The photographed pavilion does not justify a invented hanging sign; omit it.

# STONE BRIDGES: mitered walks, pale low cope slabs / short stone piers.
# All bridge tops are .34m and exact coordinates are in the manifest.
active='NorthBridges'
def offsets(points,r):
 pts=[Vector(p) for p in points];out=[]
 for i,p in enumerate(pts):
  prev=(p-pts[i-1]).normalized() if i else (pts[1]-p).normalized()
  nxt=(pts[i+1]-p).normalized() if i<len(pts)-1 else prev
  n0=Vector((-prev.y,prev.x));n1=Vector((-nxt.y,nxt.x));bis=(n0+n1).normalized();scale=r/max(.35,bis.dot(n1))
  out.append((p+bis*scale,p-bis*scale))
 return out
for bridge in BRIDGES:
 points=bridge['points'];width=bridge['width'];edge=offsets(points,width/2);rail=offsets(points,width/2-.14)
 for i,(a,b) in enumerate(zip(points,points[1:])):
  poly=[list(edge[i][0]),list(edge[i+1][0]),list(edge[i+1][1]),list(edge[i][1])]
  slab(poly,DECK-.26,DECK,'Stone')
  length=math.dist(a,b);dx,dz=b[0]-a[0],b[1]-a[1]
  # Transverse paving joints have millimeter height to avoid a gameplay obstacle.
  steps=max(1,int(length/.80))
  for j in range(1,steps):
   t=j/steps;c=(a[0]+dx*t,a[1]+dz*t);n=(-dz/length,dx/length)
   beam((c[0]+n[0]*(width/2-.20),c[1]+n[1]*(width/2-.20)),(c[0]-n[0]*(width/2-.20),c[1]-n[1]*(width/2-.20)),.010,.003,DECK+.003,'NorthJoint')
  for side in [0,1]:
   aa,bb=rail[i][side],rail[i+1][side]
   # West branch joins its main bridge here: remove only adjoining rail spans.
   if bridge['id'] in ['west_main','west_curve'] and side==0:
    if i==3:bb=bb.lerp(aa,min(.9,1.2/(bb-aa).length))
    if i==4:aa=aa.lerp(bb,min(.9,1.2/(bb-aa).length))
   if bridge['id'] in ['west_short','west_spur'] and i==0:aa=aa.lerp(bb,min(.9,1.35/(bb-aa).length))
   beam(aa,bb,.30,.30,DECK-.03,'Stone')
   beam(aa,bb,.36,.14,DECK+.60,'Stone')
   beam(aa,bb,.22,.11,DECK+.135,'Stone')
   beam(aa,bb,.28,.66,DECK+.33,'Stone',collide='BridgeBarrier_'+bridge['id']+'_'+str(i)+'_'+str(side))
   spacing=max(1,math.ceil((bb-aa).length/1.65))
   for j in range(spacing):
    t=(j+.25)/spacing;c=aa.lerp(bb,t)
    box((c.x,DECK+.365,c.y),(.24,.34,.24),'Stone')
    box((c.x,DECK+.52,c.y),(.30,.08,.30),'NorthSoffit')
 for j,p in enumerate(points):
  if j in [0,len(points)-1]:continue
  tube((p[0],-.94,p[1]),(p[0],DECK-.27,p[1]),.32,.28,'Stone',16)

# EXPERT BUILDING: existing measured footprint, estimated four-storey courtyard
# accommodation facade / pitched gray roof based on visible official background.
active='NorthExpert'
expert=next(b for b in site['background'] if str(b['osm_id'])=='270537516')
poly=[tuple(p) for p in expert['outline'][:-1]]
height=12.5
slab(poly,0,height,'NorthExpertBrick')
solids.append({'name':'ExpertBuildingSolid','type':'polygon','outline':[list(p) for p in poly],'bottom':0,'top':height})
def facade(poly,height,wallmat='NorthExpertBrick',levels=4,spacing=3.4,detail=True):
 area=sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1]));outsign=-1 if area>0 else 1
 for edge_index,(a,b) in enumerate(zip(poly,poly[1:]+poly[:1])):
  length=math.dist(a,b)
  if length<.15:continue
  ux,uz=(b[0]-a[0])/length,(b[1]-a[1])/length
  nx,nz=-uz*outsign,ux*outsign
  def p(t,off):return(a[0]+ux*t+nx*off,a[1]+uz*t+nz*off)
  beam(a,b,.30,.52,.26,'Stone')
  for y in [height-.30,height+.05]:beam(a,b,.52,.15,y,'Stone')
  if detail:
   for lev in range(1,levels):beam(a,b,.26,.10,lev*3.125,'NorthBrickPale')
  count=int(length/spacing)
  if count<1:continue
  for j in range(count):
   t=(j+.5)*length/count;w=min(1.6,length/count*.57);half=w/2
   for lev in range(levels):
    y=(lev+.57)*height/levels;h=min(1.83,height/levels*.60)
    aa=p(t-half,.05);bb=p(t+half,.05)
    beam(aa,bb,.075,h,y,'Dark')
    aa=p(t-half+.035,.10);bb=p(t+half-.035,.10)
    beam(aa,bb,.025,h-.06,y,'GlassLight' if (lev+j+edge_index)%5==0 else 'Glass')
    for tt in [-half,0,half]:
     q=p(t+tt,.16);tube((q[0],y-h/2,q[1]),(q[0],y+h/2,q[1]),.025,.025,'Frame',6)
    for yy in [y-h/2,y+.36,y+h/2]:beam(p(t-half,.16),p(t+half,.16),.065,.055,yy,'Frame')
    beam(p(t-half-.14,.18),p(t+half+.14,.18),.36,.13,y-h/2-.09,'Stone')
    if detail:
     beam(p(t-half-.13,.11),p(t-half-.13,.11+.02),.20,h+.36,y,wallmat)
     # Deep jamb strips extend from wall to frame plane.
     for tt in [-half-.11,half+.11]:
      q=p(t+tt,.16);tube((q[0],y-h/2-.11,q[1]),(q[0],y+h/2+.13,q[1]),.075,.075,'NorthBrickPale',4)
     beam(p(t-half-.22,.09),p(t+half+.22,.09),.30,.13,y+h/2+.12,'NorthBrickPale')
     # Occasional pale brick keys paraphrase visible warm red/pale wall rhythm.
     if (j+lev)%3==0:beam(p(t+half+.30,.012),p(t+half+.64,.012),.035,.16,y+.12,'NorthBrickPale')
facade(poly,height)

def hiproof(x0,x1,z0,z1,eave,ridge,mat='NorthRoofTile'):
 # Hipped ends create silhouette; no decorative dormers are invented.
 inset=min((z1-z0)*.52,(x1-x0)*.24)
 v=[(x0,eave,z0),(x1,eave,z0),(x1,eave,z1),(x0,eave,z1),(x0+inset,ridge,(z0+z1)/2),(x1-inset,ridge,(z0+z1)/2)]
 geo(v,[(0,1,5,4),(1,2,5),(2,3,4,5),(3,0,4)],mat)
 for a,b in [(v[0],v[4]),(v[1],v[5]),(v[2],v[5]),(v[3],v[4]),(v[4],v[5])]:tube(a,b,.055,.055,mat,8)
 for a,b in zip([(x0,z0),(x1,z0),(x1,z1),(x0,z1)],[(x1,z0),(x1,z1),(x0,z1),(x0,z0)]):beam(a,b,.22,.18,eave-.05,'Stone')
 # Broad tile course rhythm, not tens of thousands of tiny scanned shingles.
 for j in range(1,8):
  t=j/8;yy=eave+(ridge-eave)*t+.016
  xx0=x0+inset*t;xx1=x1-inset*t
  for z in [z0+(z1-z0)*.5*t,z1-(z1-z0)*.5*t]:beam((xx0,z),(xx1,z),.035,.026,yy,mat)
hiproof(30.6,88.9,14.8,32.1,12.64,15.0)
hiproof(30.2,60.0,27.4,37.0,12.60,14.15)
# South stem is roofed in its long axis by coordinate-swapping a local hipped roof.
# Explicit long north/south roof without patching globally used helpers.
v=[(43.9,12.64,30.8),(59.8,12.64,30.8),(59.8,12.64,55.1),(43.9,12.64,55.1),(51.85,14.80,36.5),(51.85,14.80,49.4)]
geo(v,[(0,4,5,3),(1,2,5,4),(0,1,4),(2,3,5)],'NorthRoofTile')
for a,b in [(v[0],v[4]),(v[1],v[4]),(v[2],v[5]),(v[3],v[5]),(v[4],v[5])]:tube(a,b,.055,.055,'NorthRoofTile',8)
hiproof(49.0,61.1,10.2,20.8,12.64,14.35)
# An understated south entrance and four shallow risers retain campus scale.
box((51.8,1.50,54.17),(3.4,2.85,.12),'Dark')
for x in [50.8,52.0,53.2]:box((x,1.51,54.26),(.06,2.8,.08),'Frame')
box((51.8,3.18,54.80),(4.5,.23,1.6),'Stone')
for j in range(3):box((51.8,.06*(j+1),55.6-j*.34),(4.4,.12*(j+1),.36),'Stone')
for x in [49.7,53.9]:tube((x,.34,54.75),(x,3.10,54.75),.055,.055,'Metal',12)

# Secondary real footprints remain a separate optional layer, subdued materials.
for bid in ['267646978','298741850','298741849']:
 it=next((b for b in site['background'] if str(b['osm_id'])==bid),None)
 if it is None:continue
 active='NorthSurrounding_'+bid;poly=[tuple(p) for p in it['outline'][:-1]];h=float(it['height'])
 match=next((b for b in layout.get('buildings',[]) if str(b['osm_way'])==bid),None)
 if match:poly=[tuple(p) for p in match['polygon']];h=float(match['height'])
 slab(poly,0,h,'NorthBackgroundPlaster');facade(poly,h,'NorthBackgroundPlaster',levels=max(1,round(h/3.3)),spacing=4.1,detail=False)
 slab(poly,h,h+.15,'NorthRoofTile')
 solids.append({'name':active,'type':'polygon','outline':[list(p) for p in poly],'bottom':0,'top':h,'optional_layer':'north_axis_surroundings'})

# Build material batches; controlled bevels catch light without low-poly outlines.
asset_objects={}
for (group,mat),(vs,fs) in groups.items():
 mesh=bpy.data.meshes.new(group+'_'+mat);mesh.from_pydata(vs,[],fs);mesh.materials.append(M[mat]);mesh.update()
 o=bpy.data.objects.new(group+'_'+mat,mesh);bpy.context.collection.objects.link(o);o['asset_group']=group
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.00003);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);
 if group=='NorthPavilionRoofSurface':bmesh.ops.reverse_faces(bm,faces=[f for f in bm.faces if f.normal.z<0])
 if group=='NorthPavilionRoofSoffit':bmesh.ops.reverse_faces(bm,faces=[f for f in bm.faces if f.normal.z>0])
 bm.to_mesh(mesh);bm.free()
 if mat in ['PavilionRoof','NorthTileWarm','NorthSoffit','NorthColumn','Trunk'] or group=='NorthGateVine':
  for f in mesh.polygons:f.use_smooth=True
 if mat not in ['Glass','GlassLight','Leaf','LeafLight','LeafDark','PavilionRoof','NorthTileWarm','Trunk','Frame','Dark','NorthBrickPale','NorthBackgroundPlaster']:
  bev=o.modifiers.new('Soft architectural edges','BEVEL');bev.width=.018 if group in ['NorthPavilion','NorthBridges'] else .027;bev.segments=2;bev.limit_method='ANGLE';bev.angle_limit=.55
  normal=o.modifiers.new('Face weighted normals','WEIGHTED_NORMAL');normal.keep_sharp=True
 asset_objects.setdefault(group,[]).append(o)
for o in bpy.context.scene.objects:
 if o.type=='FONT':asset_objects.setdefault(o['asset_group'],[]).append(o)
for layer in ['north_axis_architecture','north_axis_surroundings']:
 objs=[o for g,os in asset_objects.items() for o in os if g.startswith('NorthSurrounding')==(layer=='north_axis_surroundings')]
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 path=R/'blender/exports'/f'{layer}.glb';path.parent.mkdir(parents=True,exist_ok=True)
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_extras=True)
 shutil.copy2(path,R/'godot/assets'/path.name)
for group,objs in asset_objects.items():
 deps=bpy.context.evaluated_depsgraph_get();verts=[];tri=0
 for o in objs:
  ev=o.evaluated_get(deps)
  if o.type in ['MESH','FONT']:
   me=ev.to_mesh();me.calc_loop_triangles();tri+=len(me.loop_triangles)
   verts += [o.matrix_world@v.co for v in me.vertices];ev.to_mesh_clear()
 if verts:
  mini=[min(v[k] for v in verts) for k in range(3)];maxi=[max(v[k] for v in verts) for k in range(3)]
  manifest['groups'][group]={'objects':len(objs),'triangles':tri,'godot_bounds_min':[mini[0],mini[2],-maxi[1]],'godot_bounds_max':[maxi[0],maxi[2],-mini[1]]}
manifest['total_triangles']=sum(g['triangles'] for g in manifest['groups'].values())
for solid in solids:
 solid['owner']='environment' if solid['type']=='polygon' else 'root_architecture'
 solid['load_in_scene']=solid['type']!='polygon'
manifest['collision_policy']='Root loads box/cylinder/beam only. Four building polygons are informational and already built by north_axis_environment. Bridge and pavilion walkable decks/slopes belong exclusively to environment. No water blockers or ground added here.'
manifest['exports']=['godot/assets/north_axis_architecture.glb','godot/assets/north_axis_surroundings.glb']
out=R/'renders/north_axis';out.mkdir(parents=True,exist_ok=True)
(R/'godot/assets/north_axis_assets_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(out/'asset_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender/source/north_axis_architecture.blend'))
print('NORTH_AXIS_ASSETS_OK',json.dumps(manifest['groups']))

if '--proof' in sys.argv:
 scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1800;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
 scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False;scene.view_settings.view_transform='AgX'
 world=bpy.data.worlds.new('North axis proof sky');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.66,.75,.83,1);world.node_tree.nodes['Background'].inputs[1].default_value=.45;scene.world=world
 def area(name,p,energy,size,target):
  data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size;o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);o.location=pt(p);o.rotation_euler=(Vector(pt(target))-o.location).to_track_quat('-Z','Y').to_euler();return o
 lamp=area('Soft warm key',(-20,30,-15),6500,18,(0,2,0));lamp.data.color=(1,.85,.68)
 data=bpy.data.lights.new('Sun','SUN');data.energy=2.0;data.angle=.08;o=bpy.data.objects.new('Sun',data);bpy.context.collection.objects.link(o);o.rotation_euler=(.4,-.5,-.35)
 camera=bpy.data.cameras.new('ProofCamera');co=bpy.data.objects.new('ProofCamera',camera);bpy.context.collection.objects.link(co);scene.camera=co;camera.lens=55;camera.clip_end=600
 bpy.ops.mesh.primitive_plane_add(size=600);ground=bpy.context.object;ground.name='Proof neutral shadow receiver';ground.data.materials.append(M['NorthSoffit'])
 proofs=[('gate_front',[-4,7.0,-43],[-1,3.4,2.65],['NorthGate','NorthGateVine']),('gate_campus',[27,9,43],[-1,3.2,2.65],['NorthGate','NorthGateVine']),('pavilion_bridge',[20,6.4,91],[42.5,3,80.8],['NorthPavilion','NorthBridges']),('pavilion_east',[58,5.6,98],[42.5,3.4,80.8],['NorthPavilion','NorthBridges']),('expert_south',[119,43,121],[57,7,30],['NorthExpert'])]
 for name,p,target,visible in proofs:
  ground.location.z=-.42 if 'pavilion' in name else -.02
  for group,objs in asset_objects.items():
   for ob in objs:ob.hide_render=not any(group.startswith(g) for g in visible)
  co.location=pt(p);co.rotation_euler=(Vector(pt(target))-co.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'_blender.png'));bpy.ops.render.render(write_still=True)
 print('NORTH_AXIS_PROOFS_OK')
