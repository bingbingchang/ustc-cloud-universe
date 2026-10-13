extends "res://../tools/validate_plaza.gd"
const SOUTH_OUT="res://../renders/south_sports/"
const District=preload("res://scripts/south_sports.gd")
const Sports=preload("res://scripts/sports_district.gd")
const North=preload("res://scripts/north_axis_environment.gd")

func screenshot(name:String):
	player.frozen=true;player.enabled=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(24):await process_frame
	await RenderingServer.frame_post_draw
	var result=root.get_texture().get_image().save_png(SOUTH_OUT+name+".png")
	report.screenshots.append({"file":name+".png","saved":result==OK});player.frozen=false

func save_report():
	report.passed=not report.checks.values().has(false)
	var f=FileAccess.open(SOUTH_OUT+("visual_validation.json" if "--visual-only" in OS.get_cmdline_user_args() else "validation.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"));f.close();print("SOUTH_CHECKS ",JSON.stringify(report.checks));quit(0 if report.passed else 1)

func lamp_check():
	var track=North.polygon(Sports.data().track.outer_polygon);var positions=[];var bad=[]
	for n in campus.world.get_children():
		if n is MultiMeshInstance3D and String(n.get_meta("render_asset",""))=="lamp":
			for k in range(n.multimesh.instance_count):
				var p=n.global_transform*n.multimesh.get_instance_transform(k).origin;positions.append([p.x,p.y,p.z])
				if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),track):bad.append([p.x,p.z])
	report.lamps={"actual_instances":positions.size(),"inside_track":bad,"positions":positions}
	report.checks.lamps_outside_track=not positions.is_empty() and bad.is_empty()
	var wrong=[]
	for p in positions:
		for court in District.data().courts:
			if Geometry2D.is_point_in_polygon(Vector2(p[0],p[2]),North.polygon(court.polygon)):wrong.append({"position":p,"court":court.id})
	report.lamps.inside_south_courts=wrong;report.checks.lamps_outside_courts=wrong.is_empty()

func visuals():
	campus.hud.visible=false
	for view in [["01_basketball",Vector3(-224,.16,610),Vector3(-224,2,594)],
		["02_tennis_gate",Vector3(-179,.16,574),Vector3(-166,1,593)],
		["03_dorm_courtyard",Vector3(-295,.16,625),Vector3(-333,4,625)],
		["04_badminton",Vector3(-271,.16,579),Vector3(-307,4,581)],
		["05_lamp_fixed",Vector3(-184,.16,454),Vector3(-175,1.4,438)],
		["06_south_crossroad",Vector3(-241,.16,666),Vector3(-185,2,663)]]:
		await place(view[1],view[2]);player.enabled=false;player.set_view(player.position,view[2]);await screenshot(view[0])
	player.frozen=true;campus.photo_camera=Camera3D.new();campus.add_child(campus.photo_camera)
	campus.photo_camera.position=Vector3(-409,143,735);campus.photo_camera.look_at(Vector3(-211,0,558),Vector3.UP);campus.photo_camera.fov=60;campus.photo_camera.current=true
	await screenshot("07_overview")
	campus.photo_camera.free();campus.photo_camera=null;player.camera.current=true;player.frozen=false
	report.checks.screenshots_saved=report.screenshots.all(func(s):return s.saved)
	for view in [["basketball_lane",Vector3(-271,.16,593),Vector3(-271,1,626)],
		["tennis_walkway",Vector3(-179,.16,600),Vector3(-179,1,620)],
		["dorm_courtyard",Vector3(-295,.16,625),Vector3(-317,1,625)]]:
		await sample_walk(true,view[1],view[2],view[0]);report.checks["moving_"+view[0]]=report.performance[-1].walked_m>1 and report.performance[-1].focus_ratio==1.0

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOUTH_OUT))
	campus=load("res://scenes/campus_game.tscn").instantiate();root.add_child(campus);player=campus.player;await frames(24)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var repair="--repair-routes" in OS.get_cmdline_user_args()
	if repair:report=JSON.parse_string(FileAccess.get_file_as_string(SOUTH_OUT+"validation.json"))
	report.district=campus.world.get_meta("south_sports");lamp_check()
	if "--visual-only" in OS.get_cmdline_user_args():await visuals();save_report();return
	Engine.time_scale=8;Engine.physics_ticks_per_second=480
	for route in District.data().walk_routes:
		if repair and route.id not in ["courts_to_tennis_gates","entry_271958264"]:continue
		if route.id.begins_with("tennis_") and route.id.ends_with("_surface"):continue
		var points=[]
		for p in route.points:points.append(Vector3(p[0],.14,p[1]))
		report.routes=report.routes.filter(func(r):return r.id!=route.id)
		report.routes.append(await walk_route(route.id,points))
	if repair:
		report.checks.connected_routes=report.routes.all(func(r):return r.passed)
		save_report();return
	for ct in District.data().courts:
		if ct.sport!="tennis":continue
		var a=District.point(ct,0,-18.5);var b=District.point(ct,0,-8.0);var end=District.point(ct,3,-4)
		report.routes.append(await walk_route(ct.id+"_gate",[Vector3(a.x,.14,a.y),Vector3(b.x,.14,b.y),Vector3(end.x,.14,end.y)]))
	var lap=[]
	for r in Sports.data().walk_routes:
		if r.id=="track_full_lap":
			for p in r.points:lap.append(Vector3(p[0],.10,p[1]))
	report.routes.append(await walk_route("retained_track_full_lap",lap))
	report.checks.connected_routes=report.routes.all(func(r):return r.passed)
	report.barriers=[]
	report.barriers.append(await barrier("dorm364_exterior",Vector3(-300,.15,592),Vector3(-300,.15,605)))
	report.barriers.append(await barrier("badminton_wall",Vector3(-272,.15,583),Vector3(-295,.15,583)))
	report.barriers.append(await barrier("tennis_net",Vector3(-166.4,.15,590),Vector3(-166.4,.15,599)))
	report.barriers.append(await barrier("tennis_side_fence",Vector3(-163,.15,603),Vector3(-155,.15,603)))
	report.checks.physical_barriers=report.barriers.all(func(b):return b.passed)
	report.checks.district_scope=report.district.courts==10 and report.district.buildings==10 and report.district.trees>40
	await place(Vector3(-224,.15,610),Vector3(-224,1,625));var base=player.position.y;var apex=base
	Input.action_press("jump");await frames(3);Input.action_release("jump")
	for i in range(65):await frames(1);apex=maxf(apex,player.position.y)
	report.jump_height=apex-base;report.checks.jump_and_land=apex-base>.8 and player.is_on_floor()
	save_report()
