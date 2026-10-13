extends SceneTree
const North=preload("res://scripts/north_axis_environment.gd")
const Modules=preload("res://scripts/scene_modules.gd")
const Network=preload("res://scripts/campus_network.gd")
const LAYER=1<<22
func inside_exact(p:Vector2,poly:PackedVector2Array)->bool:
	# Geometry2D's edge tolerance includes points 5mm outside these long, oblique
	# campus edges. The seam probe must only demand triangles inside the footprint.
	var inside=false
	for i in range(poly.size()):
		var a=poly[i];var b=poly[(i+1)%poly.size()]
		if (a.y>p.y)!=(b.y>p.y) and p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x:inside=not inside
	return inside
func _initialize():call_deferred("run")
func run():
	var args=OS.get_cmdline_user_args()
	var scene="diorama" if "--diorama" in args else "lake_garden_expanded"
	if "--optimized" in args:scene="campus_performance"
	if "--game" in args:scene="campus_game"
	var c=load("res://scenes/"+scene+".tscn").instantiate();root.add_child(c);await process_frame
	var old="--simulate-old-ground" in args
	if old:
		for n in c.world.get_children():
			if n.name=="CoreContinuousLand":n.free()
		North._surface(c,North._pieces(North._rect(-79.9,118.1,159.8,119.8),c.ponds),0,c.mats.grass,"OldInsetGround")
	var proof=Node3D.new();c.world.add_child(proof);var meshes=0
	for n in c.world.get_children():
		if not n is MeshInstance3D or not n.visible or not n.mesh:continue
		var mat=n.material_override
		if mat!=c.mats.grass:continue
		var body=StaticBody3D.new();body.collision_layer=LAYER;body.collision_mask=0;body.transform=n.transform
		var shape=CollisionShape3D.new();shape.shape=n.mesh.create_trimesh_shape();shape.shape.backface_collision=true;body.add_child(shape);proof.add_child(body);meshes+=1
	await physics_frame;await physics_frame
	var regions=[North._core(),North.polygon(North.layout().polygon)]
	for m in Modules.layout():
		if m.enabled and m.has("polygon"):regions.append(North.polygon(m.polygon))
	var samples=0;var missing=[]
	var building_footprints=[]
	for b in Network.data().buildings:building_footprints.append(North.polygon(b.outline))
	for region in regions:
		for i in region.size():
			var a=region[i];var b=region[(i+1)%region.size()];var normal=(b-a).normalized().orthogonal()
			var steps=maxi(1,int(ceil(a.distance_to(b)/.5)))
			for j in steps:
				for offset in [-.075,-.025,-.005,.005,.025,.075]:
					var p=a.lerp(b,(j+.5)/steps)+normal*offset
					var inside=false
					for r in regions:
						if inside_exact(p,r):inside=true;break
					if not inside or North._inside_pond(p,North.layout()):continue
					var excluded=false
					for area in North.Geometry.protected_areas():
						if Geometry2D.is_point_in_polygon(p,North.polygon(area.polygon)):excluded=true;break
					for footprint in building_footprints:
						if Geometry2D.is_point_in_polygon(p,footprint):excluded=true;break
					if excluded:continue
					samples+=1
					var query=PhysicsRayQueryParameters3D.create(Vector3(p.x,.02,p.y),Vector3(p.x,-.02,p.y),LAYER)
					if c.get_world_3d().direct_space_state.intersect_ray(query).is_empty():missing.append([p.x,p.y])
	var report={"scene":scene,"simulated_old_inset":old,"visual_meshes":meshes,"samples":samples,"missing":missing,"passed":meshes>0 and samples>1000 and missing.is_empty(),"method":"Actual visible grass triangles on a separate ray layer; 0.5m boundary sampling, offsets 5/25/75mm on both sides. Water and protected areas excluded. Physics slabs cannot mask visual holes."}
	var dir="res://../renders/ground_seams/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f=FileAccess.open(dir+scene+("_before" if old else "_after")+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"))
	print("GROUND_SEAMS ",scene," old=",old," samples=",samples," missing=",missing.size())
	c.queue_free();await process_frame;await process_frame
	quit(0 if report.passed else 1)
