extends "res://scripts/north_axis_profile.gd"
func _views(c:Node)->Array:
	var views=[]
	for s in [["grove_path",Vector3(-29,.15,66),Vector3(-19,2,39),58.0],["photo",Vector3(-17,-.05,27),Vector3(-14,1,31),48.0],["reader",Vector3(-28,.05,46),Vector3(-25,1,49),48.0],["overview",Vector3(-63,34.35,84),Vector3(-25,0,46),55.0]]:
		var index=c.photo_spots.size();c.photo_spots.append({"name":s[0],"pos":s[1],"target":s[2],"fov":s[3],"ortho":false,"size":120.0,"reason":"Composition study comparison"})
		views.append({"id":s[0],"index":index,"description":s[0]})
	return views
func _save(report:Dictionary)->Error:
	var stage="static"
	if "--perf-motion" in OS.get_cmdline_user_args():stage="moving"
	if "--grove-before" in OS.get_cmdline_user_args():stage+="_before_expansion"
	report["live_actor_count"]["grove"]=0 if "--grove-before" in OS.get_cmdline_user_args() else 2
	report["profile"]="Lake composition study "+stage
	report["notes"]=["1600x900, 4x MSAA, TAA, VSync off, Original 14 actors plus 2 grove students unless --grove-before; animations live.","90 warmup and 180 measured frames per view; short sequential samples, not sustained gameplay or isolated GPU timing."]
	var f=FileAccess.open("res://../renders/west_grove/"+stage+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));return OK
