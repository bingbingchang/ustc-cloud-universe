extends RefCounted
## Tree roots and their basin share one placement record, never two spacing formulas.
static func root_half_extent(c:Node3D,record:Dictionary)->Vector2:
	var half=Vector2(.78,.78)
	for part in c.asset_cache[record.asset]:
		for s in part.mesh.get_surface_count():
			var mat=part.mesh.surface_get_material(s)
			if mat==null or not "Bark" in mat.resource_name:continue
			for v in part.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p:Vector3=record.placement*(part.transform*v)
				if p.y<.38:
					half.x=maxf(half.x,absf(p.x-record.position.x)+.16)
					half.y=maxf(half.y,absf(p.z-record.position.z)+.16)
	return half

static func legacy_rim_triangle(points:Array)->bool:
	for side in [-1,1]:
		for i in range(16,19):
			var center=Vector2(side*7.15,6+i*7.45)
			var inside=true
			for p in points:
				if absf(p.x-center.x)>.90 or absf(p.z-center.y)>.90 or p.y<-.02 or p.y>.11:inside=false;break
			if inside:return true
	return false

static func remove_legacy_rims(n:Node)->int:
	var removed=0
	if n is MeshInstance3D and n.mesh:
		var mesh=ArrayMesh.new();var overrides=[]
		for s in n.mesh.get_surface_count():
			var arrays=n.mesh.surface_get_arrays(s);var mat=n.mesh.surface_get_material(s)
			if mat and mat.resource_name.begins_with("Stone"):
				var ids=arrays[Mesh.ARRAY_INDEX];var kept=PackedInt32Array();var vs=arrays[Mesh.ARRAY_VERTEX]
				for i in range(0,ids.size(),3):
					var tri=[n.global_transform*vs[ids[i]],n.global_transform*vs[ids[i+1]],n.global_transform*vs[ids[i+2]]]
					if legacy_rim_triangle(tri):removed+=1
					else:kept.append(ids[i]);kept.append(ids[i+1]);kept.append(ids[i+2])
				arrays[Mesh.ARRAY_INDEX]=kept
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			mesh.surface_set_material(s,mat);overrides.append(n.get_surface_override_material(s))
		n.mesh=mesh
		for s in overrides.size():n.set_surface_override_material(s,overrides[s])
	for child in n.get_children():removed+=remove_legacy_rims(child)
	return removed

static func build(c:Node3D,records:Array)->Array:
	var removed=0
	for n in c.world.get_children():
		if String(n.name).to_lower().begins_with("diositedetail"):removed+=remove_legacy_rims(n)
	var basins=[];var rims=[];var soils=[]
	for record in records:
		var p:Vector3=record.position
		if p.z<118 or p.z>150:continue
		var half=root_half_extent(c,record);var width=.12
		# A square opening accommodates the widest visible root plus a soil margin.
		var h=maxf(half.x,half.y)
		for side in [-1,1]:
			rims.append(c.placement(p.x+side*(h+width*.5),.055,p.z,Vector3(width,.11,2*h+2*width),0))
			rims.append(c.placement(p.x,.055,p.z+side*(h+width*.5),Vector3(2*h,.11,width),0))
		soils.append(c.placement(p.x,.018,p.z,Vector3(h*2,.028,h*2),0))
		basins.append({"center":[p.x,p.z],"inner_half":h,"root_half":[half.x-.16,half.y-.16],"asset":record.asset})
	var geo=load("res://scripts/wave2_environment.gd")
	geo._box_batch(c,rims,c.mats.stone,"AlignedTreeBasinRims")
	geo._box_batch(c,soils,c.material(Color("514936")),"AlignedTreeBasinSoil")
	c.world.set_meta("tree_basins",{"count":basins.size(),"removed_legacy_triangles":removed,"basins":basins})
	return basins

static func overlaps(p:Vector2,r:float,basins:Array)->bool:
	for basin in basins:
		var center=Vector2(basin.center[0],basin.center[1])
		if absf(p.x-center.x)<basin.inner_half+.12+r and absf(p.y-center.y)<basin.inner_half+.12+r:return true
	return false
