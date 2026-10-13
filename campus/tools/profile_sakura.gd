extends SceneTree
func _initialize():call_deferred("run")
func run():
	var c=load("res://scenes/lookdev_live.tscn").instantiate();root.add_child(c);await process_frame
	c.get_viewport().msaa_3d=Viewport.MSAA_4X;c.get_viewport().use_taa=true
	await load("res://scripts/sakura_profile.gd").new().run(c)
