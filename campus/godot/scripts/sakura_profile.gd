extends "res://scripts/north_axis_profile.gd"
func _views(_c:Node)->Array:
	return [{"id":"avenue","index":0,"description":"Human-height Sakura Avenue"},{"id":"hall","index":3,"description":"Hall approach"},{"id":"pavilion","index":1,"description":"Lake garden"},{"id":"overview","index":19,"description":"Full campus with all actors live"}]
func _save(report:Dictionary)->Error:
	var stage="before" if "--sakura-before" in OS.get_cmdline_user_args() else "after"
	var path="res://../renders/sakura_avenue/performance_"+stage+".json"
	report["scope"]="1600x900 normal rendered window; 4x MSAA/TAA; live actors, foliage and particles; VSync off. Short warmed samples, not sustained gameplay or isolated GPU timing."
	report["profile"]="Sakura Avenue " + stage + ": whole-scene before/after, same four cameras"
	report["notes"]=["Mean delivered frame time includes CPU, GPU synchronization and OS scheduling; it is not isolated GPU timing.","Before disables the Sakura planting and painterly materials; after enables both. All existing actors remain live.","180 measured frames per view after 90 warmup frames. Short samples do not establish sustained play performance."]
	var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));return OK
