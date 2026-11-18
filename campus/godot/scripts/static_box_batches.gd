extends Node
## Same boxes, materials, world transforms and collisions; fewer submissions.
var game
func _ready():
	var groups={};var count=0
	for node in game.world.get_children():
		if not node is MeshInstance3D or not node.mesh is BoxMesh or node.get_script()!=null or not node.visible:continue
		if node.visibility_range_begin!=0 or node.visibility_range_end!=0 or "Door" in node.name:continue
		if node.mesh.size.length()>64 or node.mesh.subdivide_width!=0 or node.mesh.subdivide_height!=0 or node.mesh.subdivide_depth!=0:continue
		var material=node.get_active_material(0)
		if not material:continue
		if material is ShaderMaterial:
			var foliage=material.get_shader_parameter("foliage")
			if foliage!=null and float(foliage)>0:continue
			if "ALPHA" in material.shader.code or "TIME" in material.shader.code and material.shader.resource_path!="res://shaders/academic.gdshader":continue
		elif material is BaseMaterial3D and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
		var p=node.global_position;var cell=Vector3i(floori(p.x/24),floori(p.y/24),floori(p.z/24))
		var key=str(material.get_instance_id())+"/"+str(node.layers)+"/"+str(node.cast_shadow)+"/"+str(cell)
		if not groups.has(key):groups[key]={"material":material,"nodes":[]}
		groups[key].nodes.append(node)
	for group in groups.values():
		if group.nodes.size()<2:continue
		var first=group.nodes[0]
		var mesh=BoxMesh.new();mesh.size=Vector3.ONE;mesh.material=group.material
		var batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=mesh;batch.instance_count=group.nodes.size()
		for index in group.nodes.size():
			var source=group.nodes[index]
			batch.set_instance_transform(index,source.global_transform*Transform3D(Basis.from_scale(source.mesh.size),Vector3.ZERO))
		var node=MultiMeshInstance3D.new();node.name="StaticArchitectureBatch";node.multimesh=batch
		node.layers=first.layers;node.cast_shadow=first.cast_shadow;game.world.add_child(node)
		for source in group.nodes:source.hide();source.queue_free()
		count+=group.nodes.size()-1
	print("STATIC_BOX_BATCHES eliminated_submissions=",count)
