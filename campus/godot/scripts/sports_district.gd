extends RefCounted
const North=preload("res://scripts/north_axis_environment.gd")
const Geometry=preload("res://scripts/wave2_environment.gd")
const Network=preload("res://scripts/campus_network.gd")
const Surfaces=preload("res://scripts/road_surfaces.gd")
static func data()->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string("res://data/sports_district.json"))

static func sports_material(color:Color,turf:bool=false)->ShaderMaterial:
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/sports_surface.gdshader")
	mat.set_shader_parameter("base_color",color);mat.set_shader_parameter("turf",turf);return mat

static func oval(t:Dictionary,radius:float)->PackedVector2Array:
	var p=PackedVector2Array();var center=Vector2(t.center[0],t.center[1])
	for k in range(65):
		var a=PI*k/64;p.append(center+Vector2(radius*cos(a),t.straight_half_length+radius*sin(a)))
	for k in range(65):
		var a=PI+PI*k/64;p.append(center+Vector2(radius*cos(a),-t.straight_half_length+radius*sin(a)))
	p.append(p[0]);return p

static func paint(c:Node3D,points:PackedVector2Array,mat:Material,width:float=.09):
	# Closed offset polylines return inner contours; filling those covers the field.
	# Paint each short segment as a strip, then combine the strips in one mesh.
	var strips=[]
	for i in range(points.size()-1):strips.append_array(North._stroke(PackedVector2Array([points[i],points[i+1]]),width))
	North._surface(c,strips,.119,mat,"SportsPaint")

static func build(c:Node3D,s:Dictionary):
	Network.build_land(c,s)
	var d=data();var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/sports_district_manifest.json"))
	for asset in manifest.assets:
		var model=load("res://assets/"+asset+".glb").instantiate();model.name=asset.to_pascal_case();c.world.add_child(model);c.style(model)
	for solid in manifest.collision_solids:North._solid(c,[North.polygon(solid.polygon)],solid.bottom,solid.top,"SportsDistrict_"+solid.name)
	var track=North.polygon(d.track.outer_polygon)
	North._surface(c,[track],.10,sports_material(Color("a55240")),"AthleticRedTrack")
	North._solid(c,[track],-.1,.10,"AthleticTrackWalkable")
	North._surface(c,[North.polygon(d.soccer_outline)],.112,sports_material(Color("487952"),true),"FootballTurf")
	var white=sports_material(Color("dfddd0"))
	# Lane markings follow the whole measured oval, including both straightaways.
	for k in range(d.track.lanes+1):paint(c,oval(d.track,d.track.outer_radius-k*d.track.lane_width),white,.075)
	var cx:float=d.track.center[0];var cz:float=d.track.center[1];var x0=cx-34;var x1=cx+34;var z0=cz-52.5;var z1=cz+52.5
	paint(c,North.polygon([[x0,z0],[x1,z0],[x1,z1],[x0,z1],[x0,z0]]),white)
	paint(c,North.polygon([[x0,cz],[x1,cz]]),white)
	var circle=PackedVector2Array()
	for k in range(97):circle.append(Vector2(cx+9.15*cos(TAU*k/96),cz+9.15*sin(TAU*k/96)))
	paint(c,circle,white)
	for end in [-1,1]:
		var z=cz+end*52.5
		paint(c,North.polygon([[cx-20.16,z],[cx-20.16,z-end*16.5],[cx+20.16,z-end*16.5],[cx+20.16,z]]),white)
		paint(c,North.polygon([[cx-9.16,z],[cx-9.16,z-end*5.5],[cx+9.16,z-end*5.5],[cx+9.16,z]]),white)
		var dot=North._rect(cx-.10,z-end*11-.10,.20,.20);North._surface(c,[dot],.119,white,"PenaltySpot")
		var arc=PackedVector2Array()
		for k in range(49):
			var a=.64+(PI-1.28)*k/48;arc.append(Vector2(cx+9.15*cos(a),z-end*(11+9.15*sin(a))))
		paint(c,arc,white)
	# Finish line, staggers and unobtrusive lane numerals on the eastern straight.
	var finish_z=cz+25.0
	paint(c,North.polygon([[cx+d.track.outer_radius-d.track.lanes*d.track.lane_width,finish_z],[cx+d.track.outer_radius,finish_z]]),white,.12)
	for k in range(d.track.lanes):
		var x=cx+d.track.outer_radius-(k+.5)*d.track.lane_width
		var text=Label3D.new();text.text=str(d.track.lanes-k);text.font_size=64;text.pixel_size=.009
		text.modulate=Color("eee8d6");text.outline_size=0;text.no_depth_test=false;text.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		text.rotation_degrees.x=-90;text.position=Vector3(x,.13,finish_z+1.4);c.world.add_child(text)
		paint(c,North.polygon([[x-.47,cz-16+k*.7],[x+.47,cz-16+k*.7]]),white,.10)
	var cuts=[]
	for b in d.buildings:cuts.append(North.polygon(b.outline))
	for h in d.hardscape:
		var pieces=North._pieces(North.polygon(h.polygon),cuts+[track])
		North._surface(c,pieces,.105,Surfaces.material(c,h.surface),"SportsHardscape_"+h.id)
		North._solid(c,pieces,-.1,.105,"SportsForecourt_"+h.id)
	for b in manifest.buildings:
		var p=Vector2(b.front_approach[0],b.front_approach[2]);var nearest=Vector2.ZERO;var best=INF
		for road in Network.data().roads:
			if not road.get("build_enabled",true):continue
			var points=North.polygon(road.points)
			for i in range(points.size()-1):
				var q=Geometry2D.get_closest_point_to_segment(p,points[i],points[i+1])
				if p.distance_to(q)<best:nearest=q;best=p.distance_to(q)
		var pieces=North._valid_surface(North._stroke(PackedVector2Array([nearest,p]),3.0),[North.polygon(s.polygon)],cuts+[track])
		North._surface(c,pieces,.108,Surfaces.material(c,"concrete"),"SportsEntryApproach")
		North._solid(c,pieces,-.1,.108,"SportsEntryPath")
	var batches={}
	for t in d.trees:
		if not batches.has(t.asset):batches[t.asset]=[]
		batches[t.asset].append(c.placement(t.position[0],0,t.position[2],Vector3.ONE*t.scale,t.heading))
	for asset in batches:c.multimesh(asset,batches[asset]);c.tree_count+=batches[asset].size()
	Geometry._furniture(c,{"polygon":s.polygon,"benches":d.benches,"lamps":d.lamps,"signs":[]})
	c.signpost(Vector3(-166,.12,386),"东区田径场 · 学生公寓320—323","Athletic field · Dormitories")
	c.world.set_meta("sports_district",{"buildings":d.buildings.size(),"trees":d.trees.size(),"lanes":d.track.lanes,"hardscape_zones":d.hardscape.size(),"module":s.id})
	print("SPORTS_DISTRICT_READY buildings=",d.buildings.size()," trees=",d.trees.size()," lanes=",d.track.lanes)
