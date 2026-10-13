extends RefCounted
## Three measured landscape fragments. No replacement of the accepted Hero world.
## Shape, road samples, reservations, furnishing positions and ports come from JSON.

static func polygon(values:Array)->PackedVector2Array:
	var result=PackedVector2Array()
	for p in values:result.append(Vector2(p[0],p[1]))
	return result

static func protected_areas()->Array:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/module_layout.json"))
	return data.get("protected_polygons",[])

static func contains(spec:Dictionary,p:Vector2)->bool:
	if not Geometry2D.is_point_in_polygon(p,polygon(spec.polygon)):return false
	for excluded in protected_areas():
		if Geometry2D.is_point_in_polygon(p,polygon(excluded.polygon)):return false
	return true

static func build(c:Node3D,s:Dictionary):
	var outline=polygon(s.polygon)
	var cuts=[]
	for water in c.ponds:cuts.append(water)
	for area in protected_areas():cuts.append(polygon(area.polygon))
	# The eastern return overlaps the completed north fragment by 32 m².
	# Difference touches this module's top edge, so it creates no inner hole.
	if s.id=="east_teaching_garden_02":
		var north=JSON.parse_string(FileAccess.get_file_as_string("res://data/north_axis_layout.json"))
		cuts.append(polygon(north.polygon))
	var land=_subtract([outline],cuts)
	var stone=c.asset_material("Stone",Color("c5bca4"))
	var wood=c.asset_material("Wood",Color("665c48"))
	for part in land:
		c.poly_mesh(part,0,c.mats.grass)
		_prism(c,part,-.75,0,"Wave2WalkableLand_"+s.id)
		_skirt(c,part,-3.15,-.035,stone)
		_skirt(c,part,-3.95,-3.15,wood)
		c.poly_mesh(part,-3.94,wood)
	# Actual intersections remain blocked. All three current fragments avoid them.
	for area in protected_areas():
		for part in Geometry2D.intersect_polygons(outline,polygon(area.polygon)):
			if area.kind=="water":
				c.poly_mesh(part,-.05,c.mats.water);c.block_water(part)
			else:_prism(c,part,-.75,8.0,"Wave2ProtectedBuilding_"+area.id)
	for water in c.ponds:
		for part in Geometry2D.intersect_polygons(outline,water):
			c.poly_mesh(part,-.05,c.mats.water);c.block_water(part)
	var seam_boxes=[]
	for path in s.paths:
		var points=polygon(path.points)
		_stroke_patch(c,points,path.width+.30,.036,stone,false,land)
		_stroke_patch(c,points,path.width,s.surface_top,c.mats.path,true,land)
		for i in range(points.size()-1):
			var a=points[i];var b=points[i+1]
			var d=(b-a).normalized();var normal=Vector2(-d.y,d.x)
			for step in range(1,int(a.distance_to(b)/2.6)):
				var center=a+d*step*2.6
				if not contains(s,center+normal*(path.width*.5+.05)) or not contains(s,center-normal*(path.width*.5+.05)):continue
				seam_boxes.append(_box_transform(Vector3(center.x,s.surface_top+.001,center.y),Vector3(path.width-.16,.002,.016),atan2(d.x,d.y)))
	# Interface paving stays inside the retained plinth. The western link passes south
	# of its last hedge; these small additions never replace existing GLB surfaces.
	var old_plinth=PackedVector2Array([Vector2(-80,118),Vector2(80,118),Vector2(80,238),Vector2(-80,238)])
	var apron_land=_subtract([old_plinth],cuts)
	for apron in s.get("port_aprons",[]):
		var points=polygon(apron.points)
		_stroke_patch(c,points,apron.width+.30,.036,stone,false,apron_land)
		_stroke_patch(c,points,apron.width,s.surface_top,c.mats.path,true,apron_land)
	for node in s.story_nodes:
		var p=node.position;var size=node.pad_size
		var pad=PackedVector2Array([Vector2(p[0]-size[0]*.5,p[2]-size[1]*.5),Vector2(p[0]+size[0]*.5,p[2]-size[1]*.5),Vector2(p[0]+size[0]*.5,p[2]+size[1]*.5),Vector2(p[0]-size[0]*.5,p[2]+size[1]*.5)])
		_patch(c,pad,node.ground_y,c.mats.path,true,land)
	_box_batch(c,seam_boxes,c.asset_material("Wave2PavingJoint",Color("b4ad97")),"Wave2PavingJoints")
	_boundaries(c,s,outline)
	_planting(c,s)
	_furniture(c,s)

static func _subtract(parts:Array,cuts:Array)->Array:
	var result=parts
	for cut in cuts:
		var next=[]
		for p in result:
			for fragment in Geometry2D.clip_polygons(p,cut):next.append(fragment)
		result=next
	return result

static func _quad(a:Vector2,b:Vector2,width:float)->PackedVector2Array:
	var d=(b-a).normalized();var side=Vector2(-d.y,d.x)*width*.5
	# Small overlap closes same-height bends without leaving collision slivers.
	return PackedVector2Array([a-d*.035+side,b+d*.035+side,b+d*.035-side,a-d*.035-side])

static func _patch(c:Node3D,shape:PackedVector2Array,top:float,mat:Material,collision:bool,land:Array):
	for part in land:
		for cut in Geometry2D.intersect_polygons(shape,part):
			c.poly_mesh(cut,top,mat)
			if collision:_prism(c,cut,-.1,top,"Wave2Path")

static func _stroke_patch(c:Node3D,points:PackedVector2Array,width:float,top:float,mat:Material,collision:bool,land:Array):
	# One joined polygon retains full paving through each mapped bend. Independent
	# butt-ended quads leave triangular lawn notches on the outside of a turn.
	var extended=points.duplicate()
	extended[0]-=(points[1]-points[0]).normalized()*.04
	extended[-1]+=(points[-1]-points[-2]).normalized()*.04
	for shape in Geometry2D.offset_polyline(extended,width*.5,Geometry2D.JOIN_ROUND,Geometry2D.END_BUTT):
		_patch(c,shape,top,mat,collision,land)

static func _prism(c:Node3D,shape:PackedVector2Array,bottom:float,top:float,label:String):
	var body=StaticBody3D.new();body.name=label;c.world.add_child(body)
	# Preserve convex paving patches whole: a ray exactly on a triangle diagonal
	# can miss both coplanar hull edges despite the underlying land being safe.
	for convex in Geometry2D.decompose_polygon_in_convex(shape):
		var points=PackedVector3Array()
		for p in convex:
			points.append(Vector3(p.x,bottom,p.y));points.append(Vector3(p.x,top,p.y))
		var hull=ConvexPolygonShape3D.new();hull.points=points
		var collider=CollisionShape3D.new();collider.shape=hull;body.add_child(collider)
	return body

static func _skirt(c:Node3D,poly:PackedVector2Array,bottom:float,top:float,mat:Material):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(poly.size()):
		var a=poly[i];var b=poly[(i+1)%poly.size()]
		var vs=[Vector3(a.x,bottom,a.y),Vector3(a.x,top,a.y),Vector3(b.x,top,b.y),Vector3(b.x,bottom,b.y)]
		for index in [0,1,2,0,2,3]:st.add_vertex(vs[index])
	st.generate_normals()
	var mesh=MeshInstance3D.new();mesh.name="Wave2PlinthSkirt";mesh.mesh=st.commit();mesh.material_override=mat;c.world.add_child(mesh)

static func _on_port(a:Vector2,b:Vector2,s:Dictionary)->bool:
	for port in s.ports:
		var lo=float(port.span[0]);var hi=float(port.span[1])
		match port.side:
			"east":
				if is_equal_approx(a.x,80) and is_equal_approx(b.x,80) and minf(a.y,b.y)>=lo-.01 and maxf(a.y,b.y)<=hi+.01:return true
			"west":
				if is_equal_approx(a.x,-80) and is_equal_approx(b.x,-80) and minf(a.y,b.y)>=lo-.01 and maxf(a.y,b.y)<=hi+.01:return true
			"south":
				if is_equal_approx(a.y,238) and is_equal_approx(b.y,238) and minf(a.x,b.x)>=lo-.01 and maxf(a.x,b.x)<=hi+.01:return true
	return false

static func _boundaries(c:Node3D,s:Dictionary,outline:PackedVector2Array):
	var rim=[]
	for i in range(outline.size()):
		var a=outline[i];var b=outline[(i+1)%outline.size()]
		if _on_port(a,b,s):continue
		if s.id=="east_teaching_garden_02" and is_equal_approx(a.y,145) and is_equal_approx(b.y,145):
			if a.x<88:a.x=88
			if b.x<88:b.x=88
		for edge in boundary_segments(a,b,s.id):
			var start:Vector2=edge[0];var end:Vector2=edge[1]
			var mid=(start+end)*.5;var angle=atan2(end.x-start.x,end.y-start.y)
			var body=c.static_box(Vector3(mid.x,1.05,mid.y),Vector3(.32,3.0,start.distance_to(end)+.04),"Wave2OuterBoundary_"+s.id);body.rotation.y=angle
			rim.append(_box_transform(Vector3(mid.x,.045,mid.y),Vector3(.28,.09,start.distance_to(end)),angle))
	_box_batch(c,rim,c.mats.stone,"Wave2Rim")

static func boundary_segments(a:Vector2,b:Vector2,id:String)->Array:
	var regions=[polygon([[-80,118],[80,118],[80,238],[-80,238]])]
	if id!="north_axis":regions.append(polygon(JSON.parse_string(FileAccess.get_file_as_string("res://data/north_axis_layout.json")).polygon))
	for other in JSON.parse_string(FileAccess.get_file_as_string("res://data/module_layout.json")).modules:
		if other.id=="guo_plaza_03" and "--plaza-before" in OS.get_cmdline_user_args():continue
		if other.enabled and other.id!=id and other.has("polygon"):regions.append(polygon(other.polygon))
	var splits=[0.0,1.0];var delta=b-a
	for region in regions:
		for i in region.size():
			var at=Geometry2D.segment_intersects_segment(a,b,region[i],region[(i+1)%region.size()])
			if at!=null:
				var t=clampf((at-a).dot(delta)/delta.length_squared(),0,1)
				if t not in splits:splits.append(t)
	splits.sort();var external=[]
	var normal=delta.normalized().orthogonal()*.05
	for i in range(splits.size()-1):
		var start=a.lerp(b,splits[i]);var end=a.lerp(b,splits[i+1])
		if start.distance_to(end)<.01:continue
		var mid=(start+end)*.5;var internal=false
		for region in regions:
			if Geometry2D.is_point_in_polygon(mid+normal,region) and Geometry2D.is_point_in_polygon(mid-normal,region):internal=true;break
		if not internal:external.append([start,end])
	return external

static func _distance_to_paths(s:Dictionary,p:Vector2)->float:
	var result=INF
	for path in s.paths:
		var points=polygon(path.points)
		for i in range(points.size()-1):result=minf(result,p.distance_to(Geometry2D.get_closest_point_to_segment(p,points[i],points[i+1]))-path.width*.5)
	return result

static func _reserved(s:Dictionary,p:Vector2,margin:float=0)->bool:
	for node in s.story_nodes:
		if p.distance_to(Vector2(node.position[0],node.position[2]))<node.clear_radius+margin:return true
	return false

static func _planting(c:Node3D,s:Dictionary):
	var batches={};var trees=[]
	for tree in s.trees:
		var p=Vector2(tree[0],tree[1])
		if not contains(s,p) or _reserved(s,p,.9):continue
		var key="diotree%d%d"%[tree[2],tree[3]]
		if not batches.has(key):batches[key]=[]
		batches[key].append(c.placement(p.x,0,p.y,Vector3.ONE*tree[4],float(trees.size())*1.17))
		c.static_box(Vector3(p.x,1,p.y),Vector3(.56,2,.56),"Wave2TreeTrunk")
		trees.append(p)
	for key in batches:c.multimesh(key,batches[key]);c.tree_count+=batches[key].size()
	var rng=RandomNumberGenerator.new();rng.seed=abs(s.id.hash())
	var shrubs=[];var grass=[];var outline=polygon(s.polygon)
	for i in range(360):
		var p=Vector2(rng.randf_range(s.bounds[0]+1.0,s.bounds[2]-1.0),rng.randf_range(s.bounds[1]+1.0,s.bounds[3]-1.0))
		if not contains(s,p) or _reserved(s,p,1.0) or _distance_to_paths(s,p)<.7:continue
		var edge_distance=INF
		for j in range(outline.size()):edge_distance=minf(edge_distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,outline[j],outline[(j+1)%outline.size()])))
		if edge_distance<.9:continue
		var near_tree=false
		for tree in trees:
			if p.distance_to(tree)<2.8:near_tree=true;break
		if (near_tree or edge_distance<2.8) and shrubs.size()<26:
			shrubs.append(c.placement(p.x,0,p.y,Vector3.ONE*rng.randf_range(.58,.82),rng.randf()*TAU))
		elif grass.size()<70:grass.append(c.placement(p.x,.012,p.y,Vector3.ONE*rng.randf_range(.46,.74),rng.randf()*TAU))
	c.multimesh("dioshrub",shrubs);c.multimesh("grass",grass)

static func _furniture(c:Node3D,s:Dictionary):
	var benches=[];var lamps=[]
	for b in s.benches:
		# A small paved apron seats the bench legs; no table in front of roadside seats.
		var along=Vector2(cos(b[2]),-sin(b[2]));var mid=Vector2(b[0],b[1])
		var a=mid-along*1.3;var z=mid+along*1.3
		_patch(c,_quad(a,z,1.25),.08,c.mats.path,true,[polygon(s.polygon)])
		benches.append(c.placement(b[0],.08,b[1],Vector3.ONE,b[2]))
		var body=c.static_box(Vector3(b[0],.62,b[1]),Vector3(1.86,1.08,.60),"Wave2Bench");body.rotation.y=b[2]
	for lamp in s.lamps:
		lamps.append(c.placement(lamp[0],.08,lamp[1],Vector3.ONE,lamp[2]))
		c.static_box(Vector3(lamp[0],1.3,lamp[1]),Vector3(.20,2.6,.20),"Wave2LampPost")
	c.multimesh("bench",benches);c.multimesh("lamp",lamps)
	for sign in s.signs:
		var p=Vector3(sign[0],.08,sign[1]);c.signpost(p,sign[2],sign[3])
		c.static_box(p+Vector3(0,.8,0),Vector3(.12,1.6,.12),"Wave2SignPost")
		c.static_box(p+Vector3(0,1.46,0),Vector3(2.2,.78,.14),"Wave2SignBoard")

static func _box_transform(p:Vector3,size:Vector3,angle:float)->Transform3D:
	return Transform3D(Basis(Vector3.UP,angle)*Basis.from_scale(size),p)

static func _box_batch(c:Node3D,transforms:Array,mat:Material,label:String):
	if transforms.is_empty():return
	var cube=BoxMesh.new();cube.size=Vector3.ONE;cube.material=mat
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=cube;mm.instance_count=transforms.size()
	for i in transforms.size():mm.set_instance_transform(i,transforms[i])
	var instance=MultiMeshInstance3D.new();instance.name=label;instance.multimesh=mm;c.world.add_child(instance)
