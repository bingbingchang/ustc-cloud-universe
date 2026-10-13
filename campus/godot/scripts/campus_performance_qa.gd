extends "res://scripts/lookdev_live_qa.gd"
func save_live(name:String,value):
	var dir="res://../renders/performance_upgrade/qa/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f=FileAccess.open(dir+name,FileAccess.WRITE);f.store_string(JSON.stringify(value,"\t"))
