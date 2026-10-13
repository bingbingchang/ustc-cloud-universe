extends Node
const OUT := "res://../renders/wildlife/"
var checks: Array[Dictionary] = []
var lab: Node3D

func save_json(name: String, value: Variant) -> void:
	var file := FileAccess.open(OUT+name,FileAccess.WRITE); file.store_string(JSON.stringify(value,"\t"))

func check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name":name,"passed":passed,"detail":detail}); print("WILDLIFE_CHECK ",name," ",passed)

func sample_clip(animal: Node3D, clip: String, time: float) -> void:
	animal.preview_clip(clip); animal.animation_tree.advance(0); animal.animation_tree.advance(time)
	# Skeleton is updated once before querying contact transforms or rendering.
	animal.skeleton.force_update_all_bone_transforms()

func view(animal: Node3D, offset: Vector3, target_y: float) -> void:
	lab.camera.current = true; lab.camera.global_position = animal.global_position+animal.global_basis*offset
	lab.camera.look_at(animal.global_position+Vector3.UP*target_y)

func draw_frame() -> void:
	for i in range(3): await get_tree().process_frame
	await RenderingServer.frame_post_draw

func capture() -> void:
	lab.hud.visible = false
	var shots := [
		[0,"idle",.6,"01_cat_front",Vector3(0,.34,-1.17),.25],
		[0,"idle",.6,"02_cat_side",Vector3(-1.02,.30,0),.24],
		[0,"walk",.36,"03_cat_walk",Vector3(-.85,.31,-.65),.23],
		[0,"sit",1.0,"04_cat_sit",Vector3(-.75,.35,-.8),.22],
		[0,"lie",1.0,"05_cat_rest",Vector3(-.75,.27,-.65),.13],
		[0,"lick",1.2,"06_cat_lick",Vector3(-.7,.25,-.65),.13],
		[1,"swim",.5,"07_mallard_male",Vector3(-.85,.46,-.85),.25],
		[2,"idle",.8,"08_mallard_female",Vector3(-.85,.44,-.75),.25],
		[3,"idle",.7,"09_sparrow_front",Vector3(-.15,.14,-.28),.084],
		[3,"idle",.7,"10_sparrow_side",Vector3(-.31,.10,-.018),.085],
		[3,"fly",.095,"11_sparrow_wings",Vector3(-.22,.19,-.25),.087],
		[0,"idle",.6,"13_cat_rear",Vector3(-.70,.37,.9),.24],
		[1,"swim",.5,"14_mallard_side",Vector3(-1.05,.33,0),.25],
		[2,"preen",1.6,"15_mallard_preen",Vector3(-.85,.45,-.5),.25],
		[6,"idle",.7,"16_squirrel_front",Vector3(-.40,.17,-.47),.075],
		[6,"walk",.24,"17_squirrel_walk",Vector3(-.52,.16,0),.075],
		[6,"forage",1.2,"18_squirrel_forage",Vector3(-.40,.16,-.40),.075],
		[7,"idle",.7,"19_hedgehog_front",Vector3(-.36,.13,-.36),.06],
		[7,"walk",.32,"20_hedgehog_walk",Vector3(-.43,.11,0),.06],
		[7,"hide",1.0,"21_hedgehog_hide",Vector3(-.36,.13,-.36),.06],
	]
	var rows: Array[Dictionary] = []
	for shot in shots:
		var animal: Node3D = lab.animals[shot[0]]
		sample_clip(animal,shot[1],shot[2]); view(animal,shot[4],shot[5]); await draw_frame()
		var filename: String = shot[3]+".png"
		get_viewport().get_texture().get_image().save_png(OUT+filename)
		rows.append({"file":filename,"asset":animal.asset_name,"clip":shot[1],"time":shot[2],"camera":str(lab.camera.global_position),"target":str(animal.global_position+Vector3.UP*shot[5]),"source":"Godot native viewport"})
	for animal in lab.animals: sample_clip(animal,"idle",.4)
	lab.camera.position = Vector3(-6,5.5,8); lab.camera.look_at(Vector3(0,.3,0)); await draw_frame()
	get_viewport().get_texture().get_image().save_png(OUT+"12_lab_overview.png")
	save_json("capture_report.json",{"width":1600,"height":900,"shots":rows,"overview":"12_lab_overview.png","source":"Godot native viewport; no retouching"})

func bone_point(animal: Node3D, name: String, local: Vector3 = Vector3.ZERO) -> Vector3:
	var skeleton: Skeleton3D = animal.skeleton; var index := skeleton.find_bone(name)
	return skeleton.global_transform * skeleton.get_bone_global_pose(index) * local

func verify() -> bool:
	check("eight_instances_six_assets",lab.animals.size()==8)
	var animation_rows: Array[Dictionary] = []
	var finite := true; var textured := true; var skin_count := 0
	for animal in lab.animals:
		var clips: PackedStringArray = animal.available_clips()
		var new_ground_animal: bool = animal.species in ["squirrel","hedgehog"]
		check(animal.asset_name+"_rig_and_clips",animal.skeleton.get_bone_count()>=(6 if new_ground_animal else 11) and clips.size()>=(4 if new_ground_animal else 8),{"bones":animal.skeleton.get_bone_count(),"clips":clips})
		for mesh in animal.model.find_children("*","MeshInstance3D",true,false):
			if mesh.skin != null: skin_count+=1
			for surface in mesh.mesh.get_surface_count():
				var material: Material = mesh.get_active_material(surface)
				if material.resource_name in ["Wildlife_CatCoat","Wildlife_Body","Wildlife_Head"]:
					textured = textured and material is StandardMaterial3D and material.albedo_texture != null
		for clip in clips:
			var duration: float = animal.animation_player.get_animation(clip).length
			for phase in [0.0,.25,.5,.75,.999]:
				sample_clip(animal,clip,duration*phase)
				for index in animal.skeleton.get_bone_count():
					var pose: Transform3D = animal.skeleton.get_bone_global_pose(index)
					finite = finite and pose.origin.is_finite() and pose.basis.is_finite()
			animation_rows.append({"asset":animal.asset_name,"clip":clip,"seconds":duration})
	check("all_poses_finite",finite); check("skinned_meshes",skin_count>15,skin_count); check("coat_textures_retained",textured)
	# Stance feet evaluated against actual bone transforms, not just route positions.
	var cat: Node3D = lab.animals[0]
	var foot_heights: Array[float] = []
	for phase in [0.0,.2,.4,.6,.8]:
		sample_clip(cat,"walk",phase*.96)
		for key in ["FrontL_Foot","FrontR_Foot","BackL_Foot","BackR_Foot"]:
			var p := bone_point(cat,key,Vector3(0,.0442798,0)); foot_heights.append(p.y-cat.global_position.y-.022)
	check("cat_feet_near_surface",foot_heights.min()>-.04 and foot_heights.max()<.11,{"min_m":foot_heights.min(),"max_m":foot_heights.max()})
	var heading: float = cat.rotation.y; cat.rotation.y=0
	sample_clip(cat,"walk",.12); var stance_a := bone_point(cat,"FrontL_Foot",Vector3(0,.0442798,0))
	sample_clip(cat,"walk",.16); var stance_b := bone_point(cat,"FrontL_Foot",Vector3(0,.0442798,0))
	var nominal: float=.16/(.64*cat.animation_player.get_animation("walk").length)
	var slip: float=(stance_b-stance_a+Vector3(0,0,-nominal*.04)).length(); cat.rotation.y=heading
	check("cat_stance_matches_world_speed",slip<.003,{"four_hundredths_second_slip_m":slip,"nominal_speed_m_s":nominal})
	var history: Array[Dictionary] = []; var maximum_step := 0.0; var duck_outside := 0; var bird_landing_error := 0.0
	var landings := 0; var unique_nodes := {}; var duck_entries := 0; var duck_exits := 0
	for animal in lab.animals:
		animal.clip_override=""; animal.moving=false; animal.transition_time=0; animal.pending_motion=false
		animal.state_time=0; animal.wait_time=.3; animal.observer=null; unique_nodes[animal.name]={}
	for tick in range(7200):
		for animal in lab.animals:
			var before: Vector3 = animal.global_position; var was_moving: bool = animal.moving
			animal.simulate(1.0/60)
			maximum_step=maxf(maximum_step,before.distance_to(animal.global_position))
			unique_nodes[animal.name][animal.node_index]=true
			if not animal.moving and was_moving and animal.species=="sparrow":
				landings+=1; bird_landing_error=maxf(bird_landing_error,animal.global_position.distance_to(animal.activity_nodes[animal.node_index]))
			if animal.species=="duck":
				if animal.current_clip=="enter_water":duck_entries+=1
				if animal.current_clip=="exit_water":duck_exits+=1
				if animal.moving and animal.mode_at(animal.node_index)=="water" and animal.mode_at(animal.target_index)=="water":
					if not Geometry2D.is_point_in_polygon(Vector2(animal.global_position.x,animal.global_position.z),animal.water_polygon):duck_outside+=1
		if tick%600==0:history.append({"seconds":tick/60.0,"animals":lab.animals.map(func(a):return a.snapshot())})
	check("continuous_routes",maximum_step<.06,{"max_displacement_per_tick_m":maximum_step})
	check("ducks_stay_in_water",duck_outside==0,duck_outside)
	check("duck_water_transitions",duck_entries>0 and duck_exits>0,{"enter_samples":duck_entries,"exit_samples":duck_exits})
	check("sparrow_landings",landings>3 and bird_landing_error<.005,{"landings":landings,"max_error_m":bird_landing_error})
	check("habitat_visits",unique_nodes.values().all(func(nodes):return nodes.size()>1),unique_nodes)
	# Approach, escape and recovery using a real observer Node3D.
	var observer := Node3D.new(); lab.add_child(observer)
	var reaction_rows: Array[Dictionary] = []
	for animal in [lab.animals[0],lab.animals[1],lab.animals[3],lab.animals[6],lab.animals[7]]:
		animal.moving=false; animal.pending_motion=false; animal.transition_time=0; animal.clip_override=""; animal.node_index=0
		animal.global_position=animal.activity_nodes[0]; animal.observer=observer
		animal.reaction_cooldown=0; animal.notice_latched=false; animal.threat_latched=false; animal.observer_known=false
		animal.play_clip("idle",true); animal.wait_time=20; animal.state_time=0
		observer.position=animal.global_position+Vector3(0,0,1.2 if animal.species=="hedgehog" else 1.8); animal.simulate(1.0/60)
		var watched: bool = animal.current_behavior=="watch"
		observer.position=animal.global_position+Vector3(0,0,.25); animal.simulate(1.0/60)
		var avoided: bool = animal.current_behavior=="hide" if animal.species=="hedgehog" else animal.moving or animal.pending_motion
		observer.position=Vector3(40,0,40)
		for tick in range(1800):animal.simulate(1.0/60)
		var recovered: bool = not animal.fleeing
		reaction_rows.append({"species":animal.species,"noticed":watched,"avoided":avoided,"recovered":recovered})
		check(animal.species+"_approach_recovery",watched and avoided and recovered,reaction_rows.back())
		animal.observer=null
	observer.queue_free()
	var passed := checks.all(func(row):return row.passed)
	save_json("validation.json",{"passed":passed,"checks":checks,"animation_samples":animation_rows,"behavior_samples":history,"reactions":reaction_rows,"simulation_seconds":120,"scope":"Independent wildlife lab only"})
	return passed

func performance() -> void:
	assert(DisplayServer.get_name()!="headless","Performance requires a rendered viewport")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	lab.hud.visible=true
	for animal in lab.animals:
		animal.manual_simulation=false; animal.clip_override=""; animal.wait_time=.2; animal.state_time=0
	var views: Array[Dictionary]=[]
	for spec in [["overview",-1],["cat_close",0],["water_close",1],["sparrow_close",3]]:
		for frame in range(60):
			if spec[1]<0:
				lab.camera.position=Vector3(-6,5.5,8);lab.camera.look_at(Vector3(0,.3,0))
			else:view(lab.animals[spec[1]],Vector3(-.22,.14,-.28) if spec[1]==3 else Vector3(-.9,.42,-1),.08 if spec[1]==3 else .24)
			await get_tree().process_frame
		var timings: Array[float]=[];var draws: Array[float]=[];var focus_frames:=0
		var previous:=Time.get_ticks_usec()
		for frame in range(180):
			if spec[1]>=0:view(lab.animals[spec[1]],Vector3(-.22,.14,-.28) if spec[1]==3 else Vector3(-.9,.42,-1),.08 if spec[1]==3 else .24)
			await get_tree().process_frame
			var now:=Time.get_ticks_usec();timings.append((now-previous)/1000.0);previous=now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			if lab.get_window().has_focus():focus_frames+=1
		var sum:=0.0
		for value in timings:sum+=value
		timings.sort();draws.sort()
		views.append({"view":spec[0],"mean_frame_ms":sum/timings.size(),"median_frame_ms":timings[90],"p95_frame_ms":timings[171],"median_draw_calls":draws[90],"focused_fraction":float(focus_frames)/180})
		print("WILDLIFE_PERFORMANCE ",views.back())
	var resolution:=Vector2i(lab.get_viewport().get_texture().get_size())
	save_json("performance.json",{"completed":true,"resolution":[resolution.x,resolution.y],"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"vsync_disabled":true,"live_animals":6,"msaa_3d":lab.get_viewport().msaa_3d,"taa":lab.get_viewport().use_taa,"warm_frames":60,"measure_frames":180,"views":views,"scope":"Independent lab, live animation and following close-up camera. Wall-clock delivered frame time, no screenshot readback; focus fraction recorded per view."})

func motion() -> void:
	lab.hud.visible=false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"motion_frames"))
	var segments := [[0,"walk",5.0],[0,"sit_down",2.0],[0,"sit",3.0],[0,"lie_down",2.0],[0,"lick",3.0],[1,"swim",5.0],[2,"preen",4.0],[3,"peck",3.0],[3,"takeoff",1.0],[3,"fly",3.0],[3,"land",1.0]]
	var frame_no := 0; var rows: Array[Dictionary] = []
	for segment in segments:
		var animal: Node3D=lab.animals[segment[0]]
		rows.append({"asset":animal.asset_name,"clip":segment[1],"first_frame":frame_no,"seconds":segment[2]})
		for i in range(int(segment[2]*24)):
			var time: float=i/24.0; sample_clip(animal,segment[1],time)
			view(animal,Vector3(-.70,.34,-.90) if animal.species=="cat" else (Vector3(-.8,.45,-.95) if animal.species=="duck" else Vector3(-.22,.13,-.27)),.23 if animal.species=="cat" else (.25 if animal.species=="duck" else .08))
			await draw_frame(); get_viewport().get_texture().get_image().save_jpg(OUT+"motion_frames/frame_%04d.jpg"%frame_no,.92); frame_no+=1
		print("WILDLIFE_MOTION ",segment[1])
	# Continuous autonomous locomotion proves displacement, landing and shore transitions.
	for animal in lab.animals:
		animal.clip_override=""; animal.moving=false; animal.pending_motion=false; animal.transition_time=0; animal.wait_time=.1; animal.state_time=0
	for index in [0,1,3]:
		var animal: Node3D=lab.animals[index]
		animal.begin_route(animal.neighbors(animal.node_index)[0])
		rows.append({"asset":animal.asset_name,"clip":"autonomous_life","first_frame":frame_no,"seconds":8})
		for i in range(8*24):
			for other in lab.animals:other.simulate(1.0/24)
			view(animal,Vector3(-1.4,.7,-1.4) if animal.species!="sparrow" else Vector3(-.7,.4,-.75),.23 if animal.species=="cat" else (.25 if animal.species=="duck" else .08))
			await draw_frame();get_viewport().get_texture().get_image().save_jpg(OUT+"motion_frames/frame_%04d.jpg"%frame_no,.92);frame_no+=1
	save_json("motion_manifest.json",{"fps":24,"width":1600,"height":900,"frames":frame_no,"segments":rows,"source":"Godot native viewport"})

func run(owner_lab: Node3D, args: PackedStringArray) -> void:
	lab=owner_lab
	for i in range(4): await get_tree().process_frame
	if "--wildlife-qa" in args:
		var passed: bool = await verify()
		get_tree().quit(0 if passed else 1)
		return
	elif "--wildlife-new-motion" in args: await new_motion()
	elif "--wildlife-motion" in args: await motion()
	elif "--wildlife-performance" in args: await performance()
	else: await capture()
	get_tree().quit()

func new_motion() -> void:
	lab.hud.visible=false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"second_batch_frames"))
	var frame_no:=0
	var rows: Array[Dictionary]=[]
	for index in [6,7]:
		var animal: Node3D=lab.animals[index]
		animal.reset_behavior(); animal.observer=null
		animal.begin_route(animal.neighbors(animal.node_index)[0])
		rows.append({"asset":animal.asset_name,"clip":"autonomous_life","first_frame":frame_no,"seconds":4})
		for i in range(96):
			animal.simulate(1.0/24)
			view(animal,Vector3(-.45,.16,-.45),.07)
			await draw_frame(); get_viewport().get_texture().get_image().save_jpg(OUT+"second_batch_frames/frame_%04d.jpg"%frame_no,.92); frame_no+=1
		for clip in (["forage","observe","trot"] if index==6 else ["sniff","hide","walk"]):
			rows.append({"asset":animal.asset_name,"clip":clip,"first_frame":frame_no,"seconds":2})
			for i in range(48):
				sample_clip(animal,clip,i/24.0); view(animal,Vector3(-.45,.16,-.45),.07)
				await draw_frame(); get_viewport().get_texture().get_image().save_jpg(OUT+"second_batch_frames/frame_%04d.jpg"%frame_no,.92); frame_no+=1
	save_json("second_batch_motion_manifest.json",{"fps":24,"width":1600,"height":900,"frames":frame_no,"segments":rows,"source":"Godot native viewport"})
