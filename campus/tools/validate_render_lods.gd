extends SceneTree
func _initialize():call_deferred("run")
func parts(n:Node,out:Array):
	if n is MeshInstance3D:out.append(n.mesh)
	for child in n.get_children():parts(child,out)
func run():
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/render_lods/manifest.json"));var cache={};var errors=[];var levels=0
	for row in manifest:
		if not cache.has(row.asset):
			var node=load("res://assets/"+row.asset+".glb").instantiate();var meshes=[];parts(node,meshes);cache[row.asset]=meshes;node.free()
		var src=cache[row.asset][int(row.part)].surface_get_arrays(int(row.surface))
		var path="res://assets/render_lods/"+row.asset+"_"+str(int(row.part))+"_"+str(int(row.surface))+".res"
		var dst=load(path).surface_get_arrays(0)
		if src[Mesh.ARRAY_VERTEX]!=dst[Mesh.ARRAY_VERTEX] or src[Mesh.ARRAY_INDEX]!=dst[Mesh.ARRAY_INDEX]:errors.append(path)
		if row.source_sha256!=FileAccess.get_sha256("res://assets/"+row.asset+".glb"):errors.append("stale:"+row.asset)
		levels+=int(row.lod_levels)
	var report={"surfaces":manifest.size(),"additional_lod_levels":levels,"source_and_highest_detail_mismatches":errors,"passed":errors.is_empty() and levels>0}
	var f=FileAccess.open("res://../renders/performance_upgrade/lod_validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));print("LOD_VALIDATION ",JSON.stringify(report));quit(0 if report.passed else 1)
