extends SceneTree
func _initialize():call_deferred("run")
func run():
	if DisplayServer.get_name()=="headless":
		push_error("Tree basin proof needs a real renderer for MultiMesh transform readback; omit --headless.");quit(2);return
	var scene="diorama" if "--diorama" in OS.get_cmdline_user_args() else "campus_performance"
	var c=load("res://scenes/"+scene+".tscn").instantiate();root.add_child(c);await process_frame
	var rims=c.world.get_node("AlignedTreeBasinRims")
	var records=c.world.get_meta("sakura_bark_records")
	var failures=[];var tested=0;var root_vertices=0;var max_center_error=0.0
	for record in records:
		var at:Vector3=record.position
		if at.z<118 or at.z>150:continue
		tested+=1
		var lo=Vector3(INF,INF,INF);var hi=-lo;var pieces=0
		for i in rims.multimesh.instance_count:
			var tr=rims.global_transform*rims.multimesh.get_instance_transform(i)
			if Vector2(tr.origin.x-at.x,tr.origin.z-at.z).length()>2:continue
			var bounds=tr*rims.multimesh.mesh.get_aabb();lo=lo.min(bounds.position);hi=hi.max(bounds.end);pieces+=1
		var center=(lo+hi)*.5
		var error=Vector2(center.x-at.x,center.z-at.z).length();max_center_error=maxf(error,max_center_error)
		if pieces!=4 or error>.001:failures.append({"at":str(at),"rim_pieces":pieces,"center_error":error})
		for part in c.asset_cache[record.asset]:
			for s in part.mesh.get_surface_count():
				var mat=part.mesh.surface_get_material(s)
				if mat==null or not "Bark" in mat.resource_name:continue
				for v in part.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					var p:Vector3=record.placement*(part.transform*v)
					if p.y>=.38:continue
					root_vertices+=1
					if p.x<lo.x+.12 or p.x>hi.x-.12 or p.z<lo.z+.12 or p.z>hi.z-.12:failures.append({"escaped_root":str(p),"tree":str(at)})
	var report={"passed":tested==8 and failures.is_empty(),"scene":scene,"trees_tested":tested,"actual_root_vertices":root_vertices,"max_center_error_m":max_center_error,"failures":failures,"basins":c.world.get_meta("tree_basins")}
	var dir="res://../renders/tree_basin_northwest/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f=FileAccess.open(dir+"basin_validation_"+scene+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("BASIN_VALIDATION ",report.passed," trees=",tested," roots=",root_vertices," max_center_error=",max_center_error)
	c.queue_free();await process_frame;await process_frame;quit(0 if report.passed else 1)
