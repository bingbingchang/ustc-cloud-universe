extends SceneTree
var report={"test":"actual imported GLB locomotion; fixed-time full cycles at 20 Hz","actors":{},"passed":true}
func _initialize():call_deferred("run")
func run():
	var registry={};var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/wave2_nodes.json"))
	var points=preload("res://scripts/scene_modules.gd").story_nodes()
	# The authoritative new home file is available even during root integration.
	if FileAccess.file_exists("res://data/north_axis_layout.json"):
		var north=JSON.parse_string(FileAccess.get_file_as_string("res://data/north_axis_layout.json"))
		for n in north.get("story_nodes",[]):points[n.id]=n
	for entry in data.actors:
		var s=entry.duplicate(true);s.merge(points[entry.node_ref],true);s.id=entry.id;registry[s.id]=s
	var controller=preload("res://scripts/campus_wander.gd").new();controller.setup(registry)
	for id in registry:
		var s=registry[id];var actor=load("res://assets/"+s.asset+".glb").instantiate();root.add_child(actor)
		actor.set_script(load("res://scripts/"+s.script));actor.role=s.role;actor.prepare()
		actor.position=Vector3(s.position[0],s.position[1],s.position[2]);actor.rotation.y=s.heading
		var prop:Node3D;var prop_initial=Vector3.ZERO
		if id in ["meituan","leaf_cat"]:
			var anchor=Node3D.new();root.add_child(anchor);anchor.global_transform=actor.global_transform
			prop=actor.bones["Parcel" if id=="meituan" else "Leaf"];prop.reparent(anchor,true);prop_initial=anchor.global_position
		var period=controller.duration(id);var count=int(ceil(period*20));var dt=period/count
		var result={"cycle_seconds":period,"route_length_m":controller.paths[id].length,"sample_count":count+1,"max_speed_mps":0.0,"max_stance_slide_mps":0.0,"max_ik_error_m":0.0,"max_swing_lift_m":0.0,"walking_samples":0,"story_samples":0,"finite":true,"prop_anchor_fixed":true,"home":s.position,"states":{}}
		var previous={};var first={};var starts={};var closure_pos=0.0;var closure_basis=0.0
		for i in range(count+1):
			var t=i*dt;var m=controller.sample(id,t)
			actor.position=m.position;actor.rotation.y=m.heading;actor.pose(m.story_time);actor.apply_locomotion(m)
			var state=actor.last_state();var feet:Dictionary=state.feet_world
			result.max_speed_mps=maxf(result.max_speed_mps,m.speed_mps)
			result.finite=result.finite and state.finite and actor.global_position.is_finite()
			result.walking_samples+=int(m.phase=="walk");result.story_samples+=int(m.story_active)
			if not result.states.has(m.phase):result.states[m.phase]={"t":t,"position":[m.position.x,m.position.y,m.position.z],"gait_units":m.gait_units}
			if is_instance_valid(prop):result.prop_anchor_fixed=result.prop_anchor_fixed and prop.get_parent().global_position.distance_to(prop_initial)<.000001
			var errors=state.get("foot_target_error_m",state.get("foot_error_m",{}))
			for key in errors:result.max_ik_error_m=maxf(result.max_ik_error_m,errors[key])
			for key in feet:
				result.finite=result.finite and feet[key].is_finite()
				result.max_swing_lift_m=maxf(result.max_swing_lift_m,m.feet[key].lift*m.walking_weight)
				if not previous.is_empty() and m.walking_weight>.99999 and previous.m.walking_weight>.99999:
					if m.feet[key].stance and previous.m.feet[key].stance and m.feet[key].plant_id==previous.m.feet[key].plant_id:
						result.max_stance_slide_mps=maxf(result.max_stance_slide_mps,feet[key].distance_to(previous.feet[key])/dt)
			if i==0:
				first=m
				for b in actor.find_children("*","Node3D",true,false):starts[b.get_path()]=b.global_transform
			elif i==count:
				result["root_loop_error_m"]=m.position.distance_to(first.position)
				for b in actor.find_children("*","Node3D",true,false):
					var start:Transform3D=starts[b.get_path()];var end:Transform3D=b.global_transform
					closure_pos=maxf(closure_pos,start.origin.distance_to(end.origin));closure_basis=maxf(closure_basis,start.basis.x.distance_to(end.basis.x))
			previous={"m":m,"feet":feet}
		result["model_loop_error_m"]=closure_pos;result["model_loop_basis_error"]=closure_basis
		result["passed"]=result.finite and result.prop_anchor_fixed and result.max_speed_mps<=.9001 and result.max_stance_slide_mps<.003 and result.max_ik_error_m<.004 and result.max_swing_lift_m>.012 and result.walking_samples>100 and result.story_samples>100 and closure_pos<.0001 and closure_basis<.0001
		report.actors[id]=result;report.passed=report.passed and result.passed
		print("WANDER_ACTOR ",id," ",JSON.stringify(result));actor.queue_free()
	var out=ProjectSettings.globalize_path("res://../renders/wandering")
	DirAccess.make_dir_recursive_absolute(out);var f=FileAccess.open(out+"/locomotion_validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("WANDER_VALIDATED ",report.passed);quit(0 if report.passed else 1)
