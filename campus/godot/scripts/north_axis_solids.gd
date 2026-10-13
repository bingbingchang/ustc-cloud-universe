extends RefCounted
## Decorative structures only. Pond, bridges, ground and buildings belong to NorthAxis.
static func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
static func build(c:Node3D):
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/north_axis_assets_manifest.json"))
	for s in data.collision_solids:
		if s.type=="box":c.static_box(vec(s.center),vec(s.size),s.name)
		elif s.type=="cylinder":
			var body=StaticBody3D.new();body.name=s.name;c.world.add_child(body);body.position=vec(s.center)
			var shape=CylinderShape3D.new();shape.radius=s.radius;shape.height=s.height
			var cs=CollisionShape3D.new();cs.shape=shape;body.add_child(cs)
		elif s.type=="beam":
			var a=Vector2(s.a[0],s.a[1]);var b=Vector2(s.b[0],s.b[1]);var mid=(a+b)*.5
			var body=c.static_box(Vector3(mid.x,s.y,mid.y),Vector3(s.width,s.height,a.distance_to(b)),s.name)
			body.rotation.y=atan2(b.x-a.x,b.y-a.y)
