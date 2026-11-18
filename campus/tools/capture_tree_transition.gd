extends SceneTree
## Capture the original free-camera route looking north through Guo Moruo Plaza.
## --tree-proof-dir=<absolute directory> keeps QA output outside game exports.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-proof-dir="):
			output = arg.trim_prefix("--tree-proof-dir=")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		push_error("A graphics device and --tree-proof-dir are required.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var campus = load("res://scenes/campus_game.tscn").instantiate()
	root.add_child(campus)
	campus.hud.hide()
	campus.player.set_free_camera(true)
	campus.player.frozen = true
	campus.player.set_physics_process(false)
	var camera: Camera3D = campus.player.camera
	camera.current = true
	var ok := true
	var positions := [Vector3(4.99,19,271.18), Vector3(4.92,17.88,275.60)]
	var targets := [Vector3(3.79,.14,334.69), Vector3(5.73,.10,353)]
	for i in range(5):
		var t := i / 4.0
		camera.global_position = positions[0].lerp(positions[1],t)
		camera.look_at(targets[0].lerp(targets[1],t))
		for frame in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if img.is_empty() or img.save_png(output.path_join("plaza_%d.png" % i)) != OK:
			ok = false
	if "--compare-footprint-cost" in OS.get_cmdline_user_args():
		var proxies: Array = campus.world.get_children().filter(func(n): return n.has_meta("far_canopy_footprint"))
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
		var gpu := [[],[]]
		var calls := [[],[]]
		for enabled in [true,false,false,true]:
			for proxy in proxies: proxy.visible = enabled
			for j in range(28):
				await RenderingServer.frame_post_draw
				if j < 8: continue
				gpu[int(enabled)].append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				calls[int(enabled)].append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		for samples in gpu+calls: samples.sort()
		print("FOOTPRINT_COST ",JSON.stringify({"gpu_ms_off":gpu[0][20],"gpu_ms_on":gpu[1][20],
			"draws_off":calls[0][20],"draws_on":calls[1][20],"batches":proxies.size()}))
	print("TREE_ROUTE_CAPTURE ", ok, " ", output)
	quit(0 if ok else 1)
