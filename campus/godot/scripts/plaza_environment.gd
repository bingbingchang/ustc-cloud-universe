extends RefCounted
const Geometry=preload("res://scripts/wave2_environment.gd")
const North=preload("res://scripts/north_axis_environment.gd")

static func enabled()->bool:
	if "--plaza-before" in OS.get_cmdline_user_args():return false
	for s in JSON.parse_string(FileAccess.get_file_as_string("res://data/module_layout.json")).modules:
		if s.id=="guo_plaza_03":return s.enabled
	return false

static func spec()->Dictionary:
	for s in JSON.parse_string(FileAccess.get_file_as_string("res://data/module_layout.json")).modules:
		if s.id=="guo_plaza_03":return s
	return {}

static func _rect(x:float,z:float,w:float,h:float)->PackedVector2Array:
	return North._rect(x,z,w,h)

static func _patch(c:Node3D,parts:Array,shape:PackedVector2Array,y:float,mat:Material,solid:bool=false):
	var pieces=[]
	for part in parts:pieces.append_array(Geometry2D.intersect_polygons(shape,part))
	North._surface(c,pieces,y,mat,"PlazaPaving")
	if solid:North._solid(c,pieces,-.1,y,"PlazaWalkablePaving")

static func build(c:Node3D,s:Dictionary):
	var outline=Geometry.polygon(s.polygon)
	var exclusions=[Geometry.polygon(s.basin),Geometry.polygon(s.cafe.polygon)]
	var existing=[North._core(),North.polygon(North.layout().polygon)]
	for other in JSON.parse_string(FileAccess.get_file_as_string("res://data/module_layout.json")).modules:
		if other.id==s.id:break
		if other.enabled and other.has("polygon"):existing.append(Geometry.polygon(other.polygon))
	var land=North._pieces(outline,exclusions+existing)
	North._surface(c,land,0,c.mats.grass,"PlazaContinuousLand")
	North._solid(c,land,-.75,0,"PlazaWalkableLand")
	var usable=North._pieces(outline,exclusions)
	var stone=c.asset_material("PlazaWarmStone",Color("d4cbb9"))
	c.surface(stone,"paving",Vector2(3.2,3.2))
	var edging=c.asset_material("PlazaBrickJoint",Color("8f6d5c"))
	var paths=[]
	for path in s.paths:
		var points=Geometry.polygon(path.points)
		Geometry._stroke_patch(c,points,path.width+.28,.035,c.mats.stone,false,land)
		Geometry._stroke_patch(c,points,path.width,.08,stone,true,land)
		paths.append([points,path.width])
	# The central paving follows the photo's long basin and paired side passages.
	_patch(c,usable,_rect(-10.8,238,20.55,16.7),.08,stone,true)
	_patch(c,usable,_rect(-8.52,254.7,15.79,51.6),.08,stone,true)
	_patch(c,usable,_rect(-12.6,306.3,23.8,27.4),.08,stone,true)
	_patch(c,usable,_rect(-58,253,27,9.5),.08,stone,true)
	# The statue faces south; its planting bed sits between its back and Qinfeng Road.
	_patch(c,usable,_rect(-4.8,237.6,8.8,3.1),.092,c.mats.grass)
	var joints=[]
	for z in range(250,335,4):
		for x in [-8.45,1.80]:joints.append(Geometry._box_transform(Vector3(x+2.8,.081,z),Vector3(5.6,.003,.06),0))
	Geometry._box_batch(c,joints,edging,"PlazaPavingJoints")
	var basin=Geometry.polygon(s.basin)
	North._surface(c,[basin],-.05,c.mats.water,"PlazaBasinWater")
	North._solid(c,[basin],-.55,1.65,"PlazaNoEntryBasin")
	var coping=[]
	for i in basin.size():
		var a=basin[i];var b=basin[(i+1)%basin.size()];var mid=(a+b)*.5
		coping.append(Geometry._box_transform(Vector3(mid.x,.045,mid.y),Vector3(.18,.10,a.distance_to(b)),atan2(b.x-a.x,b.y-a.y)))
	Geometry._box_batch(c,coping,c.mats.stone,"PlazaBasinCoping")
	_landmarks(c,s)
	_planting(c,s,paths)
	Geometry._furniture(c,s)
	Geometry._boundaries(c,s,outline)
	_backdrop(c,s.backdrop)
	c.world.set_meta("guo_plaza",{"module":s.id,"mapped_basin":true,"cafe":"268207470","monument":"3026612881","trees":s.trees.size(),"new_npcs":0,"bounds":s.bounds,"playable":true})
	print("PLAZA_READY trees=",s.trees.size()," bounds=",s.bounds)

static func _landmarks(c:Node3D,s:Dictionary):
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/plaza_landmarks_manifest.json"))
	for item in [["plaza_cafe",s.cafe,"Cafe"],["plaza_guo_monument",s.monument,"Monument"]]:
		var cfg=item[1]
		var model=load("res://assets/"+item[0]+".glb").instantiate()
		model.name=item[0].to_pascal_case();c.world.add_child(model)
		model.position=Vector3(cfg.position[0],cfg.position[1],cfg.position[2]);model.rotation.y=cfg.heading
		if item[0]=="plaza_cafe":c.style(model)
		for solid in data.assets[item[2]].collision_suggestion:
			var p=Vector3(solid.center[0],solid.center[1],solid.center[2])
			if solid.type=="box":
				var size=Vector3(solid.size[0],solid.size[1],solid.size[2])
				var body=c.static_box(model.to_global(p),size,item[0]+"_Contact");body.rotation.y=cfg.heading
			else:
				var body=StaticBody3D.new();body.name="PlazaMonumentFigureContact";body.position=model.to_global(p);c.world.add_child(body)
				var collider=CollisionShape3D.new();var shape=CylinderShape3D.new();shape.radius=solid.radius;shape.height=solid.height;collider.shape=shape;body.add_child(collider)
		if item[0]=="plaza_cafe":
			for p in [Vector3(-5.3,.65,-5.9),Vector3(.1,.65,-5.85),Vector3(5.3,.65,-5.9)]:
				var body=StaticBody3D.new();body.name="PlazaCafeTableContact";body.position=model.to_global(p);c.world.add_child(body)
				var collider=CollisionShape3D.new();var shape=CylinderShape3D.new();shape.radius=.43;shape.height=1.1;collider.shape=shape;body.add_child(collider)
	c.signpost(Vector3(41,.08,238.8),"郭沫若广场","Guo Moruo Plaza")
	c.static_box(Vector3(41,.88,238.8),Vector3(.12,1.6,.12),"PlazaSignPole")
	c.static_box(Vector3(41,1.54,238.8),Vector3(2.2,.78,.14),"PlazaSignBoard")

static func _planting(c:Node3D,s:Dictionary,paths:Array):
	# The mapped planting layer now supplies the plaza's mature tree species.
	var shrubs=[];var grass=[];var flowers=[[],[]]
	var rng=RandomNumberGenerator.new();rng.seed=1958244
	for anchor in [Vector2(-43,277),Vector2(-43,303),Vector2(43,285),Vector2(46,308),Vector2(-28,328),Vector2(25,327)]:
		for i in range(8):
			var p=anchor+Vector2(rng.randf_range(-4.0,4.0),rng.randf_range(-3,3))
			var clear=true
			for path in paths:
				for j in range(path[0].size()-1):
					if p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[0][j],path[0][j+1]))<path[1]*.5+1.0:clear=false
			if not clear:continue
			shrubs.append(c.placement(p.x,0,p.y,Vector3.ONE*rng.randf_range(.70,1.15),rng.randf()*TAU))
			if i%2==0:flowers[(i/2)%2].append(c.placement(p.x,.015,p.y,Vector3.ONE*.75,rng.randf()*TAU))
			grass.append(c.placement(p.x+.6,.012,p.y-.5,Vector3.ONE*.65,rng.randf()*TAU))
	for x in [-3.8,-2.3,-.8,.7,2.2,3.2]:shrubs.append(c.placement(x,.092,238.6,Vector3.ONE*.72,x))
	c.multimesh("shrub",shrubs);c.multimesh("grass",grass)
	for i in flowers.size():c.multimesh("study_flower_mound_"+str(i),flowers[i])
	# Trimmed paired planting frames the photo's central axis without blocking it.
	var hedges=[]
	for x in [-19,18]:
		for z in [262,282,302]:
			hedges.append(Geometry._box_transform(Vector3(x,.34,z),Vector3(7,.62,1.5),0))
	Geometry._box_batch(c,hedges,c.asset_material("PlazaHedge",Color("73834a")),"PlazaLowHedges")

static func _backdrop(c:Node3D,s:Dictionary):
	for m in JSON.parse_string(FileAccess.get_file_as_string("res://data/module_layout.json")).modules:
		if m.id=="library_district_06" and m.enabled:return
	# Mapped next building is context only; its ground is outside this playable module.
	var brick=c.asset_material("Brick",Color("b46e51"));var cream=c.asset_material("PlazaFacadeStone",Color("c9c6b5"))
	var glass=c.asset_material("PlazaBackdropGlass",Color("526566"))
	var poly=Geometry.polygon(s.polygon)
	North._surface(c,[poly],14,cream,"PlazaSouthBackdropRoof")
	var walls=[];var windows=[];var belts=[]
	for i in poly.size():
		var a=poly[i];var b=poly[(i+1)%poly.size()];var mid=(a+b)*.5;var angle=atan2(b.x-a.x,b.y-a.y);var length=a.distance_to(b)
		walls.append(Geometry._box_transform(Vector3(mid.x,7,mid.y),Vector3(.42,14,length),angle))
		for y in [3.0,6.2,9.4,12.5]:
			for j in range(maxi(1,int(length/3.3))):
				var q=a.lerp(b,(j+.5)/maxi(1,int(length/3.3)))
				windows.append(Geometry._box_transform(Vector3(q.x,y,q.y),Vector3(.52,1.8,1.5),angle))
		for y in [4.5,10.8]:belts.append(Geometry._box_transform(Vector3(mid.x,y,mid.y),Vector3(.55,.45,length),angle))
	Geometry._box_batch(c,walls,brick,"PlazaSouthBackdropWalls")
	Geometry._box_batch(c,windows,glass,"PlazaSouthBackdropWindows")
	Geometry._box_batch(c,belts,cream,"PlazaSouthBackdropBands")
