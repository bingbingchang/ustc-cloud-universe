extends RefCounted
const North=preload("res://scripts/north_axis_environment.gd")
const Lake=preload("res://scripts/lake_garden.gd")
static func safe_land(p:Vector2,r:float)->bool:
	if p.x< -76+r or p.x> -9-r or p.y<73+r or p.y>147-r:return false
	for offset in [Vector2.ZERO,Vector2(r,0),Vector2(-r,0),Vector2(0,r),Vector2(0,-r)]:
		var q=p+offset
		if not (North.contains(q) or Geometry2D.is_point_in_polygon(q,North._core())) or North._inside_pond(q,North.layout()):return false
	if North._distance_paths(North.layout(),p)<r+.65:return false
	for b in North.layout().benches:
		if p.distance_to(Vector2(b[0],b[1]))<r+2:return false
	for l in North.layout().lamps:
		if p.distance_to(Vector2(l[0],l[1]))<r+.6:return false
	return true

static func safe_water(p:Vector2,r:float)->bool:
	var pond=North.layout().ponds[0];var outer=North.polygon(pond.outer)
	if not Geometry2D.is_point_in_polygon(p,outer) or Lake.edge_distance(p,outer)<r:return false
	for hole in pond.holes:
		var poly=North.polygon(hole)
		if Geometry2D.is_point_in_polygon(p,poly) or Lake.edge_distance(p,poly)<r:return false
	for bridge in North.layout().bridges:
		if Lake.edge_distance(p,North.polygon(bridge.points))<r+bridge.width*.5+.4:return false
	return true

static func build(c:Node3D):
	var rng=RandomNumberGenerator.new();rng.seed=20260919
	var before=c.tree_count
	for p in [Vector2(-65,106),Vector2(-62,126),Vector2(-49,138),Vector2(-25,135),Vector2(-14,98)]:
		var scale=rng.randf_range(.65,1.0)
		c.place_tree("lake_willow_0" if p.x< -60 else "study_canopy_1",p,1.2 if p.x< -60 else scale)
	var flowers=[[],[]];var pads=[[],[],[],[]];var stones=[];var used=[]
	for anchor in [Vector2(-65,104),Vector2(-64,119),Vector2(-58,134),Vector2(-43,137),Vector2(-29,136),Vector2(-14,113)]:
		for j in range(16):
			var a=rng.randf()*TAU;var p=anchor+Vector2(cos(a),sin(a))*sqrt(rng.randf())*3.8
			if not safe_land(p,1.0):continue
			var close=false
			for q in used:
				if p.distance_to(q)<1.5:close=true;break
			if close:continue
			used.append(p);flowers[1 if j%4==0 else 0].append(c.placement(p.x,0,p.y,Vector3.ONE*rng.randf_range(.6,.95),rng.randf()*TAU))
	for island in [[Vector2(-54,94),Vector2(4,6)],[Vector2(-52,119),Vector2(5,6)],[Vector2(-31,123),Vector2(5,3)],[Vector2(-28,82),Vector2(3,4)]]:
		for j in range(38):
			var a=rng.randf()*TAU;var r=sqrt(rng.randf());var p=island[0]+Vector2(cos(a)*island[1].x,sin(a)*island[1].y)*r
			if not safe_water(p,1.05):continue
			var k=3 if j%8==0 else j%3;pads[k].append(c.placement(p.x,-.04,p.y,Vector3.ONE*rng.randf_range(.65,.95),rng.randf()*TAU))
	for p in [Vector2(-54,100),Vector2(-46,125),Vector2(-25,86)]:
		if safe_water(p,1.9):stones.append(c.placement(p.x,-.32,p.y,Vector3.ONE*.72,rng.randf()*TAU))
	for i in range(2):c.multimesh_batch("study_flower_mound_"+str(i),flowers[i])
	for i in range(4):c.multimesh_batch("study_lotus_"+str(i),pads[i])
	c.multimesh_batch("study_rock_garden_0",stones)
	c.world.set_meta("lookdev_tree_contacts",c.lookdev_tree_contacts)
	var pad_count=0
	for group in pads:pad_count+=group.size()
	c.study_stats["west_lake"]={"trees":c.tree_count-before,"flower_groups":used.size(),"lotus_groups":pad_count,"stone_groups":stones.size(),"new_land":false}
