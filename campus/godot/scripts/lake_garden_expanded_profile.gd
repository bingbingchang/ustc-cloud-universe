extends "res://scripts/north_axis_profile.gd"
func _views(c:Node)->Array:
	var views=[]
	for s in [["composition",Vector3(24,.65,65),Vector3(43,3.1,81),48.0],["water_edge",Vector3(65.8,-.25,101),Vector3(42.5,3,80.8),58.0],["south_bank",Vector3(40,.15,134),Vector3(43,3,90),60.0],["overview",Vector3(109,62.35,137),Vector3(40,0,94),50.0]]:
		var index=c.photo_spots.size();c.photo_spots.append({"name":s[0],"pos":s[1],"target":s[2],"fov":s[3],"ortho":false,"size":120.0,"reason":"Composition study comparison"})
		views.append({"id":s[0],"index":index,"description":s[0]})
	return views
func _save(report:Dictionary)->Error:
	var stage="before" if "--garden-before" in OS.get_cmdline_user_args() else "after"
	report["profile"]="Lake composition study "+stage
	report["notes"]=["1600x900, 4x MSAA, TAA, VSync off, 14 actors and animations live.","90 warmup and 180 measured frames per view; short sequential samples, not sustained gameplay or isolated GPU timing."]
	var f=FileAccess.open("res://../renders/lake_garden_expanded/performance_"+stage+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));return OK
