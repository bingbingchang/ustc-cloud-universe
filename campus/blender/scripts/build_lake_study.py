"""Composition study: dense layered canopies, cupped leaves and grouped flowers.
Uses only the helper prefix of the existing lake generator; exports study_* only.
"""
from pathlib import Path
source=Path(__file__).with_name('build_lake_garden.py').read_text(encoding='utf-8').split('for variant in range(2):')[0]
exec(compile(source,'lake_geometry_helpers','exec'),globals())
for name,col in {'StudyBark':(.24,.23,.17),'StudyLeafDeep':(.105,.22,.15),'StudyLeafJade':(.22,.37,.20),'StudyLeafGold':(.39,.46,.20),'StudyLeafPurple':(.32,.20,.27),'StudyCream':(.94,.88,.68),'StudyRose':(.78,.42,.49)}.items():
 m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*col,1);M[name]=m
def ellipse(p,n,size,mat):
 p=V(p);u,w=axes(V(n));rot=rng.random()*math.tau;u,w=u*math.cos(rot)+w*math.sin(rot),-u*math.sin(rot)+w*math.cos(rot)
 vs=[p+V(n).normalized()*size*.12]
 for j in range(8):
  a=j*math.tau/8;vs.append(p+u*math.cos(a)*size+w*math.sin(a)*size*.48)
 geo(vs,[(0,j+1,(j+1)%8+1) for j in range(8)],mat)
def canopy(center,radius,count,variant):
 center=V(center)
 # Leaf volume, rather than an opaque ball: silhouette gaps carry the light.
 for i in range(int(count*2.5)):
  a=rng.random()*math.tau;y=rng.uniform(-1,1);rad=rng.uniform(.60,1.0);q=V((math.cos(a)*math.sqrt(1-y*y),y*.74,math.sin(a)*math.sqrt(1-y*y)))
  p=center+q*radius*rad;n=(q+V((0,.5,0))).normalized()
  mat=rng.choices(['StudyLeafDeep','StudyLeafJade','StudyLeafGold'],[.25,.55,.20])[0]
  if variant==2 and rng.random()<.8:mat='StudyLeafPurple'
  ellipse(p,n,rng.uniform(.10,.19),mat)
for variant in range(3):
 rng.seed(8711+variant*103)
 twig([(0,0,0),(0,2.5,0),(-.2,5.3,.15),(.2,7.4,0)],.32,'StudyBark',10)
 for j in range(5):
  a=j*math.tau/5;twig([(math.cos(a)*.65,.015,math.sin(a)*.65),(.05,.7,0)],.085,'StudyBark',8)
 for j in range(17):
  a=j*2.399;h=4.7+(j/16)*4.0;rr=3.1*(1-.35*j/17);p=V((math.cos(a)*rr,h,math.sin(a)*rr))
  twig([(0,2.4+j*.20,0),p*.62+V((0,.6,0)),p],.085,'StudyBark',7)
  canopy(p,rng.uniform(1.65,2.25),340,variant)
 canopy((0,8.4,0),2.2,620,variant)
 export('study_canopy_'+str(variant))
# Per-leaf height, radial curl and tilt remove the repeated flat plate shape.
def organic_pad(p,r,angle,tilt):
 p=V(p);phase=rng.random()*math.tau;u=V((math.cos(angle),0,math.sin(angle)));w=V((-math.sin(angle),0,math.cos(angle)));n=36;vs=[]
 for ring in [0,.24,.5,.76,1]:
  for j in range(n):
   a=.05+j/(n-1)*(math.tau-.10);rr=r*ring*(1+.045*math.sin(a*7+phase));h=r*(.22*ring*ring+.12*ring**4*math.sin(a*3+phase))
   vs.append(p+u*(math.cos(a)*rr)+w*(math.sin(a)*rr)+V((0,h+math.cos(a)*rr*tilt,0)))
 fs=[]
 for k in range(4):
  for j in range(n-1):fs.append((k*n+j,k*n+j+1,(k+1)*n+j+1,(k+1)*n+j))
 geo(vs,fs,'LakeLeaf' if tilt>.05 else 'LakeLeafLight')
 for j in range(0,n-1,5):
  a=.05+j/(n-1)*(math.tau-.10);end=vs[4*n+j];middle=vs[2*n+j]
  twig([p+V((0,.008,0)),middle+V((0,.01,0)),end+V((0,.01,0))],.004,'LakeVein',3)
for variant in range(4):
 rng.seed(1180+variant*31)
 for j in range(5):
  a=rng.random()*math.tau;rad=rng.uniform(.2,.7);p=V((math.cos(a)*rad,rng.uniform(.04,.78),math.sin(a)*rad))
  twig([(p.x,-.10,p.z),p],.012,'LakeReed',6);organic_pad(p,rng.uniform(.35,.61),rng.random()*math.tau,rng.uniform(-.3,.4))
 if variant>=2:
  p=V((.25,.95,-.12));twig([(.15,-.1,-.12),p],.014,'LakeReed',6);blossom(p,.35)
 export('study_lotus_'+str(variant))
for variant in range(2):
 rng.seed(861+variant)
 for j in range(32):
  a=rng.random()*math.tau;rad=rng.random()**.5*.72;p=V((math.cos(a)*rad,rng.uniform(.22,.62),math.sin(a)*rad))
  twig([(p.x*.8,0,p.z*.8),p],.007,'LakeReed',4)
  for k in range(3):ellipse(p*V((1,.3+k*.17,1)),(rng.uniform(-1,1),1,rng.uniform(-1,1)),.11,'StudyLeafJade')
  for k in range(5):
   a=k*math.tau/5;ellipse(p+V((math.cos(a)*.045,0,math.sin(a)*.045)),(0,1,0),.043,'StudyCream' if variant==0 else 'StudyRose')
  ellipse(p+V((0,.009,0)),(0,1,0),.023,'LakePollen')
 export('study_bank_patch_'+str(variant))
# A directional willow bough joins the existing north-bank willow above head height.
# Local +Z reaches towards the pond; drapes frame the approach rather than its centre.
rng.seed(91019)
twig([(0,4.0,0),(2,5.6,2.7),(4,6.2,5.1),(6,5.7,8.0)],.17,'StudyBark',9)
for j in range(75):
 z=rng.uniform(3.4,9.0);x=rng.uniform(2.0,6.0);h=6.3-abs(z-5.7)*.18+rng.uniform(-.4,.4)
 anchor=V((x,h,z));twig([(z*.65,5.8,z*.78),anchor],.019,'StudyBark',5)
 drop=rng.uniform(1.3,2.8)
 strand=[anchor+V((math.sin(t*2+j)*.12,-drop*t,t*.20)) for t in [0,.25,.5,.75,1]]
 twig(strand,.008,'LakeReed',4)
 for k in range(24):
  t=k/24;p=anchor+V((math.sin(t*2+j)*.12,-drop*t,t*.20))
  length=rng.uniform(.16,.25);long=V((rng.uniform(-.25,.25),-1,.15)).normalized();wide=V((1,.08,.3)).normalized()
  vs=[p+V((0,0,.014))]
  for a in [j*math.tau/12 for j in range(12)]:vs.append(p+long*(math.cos(a)*length*.5)+wide*(math.sin(a)*length*.16))
  geo(vs,[(0,j+1,(j+1)%12+1) for j in range(12)],'StudyLeafGold' if k%3 else 'StudyLeafJade')
export('study_willow_bough')

# Weathered, leaning stone groups: asymmetry, pale faces, moss and rooted plants.
for variant in range(2):
 rng.seed(4120+variant)
 for cx,cz,height,radius in [(0,0,2.1,.78),(.85,.4,1.1,.62),(-.65,.5,.75,.58)]:
  vs=[];fs=[];n=13
  for ring in range(7):
   t=ring/6
   for j in range(n):
    a=j*math.tau/n;rr=radius*(.82+.22*math.sin(t*5))*(1-.65*t**4)*(1+.16*math.sin(a*3+t*9)+rng.uniform(-.12,.12))
    vs.append(V((cx+math.cos(a)*rr+t*.3,height*t,cz+math.sin(a)*rr-t*.13)))
  for k in range(6):
   for j in range(n):fs.append((k*n+j,(k+1)*n+j,(k+1)*n+(j+1)%n,k*n+(j+1)%n))
  fs.append(tuple(range(6*n,7*n)))
  geo(vs,fs,'LakeStone')
  for j in range(55):
   a=rng.random()*math.tau;r=rng.uniform(.08,.35);p=V((cx+math.cos(a)*r+.3,height+.025,cz+math.sin(a)*r-.13))
   ellipse(p,(0,1,0),rng.uniform(.08,.16),'StudyLeafJade')
  for j in range(9):
   p=V((cx+rng.uniform(-.25,.25)+.3,height+.1,cz+rng.uniform(-.2,.2)-.13))
   leaf(p,.28,.045,'LakeWillow');ellipse(p+V((0,.17,0)),(0,1,0),.055,'StudyCream')
 export('study_rock_garden_'+str(variant))

for variant in range(2):
 rng.seed(6280+variant)
 for j in range(100):
  a=rng.random()*math.tau;r=rng.random()**.5*1.1;h=.35+.7*(1-r/1.4)+rng.uniform(-.12,.12);p=V((math.cos(a)*r,h,math.sin(a)*r))
  twig([(p.x*.8,0,p.z*.8),p],.008,'LakeReed',4)
  for k in range(4):ellipse(p*V((1,.35+k*.17,1)),(rng.uniform(-1,1),1,rng.uniform(-1,1)),.13,'StudyLeafJade' if k%3 else 'StudyLeafGold')
  if j%3:
   for k in range(5):
    a=k*math.tau/5;ellipse(p+V((math.cos(a)*.05,0,math.sin(a)*.05)),(0,1,0),.06,'StudyCream' if variant==0 else 'StudyRose')
 export('study_flower_mound_'+str(variant))
for i,objs in enumerate(all_objs):
 for obj in objs:obj.hide_set(False);obj.location=(i%4*12,i//4*12,0)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/source/lake_composition_study.blend'))
(OUT/'study_kit_manifest.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
print('STUDY_KIT',json.dumps(stats))
