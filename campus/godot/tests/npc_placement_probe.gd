extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://scenes/campus_game.tscn").instantiate();root.add_child(game)
	for i in range(8):await physics_frame
	var excluded:Array[RID]=[game.player.get_rid()]
	for actor in game.hero_interactions.actors.values():excluded.append(actor.contact.get_rid())
	var space=game.get_world_3d().direct_space_state
	for id in game.hero_interactions.actors:
		var actor=game.hero_interactions.actors[id]
		var samples=[0]
		if id not in ["library","network"]:continue
		if id=="library":samples=[-6,-4,-2,-1,0,1,2,3,4,5]
		if id=="network":samples=[-6,-5,-4,-3,-2,-1,0,1,2,3]
		for dx in samples:
			var at=actor.home+(Vector3(0,0,dx) if id=="library" else Vector3(dx,0,0))
			var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*4,at-Vector3.UP*3,1,excluded))
			if hit.is_empty():continue
			var query=PhysicsShapeQueryParameters3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.30;capsule.height=1.6
			query.shape=capsule;query.exclude=excluded;query.transform.origin=hit.position+Vector3.UP*.83
			print("PLACEMENT ",id," x=",at.x," z=",at.z," y=",hit.position.y," surface=",hit.collider.name," blocked=",space.intersect_shape(query).size())
	quit()
