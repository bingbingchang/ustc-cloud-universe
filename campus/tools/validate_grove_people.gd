extends SceneTree
func _initialize():call_deferred("run")
func run():
	var c=load("res://scenes/campus_performance.tscn").instantiate();root.add_child(c);await physics_frame
	var layer=c.grove_life;layer.set_process(false);var failures=[];var loops={};var sampled=0
	for id in layer.actors:
		var actor=layer.actors[id].root;loops[id]=actor.validate_loop()
		var start=layer.sample(id,0);var end=layer.sample(id,layer.registry[id].cycle_seconds)
		if not loops[id].closed or start.position.distance_to(end.position)>.0001:failures.append({"loop":id})
		for k in range(int(layer.registry[id].cycle_seconds*4)+1):
			layer.pose(k*.25);await physics_frame;sampled+=1
			var state=actor.last_state();var pos=actor.global_position
			if not state.finite:failures.append({"nonfinite":id,"time":k*.25})
			for error in state.ik_error_m.values():
				if error>.005:failures.append({"ik":id,"error":error})
			var q=PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.2,pos-Vector3.UP*.2,1,[layer.actors[id].body.get_rid()]);var hit=c.get_world_3d().direct_space_state.intersect_ray(q)
			if hit.is_empty() or absf(hit.position.y-(pos.y-.005))>.02:failures.append({"ground":id,"at":str(pos)})
			var shape=CapsuleShape3D.new();shape.radius=.26;shape.height=1.5
			var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*.8);query.exclude=[layer.actors[id].body.get_rid(),c.player.get_rid()]
			var hits=c.get_world_3d().direct_space_state.intersect_shape(query)
			for obstacle in hits:failures.append({"obstacle":String(obstacle.collider.name),"actor":id,"time":k*.25})
	var report={"passed":failures.is_empty(),"new_people":layer.actors.size(),"pose_samples":sampled,"loops":loops,"failures":failures}
	var f=FileAccess.open("res://../renders/west_grove/people_validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));print("GROVE_PEOPLE ",report.passed," samples=",sampled," failures=",failures.size())
	c.queue_free();await process_frame;quit(0 if report.passed else 1)
