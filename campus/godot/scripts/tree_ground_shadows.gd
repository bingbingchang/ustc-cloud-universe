extends RefCounted
## Bound the cost to shallow instanced boxes. The shader reads the actual
## receiving surface; no coplanar quads, extra lights or per-frame physics.
const ROWS := "res://assets/runtime_hlod/canopy_shadow_rows.json"
const TEXTURE := "res://assets/runtime_hlod/canopy_shadow_coverage.png"
const PROJECTION = preload("res://shaders/tree_ground_shadow.gdshader")
const HALF_HEIGHT := 1.35
const CELL := 144.0

static func water_surfaces(world: Node3D) -> Array[AABB]:
	var result: Array[AABB] = []
	for node in world.get_children():
		if node is MeshInstance3D and node.visible and (node.get_meta("lake_water",false) or str(node.name).begins_with("NorthWater")):
			result.append(node.global_transform * node.get_aabb())
	return result

static func add_batches(world: Node3D, groups: Dictionary, sun_basis: Basis, light: Vector3, water: Array[AABB], sun: DirectionalLight3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PROJECTION
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(ROWS))
	material.set_shader_parameter("atlas",load(TEXTURE))
	material.set_shader_parameter("row_count",float(rows.size()))
	material.set_shader_parameter("sun_right",sun_basis.x)
	material.set_shader_parameter("sun_up",sun_basis.y)
	var limit := sun.directional_shadow_max_distance
	material.set_shader_parameter("shadow_handoff",Vector2(limit * sun.directional_shadow_fade_start,limit))
	material.render_priority = -10
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = material
	var cells := {}
	var along := sun_basis.x.cross(Vector3.UP)
	var rotation := Basis(sun_basis.x, Vector3.UP, along)
	for asset in groups:
		var row := rows.find(asset)
		if row < 0:
			push_warning("No far-shadow atlas row for "+str(asset))
			continue
		for item: Dictionary in groups[asset].items:
			var center: Vector3 = item.center
			var size: Vector2 = item.size
			var projected := center - light * ((center.y - float(item.ground_y)) / light.y)
			# Include the offset of the shadow on raised paths and sloping terrain.
			var length_z := (size.y + 2.0 * HALF_HEIGHT * absf(sun_basis.y.y)) / light.y
			var scale := Vector3(size.x, HALF_HEIGHT*2.0, length_z)
			var tr := Transform3D(rotation * Basis.from_scale(scale), projected)
			var bounds := tr * mesh.get_aabb()
			var water_y := -10000.0
			for lake in water:
				if bounds.intersects(lake.grow(.05)):
					water_y = lake.get_center().y
					break
			var cell := Vector2i(floori(projected.x/CELL), floori(projected.z/CELL))
			if not cells.has(cell): cells[cell] = []
			cells[cell].append([tr,Color(item.yaw, 1.0/size.y, water_y, float(row)),bounds])
	for pieces: Array in cells.values():
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_custom_data = true
		batch.mesh = mesh
		batch.instance_count = pieces.size()
		var bounds: AABB = pieces[0][2]
		for i in pieces.size():
			batch.set_instance_transform(i,pieces[i][0])
			batch.set_instance_custom_data(i,pieces[i][1])
			bounds = bounds.merge(pieces[i][2])
		batch.custom_aabb = bounds
		var node := MultiMeshInstance3D.new()
		node.name = "FarCanopyFootprints"
		node.multimesh = batch
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		node.set_meta("far_canopy_footprint",true)
		world.add_child(node)
	return material
