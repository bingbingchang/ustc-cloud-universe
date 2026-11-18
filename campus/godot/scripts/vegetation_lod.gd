extends RefCounted
## Pair each near batch with the same placements and bounds in its far batch.

const Impostor = preload("res://shaders/detail_impostor.gdshader")


static func groups(world: Node3D, assets: Dictionary, includes: Callable) -> Array:
	var batches := {}
	for node in world.get_children():
		if not node is MultiMeshInstance3D or not node.has_meta("render_placements"):
			continue
		var asset := str(node.get_meta("render_asset", ""))
		if not assets.has(asset) or not includes.call(asset):
			continue
		var placements: Array = node.get_meta("render_placements")
		var key := [asset, placements]
		if not batches.has(key):
			batches[key] = {"asset": asset, "placements": placements, "near": []}
		batches[key].near.append(node)
	return batches.values()


static func atlas_quad(spec: Dictionary, meshes: Dictionary, shader: Shader = Impostor) -> QuadMesh:
	var path: String = spec.texture
	if not meshes.has(path):
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("atlas", load(path))
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * float(spec.size)
		quad.material = material
		meshes[path] = quad
	return meshes[path]


static func impostor_batch(spec: Dictionary, placements: Array, quad: QuadMesh) -> MultiMeshInstance3D:
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_custom_data = true
	mesh.mesh = quad
	mesh.instance_count = placements.size()
	var center := Vector3(spec.center[0], spec.center[1], spec.center[2])
	var bounds := AABB()
	for i in placements.size():
		var placement: Transform3D = placements[i]
		var scale := placement.basis.get_scale()
		var position := placement * center
		var size := maxf(scale.x, scale.z)
		mesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(size, scale.y, 1)), position))
		mesh.set_instance_custom_data(i, Color(placement.basis.orthonormalized().get_euler().y, 0, 0, 1))
		# The quad can face a raised camera as well as rotate horizontally.
		var radius := float(spec.size) * maxf(size, scale.y) * .71
		var box := AABB(position - Vector3.ONE * radius, Vector3.ONE * (2.0 * radius))
		bounds = box if i == 0 else bounds.merge(box)
	mesh.custom_aabb = bounds
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


static func pair(far: MultiMeshInstance3D, near: Array, distance: float, limit: float, margin: float, blend_half_width: float = 0.0) -> void:
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		blend_half_width = 0.0
	var bounds := AABB()
	for i in near.size():
		var source: MultiMeshInstance3D = near[i]
		var box := source.global_transform * source.get_aabb()
		bounds = box if i == 0 else bounds.merge(box)
	var center := bounds.get_center()
	var far_bounds := far.multimesh.custom_aabb
	var half_size := (far_bounds.position - center).abs().max((far_bounds.end - center).abs())
	far.custom_aabb = AABB(center - half_size, half_size * 2.0)
	far.set_meta("paired_vegetation_lod", true)
	# Godot fades symmetrically around the range boundary. Both representations
	# must measure from the same center and use the same margin.
	far.visibility_range_begin = distance if blend_half_width > 0.0 else distance + .0001
	far.visibility_range_begin_margin = blend_half_width
	far.visibility_range_end = limit
	far.visibility_range_end_margin = margin
	far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for source: MultiMeshInstance3D in near:
		source.custom_aabb = source.global_transform.affine_inverse() * bounds
		source.set_meta("paired_vegetation_lod", true)
		source.visibility_range_end = distance
		source.visibility_range_end_margin = blend_half_width
		source.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if blend_half_width > 0.0 else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


static func adapt_baked_pair(node: GeometryInstance3D) -> void:
	# The Web baker can run on Forward+. Compatibility cannot blend visibility
	# ranges: restore the coincident switch, or both opaque trees would draw.
	if not node.get_meta("paired_vegetation_lod", false):
		return
	if node.visibility_range_begin_margin > 0.0:
		node.visibility_range_begin += .0001
		node.visibility_range_begin_margin = 0.0
	elif node.visibility_range_begin == 0.0 and node.visibility_range_end_margin > 0.0:
		node.visibility_range_end_margin = 0.0
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
