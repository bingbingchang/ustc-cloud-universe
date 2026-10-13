extends "res://../tools/validate_plaza.gd"
const FULL_OUT="res://../renders/full_campus/"
const District=preload("res://scripts/full_districts.gd")
const North=preload("res://scripts/north_axis_environment.gd")
func screenshot(name:String):
	player.frozen=true;player.enabled=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(24):await process_frame
	await RenderingServer.frame_post_draw
	var result=root.get_texture().get_image().save_png(FULL_OUT+name+".png")
	report.screenshots.append({"file":name+".png","saved":result==OK,"coordinates":campus.locator.latest.duplicate(true)})
	player.frozen=false
func save_report():
	report.passed=not report.checks.values().has(false)
	var f=FileAccess.open(FULL_OUT+("visual_validation.json" if "--visual-only" in OS.get_cmdline_user_args() else "validation.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"));f.close();print("FULL_CHECKS ",JSON.stringify(report.checks));quit(0 if report.passed else 1)
func lamp_check():
	var playing=[North.polygon(preload("res://scripts/sports_district.gd").data().track.outer_polygon)]
	for court in preload("res://scripts/south_sports.gd").data().courts:playing.append(North.polygon(court.polygon))
	var lamps=[];var bad=[]
	for n in campus.world.get_children():
		if n is MultiMeshInstance3D and String(n.get_meta("render_asset",""))=="lamp":
			for k in range(n.multimesh.instance_count):
				var p=n.global_transform*n.multimesh.get_instance_transform(k).origin;lamps.append([p.x,p.y,p.z])
				for field in playing:
					if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),field):bad.append([p.x,p.z])
	report.lamps={"actual_instances":lamps.size(),"inside_sport_surfaces":bad,"positions":lamps};report.checks.lamps_clear_of_fields=bad.is_empty() and lamps.size()>200
func visuals():
	campus.hud.visible=false
	var overview_only="--overview-only" in OS.get_cmdline_user_args()
	for pair in [["01_east_housing","47#"],["02_water_lecture_hall","水上报告厅"],["03_administration","行政楼"],["04_history_museum","校史馆"],
		["05_auditorium","礼堂"],["06_research_B","物质科学教研B楼"],["07_frontier_center","地球和空间科学前沿研究中心"]]:
		if overview_only:continue
		for d in District.data().districts:
			for b in d.buildings:
				if b.name!=pair[1]:continue
				var p=b.front_approach;var q=b.approach_road;var center=Vector2.ZERO
				for v in b.outline:center+=Vector2(v[0],v[1])
				center/=b.outline.size()
				await place(Vector3(q[0],.15,q[1]),Vector3(center.x,5,center.y))
				if b.height>24:
					campus.photo_camera=Camera3D.new();campus.add_child(campus.photo_camera);campus.photo_camera.current=true
					var outward=(Vector2(p[0],p[2])-center).normalized()
					campus.photo_camera.position=Vector3(p[0]+outward.x*30,14,p[2]+outward.y*30);campus.photo_camera.look_at(Vector3(center.x,b.height*.45,center.y));campus.photo_camera.fov=64
				await screenshot(pair[0])
				if campus.photo_camera:campus.photo_camera.free();campus.photo_camera=null;player.camera.current=true
	if not overview_only:
		await place(Vector3(0,.15,108),Vector3(0,1,139));await screenshot("11_original_avenue")
	player.frozen=true;campus.photo_camera=Camera3D.new();campus.add_child(campus.photo_camera);campus.photo_camera.current=true;campus.photo_camera.far=2400
	for view in [["08_east_overview",Vector3(470,185,590),Vector3(228,0,340)],
		["09_south_overview",Vector3(-420,210,1040),Vector3(0,0,779)],
		["10_campus_overview",Vector3(-675,600,1330),Vector3(0,0,405)]]:
		if overview_only and view[0]!="10_campus_overview":continue
		campus.photo_camera.position=view[1];campus.photo_camera.look_at(view[2],Vector3.UP);campus.photo_camera.fov=34 if view[0]=="10_campus_overview" else 62;await screenshot(view[0])
	campus.photo_camera.free();campus.photo_camera=null;player.camera.current=true;player.frozen=false
	report.checks.screenshots_saved=report.screenshots.all(func(s):return s.saved)
	if overview_only:return
	for d in District.data().districts:
		var b=d.buildings.filter(func(v):return v.has("approach_road") and v.style!="west_gate")[0];var p=b.front_approach;var q=b.approach_road
		var a=Vector3(q[0],.15,q[1]);var target=Vector3(p[0],.15,p[2]);var tangent=(target-a).normalized();a-=tangent*2
		await sample_walk(true,a,target,d.id)
		report.checks["moving_"+d.id]=report.performance[-1].walked_m>1 and report.performance[-1].focus_ratio==1.0
	await sample_walk(true,Vector3(0,.15,108),Vector3(0,1,139),"original_avenue")
	report.checks.moving_original_avenue=report.performance[-1].walked_m>1 and report.performance[-1].focus_ratio==1.0
	report.checks.native_performance=report.performance.all(func(p):return p.fps>=60 and p.p95_ms<=20)
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FULL_OUT))
	campus=load("res://scenes/campus_game.tscn").instantiate();root.add_child(campus);player=campus.player;await frames(24)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0;lamp_check()
	report.districts={};report.building_count=0
	for d in District.data().districts:
		report.districts[d.id]=campus.world.get_meta(d.id);report.building_count+=report.districts[d.id].buildings
	report.checks.all_mapped_buildings=report.building_count==110
	if "--visual-only" in OS.get_cmdline_user_args():
		if "--original-performance" in OS.get_cmdline_user_args():
			report=JSON.parse_string(FileAccess.get_file_as_string(FULL_OUT+"visual_validation.json"))
			report.performance=report.performance.filter(func(p):return p.view!="original_avenue")
			await sample_walk(true,Vector3(0,.15,108),Vector3(0,1,139),"original_avenue")
			report.checks.moving_original_avenue=report.performance[-1].walked_m>1 and report.performance[-1].focus_ratio==1.0
			report.checks.native_performance=report.performance.all(func(p):return p.fps>=60 and p.p95_ms<=20)
			save_report();return
		if "--overview-only" in OS.get_cmdline_user_args():
			report=JSON.parse_string(FileAccess.get_file_as_string(FULL_OUT+"visual_validation.json"));report.screenshots=report.screenshots.filter(func(s):return s.file!="10_campus_overview.png")
		await visuals();save_report();return
	var resume="--repair" in OS.get_cmdline_user_args()
	if resume:
		var previous=JSON.parse_string(FileAccess.get_file_as_string(FULL_OUT+"validation.json"));report.routes=previous.routes
	Engine.time_scale=8;Engine.physics_ticks_per_second=480
	for d in District.data().districts:
		for route in d.walk_routes:
			if resume and report.routes.any(func(r):return r.id==route.id and r.passed):continue
			var points=[]
			for p in route.points:points.append(Vector3(p[0],.14,p[1]))
			if points[0].distance_to(points[1])<.2:continue
			report.routes=report.routes.filter(func(r):return r.id!=route.id);report.routes.append(await walk_route(route.id,points))
	for road in preload("res://scripts/campus_network.gd").data().roads:
		if road.get("priority","") not in ["east_living_10","central_life_11","south_research_12"]:continue
		if road.grade>2:continue
		if resume and report.routes.any(func(r):return r.id==road.id and r.passed):continue
		var points=[]
		for p in road.points:points.append(Vector3(p[0],.14,p[1]))
		# The straight registration crosses the joined physics/single-molecule wing.
		# Walk the existing southern and eastern lanes to the northern crossroad.
		if road.id=="road_298766172":points=[Vector3(-128.355,.14,809.722),Vector3(-49.129,.14,811.942),Vector3(-51.406,.14,807.022),Vector3(-53.128,.14,799.501),Vector3(-53.753,.14,793.645),Vector3(-52.392,.14,752.546),Vector3(-127.488,.14,750.846)]
		if road.id=="road_686071140":points[-1]=Vector3(96.925,.14,912.5) # Stand inside the southern campus edge.
		report.routes=report.routes.filter(func(r):return r.id!=road.id);report.routes.append(await walk_route(road.id,points))
	# Existing northern roads connect continuously into the east, then the southern crossroad.
	for route in [["north_to_east",[Vector3(288.8,.14,60),Vector3(287.4,.14,59.5)]],
		["history_to_south_lane",[Vector3(-82,.14,598.7),Vector3(-83.94,.14,667.58),Vector3(-137.09,.14,666.8)]],
		["research_spine",[Vector3(97.608,.14,713.292),Vector3(97.608,.14,738),Vector3(97.608,.14,767)]]]:
		if resume and report.routes.any(func(r):return r.id==route[0] and r.passed):continue
		report.routes=report.routes.filter(func(r):return r.id!=route[0]);report.routes.append(await walk_route(route[0],route[1]))
	report.checks.all_entry_and_cross_district_routes=report.routes.all(func(r):return r.passed)
	report.barriers=[]
	for name in ["校史馆","礼堂","物质科学教研B楼","47#"]:
		for d in District.data().districts:
			for b in d.buildings:
				if b.name!=name:continue
				var p=b.front_approach;var a=b.outline[b.entry_edge];var v=b.outline[(int(b.entry_edge)+1)%b.outline.size()]
				var mid=Vector3((a[0]+v[0])*.5,.14,(a[1]+v[1])*.5)
				var start=Vector3(p[0],.14,p[2]);var target=mid+(mid-start).normalized()*2
				var result=await barrier(name,start,target)
				var query=PhysicsRayQueryParameters3D.create(start+Vector3.UP,target+Vector3.UP,1,[player.get_rid()])
				var hit=campus.get_world_3d().direct_space_state.intersect_ray(query)
				result.waist_ray_collider=String(hit.collider.name) if not hit.is_empty() else ""
				result.passed=result.remaining_m>.35 and result.waist_ray_collider.begins_with("MappedBuilding_")
				report.barriers.append(result)
	report.checks.physical_building_exteriors=report.barriers.all(func(b):return b.passed)
	save_report()
