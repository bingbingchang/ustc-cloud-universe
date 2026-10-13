extends SceneTree
## Offline only: original GLB and collision meshes remain untouched.
var rows=[]
func _initialize():call_deferred("run")
func parts(n:Node,out:Array):
	if n is MeshInstance3D:out.append(n.mesh)
	for child in n.get_children():parts(child,out)
func run():
	var dir="res://assets/render_lods/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var selected=PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--assets="):selected=arg.trim_prefix("--assets=").split(",")
	if not selected.is_empty():
		for row in JSON.parse_string(FileAccess.get_file_as_string(dir+"manifest.json")):
			if row.asset not in selected:rows.append(row)
	for file in DirAccess.get_files_at("res://assets"):
		if not file.ends_with(".glb"):continue
		var asset=file.trim_suffix(".glb")
		if not selected.is_empty() and asset not in selected:continue
		if not (asset.begins_with("tree") or asset.begins_with("sakura_tree") or asset.begins_with("study_") or asset.begins_with("lake_")):continue
		var node=load("res://assets/"+file).instantiate();var meshes=[];parts(node,meshes)
		for part in meshes.size():
			var mesh=meshes[part]
			for s in mesh.get_surface_count():
				var im=ImporterMesh.new();im.add_surface(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(s))
				im.generate_lods(60,0,[])
				var path=dir+asset+"_"+str(part)+"_"+str(s)+".res"
				var error=ResourceSaver.save(im.get_mesh(),path,ResourceSaver.FLAG_COMPRESS)
				if error!=OK:push_error("Cannot save "+path);quit(1);return
				rows.append({"asset":asset,"part":part,"surface":s,"lod_levels":im.get_surface_lod_count(0),"source_sha256":FileAccess.get_sha256("res://assets/"+file)})
		node.free();print("LOD_BUILT ",asset)
	var f=FileAccess.open(dir+"manifest.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"\t"));print("LOD_SURFACES ",rows.size());quit()
