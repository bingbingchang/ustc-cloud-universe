extends "res://samples/threejs_road/preview.gd"

var output_dir := ProjectSettings.globalize_path("res://../renders/ustc1958")
var manifest: Dictionary
var assets: Node3D
var player: CharacterBody3D
var walking := false
var report: Dictionary = {}

func _ready() -> void:
	get_window().title = "USTC1958 · 科大东区 · 实景建模"
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://samples/ustc1958/assets/manifest.json"))
	_instantiate_shared_kit()
	super._ready()
	_collect_nodes(assets)
	_batch_repeated_geometry()
	var environment: Environment = find_children("*","WorldEnvironment",false,false)[0].environment
	environment.background_color = Color("e7e3db").srgb_to_linear()
	environment.ambient_light_color = Color("e1e5de").srgb_to_linear()
	environment.ambient_light_energy = .60
	environment.tonemap_exposure = 1.0
	for light in find_children("*","DirectionalLight3D",false,false):
		if light.shadow_enabled:
			light.light_energy = 1.4
			light.light_angular_distance = .8
			light.directional_shadow_max_distance = 85
	for instance in get_node("Visual").find_children("Glass*","MeshInstance3D",true,false):
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-6,-1,4,8]:
		var fill := OmniLight3D.new()
		fill.position = Vector3(x,2.65,-.1)
		fill.light_color = Color("ffe1b4")
		fill.light_energy = .7
		fill.omni_range = 4.2
		add_child(fill)
	_create_walker()
	_overview()
	_create_help()
	if "--capture-ustc1958" in OS.get_cmdline_user_args():
		pause_wind = true
		set_process_unhandled_input(false)
		player.set_process_unhandled_input(false)
		get_node("Help").hide()
		_capture.call_deferred()

func _instantiate_shared_kit() -> void:
	assets = Node3D.new()
	assets.name = "SharedAssets"
	add_child(assets)
	var library: Node3D = load("res://samples/ustc1958/assets/ustc1958_shared_library.glb").instantiate()
	var unique_meshes: Dictionary = {}
	var mesh_count := 0
	for item in manifest.instances:
		var prototype: Node3D = library.find_child(item.asset,true,false)
		var instance: Node3D = prototype.duplicate()
		instance.name = item.name
		instance.position = Vector3(item.position[0],item.position[1],item.position[2])
		instance.rotation.y = item.yaw
		instance.scale = Vector3.ONE * item.scale
		assets.add_child(instance)
		for mesh in instance.find_children("*","MeshInstance3D",true,false):
			unique_meshes[mesh.mesh.get_rid().get_id()] = true
			mesh_count += 1
	report["kit_instances"] = manifest.instances.size()
	report["shared_mesh_instances"] = mesh_count
	report["shared_unique_meshes"] = unique_meshes.size()
	library.free()

func _batch_repeated_geometry() -> void:
	var groups: Dictionary = {}
	var meshes: Array = get_node("Visual").find_children("*","MeshInstance3D",true,false)
	meshes.append_array(assets.find_children("*","MeshInstance3D",true,false))
	for instance in meshes:
		var n := str(instance.name)
		# Animated crown meshes retain their individual transforms.
		if n.begins_with("CrownClump_"):continue
		var transparent := false
		for surface in instance.mesh.get_surface_count():
			var material: Material = instance.mesh.surface_get_material(surface)
			if material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:transparent = true
		if transparent:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if not n.begins_with("NorthTube_"):continue
		var key: int = instance.mesh.get_rid().get_id()
		if not groups.has(key):groups[key] = []
		groups[key].append(instance)
	var count := 0
	var batches := 0
	for key in groups:
		var objects: Array = groups[key]
		if objects.size()<2:continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = objects[0].mesh
		multi.instance_count = objects.size()
		var batch := MultiMeshInstance3D.new()
		batch.name = "Batch_"+str(objects[0].name)
		batch.multimesh = multi
		if str(objects[0].name).begins_with("NorthTube_"):batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		for i in objects.size():
			multi.set_instance_transform(i,objects[i].global_transform)
			objects[i].queue_free()
		count += objects.size()
		batches += 1
	report["batched_elements"] = count
	report["geometry_batches"] = batches

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
	player.respawn_position = Vector3(1.625,.14,9.6)
	player.respawn_target = Vector3(1.625,1.8,3)
	player.set_view(player.respawn_position,player.respawn_target)
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _create_help() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Help"
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(22,18)
	label.text = "USTC1958 · 科大东区\n左键拖动旋转 · 右键平移 · 滚轮缩放\n1 入口   2 俯视   3 全景   4 室内   5 北侧\nTab 步行／查看 · WASD 移动 · Shift 疾行 · 空格跳跃\nEsc 释放鼠标 · P 风动 · B 底座 · F12 截图"
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","Segoe UI"])
	label.add_theme_font_override("font",font)
	label.add_theme_color_override("font_color",Color("26332a"))
	label.add_theme_font_size_override("font_size",17)
	layer.add_child(label)

func _set_view(eye: Vector3,focus: Vector3,fov: float) -> void:
	target = focus
	var offset := eye-focus
	radius = offset.length()
	azimuth = atan2(offset.x,offset.z)
	polar = acos(offset.y/radius)
	camera.fov = fov
	_update_camera()

func _overview() -> void:
	_set_view(Vector3(27,21,31),Vector3(-.5,2,-.8),38)

func _pan(delta: Vector2) -> void:
	target += (-camera.global_basis.x*delta.x+camera.global_basis.y*delta.y)*radius*.0009
	target.x = clampf(target.x,-16,16)
	target.z = clampf(target.z,-12,12)
	target.y = clampf(target.y,.2,10)

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
		match event.keycode:
			KEY_1:_set_view(Vector3(1.625,1.99,8.25),Vector3(1.625,1.85,2.8),64);return
			KEY_2:_set_view(Vector3(0,36,.20),Vector3(0,0,0),47);return
			KEY_4:_set_view(Vector3(-7.9,1.99,1.55),Vector3(6.3,1.9,-.1),67);return
			KEY_5:_set_view(Vector3(4.6,4.9,-15),Vector3(1.6,2.4,-6.4),61);return
	super._unhandled_input(event)

func _save(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	var error := get_viewport().get_texture().get_image().save_png(output_dir.path_join(label+".png"))
	if error != OK:push_error("USTC1958 screenshot failed: "+str(error));get_tree().quit(1)

func _capture() -> void:
	for i in 70:await get_tree().process_frame
	if not await _checks():get_tree().quit(1);return
	var views := [
		["overview",Vector3(27,21,31),Vector3(-.5,2,-.8),38.0],
		["entrance",Vector3(1.625,1.99,8.25),Vector3(1.625,1.85,2.8),64.0],
		["facade",Vector3(-3.4,4.2,19.7),Vector3(0,2,4.3),65.0],
		["east_sign",Vector3(19,3.8,7.2),Vector3(9.5,2.9,0),63.0],
		["window",Vector3(7.3,1.94,6.07),Vector3(8.15,2.35,4.19),67.0],
		["terrace",Vector3(-6.3,1.97,8),Vector3(-8.6,1.5,4.9),67.0],
		["north_curve",Vector3(1.3,4.1,-13.4),Vector3(.5,2.3,-6.4),70.0],
		["interior",Vector3(-7.9,1.99,1.55),Vector3(6.3,1.9,-.1),67.0],
		["conference",Vector3(-8.9,1.99,1.52),Vector3(-12.3,1.55,-.15),70.0],
		["plan",Vector3(0,36,.20),Vector3(0,0,0),47.0],
	]
	report["rendering"] = []
	for view in views:
		_set_view(view[1],view[2],view[3])
		for i in 25:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save(view[0])
		report["rendering"].append({"view":view[0],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	report["collision_shapes"] = get_node("Collision").find_children("*","CollisionShape3D",true,false).size()
	var file := FileAccess.open(output_dir.path_join("runtime.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("USTC1958 verified: ",report)
	get_tree().quit()

func _checks() -> bool:
	var facing_checks: Array = []
	for item in manifest.chair_checks:
		var chair: Node3D = assets.get_node(item.name)
		var table: Node3D = assets.get_node(item.table)
		var delta := table.global_position-chair.global_position
		delta.y = 0
		var dot := chair.global_basis.z.normalized().dot(delta.normalized())
		if dot<.99:push_error("Chair faces away from table: "+item.name);return false
		facing_checks.append({"chair":item.name,"toward_table":dot})
	report["chair_facing"] = facing_checks
	player.enabled = true
	player.frozen = false
	player.camera.current = true
	camera.current = false
	report["walk_routes"] = []
	var routes := [
		["street_to_deck",Vector3(1.625,.14,9.6),Vector3(1.625,.38,5.7)],
		["open_entry_to_interior",Vector3(1.625,.38,5.6),Vector3(1.625,.38,-.2)],
		["interior_centre_aisle",Vector3(1.625,.38,-.2),Vector3(-8.3,.38,-.2)],
		["west_conference_entry",Vector3(-8.3,.38,1.45),Vector3(-11.9,.38,1.45)],
		["west_terrace_circulation",Vector3(-10.4,.38,7.2),Vector3(-10.4,.38,4.6)],
	]
	for route in routes:
		var destination: Vector3 = route[2]
		player.set_view(route[1],destination+Vector3(0,1.65,0))
		Input.action_press("forward")
		Input.action_press("jog")
		var steps := 0
		var lowest: float = route[1].y
		while Vector2(player.position.x-destination.x,player.position.z-destination.z).length()>.12 and steps<360:
			await get_tree().physics_frame
			steps += 1
			lowest = minf(lowest,player.position.y)
		Input.action_release("forward")
		Input.action_release("jog")
		var passed := steps<360 and lowest>.08
		report["walk_routes"].append({"name":route[0],"passed":passed,"lowest_y":lowest,"steps":steps,"end":str(player.position)})
		if not passed:push_error("Blocked walking route: "+str(route[0])+" at "+str(player.position));return false
	player.set_view(Vector3(6.3,.38,3.7),Vector3(6.3,1.99,4.8))
	Input.action_press("forward")
	for i in 65:await get_tree().physics_frame
	Input.action_release("forward")
	report["glass_wall_blocks"] = player.position.z<4.0 and player.is_on_wall()
	if not report.glass_wall_blocks:push_error("Glass wall collision failed");return false
	player.set_view(Vector3(-6.7,.38,1.0),Vector3(-6.7,1.99,2.5))
	Input.action_press("forward")
	for i in 75:await get_tree().physics_frame
	Input.action_release("forward")
	report["interior_table_blocks"] = player.position.z<1.85 and player.is_on_wall()
	if not report.interior_table_blocks:push_error("Interior table collision failed");return false
	player.enabled = false
	player.frozen = true
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true
