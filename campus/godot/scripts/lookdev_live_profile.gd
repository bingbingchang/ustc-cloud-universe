extends "res://scripts/north_axis_profile.gd"
## Independent ordinary-window LookDev measurement; never overwrites old profiles.
const LIVE_OUTPUT="res://../renders/lookdev_live/performance.json"
var actual_entry_scene=""
var actor_processing={}

func _views(_campus:Node)->Array:
	return [
		{"id":"teaching_hall_original","index":3,"description":"Original LookDev human-height red-brick teaching hall and fine-leaf trees"},
		{"id":"yuquan_north_road","index":0,"description":"Human-height view along Yuquan North Road toward the teaching hall"},
		{"id":"yijian_pavilion","index":1,"description":"Eye-level lake and Yijian Pavilion, latest shared north-axis architecture"},
		{"id":"shared_overview","index":19,"description":"High view of the complete shared world, with distant context and all 14 life elements"}
	]

func _select_view(campus:Node,spec:Dictionary):
	super._select_view(campus,spec)
	campus.get_window().title="USTC / LookDev Live · 1600×900 live performance sampling"

func _save(report:Dictionary)->Error:
	report["profile"]="LookDev Live: real 1600x900 rendered window, vsync off, 4x MSAA and TAA, four short fixed-camera samples"
	report["entry_scene"]=actual_entry_scene
	report["project_default_scene"]=ProjectSettings.get_setting("application/run/main_scene")
	report["vsync_before_run"]=previous_vsync
	report["engine_max_fps_before_run"]=previous_max_fps
	report["scope"]="Short warmed camera samples with the full current live world. Not sustained gameplay, isolated GPU execution timing, or offline screenshot/video export FPS."
	var notes=[]
	for note in report.get("notes",[]):
		if "Graphics quality, vsync and frame cap are preserved" in str(note):
			notes.append("Measured quality is explicitly 1600x900, 3D scale 1.0, 4x MSAA, TAA enabled, VSync disabled and Engine.max_fps=0. HUD, characters, foliage, sky and light animation remain active; only the player is frozen.")
		elif "Each camera is sampled sequentially" in str(note):
			notes.append("Each camera is sampled sequentially in the same current LookDev Live world, with 9 original and 5 second-wave life elements. This does not by itself establish a before/after performance regression.")
		else:notes.append(note)
	report["notes"]=notes
	report["actor_processing_at_start"]=actor_processing
	var total=0
	for count in report.get("live_actor_count",{}).values():total+=int(count)
	report["total_live_actor_count"]=total
	var quality:Dictionary=report.get("quality",{})
	var quality_ok=int(quality.get("vsync_mode",-1))==DisplayServer.VSYNC_DISABLED
	quality_ok=quality_ok and int(quality.get("msaa_3d",-1))==Viewport.MSAA_4X and bool(quality.get("taa",false))
	quality_ok=quality_ok and is_equal_approx(float(quality.get("scaling_3d_scale",0)),1.0) and int(quality.get("engine_max_fps",-1))==0
	var advancing=report.get("views",[]).size()==4
	for view in report.get("views",[]):advancing=advancing and float(view.scene_time_end)>float(view.scene_time_start)
	report["requested_conditions_verified"]=quality_ok and total==14 and advancing and bool(report.get("resolution_verified",false))
	report["quality_conditions_verified"]=quality_ok
	report["live_time_advanced_in_all_views"]=advancing
	if not report.requested_conditions_verified and not report.has("error"):
		report["error"]="One of resolution, AA/VSync/frame-cap, 14-actor count, or live clock advancement did not match the requested run."
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LIVE_OUTPUT.get_base_dir()))
	var f=FileAccess.open(LIVE_OUTPUT,FileAccess.WRITE)
	if f==null:return FileAccess.get_open_error()
	f.store_string(JSON.stringify(report,"\t"));f.close()
	print("LOOKDEV_LIVE_PROFILE_REPORT ",LIVE_OUTPUT)
	return OK if report.requested_conditions_verified else ERR_INVALID_DATA

func run(campus:Node):
	actual_entry_scene=campus.scene_file_path
	if actual_entry_scene!="res://scenes/lookdev_live.tscn":
		push_error("LookDev profile must instantiate res://scenes/lookdev_live.tscn explicitly.")
		campus.get_tree().quit(1);return
	for flag in ["--lookdev-live-qa","--lookdev-live-motion","--north-axis-qa","--north-axis-motion"]:
		if flag in OS.get_cmdline_user_args():
			push_error("LookDev performance run cannot share a QA/capture mode: "+flag)
			campus.get_tree().quit(1);return
	var viewport=campus.get_viewport()
	viewport.msaa_3d=Viewport.MSAA_4X;viewport.use_taa=true;viewport.scaling_3d_scale=1.0
	actor_processing={"core":campus.life_layer.is_processing(),"wave2":campus.wave2_layer.is_processing(),
		"core_manual_time":campus.life_layer.manual_time,"wave2_manual_time":campus.wave2_layer.manual_time}
	await super.run(campus)
