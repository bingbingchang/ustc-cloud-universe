extends RefCounted
## Measured north campus fragment. Land, pond islands and bridge permissions share
## one source, including the southern pond tips that overlap the retained core.
const Geometry = preload("res://scripts/wave2_environment.gd")
const DATA = "res://data/north_axis_layout.json"
static var _cached:Dictionary={}

static func layout()->Dictionary:
	if _cached.is_empty():_cached=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return _cached

static func polygon(values:Array)->PackedVector2Array:
	return Geometry.polygon(values)

static func boundary_openings(side:String)->Array:
	var result=[]
	for port in layout().ports:
		if port.side==side:result.append(Vector2(port.span[0],port.span[1]))
	return result

static func walk_routes()->Array:
	return layout().walk_routes

static func camera_spots()->Array:
	var result=[]
	for spec in layout().camera_spots:
		var spot=spec.duplicate(true)
		spot.pos=Vector3(spec.pos[0],spec.pos[1],spec.pos[2])
		spot.target=Vector3(spec.target[0],spec.target[1],spec.target[2])
		result.append(spot)
	return result

static func _inside_pond(p:Vector2,d:Dictionary)->bool:
	for pond in d.ponds:
		if not Geometry2D.is_point_in_polygon(p,polygon(pond.outer)):continue
		var island=false
		for hole in pond.holes:
			if Geometry2D.is_point_in_polygon(p,polygon(hole)):island=true
		if not island:return true
	return false

static func contains(p:Vector2)->bool:
	var d=layout()
	if not Geometry2D.is_point_in_polygon(p,polygon(d.polygon)):return false
	if _inside_pond(p,d):return false
	for building in d.buildings:
		if Geometry2D.is_point_in_polygon(p,polygon(building.polygon)):return false
	return true

static func _core()->PackedVector2Array:
	return polygon([[-80,118],[80,118],[80,238],[-80,238]])

static func _rect(x:float,z:float,w:float,h:float)->PackedVector2Array:
	return PackedVector2Array([Vector2(x,z),Vector2(x+w,z),Vector2(x+w,z+h),Vector2(x,z+h)])

static func _bounds(shape:PackedVector2Array)->Rect2:
	var rect=Rect2(shape[0],Vector2.ZERO)
	for p in shape:rect=rect.expand(p)
	return rect

static func _cell_cut(cell:PackedVector2Array,cuts:Array,depth:int=0)->Array:
	# Godot polygon difference may return holes as reversed loops. Never fill those
	# loops as grass: subdivide the cell until each cut meets its cell boundary.
	var parts=[cell]
	for cut in cuts:
		var next=[]
		for part in parts:
			var fragments=Geometry2D.clip_polygons(part,cut)
			for fragment in fragments:
				if Geometry2D.is_polygon_clockwise(fragment):
					if depth>=10:
						push_error("North axis clipping could not resolve a hole");return []
					var bounds=_bounds(cell);var half=bounds.size*.5;var split=[]
					for dx in [0,1]:
						for dz in [0,1]:
							for sub in Geometry2D.intersect_polygons(cell,_rect(bounds.position.x+dx*half.x,bounds.position.y+dz*half.y,half.x,half.y)):
								split.append_array(_cell_cut(sub,cuts,depth+1))
					return split
				if fragment.size()>=3:next.append(fragment)
		parts=next
	return parts

static func _pieces(shape:PackedVector2Array,cuts:Array)->Array:
	var bounds=_bounds(shape);var parts=[];var step=8.0
	var nearby=[]
	for cut in cuts:
		if bounds.intersects(_bounds(cut),true):nearby.append(cut)
	for ix in range(int(floor(bounds.position.x/step)),int(ceil(bounds.end.x/step))):
		for iz in range(int(floor(bounds.position.y/step)),int(ceil(bounds.end.y/step))):
			for cell in Geometry2D.intersect_polygons(shape,_rect(ix*step,iz*step,step,step)):
				if Geometry2D.is_polygon_clockwise(cell):cell.reverse()
				for piece in _cell_cut(cell,nearby):parts.append(_clean_polygon(piece))
	return parts

static func _clean_polygon(p:PackedVector2Array)->PackedVector2Array:
	var clean=PackedVector2Array()
	for v in p:
		if clean.is_empty() or v.distance_squared_to(clean[-1])>0.00000001:clean.append(v)
	if clean.size()>1 and clean[0].distance_squared_to(clean[-1])<=0.00000001:clean.remove_at(clean.size()-1)
	var i=0
	while clean.size()>3 and i<clean.size():
		var a=clean[(i+clean.size()-1)%clean.size()];var b=clean[i];var z=clean[(i+1)%clean.size()]
		if absf((b-a).cross(z-b))<.000001:clean.remove_at(i)
		else:i+=1
	return clean

static func _surface(c:Node3D,parts:Array,y:float,mat:Material,label:String):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var count=0
	for part in parts:
		var tri=Geometry2D.triangulate_polygon(part)
		for i in range(0,tri.size(),3):
			var a=part[tri[i]];var b=part[tri[i+1]];var z=part[tri[i+2]]
			var vs=[Vector3(a.x,y,a.y),Vector3(b.x,y,b.y),Vector3(z.x,y,z.y)]
			if (vs[1]-vs[0]).cross(vs[2]-vs[0]).y<0:vs.reverse()
			for v in vs:st.set_normal(Vector3.UP);st.set_uv(Vector2(v.x,v.z));st.add_vertex(v);count+=1
	if count==0:return
	var node=MeshInstance3D.new();node.name=label;node.mesh=st.commit();node.material_override=mat;c.world.add_child(node)
	if label.begins_with("NorthWater_"):node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _solid(c:Node3D,parts:Array,bottom:float,top:float,label:String)->StaticBody3D:
	var body=StaticBody3D.new();body.name=label;c.world.add_child(body)
	if parts.size()>1:
		# Static triangle meshes match the clipped surfaces and avoid convex
		# partitioning of nearly collinear district intersections.
		var faces=PackedVector3Array()
		for part in parts:
			var triangles=Geometry2D.triangulate_polygon(part)
			for k in range(0,triangles.size(),3):
				var a=part[triangles[k]];var b=part[triangles[k+1]];var z=part[triangles[k+2]]
				var upper=[Vector3(a.x,top,a.y),Vector3(b.x,top,b.y),Vector3(z.x,top,z.y)]
				if (upper[1]-upper[0]).cross(upper[2]-upper[0]).y<0:upper.reverse()
				faces.append_array(upper)
			for i in range(part.size()):
				var a=part[i];var b=part[(i+1)%part.size()]
				faces.append_array([Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),Vector3(b.x,top,b.y),Vector3(a.x,bottom,a.y),Vector3(b.x,top,b.y),Vector3(a.x,top,a.y)])
		if not faces.is_empty():
			var mesh_shape=ConcavePolygonShape3D.new();mesh_shape.set_faces(faces);mesh_shape.backface_collision=true
			var collision=CollisionShape3D.new();collision.shape=mesh_shape;body.add_child(collision)
		return body
	for part in parts:
		for convex in Geometry2D.decompose_polygon_in_convex(part):
			var vertices=PackedVector3Array()
			for p in convex:vertices.append(Vector3(p.x,bottom,p.y));vertices.append(Vector3(p.x,top,p.y))
			var shape=ConvexPolygonShape3D.new();shape.points=vertices
			var collision=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
	return body

static func _stroke(points:PackedVector2Array,width:float)->Array:
	return Geometry2D.offset_polyline(points,width*.5,Geometry2D.JOIN_ROUND,Geometry2D.END_BUTT)

static func _valid_surface(parts:Array,regions:Array,cuts:Array)->Array:
	var result=[]
	for part in parts:
		for region in regions:
			for intersection in Geometry2D.intersect_polygons(part,region):result.append_array(_pieces(intersection,cuts))
	return result

static func build(c:Node3D):
	var d=layout();var outline=polygon(d.polygon);var water_cuts=[];var building_cuts=[]
	for pond in d.ponds:water_cuts.append(polygon(pond.outer))
	for building in d.buildings:building_cuts.append(polygon(building.polygon))
	var land=_pieces(outline,water_cuts)
	var stone=c.asset_material("Stone",Color("c5bca4"));var wood=c.asset_material("Wood",Color("665c48"))
	_surface(c,land,0,c.mats.grass,"NorthAxisLand")
	_solid(c,land,-.75,0,"NorthAxisWalkableLand")
	_plinth_skirt(c,outline,-3.15,-.035,stone);_plinth_skirt(c,outline,-3.95,-3.15,wood)
	_surface(c,[outline],-3.94,wood,"NorthAxisPlinthBottom")
	# The scenery builder owns visible architecture; no solid wall across gate openings.
	for building in d.buildings:_solid(c,[polygon(building.polygon)],-.75,building.height,"NorthBuilding_"+building.id)
	var bridge_clear=[]
	for bridge in d.bridges:
		var deck=_stroke(polygon(bridge.points),bridge.width)
		_solid(c,deck,.08,bridge.top,"NorthBridgeDeck_"+bridge.id)
		bridge_clear.append_array(_stroke(polygon(bridge.points),bridge.width+.08))
		for end in bridge.ramps:_ramp(c,bridge,end,stone)
	_solid(c,[polygon(d.pavilion.polygon)],-.2,d.pavilion.top,"NorthPavilionPlatform")
	bridge_clear.append(polygon(d.pavilion.polygon))
	var shore_boxes=[]
	for pond in d.ponds:
		var outer=polygon(pond.outer);var holes=[]
		for hole in pond.holes:
			var island=polygon(hole);holes.append(island)
			_surface(c,[island],0,c.mats.grass,"NorthPavilionIsland")
			_solid(c,[island],-.75,0,"NorthIslandGround")
		var water=_pieces(outer,holes)
		_surface(c,water,d.water_y,c.mats.water,"NorthWater_"+pond.id)
		var barriers=_pieces(outer,holes+bridge_clear)
		_solid(c,barriers,-.55,2.3,"NorthNoEntryWater_"+pond.id)
		for ring in [outer]+holes:
			for i in range(ring.size()):
				var a=ring[i];var b=ring[(i+1)%ring.size()];var mid=(a+b)*.5
				shore_boxes.append(Geometry._box_transform(Vector3(mid.x,-.01,mid.y),Vector3(.34,.20,a.distance_to(b)+.04),atan2(b.x-a.x,b.y-a.y)))
	Geometry._box_batch(c,shore_boxes,stone,"NorthShoreCoping")
	# Only new terrain and small same-height apron strokes enter the original core.
	var regions=[outline,_core()];var road_pieces=[];var rim_pieces=[];var joints=[];var path_surfaces={}
	for path in d.paths:
		var points=polygon(path.points)
		var pieces=_valid_surface(_stroke(points,path.width),regions,water_cuts+building_cuts)
		road_pieces.append_array(pieces)
		var kind=path.get("surface","pavers")
		if not path_surfaces.has(kind):path_surfaces[kind]=[]
		path_surfaces[kind].append_array(pieces)
		rim_pieces.append_array(_valid_surface(_stroke(points,path.width+.26),regions,water_cuts+building_cuts))
		for i in range(points.size()-1):
			var a=points[i];var b=points[i+1];var direction=(b-a).normalized()
			for k in range(1,int(a.distance_to(b)/3.0)):
				var p=a+direction*k*3.0
				if _inside_pond(p,d):continue
				if not Geometry2D.is_point_in_polygon(p,outline):continue
				joints.append(Geometry._box_transform(Vector3(p.x,.081,p.y),Vector3(path.width-.18,.002,.015),atan2(direction.x,direction.y)))
	_surface(c,rim_pieces,.036,stone,"NorthPavingEdge")
	for kind in path_surfaces:_surface(c,path_surfaces[kind],.08,preload("res://scripts/road_surfaces.gd").material(c,kind),"NorthPath_"+kind)
	_solid(c,road_pieces,-.1,.08,"NorthWalkablePaving")
	Geometry._box_batch(c,joints,c.asset_material("NorthJoint",Color("b4ad97")),"NorthPavingJoints")
	_boundaries(c,d,outline,stone)
	_planting(c,d)
	_furniture(c,d,regions,water_cuts+building_cuts)
	c.world.set_meta("north_axis_stats",{"land_pieces":land.size(),"road_pieces":road_pieces.size(),"trees_requested":d.trees.size(),"complete_ponds":2,"mapped_bridge_branches":4})

static func _ramp(c:Node3D,bridge:Dictionary,end:String,mat:Material):
	var pts=polygon(bridge.points);var tip=pts[0] if end=="start" else pts[-1]
	var inward=(pts[1]-tip).normalized() if end=="start" else (pts[-2]-tip).normalized()
	var outside=tip-inward*2.2;var side=Vector2(-inward.y,inward.x)*bridge.width*.5
	var corners=[outside+side,outside-side,tip-side,tip+side]
	var ys=[.08,.08,bridge.top,bridge.top];var vertices=PackedVector3Array()
	for i in range(4):vertices.append(Vector3(corners[i].x,ys[i],corners[i].y))
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0,2,1,0,3,2]:st.add_vertex(vertices[i])
	st.generate_normals();var mesh=MeshInstance3D.new();mesh.name="NorthBridgeApproachRamp";mesh.mesh=st.commit();mesh.material_override=mat;c.world.add_child(mesh)
	for p in corners:vertices.append(Vector3(p.x,-.1,p.y))
	var body=StaticBody3D.new();body.name="NorthBridgeApproachRamp";c.world.add_child(body)
	var hull=ConvexPolygonShape3D.new();hull.points=vertices;var collider=CollisionShape3D.new();collider.shape=hull;body.add_child(collider)

static func _internal_seam(a:Vector2,b:Vector2)->bool:
	if is_equal_approx(a.y,118) and is_equal_approx(b.y,118) and minf(a.x,b.x)>=-80 and maxf(a.x,b.x)<=80:return true
	if is_equal_approx(a.x,80) and is_equal_approx(b.x,80) and minf(a.y,b.y)>=118 and maxf(a.y,b.y)<=153:return true
	if minf(a.y,b.y)>=145 and maxf(a.x,b.x)<=88 and minf(a.x,b.x)>=80:return true
	return false

static func _plinth_skirt(c:Node3D,outline:PackedVector2Array,bottom:float,top:float,mat:Material):
	# Internal module edges are not the model perimeter. A skirt across z118 would
	# protrude 15 mm above the lake and draw a false straight line through the water.
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outline.size()):
		var a=outline[i];var b=outline[(i+1)%outline.size()]
		if _internal_seam(a,b):continue
		for edge in Geometry.boundary_segments(a,b,"north_axis"):
			var start:Vector2=edge[0];var end:Vector2=edge[1]
			var vs=[Vector3(start.x,bottom,start.y),Vector3(start.x,top,start.y),Vector3(end.x,top,end.y),Vector3(end.x,bottom,end.y)]
			for j in [0,1,2,0,2,3]:st.add_vertex(vs[j])
	st.generate_normals();var node=MeshInstance3D.new();node.name="NorthExternalPlinthSkirt";node.mesh=st.commit();node.material_override=mat;c.world.add_child(node)

static func _boundaries(c:Node3D,d:Dictionary,outline:PackedVector2Array,mat:Material):
	var rim=[]
	for i in range(outline.size()):
		var a=outline[i];var b=outline[(i+1)%outline.size()]
		if _internal_seam(a,b):continue
		for edge in Geometry.boundary_segments(a,b,"north_axis"):
			var start:Vector2=edge[0];var end:Vector2=edge[1]
			var mid=(start+end)*.5;var angle=atan2(end.x-start.x,end.y-start.y)
			var body=c.static_box(Vector3(mid.x,1.05,mid.y),Vector3(.32,3.0,start.distance_to(end)+.04),"NorthOuterBoundary");body.rotation.y=angle
			rim.append(Geometry._box_transform(Vector3(mid.x,.045,mid.y),Vector3(.28,.09,start.distance_to(end)),angle))
	Geometry._box_batch(c,rim,mat,"NorthPlinthRim")

static func _distance_paths(d:Dictionary,p:Vector2)->float:
	var result=INF
	for path in d.paths:
		var pts=polygon(path.points)
		for i in range(pts.size()-1):result=minf(result,p.distance_to(Geometry2D.get_closest_point_to_segment(p,pts[i],pts[i+1]))-path.width*.5)
	return result

static func _planting(c:Node3D,d:Dictionary):
	var batches={};var accepted=[]
	for tree in d.trees:
		var p=Vector2(tree[0],tree[1])
		if c.has_method("sakura_replaces") and c.sakura_replaces(p):continue
		if not contains(p) or _distance_paths(d,p)<.65:continue
		var key="diotree%d%d"%[tree[2],tree[3]]
		if not batches.has(key):batches[key]=[]
		batches[key].append(c.placement(p.x,0,p.y,Vector3.ONE*tree[4],accepted.size()*1.13));accepted.append(p)
		c.static_box(Vector3(p.x,1,p.y),Vector3(.56,2,.56),"NorthTreeTrunk")
	for key in batches:c.multimesh(key,batches[key]);c.tree_count+=batches[key].size()
	var rng=RandomNumberGenerator.new();rng.seed=19850501;var shrubs=[];var grass=[]
	for i in range(1800):
		var p=Vector2(rng.randf_range(d.bounds[0]+1,d.bounds[2]-1),rng.randf_range(d.bounds[1]+1,142))
		if not contains(p) or _distance_paths(d,p)<1.1:continue
		var near_tree=false
		for tree in accepted:
			if p.distance_to(tree)<3.5:near_tree=true;break
		if near_tree and shrubs.size()<82:shrubs.append(c.placement(p.x,0,p.y,Vector3.ONE*rng.randf_range(.58,.9),rng.randf()*TAU))
		elif grass.size()<210:grass.append(c.placement(p.x,.012,p.y,Vector3.ONE*rng.randf_range(.45,.8),rng.randf()*TAU))
	c.multimesh("dioshrub",shrubs);c.multimesh("grass",grass)

static func _furniture(c:Node3D,d:Dictionary,regions:Array,cuts:Array):
	var benches=[];var lamps=[];var pads=[]
	for b in d.benches:
		var p=Vector2(b[0],b[1])
		if not contains(p):continue
		var along=Vector2(cos(b[2]),-sin(b[2]))
		pads.append_array(_valid_surface([Geometry._quad(p-along*1.3,p+along*1.3,1.3)],regions,cuts))
		benches.append(c.placement(p.x,.08,p.y,Vector3.ONE,b[2]))
		var body=c.static_box(Vector3(p.x,.62,p.y),Vector3(1.86,1.08,.60),"NorthBench");body.rotation.y=b[2]
	for lamp in d.lamps:
		if not contains(Vector2(lamp[0],lamp[1])):continue
		lamps.append(c.placement(lamp[0],.08,lamp[1],Vector3.ONE,lamp[2]))
		c.static_box(Vector3(lamp[0],1.3,lamp[1]),Vector3(.20,2.6,.20),"NorthLampPost")
	c.multimesh("bench",benches);c.multimesh("lamp",lamps)
	_surface(c,pads,.08,c.mats.path,"NorthBenchPads");_solid(c,pads,-.1,.08,"NorthBenchPadSupport")
	for sign in d.signs:
		var p=Vector3(sign[0],.08,sign[1]);c.signpost(p,sign[2],sign[3])
		c.static_box(p+Vector3(0,.8,0),Vector3(.12,1.6,.12),"NorthSignPost")
		c.static_box(p+Vector3(0,1.46,0),Vector3(2.2,.78,.14),"NorthSignBoard")
