extends "validate_photo_entrances.gd"
## Run with --photo-output, using the normal Windows scene and default survey.


func _initialize() -> void:
	survey_path=ProjectSettings.globalize_path("res://").path_join("../tools/teaching_one_approach_survey.json")
	super._initialize()


func survey_routes() -> void:
	await super.survey_routes()
	checks["removed_obsolete_side_obstacles"]=game.world.get_meta("teaching_one_removed_legacy_triangles",0)>0
	for x in [-5.6,5.6]:
		checks["side_entry_clear_"+str(x)]=probe(Vector3(x-.5,1.25,166.8),Vector3(x+.5,1.25,166.8)).is_empty()
	var samples := 0
	var mismatches: Array = []
	for mesh in game.world.get_children():
		if not mesh is MeshInstance3D or not mesh.name.begins_with("TeachingOneSide"):
			continue
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		# The first two triangles are the actual rendered walk surface.
		for offset in [0,3]:
			for weights in [Vector3(.2,.4,.4),Vector3(.4,.2,.4),Vector3(.4,.4,.2)]:
				var position: Vector3 = mesh.to_global(vertices[offset]*weights.x+
					vertices[offset+1]*weights.y+vertices[offset+2]*weights.z)
				var hit := probe(position+Vector3.UP,position-Vector3.UP)
				samples+=1
				if hit.is_empty() or absf(hit.position.y-position.y)>.004:
					mismatches.append({"mesh":str(mesh.name),"position":str(position),"hit":str(hit)})
	checks["ramp_meshes_match_collision"]=samples==24 and mismatches.is_empty()
	print("ENTRY_SURFACE_SAMPLES ",samples," mismatches=",JSON.stringify(mismatches))
	var paint: MeshInstance3D = game.world.get_node("TeachingOneYellowKeepClear")
	var points: PackedVector3Array = paint.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var painted_area := 0.0
	for index in range(0,points.size(),3):
		painted_area+=(points[index+1]-points[index]).cross(points[index+2]-points[index]).length()*.5
	checks["yellow_lines_leave_asphalt_visible"]=painted_area>10.0 and painted_area<25.0
	checks["yellow_marking_above_pavement"]=is_equal_approx(points[0].y,.117)
	print("ENTRY_PAINT area_m2=",painted_area," court_m2=",22.4*7.0)
	if "--approach-review-obj" in OS.get_cmdline_user_args():
		export_review_mesh()


func export_review_mesh() -> void:
	# Small, exact in-game meshes for the Blender approach review; no copied GLB.
	var obj := FileAccess.open(out.path_join("approach-review.obj"),FileAccess.WRITE)
	obj.store_line("mtllib approach-review.mtl")
	var index := 1
	for mesh in game.world.get_children():
		if not mesh is MeshInstance3D or not mesh.has_meta("teaching_one_approach"):
			continue
		obj.store_line("o "+str(mesh.name))
		obj.store_line("usemtl Yellow" if mesh.name.contains("Yellow") else "usemtl Stone")
		var points: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for point in points:
			var world: Vector3 = mesh.to_global(point)
			obj.store_line("v %.6f %.6f %.6f" % [world.x,world.y,world.z-163.0])
		for offset in range(0,points.size(),3):
			obj.store_line("f %d %d %d" % [index+offset,index+offset+1,index+offset+2])
		index+=points.size()
	obj.close()
	var mtl := FileAccess.open(out.path_join("approach-review.mtl"),FileAccess.WRITE)
	mtl.store_string("newmtl Stone\nKd 0.62 0.64 0.61\nnewmtl Yellow\nKd 0.78 0.71 0.45\n")
	mtl.close()
