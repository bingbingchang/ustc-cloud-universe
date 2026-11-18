extends SceneTree
## Offline static-world bake. Region packs contain the existing world geometry
## and collisions, never a second hand-maintained map or hidden full-map scene.
const DIRECTORY="res://web/regions/"
const CELL=128.0
const CHUNK_NODES=96
var regions={}
var counts={}
var source_game
var mesh_copies={}
var dependencies={}

func record_dependencies(path:String):
	for dependency in ResourceLoader.get_dependencies(path):
		var target=str(dependency).split("::")[-1]
		if target.begins_with("res://") and not target.begins_with("res://web/shared/"):dependencies[target]=true

func local_mesh(mesh:Mesh)->Mesh:
	if not mesh_copies.has(mesh.get_instance_id()):
		var copy=mesh.duplicate()
		var path="res://web/shared/vegetation_%04d.res"%mesh_copies.size()
		if ResourceSaver.save(copy,path,ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_CHANGE_PATH)!=OK:push_error("Cannot save shared vegetation");quit(1)
		copy.take_over_path(path)
		record_dependencies(path)
		mesh_copies[mesh.get_instance_id()]=copy
	return mesh_copies[mesh.get_instance_id()]

func bounds_of(node:Node3D)->AABB:
	if node.get_meta("paired_vegetation_lod", false):
		var geometry := node as GeometryInstance3D
		# All surfaces and the impostor must ship in the same streamed region.
		return geometry.global_transform * geometry.custom_aabb
	if node is MultiMeshInstance3D:
		var result=AABB();var first=true
		for i in node.multimesh.instance_count:
			var box:AABB=node.global_transform*node.multimesh.get_instance_transform(i)*node.multimesh.mesh.get_aabb()
			result=box if first else result.merge(box);first=false
		return result
	if node is GeometryInstance3D:return node.global_transform*node.get_aabb()
	var result=AABB(node.global_position,Vector3.ZERO);var first=true
	for child in node.get_children():
		if not child is CollisionShape3D:continue
		var shape=child.shape;var box=AABB()
		if shape is BoxShape3D:box=AABB(-shape.size*.5,shape.size)
		elif shape is ConcavePolygonShape3D or shape is ConvexPolygonShape3D:
			var points=shape.get_faces() if shape is ConcavePolygonShape3D else shape.points
			if not points.is_empty():
				box=AABB(points[0],Vector3.ZERO)
				for point in points:box=box.expand(point)
		else:box=AABB(Vector3(-1,-1,-1),Vector3(2,2,2))
		result=child.global_transform*box if first else result.merge(child.global_transform*box);first=false
	return result

func _initialize():call_deferred("run")

func owned(node:Node,owner_node:Node):
	for child in node.get_children():child.owner=owner_node;owned(child,owner_node)

func cell_id(point:Vector3)->String:
	return "%d_%d"%[floori(point.x/CELL),floori(point.z/CELL)]

func region_root(id:String)->Node3D:
	if not regions.has(id):
		var node=Node3D.new();node.name="Region_"+id.replace("-","m");regions[id]=node;counts[id]=0;root.add_child(node)
	return regions[id]

func collect(node:Node):
	if node.get_script()!=null:return # Animated actors are instantiated by the zone manager.
	if node is OccluderInstance3D:return # Official Web template omits CPU occlusion.
	if node is GeometryInstance3D or node is StaticBody3D:
		if node is GeometryInstance3D and not node.is_visible_in_tree():return
		var bounds=bounds_of(node)
		var id=cell_id(bounds.get_center())
		if bounds.size.x>CELL*2 or bounds.size.z>CELL*2:id="global"
		var copy=node.duplicate(0);copy.transform=node.global_transform
		copy.name="Item_"+str(counts.get(id,0))
		if copy.has_meta("render_placements"):copy.remove_meta("render_placements")
		if copy is MultiMeshInstance3D:
			# Newly generated MultiMeshes already have no external path. Sharing
			# them within this frozen, disposable bake avoids the dummy renderer's
			# unsupported GPU buffer round-trip in MultiMesh.duplicate().
			copy.multimesh.mesh=local_mesh(copy.multimesh.mesh)
		if copy is MeshInstance3D:
			var mesh=copy.mesh.duplicate()
			if mesh is ArrayMesh:
				for surface in mesh.get_surface_count():mesh.surface_set_material(surface,node.get_active_material(surface))
			copy.mesh=mesh
		if copy is Label3D:copy.font=load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
		if copy is MeshInstance3D and (copy.get_meta("lake_water",false) or str(node.name).begins_with("NorthWater")):
			copy.material_override=source_game.mats.water;copy.set_meta("lake_water",true)
		region_root(id).add_child(copy);counts[id]+=1
		return
	for child in node.get_children():collect(child)

func run():
	if DisplayServer.get_name()=="headless":push_error("World bake needs real RenderingServer MultiMesh buffers");quit(2);return
	root.disable_3d=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://web/shared/"))
	# Only remove this baker's numbered outputs; stale shared meshes otherwise
	# remain selected for export after a batching change and inflate the core.
	for file in DirAccess.get_files_at("res://web/shared/"):
		if file.begins_with("vegetation_") and file.ends_with(".res") and file.trim_prefix("vegetation_").trim_suffix(".res").is_valid_int():
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://web/shared/"+file))
	source_game=load("res://scenes/campus_game.tscn").instantiate();root.add_child(source_game)
	await process_frame
	source_game.process_mode=Node.PROCESS_MODE_DISABLED
	for child in source_game.world.get_children():collect(child)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://web/npc_animations/"))
	for id in source_game.hero_interactions.actors:
		var library=source_game.hero_interactions.actors[id].animator.get_animation_library("")
		if ResourceSaver.save(library,"res://web/npc_animations/"+id+".res",ResourceSaver.FLAG_COMPRESS)!=OK:quit(1);return
	var shared={}
	for mesh in mesh_copies.values():
		var path=mesh.resource_path
		shared[path]={"scene":path,"bytes":FileAccess.get_file_as_bytes(path).size(),"sha256":FileAccess.get_sha256(path)}
	var manifest={"version":2,"cell_size":CELL,"core":[],"regions":{},"shared":shared,
		"terrain_enabled":false,"terrain_sha256":""}
	for id in regions:
		var node=regions[id]
		var path=DIRECTORY+id+".bin"
		var container=FileAccess.open(path,FileAccess.WRITE)
		var chunks=[];var dependencies=[]
		while node.get_child_count()>0:
			var chunk=Node3D.new();chunk.name="RegionChunk"
			for index in mini(CHUNK_NODES,node.get_child_count()):
				var child=node.get_child(0);node.remove_child(child);chunk.add_child(child)
				if child is MultiMeshInstance3D and child.multimesh.mesh.resource_path in shared:
					var dependency=child.multimesh.mesh.resource_path
					if not dependency in dependencies:dependencies.append(dependency)
			owned(chunk,chunk)
			var scene=PackedScene.new()
			if scene.pack(chunk)!=OK:push_error("Cannot pack region "+id);quit(1);return
			var scratch=DIRECTORY+"chunk_temp.scn"
			if ResourceSaver.save(scene,scratch,ResourceSaver.FLAG_COMPRESS)!=OK:quit(1);return
			record_dependencies(scratch)
			var bytes=FileAccess.get_file_as_bytes(scratch)
			chunks.append({"offset":container.get_position(),"bytes":bytes.size(),"nodes":chunk.get_child_count()})
			container.store_buffer(bytes);chunk.free()
		container.close()
		DirAccess.remove_absolute(DIRECTORY+"chunk_temp.scn")
		var bounds=[];var core=id=="global"
		if id!="global":
			var parts=id.split("_");var x=int(parts[0]);var z=int(parts[1])
			bounds=[x*CELL,z*CELL,(x+1)*CELL,(z+1)*CELL];core=x in [-1,0] and z in [-1,0,1]
		manifest.regions[id]={"scene":path,"bounds":bounds,"nodes":counts[id],"chunks":chunks,"shared":dependencies,"sha256":FileAccess.get_sha256(path),"bytes":FileAccess.get_file_as_bytes(path).size()}
		if core:manifest.core.append(id)
		print("WEB_REGION_BAKED ",id," nodes=",counts[id]," bytes=",manifest.regions[id].bytes)
	var hashes=""
	for id in regions:hashes+=manifest.regions[id].sha256
	manifest.release="r"+hashes.sha256_text().left(16)
	manifest.dependencies=dependencies.keys()
	FileAccess.open("res://web/regions.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"  "))
	print("WEB_REGIONS_COMPLETE regions=",regions.size());quit()
