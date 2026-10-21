extends RefCounted
const North=preload("res://scripts/north_axis_environment.gd")
const Geometry=preload("res://scripts/wave2_environment.gd")
const ROAD_TOP=0.14
static var _data:Dictionary={}
static func data()->Dictionary:
	if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/campus_road_network.json"))
	return _data

static func enabled()->bool:
	for s in JSON.parse_string(FileAccess.get_file_as_string("res://data/module_layout.json")).modules:
		if s.id=="north_academic_04":return s.enabled
	return false

static func bridge_approach(tip:Vector2,outward:Vector2)->Dictionary:
	if not enabled():return {}
	for road in data().roads:
		if not road.get("build_enabled",true):continue
		var points=North.polygon(road.points);var next:Vector2
		if points[0].distance_to(tip)<.01:next=points[1]
		elif points[-1].distance_to(tip)<.01:next=points[-2]
		else:continue
		if (next-tip).normalized().dot(outward)>.999:
			return {"width":road.width,"top":ROAD_TOP}
	return {}

static func regions()->Array:
	var result=[North._core(),North.polygon(North.layout().polygon)]
	for s in JSON.parse_string(FileAccess.get_file_as_string("res://data/module_layout.json")).modules:
		if s.enabled and s.has("polygon"):result.append(North.polygon(s.polygon))
	return result

static func build_land(c:Node3D,s:Dictionary):
	var cuts=[North._core(),North.polygon(North.layout().polygon)]
	var modules=JSON.parse_string(FileAccess.get_file_as_string("res://data/module_layout.json")).modules
	# Each module renders its own difference, retaining overlap as an open join.
	for other in modules:
		if other.id==s.id:break
		if other.enabled and other.has("polygon"):
			var prior=North.polygon(other.polygon)
			# Adjacent survey edges rounded to millimetres create submillimetre slivers.
			# A 2cm overlap joins the same world-space grass material without a crack.
			if s.template=="full_mapped_district":cuts.append_array(Geometry2D.offset_polygon(prior,-.02))
			else:cuts.append(prior)
	for pond in c.ponds:cuts.append(pond)
	for building in data().buildings:cuts.append(North.polygon(building.outline))
	var land=North._pieces(North.polygon(s.polygon),cuts)
	North._surface(c,land,0,c.mats.grass,"MappedCampusLand_"+s.id)
	North._solid(c,land,-.75,0,"MappedCampusGround_"+s.id)
	Geometry._boundaries(c,s,North.polygon(s.polygon))
	if s.id=="north_academic_04":_buildings(c)

static func _buildings(c:Node3D):
	for asset in ["north_teaching5","north_faculty_blocks","north_gate"]:
		var model=load("res://assets/"+asset+".glb").instantiate();model.name=asset.to_pascal_case();c.world.add_child(model);c.style(model)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/north_teaching_manifest.json"))
	for solid in manifest.collision_solids:
		North._solid(c,[North.polygon(solid.polygon)],solid.bottom,solid.top,"NorthAcademic_"+solid.name)
	var frontage=[];var building_cuts=[]
	for b in manifest.buildings:building_cuts.append(North.polygon(b.polygon))
	for b in manifest.buildings:
		var p=Vector2(b.front_approach[0],b.front_approach[2]);var nearest=Vector2.ZERO;var distance=INF
		for road in data().roads:
			var points=North.polygon(road.points)
			for i in range(points.size()-1):
				var q=Geometry2D.get_closest_point_to_segment(p,points[i],points[i+1])
				if p.distance_to(q)<distance:nearest=q;distance=p.distance_to(q)
		frontage.append_array(North._valid_surface(North._stroke(PackedVector2Array([nearest,p]),3.2),[North.polygon(data().north_extension.polygon)],building_cuts))
		frontage.append_array(North._pieces(North._rect(p.x-7.4,p.y-3.2,14.8,4.8),building_cuts))
	North._surface(c,frontage,.10,c.mats.path,"NorthAcademicEntryAprons")
	North._solid(c,frontage,-.1,.10,"NorthAcademicEntryPaths")
	c.signpost(Vector3(104,0,-53),"新北门 · 第五教学楼","North gate · Teaching 5")
	c.signpost(Vector3(155,0,-22),"教学行政楼 · 地空学院","Earth and Space Sciences")
	c.signpost(Vector3(338,0,-20),"管理科学教学科研楼","School of Management")
	c.signpost(Vector3(66,0,35),"专家楼饭店","USTC Expert Hotel")
	c.signpost(Vector3(111,0,111),"专家公寓 · 宿舍","Expert Apartments")
	c.world.set_meta("north_academic",{"buildings":manifest.buildings.size(),"new_north_gate":data().north_extension.new_north_gate.point})

static func road_distance(p:Vector2)->float:
	var nearest=INF
	for road in data().roads:
		var points=North.polygon(road.points)
		for i in range(points.size()-1):
			nearest=minf(nearest,p.distance_to(Geometry2D.get_closest_point_to_segment(p,points[i],points[i+1]))-road.width*.5-road.sidewalk_width)
	return nearest

static func legacy_tree_allowed(p:Vector2)->bool:
	if road_distance(p)<.75:return false
	if absf(p.y-225)<.1 or (absf(absf(p.x)-69)<.1 and p.y>=175 and p.y<=227):return false
	if absf(p.y-144)<.1 and absf(p.x)>12:return false
	if p.distance_to(Vector2(82,71))<.1:return false
	return true

static func _clipped(parts:Array,cuts:Array)->Array:
	var out=[];var seen=[]
	for region in regions():
		for part in parts:
			for intersection in Geometry2D.intersect_polygons(part,region):out.append_array(North._pieces(intersection,cuts+seen))
		seen.append(region)
	return out

static func build_roads(c:Node3D):
	var cuts=[]
	for pond in c.ponds:cuts.append(pond)
	for area in Geometry.protected_areas():cuts.append(North.polygon(area.polygon))
	for b in data().buildings:cuts.append(North.polygon(b.outline))
	var Surfaces=preload("res://scripts/road_surfaces.gd")
	var sidewalk=[];var curbs=[];var surfaces={};var previous_edges=[];var previous_roads=[];var built=[];var all_roads=[]
	for road in data().roads:
		if not road.get("build_enabled",true):continue
		all_roads.append_array(North._stroke(North.polygon(road.points),road.width))
	for road in data().roads:
		if not road.get("build_enabled",true):continue
		var points=North.polygon(road.points)
		if road.sidewalk_width>0:
			var edge=North._stroke(points,road.width+2*road.sidewalk_width)
			sidewalk.append_array(_clipped(edge,cuts+all_roads+previous_edges));previous_edges.append_array(edge)
			curbs.append_array(_clipped(North._stroke(points,road.width+.28),cuts+all_roads))
		var surface=North._stroke(points,road.width)
		var pieces=_clipped(surface,cuts+previous_roads);previous_roads.append_array(surface)
		if pieces.is_empty():continue
		if not surfaces.has(road.surface):surfaces[road.surface]=[]
		surfaces[road.surface].append_array(pieces)
		built.append({"id":road.id,"name":road.name,"width":road.width,"grade":road.grade,"surface":road.surface,"sidewalk_width":road.sidewalk_width})
	North._surface(c,sidewalk,.23,Surfaces.material(c,"pavers"),"MappedRoadSidewalks")
	North._solid(c,sidewalk,-.1,.23,"MappedSidewalkWalkable")
	North._surface(c,curbs,.242,c.mats.stone,"MappedMainRoadCurbs")
	for kind in surfaces:
		North._surface(c,surfaces[kind],ROAD_TOP,Surfaces.material(c,kind),"MappedRoad_"+kind)
		North._solid(c,surfaces[kind],-.1,ROAD_TOP,"MappedRoadWalkable_"+kind)
	c.world.set_meta("campus_roads",built)
	print("CAMPUS_ROADS_READY built=",built.size()," registered=",data().roads.size())

static func build_trees(c:Node3D):
	var planting=JSON.parse_string(FileAccess.get_file_as_string("res://data/campus_tree_planting.json"))
	var batches={}
	for tree in planting.trees:
		var key=tree.asset
		if not batches.has(key):batches[key]=[]
		batches[key].append(c.placement(tree.position[0],tree.position[1],tree.position[2],Vector3.ONE*tree.scale,tree.heading))
	for key in batches:c.multimesh(key,batches[key]);c.tree_count+=batches[key].size()
	c.world.set_meta("campus_tree_planting",{"count":planting.trees.size(),"species_assets":batches.keys()})
	print("CAMPUS_TREES_READY count=",planting.trees.size())
