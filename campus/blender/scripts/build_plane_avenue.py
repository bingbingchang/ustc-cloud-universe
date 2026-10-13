"""Extend the accepted ChatGPT sample into an independently authored 50 m avenue.

Reuse its glTF writer, beveled pavers, folded palm leaves and existing PNGs.
Tree scaffolds and the road layout below are authored for this longer scene.
"""
import ast
import json
import math
import shutil
from pathlib import Path
import numpy as np

CAMPUS = Path(__file__).resolve().parents[2]
REFERENCE = CAMPUS / 'references/threejs_road/original/campus_plane_tree_sample'
OUTPUT = CAMPUS / 'blender/avenue_study'
for folder in ('assets', 'textures', 'source', 'preview'):
    (OUTPUT / folder).mkdir(parents=True, exist_ok=True)
for image in (REFERENCE / 'textures').glob('*.png'):
    shutil.copy2(image, OUTPUT / 'textures' / image.name)

# Import pure building primitives without executing the old 8 x 8 m scene.
source = (REFERENCE / 'source/build_assets.py').read_text(encoding='utf-8')
tree = ast.parse(source)
definitions = [n for n in tree.body if isinstance(n, (ast.Import, ast.ImportFrom, ast.FunctionDef, ast.ClassDef))
               and not (isinstance(n, ast.ImportFrom) and n.module == 'scipy.ndimage')]
g = {'ROOT': OUTPUT, 'TAU': math.tau, '__name__': 'accepted_sample_primitives'}
exec(compile(ast.Module(body=definitions, type_ignores=[]), str(REFERENCE / 'source/build_assets.py'), 'exec'), g)
exec(source[source.index('outline=np.array'):source.index('TREE_SOURCE=[]') + len('TREE_SOURCE=[]')], g)
g['A'] = g['Asset']()
exec(source[source.index('M={}'):source.index("root=A.node('CampusAvenue")], g)
g['boxcache'] = {}
A, M = g['A'], g['M']
box, plane, tube, leaf_batch = (g[n] for n in ('box', 'plane', 'tube', 'leaf_batch'))
color, euler, quatmat, norm, spline = (g[n] for n in ('color', 'euler', 'quatmat', 'norm', 'spline'))
green, gold = g['palette_green'], g['palette_gold']
RNG = np.random.default_rng(20261012)
ROAD_WIDTH, WALK_WIDTH, VERGE_WIDTH, LENGTH = 7.2, 1.8, 1.75, 50.0
CURB = .16
WALK_INNER = ROAD_WIDTH / 2 + CURB
WALK_OUTER = WALK_INNER + WALK_WIDTH
TREE_X = WALK_OUTER + VERGE_WIDTH / 2
HALF_WIDTH = WALK_OUTER + VERGE_WIDTH

root = A.node('PlaneAvenue_50m', extras={'units': 'meters', 'length_m': LENGTH,
    'road_width_m': ROAD_WIDTH, 'clear_walkway_width_m': WALK_WIDTH,
    'source': 'campus/blender/scripts/build_plane_avenue.py'})
road = A.node('01_Road', root)
walk = A.node('02_ClearWalkways', root)
vegetation = A.node('03_PlaneTrees', root)
props = A.node('04_StreetFurniture', root)
details = A.node('05_GroundDetails', root)
box('Road_Substrate', road, [0, -.07, 0], [ROAD_WIDTH, .14, LENGTH], M['asphalt'], .012)
plane('Road_Surface', road, -ROAD_WIDTH/2, ROAD_WIDTH/2, -25, 25, .006, M['asphalt'], 1.05)

# Six deliberate stem silhouettes, with eight individual scaffold arrangements.
STEMS = [
    [[0,0,0],[-.10,.42,.04],[.04,1.6,.02],[.22,2.8,-.07],[.13,3.55,-.10]],
    [[0,0,0],[.11,.45,-.02],[.24,1.6,.11],[.14,2.85,.15],[-.03,3.6,.10]],
    [[0,0,0],[-.07,.4,.03],[-.29,1.5,-.03],[-.18,2.75,-.19],[.08,3.7,-.23]],
    [[0,0,0],[.06,.45,0],[-.02,1.45,.18],[.13,2.55,.33],[.32,3.45,.31]],
    [[0,0,0],[-.15,.42,-.02],[-.19,1.55,-.12],[-.04,2.8,-.03],[.18,3.65,.08]],
    [[0,0,0],[.03,.4,.07],[.15,1.45,-.05],[.29,2.65,-.27],[.15,3.5,-.30]],
]
# z, side, silhouette, height, five azimuths, five branch reaches, golden-leaf fraction
TREE_LAYOUT = [
    (-20.0,-1,0,12.7,[.1,2.55,4.4,5.5,1.4],[3.5,3.2,2.8,2.8,3.0],.18),
    (-17.2, 1,1,13.2,[3.1,.62,1.7,4.9,5.9],[3.7,3.1,2.5,3.3,2.8],.23),
    (-7.4,-1,2,12.2,[.35,2.9,4.25,5.7,1.6],[3.8,2.7,3.1,2.4,3.0],.16),
    (-4.0, 1,3,12.9,[2.8,.15,1.4,4.45,5.65],[3.4,3.5,3.1,2.7,2.8],.26),
    (6.0, -1,4,13.4,[.05,2.4,3.8,5.4,1.25],[3.9,3.4,2.7,3.0,2.5],.20),
    (9.4,  1,5,12.4,[3.25,.7,1.8,4.5,5.8],[3.7,2.8,3.0,3.4,2.5],.18),
    (18.4,-1,1,12.9,[.2,2.7,4.5,5.65,1.6],[3.6,3.1,2.7,3.1,2.9],.24),
    (21.5, 1,2,13.6,[3.0,.25,1.45,4.8,5.9],[3.9,3.4,2.9,3.0,2.6],.21),
]
TREE_RECIPES = []

for side in (-1, 1):
    name = 'L' if side < 0 else 'R'
    sidewalk = A.node('Walkway_'+name, walk)
    box('Walkway_Foundation_'+name, sidewalk, [side*(WALK_INNER+WALK_WIDTH/2),.057,0],
        [WALK_WIDTH,.14,LENGTH], M['grout'], .012)
    for i,z in enumerate(np.arange(-24.6,25,.8)):
        box(f'Curb_{name}_{i:03}', sidewalk, [side*(ROAD_WIDTH/2+CURB/2),.08,z], [.16,.20,.797], M['curb'], .012)
    # Six columns of full-size bricks. Nothing is stretched to fill the road.
    for row,z in enumerate(np.arange(-24.81,25,.39)):
        for column in range(6):
            x = side*(WALK_INNER+.15+column*.30)
            mat = M['pave'+str(RNG.choice(6,p=[.25,.20,.15,.15,.15,.10]))]
            box(f'Paver_{name}_{row:03}_{column}', sidewalk, [x,.135+RNG.uniform(-.001,.001),z], [.292,.029,.381], mat, .008)
    planting = A.node('PlantingVerge_'+name, vegetation)
    box('Verge_Base_'+name, planting, [side*TREE_X,.005,0], [VERGE_WIDTH,.25,LENGTH], M['soil'], .012)
    plane('Verge_Soil_'+name, planting, min(side*WALK_OUTER,side*HALF_WIDTH),max(side*WALK_OUTER,side*HALF_WIDTH),-25,25,.133,M['soil'],1.4)
    for i,z in enumerate(np.arange(-24.6,25,.8)):
        box(f'Verge_Edge_{name}_{i}', planting,[side*(HALF_WIDTH-.04),.13,z],[.08,.16,.797],M['curb'],.008)
    for i,z in enumerate(np.arange(-24.9,25,.20)):
        if RNG.random() < .04:
            continue
        box(f'EdgePaint_{name}_{i}',road,[side*(ROAD_WIDTH/2-.14),.01,z],[.075,.003,.185],M['line'],.001)

def make_tree(index, spec):
    z,side,form,height,angles,reaches,gold_ratio = spec
    label = f'{index+1:02}'
    rng = np.random.default_rng(12000+index*139)
    scale_y = height/11.4
    stem = np.array(STEMS[form],float)
    stem[:,1] *= scale_y
    stem[:,0] *= -side
    stem[:,2] += np.array([0,0,.04,-.09,.08])*(index%3-1)
    radius = .60 + (index%3-1)*.035
    parent = A.node('PlaneTree_'+label,vegetation,t=[side*TREE_X,.135,z],extras={'silhouette':form,'seed':12000+index*139,'authored_height_m':height})
    stem_group = A.node('TrunkAndRoots_'+label,parent)
    branch_group = A.node('ScaffoldBranches_'+label,parent)
    crown = A.node('Crown_'+label,parent)
    tube('Trunk_'+label,stem_group,stem,[radius,radius*.8,.40,.36,.31],M['trunk'+('A' if index%2==0 else 'B')],sub=10,sides=24,uvmode='trunk',seed=100+index)
    for j in range(8):
        a = j*math.tau/8+.25+index*.11
        end = np.array([math.cos(a)*.78,.008,math.sin(a)*.91])
        tube(f'Root_{label}_{j}',stem_group,[[0,.36,0],end*.45+[0,.10,0],end],[.23,.12,.016],M['bark'],sub=6,sides=12,seed=200+index*8+j)
    recipe={'id':label,'position':[side*TREE_X,.135,z],'silhouette':form,'stem':stem.tolist(),'primary_branches':[],'clusters':[]}
    clusters=[]
    for i,(angle,reach) in enumerate(zip(angles,reaches)):
        start = stem[3]*.35+stem[4]*.65
        start[1] -= .12*(i%3)
        direction = np.array([math.cos(angle),0,math.sin(angle)])
        cross = np.array([-math.sin(angle),0,math.cos(angle)])
        tip_y = height-.135-rng.uniform(.65,1.6)-(1.15 if i>=3 else 0)
        path=[]
        for k,t in enumerate([0,.21,.45,.70,1]):
            p = start+direction*reach*t+cross*(math.sin(t*math.pi)*(.35 if (i+index)%2 else -.29))
            p[1] = start[1]+(tip_y-start[1])*(t**.88)
            path.append(p)
        radii=np.array([.32 if i<3 else .255,.235,.145,.082,.023])*(1+rng.uniform(-.08,.09))
        tube(f'Branch_Primary_{label}_{i}',branch_group,path,radii,M['bark'],sub=8,sides=18 if i<3 else 14,seed=400+index*20+i)
        recipe['primary_branches'].append({'points':np.array(path).tolist(),'radii':radii.tolist()})
        centers, sampled_radii = spline(path,radii,8)
        for j,fraction in enumerate([.49,.72,.90]):
            origin=centers[int(fraction*(len(centers)-1))]
            a=angle+(-1 if j%2 else 1)*rng.uniform(.65,1.25)
            vector=np.array([math.cos(a)*rng.uniform(1.1,1.85),rng.uniform(.65,1.25),math.sin(a)*rng.uniform(1.1,1.85)])
            middle=origin+vector*.46+[0,-.12,0]
            end=origin+vector
            tube(f'Branch_Secondary_{label}_{i}_{j}',branch_group,[origin,middle,end],[.105,.059,.012],M['bark'],sub=6,sides=10,seed=800+index*30+i*4+j)
            clusters.append((end,rng.uniform(1.15,1.50),rng.uniform(.72,.98)))
            for twig in range(3):
                point=middle*.35+end*.65
                twig_angle=a+(twig-1)*1.13
                v=np.array([math.cos(twig_angle)*.85,.45,math.sin(twig_angle)*.85])
                tube(f'Twig_{label}_{i}_{j}_{twig}',branch_group,[point,point+v*.5+[0,.1,0],point+v],[.026,.015,.0025],M['bark'],sub=3,sides=6,seed=index*100+i*10+j*3+twig)
        clusters.append((np.array(path[-1]),1.17,.75))
    for i,(center,reach,depth) in enumerate(clusters):
        records=[]
        for _ in range(int(166+reach*51)):
            az=rng.uniform(0,math.tau)
            y=rng.uniform(-.94,.94)
            r=reach*rng.uniform(.10,1)**.38
            horizontal=math.sqrt(1-y*y)
            local=np.array([math.cos(az)*r*horizontal,y*depth,math.sin(az)*r*horizontal])
            rot=quatmat(euler(rng.uniform(-.88,.88),rng.uniform(0,math.tau),rng.uniform(-.85,.85)))
            palette=gold if rng.random()<gold_ratio else green
            c=color(palette[int(rng.integers(len(palette)))])*rng.uniform(.91,1.03)*(1 if y>-.1 else .91)
            records.append((local,rng.uniform(.23,.37),rot,c,rng.uniform(.3,.9)))
        mesh=leaf_batch(f'Geo_CrownClump_{label}_{i:02}',records,M['leaf'])
        A.node(f'CrownClump_{label}_{i:02}',crown,mesh,center,extras={'wind_amplitude':.012,'leaf_count':len(records)})
        recipe['clusters'].append({'center':center.tolist(),'leaf_count':len(records)})
    # Small grass blades cluster around roots rather than filling the path.
    centers=[]
    for _ in range(56):
        dx,dz=rng.uniform(-.75,.75),rng.uniform(-.88,.88)
        if math.hypot(dx,dz)>.57:
            centers.append([side*TREE_X+dx,.133,z+dz])
    A.node('Liriope_'+label,vegetation,g['grass_mesh']('Geo_Liriope_'+label,centers,rng))
    TREE_RECIPES.append(recipe)

for i,spec in enumerate(TREE_LAYOUT):
    make_tree(i,spec)

def make_bench(index,x,z,side):
    # Seat front is local +Z; turn both fronts toward the road and ground the feet.
    bench=A.node(f'Bench_{index:02}',props,t=[x,.133,z],q=euler(0,-side*math.pi/2,0))
    for i in range(4):box(f'Bench_SeatSlat_{index}_{i}',bench,[0,.44,-.20+i*.135],[1.50,.055,.115],M['wood'],.013)
    for i in range(3):box(f'Bench_BackSlat_{index}_{i}',bench,[0,.66+i*.14,-.275],[1.50,.10,.048],M['wood'],.012,q=euler(-.08,0,0))
    for x in [-.57,.57]:
        box('Bench_Leg',bench,[x,.225,.01],[.065,.45,.43],M['iron'],.01)
        box('Bench_BackSupport',bench,[x,.61,-.29],[.054,.60,.054],M['iron'],.007,q=euler(-.10,0,0))
        for z in [-.17,.19]:box('Bench_Screw',bench,[x,.471,z],[.015,.005,.015],M['bolt'],.002)
make_bench(1,-TREE_X,-.8,-1)
make_bench(2,TREE_X,14.5,1)
for i,(side,z) in enumerate([(1,-23),(-1,-12),(1,1),(-1,12),(1,24)]):
    lamp=A.node(f'Streetlight_{i:02}',props,t=[side*(WALK_OUTER+.32),.135,z])
    tube('Streetlight_Mast',lamp,[[0,0,0],[0,3.4,0],[0,4.5,0]],[.06,.046,.036],M['steel'],sub=3,sides=12)
    tube('Streetlight_Arm',lamp,[[0,4.13,0],[-side*.35,4.49,0],[-side*1.05,4.57,0]],[.033,.03,.025],M['steel'],sub=3,sides=12)
    box('Streetlight_Luminaire',lamp,[-side*1.05,4.54,0],[.70,.09,.21],M['steel'],.035)
    box('Streetlight_Diffuser',lamp,[-side*1.05,4.49,0],[.49,.015,.15],M['lamp'],.009)
    box('Streetlight_ServiceHatch',lamp,[0,.47,.059],[.075,.28,.026],M['iron'],.008)
for i,(side,z) in enumerate([(-1,-23),(1,-13),(-1,-3),(1,7),(-1,17),(1,24)]):
    drain=A.node(f'CurbDrain_{i:02}',props,t=[side*3.38,.018,z])
    box('Drain_DarkWell',drain,[0,-.024,0],[.30,.024,.55],M['iron'],.006)
    for x in [-.16,.16]:box('Drain_Frame',drain,[x,0,0],[.03,.025,.59],M['steel'],.004)
    for z0 in [-.28,.28]:box('Drain_Frame',drain,[0,0,z0],[.32,.025,.03],M['steel'],.004)
    for j in range(10):box('Drain_GrateBar',drain,[0,.006,-.245+j*.054],[.30,.018,.017],M['iron'],.003)
for i,(x,z) in enumerate([(-.84,-14.3),(1.12,11.8)]):
    cover=A.node(f'UtilityCover_{i}',props,t=[x,.011,z])
    tube('Cover_Disc',cover,[[0,-.013,0],[0,0,0]],[.25,.25],M['iron'],sub=2,sides=40)
    for j in range(-3,4):
        length=2*math.sqrt(max(0,.215**2-(j*.054)**2))
        box('Cover_Rib',cover,[0,.004,j*.054],[length,.006,.013],M['steel'],.001)

# Litter density follows the crowns and curbs; the middle stays comparatively clear.
cells={}
for i in range(4100):
    side=int(RNG.choice([-1,1]))
    if RNG.random()<.77:
        tree_z=float(RNG.choice([t[0] for t in TREE_LAYOUT if t[1]==side]))
        z=float(np.clip(RNG.normal(tree_z,3.1),-24.8,24.8))
        x=side*RNG.normal(3.43,.20) if RNG.random()<.78 else side*RNG.uniform(WALK_INNER+.1,HALF_WIDTH-.1)
    else:
        x,z=RNG.uniform(-3.45,3.45),RNG.uniform(-24.8,24.8)
    if min(math.hypot(x-t[1]*TREE_X,z-t[0]) for t in TREE_LAYOUT)<.57:
        continue
    rot=quatmat(euler(RNG.uniform(-.14,.14),RNG.uniform(0,math.tau),RNG.uniform(-.12,.12)))
    c=color(gold[int(RNG.integers(len(gold)))])*RNG.uniform(.85,1.03)
    size,curl=RNG.uniform(.12,.265),RNG.uniform(.5,1.9)
    # Fit each whole leaf to one ground surface instead of cutting through a step.
    base=g['leaf_base']
    footprint=np.column_stack([base[:,0],(base[:,0]**2*.24+base[:,1]**2*.30)*curl,base[:,1]])*size
    footprint[0,1]+=.033*size
    footprint=footprint@rot.T
    sign=1 if x>=0 else -1
    radial=footprint[:,0]*sign
    if abs(x)<WALK_INNER:
        inner,outer,height=0,ROAD_WIDTH/2,.006
    elif abs(x)<WALK_OUTER:
        inner,outer,height=WALK_INNER,WALK_OUTER,.151
    else:
        inner,outer,height=WALK_OUTER,HALF_WIDTH-.08,.133
    x=sign*np.clip(abs(x),inner-radial.min()+.003,outer-radial.max()-.003)
    y=height+.003-footprint[:,1].min()
    key=(int((x+HALF_WIDTH)//3),int((z+25)//5))
    cells.setdefault(key,[]).append(([x,y,z],size,rot,c,curl))
for (x,z),records in cells.items():
    A.node(f'LeafLitter_Cell_{x}_{z}',details,leaf_batch(f'Geo_LeafLitter_{x}_{z}',records,M['leaf']))

asset=A
asset.save(OUTPUT/'assets/plane_avenue_master.glb')
(OUTPUT/'source/tree_recipe.json').write_text(json.dumps(TREE_RECIPES,ensure_ascii=False,indent=2),encoding='utf-8')
triangles=sum(asset.j['accessors'][asset.j['meshes'][n['mesh']]['primitives'][0]['indices']]['count']//3 for n in asset.j['nodes'] if 'mesh' in n)
manifest={'asset_id':'PLANE_AVENUE_50M','length_m':LENGTH,'road_width_m':ROAD_WIDTH,'clear_walkway_width_m':WALK_WIDTH,
          'road_to_walkway_ratio':ROAD_WIDTH/WALK_WIDTH,'planting_verge_m':VERGE_WIDTH,'total_width_m':2*HALF_WIDTH,
          'trees':len(TREE_LAYOUT),'stem_silhouettes':len(STEMS),'tree_positions':[t['position'] for t in TREE_RECIPES],
          'source_reference':'Accepted ChatGPT campus avenue sample; original PNGs and primitive construction methods reused.',
          'dimensions_basis':'Design study, not a surveyed Tianshi Road reconstruction.',
          'stats':{'nodes':len(asset.j['nodes']),'unique_meshes':len(asset.j['meshes']),'materials':len(asset.j['materials']),
                   'embedded_images':len(asset.j['images']),'rendered_triangles':triangles,
                   'crown_leaves':sum(c['leaf_count'] for t in TREE_RECIPES for c in t['clusters']),
                   'ground_leaves':sum(len(v) for v in cells.values())}}
(OUTPUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')

# Simple independent collision proxies, with no foliage or brick-edge colliders.
C=g['Asset']()
cm=C.material('Collision_Debug','#80b2a0',1)
cr=C.node('PlaneAvenue_Collision')
def collider(name,p,size):
    x,y,z=np.array(size)/2
    vertices=[[-x,-y,-z],[x,-y,-z],[x,y,-z],[-x,y,-z],[-x,-y,z],[x,-y,z],[x,y,z],[-x,y,z]]
    faces=[[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,1,5],[0,5,4],[3,7,6],[3,6,2],[1,2,6],[1,6,5],[0,4,7],[0,7,3]]
    C.node(name+'-colonly',cr,C.mesh(name,vertices,faces,cm),p)
collider('Road',[0,-.094,0],[ROAD_WIDTH,.20,LENGTH])
for side in (-1,1):
    collider('Walkway_'+str(side),[side*(WALK_INNER+WALK_WIDTH/2),.065,0],[WALK_WIDTH,.17,LENGTH])
    collider('Curb_'+str(side),[side*(ROAD_WIDTH/2+CURB/2),.08,0],[CURB,.20,LENGTH])
    collider('Verge_'+str(side),[side*TREE_X,.05,0],[VERGE_WIDTH,.166,LENGTH])
for i,t in enumerate(TREE_LAYOUT):
    collider(f'Trunk_{i}',[t[1]*TREE_X,1.7,t[0]],[1.12,3.15,1.10])
collider('Bench_L',[-TREE_X,.633,-.8],[.58,1,1.5])
collider('Bench_R',[TREE_X,.633,14.5],[.58,1,1.5])
for i,(side,z) in enumerate([(1,-23),(-1,-12),(1,1),(-1,12),(1,24)]):
    collider(f'Lamp_{i}',[side*(WALK_OUTER+.32),2.35,z],[.13,4.5,.13])
C.save(OUTPUT/'assets/plane_avenue_collision.glb')

g['A']=g['Asset']()
g['boxcache']={}
stage=g['A']
sr=stage.node('PREVIEW_ONLY_Presentation')
base=stage.material('Preview_CutStone','#667166',.90)
trim=stage.material('Preview_ClayEdge','#ac9d7d',.94)
floor=stage.material('Preview_StudioFloor','#dbded2',1)
box('Presentation_StoneEdge',sr,[0,-.36,0],[2*HALF_WIDTH+.12,.38,LENGTH+.12],base,.065)
box('Presentation_ThinSedimentLayer',sr,[0,-.16,0],[2*HALF_WIDTH+.08,.055,LENGTH+.08],trim,.022)
plane('StudioFloor',sr,-250,250,-250,250,-.558,floor,.01)
stage.save(OUTPUT/'preview/presentation_stage.glb')
print(json.dumps(manifest,ensure_ascii=False,indent=2))
