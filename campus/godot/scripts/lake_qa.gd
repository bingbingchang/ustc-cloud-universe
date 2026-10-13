extends "res://scripts/lookdev_live_qa.gd"
## Reuse native route/barrier/character tests; persist this revision separately.
func save_live(name:String,value):
	var variant="diorama" if "--lake-diorama" in OS.get_cmdline_user_args() else "live"
	var dir="res://../renders/yijian_garden/qa_"+variant+"/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f=FileAccess.open(dir+name,FileAccess.WRITE);f.store_string(JSON.stringify(value,"\t"))

func _alignment(c:Node3D)->Dictionary:
	if "lookdev_tree_contacts" in c:return await super._alignment(c)
	var records=c.world.get_meta("sakura_bark_records",[])+c.world.get_meta("lake_bark_records",[]);var temp=Node3D.new();c.add_child(temp)
	for record in records:
		for part in c.asset_cache[record.asset]:
			for s in part.mesh.get_surface_count():
				var mat=part.mesh.surface_get_material(s)
				if mat and "Bark" in mat.resource_name:
					var ar=ArrayMesh.new();ar.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.mesh.surface_get_arrays(s));_visual_body(temp,ar,record.placement*part.transform)
	await c.get_tree().physics_frame;await c.get_tree().physics_frame
	var samples=[];var failures=[]
	for record in records:
		for d in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
			var center=record.placement.origin+Vector3.UP*.65;var a=center+d*2
			var visual=_visual_ray(c,a,center,VISUAL_LAYER);var physical=_visual_ray(c,a,center,1)
			var error=999.0 if visual.is_empty() or physical.is_empty() else visual.position.distance_to(physical.position)
			var row={"at":str(center),"direction":str(d),"error_m":error};samples.append(row)
			if error>.18:failures.append(row)
	temp.queue_free();await c.get_tree().physics_frame
	return {"scope":"New Sakura and willow bark: actual source mesh versus physical contact, four sides per instance. Existing Diorama tree shapes are outside this new-asset check.","trees":records.size(),"samples":samples,"failures":failures,"passed":records.size()==c.world.get_meta("sakura_avenue").flower_trees+c.world.get_meta("yijian_garden").willows and samples.size()==records.size()*4 and failures.is_empty()}
