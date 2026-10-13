extends SceneTree
## CPU-only imported-GLB contact audit and Blender proof pose export.
const OUT="res://../renders/wave2/"

func _initialize():call_deferred("run")

func vertices(n:Node,material_word:String)->PackedVector3Array:
	var result=PackedVector3Array()
	for child in n.find_children("*","MeshInstance3D",true,false):
		for s in child.mesh.get_surface_count():
			var mat=child.mesh.surface_get_material(s)
			if mat and not material_word in mat.resource_name:continue
			for v in child.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:result.append(child.to_global(v))
	return result

func write_json(path:String,value):
	var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(value,"\t"));f.close()

func dump(actor:Node3D,role:String,label:String):
	var result={}
	for key in actor.bones:
		var node=actor.bones[key];var tr=node.transform
		result[String(node.name)]={"origin":[tr.origin.x,tr.origin.y,tr.origin.z],"basis":[[tr.basis.x.x,tr.basis.x.y,tr.basis.x.z],[tr.basis.y.x,tr.basis.y.y,tr.basis.y.z],[tr.basis.z.x,tr.basis.z.y,tr.basis.z.z]]}
	write_json(OUT+role+"_"+label+"_pose.json",result)

func run():
	var report={"scope":"CPU-only imported production GLB, actual actor poses; vertex proximity is an upper bound on surface distance","roles":{}}
	for role in ["meituan","doubao","leaf_cat"]:
		var actor=load("res://assets/wave2_"+role+".glb").instantiate();root.add_child(actor)
		actor.set_script(load("res://scripts/mascot_actor.gd"));actor.role=role;actor.prepare()
		var item={"loop":actor.validate_loop(),"phase_samples":[],"screen_to_head_dot":[],"paw_leaf_vertex_distances":[],"nose_vertical_delta":[]}
		var times=[0.0,3.0,6.0,10.0,12.0,14.0,16.0,20.0,24.0,27.0]
		for t in times:
			actor.pose(t);item.phase_samples.append(actor.last_state())
			var nose=Vector3(0,-.032,-.174) if role=="meituan" else Vector3(0,.095,-.1) if role=="doubao" else Vector3(0,-.025,-.13)
			var neutral=actor.bones.Head.get_parent().global_transform*(actor.rest.Head*nose)
			item.nose_vertical_delta.append({"time":t,"delta_y_m":actor.bones.Head.to_global(nose).y-neutral.y})
			if role in ["meituan","doubao"]:
				var device=actor.bones.Phone if role=="meituan" else actor.bones.Tablet
				var head=actor.bones.Head.to_global(Vector3(0,.074,-.145) if role=="meituan" else Vector3(0,.145,-.083))
				var screen=device.to_global(Vector3(0,0,.012))
				item.screen_to_head_dot.append({"time":t,"dot":(device.global_basis*Vector3.BACK).normalized().dot((head-screen).normalized())})
			elif t>=10 and t<=16:
				var paw=vertices(actor.bones.FrontR,"Cream");var leaf=vertices(actor.bones.Leaf,"LeafGold")
				var distance=INF;var points=[];var lowest=INF;var leaf_lowest=INF
				for p in leaf:leaf_lowest=minf(leaf_lowest,p.y)
				for a in paw:
					lowest=minf(lowest,a.y)
					for b in leaf:
						if a.distance_to(b)<distance:distance=a.distance_to(b);points=[[a.x,a.y,a.z],[b.x,b.y,b.z]]
				item.paw_leaf_vertex_distances.append({"time":t,"distance_m":distance,"paw_min_y":lowest,"leaf_min_y":leaf_lowest,"nearest_vertices":points,"paw_vertices":paw.size(),"leaf_vertices":leaf.size()})
		if role=="meituan":actor.pose(6);dump(actor,role,"order");actor.pose(20);dump(actor,role,"open")
		elif role=="doubao":actor.pose(12);dump(actor,role,"point")
		else:actor.pose(14);dump(actor,role,"paw")
		report.roles[role]=item;actor.free()
	write_json(OUT+"mascot_contact_review.json",report)
	print(JSON.stringify(report));quit()
