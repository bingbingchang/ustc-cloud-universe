extends RefCounted
const North=preload("res://scripts/north_axis_environment.gd")
const Geometry=preload("res://scripts/wave2_environment.gd")
const Network=preload("res://scripts/campus_network.gd")
const Surfaces=preload("res://scripts/road_surfaces.gd")
const Sports=preload("res://scripts/sports_district.gd")
static func data()->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string("res://data/south_sports.json"))
static func point(ct:Dictionary,x:float,z:float)->Vector2:
	return Vector2(ct.center[0]+x*cos(ct.heading)+z*sin(ct.heading),ct.center[1]-x*sin(ct.heading)+z*cos(ct.heading))
static func line(c:Node3D,ct:Dictionary,points:Array,mat:Material):
	var world_points=PackedVector2Array()
	for p in points:world_points.append(point(ct,p[0],p[1]))
	Sports.paint(c,world_points,mat,.075)
static func arc(c:Node3D,ct:Dictionary,x:float,z:float,r:float,a:float,b:float,mat:Material):
	var points=[]
	for k in range(65):points.append([x+r*cos(lerpf(a,b,k/64.0)),z+r*sin(lerpf(a,b,k/64.0))])
	line(c,ct,points,mat)

static func fence(c:Node3D,ct:Dictionary,a:Vector2,b:Vector2,mat:Material):
	var length=a.distance_to(b);var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vs=[Vector3(a.x,.12,a.y),Vector3(b.x,.12,b.y),Vector3(b.x,3.0,b.y),Vector3(a.x,3.0,a.y)]
	var uv=[Vector2(0,0),Vector2(length,0),Vector2(length,2.88),Vector2(0,2.88)]
	for i in [0,1,2,0,2,3]:st.set_uv(uv[i]);st.add_vertex(vs[i])
	st.generate_normals();var n=MeshInstance3D.new();n.name="TennisPerimeterFence";n.mesh=st.commit();n.material_override=mat;c.world.add_child(n)
	var mid=(a+b)*.5;var yaw=atan2(b.x-a.x,b.y-a.y)
	var body=c.static_box(Vector3(mid.x,1.52,mid.y),Vector3(.06,2.8,length),"TennisFence_"+ct.id);body.rotation.y=yaw
	var steel=Sports.sports_material(Color("325c47"))
	var top=c.box(Vector3(mid.x,3.01,mid.y),Vector3(.055,.055,length),steel);top.rotation.y=yaw
	var rail=c.box(Vector3(mid.x,1.6,mid.y),Vector3(.045,.045,length),steel);rail.rotation.y=yaw
	for k in range(int(ceil(length/3.0))+1):
		var p=a.lerp(b,minf(1,k*3.0/length));c.box(Vector3(p.x,1.56,p.y),Vector3(.065,2.95,.065),steel)

static func build(c:Node3D,s:Dictionary):
	Network.build_land(c,s);var d=data();var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/south_sports_manifest.json"))
	for asset in manifest.assets:
		var model=load("res://assets/"+asset+".glb").instantiate();model.name=asset.to_pascal_case();c.world.add_child(model);c.style(model)
	for solid in manifest.collision_solids:North._solid(c,[North.polygon(solid.polygon)],solid.bottom,solid.top,"SouthSports_"+solid.name)
	var cuts=[];var court_cuts=[]
	for b in d.buildings:cuts.append(North.polygon(b.outline))
	for ct in d.courts:court_cuts.append(North.polygon(ct.polygon))
	var white=Sports.sports_material(Color("dedfd4"));var green=Sports.sports_material(Color("496c52"));var blue=Sports.sports_material(Color("506580"));var red=Sports.sports_material(Color("99533e"))
	var fence_mat=ShaderMaterial.new();fence_mat.shader=preload("res://shaders/court_fence.gdshader")
	for ct in d.courts:
		var outer=North.polygon(ct.polygon);var inner=North.polygon(ct.court_polygon)
		North._surface(c,[outer],.10,red if ct.sport=="basketball" else green,"CourtRunoff_"+ct.id)
		North._solid(c,[outer],-.1,.10,"CourtWalkable_"+ct.id)
		North._surface(c,[inner],.112,green if ct.sport=="basketball" else blue,"CourtPlayingSurface_"+ct.id)
		var w:float=ct.width*.5;var l:float=ct.length*.5
		line(c,ct,[[-w,-l],[w,-l],[w,l],[-w,l],[-w,-l]],white)
		if ct.sport=="basketball":
			line(c,ct,[[-w,0],[w,0]],white);arc(c,ct,0,0,1.8,0,TAU,white)
			for side in [-1,1]:
				var z=side*l
				line(c,ct,[[-2.45,z],[-2.45,z-side*5.3],[2.45,z-side*5.3],[2.45,z]],white)
				arc(c,ct,0,z-side*5.3,1.8,0,TAU,white)
				arc(c,ct,0,z-side*1.15,6.05,PI if side>0 else 0,TAU if side>0 else PI,white)
		else:
			line(c,ct,[[-4.115,-l],[-4.115,l]],white);line(c,ct,[[4.115,-l],[4.115,l]],white)
			for side in [-1,1]:line(c,ct,[[-4.115,side*6.4],[4.115,side*6.4]],white)
			line(c,ct,[[0,-6.4],[0,6.4]],white)
			var post=point(ct,0,0);var body=c.static_box(Vector3(post.x,.65,post.y),Vector3(ct.width+1.8,1.06,.06),"TennisNet_"+ct.id);body.rotation.y=ct.heading
			# 3.2m openings at both ends give actual access to either half of the court.
			var fw=8.25;var fl=17.1
			fence(c,ct,point(ct,-fw,-fl),point(ct,-fw,fl),fence_mat);fence(c,ct,point(ct,fw,-fl),point(ct,fw,fl),fence_mat)
			for end in [-fl,fl]:
				fence(c,ct,point(ct,-fw,end),point(ct,-1.6,end),fence_mat);fence(c,ct,point(ct,1.6,end),point(ct,fw,end),fence_mat)
	for h in d.hardscape:
		var pieces=North._pieces(North.polygon(h.polygon),cuts+court_cuts)
		North._surface(c,pieces,.105,Surfaces.material(c,h.surface),"SouthHardscape_"+h.id);North._solid(c,pieces,-.1,.105,"SouthForecourt_"+h.id)
	for b in manifest.buildings:
		var p=Vector2(b.front_approach[0],b.front_approach[2]);var nearest=Vector2.ZERO;var best=INF
		for road in Network.data().roads:
			if not road.get("build_enabled",true):continue
			var ps=North.polygon(road.points)
			for i in range(ps.size()-1):
				var q=Geometry2D.get_closest_point_to_segment(p,ps[i],ps[i+1])
				if p.distance_to(q)<best:nearest=q;best=p.distance_to(q)
		var pieces=North._valid_surface(North._stroke(PackedVector2Array([nearest,p]),2.8),[North.polygon(s.polygon)],cuts+court_cuts)
		North._surface(c,pieces,.108,Surfaces.material(c,"concrete"),"SouthEntryApproach");North._solid(c,pieces,-.1,.108,"SouthEntryPath")
	var batches={}
	for t in d.trees:
		if not batches.has(t.asset):batches[t.asset]=[]
		batches[t.asset].append(c.placement(t.position[0],0,t.position[2],Vector3.ONE*t.scale,t.heading))
	for asset in batches:c.multimesh(asset,batches[asset]);c.tree_count+=batches[asset].size()
	Geometry._furniture(c,{"polygon":s.polygon,"benches":d.benches,"lamps":d.lamps,"signs":[]})
	c.signpost(Vector3(-269,.12,584),"篮球场 · 网球场 · 364／365公寓","Courts · Graduate dormitories")
	c.world.set_meta("south_sports",{"buildings":d.buildings.size(),"trees":d.trees.size(),"courts":d.courts.size(),"module":s.id})
	print("SOUTH_SPORTS_READY buildings=",d.buildings.size()," courts=",d.courts.size()," trees=",d.trees.size())
