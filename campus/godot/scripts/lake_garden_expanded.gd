extends "res://scripts/lake_study.gd"
## Five connected compositions around the east pond, using the accepted direction.
func compose_garden():
	super.compose_garden()
	if "--garden-before" in OS.get_cmdline_user_args():return
	rng.seed=20260912
	var initial_trees=tree_count
	# Lower silhouettes preserve the pavilion and the existing taller forest backdrop.
	for p in [Vector2(67,116),Vector2(61,130),Vector2(38,132),Vector2(24,127),Vector2(74,107),Vector2(43,56),Vector2(72,64)]:
		place_tree("study_canopy_"+str(2 if study_records.size()%3==0 else 1),p,rng.randf_range(.55,.80))
	var flowers=[[],[]];var reeds=[[],[]];var stones=[[],[]];var positions=[]
	var zones=[
		{"name":"east_flower_bank","anchors":[Vector2(68,98),Vector2(68,109),Vector2(66,119)],"count":18,"radius":3.8},
		{"name":"south_grove","anchors":[Vector2(59,130),Vector2(48,132),Vector2(34,132)],"count":11,"radius":4.0},
		{"name":"cherry_transition","anchors":[Vector2(21,117),Vector2(22,125)],"count":9,"radius":2.8},
		{"name":"north_approach","anchors":[Vector2(39,56),Vector2(49,56),Vector2(59,54)],"count":13,"radius":3.0},
		{"name":"east_bridge_arrival","anchors":[Vector2(72,69),Vector2(76,74),Vector2(79,83)],"count":11,"radius":2.6}]
	for zone in zones:
		for anchor in zone.anchors:
			for j in range(zone.count):
				var a=rng.randf()*TAU;var r=sqrt(rng.randf())*zone.radius
				var p=anchor+Vector2(cos(a),sin(a))*r
				if not study_land_safe(p,1.1):continue
				var crowded=false
				for old in positions:
					if p.distance_to(old)<1.35:crowded=true;break
				if crowded:continue
				positions.append(p)
				var k=0 if j%4 else 1
				flowers[k].append(placement(p.x,0,p.y,Vector3.ONE*rng.randf_range(.72,1.12),rng.randf()*TAU))
	# Small stone groups sit in already non-walkable water, sheltered by reeds.
	for p in [Vector2(57,104),Vector2(53,116),Vector2(44,123),Vector2(33,123),Vector2(23,112)]:
		if not Lake.water_safe(p,2.3):continue
		var k=stones[0].size()%2
		stones[k].append(placement(p.x,-.30,p.y,Vector3.ONE*rng.randf_range(.68,.96),rng.randf()*TAU))
		for j in range(9):
			var a=j*TAU/9;var q=p+Vector2(cos(a),sin(a))*rng.randf_range(1.2,2.1)
			if Lake.water_safe(q,.55):reeds[j%2].append(placement(q.x,-.12,q.y,Vector3.ONE*rng.randf_range(.9,1.5),rng.randf()*TAU))
	for i in range(2):
		multimesh_batch("study_flower_mound_"+str(i),flowers[i])
		multimesh_batch("lake_reeds_"+str(i),reeds[i])
		multimesh_batch("study_rock_garden_"+str(i),stones[i])
	world.set_meta("lookdev_tree_contacts",lookdev_tree_contacts)
	world.set_meta("study_tree_records",study_records)
	study_stats["extension"]={"zones":zones.size(),"trees":tree_count-initial_trees,"flower_mounds":positions.size(),"stone_groups":stones[0].size()+stones[1].size(),"reed_groups":reeds[0].size()+reeds[1].size()}
	for n in world.get_children():
		if n is GeometryInstance3D:n.visibility_range_end=0

func _ready():
	super._ready()
	for s in [["东岸花石",Vector3(73,.15,120),Vector3(45,2,101),58.0],["南岸疏林",Vector3(40,.15,134),Vector3(43,3,90),60.0],["樱花接湖",Vector3(16,.15,122),Vector3(44,3,105),58.0]]:
		photo_spots.append({"name":s[0],"pos":s[1],"target":s[2],"fov":s[3],"ortho":false,"size":120.0,"reason":"连续湖园 · 莫奈方向"})
	viewpoint(photo_spots.size()-3)
