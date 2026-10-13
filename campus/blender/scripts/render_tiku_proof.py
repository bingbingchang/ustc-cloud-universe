"""Render the exported character's actual Blender geometry in a neutral studio.

Run with Blender --background --factory-startup --python-exit-code 1 --python
this_file.py [-- --uniform].  The source .blend is opened read-only in practice:
all studio changes are in memory and this script never saves a .blend file.
"""

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
UNIFORM = "--uniform" in ARGS
ASSET = "tiku_boy1_uniform" if UNIFORM else "tiku_boy1"
SOURCE = ROOT / "blender" / "source" / (ASSET + ".blend")
OUT = ROOT / "renders" / "tiku_identity" / ("blender_uniform" if UNIFORM else "blender")


def gpoint(x, y, z):
    """The production helper maps Godot's Y-up coordinates into Blender Z-up."""
    return Vector((x, -z, y))


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def hide_hierarchy(obj):
    obj.hide_render = True
    for child in obj.children_recursive:
        child.hide_render = True


def area_light(name, location, target, power, color, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = power
    data.color = color
    data.shape = "DISK"
    data.size = size
    data.use_shadow = True
    if hasattr(data, "use_shadow_jitter"):
        data.use_shadow_jitter = True
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    aim(obj, target)
    return obj


if not SOURCE.is_file():
    raise FileNotFoundError("Build the production model before rendering: " + str(SOURCE))
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene

# Restrict the studio to the actual production character, not newly modelled
# render-only facial parts.  Uniform exports may use a distinct root label.
root = bpy.data.objects.get("TikuBoy01") or bpy.data.objects.get("TikuBoy01Uniform")
if root is None:
    root = next((o for o in scene.objects if o.type == "EMPTY" and o.parent is None
                 and any(c.name == "Tiku_Head" for c in o.children_recursive)), None)
if root is None:
    raise RuntimeError("No Tiku character root with Tiku_Head exists in " + str(SOURCE))
character_objects = {root, *root.children_recursive}
for obj in list(scene.objects):
    if obj not in character_objects:
        obj.hide_render = True
for obj in character_objects:
    obj.hide_render = False
    if obj.type == "EMPTY" and obj.name.startswith("Tiku_"):
        obj.rotation_mode = "XYZ"
        obj.rotation_euler = (0, 0, 0)
for name in ("Tiku_Book", "Tiku_Pen"):
    obj = bpy.data.objects.get(name)
    if obj:
        hide_hierarchy(obj)

bpy.context.view_layer.update()
depsgraph = bpy.context.evaluated_depsgraph_get()
vertices = []
for obj in character_objects:
    if obj.type == "MESH" and not obj.hide_render:
        evaluated = obj.evaluated_get(depsgraph)
        vertices.extend(evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box)
if not vertices:
    raise RuntimeError("Character contains no visible production meshes")
z_min = min(v.z for v in vertices)
z_max = max(v.z for v in vertices)
height = z_max - z_min
center = Vector((root.matrix_world.translation.x, root.matrix_world.translation.y,
                 (z_min + z_max) * 0.5))

# Blender 5.2 calls the engine BLENDER_EEVEE; retain a fallback for older sources.
engines = {x.identifier for x in scene.render.bl_rna.properties["engine"].enum_items}
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
if hasattr(scene, "eevee"):
    eevee = scene.eevee
    for key, value in (("taa_render_samples", 192), ("use_shadows", True),
                       ("shadow_ray_count", 3), ("shadow_step_count", 12),
                       ("use_raytracing", True)):
        if hasattr(eevee, key):
            setattr(eevee, key, value)
scene.render.resolution_x = 1200
scene.render.resolution_y = 1500
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "8"
scene.render.film_transparent = False
scene.render.use_file_extension = True
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "None"
scene.view_settings.exposure = 0.0
scene.view_settings.gamma = 1.0
scene.use_nodes = False

world = bpy.data.worlds.new("Tiku proof | neutral studio")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.70, 0.76, 0.82, 1.0)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35
scene.world = world

bpy.ops.mesh.primitive_plane_add(size=200, location=(center.x, center.y, z_min - 0.003))
ground = bpy.context.object
ground.name = "PROOF_ONLY_WarmGreyFloor"
floor_mat = bpy.data.materials.new("PROOF_ONLY_WarmGrey")
floor_mat.use_nodes = True
bsdf = floor_mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (0.50, 0.48, 0.44, 1)
bsdf.inputs["Roughness"].default_value = 0.95
ground.data.materials.append(floor_mat)

area_light("PROOF_Key", center + Vector((-2.5, 3.0, 3.0)), center,
           420, (1.0, 0.91, 0.80), 3.0)
area_light("PROOF_SkyFill", center + Vector((2.3, 1.0, 1.4)), center,
           180, (0.78, 0.86, 1.0), 3.5)
area_light("PROOF_Rim", center + Vector((1.5, -2.0, 2.0)), center,
           220, (1.0, 0.94, 0.85), 2.5)

camera_data = bpy.data.cameras.new("PROOF_Camera")
camera_data.type = "ORTHO"
camera_data.clip_start = 0.01
camera_data.clip_end = 300
camera = bpy.data.objects.new("PROOF_Camera", camera_data)
bpy.context.collection.objects.link(camera)
scene.camera = camera

head = bpy.data.objects.get("Tiku_Head")
head_pos = head.matrix_world.translation
face_target = head_pos + gpoint(0, 0.135, -0.015)
full_scale = height * 1.17
shots = [
    ("01_front", center, gpoint(0, 0.025, -1), full_scale),
    ("02_three_quarter", center, gpoint(-0.57, 0.055, -0.82), full_scale),
    ("03_side", center, gpoint(-1, 0.025, 0), full_scale),
    ("04_face_front", face_target, gpoint(0, 0.025, -1), 0.49),
    ("05_face_three_quarter", face_target, gpoint(-0.52, 0.04, -0.85), 0.49),
]
manifest = {
    "source": str(SOURCE), "source_saved": False,
    "engine": scene.render.engine, "resolution": [1200, 1500],
    "color_management": "AgX / None / exposure 0",
    "asset_height_m": round(height, 5),
    "notes": "Production source geometry and materials; neutral studio, rest pose, book and pen hidden.",
    "shots": [],
}
for name, target, direction, scale in shots:
    camera.location = target + direction.normalized() * 4.5
    camera_data.ortho_scale = scale
    aim(camera, target)
    scene.render.filepath = str(OUT / (name + ".png"))
    bpy.ops.render.render(write_still=True)
    manifest["shots"].append({
        "name": name, "path": scene.render.filepath,
        "camera_blender": list(camera.location), "target_blender": list(target),
        "orthographic_vertical_scale_m": scale,
    })
    print("TIKU_BLENDER_PROOF_SHOT " + name, flush=True)
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print("TIKU_BLENDER_PROOF_OK " + ASSET + " " + str(len(shots)), flush=True)
