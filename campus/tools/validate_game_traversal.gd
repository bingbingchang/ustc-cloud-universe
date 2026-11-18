extends SceneTree
## Ten real minutes in the actual game; no model calls and no synthetic FPS claim.
var game
var report={"completed":false,"passed":true,"npcs":[],"samples":[],"failures":[]}
var started=0
var next_sample=0
var previous_draw=0
var forced_draws=0
var output="res://../renders/runtime_optimization/traversal_10_minutes.json"
func _initialize():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--traversal-output="):output=argument.trim_prefix("--traversal-output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	call_deferred("run")
func check(value:bool,message:String):
	if not value:report.passed=false;report.failures.append(message);push_warning(message)
func _process(_delta)->bool:
	if not is_instance_valid(game) or started==0:return false
	if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	# Keep exercising rendering if Windows occludes the test window. This is
	# a stability test; formal FPS measurements use ordinary presented frames.
	if Engine.get_frames_drawn()==previous_draw:RenderingServer.force_draw(false);forced_draws+=1
	previous_draw=Engine.get_frames_drawn()
	var elapsed=Time.get_ticks_msec()-started
	if elapsed>=next_sample:
		next_sample=elapsed+10000
		report.samples.append({"seconds":elapsed/1000.0,"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
			"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"drawn_frames":Engine.get_frames_drawn(),"forced_draws":forced_draws})
	return false
func wait_for(seconds:float):
	var until=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:await process_frame
func run():
	game=load("res://scenes/campus_game.tscn").instantiate();root.add_child(game)
	await process_frame;await physics_frame
	Engine.max_fps=30;OS.low_processor_usage_mode=false
	root.size=Vector2i(1440,810);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.player.touch_mode=true
	started=Time.get_ticks_msec();report.start_nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	report.terrain_enabled=false;report.real_minutes=10
	var heroes=game.hero_interactions
	check(heroes.definitions.size()==15,"The complete 15-NPC roster is missing")
	var moved_total=0.0;var jumped=false
	for hero in heroes.definitions:
		var segment=Time.get_ticks_msec()
		var travelled=await heroes.travel_to(hero.id);await wait_for(1.0)
		check(travelled,"Travel failed: "+hero.id)
		var actor=heroes.actors[hero.id]
		var floor=game.player.is_on_floor()
		check(floor,"Player did not settle onto a floor near "+hero.id)
		var before=game.player.global_position;game.player.touch_move=Vector2(0,-1)
		await wait_for(.45);game.player.touch_move=Vector2.ZERO
		var moved=Vector2(game.player.global_position.x-before.x,game.player.global_position.z-before.z).length();moved_total+=moved
		game.player.touch_move=Vector2(0,1);await wait_for(.45);game.player.touch_move=Vector2.ZERO;await wait_for(.3)
		var base_y=game.player.global_position.y;game.player.touch_jump=true
		var max_y=base_y;var until=Time.get_ticks_msec()+1500
		while Time.get_ticks_msec()<until:
			await process_frame;max_y=maxf(max_y,game.player.global_position.y)
		jumped=jumped or max_y-base_y>.4
		await heroes.open_dialogue(hero.id);await process_frame
		check(heroes.active_id==hero.id and heroes.panel.visible and not game.player.enabled,"Dialogue did not lock controls: "+hero.id)
		heroes.close_ui();await process_frame
		check(game.player.enabled and not heroes.modal_active,"Closing dialogue did not restore controls: "+hero.id)
		game.player.toggle_view();check(not game.player.third_person,"First-person toggle failed")
		game.player.toggle_view();check(game.player.third_person,"Third-person toggle failed")
		game.player.set_free_camera(true);check(game.player.free_camera,"Free camera toggle failed")
		game.player.set_free_camera(false);check(not game.player.free_camera,"Walking camera restore failed")
		game.campus_agent.open_panel();await process_frame;check(not game.player.enabled,"Guide did not lock controls")
		game.campus_agent.close_panel();await process_frame;check(game.player.enabled,"Guide did not release controls")
		report.npcs.append({"id":hero.id,"travelled":travelled,"floor":floor,"walked_m":moved,"jump_height_m":max_y-base_y,
			"player":[game.player.global_position.x,game.player.global_position.y,game.player.global_position.z],
			"actor":[actor.global_position.x,actor.global_position.y,actor.global_position.z]})
		print("TRAVERSAL_NPC ",hero.id," floor=",floor," moved=",snappedf(moved,.01))
		FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
		await wait_for(maxf(0,35.0-float(Time.get_ticks_msec()-segment)/1000.0))
	check(moved_total>5.0,"Walking did not produce sufficient motion");check(jumped,"Jump did not leave the floor")
	await heroes.travel_to("student")
	await wait_for(maxf(0,600.0-float(Time.get_ticks_msec()-started)/1000.0))
	report.elapsed_seconds=float(Time.get_ticks_msec()-started)/1000.0
	report.end_nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	report.completed=true;report.walked_total_m=moved_total;report.jumped=jumped
	check(report.end_nodes-report.start_nodes<150,"Unexpected node accumulation")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRAVERSAL_COMPLETE passed=",report.passed," seconds=",report.elapsed_seconds);quit(0 if report.passed else 1)
