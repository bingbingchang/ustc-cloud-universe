extends "res://samples/threejs_road/preview.gd"

var output_dir := ProjectSettings.globalize_path("res://../renders/cafe_courtyard")
var player: CharacterBody3D
var walking := false
var report: Dictionary = {}

func _ready() -> void:
	get_window().title = "校园咖啡小院 · Blender 直接建模"
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	super._ready()
	_batch_repeated_geometry()
	var environment: Environment = find_children("*","WorldEnvironment",false,false)[0].environment
	environment.background_color = Color("e7e3d8").srgb_to_linear()
	environment.ambient_light_color = Color("dee2d8").srgb_to_linear()
	environment.ambient_light_energy = .54
	environment.tonemap_exposure = .92
	for light in find_children("*","DirectionalLight3D",false,false):
		if light.shadow_enabled:
			light.light_energy = 1.45
			light.light_angular_distance = .9
			light.directional_shadow_max_distance = 45
	for instance in get_node("Visual").find_children("Glass*","MeshInstance3D",true,false):
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-1.95,1.95]:
		var fill := OmniLight3D.new()
		fill.position = Vector3(x,2.5,-2.4)
		fill.light_color = Color("ffe0a9")
		fill.light_energy = .5
		fill.omni_range = 4
		add_child(fill)
	_create_walker()
	_overview()
	if "--capture-cafe" in OS.get_cmdline_user_args():
		pause_wind = true
		_capture.call_deferred()

func _batch_repeated_geometry() -> void:
	var groups: Dictionary = {}
	var count := 0
	for instance in get_node("Visual").find_children("*","MeshInstance3D",true,false):
		if not str(instance.name).begins_with("Paver_") and not str(instance.name).begins_with("Entry_Paver") and not str(instance.name).begins_with("RoofTile_"):
			continue
		var key: int = instance.mesh.get_rid().get_id()
		if not groups.has(key):groups[key] = []
		groups[key].append(instance)
	for key in groups:
		var objects: Array = groups[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = objects[0].mesh
		multi.instance_count = objects.size()
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = multi
		add_child(batch)
		for i in objects.size():
			multi.set_instance_transform(i,objects[i].global_transform)
			objects[i].queue_free()
		count += objects.size()
	report["batched_elements"] = count
	report["batches"] = groups.size()

func _create_walker() -> void:
	var keys := {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"jog":KEY_SHIFT,"jump":KEY_SPACE,"up":KEY_E,"down":KEY_Q}
	for action in keys:
		if not InputMap.has_action(action):InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = keys[action]
		InputMap.action_add_event(action,key)
	player = load("res://scripts/player.gd").new()
	add_child(player)
	player.enabled = false
	player.frozen = true
	player.respawn_position = Vector3(0,.28,5.55)
	player.respawn_target = Vector3(0,1.8,-1)
	player.set_view(player.respawn_position,player.respawn_target)
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _set_view(eye: Vector3,focus: Vector3,fov: float) -> void:
	target = focus
	var offset := eye-focus
	radius = offset.length()
	azimuth = atan2(offset.x,offset.z)
	polar = acos(offset.y/radius)
	camera.fov = fov
	_update_camera()

func _overview() -> void:
	_set_view(Vector3(13.3,12.7,17.2),Vector3(0,1.0,0),36)

func _pan(delta: Vector2) -> void:
	target += (-camera.global_basis.x*delta.x+camera.global_basis.y*delta.y)*radius*.0009
	target.x = clampf(target.x,-7,7)
	target.z = clampf(target.z,-6,6)
	target.y = clampf(target.y,.2,6)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			walking = not walking
			player.enabled = walking
			player.frozen = not walking
			player.camera.current = walking
			camera.current = not walking
			if walking:player.set_view(player.respawn_position,player.respawn_target)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if walking else Input.MOUSE_MODE_VISIBLE
			return
		if event.keycode == KEY_F12:
			_save("manual")
			return
		if event.keycode == KEY_R or event.keycode == KEY_3:
			if walking:player.set_view(player.respawn_position,player.respawn_target)
			else:_overview()
			return
	if walking:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_set_view(Vector3(0,1.89,5.2),Vector3(0,1.7,-1),64)
			return
		if event.keycode == KEY_2:
			_set_view(Vector3(0,22,.01),Vector3(0,0,0),40)
			return
	super._unhandled_input(event)

func _save(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	assert(get_viewport().get_texture().get_image().save_png(output_dir.path_join(label+".png")) == OK,"Cafe screenshot failed")

func _capture() -> void:
	for i in 80:await get_tree().process_frame
	await _checks()
	var views := [
		["overview",Vector3(13.3,12.7,17.2),Vector3(0,1.0,0),36.0],
		["entrance",Vector3(0,1.89,5.2),Vector3(0,1.9,-1),64.0],
		["facade",Vector3(-4.7,3.2,5.7),Vector3(0,1.9,-1),49.0],
		["roof",Vector3(6.5,7.3,4),Vector3(0,3.8,-2.7),42.0],
		["table",Vector3(-.9,1.75,3.5),Vector3(-2.75,.83,1.75),48.0],
		["window",Vector3(2.0,1.80,.26),Vector3(1.65,1.65,-3.05),53.0],
		["garden",Vector3(-3.6,1.35,5.4),Vector3(-5.35,.70,3.9),48.0],
		["reverse",Vector3(-14,11,-16),Vector3(0,1.3,-1),40.0],
	]
	report["rendering"] = []
	for view in views:
		_set_view(view[1],view[2],view[3])
		for i in 30:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save(view[0])
		report["rendering"].append({"view":view[0],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	report["crowns"] = crowns.size()
	report["collision_shapes"] = get_node("Collision").find_children("*","CollisionShape3D",true,false).size()
	var file := FileAccess.open(output_dir.path_join("runtime.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("Cafe courtyard: ",report)
	get_tree().quit()

func _checks() -> void:
	var facing_checks: Array = []
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://samples/cafe_courtyard/assets/manifest.json"))
	for item in manifest.chairs:
		var chair: Node3D = get_node("Visual").find_child(item.id,true,false)
		var table: Node3D = get_node("Visual").find_child("CafeTable_"+str(int(item.table_index)),true,false)
		var delta := table.global_position-chair.global_position
		delta.y = 0
		var dot := chair.global_basis.z.normalized().dot(delta.normalized())
		assert(dot>.99,"Chair faces away from its table")
		facing_checks.append({"chair":item.id,"toward_table":dot})
	report["chair_facing"] = facing_checks
	player.enabled = true
	player.frozen = false
	player.camera.current = true
	camera.current = false
	report["walk_routes"] = []
	var routes := [
		["entry_to_door",Vector3(0,.28,5.55),Vector3(0,.28,-.4)],
		["left_table_circulation",Vector3(-4.3,.28,4.4),Vector3(-4.3,.28,.25)],
		["front_table_circulation",Vector3(-4.3,.28,4.65),Vector3(4.8,.28,4.65)],
	]
	for route in routes:
		var destination: Vector3 = route[2]
		player.set_view(route[1],destination+Vector3(0,1.65,0))
		Input.action_press("forward")
		Input.action_press("jog")
		var steps := 0
		var lowest := .28
		while Vector2(player.position.x-destination.x,player.position.z-destination.z).length()>.12 and steps<360:
			await get_tree().physics_frame
			steps += 1
			lowest = minf(lowest,player.position.y)
		Input.action_release("forward")
		Input.action_release("jog")
		var passed := steps<360 and lowest>.20
		assert(passed,"Cafe circulation route blocked or unsupported: "+str(route[0]))
		report["walk_routes"].append({"name":route[0],"passed":passed,"lowest_y":lowest,"steps":steps,"end":str(player.position)})
	# Closed entry door and furniture must stop the actual player capsule.
	player.set_view(Vector3(0,.28,.1),Vector3(0,1.89,-2))
	Input.action_press("forward")
	for i in 65:await get_tree().physics_frame
	Input.action_release("forward")
	report["closed_door_blocks"] = player.position.z>-.7 and player.is_on_wall()
	assert(report["closed_door_blocks"],"Closed door collision failed")
	player.set_view(Vector3(-2.75,.28,4.4),Vector3(-2.75,1.89,1.75))
	Input.action_press("forward")
	for i in 95:await get_tree().physics_frame
	Input.action_release("forward")
	report["furniture_blocks"] = player.position.z>2.3 and player.is_on_wall()
	assert(report["furniture_blocks"],"Table/chair collision failed")
	player.enabled = false
	player.frozen = true
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
