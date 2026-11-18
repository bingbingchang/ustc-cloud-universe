extends SceneTree

const MAPPED_VIEWS := {
	"auditorium": [
		[Vector3(-67,2.2,716),Vector3(-98.2,4.15,717),47.0],
		[Vector3(-77,2.35,730),Vector3(-98.5,3.8,718),52.0],
		[Vector3(-92,2.35,724),Vector3(-98.45,3.1,721),66.0]],
	"activity": [
		[Vector3(89,2.35,488),Vector3(124.7,9.6,488),56.0],
		[Vector3(99,2.35,502),Vector3(125,7.1,488),59.0],
		[Vector3(112,1.85,487.8),Vector3(137,4.2,487.8),68.0]],
	"archives": [
		[Vector3(88,2.25,586),Vector3(106,2.8,574),62.0],
		[Vector3(96.4,2.10,582),Vector3(106.1,2.7,578),60.0],
		[Vector3(99.7,1.85,562.5),Vector3(106,2.1,569),67.0]],
}
const LIBRARY_VIEWS := {
	"new-library": [
		[Vector3(2.55,2.45,452.19),Vector3(2.85,10.6,429.5),58.0],
		[Vector3(18.2,2.45,448.0),Vector3(2.85,10.0,429.4),67.0],
		[Vector3(1.85,1.75,438.2),Vector3(2.85,4.6,430.8),69.0]],
	"old-library": [
		[Vector3(.98,2.2,344.24),Vector3(1.16,6.85,369.4),60.0],
		[Vector3(-9.3,2.25,351.6),Vector3(1.16,6.3,369.4),64.0],
		[Vector3(2.05,1.76,363.25),Vector3(1.16,3.35,368.9),69.0]],
	"teaching-two": [
		[Vector3(149.11,2.20,373.6),Vector3(149.35,6.3,355.5),64.0],
		[Vector3(159.0,2.15,367.0),Vector3(149.35,4.7,355.3),61.0],
		[Vector3(146.7,1.76,359.5),Vector3(149.35,2.2,354.4),68.0]],
	"gifted-young": [
		[Vector3(98.02,1.91,279.5),Vector3(97.71,6.66,293),62.0],
		[Vector3(91.0,2.2,277.7),Vector3(97.71,6.15,293.15),64.0],
		[Vector3(98.75,1.76,285.5),Vector3(97.71,4.50,292.33),65.0]],
	"canteen": [
		[Vector3(150.27,2.15,371.0),Vector3(150.18,5.9,389),62.0],
		[Vector3(136.65,2.25,376.0),Vector3(150.18,5.4,389),63.0],
		[Vector3(150.21,1.76,383.5),Vector3(150.18,2.85,390.1),68.0]],
}

var game
var player
var phase := "after"
var groups := "mapped"
var out := ""
var survey_path := ""
var survey := {}
var checks := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--photo-output="):
			out = arg.trim_prefix("--photo-output=")
		elif arg == "--photo-before":
			phase = "before"
		elif arg == "--photo-library":
			groups = "library"
		elif arg.begins_with("--photo-survey="):
			survey_path = arg.trim_prefix("--photo-survey=")
	call_deferred("run")


func probe(from: Vector3, to: Vector3) -> Dictionary:
	return game.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from,to,1,[player.get_rid()]))


func hit(from: Vector3, to: Vector3, expected: String) -> bool:
	var result := probe(from,to)
	return not result.is_empty() and str(result.collider.name).contains(expected)


func capture(name: String, index: int, view: Array) -> void:
	var camera: Camera3D = player.camera
	camera.global_position = view[0]
	camera.look_at(view[1])
	camera.fov = view[2]
	for frame in 10:
		await process_frame
		await RenderingServer.frame_post_draw
	var label: String = ["front","angle","approach"][index] if index<3 else "view-%d" % (index+1)
	var file := "%s-%s-%s.jpg" % [phase,name,label]
	var saved := root.get_texture().get_image().save_jpg(out.path_join(file),.9) == OK
	checks[file] = saved


func walk(id: String, start: Vector3, target: Vector3, tolerance: float) -> void:
	player.set_view(start,target)
	for frame in 10:
		await physics_frame
	var upper := start.y
	var lower := start.y
	player.touch_move = Vector2(0,-1)
	for frame in ceil(start.distance_to(target)/5.2*60.0)+180:
		await physics_frame
		if player.touch_move==Vector2.ZERO:
			player.touch_move=Vector2(0,-1)
		upper = maxf(upper,player.position.y)
		lower = minf(lower,player.position.y)
		if Vector2(player.position.x,player.position.z).distance_to(Vector2(target.x,target.z)) < tolerance:
			break
	player.touch_move = Vector2.ZERO
	var remaining := Vector2(player.position.x,player.position.z).distance_to(Vector2(target.x,target.z))
	checks[id] = remaining < tolerance and lower > -.08
	print("PHOTO_WALK ",id," ok=",checks[id]," feet=",player.position," remaining=",remaining,
		" max_y=",upper," min_y=",lower)
	if not checks[id]:
		for i in player.get_slide_collision_count():
			var collision=player.get_slide_collision(i)
			var body=collision.get_collider()
			if body:
				print("PHOTO_BLOCKER ",id," ",body.get_meta("source_label",body.name)," at=",collision.get_position())


func run() -> void:
	if out.is_empty():
		push_error("Set --photo-output to a directory")
		quit(1)
		return
	if not survey_path.is_empty():
		var config = JSON.parse_string(FileAccess.get_file_as_string(survey_path))
		if not config is Dictionary or not config.has("views") or not config.has("id"):
			push_error("Invalid photo survey file")
			quit(1)
			return
		survey=config
	DirAccess.make_dir_recursive_absolute(out)
	game = load("res://scenes/campus_game.tscn").instantiate()
	root.add_child(game)
	player = game.player
	player.enabled = false
	player.frozen = true
	player.set_free_camera(true)
	player.avatar.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in game.get_children():
		if child is CanvasLayer:
			child.hide()
	game.hero_interactions.layer.hide()
	var views := LIBRARY_VIEWS if groups == "library" else MAPPED_VIEWS
	if not survey.is_empty():
		views={}
		for name in survey.views:
			views[name]=[]
			for view in survey.views[name]:
				views[name].append([point(view[0]),point(view[1]),float(view[2])])
	for name in views:
		for index in views[name].size():
			await capture(name,index,views[name][index])
	if phase == "after":
		player.set_free_camera(false)
		player.frozen = false
		player.enabled = true
		player.touch_mode = true
		await physics_frame
		if not survey.is_empty():
			await survey_routes()
		elif groups == "library":
			await library_routes()
		else:
			await mapped_routes()
	var passed := not checks.values().has(false)
	var suffix := "-library" if groups == "library" else "-entrances"
	if not survey.is_empty():
		suffix="-"+str(survey.id)
	var file := FileAccess.open(out.path_join(phase+suffix+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks},"	"))
	file.close()
	print("PHOTO_ENTRANCES ",JSON.stringify(checks))
	quit(0 if passed else 1)


func point(a: Array) -> Vector3:
	return Vector3(a[0],a[1],a[2])


func survey_routes() -> void:
	for route in survey.get("walks",[]):
		var target:=point(route.target)
		await walk(route.id,point(route.start),target,route.get("tolerance",.30))
		checks[route.id+"_height"]=absf(player.position.y-target.y)<route.get("height_tolerance",.09)
	for ray in survey.get("rays",[]):
		var source:=point(ray.from)
		var target:=point(ray.to)
		var result:=probe(source,target)
		var collider: String=str(result.collider.get_meta("source_label",result.collider.name)) if not result.is_empty() else ""
		checks[ray.id]=collider.is_empty() if ray.body.is_empty() else collider.contains(ray.body)
		print("PHOTO_RAY ",ray.id," ok=",checks[ray.id]," hit=",collider)


func mapped_routes() -> void:
		checks["auditorium_stair_solid"] = hit(Vector3(-96.2,3,717.25),Vector3(-96.2,.12,717.25),"271958271_step")
		checks["auditorium_door_closed"] = hit(Vector3(-95.8,1.5,717.3),Vector3(-98.8,1.5,717.3),"271958271_hall")
		checks["activity_core_closed"] = hit(Vector3(134,1.35,488),Vector3(138.9,1.35,488),"267624861_closed_core")
		checks["activity_court_open"] = probe(Vector3(109,1.35,488),Vector3(133,1.35,488)).is_empty()
		checks["archive_gate"] = hit(Vector3(104,1.35,581.4),Vector3(107,1.35,581.4),"271958263_closed_gate")
		checks["archive_stair"] = hit(Vector3(105.2,2.3,575.18),Vector3(105.2,.12,575.18),"271958263_archive_short")
		await walk("auditorium_cross_apron",Vector3(-88,.15,717.3),Vector3(-93.8,.15,717.3),.45)
		await walk("auditorium_climb",Vector3(-94.65,.15,717.3),Vector3(-97.45,.95,717.3),.18)
		checks["auditorium_landing_height"] = is_equal_approx(snappedf(player.position.y,.01),.95)
		await walk("activity_walk_under_portico",Vector3(97.0,.15,488),Vector3(134.15,.153,488),.42)
		await walk("activity_walk_back_to_road",Vector3(134.15,.153,488),Vector3(97.0,.15,488),.42)
		await walk("archive_approach",Vector3(98.08,.14,581.45),Vector3(104,.14,581.4),.44)
		await walk("archive_side_lane",Vector3(101.62,.14,579.9),Vector3(101.62,.14,562.0),.42)
		await walk("archive_stair_climb",Vector3(105.12,.13,576.7),Vector3(105.3,1.16,573.35),.30)
		checks["archive_lower_landing_height"] = absf(player.position.y-1.16)<.06


func library_routes() -> void:
	await walk("library_left_stair",Vector3(7.70,.15,437.8),Vector3(7.70,3.18,430.34),.24)
	checks["library_left_landing"] = absf(player.position.y-3.18)<.06
	await walk("library_right_stair",Vector3(-2.25,.15,437.8),Vector3(-2.25,3.18,430.32),.24)
	checks["library_right_landing"] = absf(player.position.y-3.18)<.06
	await walk("library_lower_front",Vector3(2.70,.15,437.0),Vector3(2.78,.14,426.98),.29)
	checks["library_lower_headroom"] = player.position.y < .21
	checks["library_lower_closed"] = hit(Vector3(2.82,1.35,427.0),Vector3(2.82,1.35,424.8),"south_library_closed_exterior")
	await walk("old_library_stair",Vector3(1.10,.15,364.3),Vector3(1.15,1.42,368.91),.23)
	checks["old_library_landing"] = absf(player.position.y-1.42)<.06
	await walk("teaching_two_portico",Vector3(149.23,.15,360.2),Vector3(149.34,.147,353.49),.28)
	checks["teaching_two_door_closed"] = hit(Vector3(149.34,1.40,353.54),Vector3(149.34,1.40,351.9),"south_teaching2_closed_exterior")
	await walk("gifted_school_stair",Vector3(97.64,.15,286.6),Vector3(97.7,2.24,292.69),.21)
	checks["gifted_school_landing"] = absf(player.position.y-2.24)<.06
	await walk("canteen_front_steps",Vector3(150.22,.15,383.8),Vector3(150.18,.445,388.85),.25)
	checks["canteen_front_landing"] = absf(player.position.y-.445)<.06
	await walk("canteen_upper_west_stair",Vector3(143.83,.445,384.91),Vector3(143.77,2.96,390.43),.21)
	checks["canteen_upper_landing"] = absf(player.position.y-2.96)<.08
