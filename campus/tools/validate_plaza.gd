extends "res://../tools/validate_gameplay.gd"
const PLAZA_OUT="res://../renders/plaza_expansion/"

func screenshot(name:String):
	var was_frozen=player.frozen;player.frozen=true
	for i in range(30):await process_frame
	await RenderingServer.frame_post_draw
	var result=root.get_texture().get_image().save_png(PLAZA_OUT+name+".png")
	report.screenshots.append({"file":name+".png","saved":result==OK,"feet":str(player.position),"camera":str(player.camera.global_position)})
	player.frozen=was_frozen

func sample_walk(use_balanced:bool,pos:Vector3,target:Vector3,id:String):
	root.grab_focus()
	campus.apply_quality(use_balanced);await place(pos,target)
	for i in range(90):await process_frame
	var times=[];var previous=Time.get_ticks_usec();var focus=0;var start=player.position
	Input.action_press("forward")
	for i in range(180):
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		await process_frame
		var now=Time.get_ticks_usec();times.append((now-previous)/1000.0);previous=now
		if root.has_focus():focus+=1
	Input.action_release("forward")
	var distance=player.position.distance_to(start);times.sort();var total=0.0
	for t in times:total+=t
	var result={"view":id,"quality":"balanced" if use_balanced else "quality","fps":1000.0/(total/times.size()),"p95_ms":times[int(times.size()*.95)],"walked_m":distance,"focus_ratio":float(focus)/times.size(),"resolution":str(root.size)}
	report.performance.append(result);print("PLAZA_PERF ",JSON.stringify(result))
	await frames(15)

func save_report():
	report.passed=not report.checks.values().has(false)
	var name="performance_before.json" if "--plaza-before" in OS.get_cmdline_user_args() else "validation.json"
	var f=FileAccess.open(PLAZA_OUT+name,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("PLAZA_CHECKS ",JSON.stringify(report.checks))
	quit(0 if report.passed else 1)

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PLAZA_OUT))
	campus=load("res://scenes/campus_game.tscn").instantiate();root.add_child(campus);player=campus.player
	await frames(30)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	if "--refresh-performance" in OS.get_cmdline_user_args():
		report=JSON.parse_string(FileAccess.get_file_as_string(PLAZA_OUT+"validation.json"));report.performance=[]
		for view in [["original_avenue",Vector3(0,.15,108),Vector3(0,1,139)],["plaza_axis",Vector3(-5.7,.15,280),Vector3(-5.7,1,325)],["cafe_approach",Vector3(-43,.15,260),Vector3(-28,1,260)]]:
			await sample_walk(true,view[1],view[2],view[0])
			report.checks["moving_"+view[0]]=report.performance[-1].walked_m>1 and report.performance[-1].focus_ratio==1.0
		save_report();return
	if "--profile-only" in OS.get_cmdline_user_args():
		await sample_walk(true,Vector3(0,.15,108),Vector3(0,1,139),"original_avenue")
		save_report();return
	var spec=load("res://scripts/plaza_environment.gd").spec()
	report.scope="Actual third-person player walks from retained campus into mapped Guo Moruo plaza; no in-route teleportation. Native graphics and 60Hz physical integration."
	report.module=spec.id;report.checks.new_region=campus.world.has_meta("guo_plaza")
	report.npcs=campus.life_layer.actors.size()+campus.wave2_layer.actors.size()+campus.grove_life.actors.size()
	report.checks.population=report.npcs==16
	Engine.time_scale=4;Engine.physics_ticks_per_second=240
	for route in spec.walk_routes:
		var points=[]
		for p in route.points:points.append(Vector3(p[0],.08,p[1]))
		report.routes.append(await walk_route(route.id,points))
	report.routes.append(await walk_route("old_west_join",[Vector3(-104,.08,234.1),Vector3(-89,.08,236.5),Vector3(-82,.08,237.3),Vector3(-78,.08,238),Vector3(-64,.08,250)]))
	report.routes.append(await walk_route("cafe_terrace",[Vector3(-45,.08,260),Vector3(-43,.22,254.4),Vector3(-41,.22,254.6)]))
	report.routes.append(await walk_route("original_avenue",[Vector3(0,.08,55),Vector3(0,.08,105),Vector3(0,.08,139)]))
	report.checks.continuous_walk=report.routes.all(func(r):return r.passed)
	report.barriers=[]
	report.barriers.append(await barrier("plaza_basin",Vector3(-6,.15,265),Vector3(0,.15,265)))
	report.barriers.append(await barrier("cafe_wall",Vector3(-44,.15,260),Vector3(-44,.15,248)))
	report.barriers.append(await barrier("monument",Vector3(-.597,.15,250),Vector3(-.597,.15,244.127)))
	report.barriers.append(await barrier("new_outer_south",Vector3(54,.15,335),Vector3(54,.15,346)))
	report.checks.landmark_collision=report.barriers.all(func(b):return b.passed)
	await place(Vector3(12,.15,280),Vector3(12,1,300))
	var ground=player.position.y;var apex=ground
	Input.action_press("jump");await frames(3);Input.action_release("jump")
	for i in range(65):await frames(1);apex=maxf(apex,player.position.y)
	report.jump_height_m=apex-ground;report.checks.jump_and_land=apex-ground>.80 and player.is_on_floor()
	Engine.time_scale=1;Engine.physics_ticks_per_second=60
	await place(Vector3(9,.15,261),Vector3(-.597,1.8,244.127));await screenshot("01_monument")
	await place(Vector3(-34,.15,268),Vector3(-45,1.7,247.33));await screenshot("02_cafe")
	await place(Vector3(-5.7,.15,279),Vector3(-.6,1.0,331));await screenshot("03_plaza_south")
	player.frozen=true;campus.hud.visible=false
	campus.photo_camera=Camera3D.new();campus.add_child(campus.photo_camera)
	campus.photo_camera.position=Vector3(-105,77,366);campus.photo_camera.look_at(Vector3(-3,0,270),Vector3.UP)
	campus.photo_camera.fov=58;campus.photo_camera.current=true
	await screenshot("04_overview")
	campus.photo_camera.free();campus.photo_camera=null;player.camera.current=true;player.frozen=false;campus.hud.visible=true
	for view in [["original_avenue",Vector3(0,.15,108),Vector3(0,1,139)],["plaza_axis",Vector3(-5.7,.15,280),Vector3(-5.7,1,325)],["cafe_approach",Vector3(-43,.15,260),Vector3(-28,1,260)]]:
		await sample_walk(true,view[1],view[2],view[0])
		report.checks["moving_"+view[0]]=report.performance[-1].walked_m>1 and report.performance[-1].focus_ratio==1.0
	save_report()
