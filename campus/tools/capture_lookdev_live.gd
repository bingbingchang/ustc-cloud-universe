extends SceneTree
func _initialize():call_deferred("run")
func run():
	var compare="--compare-diorama" in OS.get_cmdline_user_args()
	var scene="res://scenes/diorama.tscn" if compare else "res://scenes/lookdev_live.tscn"
	var campus=load(scene).instantiate();root.add_child(campus)
	await process_frame
	var proof=load("res://scripts/lookdev_live_proof.gd").new()
	if "--live-motion" in OS.get_cmdline_user_args():await proof.capture_motion(campus)
	else:await proof.capture_stills(campus)
