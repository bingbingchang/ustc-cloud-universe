extends SceneTree
## Standalone entry: no changes to main scene or its ready/input callbacks.
func _initialize():call_deferred("run")
func run():
	var main=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(main);await process_frame
	await preload("res://scripts/north_axis_profile.gd").new().run(main)
