extends RefCounted
const North=preload("res://scripts/north_axis_environment.gd")
const Geometry=preload("res://scripts/wave2_environment.gd")
const Network=preload("res://scripts/campus_network.gd")
const Surfaces=preload("res://scripts/road_surfaces.gd")
static var _data:Dictionary={}
static var _manifest:Dictionary={}
static func data()->Dictionary:
	if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/full_districts.json"))
	return _data
static func manifest()->Dictionary:
	if _manifest.is_empty():_manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/full_districts_manifest.json"))
	return _manifest
static func build(c:Node3D,s:Dictionary):
	Network.build_land(c,s)
	var d:Dictionary
	for district in data().districts:
		if district.id==s.id:d=district;break
	var m:Dictionary=manifest().districts[s.id];var asset_ids:Dictionary={}
	for asset in m.assets:
		asset_ids[asset]=true
		var model=load("res://assets/"+asset+".glb").instantiate();model.name=asset.to_pascal_case();c.world.add_child(model);c.style(model)
	for solid in manifest().collision_solids:
		var asset=String(solid.name).get_slice("_",0)+"_"+String(solid.name).get_slice("_",1)
		if asset_ids.has(asset):North._solid(c,[North.polygon(solid.polygon)],solid.bottom,solid.top,"MappedBuilding_"+solid.name)
	var cuts=[]
	for b in Network.data().buildings:cuts.append(North.polygon(b.outline))
	for pond in c.ponds:cuts.append(pond)
	var pieces_by_surface={};var region=[North.polygon(s.polygon)]
	for h in d.hardscape:
		var pieces=North._valid_surface([North.polygon(h.polygon)],region,cuts)
		if not pieces_by_surface.has(h.surface):pieces_by_surface[h.surface]=[]
		pieces_by_surface[h.surface].append_array(pieces)
	for b in m.buildings:
		if not b.has("approach_road") or b.style=="west_gate":continue
		var p=Vector2(b.front_approach[0],b.front_approach[2]);var q=Vector2(b.approach_road[0],b.approach_road[1])
		if not pieces_by_surface.has("concrete"):pieces_by_surface.concrete=[]
		pieces_by_surface.concrete.append_array(North._valid_surface(North._stroke(PackedVector2Array([q,p]),2.8),region,cuts))
	for surface in pieces_by_surface:
		North._surface(c,pieces_by_surface[surface],.105,Surfaces.material(c,surface),"MappedForecourt_"+s.id+"_"+surface)
		North._solid(c,pieces_by_surface[surface],-.1,.105,"MappedForecourtWalkable_"+s.id)
	var markings=[]
	for h in d.hardscape:
		if h.get("kind","")!="parking":continue
		var poly=North.polygon(h.polygon);var longest=0.0;var a=Vector2.ZERO;var b=Vector2.ZERO
		for i in range(poly.size()):
			if poly[i].distance_to(poly[(i+1)%poly.size()])>longest:
				a=poly[i];b=poly[(i+1)%poly.size()];longest=a.distance_to(b)
		var tangent=(b-a).normalized();var normal=Vector2(-tangent.y,tangent.x)
		if not Geometry2D.is_point_in_polygon((a+b)*.5+normal,poly):normal=-normal
		for k in range(1,int(longest/2.5)):
			var p=a+tangent*k*2.5+normal*.6;var q=p+normal*5
			markings.append_array(North._valid_surface(North._stroke(PackedVector2Array([p,q]),.08),[poly],cuts))
	North._surface(c,markings,.11,c.mats.stone,"MappedParkingLines_"+s.id)
	var batches={}
	for t in d.trees:
		if not batches.has(t.asset):batches[t.asset]=[]
		batches[t.asset].append(c.placement(t.position[0],0,t.position[2],Vector3.ONE*t.scale,t.heading))
	for asset in batches:c.multimesh(asset,batches[asset]);c.tree_count+=batches[asset].size()
	Geometry._furniture(c,{"polygon":s.polygon,"benches":d.benches,"lamps":d.lamps,"signs":[]})
	for b in m.buildings:
		if b.style in ["heritage","research_tower","research_glass","auditorium","student_activity"] and b.has("front_approach"):
			var p=b.front_approach;c.signpost(Vector3(p[0]+2,.12,p[2]),b.name,"USTC East Campus")
	c.world.set_meta(s.id,{"buildings":m.buildings.size(),"trees":d.trees.size(),"lamps":d.lamps.size(),"assets":m.assets.size(),"entries":d.walk_routes.size()})
	print("MAPPED_DISTRICT_READY ",s.id," buildings=",m.buildings.size()," trees=",d.trees.size())
