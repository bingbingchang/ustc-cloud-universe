extends SceneTree

const OUT="res://../renders/gameplay/"
var campus:Node3D
var player:CharacterBody3D
var report={"checks":{},"routes":[],"screenshots":[],"performance":[]}

func _initialize():call_deferred("run")

func frames(count:int):
	for i in range(count):
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		await physics_frame

func place(pos:Vector3,target:Vector3):
	player.frozen=false;player.enabled=true
	player.set_view(pos,target)
	await frames(15)

func screenshot(name:String):
	if DisplayServer.get_name()=="headless":return
	var was_frozen=player.frozen;player.frozen=true
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	var result=root.get_texture().get_image().save_png(OUT+name+".png")
	report.screenshots.append({"file":name+".png","saved":result==OK,"state":player.avatar.locomotion,"feet":str(player.position)})
	player.frozen=was_frozen

func walk_route(id:String,points:Array)->Dictionary:
	await place(points[0]+Vector3.UP*.10,points[1])
	var reached=true;var min_y=player.position.y;var max_step=0.0;var travelled=0.0;var segments=[];var contacts=[]
	for target in points.slice(1):
		Input.action_press("forward")
		var start=player.position
		var budget=int(Vector2(start.x-target.x,start.z-target.z).length()/2.6*60)+180
		var hit=false;var stalled=0
		for i in range(budget):
			var delta=target-player.position
			player.orbit.rotation.y=atan2(-delta.x,-delta.z)
			var previous=player.position
			await frames(1)
			var distance=player.position.distance_to(previous)
			max_step=maxf(max_step,distance);travelled+=Vector2(player.position.x-previous.x,player.position.z-previous.z).length()
			min_y=minf(min_y,player.position.y)
			if Vector2(player.position.x-target.x,player.position.z-target.z).length()<.14:hit=true;break
			stalled=stalled+1 if distance<.002 else 0
			if stalled>90:
				for j in range(player.get_slide_collision_count()):contacts.append(String(player.get_slide_collision(j).get_collider().name))
				break
		Input.action_release("forward")
		await frames(8)
		segments.append({"target":str(target),"reached":hit,"remaining_m":Vector2(player.position.x-target.x,player.position.z-target.z).length()})
		if not hit:reached=false;break
	var result={"id":id,"passed":reached and min_y>-.15 and max_step<.50,"travelled_m":travelled,"min_feet_y":min_y,"max_step_m":max_step,"segments":segments,"blockers":contacts,"final":str(player.position)}
	print("GAME_ROUTE ",id," ",result.passed," ",player.position)
	return result

func barrier(id:String,start:Vector3,target:Vector3)->Dictionary:
	await place(start,target)
	Input.action_press("forward")
	var bodies=[]
	var budget=int(start.distance_to(target)/2.6*60)+120
	for i in range(budget):
		await frames(1)
		for j in range(player.get_slide_collision_count()):
			var hit=player.get_slide_collision(j)
			if absf(hit.get_normal().y)<.5:
				var body=String(hit.get_collider().name)
				if body not in bodies:bodies.append(body)
	Input.action_release("forward")
	var remaining=Vector2(player.position.x-target.x,player.position.z-target.z).length()
	return {"id":id,"passed":not bodies.is_empty() and remaining>.35,"horizontal_contacts":bodies,"remaining_m":remaining,"final":str(player.position)}

func check_barriers():
	report.barriers=[]
	report.barriers.append(await barrier("building",Vector3(0,.15,163),Vector3(0,.15,174)))
	report.barriers.append(await barrier("lake",Vector3(-12,.15,95),Vector3(-24,.15,95)))
	var trunk=campus.lookdev_tree_contacts[0].position
	report.barriers.append(await barrier("tree",trunk+Vector3(0,.15,2),trunk))
	report.checks.world_collision=report.barriers.all(func(b):return b.passed)

func save_report():
	report.passed=not report.checks.values().has(false)
	var f=FileAccess.open(OUT+"validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("GAMEPLAY_CHECKS ",JSON.stringify(report.checks))
	quit(0 if report.passed else 1)

func sample_quality(use_balanced:bool,pos:Vector3,target:Vector3,id:String):
	campus.apply_quality(use_balanced)
	await place(pos,target);player.frozen=true
	for i in range(90):await process_frame
	var samples=[];var previous=Time.get_ticks_usec();var focus=0
	for i in range(180):
		# Rotate continuously: test the orbiting gameplay camera and live reflection.
		player.orbit.rotation.y+=.0012
		await process_frame
		var now=Time.get_ticks_usec();samples.append((now-previous)/1000.0);previous=now
		if root.has_focus():focus+=1
	samples.sort()
	var sum=0.0
	for s in samples:sum+=s
	report.performance.append({"view":id,"quality":"balanced" if use_balanced else "quality","fps":1000.0/(sum/samples.size()),"p95_ms":samples[int(samples.size()*.95)],"focus_ratio":float(focus)/samples.size(),"reflection_size":str(campus.reflection_view.size),"window_size":str(root.size),"msaa":root.msaa_3d,"taa":root.use_taa})
	print("GAME_PERF ",JSON.stringify(report.performance[-1]))
	player.frozen=false

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	campus=load("res://scenes/campus_game.tscn").instantiate();root.add_child(campus);player=campus.player
	await frames(30)
	if "--barriers-only" in OS.get_cmdline_user_args():
		report=JSON.parse_string(FileAccess.get_file_as_string(OUT+"validation.json"))
		Engine.time_scale=4;Engine.physics_ticks_per_second=240
		await check_barriers()
		save_report();return
	for i in range(90):await process_frame
	report.checks.visible_avatar=player.avatar.visible and player.avatar.bones.size()>10
	var collider=player.get_child(0)
	report.collider={"type":collider.shape.get_class(),"height_m":collider.shape.height,"radius_m":collider.shape.radius}
	report.checks.capsule_body=collider.shape is CapsuleShape3D and player.collision_mask==1
	await place(Vector3(0,.15,105),Vector3(0,1,140))
	await screenshot("01_third_person")
	var origin=player.position
	Input.action_press("forward");await frames(90)
	report.walk_speed=Vector2(player.velocity.x,player.velocity.z).length()
	report.checks.walk=player.position.z-origin.z>3 and absf(report.walk_speed-2.6)<.05 and player.avatar.locomotion=="walk"
	await screenshot("02_walking")
	Input.action_press("jog");await frames(45)
	report.run_speed=Vector2(player.velocity.x,player.velocity.z).length()
	report.checks.run=absf(report.run_speed-5.0)<.05 and player.avatar.locomotion=="run"
	Input.action_release("forward");Input.action_release("jog");await frames(25)
	report.checks.stop=Vector2(player.velocity.x,player.velocity.z).length()<.01 and player.avatar.locomotion=="idle"
	var apex=player.position.y;var ground=apex;var jumps=player.jump_count
	Input.action_press("jump");await frames(3);Input.action_release("jump")
	report.checks.jump_pose=player.avatar.locomotion=="jump"
	# An extra press in flight must not create a second jump.
	Input.action_press("jump");await frames(2);Input.action_release("jump")
	for i in range(65):
		await frames(1);apex=maxf(apex,player.position.y)
		if i==12:await screenshot("03_jumping")
	report.jump_height_m=apex-ground
	report.checks.jump_and_land=report.jump_height_m>.80 and report.jump_height_m<1.1 and player.is_on_floor()
	report.checks.no_double_jump=player.jump_count==jumps+1
	for action in ["left","right","back"]:
		await place(Vector3(0,.15,108),Vector3(0,1,140));origin=player.position
		Input.action_press(action);await frames(45);Input.action_release(action)
		var displacement=player.position-origin
		report.checks[action]=displacement.x>1.4 if action=="left" else displacement.x< -1.4 if action=="right" else displacement.z< -1.4
	await place(Vector3(0,.15,108),Vector3(0,1,140))
	Input.action_press("forward");Input.action_press("right");await frames(45)
	report.checks.diagonal_speed=Vector2(player.velocity.x,player.velocity.z).length()<2.65
	Input.action_release("forward");Input.action_release("right");await frames(15)
	var old_yaw=player.orbit.rotation.y
	var mouse=InputEventMouseMotion.new();mouse.screen_relative=Vector2(120,20);player._unhandled_input(mouse)
	report.checks.mouse_orbit=absf(player.orbit.rotation.y-old_yaw)>.2
	var key=InputEventKey.new();key.keycode=KEY_TAB;key.pressed=true;player._unhandled_input(key)
	report.checks.first_person=not player.third_person and not player.avatar.visible and player.arm.spring_length==0
	await screenshot("04_first_person")
	player._unhandled_input(key)
	report.checks.return_third_person=player.third_person and player.avatar.visible
	key.keycode=KEY_ESCAPE;player._unhandled_input(key);origin=player.position
	Input.action_press("forward")
	for i in range(30):await physics_frame
	Input.action_release("forward")
	report.checks.release_stops_movement=player.position.distance_to(origin)<.1
	# Accelerated integration keeps a 1/60 s simulation step.
	Engine.time_scale=4;Engine.physics_ticks_per_second=240
	var layout=load("res://scripts/north_axis_environment.gd").layout()
	for spec in layout.walk_routes:
		if spec.id not in ["oldgate_to_core","west_bridge_approach","west_curve"]:continue
		var points=[]
		for p in spec.points:points.append(Vector3(p[0],p[1],p[2]))
		report.routes.append(await walk_route(spec.id,points))
	report.routes.append(await walk_route("through_pavilion",[
		Vector3(26.703,.08,63.899),Vector3(28.635,.34,65.95),Vector3(34.35,.34,67.971),Vector3(36.413,.34,70.165),Vector3(40.32,.34,71.405),Vector3(42.539,.34,74.046),Vector3(43.025,.34,76.044),Vector3(41.7,.34,77),Vector3(41.3,.34,78.4),Vector3(42.501,.34,80.789),Vector3(44.8,.34,78),Vector3(45.9,.34,78.45),Vector3(46.521,.34,78.591),Vector3(52.296,.34,78.799),Vector3(57.33,.34,78.383),Vector3(59.275,.34,76.32),Vector3(60.468,.34,75.573),Vector3(68.84,.34,75.64),Vector3(76.804,.08,80.538)]))
	report.routes.append(await walk_route("west_grove",[Vector3(-5,.08,25),Vector3(-12,.08,38),Vector3(-19,.08,51),Vector3(-27,.08,66),Vector3(-33,.08,70),Vector3(-39,.08,75)]))
	report.routes.append(await walk_route("hall_steps",[Vector3(0,.08,159),Vector3(0,.48,166.6)]))
	report.checks.campus_routes=report.routes.all(func(r):return r.passed)
	await check_barriers()
	await place(Vector3(0,.6,166.2),Vector3(0,.6,150));await frames(15)
	report.camera_hit_length_m=player.arm.get_hit_length()
	report.checks.camera_wall_collision=report.camera_hit_length_m<3.5 and report.camera_hit_length_m>.05
	Engine.time_scale=1;Engine.physics_ticks_per_second=60
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
		for s in [["avenue",Vector3(0,.15,108),Vector3(0,1,140)],["pavilion",Vector3(38.8,.45,75),Vector3(42.5,1,82)],["grove",Vector3(-29,.15,66),Vector3(-19,1,39)]]:
			for quality in [false,true]:await sample_quality(quality,s[1],s[2],s[0])
	save_report()
