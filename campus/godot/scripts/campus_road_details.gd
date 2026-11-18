extends RefCounted

const North=preload("res://scripts/north_axis_environment.gd")
const Detail=preload("res://scripts/north_axis_photo_details.gd")
const Surfaces=preload("res://scripts/road_surfaces.gd")

static func build(c:Node3D)->void:
	var red_walk:=Detail.matte(Color(.31,.12,.089))
	red_walk.cull_mode=BaseMaterial3D.CULL_DISABLED
	var warm_stone:=Surfaces.material(c,"pavers")
	# GIS 88–89 and 99–100 show a gently raised red edge and narrow drain beside
	# the lane. Only the traced shared segments receive this finish.
	_edge(c,PackedVector2Array([Vector2(18.5,146.61),Vector2(40,146.58),Vector2(58,146.45),Vector2(69.4,146.42)]),.74,.109,red_walk,"HanhaiRedPedestrianEdge")
	_edge(c,PackedVector2Array([Vector2(84.7,228.93),Vector2(111.0,227.91),Vector2(139.4,227.04)]),.63,.158,red_walk,"QinfengRedPedestrianEdge")
	_edge(c,PackedVector2Array([Vector2(-76.1,232.8),Vector2(-75.5,247.0),Vector2(-75.4,262.7),Vector2(-75.2,277.7)]),.45,.151,red_walk,"GuoRoadRedShoulder")
	_edge(c,PackedVector2Array([Vector2(-74.18,166.0),Vector2(-74.18,193.15),Vector2(-74.38,219.0)]),.28,.153,warm_stone,"TeachingWestPavedKerb")
	var white:=Detail.matte(Color(.65,.65,.57))
	white.cull_mode=BaseMaterial3D.CULL_DISABLED
	var crossings=[]
	for i in range(7):
		crossings.append(North._rect(-81.0+i*.81,285.50,.40,2.85))
	for i in range(6):
		crossings.append(North._rect(54.8,148.0+i*.82,2.52,.40))
	North._surface(c,crossings,.145,white,"MappedCampusPedestrianMarkings")

static func _edge(c:Node3D,line:PackedVector2Array,width:float,y:float,mat:Material,label:String)->void:
	var parts:=North._stroke(line,width)
	North._surface(c,parts,y,mat,label)
	North._solid(c,parts,-.02,y,label+"Walk")
