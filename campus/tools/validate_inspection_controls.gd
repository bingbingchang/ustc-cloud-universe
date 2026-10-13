extends "res://../tools/validate_gameplay.gd"
const CHECK_OUT="res://../renders/inspection_controls/"
func key(code:Key):
	var event=InputEventKey.new();event.keycode=code;event.pressed=true;Input.parse_input_event(event);await frames(2)
	event=InputEventKey.new();event.keycode=code;event.pressed=false;Input.parse_input_event(event);await frames(2)
func shot(name:String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(CHECK_OUT+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHECK_OUT))
	campus=load("res://scenes/campus_game.tscn").instantiate();root.add_child(campus);player=campus.player;await frames(30)
	await place(Vector3(-236,.16,589),Vector3(-207,1.5,607));campus.locator.refresh()
	report.checks.coordinates_visible=campus.locator.visible and campus.locator.latest.center_hit!=null
	report.player=campus.locator.latest.duplicate(true);await shot("01_player_coordinates")
	var feet=player.global_position;var eye=player.camera.global_transform
	await key(KEY_V);report.checks.keyboard_fly=player.free_camera
	Input.action_press("up");Input.action_press("forward");await frames(60);Input.action_release("up");Input.action_release("forward")
	report.checks.fly_moves_without_avatar=player.global_position.distance_to(feet)<.001 and player.camera.global_position.y>eye.origin.y+8
	campus.locator.refresh();report.free_camera=campus.locator.latest.duplicate(true);campus.hud.visible=false
	report.checks.coordinates_survive_hidden_hud=campus.locator.visible;await shot("02_free_camera_coordinates")
	await key(KEY_V);report.checks.return_preserves_position=not player.free_camera and player.global_position.distance_to(feet)<.01 and player.camera.global_position.distance_to(eye.origin)<.05
	campus.hud.visible=true;campus.control_buttons[1].pressed.emit();await frames(3);report.checks.button_free_camera=player.free_camera
	campus.control_buttons[0].pressed.emit();await frames(3);report.checks.button_avatar=not player.free_camera
	await key(KEY_7);var housing=player.position
	await key(KEY_8);var history=player.position
	await key(KEY_9);var research=player.position
	report.checks.region_shortcuts=housing.distance_to(Vector3(255,.16,406))<.3 and history.distance_to(Vector3(55.7,.16,523))<.3 and research.distance_to(Vector3(97.6,.16,713.3))<.3
	await key(KEY_V);await key(KEY_8)
	report.checks.free_camera_region_jump=player.free_camera and player.camera.global_position.distance_to(player.global_position+Vector3.UP*1.65)<.1
	await key(KEY_V)
	await key(KEY_C);var hidden=not campus.locator.visible;await key(KEY_C);report.checks.coordinate_toggle=hidden and campus.locator.visible
	await campus.capture("inspection_controls/03_screenshot_context")
	var context=JSON.parse_string(FileAccess.get_file_as_string(CHECK_OUT+"03_screenshot_context.json"))
	report.checks.screenshot_context=context.has("center_hit") and context.has("camera") and context.has("player")
	report.routes.append(await walk_route("walk_after_camera_switch",[Vector3(-271,.14,593),Vector3(-271,.14,622)]));report.checks.avatar_still_walks=report.routes[-1].passed
	campus.queue_free();await frames(3)
	for action in ["forward","back","left","right","jog","jump","up","down"]:InputMap.erase_action(action)
	campus=load("res://scenes/lookdev_live.tscn").instantiate();root.add_child(campus);player=campus.player;await frames(24)
	await key(KEY_V);await frames(3);campus.locator.refresh()
	report.checks.photography_coordinates=campus.locator.visible and campus.locator.latest.mode in ["自由相机","摄影相机"];await shot("04_photography_coordinates")
	# Native 4K photography renders into its own viewport, including the locator.
	player.frozen=true;campus.photo_view=SubViewport.new();campus.photo_view.size=Vector2i(3840,2160)
	campus.photo_view.world_3d=campus.get_viewport().world_3d;campus.photo_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;campus.add_child(campus.photo_view)
	campus.photo_camera=Camera3D.new();campus.photo_view.add_child(campus.photo_camera);campus.photo_camera.global_transform=player.camera.global_transform;campus.photo_camera.fov=player.camera.fov;campus.photo_camera.current=true
	campus.locator.queue_free();await frames(3);campus.locator=preload("res://scripts/scene_locator.gd").new();campus.locator.campus=campus;campus.photo_view.add_child(campus.locator)
	await frames(8);await campus.capture("inspection_controls/05_native4k_coordinates")
	report.checks.native4k_coordinates=campus.locator.get_viewport()==campus.photo_view and campus.locator.readout.get_theme_font_size("font_size")>=30
	var native_image=Image.load_from_file(CHECK_OUT+"05_native4k_coordinates.png")
	report.checks.native4k_capture=native_image.get_size()==Vector2i(3840,2160)
	report.passed=not report.checks.values().has(false)
	var f=FileAccess.open(CHECK_OUT+"validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("INSPECTION_CHECKS ",JSON.stringify(report.checks));quit(0 if report.passed else 1)
