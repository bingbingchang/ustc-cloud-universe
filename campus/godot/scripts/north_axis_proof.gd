extends RefCounted
const OUT="res://../renders/north_axis/"
const NorthAxis=preload("res://scripts/north_axis_environment.gd")

func save(name:String,data):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var f=FileAccess.open(OUT+name,FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"))

func prepare(c:Node3D):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	c.hud.visible=false;c.player.frozen=true;c.player.enabled=false
	c.life_layer.set_process(false);c.wave2_layer.set_process(false)

func pose(c:Node3D,t:float):
	c.life_layer.manual_time=t;c.wave2_layer.manual_time=t
	c.life_layer.pose(t);c.wave2_layer.pose(t)

func aim(c:Node3D,p:Vector3,target:Vector3,fov=42.0,shadow=180.0):
	c.player.free_camera=true;c.player.frozen=true;c.player.enabled=false
	var camera=c.photo_camera if c.photo_camera else c.player.camera
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.global_position=p;camera.look_at(target);camera.fov=fov
	c.sun.directional_shadow_max_distance=shadow;c.sun.light_angular_distance=.8;c.sun.shadow_blur=1.2

func walking_time(c:Node3D,id:String)->float:
	var path=c.wave2_layer.wander.paths[id]
	for part in path.phases:
		if part.kind=="walk":return part.start+part.seconds*.5-float(c.wave2_layer.wander.routes[id].get("time_offset",0))
	return 0

func actor_view(c:Node3D,id:String,close=true):
	var actor=c.wave2_layer.actors[id].root;var p=actor.position
	var h=float(c.wave2_layer.registry[id].height);var basis=Basis(Vector3.UP,actor.rotation.y)
	var offset=Vector3(-.8,h*1.15,-3.3) if close else Vector3(-4.5,4.8,-9.2)
	if id=="leaf_cat":offset=Vector3(-.65,.72,-1.6) if close else Vector3(-2,1.8,-4)
	aim(c,p+basis*offset,p+Vector3(0,h*.48,0),43,80)

func shot(c:Node3D,id:String):
	match id:
		"whole":c.viewpoint(19)
		"north":c.viewpoint(20)
		"gate":aim(c,Vector3(-.8,5.4,-24),Vector3(-.8,3.35,3),49)
		"axis":aim(c,Vector3(0,2.1,13),Vector3(0,4,167),49,250)
		"pools":aim(c,Vector3(-76,98,3),Vector3(8,0,93),44,420)
		"pavilion":c.viewpoint(22)
		"pavilion_front":aim(c,Vector3(56,8,96),Vector3(42.5,3.2,80.8),44,180)
		"bridge":aim(c,Vector3(72,2.15,78),Vector3(42.7,2,80.5),52)
		"west_bridge":aim(c,Vector3(-21,7,132),Vector3(-37,1.1,113),49,180)
		"inside":c.viewpoint(24)
		"neighbours":aim(c,Vector3(199,90,-8),Vector3(87,3,65),43,440)
		"core":c.viewpoint(0)
		"tiku":aim(c,Vector3(-18.3,1.45,145.1),Vector3(-17,1.05,146.85),38,60)
		"routes":aim(c,Vector3(111,26,107),Vector3(89.5,.1,79),44,180)
		_:actor_view(c,id)

func capture_stills(c:Node3D):
	prepare(c)
	var shots=["whole","north","gate","axis","pools","pavilion","pavilion_front","bridge","west_bridge","inside","neighbours","core","tiku","raiden","march7","meituan","doubao","leaf_cat"]
	var report={"source":"Godot 4.7 Forward+ native render","resolution":[3840,2160],"shots":[],"scope":"Completed researched north core and 5 wandering stories","north_geometry":c.world.get_meta("north_axis_stats"),"lake_details":c.world.get_meta("north_lake_detail"),"trees":c.tree_count}
	for i in range(shots.size()):
		var id=shots[i];var t=walking_time(c,id) if c.wave2_layer.actors.has(id) else 3.0 if id=="tiku" else 24.0
		pose(c,t);shot(c,id)
		for frame in range(32):await c.get_tree().process_frame
		var file="%02d_%s"%[i+1,id];await c.capture("north_axis/"+file)
		var camera=c.photo_camera
		var row={"file":file+".png","id":id,"time":t,"camera_position":str(camera.global_position),"transform":str(camera.global_transform),"fov":camera.fov,"projection":camera.projection,"size":camera.size,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
		if c.wave2_layer.actors.has(id):
			var state=c.wave2_layer.wander.sample(id,t);row["phase"]=state.phase;row["actor_position"]=str(state.position);row["speed_mps"]=state.speed_mps
		report.shots.append(row);print("NORTH_STILL ",file)
	# Route overlay is an inspection view, never baked into the promotional images.
	if c.wave2_layer.has_method("toggle_routes"):
		c.wave2_layer.toggle_routes();shot(c,"routes")
		for frame in range(16):await c.get_tree().process_frame
		await c.capture("north_axis/19_routes_debug");c.wave2_layer.toggle_routes()
	save("capture_report.json",report);c.get_tree().quit()

func validate(c:Node3D):
	prepare(c);pose(c,0)
	await c.get_tree().physics_frame
	var checks={};var hashes={}
	for version in ["accepted_v0_4","accepted_v0_5"]:
		var data=JSON.parse_string(FileAccess.get_file_as_string("res://../benchmarks/"+version+"/manifest.json"))
		for path in data.frozen_sha256:hashes[path]=FileAccess.get_sha256("res://../"+path)==data.frozen_sha256[path]
	checks.accepted_assets_preserved=not hashes.values().has(false)
	var runtime=await load("res://scripts/north_axis_runtime_qa.gd").new().validate(c)
	checks.runtime_physics=runtime.get("passed",false)
	var all_moving=true;var sampled=[];var route_conflicts=[]
	var space=c.get_world_3d().direct_space_state
	var excluded=[c.player.get_rid()]
	for body in c.world.find_children("*","PhysicsBody3D",true,false):
		if body is AnimatableBody3D:excluded.append(body.get_rid())
	for id in c.wave2_layer.actors:
		var duration=c.wave2_layer.wander.duration(id);var initial=c.wave2_layer.wander.sample(id,0).position
		var maximum=0.0;var phases=[];var points=0;var max_speed=0.0
		var shape=CapsuleShape3D.new();shape.radius=.18 if id=="leaf_cat" else .25;shape.height=.42 if id=="leaf_cat" else 1.35
		for step in range(int(duration*4)+1):
			var state=c.wave2_layer.wander.sample(id,step*.25);maximum=maxf(maximum,initial.distance_to(state.position));max_speed=maxf(max_speed,state.speed_mps)
			if not state.phase in phases:phases.append(state.phase)
			if state.phase!="walk":continue
			points+=1
			var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.exclude=excluded;query.margin=.01
			query.transform=Transform3D(Basis.IDENTITY,state.position+Vector3.UP*(shape.height*.5+.04))
			for hit in space.intersect_shape(query,8):route_conflicts.append({"id":id,"time":step*.25,"obstacle":str(hit.collider.name),"position":str(state.position)})
		all_moving=all_moving and maximum>3 and max_speed<=1.05 and "walk" in phases
		sampled.append({"id":id,"period":duration,"max_displacement":maximum,"max_speed_mps":max_speed,"phases":phases,"walking_samples":points})
	checks.five_real_wanderers=all_moving;checks.walk_routes_obstacle_free=route_conflicts.is_empty()
	var totals={"Hero":0,"Ambient":0,"Creature":0};var entries=[]
	for layer in [c.life_layer,c.wave2_layer]:
		for id in layer.registry:
			var r=layer.registry[id];totals[r.tier]+=1;entries.append({"layer":layer,"id":id,"tier":r.tier})
	var violations=[]
	for t in range(0,361,12):
		pose(c,t)
		for ax in entries:
			for az in entries:
				var x=ax.layer.actors[ax.id].root.position.x;var z=az.layer.actors[az.id].root.position.z;var counts={"Hero":0,"Ambient":0,"Creature":0}
				for a in entries:
					var p=a.layer.actors[a.id].root.position
					if p.x>=x and p.x<=x+100 and p.z>=z and p.z<=z+100:counts[a.tier]+=1
				for tier in counts:
					if counts[tier]>c.life_layer.budgets[tier]:violations.append({"time":t,"tier":tier,"count":counts[tier]})
	checks.population_unchanged=totals=={"Hero":4,"Ambient":6,"Creature":4};checks.density=violations.is_empty()
	var report={"checks":checks,"passed":not checks.values().has(false),"frozen_files":hashes,"routes":sampled,"obstacles":route_conflicts,"population":totals,"density_violations":violations,"runtime":runtime}
	save("validation.json",report);print("NORTH_VALIDATION ",JSON.stringify(checks));c.get_tree().quit(0 if report.passed else 1)

func capture_motion(c:Node3D):
	prepare(c)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"motion_frames"))
	# A real rendered sequence, with animation evaluated at 12 fps and native shadows.
	var camera=c.photo_camera if c.photo_camera else c.player.camera
	if c.photo_view:c.photo_view.size=Vector2i(1280,720)
	else:c.get_window().size=Vector2i(1280,720)
	for warm in range(3):await c.get_tree().process_frame
	var segments=["whole","axis","pavilion","raiden","march7","meituan","doubao","leaf_cat"]
	var report={"fps":12,"width":1280,"height":720,"frames":0,"segments":[]};var frame_no=0
	for id in segments:
		var start=walking_time(c,id)-5 if c.wave2_layer.actors.has(id) else 18.0
		var duration=12.0;report.segments.append({"id":id,"first_frame":frame_no,"time":start,"seconds":duration})
		for frame in range(int(duration*12)):
			var t=start+frame/12.0;pose(c,t);shot(c,id)
			# Slightly wider than the still close-up so foot plants remain readable.
			if c.wave2_layer.actors.has(id):actor_view(c,id,false)
			for warm in range(2):await c.get_tree().process_frame
			await RenderingServer.frame_post_draw
			camera.get_viewport().get_texture().get_image().save_jpg(OUT+"motion_frames/frame_%04d.jpg"%frame_no,.94);frame_no+=1
		print("NORTH_MOTION ",id)
	report.frames=frame_no;save("motion_manifest.json",report);c.get_tree().quit()
