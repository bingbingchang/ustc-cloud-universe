extends "res://samples/threejs_road/preview.gd"

var output_dir := ProjectSettings.globalize_path("res://../renders/plane_avenue")
var player: CharacterBody3D
var walking := false
var batch_count := 0
var instanced_elements := 0
var report: Dictionary = {}

func _ready() -> void:
	get_window().title = "梧桐林荫路 · 50米样段"
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	super._ready()
	_instance_repeated_paving()
	var environment: Environment = find_children("*", "WorldEnvironment", false, false)[0].environment
	environment.background_color = Color("eceedf").srgb_to_linear()
	environment.ambient_light_energy = 0.42
	environment.tonemap_exposure = 0.85
	for light in find_children("*", "DirectionalLight3D", false, false):
		if light.shadow_enabled:
			light.directional_shadow_max_distance = 110.0
			light.light_angular_distance = 0.5
	_create_walker()
	_reset_overview()
	if "--capture-avenue" in OS.get_cmdline_user_args():
		pause_wind = true
		_capture.call_deferred()

func _instance_repeated_paving() -> void:
	var groups: Dictionary = {}
	for instance in get_node("Visual").find_children("*", "MeshInstance3D", true, false):
		if not str(instance.name).begins_with("Paver_") and not str(instance.name).begins_with("Curb_") and not str(instance.name).begins_with("EdgePaint_") and not str(instance.name).begins_with("Verge_Edge_"):
			continue
		var cell := int(floor((instance.global_position.z + 25.0) / 10.0))
		var key := str(instance.mesh.get_rid().get_id()) + ":" + str(cell)
		if not groups.has(key):
			groups[key] = []
		groups[key].append(instance)
	for key in groups:
		var objects: Array = groups[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = objects[0].mesh
		multi.instance_count = objects.size()
		var batch := MultiMeshInstance3D.new()
		batch.name = "PavingBatch_" + str(batch_count)
		batch.multimesh = multi
		add_child(batch)
		for i in objects.size():
			multi.set_instance_transform(i, objects[i].global_transform)
			objects[i].queue_free()
		instanced_elements += objects.size()
		batch_count += 1

func _create_walker() -> void:
	var keys := {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"jog":KEY_SHIFT,"jump":KEY_SPACE,"up":KEY_E,"down":KEY_Q}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = keys[action]
		InputMap.action_add_event(action, key)
	player = load("res://scripts/player.gd").new()
	add_child(player)
	player.enabled = false
	player.frozen = true
	player.respawn_position = Vector3(0,0.04,23)
	player.respawn_target = Vector3(0,3,-20)
	player.set_view(player.respawn_position,player.respawn_target)
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _reset_overview() -> void:
	_set_view(Vector3(34,32,46),Vector3(0,3.2,0),34)

func _set_view(eye: Vector3, focus: Vector3, fov: float) -> void:
	target = focus
	var offset := eye-focus
	radius = offset.length()
	azimuth = atan2(offset.x,offset.z)
	polar = acos(offset.y/radius)
	camera.fov = fov
	_update_camera()

func _toggle_walking() -> void:
	walking = not walking
	player.enabled = walking
	player.frozen = not walking
	player.camera.current = walking
	camera.current = not walking
	if walking:
		player.set_view(player.respawn_position,player.respawn_target)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if walking else Input.MOUSE_MODE_VISIBLE

func _pan(delta: Vector2) -> void:
	target += (-camera.global_basis.x*delta.x+camera.global_basis.y*delta.y)*radius*.0009
	target.x = clampf(target.x,-9,9)
	target.z = clampf(target.z,-25,25)
	target.y = clampf(target.y,.15,14)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				_toggle_walking()
				return
			KEY_F12:
				_save("manual")
				return
			KEY_R:
				if walking:
					player.set_view(player.respawn_position,player.respawn_target)
				else:
					_reset_overview()
				return
	if walking:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			radius = maxf(2,radius*.91)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			radius = minf(100,radius*1.10)
			return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_set_view(Vector3(0,1.65,24),Vector3(0,4.5,-16),64)
				return
			KEY_2:
				_set_view(Vector3(0,57,.01),Vector3(0,0,0),50)
				return
			KEY_3:
				_reset_overview()
				return
	super._unhandled_input(event)

func _save(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	var result := get_viewport().get_texture().get_image().save_png(output_dir.path_join(label+".png"))
	assert(result == OK,"Avenue screenshot failed")

func _capture() -> void:
	for i in 90:
		await get_tree().process_frame
	if "--validate-avenue" in OS.get_cmdline_user_args():
		await _walk_checks()
	var views := [
		["overview",Vector3(34,32,46),Vector3(0,3.2,0),34.0],
		["entrance",Vector3(0,1.65,24),Vector3(0,4.5,-16),64.0],
		["middle",Vector3(0,1.65,5),Vector3(0,5.4,-20),64.0],
		["tree_fork",Vector3(-3.65,3.5,23.8),Vector3(-6.45,4.0,18.4),47.0],
		["ground",Vector3(2.9,1.55,23),Vector3(3.45,.03,19.5),48.0],
		["reverse",Vector3(0,1.65,-24),Vector3(0,4.5,18),64.0],
		["section",Vector3(0,23,30),Vector3(0,0,18),50.0],
		["bench_left",Vector3(-3.8,1.5,1.0),Vector3(-6.435,.65,-.8),49.0],
		["bench_right",Vector3(3.8,1.5,12.7),Vector3(6.435,.65,14.5),49.0],
	]
	report["rendering"] = []
	for view in views:
		_set_view(view[1],view[2],view[3])
		for i in 35:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save(view[0])
		report["rendering"].append({"view":view[0],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	report["crowns"] = crowns.size()
	report["instanced_paving_elements"] = instanced_elements
	report["paving_batches"] = batch_count
	report["collision_shapes"] = get_node("Collision").find_children("*","CollisionShape3D",true,false).size()
	report["views"] = views.size()
	var file := FileAccess.open(output_dir.path_join("runtime.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("Avenue sample: ",report)
	get_tree().quit()

func _walk_checks() -> void:
	report["walk_routes"] = []
	for x in [0.0,-4.66,4.66]:
		var start_y := .04 if x == 0 else .19
		player.set_view(Vector3(x,start_y,23),Vector3(x,1.6,-25))
		player.enabled = true
		player.frozen = false
		player.camera.current = true
		camera.current = false
		Input.action_press("forward")
		Input.action_press("jog")
		var steps := 0
		var floor_steps := 0
		var lowest_y := start_y
		while player.position.z > -22 and steps < 900:
			await get_tree().physics_frame
			steps += 1
			if player.is_on_floor():
				floor_steps += 1
			lowest_y = minf(lowest_y,player.position.y)
		Input.action_release("forward")
		Input.action_release("jog")
		var passed := player.position.z <= -22 and lowest_y > -.05 and float(floor_steps)/steps > .97
		report["walk_routes"].append({"x":x,"end":str(player.position),"physics_steps":steps,"floor_ratio":float(floor_steps)/steps,"lowest_y":lowest_y,"passed":passed})
		print("Walk route at x=",x," passed=",passed)
		assert(passed,"Avenue walking route failed")
	for i in 5:
		await get_tree().physics_frame
	var base_y := player.position.y
	var peak_y := base_y
	Input.action_press("jump")
	for i in 2:
		await get_tree().physics_frame
	Input.action_release("jump")
	for i in 90:
		await get_tree().physics_frame
		peak_y = maxf(peak_y,player.position.y)
	report["jump_height"] = peak_y-base_y
	report["jump_landed"] = player.is_on_floor()
	assert(peak_y-base_y > .65 and player.is_on_floor(),"Avenue jump failed")
	var trunks := 0
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://samples/plane_avenue/assets/manifest.json"))
	for position in manifest.tree_positions:
		var x: float = position[0]
		var z: float = position[2]
		var ray := PhysicsRayQueryParameters3D.create(Vector3(0,1.4,z),Vector3(x*1.3,1.4,z))
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and str(hit.collider.name).begins_with("Trunk_"):
			trunks += 1
	report["trunk_collisions"] = trunks
	assert(trunks == 8,"Tree collision proxy missing")
	report["benches"] = []
	for bench_name in ["Bench_01","Bench_02"]:
		var bench: Node3D = get_node("Visual").find_child(bench_name,true,false)
		var side := signf(bench.global_position.x)
		var toward_road := Vector3(-side,0,0)
		var facing := bench.global_basis.z.normalized().dot(toward_road)
		assert(facing > .99,"Bench faces away from road")
		player.set_view(Vector3(side*4.66,.19,bench.global_position.z),bench.global_position+Vector3(0,1.5,0))
		Input.action_press("forward")
		var steps := 0
		while absf(player.position.x) < 5.75 and steps < 180:
			await get_tree().physics_frame
			steps += 1
		Input.action_release("forward")
		for i in 10:
			await get_tree().physics_frame
		var accessible := absf(player.position.x) >= 5.75 and player.is_on_floor()
		assert(accessible,"Cannot walk from sidewalk to bench front")
		# Continue toward the seat to confirm its collision stops the player.
		Input.action_press("forward")
		for i in 75:
			await get_tree().physics_frame
		Input.action_release("forward")
		var blocked := absf(player.position.x) < 6.0 and player.is_on_wall()
		assert(blocked,"Bench collision does not stop player")
		report["benches"].append({"name":bench_name,"front_dot_toward_road":facing,"ground_y":bench.global_position.y,"front_accessible":accessible,"collision_stops_player":blocked,"end":str(player.position)})
	var file := FileAccess.open(output_dir.path_join("walking.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	player.enabled = false
	player.frozen = true
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
