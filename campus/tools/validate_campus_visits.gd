extends SceneTree
## Runs from the rendered Windows gameplay scene. Injected E events traverse
## the same input path as a real key press, including GUI and NPC arbitration.

var game
var player
var output := ""
var only := ""
var results := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visit-output="):
			output=arg.trim_prefix("--visit-output=")
		if arg.begins_with("--visit-only="):
			only=arg.trim_prefix("--visit-only=")
	call_deferred("run")


func verify(name: String, passed: bool) -> void:
	results[name]=passed
	print("VISIT_CHECK ",name," ",passed)


func wait_physics(count: int) -> void:
	for i in count:
		await physics_frame
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED


func key_e() -> void:
	var event := InputEventKey.new()
	event.keycode=KEY_E
	event.pressed=true
	Input.parse_input_event(event)
	await wait_physics(2)
	event=InputEventKey.new()
	event.keycode=KEY_E
	Input.parse_input_event(event)
	await wait_physics(2)


func orient(feet: Vector3, toward: Vector3) -> void:
	player.set_view(feet,toward)
	await wait_physics(8)


func walk(target: Vector3, ticks: int=115, expected_level: bool=true) -> bool:
	var previous: Vector2 = player.touch_move
	for i in ticks:
		player.touch_move=Vector2(0,-.40)
		await wait_physics(1)
		var feet: Vector3 = player.position
		if Vector2(feet.x,feet.z).distance_to(Vector2(target.x,target.z)) < .11:
			break
	player.touch_move=previous
	await wait_physics(10)
	var feet: Vector3 = player.position
	var horizontal := Vector2(feet.x-target.x,feet.z-target.z).length()
	return horizontal<.25 and player.is_on_floor() and (not expected_level or absf(feet.y-target.y)<.13)


func capture_inside(room,door) -> void:
	if output.is_empty():
		return
	var camera: Camera3D = player.camera
	var before := camera.global_transform
	var visible: bool = game.hud.visible
	var locator_visible: bool = game.locator.visible
	player.frozen=true
	player.set_free_camera(true)
	player.avatar.hide()
	game.hud.hide()
	game.hero_interactions.layer.hide()
	game.campus_agent.layer.hide()
	game.locator.visible=false
	camera.global_position=door.to_global(Vector3(0,1.62,.75))
	camera.look_at(room.to_global(Vector3(0,1.47,float(room.spec.depth)-.2)))
	for i in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	var path := output.path_join("interior-"+str(room.spec.id)+"-"+str(door.door_id)+".jpg")
	verify(str(room.spec.id)+"/"+str(door.door_id)+"/capture",
		root.get_texture().get_image().save_jpg(path,.91)==OK)
	player.set_free_camera(false)
	camera.global_transform=before
	player.avatar.visible=player.third_person
	game.hud.visible=visible
	game.hero_interactions.layer.show()
	game.campus_agent.layer.show()
	game.locator.visible=locator_visible
	player.frozen=false


func check_door(room,door,capture: bool) -> void:
	var id := str(room.spec.id)+"/"+str(door.door_id)+"/"
	var center: Vector3 = door.global_position
	var outside: Vector3 = door.to_global(Vector3(0,0,-1.75))
	var beyond_swing := maxf(1.84,door.width*.5+.41)
	var inside: Vector3 = door.to_global(Vector3(0,0,beyond_swing))
	door.target_open=false
	await orient(outside,center)
	await wait_physics(35)
	verify(id+"prompt",game.campus_visits.selected==door and game.campus_visits._label.text=="E 开门")
	verify(id+"closed",not await walk(inside,90) and door.to_local(player.position).z<0)
	await orient(outside,center)
	await key_e()
	await wait_physics(31)
	verify(id+"e_opens",door.open_amount==1.0)
	var entered := await walk(inside,140)
	verify(id+"walk_inside",entered)
	if not entered:
		print("VISIT_FEET ",id," local=",door.to_local(player.position)," world=",player.position)
		for i in player.get_slide_collision_count():
			print("VISIT_BLOCK ",player.get_slide_collision(i).get_collider().name)
	if entered and capture:
		await capture_inside(room,door)

	var sweep: Vector3 = door.to_global(Vector3(0,0,.18))
	await orient(sweep,center)
	await key_e()
	await wait_physics(31)
	verify(id+"protected",door.open_amount==1.0)
	await orient(inside,center)
	await key_e()
	await wait_physics(31)
	verify(id+"inside_can_close",door.open_amount==0.0)
	verify(id+"cannot_leave_closed",not await walk(outside,90) and door.to_local(player.position).z>0)
	await orient(inside,center)
	await key_e()
	await wait_physics(31)
	verify(id+"inside_can_reopen",door.open_amount==1.0)
	var exited := await walk(outside,140,false)
	verify(id+"walk_outside",exited)
	if not exited:
		print("VISIT_EXIT_FEET ",id," local=",door.to_local(player.position))
	await orient(outside,center)
	await key_e()
	await wait_physics(31)
	verify(id+"left_closed",door.open_amount==0.0)


func other_contexts(room) -> void:
	var door=room.doors[0]
	var second = room.doors[1] if room.doors.size()>1 else null
	var center: Vector3 = door.global_position
	var outside: Vector3 = door.to_global(Vector3(0,0,-1.70))
	await orient(outside,center)
	if second:
		verify("two_doors_aim_first",game.campus_visits.selected==door)
		await orient(second.to_global(Vector3(0,0,-1.70)),second.global_position)
		verify("two_doors_aim_second",game.campus_visits.selected==second)
		await orient(outside,center)

	var hero=game.hero_interactions.actors.values()[0]
	var old_position: Vector3 = hero.global_position
	var old_home: Vector3=hero.home
	hero.home=door.to_global(Vector3(1.57,0,-1.5))
	hero.global_position=hero.home
	await wait_physics(15)
	verify("npc_near_door",not game.hero_interactions.nearest.is_empty() and not game.hero_interactions.prompt_label.visible)
	await key_e()
	await wait_physics(31)
	verify("door_beats_npc",door.open_amount==1.0 and not game.hero_interactions.panel.visible)
	await key_e()
	await wait_physics(31)
	await orient(outside,outside+(outside-center))
	await wait_physics(8)
	verify("npc_when_looking_away_from_door",game.hero_interactions.prompt_label.visible)
	hero.home=old_home
	hero.global_position=old_position

	await orient(outside,center)
	var field:=LineEdit.new()
	game.hud.add_child(field)
	field.grab_focus()
	await key_e()
	await wait_physics(31)
	verify("typing_keeps_door_closed",door.open_amount==0.0)
	field.queue_free()

	player.set_free_camera(true)
	await wait_physics(4)
	var initial: Vector3=player.camera.global_position
	Input.action_press("up")
	await wait_physics(18)
	Input.action_release("up")
	verify("free_camera_ascends_only",player.camera.global_position.y>initial.y+2 and door.open_amount==0.0)
	player.set_free_camera(false)


func check_teaching_five_ramp(room) -> void:
	var x: float = room.edge_length*.5-1.23
	var foot: Vector3 = room.to_global(Vector3(x,-.35,-5.22))
	var top: Vector3 = room.to_global(Vector3(x,0,-.57))
	var landing: Vector3 = room.doors[1].to_global(Vector3(0,0,-.60))
	await orient(foot,top)
	verify("teaching-five/ramp/up",await walk(top,280))
	await orient(top,landing)
	verify("teaching-five/ramp/reaches_door",await walk(landing,280))
	await orient(landing,top)
	verify("teaching-five/ramp/from_door",await walk(top,280))
	await orient(top,foot)
	verify("teaching-five/ramp/down",await walk(foot,280,false))


func render_at(camera: Camera3D, eye: Vector3, target: Vector3) -> Image:
	camera.global_position=eye
	camera.look_at(target)
	for i in range(6):
		await process_frame
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func sees_marker(image: Image) -> bool:
	var pixel := image.get_pixelv(image.get_size()/2)
	return minf(pixel.r,pixel.b)-pixel.g>.22


func create_surface_marker() -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * .20
	marker.mesh = box
	var fluorescent := StandardMaterial3D.new()
	fluorescent.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fluorescent.albedo_color = Color.MAGENTA
	marker.material_override = fluorescent
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(marker)
	return marker


func check_teaching_five_curtain(room: Node3D) -> void:
	var inside := room.to_global(Vector3(.68, 4.0, 1.30))
	var outside := room.to_global(Vector3(.68, 4.0, -3.0))
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var hud_visible: bool = game.hud.visible
	game.hud.hide()
	var marker := create_surface_marker()
	marker.global_position = inside + Vector3.UP * 1.28
	var view := await render_at(camera, outside + Vector3.UP * 1.28, marker.global_position)
	verify("teaching-five/curtain_glass_reveals_landing", sees_marker(view))
	marker.queue_free()
	camera.queue_free()
	player.camera.make_current()
	game.hud.visible = hud_visible

	await orient(inside, outside)
	var crossed := await walk(outside)
	var feet := room.to_local(player.global_position)
	verify("teaching-five/curtain_blocks_fall", not crossed and feet.z > .20
		and absf(feet.y - 4.0) < .05 and player.is_on_floor())


func sample_world_color(camera: Camera3D, image: Image, point: Vector3) -> Color:
	var rect := camera.get_viewport().get_visible_rect()
	var screen := camera.unproject_position(point)
	if not rect.has_point(screen):
		return Color.TRANSPARENT
	# Canvas scaling can make the camera's coordinates larger than the capture.
	var pixel := Vector2i((screen - rect.position) * Vector2(image.get_size()) / rect.size)
	return image.get_pixelv(pixel)


func check_teaching_one_facade(camera: Camera3D) -> void:
	var eye := Vector3(-.05, .49, 145.98)
	var target := Vector3(.27, 6.30, 167.92)
	var facade := await render_at(camera, eye, target)
	var brick := sample_world_color(camera, facade, Vector3(11.03, 6.30, 167.94))
	var glass := sample_world_color(camera, facade, Vector3(-22.23, 6.30, 168.173))
	verify("teaching-one/interior_keeps_red_facade", brick.r - brick.g > .16)
	verify("teaching-one/interior_keeps_visible_windows", glass.g > glass.r and glass.g < .55)
	var roof_center_stays_red := true
	for offset in [Vector3.ZERO, Vector3(.22, .09, .15), Vector3(-.22, .09, .15)]:
		var view := await render_at(camera, eye + offset, target)
		var center := sample_world_color(camera, view, Vector3(.31, 14.90, 167.94))
		roof_center_stays_red = roof_center_stays_red and center.r - center.g > .16
	verify("teaching-one/upper_center_keeps_red_facade", roof_center_stays_red)


func check_teaching_one_surfaces(room) -> void:
	var door: Node3D = room.doors[0]
	var center := door.global_position
	var outside := door.to_global(Vector3(0,0,-1.75))
	await orient(outside,center)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	player.avatar.hide()
	var hud_layers := [game.hud,game.locator,game.hero_interactions.layer,game.campus_agent.layer]
	var was_visible := {}
	for layer in hud_layers:
		was_visible[layer]=layer.visible
		layer.hide()
	await check_teaching_one_facade(camera)
	var marker := create_surface_marker()
	marker.global_position=door.to_global(Vector3(.37,1.58,3.8))
	var through_glass := await render_at(camera,door.to_global(Vector3(.37,1.58,-2.60)),marker.global_position)
	verify("teaching-one/closed_glass_reveals_room",door.open_amount==0.0 and sees_marker(through_glass))
	marker.hide()
	if not output.is_empty():
		var front := await render_at(camera,Vector3(-1.09,1.92,155.90),Vector3(-.27,1.66,173.81))
		verify("teaching-one/glazing_capture",front.save_jpg(output.path_join("teaching-one-glass.jpg"),.92)==OK)
	await key_e()
	await wait_physics(31)
	var waypoint := door.to_global(Vector3(0,0,1.84))
	var entered := await walk(waypoint,190)
	var floor_point := Vector3(-1.03,room.global_position.y,172.24)
	await orient(player.global_position,floor_point)
	var reached := await walk(floor_point,190)
	verify("teaching-one/deep_floor_support",entered and reached and absf(player.global_position.y-floor_point.y)<.02)
	marker.global_position=floor_point+Vector3(0,.13,0)
	marker.show()
	var floor_view := await render_at(camera,Vector3(-4.32,2.62,172.43),marker.global_position)
	verify("teaching-one/floor_is_visible_at_player_height",sees_marker(floor_view))
	marker.hide()
	if not output.is_empty():
		player.avatar.show()
		var room_view := await render_at(camera,Vector3(-4.32,2.62,172.43),player.global_position+Vector3.UP*.80)
		verify("teaching-one/feet_capture",room_view.save_jpg(output.path_join("teaching-one-floor.jpg"),.92)==OK)
	marker.queue_free()
	camera.queue_free()
	player.camera.make_current()
	player.avatar.visible=player.third_person
	for layer in hud_layers:
		layer.visible=was_visible[layer]


func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Run visit tests in a rendered Windows window.")
		quit(2)
		return
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
	game=load("res://scenes/campus_game.tscn").instantiate()
	root.add_child(game)
	player=game.player
	root.grab_focus()
	player.touch_mode=true
	if not "--visit-third-person" in OS.get_cmdline_user_args():
		player.toggle_view()
	await wait_physics(18)
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/campus_visits.json"))
	if game.campus_visits==null or game.campus_visits.rooms.size()!=catalog.size():
		push_error("An expected visit room failed to register.")
		quit(1)
		return
	for room in game.campus_visits.rooms:
		if only.is_empty() or room.spec.id==only:
			for door in room.doors:
				await check_door(room,door,true)
			if room.spec.id=="teaching-five":
				await check_teaching_five_ramp(room)
				await check_teaching_five_curtain(room)
			elif room.spec.id=="teaching-one":
				await check_teaching_one_surfaces(room)
	if only.is_empty():
		await other_contexts(game.campus_visits.rooms[0])
	var passed := not results.is_empty() and not results.values().has(false)
	if not output.is_empty():
		var file=FileAccess.open(output.path_join("visits.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"passed":passed,"checks":results},"	"))
		file.close()
	print("VISITS_COMPLETE ",passed)
	quit(0 if passed else 1)
