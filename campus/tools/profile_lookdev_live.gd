extends SceneTree
## Explicit LookDev entry; project default scene and old profiles are untouched.
func _initialize():call_deferred("run")

func run():
	var campus=load("res://scenes/lookdev_live.tscn").instantiate()
	root.add_child(campus)
	await process_frame
	await preload("res://scripts/lookdev_live_profile.gd").new().run(campus)
