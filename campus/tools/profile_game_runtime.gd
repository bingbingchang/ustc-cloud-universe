extends SceneTree
## Actual gameplay scene, normal rendered window, timed samples and native captures.
var game
var label="baseline"
var diagnostic="none"
var sample_seconds=12.0
var warm_seconds=5.0
var selected_views=PackedStringArray()
var output="res://../renders/runtime_optimization/"

class DiagnosticController extends Node:
	var game
	var mode="none"
	func _process(_delta):
		if mode=="no_reflection" and is_instance_valid(game.reflection_view):
			game.reflection_view.render_target_update_mode=SubViewport.UPDATE_DISABLED

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile-label="):label=arg.trim_prefix("--profile-label=")
		if arg.begins_with("--diagnostic="):diagnostic=arg.trim_prefix("--diagnostic=")
		if arg.begins_with("--sample-seconds="):sample_seconds=maxf(2,float(arg.trim_prefix("--sample-seconds=")))
		if arg.begins_with("--views="):selected_views=arg.trim_prefix("--views=").split(",")
		if arg.begins_with("--profile-output="):output=arg.trim_prefix("--profile-output=").trim_suffix("/")+"/"
	call_deferred("run")

func percentile(values:Array,fraction:float)->float:
	var sorted=values.duplicate();sorted.sort()
	return float(sorted[clampi(int((sorted.size()-1)*fraction),0,sorted.size()-1)])

func views()->Array:
	if "--diagnostic-sweep" in OS.get_cmdline_user_args():
		var cases=[]
		for mode in ["none","no_shadows","no_post","no_reflection","no_groundcover","no_trees"]:
			cases.append({"id":"near_"+mode,"eye":Vector3(-1,1.8,105),"target":Vector3(0,7,177),"mode":mode})
		return cases
	return [
		{"id":"avenue_near","eye":Vector3(-1,1.8,105),"target":Vector3(0,7,177)},
		{"id":"avenue_gate","eye":Vector3(0,1.8,12),"target":Vector3(0,5,110)},
		{"id":"hall_occluded","eye":Vector3(25,1.8,225),"target":Vector3(0,5,100)},
		{"id":"avenue_far","eye":Vector3(-65,1.8,220),"target":Vector3(0,6,100)},
		{"id":"lake_toward_trees","eye":Vector3(65,1.8,101),"target":Vector3(0,5,105)},
		{"id":"gate_away","eye":Vector3(0,1.8,15),"target":Vector3(0,3,-25)}]

func run():
	if DisplayServer.get_name()=="headless":push_error("GPU profile requires a rendered window");quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	game=load("res://scenes/campus_game.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	print("PROFILE_RENDER_MODE low_processor=",OS.low_processor_usage_mode," render_loop=",RenderingServer.is_render_loop_enabled())
	OS.low_processor_usage_mode=false
	var window=game.get_window();window.size=Vector2i(1440,810);window.always_on_top=true
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	window.title="USTC runtime profile / "+label
	window.grab_focus();DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED,window.get_window_id());Engine.max_fps=0
	game.player.set_free_camera(true);game.player.frozen=true;game.player.enabled=false
	game.player.avatar.hide() # Eye-height free-camera samples must not intersect our own head.
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var controller=DiagnosticController.new();controller.game=game;controller.mode=diagnostic;controller.process_priority=100000;root.add_child(controller)
	if diagnostic=="no_shadows":game.sun.shadow_enabled=false
	if diagnostic=="no_post":game.live_environment.ssil_enabled=false;game.live_environment.ssr_enabled=false
	if diagnostic=="no_sakura":
		for node in game.world.get_children():
			if node is GeometryInstance3D and node.get_meta("sakura_authored",false):node.hide()
	var report={"label":label,"diagnostic":diagnostic,"engine":Engine.get_version_info().string,
		"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),
		"sample_seconds":sample_seconds,"warm_seconds":warm_seconds,"views":[],"completed":false,
		"notes":"Wall-clock delivered frame time, all NPCs and animations live; primitives include shadow, depth and reflection passes; not isolated GPU execution time."}
	report["source_sha256"]={}
	for path in ["scripts/campus_game.gd","scripts/campus_performance.gd","scripts/runtime_render_policy.gd","scripts/tree_hlod.gd","project.godot"]:
		if FileAccess.file_exists("res://"+path):report.source_sha256[path]=FileAccess.get_sha256("res://"+path)
	report["arguments"]=Array(OS.get_cmdline_user_args())
	var visibility={}
	for node in game.world.get_children():
		if node is GeometryInstance3D:visibility[node]=node.visible
	var post=[game.live_environment.ssao_enabled,game.live_environment.ssil_enabled,game.live_environment.ssr_enabled]
	for spec in views():
		if not selected_views.is_empty() and spec.id not in selected_views:continue

		if spec.has("mode"):
			controller.mode=spec.mode;game.sun.shadow_enabled=spec.mode!="no_shadows"
			game.live_environment.ssao_enabled=post[0] and spec.mode!="no_post"
			game.live_environment.ssil_enabled=post[1] and spec.mode!="no_post"
			game.live_environment.ssr_enabled=post[2] and spec.mode!="no_post"
			for node in visibility:
				if not is_instance_valid(node):continue
				node.visible=visibility[node]
				var asset=str(node.get_meta("render_asset",""));var policy=game.runtime_render_policy
				if spec.mode=="no_groundcover" and (policy.is_detail(asset) and not policy.is_tree(asset) or str(node.name).begins_with("DetailFar_")):node.hide()
				if spec.mode=="no_trees" and (policy.is_tree(asset) or str(node.name).begins_with("SakuraFar_") or str(node.name).begins_with("SakuraShadow_") or str(node.name).begins_with("TreeReflection_")):node.hide()
		window.grab_focus()
		game.player.camera.global_position=spec.eye;game.player.camera.look_at(spec.target)
		game.player.camera.fov=66
		var until=Time.get_ticks_msec()+int(warm_seconds*1000)
		while Time.get_ticks_msec()<until:await process_frame
		var frames=[];var draws=[];var primitives=[];var cpu_process=[];var cpu_physics=[];var render_gpu=[];var render_cpu=[];var focused=0;var previous=Time.get_ticks_usec()
		var draw_start=Engine.get_frames_drawn()
		until=Time.get_ticks_msec()+int(sample_seconds*1000)
		while Time.get_ticks_msec()<until:
			await process_frame
			if not window.has_focus():window.grab_focus()
			var now=Time.get_ticks_usec();frames.append(float(now-previous)/1000.0);previous=now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			cpu_process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
			cpu_physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
			render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
			if window.has_focus():focused+=1
		var total=0.0
		for value in frames:total+=value
		var row={"id":spec.id,"fps":1000.0/(total/frames.size()),"p95_ms":percentile(frames,.95),
			"rendered_fps":float(Engine.get_frames_drawn()-draw_start)*1000.0/total,"render_fraction":float(Engine.get_frames_drawn()-draw_start)/frames.size(),
			"p99_ms":percentile(frames,.99),"samples":frames.size(),"focus_fraction":float(focused)/frames.size(),
			"draw_calls":percentile(draws,.5),"primitives":percentile(primitives,.5),"frame_ms":frames,
			"cpu_process_p95_ms":percentile(cpu_process,.95),"cpu_physics_p95_ms":percentile(cpu_physics,.95),
			"render_gpu_p95_ms":percentile(render_gpu,.95),"render_cpu_p95_ms":percentile(render_cpu,.95),
			"eye":[spec.eye.x,spec.eye.y,spec.eye.z],"target":[spec.target.x,spec.target.y,spec.target.z],
			"memory_static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"resolution":str(root.size)}
		report.views.append(row)
		print("RUNTIME_PROFILE ",spec.id," fps=",snappedf(row.fps,.1)," rendered_fps=",snappedf(row.rendered_fps,.1)," render_fraction=",row.render_fraction," p95=",snappedf(row.p95_ms,.1)," primitives=",row.primitives," focus=",row.focus_fraction)
		if not "--no-captures" in OS.get_cmdline_user_args():
			root.get_texture().get_image().save_png(output+label+"_"+spec.id+".png")
		FileAccess.open(output+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	report.completed=true
	FileAccess.open(output+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RUNTIME_PROFILE_COMPLETE ",label);quit()
