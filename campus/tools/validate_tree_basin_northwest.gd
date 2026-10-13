extends SceneTree
func _initialize():call_deferred("run")
func run():
	var c=load("res://scenes/campus_performance.tscn").instantiate();root.add_child(c);await process_frame
	var result=await load("res://scripts/tree_basin_northwest_qa.gd").new().validate(c)
	quit(0 if result.passed else 1)
