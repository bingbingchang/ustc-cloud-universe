extends "res://../tools/validate_plaza.gd"
const LIBRARY_OUT="res://../renders/library_district/"
const District=preload("res://scripts/library_district.gd")

func screenshot(name:String):
	player.frozen=true;player.enabled=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(24):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(LIBRARY_OUT+name+".png")
	report.screenshots.append(name+".png")
	player.frozen=false

func save_report():
	report.passed=not report.checks.values().has(false)
	var f=FileAccess.open(LIBRARY_OUT+("visual_validation.json" if "--visual-only" in OS.get_cmdline_user_args() else "validation.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"));f.close();print("LIBRARY_CHECKS ",JSON.stringify(report.checks));quit(0 if report.passed else 1)

func visuals():
	campus.hud.visible=false
	for view in [["01_coffee_west_main_road",Vector3(-77,.26,273),Vector3(-77,1.7,337)],["02_library",Vector3(19,.26,444),Vector3(2.1,5,430)],["03_teaching2",Vector3(91,.15,360),Vector3(143,4,330)],["04_old_library_axis",Vector3(-5,.15,350),Vector3(0,2,370)],["05_pebble_lake_path",Vector3(16,.15,79),Vector3(24,1.1,65)],["06_plaza_branch",Vector3(-27,.15,296),Vector3(-27,1.0,325)]]:
		await place(view[1],view[2]);player.enabled=false;player.set_view(player.position,view[2]);await screenshot(view[0])
	player.frozen=true;campus.photo_camera=Camera3D.new();campus.add_child(campus.photo_camera)
	campus.photo_camera.position=Vector3(-159,149,510);campus.photo_camera.look_at(Vector3(43,0,363),Vector3.UP);campus.photo_camera.fov=62;campus.photo_camera.current=true
	await screenshot("07_overview")
	campus.photo_camera.free();campus.photo_camera=null;player.camera.current=true;player.frozen=false
	for view in [["coffee_main",Vector3(-77,.15,279),Vector3(-77,1,302)],["library_south",Vector3(29,.15,442),Vector3(0,1,442)],["teaching2_lane",Vector3(77,.15,370),Vector3(77,1,392)]]:
		await sample_walk(true,view[1],view[2],view[0]);report.checks["moving_"+view[0]]=report.performance[-1].walked_m>1 and report.performance[-1].focus_ratio==1.0

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LIBRARY_OUT))
	campus=load("res://scenes/campus_game.tscn").instantiate();root.add_child(campus);player=campus.player;await frames(24)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	report.district=campus.world.get_meta("library_district");report.roads=campus.world.get_meta("campus_roads")
	if "--visual-only" in OS.get_cmdline_user_args():await visuals();save_report();return
	Engine.time_scale=8;Engine.physics_ticks_per_second=480
	for route in District.data().walk_routes:
		var points=[]
		for p in route.points:points.append(Vector3(p[0],.14,p[1]))
		report.routes.append(await walk_route(route.id,points))
	report.routes.append(await walk_route("raised_main_sidewalk",[Vector3(-85,.23,278),Vector3(-85,.23,320),Vector3(-85,.23,345),Vector3(-85,.23,397)]))
	report.routes.append(await walk_route("library_stairs",[Vector3(2.1,.14,441.7),Vector3(2.1,.10,437.2),Vector3(2.1,2,431.3)]))
	report.routes.append(await walk_route("original_yuquan",[Vector3(0,.14,12),Vector3(0,.14,97),Vector3(0,.14,150)]))
	report.checks.connected_routes=report.routes.all(func(r):return r.passed)
	report.barriers=[]
	report.barriers.append(await barrier("library_exterior",Vector3(20,.15,437),Vector3(20,.15,419)))
	report.barriers.append(await barrier("teaching2_exterior",Vector3(157,.15,363),Vector3(157,.15,335)))
	report.checks.building_collision=report.barriers.all(func(b):return b.passed)
	var guo={};var narrow={}
	for r in report.roads:
		if r.id=="road_265032055":guo=r
		if r.id=="road_265575543":narrow=r
	report.checks.individual_road_profiles=guo.grade==1 and guo.width>=9 and guo.sidewalk_width>=2 and narrow.grade==2 and narrow.sidewalk_width==0
	var kinds=[]
	for r in report.roads:
		if r.grade not in kinds:kinds.append(r.grade)
	report.checks.three_road_grades=kinds.size()==3
	report.checks.hardscape_and_lawn=report.district.hardscape_zones==5 and campus.world.has_node("MappedCampusLand_library_district_06")
	await place(Vector3(-85,.25,348),Vector3(-85,1,359));var base=player.position.y;var apex=base
	Input.action_press("jump");await frames(3);Input.action_release("jump")
	for i in range(65):await frames(1);apex=maxf(apex,player.position.y)
	report.jump_height=apex-base;report.checks.jump_and_land=apex-base>.8 and player.is_on_floor()
	save_report()
