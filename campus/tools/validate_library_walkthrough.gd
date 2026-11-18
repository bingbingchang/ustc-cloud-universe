extends "res://../tools/validate_campus_visits.gd"
## Resource-bounded integration test: real player, door manager, door physics,
## imported mesh, campus coordinates and manifest contacts; no AI or distant map.

const District = preload("res://scripts/library_district.gd")
const North = preload("res://scripts/north_axis_environment.gd")
var source_asset_sha256 := ""

class LibraryHost extends Node3D:
	var world := Node3D.new()
	var player: CharacterBody3D
	var hud := CanvasLayer.new()
	var campus_visits
	var hero_interactions = null
	var campus_agent = null
	func style(node: Node) -> void:
		var painter=load("res://scripts/campus.gd").new()
		painter.style(node)
		painter.free()
	func label(caption: String, size: int, color: Color) -> Label:
		var text := Label.new()
		text.text=caption
		text.add_theme_font_size_override("font_size",size)
		text.add_theme_color_override("font_color",color)
		return text
	func add_visit_opening(outline: PackedVector2Array,bottom: float,top: float,title: String) -> bool:
		return campus_visits.replace_shell(outline,bottom,top,title)
	func _unhandled_input(event):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
			if campus_visits.interact():
				get_viewport().set_input_as_handled()


func capture_inside(room, door) -> void:
	if output.is_empty():return
	await photograph("interior-"+str(door.door_id),
		door.to_global(Vector3(0,1.62,.80)),room.to_global(Vector3(0,1.50,7.9)),70)


func photograph(title: String, eye: Vector3, target: Vector3, fov: float) -> void:
	player.frozen=true
	player.avatar.hide()
	game.hud.hide()
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.fov=fov
	camera.global_position=eye
	camera.look_at(target)
	camera.make_current()
	for i in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	verify("capture_"+title,image.save_jpg(output.path_join(title+".jpg"),.92)==OK)
	camera.queue_free()
	player.camera.make_current()
	player.avatar.visible=player.third_person
	game.hud.show()
	player.frozen=false


func run() -> void:
	source_asset_sha256=FileAccess.get_sha256("res://assets/south_library.glb")
	if DisplayServer.get_name()=="headless":
		push_error("Run this integration test with the rendered Windows backend.")
		quit(2);return
	if output.is_empty():output="res://../renders/library_walkthrough"
	DirAccess.make_dir_recursive_absolute(output)
	game=LibraryHost.new()
	root.add_child(game)
	game.add_child(game.world)
	game.add_child(game.hud)
	var styling=load("res://scripts/campus.gd").new()
	styling.setup_input()
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/library_district_manifest.json"))
	var pose := District.asset_transform(manifest.assets.south_library)
	var model: Node3D=load("res://assets/south_library.glb").instantiate()
	model.name="SouthLibrary"
	model.transform=pose
	game.world.add_child(model)
	styling.style(model)
	styling.free()
	game.player=load("res://scripts/third_person_player.gd").new()
	game.add_child(game.player)
	player=game.player
	player.touch_mode=true
	player.toggle_view()
	game.campus_visits=load("res://scripts/campus_visits.gd").new()
	game.campus_visits.configure(game)
	for solid in manifest.collision_solids:
		if str(solid.name).begins_with("south_library_"):
			North._solid(game,[North.polygon(solid.polygon)],solid.bottom,solid.top,"LibraryDistrict_"+solid.name)
	game.add_child(game.campus_visits)
	var fittings=load("res://scripts/campus_visit_interior.gd")
	fittings.collider(game.world,"LibraryTestGround",Vector3(2.85,-.01,420),Vector3(170,.30,100))
	fittings.mesh_box(game.world,Vector3(2.85,-.01,420),Vector3(170,.30,100),fittings.material(Color("9e9d94")))
	var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("cad9e4")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("d8e5f0")
	environment.ambient_light_energy=.7
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var sky := WorldEnvironment.new()
	sky.environment=environment
	game.add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-36,-32,0)
	sun.light_energy=1.25
	sun.shadow_enabled=true
	game.add_child(sun)
	root.grab_focus()
	await wait_physics(18)
	verify("library_room_registered",game.campus_visits.rooms.size()==1)
	var leaves_hidden := true
	for child in model.get_children():
		if child is MeshInstance3D and "PhotoVisitGlass" in child.name:
			leaves_hidden = leaves_hidden and not child.visible
	verify("temporary_exported_leaves_hidden",leaves_hidden)
	if game.campus_visits.rooms.size()!=1:
		quit(1);return
	var room=game.campus_visits.rooms[0]
	if "--library-capture-only" in OS.get_cmdline_user_args():
		for door in room.doors:
			await capture_inside(room,door)
		await photograph("front",pose*Vector3(0,8,60),pose*Vector3(0,13,-3),57)
		await photograph("entrance",pose*Vector3(15,5,25),pose*Vector3(0,8,-1),63)
		await photograph("side",pose*Vector3(64,13,-12),pose*Vector3(0,13,-12),55)
		await photograph("oblique",pose*Vector3(62,42,57),pose*Vector3(0,13,-10),57)
		var captured := not results.values().has(false)
		var capture_report=FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE)
		capture_report.store_string(JSON.stringify({"passed":captured,"checks":results,
			"source_asset_sha256":source_asset_sha256,"scope":"Final model screenshots and room registration only; movement results remain separately recorded in visits.json."},"\t"))
		capture_report.close()
		print("LIBRARY_CAPTURE_COMPLETE ",captured)
		quit(0 if captured else 1)
		return
	for door in room.doors:
		await check_door(room,door,true)
	for side in [-1,1]:
		var foot: Vector3=pose*Vector3(side*5.91,.15,11.2)
		var landing: Vector3=pose*Vector3(side*5.91,3.18,4.05)
		await orient(foot,landing)
		verify("stair_up_"+str(side),await walk(landing,360))
		var entry: Node3D = room.doors[0] if side > 0 else room.doors[1]
		var outside: Vector3 = entry.to_global(Vector3(0,0,-1.75))
		await orient(landing,outside)
		verify("landing_to_center_door_"+str(side),await walk(outside,300))
		await orient(outside,landing)
		verify("center_door_back_to_stair_"+str(side),await walk(landing,300))
		await orient(landing,foot)
		verify("stair_down_"+str(side),await walk(foot,360,false))
	await photograph("front",pose*Vector3(0,8,60),pose*Vector3(0,13,-3),57)
	await photograph("entrance",pose*Vector3(15,5,25),pose*Vector3(0,8,-1),63)
	await photograph("side",pose*Vector3(64,13,-12),pose*Vector3(0,13,-12),55)
	await photograph("oblique",pose*Vector3(62,42,57),pose*Vector3(0,13,-10),57)
	var passed := not results.is_empty() and not results.values().has(false)
	var file=FileAccess.open(output.path_join("visits.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":results,"source_asset_sha256":source_asset_sha256,
		"scope":"Isolated library with production player, doors, materials and collision manifest; no AI or full-campus scene."},"\t"))
	file.close()
	var capture_checks := {}
	for key in results:
		if str(key).begins_with("capture_"):
			capture_checks[key]=results[key]
	var capture_report=FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE)
	capture_report.store_string(JSON.stringify({"passed":not capture_checks.values().has(false),
		"checks":capture_checks,"source_asset_sha256":source_asset_sha256,
		"scope":"Screenshots captured during this movement validation run."},"\t"))
	capture_report.close()
	print("LIBRARY_WALKTHROUGH_COMPLETE ",passed)
	quit(0 if passed else 1)
