extends RefCounted

const North=preload("res://scripts/north_axis_environment.gd")
const Geometry=preload("res://scripts/wave2_environment.gd")
const Detail=preload("res://scripts/north_axis_photo_details.gd")
const Surfaces=preload("res://scripts/road_surfaces.gd")

static func track_entry(c:Node3D,track:Dictionary)->void:
	var x:float=track.center[0]+track.outer_radius+1.7
	var gate_z:=440.7
	var runs=[[gate_z-16.0,gate_z-1.85],[gate_z+1.85,gate_z+15.1]]
	var steel:=Detail.matte(Color(.109,.255,.157))
	var blocks=[]
	for run in runs:
		var a:float=run[0]
		var b:float=run[1]
		var v:float=(a+b)*.5
		_mesh_fence(c,Vector2(x,a),Vector2(x,b),2.55)
		c.static_box(Vector3(x,1.31,v),Vector3(.07,2.48,b-a),"AthleticFenceContact")
		blocks.append(Geometry._box_transform(Vector3(x,2.55,v),Vector3(.064,.062,b-a),0))
		blocks.append(Geometry._box_transform(Vector3(x,.166,v),Vector3(.068,.064,b-a),0))
		var n:=ceili((b-a)/2.65)
		for i in range(n+1):
			var z:=lerpf(a,b,float(i)/n)
			blocks.append(Geometry._box_transform(Vector3(x,1.31,z),Vector3(.10,2.56,.10),0))
	Geometry._box_batch(c,blocks,steel,"AthleticEntryFenceFrames")
	var crossing:=North._rect(x-2.33,gate_z-1.80,7.5,3.60)
	North._surface(c,[crossing],.123,Surfaces.material(c,"pavers"),"AthleticsGatePaving")
	North._solid(c,[crossing],-.12,.123,"AthleticsGateApproach")
	var booth:=Vector3(x+2.15,0,gate_z-3.48)
	var plaster:=Detail.matte(Color(.50,.485,.40))
	var glazing:=Detail.matte(Color(.116,.172,.152))
	c.box(booth+Vector3(0,.52,0),Vector3(2.10,.86,2.05),plaster)
	c.box(booth+Vector3(0,1.48,0),Vector3(2.02,1.11,1.98),glazing)
	c.box(booth+Vector3(0,2.17,0),Vector3(2.22,.26,2.20),plaster)
	for lx in [-.97,.97]:
		for z in [-.93,.93]:
			c.box(booth+Vector3(lx,1.45,z),Vector3(.125,1.19,.125),plaster)
	c.static_box(booth+Vector3(0,1.15,0),Vector3(2.1,2.10,2.05),"AthleticGuardHouse")

static func _mesh_fence(c:Node3D,a:Vector2,b:Vector2,height:float)->void:
	var points=[Vector3(a.x,.1,a.y),Vector3(b.x,.1,b.y),Vector3(b.x,height,b.y),Vector3(a.x,height,a.y)]
	var uv=[Vector2.ZERO,Vector2(a.distance_to(b),0),Vector2(a.distance_to(b),height-.10),Vector2(0,height-.10)]
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0,1,2,0,2,3]:
		tool.set_uv(uv[i])
		tool.add_vertex(points[i])
	tool.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.name="AthleticEntryFenceMesh"
	mesh.mesh=tool.commit()
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/court_fence.gdshader")
	mesh.material_override=material
	c.world.add_child(mesh)

static func courtside_seats(c:Node3D)->void:
	var stones=[]
	for i in range(3):
		var z:=595.7+float(i)*.38
		var top:=.23+float(i)*.172
		var area:=North._rect(-229.0,z-.19,39.4,.38)
		stones.append(Geometry._box_transform(Vector3(-209.3,top*.50,z),Vector3(39.4,top,.38),0))
		North._solid(c,[area],.02,top,"SouthCourtsSpectatorStep")
	Geometry._box_batch(c,stones,Detail.matte(Color(.44,.45,.411)),"SouthCourtsSpectatorTiers")
	var benches=[]
	for x in [-247.0,-231.4,-216.15,-201.0]:
		var z:=580.1 if x<-222 else 593.32
		benches.append(c.placement(x,.13,z,Vector3.ONE*.87,0))
	c.multimesh("bench",benches)
