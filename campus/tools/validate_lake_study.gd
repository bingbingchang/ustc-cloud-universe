extends SceneTree
func _initialize():call_deferred("run")
func run():
	var c=load("res://scenes/lake_study.tscn").instantiate();root.add_child(c);await process_frame
	var result=await load("res://scripts/lake_study_qa.gd").new().validate(c)
	quit(0 if result.passed else 1)
