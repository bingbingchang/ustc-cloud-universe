extends "res://../tools/validate_plaza.gd"
const NETWORK=preload("res://scripts/campus_network.gd")
const NETWORK_OUT="res://../renders/campus_network/"

func screenshot(name:String):
	var frozen=player.frozen;player.frozen=true
	for i in range(30):await process_frame
	await RenderingServer.frame_post_draw
	var error=root.get_texture().get_image().save_png(NETWORK_OUT+name+".png")
	var camera=campus.photo_camera if campus.photo_camera else player.camera
	report.screenshots.append({"file":name+".png","saved":error==OK,"player":str(player.position),"camera":str(camera.global_position)})
	player.frozen=frozen

func save_report():
	report.passed=not report.checks.values().has(false)
	var f=FileAccess.open(NETWORK_OUT+("visual_validation.json" if "--visual-only" in OS.get_cmdline_user_args() else "validation.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"));f.close()
	print("NETWORK_CHECKS ",JSON.stringify(report.checks));quit(0 if report.passed else 1)

func visuals():
	campus.hud.visible=false
	for view in [["01_qinfeng_trees",Vector3(10,.15,248),Vector3(0,2,232)],["02_tianshi_lake_dorms",Vector3(89,.15,104),Vector3(91,2,56)],["03_plaza_species",Vector3(-20,.15,270),Vector3(32,2,289)],["04_teaching5",Vector3(194,.15,20),Vector3(199,2,6)],["05_new_north_gate",Vector3(111,.15,-49),Vector3(112,2,-72)]]:
		if "--fifth-photo-only" in OS.get_cmdline_user_args() and view[0]!="04_teaching5":continue
		await place(view[1],view[2])
		# Discard cursor recenter events before composing a repeatable gameplay view.
		player.enabled=false;player.set_view(player.position,view[2]);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		await screenshot(view[0])
	if "--fifth-photo-only" in OS.get_cmdline_user_args():return
	player.frozen=true;campus.photo_camera=Camera3D.new();campus.add_child(campus.photo_camera)
	campus.photo_camera.position=Vector3(58,113,154);campus.photo_camera.look_at(Vector3(231,0,-28),Vector3.UP);campus.photo_camera.fov=64;campus.photo_camera.current=true
	await screenshot("06_north_overview")
	campus.photo_camera.free();campus.photo_camera=null;player.camera.current=true;player.frozen=false
	if "--screens-only" in OS.get_cmdline_user_args():return
	for view in [["qinfeng",Vector3(8,.15,232),Vector3(40,1,232)],["tianshi",Vector3(91,.15,93),Vector3(90,1,72)],["north_teaching5",Vector3(171,.15,19),Vector3(198,1,19)],["plaza",Vector3(-5.7,.15,280),Vector3(-5.7,1,310)]]:
		await sample_walk(true,view[1],view[2],view[0])
		report.checks["moving_"+view[0]]=report.performance[-1].walked_m>1 and report.performance[-1].focus_ratio==1.0

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NETWORK_OUT))
	campus=load("res://scenes/campus_game.tscn").instantiate();root.add_child(campus);player=campus.player
	await frames(30)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	report.roads=campus.world.get_meta("campus_roads")
	report.trees=campus.world.get_meta("campus_tree_planting")
	report.north_academic=campus.world.get_meta("north_academic")
	if "--entry-only" in OS.get_cmdline_user_args():
		report=JSON.parse_string(FileAccess.get_file_as_string(NETWORK_OUT+"validation.json"))
		Engine.time_scale=4;Engine.physics_ticks_per_second=240
		report.routes.append(await walk_route("fifth_frontage_path",[Vector3(177.357,.13,10.043),Vector3(188,.10,10.5),Vector3(199.09,.10,10.617),Vector3(199.09,.16,8.2)]))
		report.checks.fifth_frontage_path=report.routes[-1].passed
		save_report();return
	if "--visual-only" in OS.get_cmdline_user_args():
		if "--screens-only" in OS.get_cmdline_user_args():
			report=JSON.parse_string(FileAccess.get_file_as_string(NETWORK_OUT+"visual_validation.json"))
			if "--fifth-photo-only" in OS.get_cmdline_user_args():report.screenshots=report.screenshots.filter(func(s):return s.file!="04_teaching5.png")
			else:report.screenshots=[]
		await visuals();save_report();return
	Engine.time_scale=8;Engine.physics_ticks_per_second=480
	for route in NETWORK.data().walk_routes:
		var points=[]
		for p in route.points:points.append(Vector3(p[0],.13,p[1]))
		report.routes.append(await walk_route(route.id,points))
	report.routes.append(await walk_route("courtyard_to_qinfeng",[Vector3(0,.08,201),Vector3(0,.08,225),Vector3(-.929,.13,232.06)]))
	report.routes.append(await walk_route("plaza_to_qinfeng",[Vector3(-5.7,.08,280),Vector3(-5.7,.08,255),Vector3(-7,.13,232)]))
	report.routes.append(await walk_route("original_yuquan",[Vector3(0,.13,12),Vector3(0,.13,97),Vector3(0,.13,150)]))
	report.routes.append(await walk_route("fifth_frontage_path",[Vector3(177.357,.13,10.043),Vector3(188,.10,10.5),Vector3(199.09,.10,10.617),Vector3(199.09,.16,8.2)]))
	report.checks.fifth_frontage_path=report.routes[-1].passed
	report.checks.connected_road_routes=report.routes.all(func(r):return r.passed)
	report.barriers=[]
	report.barriers.append(await barrier("teaching5_shell",Vector3(219,.15,19),Vector3(219,.15,-7)))
	report.barriers.append(await barrier("administration_shell",Vector3(177,.15,-31),Vector3(177,.15,-46)))
	report.barriers.append(await barrier("management_shell",Vector3(304,.15,-25),Vector3(304,.15,-43)))
	var tree={}
	for t in campus.lookdev_tree_contacts:
		if String(t.asset).begins_with("tree_plane"):tree=t;break
	report.barriers.append(await tree_barrier(tree))
	report.checks.building_and_tree_collision=report.barriers.all(func(b):return b.passed)
	await place(Vector3(170,.15,20),Vector3(181,1,20));var floor_y=player.position.y;var apex=floor_y
	Input.action_press("jump");await frames(3);Input.action_release("jump")
	for i in range(65):await frames(1);apex=maxf(apex,player.position.y)
	report.jump_height_m=apex-floor_y;report.checks.north_jump=apex-floor_y>.8 and player.is_on_floor()
	report.checks.mapped_roads_built=report.roads.size()>=24
	report.checks.diverse_mature_trees=report.trees.species_assets.size()==5 and report.trees.count>100
	report.checks.new_buildings=report.north_academic.buildings==4
	Engine.time_scale=1;Engine.physics_ticks_per_second=60
	save_report()

func tree_barrier(tree:Dictionary)->Dictionary:
	await place(tree.position+Vector3(0,.15,3),tree.position)
	Input.action_press("forward");var contacts=[]
	for i in range(220):
		await frames(1)
		for j in player.get_slide_collision_count():
			var hit=player.get_slide_collision(j)
			if hit.get_collider()==campus.get_node(tree.body):
				contacts.append({"body":str(tree.body),"normal":str(hit.get_normal())})
	Input.action_release("forward")
	var remaining=Vector2(player.position.x-tree.position.x,player.position.z-tree.position.z).length()
	return {"id":"new_plane_trunk","passed":not contacts.is_empty() and remaining>.35,"tree_contact":contacts.slice(0,6),"remaining_m":remaining,"final":str(player.position)}
