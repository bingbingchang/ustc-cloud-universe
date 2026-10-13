extends RefCounted
const North=preload("res://scripts/north_axis_environment.gd")
static func config()->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string("res://data/west_grove.json"))
static func safe(p:Vector2,r:float)->bool:
	var d=config();var b=d.bounds
	if p.x<b[0]+r or p.x>b[2]-r or p.y<b[1]+r or p.y>b[3]-r:return false
	for q in [p,p+Vector2(r,0),p-Vector2(r,0),p+Vector2(0,r),p-Vector2(0,r)]:
		if not North.contains(q):return false
	if North._distance_paths(North.layout(),p)<r+.5:return false
	for a in d.actors:
		var start=Vector2(a.position[0],a.position[2]);var end=Vector2(a.get("path_end",a.position)[0],a.get("path_end",a.position)[2])
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,start,end))<r+1.4:return false
	return true
static func build(c:Node3D):
	var d=config();var rng=RandomNumberGenerator.new();rng.seed=20260913
	var before=c.tree_count
	for point in d.trees:c.place_tree("study_canopy_1",Vector2(point[0],point[1]),.9)
	var flowers=[[],[]];var banks=[[],[]];var rocks=[];var used=[]
	for anchor in d.flower_anchors:
		for j in range(30):
			var a=rng.randf()*TAU;var p=Vector2(anchor[0],anchor[1])+Vector2(cos(a)*4.5,sin(a)*3)*sqrt(rng.randf())
			if not safe(p,.95):continue
			var blocked=false
			for q in used:
				if p.distance_to(q)<1.5:blocked=true;break
			for record in c.lookdev_tree_contacts:
				if p.distance_to(Vector2(record.position.x,record.position.z))<1.7:blocked=true;break
			if blocked:continue
			used.append(p);var tr=c.placement(p.x,0,p.y,Vector3.ONE*rng.randf_range(.65,.95),rng.randf()*TAU)
			if j%3==0:banks[j%2].append(tr)
			else:flowers[1 if j%5==0 else 0].append(tr)
	for p in [Vector2(-31,38),Vector2(-35,62)]:
		if safe(p,1.5):rocks.append(c.placement(p.x,-.3,p.y,Vector3.ONE*.46,.8))
	for i in range(2):c.multimesh_batch("study_flower_mound_"+str(i),flowers[i]);c.multimesh_batch("study_bank_patch_"+str(i),banks[i])
	c.multimesh_batch("study_rock_garden_0",rocks)
	c.world.set_meta("lookdev_tree_contacts",c.lookdev_tree_contacts)
	c.study_stats["west_grove"]={"trees":c.tree_count-before,"flowers":flowers[0].size()+flowers[1].size(),"bank_groups":banks[0].size()+banks[1].size(),"rocks":rocks.size(),"additional_people":2,"new_land":false}
