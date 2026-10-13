extends "res://scripts/wave2_profile.gd"
## Reuses delivered-frame sampling and summaries; independent ordinary-window run.
const NORTH_OUTPUT="res://../renders/north_axis/performance.json"
var previous_vsync=0
var previous_max_fps=0

func _views(_campus:Node)->Array:
	return [
		{"id":"whole_campus","index":19,"description":"Current complete Diorama, old north gate / twin ponds / first teaching building"},
		{"id":"north_axis","index":21,"description":"Human-scale north-to-south view down Yuquan North Road"},
		{"id":"lake_pavilion","index":22,"description":"Yijian Pavilion, lake and neighbouring expert building"},
		{"id":"creature_close","index":17,"description":"Current moving leaf-cat close-up; all five wanderers and existing population remain active"}
	]

func _select_view(campus:Node,spec:Dictionary):
	if int(spec.index) in [13,14,15,16,17]:
		var current=campus.wave2_layer.spots()
		for i in range(current.size()):campus.photo_spots[13+i]=current[i]
	super._select_view(campus,spec)

func _save(report:Dictionary)->Error:
	report["profile"]="North axis: ordinary 1600x900 live Diorama, vsync off, four short fixed-camera samples"
	report["entry_scene"]=ProjectSettings.get_setting("application/run/main_scene")
	report["vsync_before_run"]=previous_vsync;report["engine_max_fps_before_run"]=previous_max_fps
	report["scope"]="Short warm camera samples, not a sustained stress test, not isolated GPU timing, not offline 4K export FPS."
	var notes=[]
	for note in report.get("notes",[]):
		if "Graphics quality, vsync and frame cap are preserved" in str(note):
			notes.append("Ordinary project graphics quality is preserved. Vsync is explicitly disabled and Engine.max_fps is zero. HUD, all actors, foliage, sky and lights remain live; only player movement is frozen.")
		else:notes.append(note)
	report["notes"]=notes
	report["vsync_disabled_verified"]=int(report.get("quality",{}).get("vsync_mode",-1))==DisplayServer.VSYNC_DISABLED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NORTH_OUTPUT.get_base_dir()))
	var f=FileAccess.open(NORTH_OUTPUT,FileAccess.WRITE)
	if f==null:return FileAccess.get_open_error()
	f.store_string(JSON.stringify(report,"\t"));f.close();print("NORTH_AXIS_PROFILE_REPORT ",NORTH_OUTPUT)
	return OK

func run(campus:Node):
	var window=campus.get_window()
	previous_vsync=DisplayServer.window_get_vsync_mode(window.get_window_id());previous_max_fps=Engine.max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED,window.get_window_id());Engine.max_fps=0
	window.title="USTC / North Axis · 1600×900 ordinary-play performance sampling"
	await super.run(campus)
