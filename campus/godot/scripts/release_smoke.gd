extends RefCounted
static func frames(c:Node,count:int):
	for i in range(count):
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;await c.get_tree().physics_frame
static func key(c:Node,code:Key):
	var e=InputEventKey.new();e.keycode=code;e.pressed=true;Input.parse_input_event(e);await frames(c,2)
	e=InputEventKey.new();e.keycode=code;e.pressed=false;Input.parse_input_event(e);await frames(c,2)
static func run(c:Node3D):
	c.get_window().grab_focus();await frames(c,90)
	var checks={};var p=c.player;var start=p.position
	Input.action_press("forward");await frames(c,60);Input.action_release("forward")
	checks.walk=p.position.distance_to(start)>1
	await frames(c,10)
	await key(c,KEY_V);checks.free_camera=p.free_camera
	# The avatar can still decelerate before the V event is processed. Measure
	# the flight itself, starting after the camera detaches from the spring arm.
	var feet=p.position;var eye=p.camera.global_position
	Input.action_press("up");await frames(c,30);Input.action_release("up")
	checks.fly=p.camera.global_position.y>eye.y+4 and p.position.distance_to(feet)<.01
	await key(c,KEY_V);checks.return_to_avatar=not p.free_camera
	await key(c,KEY_7);checks.housing=p.position.distance_to(Vector3(255,.16,406))<.3
	await key(c,KEY_8);checks.history=p.position.distance_to(Vector3(55.7,.16,523))<.3
	await key(c,KEY_9);checks.research=p.position.distance_to(Vector3(97.6,.16,713.3))<.3
	c.locator.refresh();checks.coordinates=c.locator.latest.center_hit!=null and c.locator.visible
	p.set_view(Vector3(0,.15,108),Vector3(0,1,139));await frames(c,10)
	# QA can write inside its workspace when AppData is restricted. Every check
	# uses a fresh capture and the actual save result, never a previous run's file.
	var output="user://"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--smoke-output="):output=argument.trim_prefix("--smoke-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var capture_name="release_smoke_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	await c.get_tree().process_frame;RenderingServer.force_draw()
	checks.screenshot=c.get_viewport().get_texture().get_image().save_png(output+capture_name+".png")==OK
	c.locator.refresh()
	var context=FileAccess.open(output+capture_name+".json",FileAccess.WRITE)
	checks.context=context!=null
	if context:context.store_string(JSON.stringify(c.locator.latest,"\t"));context.close()
	var report={"passed":not checks.values().has(false),"checks":checks,"engine":Engine.get_version_info().string,"exported":not OS.has_feature("editor"),"user_directory":OS.get_user_data_dir(),"output_directory":ProjectSettings.globalize_path(output)}
	var license=FileAccess.open(output+"GODOT_LICENSE.txt",FileAccess.WRITE)
	if license:license.store_string(Engine.get_license_text());license.close()
	var third=FileAccess.open(output+"GODOT_THIRD_PARTY.json",FileAccess.WRITE)
	if third:third.store_string(JSON.stringify({"licenses":Engine.get_license_info(),"components":Engine.get_copyright_info()},"\t"));third.close()
	var file=FileAccess.open(output+"release_smoke.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(report,"\t"));file.close()
	print("RELEASE_SMOKE ",JSON.stringify(report));c.get_tree().quit(0 if report.passed else 1)
