extends SceneTree

var game
var failure_count=0
var visual=false

func check(condition:bool,message:String):
	print("HERO_CHECK ","PASS " if condition else "FAIL ",message)
	if not condition:failure_count+=1

func _initialize():call_deferred("run")

func photo(filename:String):
	if not visual:return
	await process_frame;await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://../renders/heroes/"+filename+".png")

func run():
	visual="--hero-visual" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../renders/heroes"))
	game=load("res://scenes/campus_game.tscn").instantiate();root.add_child(game)
	for i in range(12):await physics_frame
	var heroes=game.hero_interactions
	check(heroes.actors.size()==15,"fifteen individually designed NPC instances")
	for id in heroes.actors:
		heroes.travel_to(id)
		for i in range(15):await physics_frame
		var excluded:Array[RID]=[game.player.get_rid()]
		for a in heroes.actors.values():excluded.append(a.contact.get_rid())
		var query=PhysicsShapeQueryParameters3D.new();var shape=CapsuleShape3D.new();shape.radius=.32;shape.height=1.6
		query.shape=shape;query.exclude=excluded
		query.transform.origin=heroes.actors[id].global_position+Vector3(0,.92,0)
		var overlaps=game.get_world_3d().direct_space_state.intersect_shape(query)
		check(overlaps.is_empty(),id+" body clear of world obstacles")
		if not overlaps.is_empty():
			for overlap in overlaps:print("NPC_OBSTACLE ",id," ",overlap.collider.name)
			var ground_query=PhysicsRayQueryParameters3D.create(actor_position(heroes.actors[id])+Vector3.UP*4,actor_position(heroes.actors[id])-Vector3.UP*2,1,excluded)
			print("NPC_GROUND ",id," ",game.get_world_3d().direct_space_state.intersect_ray(ground_query))
			for dx in [-4,-2,2,4]:
				query.transform.origin=heroes.actors[id].global_position+Vector3(dx,.92,0)
				print("POSITION_CANDIDATE ",id," dx=",dx," overlaps=",game.get_world_3d().direct_space_state.intersect_shape(query).size())
		check(game.player.is_on_floor(),id+" approach has walkable ground")
		check(heroes.actors[id].bones.size()>10,id+" shared human rig loaded")
		var actor=heroes.actors[id]
		check(actor.animator.get_animation_list().size()==6,id+" six keyed animation clips loaded")
		actor.manual_state="greet";actor.current_state="greet";actor.animator.play("greet",0);actor.manual_time=0
		await physics_frame;await physics_frame
		var before=actor.bones.HandR.global_position
		actor.manual_time=1.4;await physics_frame;await physics_frame
		check(before.distance_to(actor.bones.HandR.global_position)>.35,id+" greeting moves hand visibly")
		actor.manual_state="work";actor.current_state="work";actor.animator.play("work",0);actor.manual_time=0
		await physics_frame;await physics_frame
		before=actor.bones.HandR.global_position
		actor.manual_time=1.5;await physics_frame;await physics_frame
		check(before.distance_to(actor.bones.HandR.global_position)>.012,id+" occupational action changes hand pose")
		actor.manual_state="";actor.manual_time=-1
		heroes.open_dialogue(id)
		check(not game.player.enabled and heroes.panel.visible,id+" dialogue blocks world controls")
		check(heroes.active_id==id and heroes.transcript.get_parsed_text().length()>10,id+" greeting visible")
		if "--hero-api-all" in OS.get_cmdline_user_args():
			heroes.question.text=actor.definition.questions[0];heroes.send_question()
			var deadline=Time.get_ticks_msec()+100000
			while heroes.busy and Time.get_ticks_msec()<deadline:await process_frame
			check(heroes.histories[id].size()==2,id+" real Qwen answer in isolated history")
			check(heroes.completed.has(id),id+" response cites retrieved knowledge")
		await photo(id+"_dialogue")
		heroes.close_ui()
		check(game.player.enabled,id+" closes and restores controls")
	heroes.travel_to("solar");heroes.toggle_journal();await photo("hero_journal")
	heroes.close_ui();heroes.travel_to("library");heroes.open_dialogue("library")
	if "--hero-api" in OS.get_cmdline_user_args():
		var previous_turns=heroes.histories.library.size()
		heroes.question.text="学生能借几本书，借多久？";heroes.send_question()
		var until=Time.get_ticks_msec()+100000
		while heroes.busy and Time.get_ticks_msec()<until:await process_frame
		check(heroes.histories.library.size()==previous_turns+2,"real cloud chat recorded")
		check(heroes.completed.has("library"),"real answer has numbered evidence")
		await photo("cloud_answer")
		heroes.source_button.pressed.emit()
		check(heroes.source_panel.visible and "60天" in heroes.source_text.get_parsed_text(),"source panel displays original borrowing rule")
		await photo("cloud_evidence")
	print("HERO_SMOKE_COMPLETE failures=",failure_count)
	quit(0 if failure_count==0 else 1)

func actor_position(actor:Node3D)->Vector3:return actor.global_position
