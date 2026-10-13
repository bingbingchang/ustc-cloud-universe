extends RefCounted
## Ordinary game-viewport timing, separate from native 4K image export.
## Call await PopulationProfile.new().run(campus) after the scene is initialized.
const OUTPUT="res://../renders/population/performance.json"
const TARGET_SIZE=Vector2i(1600,900)
const WARM_FRAMES=60
const MEASURE_FRAMES=120

func _percentile(values:Array,q:float)->float:
	if values.is_empty():return 0.0
	var sorted=values.duplicate();sorted.sort()
	var index=(sorted.size()-1)*clampf(q,0.0,1.0)
	var lower=int(floor(index));var upper=int(ceil(index))
	return lerpf(float(sorted[lower]),float(sorted[upper]),index-lower)

func _summary(values:Array)->Dictionary:
	if values.is_empty():return {}
	var total=0.0
	for value in values:total+=float(value)
	return {"median":_percentile(values,.5),"p95":_percentile(values,.95),"mean":total/values.size(),"min":values.min(),"max":values.max()}

func _save(report:Dictionary)->Error:
	var directory=ProjectSettings.globalize_path(OUTPUT.get_base_dir())
	var error=DirAccess.make_dir_recursive_absolute(directory)
	if error!=OK:return error
	var file=FileAccess.open(OUTPUT,FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(report,"\t"));file.close()
	return OK

func run(campus:Node):
	var report={
		"schema_version":1,
		"source":"Time.get_ticks_usec deltas between actual SceneTree.process_frame signals",
		"profile":"Ordinary 1600x900 game viewport; no image readback or image encoding",
		"engine":Engine.get_version_info().string,
		"renderer":RenderingServer.get_current_rendering_method(),
		"gpu":RenderingServer.get_video_adapter_name(),
		"display_server":DisplayServer.get_name(),
		"requested_resolution":[TARGET_SIZE.x,TARGET_SIZE.y],
		"warm_frames_per_view":WARM_FRAMES,
		"measured_frames_per_view":MEASURE_FRAMES,
		"percentile_method":"Linear interpolation at (sample_count - 1) * quantile",
		"notes":[
			"Frame time is wall-clock delivery latency, including CPU, GPU synchronization and any vsync/frame-cap wait; it is not isolated GPU execution time.",
			"Draw calls and triangles use Godot's total rendered-frame monitors. The triangles field is submitted rendering primitives, including repeated shadow/depth passes; it is not unique asset triangle count.",
			"Quality settings, vsync and frame cap are recorded without changing them. Player input is frozen, while actors, foliage, clouds and scene lighting continue normally."
		],
		"views":[],
		"completed":false
	}
	var arguments=OS.get_cmdline_user_args()
	var incompatible=[]
	for argument in ["--capture","--verify","--ultra","--motion","--population-capture","--population-motion"]:
		if argument in arguments:incompatible.append(argument)
	if DisplayServer.get_name()=="headless" or not incompatible.is_empty() or is_instance_valid(campus.photo_view):
		report["error"]="Run --population-profile in a rendered normal window without capture, motion, verify, headless or ultra mode."
		report["incompatible_arguments"]=incompatible
		_save(report);push_error(report.error);campus.get_tree().quit(1);return

	var viewport=campus.get_viewport()
	var window=campus.get_window()
	window.mode=Window.MODE_WINDOWED
	window.size=TARGET_SIZE
	window.content_scale_size=TARGET_SIZE
	viewport.disable_3d=false
	campus.player.enabled=false;campus.player.frozen=true;campus.player.free_camera=true
	campus.player.camera.current=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	# Keep the ordinary HUD cost. No photographic SubViewport is created here.
	campus.hud.visible=true
	campus.life_layer.manual_time=-1.0
	report["quality"]={
		"msaa_3d":viewport.msaa_3d,
		"taa":viewport.use_taa,
		"scaling_3d_scale":viewport.scaling_3d_scale,
		"engine_max_fps":Engine.max_fps,
		"vsync_mode":DisplayServer.window_get_vsync_mode(window.get_window_id()),
		"hud_visible":campus.hud.visible,
		"live_animations":true
	}
	var texture_sizes_match=true
	for spec in [[0,"overview",8.0],[5,"hero_study",3.0],[10,"cyclist",27.0]]:
		# Seed story time to keep the named subject inside its ordinary camera.
		# Playback is live throughout warmup and measurement; no pose is frozen.
		campus.life_layer.time=spec[2];campus.life_layer.cyclist_time=spec[2]
		campus.life_layer.pose(spec[2]);campus.viewpoint(spec[0])
		for frame in range(WARM_FRAMES):await campus.get_tree().process_frame
		var resolution=Vector2i(viewport.get_texture().get_size())
		texture_sizes_match=texture_sizes_match and resolution==TARGET_SIZE
		var frame_ms=[];var calls=[];var primitives=[]
		var start_time=campus.life_layer.time
		var previous=Time.get_ticks_usec()
		for frame in range(MEASURE_FRAMES):
			await campus.get_tree().process_frame
			var now=Time.get_ticks_usec()
			frame_ms.append(float(now-previous)/1000.0);previous=now
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var frame_summary=_summary(frame_ms)
		var result={
			"id":spec[1],"view_index":spec[0],"view_number":spec[0]+1,
			"name":campus.photo_spots[spec[0]].name,
			"resolution":[resolution.x,resolution.y],
			"renderer":report.renderer,
			"median_frame_ms":frame_summary.median,
			"p95_frame_ms":frame_summary.p95,
			"frame_ms":frame_summary,
			"draw_calls":_summary(calls),
			"triangles":_summary(primitives),
			"samples":MEASURE_FRAMES,
			"scene_time_start":start_time,
			"scene_time_end":campus.life_layer.time,
			"camera_position":str(campus.player.camera.global_position),
			"camera_transform":str(campus.player.camera.global_transform),
			"projection":campus.player.camera.projection,
			"fov":campus.player.camera.fov,
			"directional_shadow_distance":campus.sun.directional_shadow_max_distance,
			"raw_frame_ms":frame_ms,
			"raw_draw_calls":calls,
			"raw_render_primitives":primitives
		}
		report.views.append(result)
		print("POPULATION_PROFILE_VIEW ",spec[1]," median_ms=",result.median_frame_ms," p95_ms=",result.p95_frame_ms," resolution=",resolution)
	report["resolution"]=[TARGET_SIZE.x,TARGET_SIZE.y] if texture_sizes_match else null
	report["resolution_verified"]=texture_sizes_match
	report["completed"]=true
	var error=_save(report)
	if error!=OK:push_error("Could not save population/performance.json: "+str(error))
	if not texture_sizes_match:push_error("Actual viewport resolution differs from requested 1600x900; see per-view measurements.")
	print("POPULATION_PROFILE_COMPLETE ",OUTPUT)
	campus.get_tree().quit(0 if error==OK and texture_sizes_match else 1)
