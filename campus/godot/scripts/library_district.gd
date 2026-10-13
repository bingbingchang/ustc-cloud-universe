extends RefCounted
const North=preload("res://scripts/north_axis_environment.gd")
const Geometry=preload("res://scripts/wave2_environment.gd")
const Network=preload("res://scripts/campus_network.gd")
const Surfaces=preload("res://scripts/road_surfaces.gd")
static func data()->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string("res://data/library_district.json"))
static func build(c:Node3D,s:Dictionary):
	Network.build_land(c,s)
	var d=data();var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/library_district_manifest.json"))
	for asset in manifest.assets:
		var model=load("res://assets/"+asset+".glb").instantiate();model.name=asset.to_pascal_case();c.world.add_child(model);c.style(model)
	for solid in manifest.collision_solids:North._solid(c,[North.polygon(solid.polygon)],solid.bottom,solid.top,"LibraryDistrict_"+solid.name)
	var cuts=[]
	for b in d.buildings:cuts.append(North.polygon(b.outline))
	for zone in d.hardscape:
		var pieces=North._pieces(North.polygon(zone.polygon),cuts)
		North._surface(c,pieces,.10,Surfaces.material(c,zone.surface),"LibraryHardscape_"+zone.id)
		North._solid(c,pieces,-.1,.10,"LibraryForecourt_"+zone.id)
	# The photo's entrance geometry gets a paved approach to the mapped street.
	for b in manifest.buildings:
		var p=Vector2(b.front_approach[0],b.front_approach[2]);var nearest=Vector2.ZERO;var best=INF
		for road in Network.data().roads:
			if road.get("build_enabled",true)==false:continue
			var points=North.polygon(road.points)
			for i in range(points.size()-1):
				var q=Geometry2D.get_closest_point_to_segment(p,points[i],points[i+1])
				if p.distance_to(q)<best:nearest=q;best=p.distance_to(q)
		var pieces=North._valid_surface(North._stroke(PackedVector2Array([nearest,p]),3.2),[North.polygon(s.polygon)],cuts)
		North._surface(c,pieces,.105,Surfaces.material(c,"pavers"),"LibraryEntryApproach")
		North._solid(c,pieces,-.1,.105,"LibraryEntryPath")
	var batches={}
	for t in d.trees:
		if not batches.has(t.asset):batches[t.asset]=[]
		batches[t.asset].append(c.placement(t.position[0],0,t.position[2],Vector3.ONE*t.scale,t.heading))
	for asset in batches:c.multimesh(asset,batches[asset]);c.tree_count+=batches[asset].size()
	Geometry._furniture(c,{"polygon":s.polygon,"benches":[[-35,352,0],[37,352,0],[89,371,1.57],[-31,434,0]],
		"lamps":[[-.34,344,0],[-26,353,0],[25,353,0],[68,373,0],[68,425,0],[-68,425,0],[185,377,0]],"signs":[]})
	c.signpost(Vector3(62,.14,438),"图书馆 · 二教 · 学生食堂","Library · Teaching 2")
	c.world.set_meta("library_district",{"buildings":d.buildings.size(),"trees":d.trees.size(),"hardscape_zones":d.hardscape.size(),"module":s.id})
	print("LIBRARY_DISTRICT_READY buildings=",d.buildings.size()," trees=",d.trees.size())
