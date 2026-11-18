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

static func build_waterfront(c:Node3D,id:String) -> void:
	for district in data().districts:
		if district.id!=id or not district.has("waterfront"):continue
		var waterfront:Dictionary=district.waterfront
		var pond:=North.polygon(waterfront.shore)
		c.ponds.append(pond)
		var clearances=[]
		for solid in manifest().collision_solids:
			if solid.name=="mapped_267646980_promenade":
				clearances.append(North.polygon(solid.polygon))
				break
		if clearances.is_empty():
			c.ponds.pop_back()
			return
		var water := North._surface(c,[pond],-.14,c.mats.water,"MappedReportHallPond")
		water.set_meta("lake_water",true)
		var barrier := North._solid(c,North._pieces(pond,clearances),-.69,1.64,"ReportHallWaterBarrier")
		barrier.set_meta("water_entry_barrier",true)
		var coping=[]
		var posts=[]
		var chains=[]
		for i in pond.size():
			var a:=pond[i]
			var b:=pond[(i+1)%pond.size()]
			var middle:=(a+b)*.5
			if middle.x<120.0 and middle.y>252.0 and middle.y<282.1:continue
			var angle:=atan2(b.x-a.x,b.y-a.y)
			coping.append(Geometry._box_transform(Vector3(middle.x,-.095,middle.y),Vector3(.42,.30,a.distance_to(b)+.04),angle))
			var count:=maxi(1,roundi(a.distance_to(b)/2.1))
			var previous := Vector3.ZERO
			for step in count:
				var p:=a.lerp(b,(step+.5)/count)
				var anchor := Vector3(p.x,.47,p.y)
				posts.append(Geometry._box_transform(anchor-Vector3.UP*.18,Vector3(.19,.50,.19),angle))
				if step > 0:
					var last := previous
					for link in range(1,7):
						var fraction := link/6.0
						var next := previous.lerp(anchor,fraction)-Vector3.UP*.44*fraction*(1.0-fraction)
						var chord := (next-last).length()
						var basis := Basis.looking_at(next-last)*Basis.from_scale(Vector3(.043,.043,chord+.018))
						chains.append(Transform3D(basis,(last+next)*.5))
						last=next
				previous=anchor
		Geometry._box_batch(c,coping,c.mats.stone,"ReportHallGraniteCoping")
		Geometry._box_batch(c,posts,c.mats.stone,"ReportHallShoreBollards")
		if OS.has_feature("windows"):
			var metal := StandardMaterial3D.new()
			metal.albedo_color=Color("65665e")
			metal.metallic=.56
			Geometry._box_batch(c,chains,metal,"ReportHallBollardChains")

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
		if not asset_ids.has(asset):continue
		var polygon:=North.polygon(solid.polygon)
		var label:String="MappedBuilding_"+solid.name
		if solid.type=="sloped_prism":
			North._sloped_solid(c,polygon,solid.bottom,solid.top_heights,label)
		else:
			North._solid(c,[polygon],solid.bottom,solid.top,label)
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
	if OS.has_feature("windows") and s.id=="east_living_10":
		preload("res://scripts/east_living_photo_details.gd").kindergarten(c)
	if OS.has_feature("windows") and s.id=="central_life_11":
		preload("res://scripts/east_living_photo_details.gd").ruzi_ox(c)
	for b in m.buildings:
		if b.style in ["heritage","research_tower","research_glass","auditorium","student_activity"] and b.has("front_approach"):
			if b.get("exterior_sign",false):continue
			var p=b.front_approach;c.signpost(Vector3(p[0]+2,.12,p[2]),b.name,"USTC East Campus")
	c.world.set_meta(s.id,{"buildings":m.buildings.size(),"trees":d.trees.size(),"lamps":d.lamps.size(),"assets":m.assets.size(),"entries":d.walk_routes.size()})
	print("MAPPED_DISTRICT_READY ",s.id," buildings=",m.buildings.size()," trees=",d.trees.size())
