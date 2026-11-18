extends SceneTree
## Check the actual pavement meshes independently from the walkable terrain.

const North = preload("res://scripts/north_axis_environment.gd")
const Network = preload("res://scripts/campus_network.gd")
const Sight = 1 << 22
var game
var space: PhysicsDirectSpaceState3D
var mesh_hits := 0
var physics_hits := 0
var misses := []
var sections := {}
var report_path := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--road-surface-report="):
			report_path = argument.trim_prefix("--road-surface-report=")
	call_deferred("run")

func check(label: String, p: Vector2) -> void:
	var high := Vector3(p.x,Network.ROAD_TOP+.016,p.y)
	var low := Vector3(p.x,Network.ROAD_TOP-.021,p.y)
	var visual := not space.intersect_ray(PhysicsRayQueryParameters3D.create(high,low,Sight)).is_empty()
	var walkable := not space.intersect_ray(PhysicsRayQueryParameters3D.create(high,low,1)).is_empty()
	mesh_hits += int(visual)
	physics_hits += int(walkable)
	sections[label] = int(sections.get(label,0)) + 1
	if not visual or not walkable:
		misses.append([label,p.x,p.y,visual,walkable])

func run() -> void:
	game = load("res://scenes/campus_game.tscn").instantiate()
	root.add_child(game)
	game.player.frozen=true
	var count := 0
	for mesh in game.world.get_children():
		if not mesh is MeshInstance3D or not mesh.visible:
			continue
		if not str(mesh.name).begins_with("MappedRoad_") and mesh.name != "SakuraAvenueStone":
			continue
		var body := StaticBody3D.new()
		body.collision_layer = Sight
		body.collision_mask = 0
		game.world.add_child(body)
		body.global_transform = mesh.global_transform
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_trimesh_shape()
		shape.shape.backface_collision = true
		body.add_child(shape)
		count += 1
	for i in range(4):
		await physics_frame
	space = game.get_world_3d().direct_space_state
	var region_polys := Network.regions()
	var avoid: Array = game.ponds.duplicate()
	for area in North.Geometry.protected_areas():
		avoid.append(North.polygon(area.polygon))
	for building in Network.data().buildings:
		avoid.append(North.polygon(building.outline))
	var exclusions := []
	for polygon in avoid:
		exclusions.append([North._bounds(polygon).grow(.012),polygon])
	for road: Dictionary in Network.data().roads:
		if not road.get("build_enabled",true):
			continue
		var points := North.polygon(road.points)
		for i in range(points.size()-1):
			var a := points[i]
			var b := points[i+1]
			var right := (b-a).normalized().orthogonal() * float(road.width) * .30
			var n := ceili(a.distance_to(b) / .65)
			for j in n:
				for side in [-1,0,1]:
					var p: Vector2 = a.lerp(b,(j+.5)/n) + right*side
					if not region_polys.any(func(poly): return Geometry2D.is_point_in_polygon(p,poly)):
						continue
					if exclusions.any(func(entry): return entry[0].has_point(p) and Geometry2D.is_point_in_polygon(p,entry[1])):
						continue
					check(road.id,p)
	# Probe the two repaired junctions at 2 cm resolution.
	for join: Array in [["fangcao",Vector2(165.8,621.20),Vector2(174.4,621.14)],
			  ["garden",Vector2(181.995,217.4),Vector2(181.995,221.2)]]:
		for j in 401:
			check(join[0],join[1].lerp(join[2],j/400.0))
	var report := {"passed":misses.is_empty() and mesh_hits>20000,"render_meshes":count,"visual_hits":mesh_hits,"physical_hits":physics_hits,"checked_roads":sections.size()-2,"misses":misses,"sections":sections}
	if not report_path.is_empty():
		FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ROAD_SURFACES meshes=",count," roads=",sections.size()-2," display_hits=",mesh_hits," physics_hits=",physics_hits," misses=",misses.slice(0,35)," missing_count=",misses.size())
	game.queue_free()
	await process_frame
	quit(0 if report.passed else 1)
