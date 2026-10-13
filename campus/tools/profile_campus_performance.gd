extends SceneTree
func _initialize():call_deferred("run")
func run():
	var c=load("res://scenes/campus_performance.tscn").instantiate();root.add_child(c);await process_frame
	c.get_viewport().msaa_3d=Viewport.MSAA_4X;c.get_viewport().use_taa=true
	await load("res://scripts/campus_performance_profile.gd").new().run(c)
