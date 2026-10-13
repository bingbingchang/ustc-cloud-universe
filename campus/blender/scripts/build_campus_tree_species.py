"""Authored campus tree kit, metres, independent of the established campus assets.

Run with Blender --factory-startup -b --python this_file.py.
The palette and silhouette use the USTC campus photographs cited in the manifest.
Leaf silhouettes are geometry, with no alpha cards, texture downloads or old exports.
"""
from pathlib import Path
from collections import defaultdict
import bpy
import json
import math
import random
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'godot/assets'
SOURCE = ROOT / 'blender/source/campus_tree_species.blend'
PREVIEW = ROOT / 'renders/tree_species'
ASSETS.mkdir(parents=True, exist_ok=True)
PREVIEW.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

PALETTE = {
    'PlaneBark': (.40, .37, .27),
    'PlaneBarkPale': (.60, .57, .42),
    'PlaneBarkBrown': (.27, .25, .19),
    'PlaneLeaf': (.21, .34, .09),
    'PlaneLeafLight': (.30, .43, .14),
    'PlaneLeafDark': (.12, .24, .07),
    'ConiferBark': (.27, .22, .16),
    'ConiferLeaf': (.10, .23, .14),
    'ConiferLeafLight': (.17, .30, .18),
    'ConiferLeafDark': (.065, .16, .095),
    'GardenBark': (.31, .28, .20),
    'GardenLeaf': (.12, .28, .13),
    'GardenLeafLight': (.23, .36, .16),
    'GardenLeafDark': (.07, .18, .10),
}
MATERIALS = {}
for name, color in PALETTE.items():
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = .90 if 'Bark' in name else .76
    mat.use_backface_culling = False
    MATERIALS[name] = mat

groups = defaultdict(lambda: [[], []])
rng = random.Random()
records = {}
asset_objects = {}


def vec(p):
    return Vector(p)


def axes(normal):
    n = vec(normal).normalized()
    u = n.cross(vec((0, 1, 0)))
    if u.length < .02:
        u = n.cross(vec((1, 0, 0)))
    u.normalize()
    return u, n.cross(u).normalized()


def geo(points, faces, material):
    """Godot/Y-up coordinates to Blender/Z-up, before the GLB Y-up export."""
    verts, polys = groups[material]
    offset = len(verts)
    verts.extend((p[0], -p[2], p[1]) for p in points)
    polys.extend(tuple(offset + i for i in f) for f in faces)


def branch(points, radii, material, sides=8, mottled=False):
    points = [vec(p) for p in points]
    verts = []
    angle = rng.uniform(0, math.tau)
    for i, p in enumerate(points):
        tangent = points[min(i + 1, len(points) - 1)] - points[max(0, i - 1)]
        u, w = axes(tangent)
        for j in range(sides):
            a = angle + j * math.tau / sides
            # Very small irregular cross section, without a faceted low root block.
            r = radii[i] * (1 + .045 * math.sin(j * 2.3 + i * 1.4))
            verts.append(p + (u * math.cos(a) + w * math.sin(a)) * r)
    material_faces = defaultdict(list)
    for i in range(len(points) - 1):
        for j in range(sides):
            face = (i*sides+j, i*sides+(j+1)%sides,
                    (i+1)*sides+(j+1)%sides, (i+1)*sides+j)
            mat = material
            if mottled:
                mat = rng.choices(['PlaneBark', 'PlaneBarkPale', 'PlaneBarkBrown'],
                                  [5, 2, 1])[0]
            material_faces[mat].append(face)
    material_faces[material].extend([tuple(range(sides - 1, -1, -1)),
                tuple((len(points)-1)*sides+j for j in range(sides))])
    for mat, faces in material_faces.items():
        geo(verts, faces, mat)


def twig(a, b, radius, material, sides=6):
    a, b = vec(a), vec(b)
    mid = a.lerp(b, .52) + vec((rng.uniform(-.08, .08), .08, rng.uniform(-.08, .08)))
    branch([a, mid, b], [radius, radius*.61, max(.004, radius*.15)], material, sides)


def plane_leaf(p, normal, length, material):
    p = vec(p)
    n = vec(normal).normalized()
    u, w = axes(n)
    a = rng.uniform(0, math.tau)
    u, w = u*math.cos(a)+w*math.sin(a), -u*math.sin(a)+w*math.cos(a)
    # Palmately lobed leaf: central point, lateral lobes, not a generic oval.
    outline = [(-.04, -.44), (-.43, -.13), (-.26, .07), (-.46, .30),
               (-.16, .20), (0, .58), (.16, .20), (.46, .30),
               (.26, .07), (.43, -.13), (.04, -.44)]
    pts = [p + u*x*length + w*y*length - n*abs(x)*length*.075
           for x, y in outline]
    pts.append(p + n*length*.055)
    geo(pts, [((j+1) % len(outline), j, len(outline)) for j in range(len(outline))], material)


def garden_leaf(p, normal, length, material):
    p = vec(p)
    n = vec(normal).normalized()
    u, w = axes(n)
    a = rng.uniform(0, math.tau)
    u, w = u*math.cos(a)+w*math.sin(a), -u*math.sin(a)+w*math.cos(a)
    outline = [(0, -.54), (-.20, -.28), (-.27, 0), (-.18, .31),
               (0, .58), (.18, .31), (.27, 0), (.20, -.28)]
    pts = [p + u*x*length + w*y*length - n*abs(x)*length*.14 for x, y in outline]
    pts.append(p + n*length*.05)
    geo(pts, [((j+1) % 8, j, 8) for j in range(8)], material)


def leaf_cluster(center, scale, count, family):
    center = vec(center)
    for k in range(count):
        a = rng.uniform(0, math.tau)
        h = rng.uniform(-1, 1)
        r = rng.random()**.27
        ring = math.sqrt(1-h*h)
        offset = vec((math.cos(a)*ring*scale[0], h*scale[1], math.sin(a)*ring*scale[2]))*r
        normal = (offset.normalized() + vec((rng.uniform(-.6, .6), .72,
                                             rng.uniform(-.6, .6)))).normalized()
        mat = rng.choices([family+'Leaf', family+'LeafLight', family+'LeafDark'], [6, 2, 2])[0]
        if family == 'Plane':
            plane_leaf(center + offset, normal, rng.uniform(.32, .51), mat)
        else:
            garden_leaf(center + offset, normal, rng.uniform(.31, .49), mat)


def roots(trunk_radius, material):
    for j in range(7):
        a = j * math.tau / 7 + rng.uniform(-.12, .12)
        d = vec((math.cos(a), 0, math.sin(a)))
        branch([d*trunk_radius*.48+vec((0,.65,0)),
                d*trunk_radius*1.55+vec((0,.17,0)),
                d*trunk_radius*2.5+vec((0,.018,0))],
               [trunk_radius*.38, trunk_radius*.20, .015], material, 7)


def export(name, family, note, clear_height):
    objs = []
    triangle_count = 0
    points_yup = []
    for mat, (verts, faces) in groups.items():
        if not verts:
            continue
        # Only vertices used by faces are retained; branch surfaces are grouped by material.
        used = sorted({j for f in faces for j in f})
        lookup = {j:i for i,j in enumerate(used)}
        compact = [verts[j] for j in used]
        faces = [tuple(lookup[j] for j in f) for f in faces]
        mesh = bpy.data.meshes.new(name+'_'+mat)
        mesh.from_pydata(compact, [], faces)
        mesh.materials.append(MATERIALS[mat])
        mesh.update()
        for poly in mesh.polygons:
            poly.use_smooth = 'Bark' in mat
        obj = bpy.data.objects.new(name+'_'+mat, mesh)
        bpy.context.collection.objects.link(obj)
        objs.append(obj)
        triangle_count += sum(len(f)-2 for f in faces)
        points_yup.extend((p[0], p[2], -p[1]) for p in compact)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=str(ASSETS/(name+'.glb')), export_format='GLB',
                              use_selection=True, export_yup=True, export_materials='EXPORT')
    lo = [min(p[k] for p in points_yup) for k in range(3)]
    hi = [max(p[k] for p in points_yup) for k in range(3)]
    records[name] = {
        'family': family, 'description': note,
        'triangles': triangle_count, 'mesh_surfaces': len(objs),
        'bounds_godot_m': {'min': [round(x, 3) for x in lo], 'max': [round(x, 3) for x in hi]},
        'dimensions_m': [round(hi[k]-lo[k], 3) for k in range(3)],
        'canopy_clearance_m': clear_height,
        'materials': list(groups),
        'collision': 'Clip real Bark mesh below 2.4 m, using existing low_trunk_shape().',
        'lod_suggestion': {'lod0_m': 32, 'lod1_m': 75, 'lod2_m': 160,
                           'triangle_ratios': [1.0, .50, .20],
                           'notes': 'Keep trunk and major forks; use mesh LOD with existing spatial MultiMesh batches.'},
    }
    asset_objects[name] = objs
    for obj in objs:
        obj.hide_set(True)
    groups.clear()


def build_plane(variant):
    rng.seed(20111024 + variant*873)
    height = [14.6, 15.3, 13.4][variant]
    radius = [.47, .53, .43][variant]
    clearance = [5.2, 5.6, 4.9][variant]
    lean = vec(([.32,-.22,.14][variant],0,[.16,.12,-.20][variant]))
    stem = [vec((0,0,0)), lean*.1+vec((0,.7,0)), lean*.32+vec((0,2.2,0)),
            lean*.8+vec((0,clearance-.4,0)), lean+vec((0,clearance+1.1,0))]
    roots(radius, 'PlaneBark')
    branch(stem, [radius*1.17, radius, radius*.91, radius*.76, radius*.64],
           'PlaneBark', 12, True)
    count_main = [8, 9, 7][variant]
    for j in range(count_main):
        angle = j*math.tau/count_main + rng.uniform(-.28, .28) + variant*.63
        d = vec((math.cos(angle), 0, math.sin(angle)))
        side = vec((-d.z, 0, d.x))
        reach = rng.uniform(3.2, 4.7) * [1.0, 1.12, .97][variant]
        crown_h = height - rng.uniform(1.2, 3.2)
        start = stem[3].lerp(stem[4], rng.uniform(.15, .85))
        elbow = start + d*reach*.40 + vec((0,1.7,0))
        end = d*reach + lean + vec((0,crown_h,0))
        branch([start, start.lerp(elbow,.5)+side*.13, elbow,
                elbow.lerp(end,.5)+side*rng.uniform(-.3,.3), end],
               [radius*.44, radius*.34, radius*.24, .085, .027], 'PlaneBark', 9, True)
        for k in range(7):
            t = .30 + k*.108
            base = elbow.lerp(end,t)
            tip = base + side*((-1 if k%2 else 1)*rng.uniform(.72,1.4))
            tip += d*rng.uniform(.28,.73) + vec((0,rng.uniform(.3,.96),0))
            twig(base,tip,rng.uniform(.036,.06),'PlaneBark',6)
            leaf_cluster(tip,(1.07, .79, 1.14),21,'Plane')
            for l in range(2):
                shoot = tip+vec((rng.uniform(-.6,.6),rng.uniform(-.05,.7),rng.uniform(-.6,.6)))
                twig(tip,shoot,.015,'PlaneBark',5)
        leaf_cluster(end,(1.3,.94,1.3),40,'Plane')
    # Tall inner forks fill the upper central crown, with uneven leaders.
    for j in range(3):
        a = j*math.tau/3 + variant*.83
        end = vec((math.cos(a)*rng.uniform(.8,1.7), height-.72,
                   math.sin(a)*rng.uniform(.8,1.7))) + lean
        branch([stem[4], stem[4].lerp(end,.52)+vec((.15,0,-.1)), end],
               [radius*.28,.06,.017], 'PlaneBark',7)
        leaf_cluster(end,(1.53,.86,1.52),75,'Plane')
        leaf_cluster(end-vec((0,1.4,0)),(1.15,.68,1.15),40,'Plane')
    export('tree_plane_'+['a','b','c'][variant], 'mature plane / campus 梧桐',
           'Tall roadside tree, mottled bark, high forks and palmately lobed real mesh leaves. '
           'Uneven broad crown; not clipped spherical topiary.',clearance)


def needle_spray(center, direction, length, material):
    center, direction = vec(center), vec(direction).normalized()
    side = direction.cross(vec((0,1,0))).normalized()
    if side.length < .01:
        side = vec((1,0,0))
    up = side.cross(direction).normalized()
    for k in range(3):
        base = center + direction*(k/3-.5)*length*.55
        for sign in [-1,1]:
            end = base + direction*length*.50 + side*length*.42*sign + up*rng.uniform(-.18,.12)
            width = (direction*.60+up*.80)*length*.12
            # Each opaque tapered blade stands for a small group of cedar needles;
            # the six spreading blades give the shelf a volume without alpha overdraw.
            geo([base-width, base+width, end],[(0,1,2)],material)


def build_conifer():
    rng.seed(531942)
    height = 13.3
    roots(.40,'ConiferBark')
    branch([(0,0,0),(.07,1.7,.02),(.12,5.8,.02),(.05,9.5,.08),(0,height,0)],
           [.47,.36,.26,.13,.012],'ConiferBark',11)
    for tier in range(10):
        y = 3.05 + tier*.91
        reach = (1-tier/11)*3.75 + .38
        arms = 7 if tier < 7 else 6
        for j in range(arms):
            a = j*math.tau/arms+tier*.52+rng.uniform(-.16,.16)
            d = vec((math.cos(a),0,math.sin(a)))
            side = vec((-d.z,0,d.x))
            end = d*reach*rng.uniform(.83,1.14)+vec((.05,y-.30,0))
            start = vec((.08,y,0))
            middle = start.lerp(end,.52)+vec((0,.14,0))
            twig(start,middle,.095*(1-tier*.067),'ConiferBark',7)
            twig(middle,end,.045*(1-tier*.067),'ConiferBark',6)
            # Flat, wide horizontal shelves; no opaque cone used for crown volume.
            for k in range(5):
                base = start.lerp(end,.2+k*.17)
                width = reach*.32*(1-k*.055)
                for sign in [-1,1]:
                    tip = base+side*width*sign+d*.14+vec((0,rng.uniform(-.18,.13),0))
                    branch([base,tip],[.016,.004],'ConiferBark',4)
                    for n in range(3):
                        t = n/2
                        center = base.lerp(tip,t)+d*rng.uniform(-.11,.12)
                        mat = rng.choices(['ConiferLeaf','ConiferLeafLight','ConiferLeafDark'],[6,2,2])[0]
                        needle_spray(center,side*sign+d*.5+vec((0,.07,0)),rng.uniform(.48,.70),mat)
            needle_spray(end,d,.52,'ConiferLeafLight')
    for j in range(30):
        y = rng.uniform(11.1,13.15)
        a = rng.uniform(0,math.tau)
        d = vec((math.cos(a),.2,math.sin(a)))
        needle_spray(vec((0,y,0))+d*.13,d,.31,'ConiferLeaf')
    export('tree_conifer','cedar / fir type evergreen',
           'Dark conifer with single leader, layered horizontal branches and geometric needle sprays. '
           'Snow cedar is documented beside First Teaching Hall; this is a general asset silhouette.',2.8)


def build_garden():
    rng.seed(831944)
    radius = .30
    stem = [vec((0,0,0)), vec((.07,1.1,.02)), vec((.04,2.6,-.06)),vec((.23,4.2,-.05))]
    roots(radius,'GardenBark')
    branch(stem,[.36,.29,.23,.16],'GardenBark',10)
    for j in range(9):
        a = j*math.tau/9+rng.uniform(-.21,.21)
        d = vec((math.cos(a),0,math.sin(a)))
        side = vec((-d.z,0,d.x))
        height = rng.uniform(6.7,8.4)
        start = stem[2].lerp(stem[3],rng.uniform(0,1))
        end = d*rng.uniform(2.0,3.15)+vec((0,height,0))
        mid = start.lerp(end,.55)+vec((0,.45,0))
        branch([start,mid,end],[.13,.058,.015],'GardenBark',8)
        for k in range(6):
            base = mid.lerp(end,.15+k*.15)
            tip = base+side*((-1 if k%2 else 1)*rng.uniform(.45,.85))+vec((0,.25,0))
            twig(base,tip,.031,'GardenBark',6)
            leaf_cluster(tip,(.83,.74,.87),36,'Garden')
        leaf_cluster(end,(.98,.76,.98),63,'Garden')
    leaf_cluster((.15,8.42,-.05),(1.25,.78,1.3),200,'Garden')
    branch([stem[3],(.15,6.4,-.05),(.15,8.42,-.05)],[.13,.035,.01],'GardenBark',7)
    export('tree_garden','garden evergreen broadleaf / magnolia type',
           'Lower, broad asymmetric garden crown, leathery oval real mesh leaves. '
           'Magnolia and loquat are documented in Guo Moruo Square; the asset uses magnolia-type leaves.',2.7)


for variant in range(3):
    build_plane(variant)
build_conifer()
build_garden()

# Editable board: exports were made at local origin, before objects are spaced.
positions = [-23,-11,1,13,24]
for i,(name,objs) in enumerate(asset_objects.items()):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    for obj in objs:
        obj.hide_set(False)
        obj.location = (positions[i],0,0)
        for old in list(obj.users_collection):
            old.objects.unlink(obj)
        collection.objects.link(obj)

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 1400
scene.render.resolution_y = 470
scene.render.resolution_percentage = 100
scene.world.color = (.7,.7,.7)
scene.world.use_nodes = True
scene.world.node_tree.nodes.get('Background').inputs['Color'].default_value = (.78,.85,.92,1)
scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value = .8
scene.view_settings.view_transform = 'AgX'

bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.028))
floor = bpy.context.object
floor.name = 'PreviewGround_ExcludeFromExports'
mat = bpy.data.materials.new('PreviewStone')
mat.diffuse_color = (.53,.57,.48,1)
mat.use_nodes = True
mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (.53,.57,.48,1)
mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = 1
floor.data.materials.append(mat)
bpy.ops.object.light_add(type='SUN',location=(0,-15,25))
sun = bpy.context.object
sun.name = 'PreviewSun_ExcludeFromExports'
sun.rotation_euler = (math.radians(25),math.radians(-28),math.radians(-30))
sun.data.energy = 2.3
sun.data.angle = math.radians(7)
bpy.ops.object.camera_add(location=(.5,-52,14.8))
camera = bpy.context.object
camera.name = 'PreviewCamera_ExcludeFromExports'
camera.rotation_euler = (Vector((.5,0,7.1))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 61
scene.camera = camera
scene.render.filepath = str(PREVIEW/'tree_species_board.png')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
bpy.ops.render.render(write_still=True)

# First-person-scale view of the mature plane fork and leaves.
for name,objs in asset_objects.items():
    for obj in objs:
        obj.hide_render = name != 'tree_plane_a'
camera.data.type = 'PERSP'
camera.data.lens = 45
camera.location = (-20.5,-12.5,2.05)
camera.rotation_euler = (Vector((-23,0,8.9))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x = 780
scene.render.resolution_y = 720
scene.render.filepath = str(PREVIEW/'plane_tree_close.png')
bpy.ops.render.render(write_still=True)

manifest = {
    'units': 'metres', 'export_axes': 'Godot/glTF Y-up',
    'source': str(SOURCE.relative_to(ROOT)),
    'references': [
        {'url':'https://business.ustc.edu.cn/2011/1026/c28419a526436/page.htm',
         'observations':'Official campus photo captions: tall snow cedars below First Teaching Hall; '
                        'plane leaves; tall golden-rain trees beside Guo Moruo Road.'},
        {'url':'https://ef.ustc.edu.cn/info/1061/2005.htm',
         'observations':'Official tree locations: plane north of First Teaching Hall; magnolia and '
                        'loquat in Guo Moruo Square; camphor at Glasses Lake; pine beside USTC1958.'},
        {'local':'references/buildings/东区郭沫若广场.jpg',
         'url':'https://sz.ustc.edu.cn/wdxz_show/61.html',
         'observations':'Mature irregular broad crowns behind clipped shrubs, tall tiered conifers; '
                        'larger trees flank both sides of the plaza.'},
        {'local':'references/buildings/teaching_north.jpg',
         'observations':'High plane-tree trunks, widely spaced roadside planting, visible large forks.'},
    ],
    'geometry':'Original procedural opaque 3D leaf silhouettes, branches and flared roots. '
               'Asset species and sizes convey the referenced types; placement is performed by the scene module.',
    'assets': records,
}
(ASSETS/'campus_tree_species_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('CAMPUS_TREE_SPECIES_COMPLETE',json.dumps({k:v['triangles'] for k,v in records.items()}))
