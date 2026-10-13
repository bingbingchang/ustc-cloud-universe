extends RefCounted
const West=preload("res://scripts/west_lake_garden.gd")
const North=preload("res://scripts/north_axis_environment.gd")

static func build(c:Node3D):
	var rng=RandomNumberGenerator.new();rng.seed=20260920
	var before=c.tree_count
	for p in [Vector2(-69,81),Vector2(-70,97)]:
		c.place_tree("study_canopy_1",p,.85)
	var flowers=[[],[]];var banks=[[],[]];var reeds=[[],[]];var pads=[[],[],[],[]];var stones=[];var used=[]
	# Three pockets frame the northern inlet; leave breaks where paths reach water.
	for anchor in [Vector2(-69,81),Vector2(-71,92),Vector2(-59,74),Vector2(-46,80),Vector2(-17,82),Vector2(-17,94),Vector2(-63,96)]:
		for j in range(30):
			var a=rng.randf()*TAU;var p=anchor+Vector2(cos(a)*5,sin(a)*2.4)*sqrt(rng.randf())
			if not West.safe_land(p,.95):continue
			var close=false
			for q in used:
				if p.distance_to(q)<1.4:close=true;break
			for record in c.lookdev_tree_contacts:
				if p.distance_to(Vector2(record.position.x,record.position.z))<1.7:close=true;break
			if close:continue
			used.append(p)
			var tr=c.placement(p.x,0,p.y,Vector3.ONE*rng.randf_range(.6,.85),rng.randf()*TAU)
			if j%3==0:banks[j%2].append(tr)
			else:flowers[1 if j%5==0 else 0].append(tr)
	var shore=North.polygon(North.layout().ponds[0].outer)
	for i in range(shore.size()):
		var a:Vector2=shore[i];var b:Vector2=shore[(i+1)%shore.size()]
		for j in range(1,5):
			var p=a.lerp(b,j/5.0)
			if p.y>100:continue
			# Find a small inward offset, with bridge/water clearance validation.
			var tangent=(b-a).normalized();var normal=Vector2(-tangent.y,tangent.x)
			for side in [-1,1]:
				var q=p+normal*side*1.1
				if not West.safe_water(q,.65):continue
				reeds[j%2].append(c.placement(q.x,-.11,q.y,Vector3.ONE*.65,rng.randf()*TAU));break
	for island in [[Vector2(-49,86),Vector2(5,2)],[Vector2(-27,94),Vector2(2.5,4)]]:
		for j in range(30):
			var a=rng.randf()*TAU;var p=island[0]+Vector2(cos(a)*island[1].x,sin(a)*island[1].y)*sqrt(rng.randf())
			if West.safe_water(p,1.05):pads[j%4].append(c.placement(p.x,-.04,p.y,Vector3.ONE*rng.randf_range(.65,.9),rng.randf()*TAU))
	for p in [Vector2(-57,87),Vector2(-39,87),Vector2(-25,98)]:
		if West.safe_water(p,1.6):stones.append(c.placement(p.x,-.32,p.y,Vector3.ONE*.58,rng.randf()*TAU))
	for i in range(2):
		c.multimesh_batch("study_flower_mound_"+str(i),flowers[i]);c.multimesh_batch("study_bank_patch_"+str(i),banks[i]);c.multimesh_batch("lake_reeds_"+str(i),reeds[i])
	for i in range(4):c.multimesh_batch("study_lotus_"+str(i),pads[i])
	c.multimesh_batch("study_rock_garden_1",stones)
	c.world.set_meta("lookdev_tree_contacts",c.lookdev_tree_contacts)
	c.study_stats["northwest_lake"]={"trees":c.tree_count-before,"flower_groups":flowers[0].size()+flowers[1].size(),"bank_groups":banks[0].size()+banks[1].size(),"reeds":reeds[0].size()+reeds[1].size(),"lotus_groups":pads[0].size()+pads[1].size()+pads[2].size()+pads[3].size(),"stone_groups":stones.size(),"new_land":false}
