extends RefCounted
## Reproducible engine evidence. Still and motion images are never AI generated.
const OUT="res://../renders/population/"

func save_json(name:String,data):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var f=FileAccess.open(OUT+name,FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"));f.close()

func aim(c:Node3D,pos:Vector3,target:Vector3,fov:float=42.0):
	c.player.free_camera=true;c.player.frozen=true;c.player.enabled=false
	c.photo_camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	c.photo_camera.global_position=pos;c.photo_camera.look_at(target);c.photo_camera.fov=fov
	c.sun.directional_shadow_max_distance=70;c.sun.light_angular_distance=.6;c.sun.shadow_blur=1.15

func capture_stills(c:Node3D):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	c.hud.visible=false;c.player.frozen=true;c.player.enabled=false
	var shots=[
		["01_world",0,8.0], ["02_tiku_preserved",5,3.0],
		["03_sakura_photographer",6,6.0], ["04_cyclist_riding",10,7.0],
		["05_cyclist_pushing",10,25.0], ["06_courtyard_reader",11,12.0],
		["07_north_connection",12,8.0], ["08_courtyard_context",4,14.0],
		["09_tiku_uniform_preserved",9,9.6], ["10_cyclist_pause",10,34.0],
		["11_photo_review",6,15.5], ["12_reading_walk",8,12.0]]
	var report={"source":"Godot Forward+ actual viewport","resolution":[3840,2160],"scope":"Population and 144m2 extension; visual QA is manual","shots":[]}
	for s in shots:
		c.life_layer.manual_time=s[2];c.life_layer.pose(s[2]);c.viewpoint(s[1])
		if s[1]==10:
			var root=c.life_layer.actors.cyclist.root.position
			aim(c,root+Vector3(3.2,1.8,-3.5),root+Vector3(0,.9,0),42)
		elif s[1]==11:aim(c,Vector3(-24.4,1.7,221.9),Vector3(-27,.93,218.8),42)
		elif s[1]==5:aim(c,Vector3(-18.3,1.45,145.1),Vector3(-17,1.05,146.85),38)
		elif s[1]==9:aim(c,Vector3(1.8,1.72,142.35),Vector3(3.4,1.14,145.0),38)
		elif s[1]==6:aim(c,Vector3(8.5,1.8,138.0),Vector3(10.4,.95,140.8),43)
		elif s[1]==8:aim(c,Vector3(22.3,1.9,152.7),Vector3(19.3,1.0,155.6),42)
		for frame in range(36):await c.get_tree().process_frame
		await c.capture("population/"+s[0])
		report.shots.append({"file":s[0]+".png","view":s[1]+1,"time":s[2],"camera":str(c.photo_camera.global_position),"camera_transform":str(c.photo_camera.global_transform),"fov":c.photo_camera.fov,"fps":Engine.get_frames_per_second(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
		print("POPULATION_STILL ",s[0])
	save_json("capture_report.json",report);c.get_tree().quit()

func validate(c:Node3D):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	c.life_layer.manual_time=0;c.player.frozen=true
	await c.get_tree().physics_frame
	var checks={};var report={"scope":"Actual Godot actors, physics, route, density and accepted hero hashes","checks":checks}
	var counts={"Hero":0,"Ambient":0,"Creature":0}
	for s in c.life_layer.registry.values():counts[s.tier]+=1
	report.counts=counts;checks.population=counts=={"Hero":2,"Ambient":4,"Creature":3}
	var density_failures=[];var excluded_modules=[]
	for t in range(0,65,8):
		c.life_layer.pose(t)
		var points=[]
		for id in c.life_layer.registry:
			var root=c.life_layer.actors[id].root
			points.append({"id":id,"tier":c.life_layer.registry[id].tier,"p":Vector2(root.position.x,root.position.z)})
		# The densest axis-aligned 100m square can be anchored to occupied coordinates.
		for x in points:
			for z in points:
				var local_count={"Hero":0,"Ambient":0,"Creature":0}
				for p in points:
					if p.p.x>=x.p.x and p.p.x<=x.p.x+100 and p.p.y>=z.p.y and p.p.y<=z.p.y+100:local_count[p.tier]+=1
				for tier in local_count:
					if local_count[tier]>c.life_layer.budgets[tier]:density_failures.append({"time":t,"tier":tier,"count":local_count[tier]})
		for module in preload("res://scripts/scene_modules.gd").layout():
			if module.enabled and not module.population_allowed:
				var b=module.bounds
				for p in points:
					if p.p.x>b[0] and p.p.x<b[2] and p.p.y>b[1] and p.p.y<b[3]:excluded_modules.append(p.id)
	checks.local_density=density_failures.is_empty();checks.quiet_connector=excluded_modules.is_empty()
	report.density_failures=density_failures;report.excluded_module_actors=excluded_modules
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://../benchmarks/accepted_v0_4/manifest.json"))
	var hashes={}
	for path in manifest.frozen_sha256:
		hashes[path]=FileAccess.get_sha256("res://../"+path)==manifest.frozen_sha256[path]
	checks.hero_frozen=not hashes.values().has(false);report.frozen_files=hashes
	var samples=[];var finite=true;var dry=true;var close_enough=true;var max_ik=0.0;var max_speed=0.0;var previous=Vector3.ZERO
	for i in range(1281):
		var t=i/20.0;c.life_layer.pose(t)
		for id in ["cyclist","bench_reader","photo","reader"]:
			var state=c.life_layer.actors[id].root.last_state()
			finite=finite and state.finite
			for e in state.ik_error_m.values():max_ik=maxf(max_ik,float(e))
		var p=c.life_layer.actors.cyclist.root.position
		# Check the entire bicycle/pushing student swept box, not only its origin.
		for dx in [-1.0,0.0,1.0]:
			for dz in [-.8,0.0,.8]:
				var q=Vector2(p.x+dx,p.z+dz);dry=dry and not c.pond_at(q) and not c.in_building(q)
		if i>0:max_speed=maxf(max_speed,p.distance_to(previous)*20)
		previous=p
		if i%40==0:
			c.life_layer.time=t;samples.append(c.life_layer.snapshot())
	checks.finite_pose=finite;checks.cycle_land_clearance=dry;checks.ik_contacts=max_ik<.012
	checks.quiet_cycle_speed=max_speed<2.8
	report.max_ik_error_m=max_ik;report.max_speed_mps=max_speed;report.samples=samples
	var loops={}
	for id in ["cyclist","bench_reader","photo","reader"]:loops[id]=c.life_layer.actors[id].root.validate_loop()
	report.loops=loops;checks.pose_loops=loops.values().all(func(v):return v.closed)
	# Observe real rendered shoe height against physics surfaces (pads included).
	var shoe_contacts=[];var shoe_pass=true
	for id in ["bench_reader","photo","reader"]:
		c.life_layer.pose(12.0)
		var actor=c.life_layer.actors[id].root
		for side in ["L","R"]:
			var sole=actor.to_global(actor._endpoint(side,false))-Vector3(0,.064,0)
			var q=PhysicsRayQueryParameters3D.create(sole+Vector3.UP*.15,sole-Vector3.UP*.20);q.exclude=[c.player.get_rid()]
			var hit=c.get_world_3d().direct_space_state.intersect_ray(q)
			var error=sole.y-hit.position.y if not hit.is_empty() else 999.0
			shoe_pass=shoe_pass and absf(error)<.018
			shoe_contacts.append({"actor":id,"side":side,"sole":str(sole),"surface_error_m":error})
	checks.shoe_surface_contact=shoe_pass;report.shoe_contacts=shoe_contacts
	var a=c.life_layer.cycle_route(0);var b=c.life_layer.cycle_route(63.999)
	checks.root_loop=a.position.distance_to(b.position)<.002 and absf(angle_difference(a.heading,b.heading))<.002
	# Continuous ray coverage includes both landscape shoulders and the old seam.
	var missing=[];var space=c.get_world_3d().direct_space_state
	for x in range(-5,6):
		for z in range(107,123):
			var q=PhysicsRayQueryParameters3D.create(Vector3(x,.5,z),Vector3(x,-1,z));q.exclude=[c.player.get_rid()]
			if space.intersect_ray(q).is_empty():missing.append([x,z])
	checks.connector_ground=missing.is_empty();report.connector_samples=176;report.connector_missing=missing
	# Validate yield using a real actor position, not a mocked predicate.
	c.life_layer.manual_time=-1;c.life_layer.cyclist_time=30;c.life_layer.pose(30)
	c.player.free_camera=false;c.player.global_position=c.life_layer.actors.cyclist.root.global_position+Vector3(1.6,0,0)
	checks.yield_near=c.life_layer.should_yield()
	var stopped_time=c.life_layer.cyclist_time
	for f in range(60):await c.get_tree().physics_frame
	checks.yield_stops_clock=absf(c.life_layer.cyclist_time-stopped_time)<.002
	c.player.global_position=Vector3(0,.16,127);checks.yield_clear=not c.life_layer.should_yield()
	for f in range(60):await c.get_tree().physics_frame
	checks.yield_resumes=c.life_layer.cyclist_time>stopped_time+.5
	c.life_layer.manual_time=30;c.life_layer.pose(30)
	c.player.frozen=false;c.player.enabled=true;c.player.free_camera=false
	c.player.set_view(Vector3(59,.2,157),Vector3(53,1.85,157));Input.action_press("forward")
	for f in range(150):await c.get_tree().physics_frame
	Input.action_release("forward")
	checks.cyclist_blocks_player=c.player.position.x>57.0 and c.player.position.x<57.5
	report.cycle_contact_stop=str(c.player.position)
	c.player.set_view(Vector3(-27,.2,221),Vector3(-27,1.85,218));Input.action_press("forward")
	for f in range(150):await c.get_tree().physics_frame
	Input.action_release("forward")
	checks.reader_bench_blocks_player=c.player.position.z>219.2 and c.player.position.z<219.6
	report.bench_contact_stop=str(c.player.position)
	c.life_layer.manual_time=0
	checks.land_traversal=await c.audit_ground(false)
	# New northern end and shoulder edges still stop the player.
	var edge_tests=[]
	for test in [[Vector3(0,.2,109),Vector3(0,1.85,95),"north"],[Vector3(4.8,.2,112),Vector3(12,1.85,112),"east"]]:
		c.player.set_view(test[0],test[1]);Input.action_press("forward");Input.action_press("jog")
		for f in range(150):await c.get_tree().physics_frame
		Input.action_release("forward");Input.action_release("jog")
		var p=c.player.position;edge_tests.append({"edge":test[2],"end":str(p),"passed":p.z>106.1 and p.x<5.9 and p.y>-.1})
	checks.connector_boundaries=edge_tests[0].passed and edge_tests[1].passed;report.edge_tests=edge_tests
	var passed=not checks.values().has(false);report.passed=passed
	save_json("validation.json",report);print("POPULATION_QA ",JSON.stringify(checks));c.get_tree().quit(0 if passed else 1)

func capture_motion(c:Node3D):
	c.hud.visible=false;c.player.enabled=false;c.player.frozen=true;c.player.free_camera=true
	c.photo_view=SubViewport.new();c.photo_view.size=Vector2i(1280,720);c.photo_view.world_3d=c.get_world_3d();c.photo_view.msaa_3d=Viewport.MSAA_4X;c.photo_view.use_taa=true;c.photo_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;c.add_child(c.photo_view)
	c.photo_camera=Camera3D.new();c.photo_view.add_child(c.photo_camera);c.photo_camera.current=true;c.photo_camera.near=.06;c.photo_camera.far=850;c.get_viewport().disable_3d=true
	var directory=ProjectSettings.globalize_path(OUT+"motion_frames");DirAccess.make_dir_recursive_absolute(directory)
	var manifest={"width":1280,"height":720,"fps":12,"source":"Actual Godot frames","clips":[]};var frame_index=0
	for clip in [["cyclist_full_loop",64.0,0.0],["courtyard_reader",8.0,4.0],["sakura_photo",8.0,13.0],["study_walk",12.0,2.0],["tiku_preserved",8.0,9.0]]:
		for i in range(int(clip[1]*12)):
			var t=clip[2]+i/12.0;c.life_layer.manual_time=t;c.life_layer.pose(t)
			if clip[0]=="cyclist_full_loop":
				var p=c.life_layer.actors.cyclist.root.position;aim(c,p+Vector3(3.4,1.7,-4),p+Vector3(0,.85,0),43)
			elif clip[0]=="courtyard_reader":aim(c,Vector3(-24.4,1.7,221.9),Vector3(-27,.93,218.8),42)
			elif clip[0]=="sakura_photo":aim(c,Vector3(8.5,1.8,138),Vector3(10.4,.95,140.8),43)
			elif clip[0]=="study_walk":
				var p=c.life_layer.actors.reader.root.position;aim(c,p+Vector3(3,1.8,-3),p+Vector3(0,.95,0),43)
			else:aim(c,Vector3(-18.3,1.45,145.1),Vector3(-17,1.05,146.85),38)
			if i==0:
				for warm in range(24):await c.get_tree().process_frame
			await RenderingServer.frame_post_draw
			c.photo_view.get_texture().get_image().save_jpg(directory+"/frame_%05d.jpg"%frame_index,.94);frame_index+=1
		manifest.clips.append({"name":clip[0],"frames":int(clip[1]*12),"seconds":clip[1]});print("POPULATION_MOTION_CLIP ",clip[0])
	manifest.frames=frame_index;save_json("motion_manifest.json",manifest);c.get_tree().quit()
