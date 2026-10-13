extends RefCounted
## Shared, art-directed planting over the existing GIS layout and physical campus.
const North=preload("res://scripts/north_axis_environment.gd")
const Geometry=preload("res://scripts/wave2_environment.gd")
const Basins=preload("res://scripts/tree_basins.gd")

static func enabled()->bool:
	return not "--sakura-before" in OS.get_cmdline_user_args()

static func in_segment(p:Vector2)->bool:
	var lo=80.0 if "--sakura-sample" in OS.get_cmdline_user_args() else 12.0
	var hi=118.0 if "--sakura-sample" in OS.get_cmdline_user_args() else 150.0
	return enabled() and absf(p.x)<9.0 and p.y>=lo and p.y<hi

static func safe(c:Node3D,p:Vector2,radius:float)->bool:
	if not in_segment(Vector2(0,p.y)):return false
	if p.y<118:
		for delta in [Vector2.ZERO,Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
			if not North.contains(p+delta):return false
		if North._distance_paths(North.layout(),p)<radius+.25:return false
	else:
		if c.pond_at(p) or absf(p.x)<5.9 or p.y>147:return false
		if North._distance_paths(North.layout(),p)<radius+.25:return false
	# Leave existing lamps, photographer, scholar, and lake approach clear.
	for l in North.layout().lamps:
		if p.distance_to(Vector2(l[0],l[1]))<radius+.55:return false
	for b in North.layout().benches:
		if p.distance_to(Vector2(b[0],b[1]))<radius+1.45:return false
	for q in [Vector2(10.4,140.8),Vector2(3.4,145),Vector2(-17,146.9)]:
		if p.distance_to(q)<radius+2:return false
	return true

static func low_bark(c:Node3D,asset:String)->ConcavePolygonShape3D:
	var faces=PackedVector3Array()
	for part in c.asset_cache[asset]:
		for s in part.mesh.get_surface_count():
			var mat=part.mesh.surface_get_material(s)
			if mat==null or not "Bark" in mat.resource_name:continue
			var ar=part.mesh.surface_get_arrays(s);var vs=ar[Mesh.ARRAY_VERTEX];var ids=ar[Mesh.ARRAY_INDEX]
			var count=ids.size() if ids!=null and not ids.is_empty() else vs.size()
			for i in range(0,count,3):
				var tri=[]
				for j in range(3):tri.append(part.transform*vs[ids[i+j] if ids!=null and not ids.is_empty() else i+j])
				var clipped=[]
				for j in range(3):
					var a:Vector3=tri[j];var b:Vector3=tri[(j+1)%3]
					if a.y<=2.4:clipped.append(a)
					if (a.y<=2.4)!=(b.y<=2.4):clipped.append(a.lerp(b,(2.4-a.y)/(b.y-a.y)))
				for j in range(1,clipped.size()-1):faces.append(clipped[0]);faces.append(clipped[j]);faces.append(clipped[j+1])
	var shape=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces);return shape

static func build(c:Node3D):
	if not enabled():return
	var first=c.world.get_child_count()
	var rng=RandomNumberGenerator.new();rng.seed=20260405
	var batches=[[],[],[]];var points=[]
	# Existing research coordinates retained; only the tree geometry/scale changes.
	for tree in North.layout().trees:
		var p=Vector2(tree[0],tree[1])
		if in_segment(p) and safe(c,p,.55):points.append(p)
	for side in [-1,1]:
		for i in range(4):
			var p=Vector2(side*7.15,123+i*7.45)
			if in_segment(p) and safe(c,p,.55):points.append(p)
		var entrance=Vector2(side*7.15,14.0)
		if in_segment(entrance) and safe(c,entrance,.55):points.append(entrance)
	for i in points.size():
		var p:Vector2=points[i];var sc=rng.randf_range(1.04,1.16)
		batches[i%3].append(c.placement(p.x,0,p.y,Vector3(sc,sc*rng.randf_range(.93,1.05),sc),rng.randf()*TAU))
	var contacts=[];var bark_records=[]
	for variant in range(3):
		var asset="sakura_tree_"+str(variant);c.multimesh_batch(asset,batches[variant])
		if batches[variant].is_empty():continue
		var shape=low_bark(c,asset)
		for tr in batches[variant]:
			var body=StaticBody3D.new();body.name="SakuraBarkContact";body.transform=tr;c.world.add_child(body)
			var cs=CollisionShape3D.new();cs.shape=shape;body.add_child(cs)
			contacts.append({"at":[tr.origin.x,tr.origin.z],"asset":asset,"scale":str(tr.basis.get_scale()),"collision":"actual bark clipped at local y=2.4"})
			var record={"asset":asset,"actual_asset":asset,"placement":tr,"position":tr.origin,"body":body.get_path()}
			bark_records.append(record)
			if "lookdev_tree_contacts" in c:c.lookdev_tree_contacts.append(record)
	c.tree_count+=points.size()
	var basins=Basins.build(c,bark_records)
	# Discontinuous planting islands. Their shapes follow vegetation and leave paths open.
	var shrubs=[[],[],[]];var grasses=[];var occupied=[]
	for side in [-1,1]:
		for i in range(165):
			var z=13.5+i*.80;var x=side*(7.0+rng.randf_range(-.7,2.8));var p=Vector2(x,z)
			var sc=rng.randf_range(.70,1.18)
			if not safe(c,p,.75*sc):continue
			var near=false
			for t in points:
				if p.distance_to(t)<.82:near=true;break
			if near:continue
			var tr=c.placement(x,0,z,Vector3(sc,sc*rng.randf_range(.65,1.0),sc),rng.randf()*TAU)
			if Basins.overlaps(p,.95*sc,basins):continue
			shrubs[i%3].append(tr);occupied.append(p)
		for i in range(300):
			var z=rng.randf_range(13,147);var x=side*rng.randf_range(6.3,10.1);var p=Vector2(x,z)
			if not safe(c,p,.33):continue
			var tr=c.placement(x,.012,z,Vector3.ONE*rng.randf_range(.6,1.05),rng.randf()*TAU)
			if Basins.overlaps(p,.4,basins):continue
			grasses.append(tr)
	for i in range(3):c.multimesh_batch("sakura_shrub_"+str(i),shrubs[i])
	c.multimesh_batch("sakura_grass",grasses)
	# Higher green silhouettes sit behind the flower row, checked against lakes/paths/buildings.
	var backdrop=[]
	for side in [-1,1]:
		for i in range(8):
			var p=Vector2(side*(11.6+rng.randf_range(0,1.0)),31+i*15)
			if not safe(c,p,1.05):continue
			var close=false
			for t in North.layout().trees:
				if p.distance_to(Vector2(t[0],t[1]))<4:close=true;break
			if not close:backdrop.append(c.placement(p.x,0,p.y,Vector3.ONE*rng.randf_range(.96,1.17),rng.randf()*TAU))
	c.multimesh("diotree10",backdrop);c.tree_count+=backdrop.size()
	# Diorama contacts for the additional high trees; Live supplies actual bark contacts.
	if not "lookdev_tree_contacts" in c:
		for t in backdrop:c.static_box(t.origin+Vector3.UP,Vector3(.56,2,.56),"SakuraBackgroundTrunk")
	var pavers=[]
	for side in [-1,1]:
		for z in range(13,150):
			if not in_segment(Vector2(0,z)):continue
			var p=Vector2(side*5.10,z+.5)
			if z<118 and not North.contains(p):continue
			pavers.append(Geometry._box_transform(Vector3(p.x,.042,p.y),Vector3(1.45,.076,.988),0))
			# Thin infill sits on the already walkable strip; top difference is below a step.
			c.static_box(Vector3(p.x,.015,p.y),Vector3(1.45,.13,.99),"SakuraSidePavingSupport")
	Geometry._box_batch(c,pavers,c.mats.path,"SakuraSidePaving")
	# Understated low garden lights, placed in planting rather than the travel lane.
	var dark=c.material(Color("354b43"));var glow=c.material(Color("e7d9ac"))
	for side in [-1,1]:
		for z in [34,61,87,115,132]:
			var p=Vector2(side*6.25,z)
			if not safe(c,p,.22):continue
			c.box(Vector3(p.x,.40,p.y),Vector3(.16,.8,.16),dark)
			c.box(Vector3(p.x,.76,p.y),Vector3(.19,.13,.19),glow)
			c.box(Vector3(p.x,.86,p.y),Vector3(.23,.05,.23),dark)
			c.static_box(Vector3(p.x,.44,p.y),Vector3(.23,.9,.23),"SakuraGardenLight")
	petals(c,rng)
	for i in range(first,c.world.get_child_count()):
		var n=c.world.get_child(i);n.set_meta("sakura_authored",true)
		if n is GeometryInstance3D:n.visibility_range_end=0
	c.world.set_meta("sakura_avenue",{"flower_trees":points.size(),"green_backdrop_trees":backdrop.size(),"shrubs":occupied.size(),"grass_clumps":grasses.size(),"tree_contacts":contacts,"sample_only":"--sakura-sample" in OS.get_cmdline_user_args(),"map_changed":false,"existing_population_changed":false})
	c.world.set_meta("sakura_bark_records",bark_records)
	print("SAKURA_READY flowers=",points.size()," shrubs=",occupied.size()," grasses=",grasses.size()," backdrop=",backdrop.size())

static func petals(c:Node3D,rng:RandomNumberGenerator):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var a=TAU*i/8;var b=TAU*(i+1)/8
		for point in [Vector3(0,.008,0),Vector3(cos(b)*.038,0,sin(b)*.024),Vector3(cos(a)*.038,0,sin(a)*.024)]:st.add_vertex(point)
	st.generate_normals();var mesh=st.commit()
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=mesh
	var transforms=[];var colors=[]
	for i in range(3400):
		var z=rng.randf_range(14,149)
		if not in_segment(Vector2(0,z)):continue
		var x=([-1,1][i%2])*rng.randf_range(3.25,3.95)
		if i%7==0:x=rng.randf_range(-3.2,3.2)
		# Modulation leaves clean sections between pockets of fallen blossom.
		if sin(z*.47+x)*.5+.5<rng.randf_range(0,.85):continue
		var sc=rng.randf_range(.6,1.4);transforms.append(c.placement(x,.098,z,Vector3(sc,1,sc),rng.randf()*TAU))
		colors.append(Color("e8b4bc").lerp(Color("f2d8c7"),rng.randf()))
	mm.instance_count=transforms.size()
	for i in transforms.size():mm.set_instance_transform(i,transforms[i]);mm.set_instance_color(i,colors[i])
	var mi=MultiMeshInstance3D.new();mi.name="SakuraFallenPetals";mi.multimesh=mm
	var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.95;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mi.material_override=mat;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;c.world.add_child(mi)
	var drift=GPUParticles3D.new();drift.name="SakuraDriftingPetals";drift.amount=100;drift.lifetime=18;drift.preprocess=12
	drift.position=Vector3(0,4.2,85);drift.visibility_aabb=AABB(Vector3(-15,-6,-80),Vector3(30,14,160));drift.draw_pass_1=mesh
	var pm=ParticleProcessMaterial.new();pm.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;pm.emission_box_extents=Vector3(7,2.5,60)
	pm.direction=Vector3(.3,-1,.1);pm.spread=16;pm.initial_velocity_min=.12;pm.initial_velocity_max=.32;pm.gravity=Vector3(.008,-.012,0)
	pm.angular_velocity_min=-24;pm.angular_velocity_max=28;pm.scale_min=.8;pm.scale_max=1.5;pm.color=Color("efc8cd")
	drift.process_material=pm;drift.material_override=mat;drift.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;c.world.add_child(drift)
