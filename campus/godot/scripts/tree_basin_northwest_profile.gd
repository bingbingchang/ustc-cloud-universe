extends "res://scripts/north_axis_profile.gd"
func _views(c:Node)->Array:
	var views=[]
	for s in [["tree_pits",Vector3(3.7,.15,126),Vector3(7.15,.45,123),58.0],["tree_row",Vector3(0,1.15,148),Vector3(7.15,.4,133),60.0],["northwest_bank",Vector3(-67,.15,99),Vector3(-44,1.4,86),58.0],["northwest_overview",Vector3(-82,33.35,114),Vector3(-44,0,85),55.0]]:
		var index=c.photo_spots.size();c.photo_spots.append({"name":s[0],"pos":s[1],"target":s[2],"fov":s[3],"ortho":false,"size":120.0,"reason":"Composition study comparison"})
		views.append({"id":s[0],"index":index,"description":s[0]})
	return views
func _save(report:Dictionary)->Error:
	var stage="static"
	if "--perf-motion" in OS.get_cmdline_user_args():stage="moving"
	if "--northwest-before" in OS.get_cmdline_user_args():stage+="_before_expansion"
	report["profile"]="Lake composition study "+stage
	report["notes"]=["1600x900, 4x MSAA, TAA, VSync off, 14 actors and animations live.","90 warmup and 180 measured frames per view; short sequential samples, not sustained gameplay or isolated GPU timing."]
	var f=FileAccess.open("res://../renders/tree_basin_northwest/"+stage+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));return OK
