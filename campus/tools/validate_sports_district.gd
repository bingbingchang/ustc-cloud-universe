extends "res://../tools/validate_plaza.gd"
const SPORTS_OUT="res://../renders/sports_district/"
const District=preload("res://scripts/sports_district.gd")

func screenshot(name:String):
	player.frozen=true;player.enabled=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(24):await process_frame
	await RenderingServer.frame_post_draw
	var result=root.get_texture().get_image().save_png(SPORTS_OUT+name+".png")
	report.screenshots.append({"file":name+".png","saved":result==OK})
	player.frozen=false

func save_report():
	report.passed=not report.checks.values().has(false)
	var f=FileAccess.open(SPORTS_OUT+("visual_validation.json" if "--visual-only" in OS.get_cmdline_user_args() else "validation.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"));f.close();print("SPORTS_CHECKS ",JSON.stringify(report.checks));quit(0 if report.passed else 1)

func visuals():
	campus.hud.visible=false
	for view in [["01_track_entry",Vector3(-187,.16,418),Vector3(-236,2,450)],
		["02_grandstand",Vector3(-238,.16,453),Vector3(-281,3.4,459)],
		["03_dormitory_walk",Vector3(-178,.16,436),Vector3(-124,3,455)],
		["04_guo_road_south",Vector3(-85.5,.25,484),Vector3(-86,2,426)],
		["05_finish_line",Vector3(-184,.16,490),Vector3(-182,1.6,463)],
		["06_library_connection",Vector3(-94,.16,441),Vector3(-132,1.5,440)]]:
		await place(view[1],view[2]);player.enabled=false;player.set_view(player.position,view[2]);await screenshot(view[0])
	player.frozen=true;campus.photo_camera=Camera3D.new();campus.add_child(campus.photo_camera)
	campus.photo_camera.position=Vector3(-365,135,596);campus.photo_camera.look_at(Vector3(-155,0,432),Vector3.UP);campus.photo_camera.fov=62;campus.photo_camera.current=true
	await screenshot("07_overview")
	campus.photo_camera.free();campus.photo_camera=null;player.camera.current=true;player.frozen=false
	report.checks.screenshots_saved=report.screenshots.all(func(s):return s.saved)
	for view in [["track",Vector3(-184,.16,454),Vector3(-184,1,480)],
		["dormitory_lane",Vector3(-107,.16,440.7),Vector3(-149,1,440.7)],
		["retained_library",Vector3(29,.16,442),Vector3(0,1,442)]]:
		await sample_walk(true,view[1],view[2],view[0]);report.checks["moving_"+view[0]]=report.performance[-1].walked_m>1 and report.performance[-1].focus_ratio==1.0

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SPORTS_OUT))
	campus=load("res://scenes/campus_game.tscn").instantiate();root.add_child(campus);player=campus.player;await frames(24)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	report.district=campus.world.get_meta("sports_district");report.scope="Actual third-person physical walking; mapped roads connect retained coffee/library areas to track and dormitories."
	if "--visual-only" in OS.get_cmdline_user_args():await visuals();save_report();return
	Engine.time_scale=8;Engine.physics_ticks_per_second=480
	for route in District.data().walk_routes:
		var points=[]
		for p in route.points:points.append(Vector3(p[0],.14,p[1]))
		report.routes.append(await walk_route(route.id,points))
	report.routes.append(await walk_route("grandstand_steps",[Vector3(-273,.1,420),Vector3(-275,.8,420),Vector3(-279,2.0,420)]))
	report.checks.connected_routes=report.routes.all(func(r):return r.passed)
	report.barriers=[]
	report.barriers.append(await barrier("dorm320_exterior",Vector3(-112,.15,428),Vector3(-112,.15,415)))
	report.barriers.append(await barrier("dorm323_exterior",Vector3(-151,.15,545),Vector3(-151,.15,531)))
	report.barriers.append(await barrier("grandstand_pavilion",Vector3(-272,.15,458),Vector3(-283,.15,458)))
	report.checks.building_collision=report.barriers.all(func(b):return b.passed)
	report.checks.sports_scope=report.district.lanes==8 and report.district.buildings==5 and report.district.trees>40
	var road_profiles=campus.world.get_meta("campus_roads")
	report.checks.graded_roads=road_profiles.any(func(r):return r.id=="road_265032055" and r.grade==1 and r.sidewalk_width==2.0) and road_profiles.any(func(r):return r.id=="road_1135310345" and r.grade==2 and r.sidewalk_width==0) and road_profiles.any(func(r):return r.id=="road_308701271" and r.grade==3)
	await place(Vector3(-225,.15,456),Vector3(-225,1,476));var base=player.position.y;var apex=base
	Input.action_press("jump");await frames(3);Input.action_release("jump")
	for i in range(65):await frames(1);apex=maxf(apex,player.position.y)
	report.jump_height=apex-base;report.checks.jump_and_land=apex-base>.8 and player.is_on_floor()
	save_report()
