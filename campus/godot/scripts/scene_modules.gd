extends RefCounted
const NorthAxis=preload("res://scripts/north_axis_environment.gd")
## Small grounded modules use the same materials and collision convention as the hero.
## The JSON is the layout source; this builder never rescales the measured campus.
static func layout()->Array:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/module_layout.json"))
	if "--plaza-before" in OS.get_cmdline_user_args():
		for s in data.modules:
			if s.id=="guo_plaza_03":s.enabled=false
	return data.modules

static func build(campus:Node3D):
	NorthAxis.build(campus)
	preload("res://scripts/north_axis_landscape_detail.gd").build(campus)
	for spec in layout():
		if not spec.enabled:continue
		if spec.template=="tree_lined_walkway":walkway(campus,spec)
		elif spec.template=="wave2_landscape":preload("res://scripts/wave2_environment.gd").build(campus,spec)
		elif spec.template=="plaza_expansion":preload("res://scripts/plaza_environment.gd").build(campus,spec)
		elif spec.template=="mapped_campus_land":preload("res://scripts/campus_network.gd").build_land(campus,spec)
		elif spec.template=="library_district":preload("res://scripts/library_district.gd").build(campus,spec)
		elif spec.template=="sports_district":preload("res://scripts/sports_district.gd").build(campus,spec)
		elif spec.template=="south_sports":preload("res://scripts/south_sports.gd").build(campus,spec)
		elif spec.template=="full_mapped_district":preload("res://scripts/full_districts.gd").build(campus,spec)
	preload("res://scripts/campus_network.gd").build_roads(campus)
	preload("res://scripts/campus_network.gd").build_trees(campus)

static func boundary_openings(side:String)->Array:
	var result=NorthAxis.boundary_openings(side)
	for spec in layout():
		if not spec.enabled:continue
		for port in spec.get("ports",[]):
			if port.side==side:result.append(Vector2(port.span[0],port.span[1]))
	result.sort_custom(func(a,b):return a.x<b.x)
	return result

static func story_nodes()->Dictionary:
	var result={}
	for spec in layout():
		if not spec.enabled:continue
		for node in spec.get("story_nodes",[]):
			result[node.id]=node.duplicate(true)
			result[node.id]["module_id"]=spec.id
	for node in NorthAxis.layout().story_nodes:
		result[node.id]=node.duplicate(true)
		result[node.id]["module_id"]="north_axis"
	return result

static func contains(point:Vector2)->bool:
	if NorthAxis.contains(point):return true
	for spec in layout():
		if not spec.enabled:continue
		if spec.has("polygon"):
			if preload("res://scripts/wave2_environment.gd").contains(spec,point):return true
		else:
			var b=spec.bounds
			if point.x>=b[0] and point.x<=b[2] and point.y>=b[1] and point.y<=b[3]:return true
	return false

static func walkway(c:Node3D,s:Dictionary):
	var b=s.bounds
	var x=(b[0]+b[2])*.5;var z=(b[1]+b[3])*.5
	var w=b[2]-b[0];var length=b[3]-b[1]
	var rect=PackedVector2Array([Vector2(b[0],b[1]),Vector2(b[2],b[1]),Vector2(b[2],b[3]+.02),Vector2(b[0],b[3]+.02)])
	var land=[rect]
	for pond in c.ponds:
		var next=[]
		for p in land:
			for piece in Geometry2D.clip_polygons(p,pond):next.append(piece)
		land=next
		for water in Geometry2D.intersect_polygons(rect,pond):
			c.poly_mesh(water,-.05,c.mats.water);c.block_water(water)
	for p in land:c.poly_mesh(p,0,c.mats.grass)
	c.box(Vector3(x,-1.7,z),Vector3(w,3.2,length),c.asset_material("Stone",Color("c5bca4")))
	c.box(Vector3(x,-3.7,z),Vector3(w+1,.8,length),c.asset_material("Wood",Color("665c48")))
	c.static_box(Vector3(x,-.35,z),Vector3(w,.7,length+.04),"ModuleWalkableLand")
	c.box(Vector3(x,s.surface_top-.05,z),Vector3(s.path_width,.10,length+.04),c.mats.path,true)
	for side in [-1,1]:
		var edge=x+side*(s.path_width*.5+.25)
		for k in range(int(length)):
			c.box(Vector3(edge,.09,b[1]+.5+k),Vector3(.23,.18,.96),c.mats.stone)
		c.static_box(Vector3(x+side*w*.5,1,z),Vector3(.4,3,length),"ModuleBoundary")
	c.static_box(Vector3(x,1,b[1]),Vector3(w,3,.4),"ModuleBoundary")
	# Repeatable small landscape accents at the quiet join, leaving the axis clear.
	var grass=[]
	for side in [-1,1]:
		for k in range(5):grass.append(c.placement(x+side*5.35,.02,b[1]+1.1+k*2.1,Vector3.ONE*.65,k*1.17))
	c.multimesh("grass",grass)
