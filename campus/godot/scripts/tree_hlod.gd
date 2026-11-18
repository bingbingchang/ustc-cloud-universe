extends Node
## Baked from the original meshes, with original collision bodies left in place.
const VegetationLOD = preload("res://scripts/vegetation_lod.gd")
const TreeAtlas = preload("res://shaders/tree_atlas_blend.gdshader")
const TREE_BLEND_HALF_WIDTH := 4.0
var game
var atlas_meshes := {}
var mirror_groups={}
var shadow_groups={}
var shadow_materials=[]
var last_shadow_camera=Vector3.INF
var footprint_materials: Array[ShaderMaterial] = []
var last_shadow_limits := Vector2.INF

func _ready():
	var path="res://assets/runtime_hlod/manifest.json"
	if not FileAccess.file_exists(path):return
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(path))
	var groups := VegetationLOD.groups(game.world, manifest.assets, get_parent().is_tree)
	var seen := {}
	# Reflection cards keep their cheaper single-view shader and separate cache.
	var main_view_meshes := {}
	for index in groups.size():
		var group: Dictionary = groups[index]
		var asset: String = group.asset
		var spec: Dictionary = manifest.assets[asset]
		var quad := VegetationLOD.atlas_quad(spec, main_view_meshes, TreeAtlas)
		var impostor := VegetationLOD.impostor_batch(spec, group.placements, quad)
		impostor.name = "SakuraFar_%d" % index
		VegetationLOD.pair(impostor, group.near, 27.0 if asset.begins_with("sakura") else 39.0, 420.0, 12.0, TREE_BLEND_HALF_WIDTH)
		game.world.add_child(impostor)
		for node: MultiMeshInstance3D in group.near:
			node.layers &= ~game.REFLECTION_LAYER
			node.set_meta("runtime_hlod", true)
		for placement: Transform3D in group.placements:
			var key := [asset, placement]
			if seen.has(key):
				continue
			seen[key] = true
			_add_reflection_and_shadow(asset, spec, placement, quad.size)
	build_mirror_batches()
	build_shadow_batches()
	print("TREE_HLOD_READY trees=",seen.size()," far_batches=",groups.size(),
		" reflection_batches=",mirror_groups.size()," shadow_batches=",shadow_groups.size())

func _add_reflection_and_shadow(asset: String, spec: Dictionary, tr: Transform3D, size: Vector2) -> void:
	var cell := Vector2i(floori(tr.origin.x / 64), floori(tr.origin.z / 64))
	var mirror_key := [asset, cell]
	if not mirror_groups.has(mirror_key):
		mirror_groups[mirror_key] = {"spec": spec, "placements": []}
	mirror_groups[mirror_key].placements.append(tr)
	# Keep textured canopy shadows without redrawing the full source mesh.
	var local_sun: Vector3 = tr.basis.orthonormalized().inverse() * game.sun.global_basis.z
	var yaw := posmod(roundi(atan2(local_sun.x, local_sun.z) * 8.0 / TAU), 8)
	if not shadow_groups.has(asset):
		shadow_groups[asset] = {"spec": spec, "items": []}
	var center := tr * Vector3(spec.center[0], spec.center[1], spec.center[2])
	var scale := tr.basis.get_scale()
	shadow_groups[asset].items.append({"center": center, "ground_y": tr.origin.y,
		"size": size * Vector2(maxf(scale.x, scale.z), scale.y), "yaw": yaw})

func _process(_delta):
	var camera=game.get_viewport().get_camera_3d()
	var limits := Vector2(game.sun.directional_shadow_fade_start, game.sun.directional_shadow_max_distance)
	if last_shadow_limits != limits:
		last_shadow_limits = limits
		for material in footprint_materials:
			material.set_shader_parameter("shadow_handoff", Vector2(limits.x * limits.y, limits.y))
	if not camera or camera.global_position.distance_to(last_shadow_camera)<.25:return
	last_shadow_camera=camera.global_position
	for material in shadow_materials:material.set_shader_parameter("main_camera",last_shadow_camera)

func build_shadow_batches():
	var light: Vector3 = game.sun.global_basis.z.normalized()
	# Match the atlas camera looking from the sun towards the canopy.
	var basis := Basis.looking_at(-light, Vector3.UP if absf(light.y)<.999 else Vector3.FORWARD)
	var water := preload("res://scripts/tree_ground_shadows.gd").water_surfaces(game.world)
	for group in shadow_groups.values():
		var material=ShaderMaterial.new();material.shader=preload("res://shaders/tree_shadow_impostor.gdshader")
		material.set_shader_parameter("atlas",load(group.spec.texture));shadow_materials.append(material)
		var mesh=QuadMesh.new();mesh.size=Vector2.ONE;mesh.material=material
		var batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_custom_data=true
		batch.mesh=mesh;batch.instance_count=group.items.size()
		var bounds=AABB();var first=true
		for index in group.items.size():
			var item=group.items[index];var tr=Transform3D(basis*Basis.from_scale(Vector3(item.size.x,item.size.y,1)),item.center)
			batch.set_instance_transform(index,tr);batch.set_instance_custom_data(index,Color(item.yaw,0,0,1))
			var box=tr*mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
		batch.custom_aabb=bounds
		var node=MultiMeshInstance3D.new();node.name="TreeCanopyShadowBatch";node.multimesh=batch
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		node.set_meta("runtime_camera_shadow",true);game.world.add_child(node)
	if light.y > .15 and not shadow_groups.is_empty():
		var ground_material := preload("res://scripts/tree_ground_shadows.gd").add_batches(
			game.world, shadow_groups, basis, light, water, game.sun)
		footprint_materials.append(ground_material)

func build_mirror_batches():
	var groups := mirror_groups.values()
	for index in groups.size():
		var group: Dictionary = groups[index]
		var spec: Dictionary = group.spec
		var quad := VegetationLOD.atlas_quad(spec, atlas_meshes)
		var mirror := VegetationLOD.impostor_batch(spec, group.placements, quad)
		mirror.name = "TreeReflectionBatch_%d" % index
		mirror.layers = game.REFLECTION_LAYER
		mirror.visibility_range_end = 420.0
		game.world.add_child(mirror)
