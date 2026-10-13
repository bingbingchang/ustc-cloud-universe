extends SceneTree
func _initialize():call_deferred("run")
func run():
	var scene="res://scenes/diorama.tscn" if "--sakura-diorama" in OS.get_cmdline_user_args() else "res://scenes/lookdev_live.tscn"
	var c=load(scene).instantiate();root.add_child(c);await process_frame
	var result=await load("res://scripts/sakura_qa.gd").new().validate(c)
	quit(0 if result.passed else 1)
