extends RefCounted
const OUT="res://../renders/wave2/"
const Modules=preload("res://scripts/scene_modules.gd")
const EnvironmentModule=preload("res://scripts/wave2_environment.gd")

func save_json(name:String,data):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var f=FileAccess.open(OUT+name,FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"))

func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])

func aim(c:Node3D,p:Vector3,target:Vector3,fov=40.0):
	c.player.free_camera=true;c.player.frozen=true;c.player.enabled=false
	var camera=c.photo_camera if c.photo_camera else c.player.camera
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.global_position=p;camera.look_at(target);camera.fov=fov
	c.sun.directional_shadow_max_distance=75;c.sun.light_angular_distance=.6;c.sun.shadow_blur=1.2

func actor_view(c:Node3D,id:String,close=true):
	var r=c.wave2_layer.registry[id];var p=c.wave2_layer.actors[id].root.position
	var b=Basis(Vector3.UP,r.heading);var h=float(r.height)
	var offset=Vector3(-.60,h*1.3,-3.3) if close else Vector3(-1.8,4.2,-8.0)
	if id=="leaf_cat":offset=Vector3(-.3,.75,-1.50) if close else Vector3(-.7,2.3,-4.5)
	if id=="meituan" and close:offset=Vector3(-.7,1.9,-3.0)
	aim(c,p+b*offset,p+Vector3(0,h*.52,0),42 if close else 44)

func capture_stills(c:Node3D):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	c.hud.visible=false;c.player.frozen=true;c.player.enabled=false
	var shots=[
		["01_overview","overview",7.0,false],["02_baseline","baseline",8.0,false],
		["03_raiden_close","raiden",13.0,true],["04_raiden_story","raiden",7.0,false],
		["05_march7_close","march7",0.0,true],["06_march7_story","march7",7.0,false],
		["07_meituan_close","meituan",5.0,true],["08_meituan_order","meituan",19.0,true],
		["09_doubao_close","doubao",9.0,true],["10_doubao_story","doubao",21.0,false],
		["11_cat_leaf","leaf_cat",13.0,true],["12_west_walk","west",8.0,false],
		["13_east_garden","east",9.0,false],["14_south_reading","south",7.0,false],
		["15_tiku_preserved","tiku",3.0,true]]
	var report={"source":"Godot Forward+ actual native viewport","resolution":[3840,2160],"shots":[],"new_story_count":5}
	for s in shots:
		c.life_layer.manual_time=s[2];c.wave2_layer.manual_time=s[2];c.life_layer.pose(s[2]);c.wave2_layer.pose(s[2])
		match s[1]:
			"overview":c.viewpoint(18)
			"baseline":c.viewpoint(0)
			"west":aim(c,Vector3(-152,25,212),Vector3(-98,1,236),48)
			"east":aim(c,Vector3(159,39,237),Vector3(92,1,178),46)
			"south":aim(c,Vector3(68,20,284),Vector3(23,1,242),45)
			"tiku":aim(c,Vector3(-18.3,1.45,145.1),Vector3(-17,1.05,146.85),38)
			_:actor_view(c,s[1],s[3])
		for frame in range(32):await c.get_tree().process_frame
		await c.capture("wave2/"+s[0])
		var camera=c.photo_camera
		report.shots.append({"file":s[0]+".png","id":s[1],"time":s[2],"position":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"transform":str(camera.global_transform),"fov":camera.fov,"projection":"orthogonal" if camera.projection==1 else "perspective","size":camera.size,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
		print("WAVE2_STILL ",s[0])
	save_json("capture_report.json",report);c.get_tree().quit()

func walk_route(c:Node3D,name:String,points:Array)->Dictionary:
	c.player.frozen=false;c.player.enabled=true;c.player.free_camera=false
	c.player.set_view(points[0]+Vector3.UP*.15,points[1]+Vector3.UP*1.65)
	var reached=true;var min_y=100.0;var steps=0
	for target in points.slice(1):
		c.player.set_view(c.player.position,Vector3(target.x,c.player.position.y+1.65,target.z))
		Input.action_press("forward")
		var budget=int(Vector2(c.player.position.x-target.x,c.player.position.z-target.z).length()/1.8*60)+200
		var hit=false
		for frame in range(budget):
			await c.get_tree().physics_frame;steps+=1;min_y=minf(min_y,c.player.position.y)
			if Vector2(c.player.position.x-target.x,c.player.position.z-target.z).length()<.50:hit=true;break
		Input.action_release("forward")
		if not hit:reached=false;break
	c.player.frozen=true
	return {"name":name,"reached":reached,"min_feet_y":min_y,"steps":steps,"final":str(c.player.position)}

func validate(c:Node3D):
	c.life_layer.manual_time=0;c.wave2_layer.manual_time=0;c.player.frozen=true
	await c.get_tree().physics_frame
	var checks={};var report={"checks":checks,"scope":"Full imported Godot scene; old and new population, native physics and loops"}
	var entries=[]
	for id in c.life_layer.registry:entries.append({"id":id,"tier":c.life_layer.registry[id].tier,"root":c.life_layer.actors[id].root})
	for id in c.wave2_layer.registry:entries.append({"id":id,"tier":c.wave2_layer.registry[id].tier,"root":c.wave2_layer.actors[id].root})
	var counts={"Hero":0,"Ambient":0,"Creature":0}
	for a in entries:counts[a.tier]+=1
	report.counts=counts;checks.population=counts=={"Hero":4,"Ambient":6,"Creature":4};checks.five_new_nodes=c.wave2_layer.actors.size()==5
	var density=[];var min_story_distance=INF
	for i in range(entries.size()):
		for j in range(i+1,entries.size()):
			if entries[i].tier=="Hero" and entries[j].tier=="Hero":min_story_distance=minf(min_story_distance,entries[i].root.position.distance_to(entries[j].root.position))
	for t in range(0,65,8):
		c.life_layer.pose(t);c.wave2_layer.pose(t)
		for ax in entries:
			for az in entries:
				var local_count={"Hero":0,"Ambient":0,"Creature":0}
				for a in entries:
					var p=a.root.position
					if p.x>=ax.root.position.x and p.x<=ax.root.position.x+100 and p.z>=az.root.position.z and p.z<=az.root.position.z+100:local_count[a.tier]+=1
				for tier in local_count:
					if local_count[tier]>c.life_layer.budgets[tier]:density.append({"time":t,"tier":tier,"count":local_count[tier]})
	checks.local_density=density.is_empty();report.density_failures=density;report.min_hero_distance_m=min_story_distance
	var hashes={}
	for version in ["accepted_v0_4","accepted_v0_5"]:
		var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://../benchmarks/"+version+"/manifest.json"))
		for path in manifest.frozen_sha256:hashes[path]=FileAccess.get_sha256("res://../"+path)==manifest.frozen_sha256[path]
	checks.accepted_assets_frozen=not hashes.values().has(false);report.frozen_files=hashes
	var finite=true;var max_ik=0.0;var loops={};var phases={};var contact_samples=[]
	for id in c.wave2_layer.actors:
		var actor=c.wave2_layer.actors[id].root;var s=c.wave2_layer.registry[id];var states=[]
		for frame in range(int(s.period*20)+1):
			actor.pose(frame/20.0);var state=actor.last_state();finite=finite and state.finite
			for e in state.ik_error_m.values():max_ik=maxf(max_ik,float(e))
			if not state.phase in states:states.append(state.phase)
		loops[id]=actor.validate_loop();phases[id]=states
		# Actual imported shoe endpoints, or measured production sole markers.
		actor.pose(0)
		var soles=[]
		if id in ["raiden","march7"]:
			for side in ["L","R"]:soles.append(actor.to_global(actor._endpoint(side,false)-Vector3(0,.064,0)))
		elif id=="doubao":
			for side in ["L","R"]:soles.append(actor.bones["Leg"+side].to_global(Vector3(0,-.406,-.025)))
		elif id=="meituan":
			for side in ["L","R"]:soles.append(actor.bones["Leg"+side].to_global(Vector3(0,-.30,-.095)))
		else:
			for side in ["L","R"]:soles.append(actor.bones["Back"+side].to_global(Vector3(0,-.20,-.019)))
		for sole in soles:
			# Probe beside the foot to avoid its own character collision volume.
			var probe=sole+actor.global_basis*Vector3(.35,0,0)
			var q=PhysicsRayQueryParameters3D.create(probe+Vector3.UP*.18,probe-Vector3.UP*.20);q.exclude=[c.player.get_rid()]
			var hit=c.get_world_3d().direct_space_state.intersect_ray(q)
			contact_samples.append({"id":id,"sole_y":sole.y,"surface_error_m":sole.y-hit.position.y if not hit.is_empty() else 999})
	checks.pose_finite=finite;checks.ik_contact=max_ik<.012;checks.loops=loops.values().all(func(v):return v.closed)
	checks.story_actions=phases.values().all(func(v):return v.size()>=3)
	checks.soles_grounded=contact_samples.all(func(v):return absf(v.surface_error_m)<.018)
	report.loops=loops;report.phases=phases;report.max_ik_error_m=max_ik;report.sole_contacts=contact_samples
	var missing=[];var sample_count=0;var area=0.0;var boundary_excluded=0
	for s in Modules.layout():
		if not s.enabled or s.template!="wave2_landscape":continue
		var poly=EnvironmentModule.polygon(s.polygon)
		var signed_area=0.0
		for i in range(poly.size()):signed_area+=(poly[i].x*poly[(i+1)%poly.size()].y-poly[(i+1)%poly.size()].x*poly[i].y)*.5
		area+=absf(signed_area)
		for x in range(int(s.bounds[0])+1,int(s.bounds[2])):
			for z in range(int(s.bounds[1])+1,int(s.bounds[3])):
				if not EnvironmentModule.contains(s,Vector2(x,z)):continue
				var in_wall=false
				for edge in range(poly.size()):
					var a=poly[edge];var b=poly[(edge+1)%poly.size()]
					if not EnvironmentModule._on_port(a,b,s) and Vector2(x,z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(x,z),a,b))<.45:in_wall=true
				if in_wall:boundary_excluded+=1;continue
				sample_count+=1
				var q=PhysicsRayQueryParameters3D.create(Vector3(x,.35,z),Vector3(x,-.2,z));q.exclude=[c.player.get_rid()]
				if c.get_world_3d().direct_space_state.intersect_ray(q).is_empty():missing.append([x,z])
	checks.expanded_ground=missing.is_empty();report.ground_samples=sample_count;report.missing_ground=missing;report.added_area_m2=area;report.boundary_wall_samples_excluded=boundary_excluded
	# Preserve normal integration step while accelerating headless route observation.
	Engine.physics_ticks_per_second=240;Engine.time_scale=4
	checks.core_land=await c.audit_ground(false)
	var routes=[]
	routes.append(await walk_route(c,"east_delivery",[Vector3(73,0,158),Vector3(85,0,155),Vector3(90,0,156),Vector3(94,0,160)]))
	routes.append(await walk_route(c,"east_garden",[Vector3(73,0,187),Vector3(90,0,187),Vector3(99,0,197),Vector3(113,0,205),Vector3(116,0,201)]))
	routes.append(await walk_route(c,"west_reading",[Vector3(-45,0,232),Vector3(-78,0,232),Vector3(-90,0,234),Vector3(-108,0,236),Vector3(-121,0,242)]))
	routes.append(await walk_route(c,"south_reading",[Vector3(0,0,231),Vector3(22,0,236),Vector3(31,0,246),Vector3(31,0,258)]))
	checks.connected_routes=routes.all(func(v):return v.reached and v.min_feet_y>-.15);report.routes=routes
	var edge_tests=[]
	for s in Modules.layout():
		if not s.enabled or not s.has("polygon"):continue
		var poly=EnvironmentModule.polygon(s.polygon)
		for edge in range(poly.size()):
			var a=poly[edge];var b=poly[(edge+1)%poly.size()]
			if EnvironmentModule._on_port(a,b,s) or a.distance_to(b)<8:continue
			var mid=(a+b)*.5;var d=(b-a).normalized();var n=Vector2(-d.y,d.x)
			if not Geometry2D.is_point_in_polygon(mid+n,poly):n=-n
			var start=mid+n*1.4;var target=mid-n*2.0
			c.player.frozen=false;c.player.enabled=true;c.player.free_camera=false
			c.player.set_view(Vector3(start.x,.14,start.y),Vector3(target.x,1.79,target.y));Input.action_press("forward")
			for frame in range(100):await c.get_tree().physics_frame
			Input.action_release("forward");c.player.frozen=true
			var p=Vector2(c.player.position.x,c.player.position.z)
			edge_tests.append({"module":s.id,"final":str(c.player.position),"inside":Geometry2D.is_point_in_polygon(p,poly),"edge_distance":p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))})
			break
	checks.expanded_boundaries=edge_tests.all(func(v):return v.inside and v.edge_distance>.25 and v.edge_distance<.8);report.edge_tests=edge_tests
	Engine.time_scale=1;Engine.physics_ticks_per_second=60
	var bounds_ok=true
	for id in c.wave2_layer.registry:
		var r=c.wave2_layer.registry[id];var p=vec(r.position)
		bounds_ok=bounds_ok and Modules.contains(Vector2(p.x,p.z)) and not c.pond_at(Vector2(p.x,p.z))
	checks.story_nodes_on_land=bounds_ok
	var passed=not checks.values().has(false);report.passed=passed
	save_json("validation.json",report);print("WAVE2_QA ",JSON.stringify(checks));c.get_tree().quit(0 if passed else 1)

func capture_motion(c:Node3D):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"motion_frames"))
	c.hud.visible=false;c.player.frozen=true;c.player.enabled=false
	DisplayServer.window_set_size(Vector2i(1280,720));c.get_viewport().size=Vector2i(1280,720)
	var frame=0;var clips=[]
	for id in ["raiden","march7","meituan","doubao","leaf_cat"]:
		var duration=int(c.wave2_layer.registry[id].period);actor_view(c,id,true)
		for i in range(duration*12):
			var t=i/12.0-float(c.wave2_layer.registry[id].time_offset)
			c.wave2_layer.manual_time=maxf(t,0);c.wave2_layer.pose(t);c.wave2_layer.set_process(false)
			c.life_layer.manual_time=i/12.0
			await c.get_tree().process_frame;RenderingServer.force_draw()
			var im=c.get_viewport().get_texture().get_image()
			im.save_jpg(ProjectSettings.globalize_path(OUT+"motion_frames/frame_%05d.jpg"%frame),.88);frame+=1
		clips.append({"name":id+"_full_loop","seconds":duration,"frames":duration*12})
		print("WAVE2_MOTION ",id," ",frame)
	save_json("motion_manifest.json",{"source":"Actual Godot frames","fps":12,"frames":frame,"width":1280,"height":720,"clips":clips})
	c.get_tree().quit()
