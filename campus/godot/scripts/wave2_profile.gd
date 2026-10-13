extends RefCounted
## Normal rendered-window measurements. No offline capture or texture readback.
const OUTPUT="res://../renders/wave2/performance.json"
const TARGET_SIZE=Vector2i(1600,900)
const WARM_FRAMES=90
const MEASURE_FRAMES=180

func _percentile(values:Array,q:float)->float:
	var ordered=values.duplicate();ordered.sort()
	var index=(ordered.size()-1)*clampf(q,0.0,1.0)
	return lerpf(float(ordered[int(floor(index))]),float(ordered[int(ceil(index))]),index-floor(index))

func _summary(values:Array)->Dictionary:
	var total=0.0
	for value in values:total+=float(value)
	return {"median":_percentile(values,.5),"p95":_percentile(values,.95),"mean":total/values.size(),"min":values.min(),"max":values.max()}

func _save(report:Dictionary)->Error:
	var error=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if error!=OK:return error
	var f=FileAccess.open(OUTPUT,FileAccess.WRITE)
	if f==null:return FileAccess.get_open_error()
	f.store_string(JSON.stringify(report,"\t"));f.close();return OK

func _views(campus:Node)->Array:
	var overall=-1
	for i in range(campus.photo_spots.size()):
		if "第二波总览" in String(campus.photo_spots[i].name):overall=i;break
	return [
		{"id":"original_core","index":0,"description":"Existing core Diorama orthographic viewpoint"},
		{"id":"new_overall","index":overall,"description":"Existing Wave 2 overall Diorama viewpoint"},
		{"id":"east_garden","index":-1,"name":"东侧教学花园 / 性能广角","pos":Vector3(158,61,119),"target":Vector3(104,1.5,180),"fov":50.0,"description":"Broad 3/4 perspective of the east garden, with the same overview shadow settings"}
	]

func _select_view(campus:Node,spec:Dictionary):
	if int(spec.index)>=0:
		campus.viewpoint(int(spec.index));return
	# Prime the same ordinary overview quality as the core, then move only its camera.
	campus.viewpoint(0)
	campus.player.set_view(spec.pos,spec.target)
	campus.player.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	campus.player.camera.fov=spec.fov
	campus.spot_label.text=spec.name+" · 普通窗口性能采样"

func run(campus:Node):
	var report={
		"schema_version":1,"completed":false,
		"timestamp_utc":Time.get_datetime_string_from_system(true),
		"profile":"Wave 2 ordinary live 1600x900 window; no offline image capture",
		"source":"Wall-clock Time.get_ticks_usec deltas between SceneTree.process_frame signals",
		"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),
		"gpu":RenderingServer.get_video_adapter_name(),"display_server":DisplayServer.get_name(),
		"requested_resolution":[TARGET_SIZE.x,TARGET_SIZE.y],
		"warm_frames_per_view":WARM_FRAMES,"measured_frames_per_view":MEASURE_FRAMES,
		"percentile_method":"Linear interpolation at (sample_count - 1) * quantile",
		"notes":[
			"Effective FPS is 1000 divided by mean real delivered-frame milliseconds. It is not offline screenshot generation FPS.",
			"Frame time includes CPU work, GPU synchronization, vsync/frame-cap waits and OS scheduling. It is not isolated GPU execution time.",
			"Draw calls and primitives are Godot total per-frame rendering monitors. Primitives include shadow/depth repeats and are not unique model triangles.",
			"Graphics quality, vsync and frame cap are preserved. Ordinary HUD, actors, foliage, sky and light animation stay live; player input is frozen for repeatable cameras.",
			"Each camera is sampled sequentially with all Wave 2 actors loaded. This is a current-build camera comparison, not a before/after regression benchmark.",
			"Window focus and actual viewport resolution are recorded. Desktop GPU contention, background throttling and shader/driver cache state can affect results."
		],"views":[]
	}
	var incompatible=[];var arguments=OS.get_cmdline_user_args()
	report["user_arguments"]=arguments
	for argument in ["--capture","--verify","--ultra","--motion","--population-capture","--population-motion","--population-profile","--population-qa","--wave2-capture","--wave2-motion","--wave2-qa"]:
		if argument in arguments:incompatible.append(argument)
	if DisplayServer.get_name()=="headless" or not incompatible.is_empty() or is_instance_valid(campus.photo_view):
		report["error"]="Run --wave2-profile alone in an ordinary rendered window, without capture, ultra, verify, QA or headless modes."
		report["incompatible_arguments"]=incompatible;_save(report);push_error(report.error);campus.get_tree().quit(1);return
	var specs=_views(campus)
	if int(specs[1].index)<0 or not is_instance_valid(campus.wave2_layer):
		report["error"]="Wave 2 world/overall viewpoint is missing; cannot profile the requested cameras."
		_save(report);push_error(report.error);campus.get_tree().quit(1);return
	if not "--lookdev" in arguments:
		report["error"]="Pass --lookdev to match run_diorama.ps1 ordinary-demo initialization."
		_save(report);push_error(report.error);campus.get_tree().quit(1);return
	var viewport=campus.get_viewport();var window=campus.get_window()
	window.mode=Window.MODE_WINDOWED;window.size=TARGET_SIZE;window.content_scale_size=TARGET_SIZE
	viewport.disable_3d=false
	campus.player.enabled=false;campus.player.frozen=true;campus.player.free_camera=true;campus.player.camera.current=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;campus.hud.visible=true
	campus.life_layer.manual_time=-1.0;campus.wave2_layer.manual_time=-1.0
	report["quality"]={"msaa_3d":viewport.msaa_3d,"taa":viewport.use_taa,"scaling_3d_scale":viewport.scaling_3d_scale,"engine_max_fps":Engine.max_fps,"vsync_mode":DisplayServer.window_get_vsync_mode(window.get_window_id()),"hud_visible":campus.hud.visible,"live_animations":true}
	report["live_actor_count"]={"core":campus.life_layer.actors.size(),"wave2":campus.wave2_layer.actors.size()}
	var resolution_ok=true
	for spec in specs:
		# All actors remain live after this reproducible starting phase.
		campus.life_layer.time=8;campus.life_layer.cyclist_time=8;campus.life_layer.pose(8)
		campus.wave2_layer.time=8;campus.wave2_layer.pose(8)
		_select_view(campus,spec)
		for frame in range(WARM_FRAMES):await campus.get_tree().process_frame
		var size=Vector2i(viewport.get_texture().get_size());resolution_ok=resolution_ok and size==TARGET_SIZE
		var frames=[];var draws=[];var primitives=[];var cpu_process=[];var cpu_physics=[];var focused=0
		var start_time=campus.wave2_layer.time;var previous=Time.get_ticks_usec()
		for frame in range(MEASURE_FRAMES):
			await campus.get_tree().process_frame
			var now=Time.get_ticks_usec();frames.append(float(now-previous)/1000.0);previous=now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			cpu_process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
			cpu_physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
			if window.has_focus():focused+=1
		var summary=_summary(frames);var camera=campus.player.camera
		var result={
			"id":spec.id,"name":campus.photo_spots[int(spec.index)].name if int(spec.index)>=0 else spec.name,
			"view_index":spec.index,"description":spec.description,"resolution":[size.x,size.y],
			"effective_fps":1000.0/summary.mean,"median_frame_ms":summary.median,"p95_frame_ms":summary.p95,"frame_ms":summary,
			"draw_calls":_summary(draws),"submitted_primitives":_summary(primitives),"process_monitor_ms":_summary(cpu_process),"physics_monitor_ms":_summary(cpu_physics),
			"samples":MEASURE_FRAMES,"focused_frames":focused,"focus_fraction":float(focused)/MEASURE_FRAMES,
			"scene_time_start":start_time,"scene_time_end":campus.wave2_layer.time,
			"camera_position":str(camera.global_position),"camera_transform":str(camera.global_transform),"projection":camera.projection,"fov":camera.fov,"orthographic_size":camera.size,
			"directional_shadow_distance":campus.sun.directional_shadow_max_distance,
			"raw_frame_ms":frames,"raw_draw_calls":draws,"raw_render_primitives":primitives
		}
		report.views.append(result)
		print("WAVE2_PROFILE_VIEW ",spec.id," fps=",result.effective_fps," median_ms=",result.median_frame_ms," p95_ms=",result.p95_frame_ms," draws=",result.draw_calls.median," focus=",result.focus_fraction)
	report["resolution_verified"]=resolution_ok;report["completed"]=true
	var error=_save(report)
	if error!=OK:push_error("Failed to save Wave 2 performance report: "+str(error))
	if not resolution_ok:push_error("Actual viewport dimensions did not match 1600x900.")
	print("WAVE2_PROFILE_COMPLETE ",OUTPUT)
	campus.get_tree().quit(0 if error==OK and resolution_ok else 1)
