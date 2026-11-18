extends SceneTree
## Small structural gate for the replacement library; does not start the campus
## or AI services. Actual movement uses validate_campus_visits separately.

const District = preload("res://scripts/library_district.gd")
const Room = preload("res://scripts/campus_visit_room.gd")
var checks := {}
var meshes := 0
var triangles := 0
var bounds := AABB()
var has_bounds := false
var permanent_meshes: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func verify(label: String, passed: bool) -> void:
	checks[label] = passed
	print("LIBRARY_MULTIVIEW_CHECK ", label, " ", passed)


func measure(node: Node3D, parent_transform := Transform3D.IDENTITY) -> void:
	var transform: Transform3D = parent_transform * node.transform
	if node is MeshInstance3D and node.mesh:
		var part: AABB = transform * node.get_aabb()
		bounds = bounds.merge(part) if has_bounds else part
		has_bounds = true
		meshes += 1
		if not "PhotoVisitGlass" in node.name:
			permanent_meshes.append({"name":str(node.name),"bounds":part,
				"transform":transform,"mesh":node.mesh})
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += indices.size() / 3
	for child in node.get_children():
		if child is Node3D:
			measure(child, transform)


func clear_door_aperture(center: Vector3, width: float, height: float) -> bool:
	var offset := minf(.65,width*.3)
	for dx in [-offset,0.0,offset]:
		for dy in [.3,1.02,height*.5,height-.25]:
			var start := center + Vector3(dx,dy,.51)
			var end := center + Vector3(dx,dy,-.94)
			for part in permanent_meshes:
				var box: AABB = part.bounds
				if start.x < box.position.x or start.x > box.end.x or start.y < box.position.y or start.y > box.end.y:
					continue
				if box.end.z < end.z or box.position.z > start.z:
					continue
				var local_start: Vector3 = part.transform.affine_inverse() * start
				var local_end: Vector3 = part.transform.affine_inverse() * end
				var faces: PackedVector3Array = part.mesh.get_faces()
				for i in range(0,faces.size(),3):
					if Geometry3D.segment_intersects_triangle(local_start,local_end,faces[i],faces[i+1],faces[i+2]) != null:
						print("LIBRARY_PERMANENT_DOOR_OBSTRUCTION ",part.name," at ",start)
						return false
	return true


func run() -> void:
	var music := root.get_node_or_null("CampusMusic") as AudioStreamPlayer
	if music:
		music.stop()
		music.stream = null
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/library_district_manifest.json"))
	var spec: Dictionary = manifest.assets.south_library
	verify("local_coordinate_contract", spec.has("local_placement"))
	var pose := District.asset_transform(spec)
	verify("campus_entrance_origin", pose.origin.distance_to(Vector3(2.8535, 0, 426.1915)) < .00001)
	verify("campus_orientation", (pose * Vector3(1,0,0)).distance_to(Vector3(3.853433583,0,426.20302515)) < .00001)
	for asset in manifest.assets:
		if asset != "south_library":
			verify("unchanged_pose_"+asset, District.asset_transform(manifest.assets[asset]) == Transform3D.IDENTITY)
	var model: Node3D = load("res://assets/south_library.glb").instantiate()
	root.add_child(model)
	measure(model)
	verify("local_asset_width", has_bounds and bounds.size.x >= 71.8 and bounds.size.x < 73.5)
	verify("local_asset_height", bounds.end.y >= 31.9 and bounds.end.y < 32.5)
	verify("local_asset_depth", bounds.position.z <= -25.4 and bounds.position.z > -27.0 and bounds.end.z >= 10.3 and bounds.end.z < 12.0)
	var fallbacks: Array[Node3D] = []
	for child in model.get_children():
		if child is MeshInstance3D and "PhotoVisitGlass" in child.name:
			fallbacks.append(child)
	verify("separate_replaceable_door_leaves", not fallbacks.is_empty())
	var plan: Dictionary
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://data/campus_visits.json")):
		if entry.id == "new-library":
			plan = entry
	var edge_length := Vector2(plan.edge[0][0],plan.edge[0][1]).distance_to(Vector2(plan.edge[1][0],plan.edge[1][1]))
	for doorway: Dictionary in plan.doors:
		var center := Vector3(-float(doorway.offset)*edge_length,plan.floor,doorway.outset)
		verify(str(doorway.id)+"_no_permanent_mesh", clear_door_aperture(center,float(doorway.span)*edge_length,doorway.height))
	model.transform = pose
	var room := Room.new()
	room.configure(plan)
	root.add_child(room)
	verify("landing_height_retained", is_equal_approx(room.position.y, 3.18))
	var shell: Dictionary
	for solid in manifest.collision_solids:
		if solid.name == "south_library_closed_exterior":
			shell = solid
	var polygon := PackedVector2Array()
	for point in shell.polygon:
		polygon.append(Vector2(point[0],point[1]))
	verify("new_shell_main_roof", is_equal_approx(float(shell.top),24.3))
	verify("door_cut_intersects_shell", not room.shell_opening(polygon).is_empty())
	room.build_entry()
	verify("two_working_entry_door_nodes", room.doors.size() == 2)
	for index in room.doors.size():
		var door: Node3D = room.doors[index]
		var doorway: Dictionary = plan.doors[index]
		var local := pose.affine_inverse() * door.global_position
		verify("door_position_"+str(door.name), absf(local.x+float(doorway.offset)*edge_length) < .0001
			and absf(local.z-float(doorway.outset))<.0001 and absf(local.y-float(plan.floor))<.0001)
	for point in [Vector2(-40,-12),Vector2(40,-12),Vector2(0,-27)]:
		var world := pose * Vector3(point.x,0,point.y)
		verify("old_shell_removed_"+str(point), not Geometry2D.is_point_in_polygon(Vector2(world.x,world.z),polygon))
	var passed := true
	for result in checks.values():
		passed = passed and bool(result)
	var report := {"passed":passed,"checks":checks,"mesh_count":meshes,"triangles":triangles,
		"source_asset_sha256":FileAccess.get_sha256("res://assets/south_library.glb"),
		"local_bounds_position":[bounds.position.x,bounds.position.y,bounds.position.z],
		"local_bounds_size":[bounds.size.x,bounds.size.y,bounds.size.z]}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--library-report="):
			var file := FileAccess.open(arg.trim_prefix("--library-report="),FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(report,"\t"))
	print("LIBRARY_MULTIVIEW_REPORT ",JSON.stringify(report))
	permanent_meshes.clear()
	room.free()
	model.free()
	await process_frame
	quit(0 if passed else 1)
