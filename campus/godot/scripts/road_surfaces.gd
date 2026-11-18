extends RefCounted
static func material(c:Node3D,surface:String)->Material:
	var key="RoadSurface_"+surface
	if c.original_mats.has(key):return c.original_mats[key]
	var m:ShaderMaterial
	if surface=="sakura_stone":
		m=ShaderMaterial.new()
		m.shader=preload("res://shaders/teaching5_tile.gdshader")
		m.set_shader_parameter("wall_color",Color("c0bab5"))
		m.set_shader_parameter("tile_size",Vector2(.93,.48))
		m.set_shader_parameter("tile_variation",.095)
		m.set_shader_parameter("joint_strength",.19)
		m.set_shader_parameter("staggered_rows",true)
	elif surface in ["asphalt","pebble"]:
		m=ShaderMaterial.new();m.shader=preload("res://shaders/campus_aggregate.gdshader")
		m.set_shader_parameter("base_color",Color("555c58") if surface=="asphalt" else Color.WHITE)
		m.set_shader_parameter("pebbles",surface=="pebble");c.art_mats.append(m)
	else:
		m=c.material(Color.WHITE,0,1)
		c.surface(m,"paving" if surface=="pavers" else "stone",Vector2(2.0,2.0) if surface=="pavers" else Vector2(1.2,1.2))
		m.set_shader_parameter("base_color",Color("d3cebd") if surface=="pavers" else Color("c3c7bf") if surface=="concrete" else Color("b6bbb7"))
	c.original_mats[key]=m;return m
