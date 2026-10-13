extends RefCounted
const Axis=preload("res://scripts/north_axis_environment.gd")

static func _distance_segments(p:Vector2,points:PackedVector2Array,closed=false)->float:
	var nearest=INF
	for i in range(points.size() if closed else points.size()-1):
		nearest=minf(nearest,p.distance_to(Geometry2D.get_closest_point_to_segment(p,points[i],points[(i+1)%points.size()])))
	return nearest

static func _bridge_clear(p:Vector2,d:Dictionary,margin:float)->bool:
	for bridge in d.bridges:
		if _distance_segments(p,Axis.polygon(bridge.points))<bridge.width*.5+margin:return false
	return true

static func build(c:Node3D):
	var d=Axis.layout();var rng=RandomNumberGenerator.new();rng.seed=19700521
	var lilies=[];var rocks=[];var used=[]
	# Small near-shore pockets follow the measured ponds; spring growth leaves most
	# open water clear. Their placement is inferred landscaping, never a new shoreline.
	for anchor in [Vector2(23,76),Vector2(26,113),Vector2(55,98),Vector2(-29,83),Vector2(-48,101)]:
		var count=0
		for i in range(100):
			var p=anchor+Vector2(rng.randf_range(-7,7),rng.randf_range(-7,7))
			if not Axis._inside_pond(p,d) or not _bridge_clear(p,d,3.2):continue
			var shore=INF
			for pond in d.ponds:shore=minf(shore,_distance_segments(p,Axis.polygon(pond.outer),true))
			if shore<1.0 or shore>4.8:continue
			var crowded=false
			for other in used:
				if p.distance_to(other)<1.65:crowded=true
			if crowded:continue
			used.append(p);var size=rng.randf_range(.83,1.15)
			lilies.append(c.placement(p.x,d.water_y,p.y,Vector3.ONE*size,rng.randf()*TAU));count+=1
			if count>=7:break
	# Low stone groups add an island edge without enclosing the pavilion entrances.
	for hole in d.ponds[1].holes:
		var island=Axis.polygon(hole);var platform=Axis.polygon(d.pavilion.polygon)
		for i in range(120):
			var p=Vector2(rng.randf_range(36.8,54.0),rng.randf_range(72.3,86.9))
			if not Geometry2D.is_point_in_polygon(p,island) or not _bridge_clear(p,d,1.1):continue
			if Geometry2D.is_point_in_polygon(p,platform) or _distance_segments(p,platform,true)<1.05:continue
			if _distance_segments(p,island,true)<.8:continue
			var crowded=false
			for other in rocks:
				if Vector2(other.origin.x,other.origin.z).distance_to(p)<2.1:crowded=true
			if crowded:continue
			var size=rng.randf_range(.58,.76);var angle=rng.randf()*TAU
			rocks.append(c.placement(p.x,0,p.y,Vector3.ONE*size,angle))
			var solid=c.static_box(Vector3(p.x,size*.42,p.y),Vector3(1.25,.92,.86)*size,"NorthIslandRock");solid.rotation.y=angle
			if rocks.size()>=4:break
	c.multimesh("north_lily",lilies);c.multimesh("north_rock",rocks)
	c.world.set_meta("north_lake_detail",{"lily_groups":lilies.size(),"island_rock_groups":rocks.size(),"source":"original Blender assets; art-directed near-shore pockets"})
