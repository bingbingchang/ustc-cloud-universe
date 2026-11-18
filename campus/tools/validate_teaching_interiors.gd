extends SceneTree
## Walk the production player between all levels and test room connectivity
## against the same collision shapes used in the Windows game.

var game
var player
var failures: Array = []
var outcomes := {}
var output := ""
var stair_routes := 0
var room_routes := 0
var door_nodes := 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--teaching-report="):
			output = argument.trim_prefix("--teaching-report=")
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func require(label: String, passed: bool, detail: Variant = "") -> void:
	outcomes[label] = passed
	if not passed:
		failures.append([label, str(detail)])
		print("TEACHING_FAIL ", label, " ", detail)

func blocks() -> Array:
	var names := []
	for i in player.get_slide_collision_count():
		names.append(str(player.get_slide_collision(i).get_collider().get_path()))
	return names

func walk(target: Vector3, vertical_slop: float = .095) -> bool:
	var limit := ceili(Vector2(target.x-player.position.x,target.z-player.position.z).length() * 39) + 100
	for i in limit:
		var d: Vector3 = target - player.position
		d.y = 0
		if d.length() < .10:
			break
		player.orbit.rotation.y = atan2(-d.x,-d.z)
		player.touch_move = Vector2(0, -clampf(d.length() * 1.18, .22, .70))
		await physics_frame
		if player.position.y < minf(target.y - 3.8, -.50):
			break
	player.touch_move = Vector2.ZERO
	await frames(8)
	var final: Vector3 = player.position
	var horizontal := Vector2(target.x-final.x,target.z-final.z).length()
	return horizontal < .19 and absf(final.y - target.y) <= vertical_slop and player.is_on_floor()

func entry_to_stair(room) -> bool:
	var door: Node3D = room.doors[0]
	var start := door.to_global(Vector3(0,0,-1.68))
	var inside := door.to_global(Vector3(0,0,1.75))
	player.set_view(start,inside)
	player.frozen=false
	await frames(16)
	door.target_open = true
	await frames(34)
	var prefix: String = str(room.spec.id) + "/entry"
	var reached := await walk(inside)
	require(prefix,reached,[player.position,inside,blocks()])
	if not reached:
		return false
	var y: float = inside.y
	var bend: Array = {
		"teaching-one": [Vector3(-8.0,y,171.7),Vector3(-11.1,y,173.5),Vector3(-11.2,y,180.55)],
		"teaching-two": [Vector3(150,y,349),Vector3(153.95,y,342),Vector3(154.24,y,338.1),Vector3(153.90,y,332),Vector3(153.90,y,329),Vector3(154,y,325),Vector3(154,y,308.40),Vector3(110.9,y,308.56)],
		"teaching-five": [Vector3(182.2,y,-10.7)]
	}[room.spec.id]
	bend.append(room.contents.level_data[0].stair_start)
	for point: Vector3 in bend:
		reached = await walk(point)
		if not reached:
			require(prefix+"/walk-to-stairs",false,[player.position,point,blocks()])
			return false
	require(prefix+"/walk-to-stairs",true)
	return true

func stair_trip(room, ascending: bool) -> void:
	var levels: Array = room.contents.level_data
	var trip := "up" if ascending else "down"
	var initial: Vector3 = levels[0].stair_start if ascending else levels[-2].stair_finish
	player.set_view(initial + Vector3.UP*.01,initial+Vector3.BACK)
	await frames(12)
	for i in range(levels.size() - 1):
		var index := i if ascending else levels.size() - 2 - i
		var floor: Dictionary = levels[index]
		var path := [floor.stair_start,floor.stair_turn_a,floor.stair_turn_b,floor.stair_finish]
		if not ascending:
			path.reverse()
		for j in path.size():
			var p: Vector3 = path[j]
			var ok := await walk(p,.10)
			if not ok:
				require("%s/%s/%s/%s" % [room.spec.id,trip, index+1, j],false,[player.position,p,blocks()])
				return
		stair_routes += 1
		require("%s/%s/%s" % [room.spec.id, trip,index+1],true)

func space_for(p: Vector2, y: float, floor_body: StaticBody3D, space: PhysicsDirectSpaceState3D, cap: PhysicsShapeQueryParameters3D) -> bool:
	var foot := Vector3(p.x,y,p.y)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.037,foot-Vector3.UP*.042,1,cap.exclude))
	if hit.is_empty() or hit.collider != floor_body:
		return false
	cap.transform.origin = foot + Vector3.UP * .905
	return not space.collide_shape(cap,1)

func cell(p: Vector2, origin: Vector2, step: float) -> Vector2i:
	return Vector2i(roundi((p.x-origin.x)/step),roundi((p.y-origin.y)/step))

func nearest(p: Vector2, origin: Vector2, step: float, available: Dictionary) -> Vector2i:
	var base := cell(p,origin,step)
	var choice := Vector2i(-999,-999)
	var best := .70
	for dx in range(-1,2):
		for dz in range(-1,2):
			var n := base + Vector2i(dx,dz)
			var distance := (origin + Vector2(n)*step).distance_to(p)
			if distance < best and available.has(n):
				best = distance
				choice = n
	return choice

func route_grid(room, level: Dictionary, doors: Array) -> void:
	var y: float = level.height
	var floor_node: Node3D = room.contents.get_node("Floor%d" % level.floor)
	var floor_body: StaticBody3D = floor_node.get_node("PartitionsAndStairs")
	var area: Rect2 = room.building_bounds
	var space := floor_node.get_world_3d().direct_space_state
	var body := CapsuleShape3D.new()
	body.radius = .28
	body.height = 1.75
	var cap := PhysicsShapeQueryParameters3D.new()
	cap.shape = body
	cap.exclude = [player.get_rid()]
	var step := .45
	# Build a conservative walkable grid from the actual runtime floor and
	# collision shapes. Each adjacency is checked at its midpoint as well.
	var available := {}
	for iz in ceili(area.size.y/step):
		for ix in ceili(area.size.x/step):
			var key := Vector2i(ix,iz)
			var p := area.position + Vector2(key)*step
			if space_for(p,y,floor_body,space,cap):
				available[key] = true
	var seed: Vector3 = level.stair_start
	if level.floor > 1:
		seed = room.contents.level_data[level.floor-2].stair_finish
	var first := nearest(Vector2(seed.x,seed.z),area.position,step,available)
	var visited := {}
	var queue: Array[Vector2i] = []
	if available.has(first):
		queue.append(first)
		visited[first] = true
	var offset := 0
	while offset < queue.size():
		var at := queue[offset]
		offset += 1
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var to: Vector2i = at + direction
			if not available.has(to) or visited.has(to):
				continue
			var mid := area.position + (Vector2(at)+Vector2(to))*step*.5
			if not space_for(mid,y,floor_body,space,cap):
				continue
			visited[to] = true
			queue.append(to)
	var missing := []
	for door: Node3D in doors:
		var inside := door.to_global(Vector3(0,0,.69))
		var outside := door.to_global(Vector3(0,0,-.69))
		var in_key := nearest(Vector2(inside.x,inside.z),area.position,step,visited)
		var out_key := nearest(Vector2(outside.x,outside.z),area.position,step,visited)
		if not visited.has(in_key) or not visited.has(out_key):
			missing.append([door.door_id, str(outside), visited.has(out_key)])
		else:
			room_routes += 1
	require("%s/%s/rooms" % [room.spec.id,level.floor],missing.is_empty() and not queue.is_empty(),missing)
	print("TEACHING_GRID ",room.spec.id," ",level.floor," reachable=",visited.size()," doors=",doors.size()," gaps=",missing.size())

func run() -> void:
	Engine.time_scale=6
	Engine.physics_ticks_per_second=360
	Engine.max_fps=360
	game = load("res://scenes/campus_game.tscn").instantiate()
	root.add_child(game)
	player=game.player
	player.touch_mode=true
	game.hero_interactions.set_process(false)
	game.campus_agent.set_process(false)
	for room in game.campus_visits.rooms:
		var id: String = room.spec.id
		if room.teaching_layout.is_empty():
			continue
		player.frozen=true
		player.set_view(room.to_global(Vector3(0,0,-2)),room.global_position)
		room.prepare()
		await frames(20)
		if not room.contents:
			require(id+"/load",false)
			continue
		await entry_to_stair(room)
		await stair_trip(room,true)
		await stair_trip(room,false)
		player.frozen = true
		player.global_position=room.global_position
		for door in room.contents.doors:
			door.target_open=true
			door.advance(1.0,player)
		await frames(5)
		door_nodes += room.contents.doors.size()
		for level: Dictionary in room.contents.level_data:
			var doors: Array = room.contents.doors.filter(func(d): return absf(d.global_position.y-level.height)<.03)
			route_grid(room,level,doors)
		room.release_contents()
		player.global_position = Vector3(0,.13,12)
		await frames(2)
	var report := {
		"passed": failures.is_empty() and stair_routes == 26 and room_routes == door_nodes and door_nodes == 109,
		"stairs_passed": stair_routes, "rooms_reachable": room_routes, "doors": door_nodes,
		"checks": outcomes, "failures": failures
	}
	if not output.is_empty():
		FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TEACHING_COMPLETE ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if report.passed else 1)
