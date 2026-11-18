extends RefCounted

const North=preload("res://scripts/north_axis_environment.gd")
const Geometry=preload("res://scripts/wave2_environment.gd")
const Detail=preload("res://scripts/north_axis_photo_details.gd")

static func kindergarten(c:Node3D)->void:
	# GIS panorama 108 and OSM gate 10582890745. Sign wall is off the mapped through lane.
	var stone:=Detail.matte(Color(.52,.51,.45))
	var blue:=Detail.matte(Color(.087,.278,.523))
	var pink:=Detail.matte(Color(.54,.145,.257))
	var paving:=North._rect(361.0,262.36,6.10,6.07)
	North._surface(c,[paving],.116,preload("res://scripts/road_surfaces.gd").material(c,"pavers"),"KindergartenPavedThreshold")
	North._solid(c,[paving],-.10,.116,"KindergartenNearWalkway")
	var panels=[]
	for i in range(7):
		var z:=258.50+i*.67
		panels.append(Geometry._box_transform(Vector3(366.9,.88,z),Vector3(.25,1.71,.668),0))
	Geometry._box_batch(c,panels,stone,"KindergartenStoneSignWall")
	c.static_box(Vector3(366.9,.89,260.52),Vector3(.22,1.77,4.69),"KindergartenWallContact")
	c.box(Vector3(366.92,1.76,260.52),Vector3(.33,.17,4.76),blue)
	for item in [[Vector3(366.10,1.46,263.32),Vector3(.31,2.83,.28)],
			[Vector3(366.10,1.49,268.31),Vector3(.31,2.88,.28)],
			[Vector3(366.10,2.91,265.82),Vector3(.37,.15,5.27)]]:
		c.box(item[0],item[1],blue)
		c.static_box(item[0],item[1],"KindergartenOpenGateFrame")
	Detail.fixed_sign(c,"中国科大幼儿园",Vector3(366.736,1.26,260.43),.013,Color("22477d"),-PI*.5)
	for z in [259.2,260.45,261.7]:
		c.box(Vector3(366.735,.83,z),Vector3(.07,.067,.84),pink)

static func ruzi_ox(c:Node3D)->void:
	if not ResourceLoader.exists("res://assets/ruzi_ox.glb"):return
	var resource:=load("res://assets/ruzi_ox.glb") as PackedScene
	if not resource:return
	var sculpture:=resource.instantiate() as Node3D
	sculpture.name="RuziOxAndGlobe"
	sculpture.position=Vector3(-12.791,0,571.797)
	c.world.add_child(sculpture)
	c.style(sculpture)
	c.static_box(sculpture.position+Vector3(0,.478,0),Vector3(5.04,.957,3.22),"RuziOxPedestal")
	c.static_box(sculpture.position+Vector3(.10,1.62,-.05),Vector3(3.95,1.37,1.84),"RuziOxCarvingContact")
	var shrubs=[]
	for i in range(11):
		var x:float=sculpture.position.x-3.2+i*.64
		shrubs.append(c.placement(x,0,sculpture.position.z-2.4,Vector3.ONE*.53,1.7*i))
	c.multimesh("shrub",shrubs)
