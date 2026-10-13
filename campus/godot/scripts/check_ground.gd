extends SceneTree
func _initialize():call_deferred("audit")
func audit():
	var scene=load("res://scenes/diorama.tscn").instantiate();root.add_child(scene)
	await physics_frame;await physics_frame
	for p in [Vector3(22,0,143),Vector3(-27,0,139),Vector3(20,0,215),Vector3(73,0,230),Vector3(0,0,155)]:
		var down=PhysicsRayQueryParameters3D.create(p+Vector3.UP*3,p-Vector3.UP*3)
		var up=PhysicsRayQueryParameters3D.create(p-Vector3.UP*3,p+Vector3.UP*3)
		print("GROUND_AUDIT ",p," down=",not scene.get_world_3d().direct_space_state.intersect_ray(down).is_empty()," up=",not scene.get_world_3d().direct_space_state.intersect_ray(up).is_empty())
	quit()
