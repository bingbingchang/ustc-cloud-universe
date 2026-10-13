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
	await frames(c,10);var feet=p.position;var eye=p.camera.global_position
	await key(c,KEY_V);checks.free_camera=p.free_camera
	Input.action_press("up");await frames(c,30);Input.action_release("up")
	checks.fly=p.camera.global_position.y>eye.y+4 and p.position.distance_to(feet)<.01
	await key(c,KEY_V);checks.return_to_avatar=not p.free_camera
	await key(c,KEY_7);checks.housing=p.position.distance_to(Vector3(255,.16,406))<.3
	await key(c,KEY_8);checks.history=p.position.distance_to(Vector3(55.7,.16,523))<.3
	await key(c,KEY_9);checks.research=p.position.distance_to(Vector3(97.6,.16,713.3))<.3
	c.locator.refresh();checks.coordinates=c.locator.latest.center_hit!=null and c.locator.visible
	p.set_view(Vector3(0,.15,108),Vector3(0,1,139));await frames(c,10)
	await c.capture("release_smoke")
	checks.screenshot=FileAccess.file_exists("user://screenshots/release_smoke.png")
	checks.context=FileAccess.file_exists("user://screenshots/release_smoke.json")
	var report={"passed":not checks.values().has(false),"checks":checks,"engine":Engine.get_version_info().string,"exported":not OS.has_feature("editor"),"user_directory":OS.get_user_data_dir()}
	var license=FileAccess.open("user://GODOT_LICENSE.txt",FileAccess.WRITE);license.store_string(Engine.get_license_text());license.close()
	var third=FileAccess.open("user://GODOT_THIRD_PARTY.json",FileAccess.WRITE);third.store_string(JSON.stringify({"licenses":Engine.get_license_info(),"components":Engine.get_copyright_info()},"\t"));third.close()
	var file=FileAccess.open("user://release_smoke.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("RELEASE_SMOKE ",JSON.stringify(report));c.get_tree().quit(0 if report.passed else 1)
