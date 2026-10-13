extends SceneTree
func _initialize():call_deferred("verify")
func verify():
	var results={};var failed=false
	for role in ["cyclist","bench_reader","photographer","study_walk"]:
		var doc=GLTFDocument.new();var state=GLTFState.new()
		var err=doc.append_from_file("res://assets/ambient_"+role+".glb",state)
		if err!=OK:push_error("GLB load failed "+role);quit(2);return
		var actor=doc.generate_scene(state);root.add_child(actor)
		actor.set_script(load("res://scripts/ambient_actor.gd"));actor.role=role;actor.prepare()
		var finite=true;var hands=0.0;var feet=0.0;var all_ik=0.0;var phases={};var samples=[]
		var duration={"cyclist":64.0,"bench_reader":32.0,"photographer":22.0,"study_walk":46.0}[role]
		for i in range(int(duration*20)+1):
			actor.pose(i/20.0);var s=actor.last_state();finite=finite and s.finite;phases[s.phase]=true
			for key in s.ik_error_m:all_ik=maxf(all_ik,float(s.ik_error_m[key]))
			for side in ["L","R"]:hands=maxf(hands,s.hand_target_error_m[side])
			if role=="cyclist" and s.push_weight<.00001:
				for side in ["L","R"]:feet=maxf(feet,s.pedal_contact_m[side])
			if role=="bench_reader":
				for side in ["L","R"]:feet=maxf(feet,absf(s.foot_ground_error_m[side]))
			if role in ["photographer","study_walk"]:
				for side in ["L","R"]:feet=maxf(feet,absf(s.foot_target_error_m[side]))
			if i%20==0:samples.append(s)
		var closure=actor.validate_loop()
		var pass_actor=finite and closure.closed and hands<.012 and feet<.012 and all_ik<.012
		failed=failed or not pass_actor
		results[role]={"passed":pass_actor,"finite":finite,"loop":closure,"max_hand_error_m":hands,"max_foot_error_m":feet,"max_all_phase_ik_error_m":all_ik,"sample_rate_fps":20,"poses_checked":int(duration*20)+1,"phases":phases.keys(),"samples":samples}
		# Save actual runtime matrices for an independent Blender contact proof.
		var proofs={"cyclist":[["ride",4.0],["push",25.0],["pause",34.0]],"bench_reader":[["read",2.0],["page",7.0]],"photographer":[["photo",8.0],["review",19.0]],"study_walk":[["walk",4.0],["read",15.0]]}
		for proof in proofs[role]:
			actor.pose(proof[1]);var transforms={}
			for key in actor.bones:
				var x=actor.bones[key].transform
				transforms["Ambient_"+key]={"origin":[x.origin.x,x.origin.y,x.origin.z],"basis":[[x.basis.x.x,x.basis.x.y,x.basis.x.z],[x.basis.y.x,x.basis.y.y,x.basis.y.z],[x.basis.z.x,x.basis.z.y,x.basis.z.z]]}
			var f=FileAccess.open("res://../renders/population/"+role+"_"+proof[0]+"_pose.json",FileAccess.WRITE);f.store_string(JSON.stringify(transforms));f.close()
		actor.queue_free()
	var f=FileAccess.open("res://../renders/population/animation_validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(results,"\t"));f.close()
	print("AMBIENT_VERIFY ",not failed," ",JSON.stringify({"cyclist_hand":results.cyclist.max_hand_error_m,"cyclist_foot":results.cyclist.max_foot_error_m,"reader_foot":results.bench_reader.max_foot_error_m}))
	quit(1 if failed else 0)
