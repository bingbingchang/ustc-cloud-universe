extends SceneTree
## Headless runner, intentionally does not trigger the north-axis capture flags.
func _initialize():call_deferred("run")

func run():
	var path="res://scenes/lookdev_live.tscn"
	if not ResourceLoader.exists(path):
		push_error("LookDev Live scene is not ready: "+path);quit(1);return
	var campus=load(path).instantiate();root.add_child(campus)
	await process_frame;await physics_frame
	if campus.get("live_initialized")!=true:
		push_error("LookDev Live did not finish initialization; aborting QA instead of validating a partial scene.");quit(1);return
	var suite=load("res://scripts/lookdev_live_qa.gd").new()
	if "--lookdev-alignment-only" in OS.get_cmdline_user_args():
		campus.life_layer.set_process(false);campus.wave2_layer.set_process(false)
		campus.player.frozen=true;campus.player.enabled=false
		var alignment=await suite._alignment(campus)
		suite.save_live("alignment_diagnostic.json",alignment)
		print("LOOKDEV_ALIGNMENT trees=",alignment.tree_instances," samples=",alignment.tree_samples.size()," failures=",alignment.tree_failures.size()," passed=",alignment.passed)
		quit(0 if alignment.passed else 1);return
	var report=await suite.validate(campus)
	quit(0 if report.passed else 1)
