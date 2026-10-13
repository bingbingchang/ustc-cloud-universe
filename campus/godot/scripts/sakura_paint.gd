extends RefCounted
## Generated Monet-inspired pigment atlas; original material shaders stay intact.
static var shaders:Dictionary={}
static func enabled()->bool:
	return not "--sakura-before" in OS.get_cmdline_user_args() and not "--sakura-unpainted" in OS.get_cmdline_user_args()

static func apply(m:ShaderMaterial,kind:String,bounded=false)->ShaderMaterial:
	if not enabled() or m.get_meta("sakura_painted",false):return m
	m.set_meta("sakura_painted",true)
	var source=m.shader.resource_path
	if not shaders.has(source):
		var shader=Shader.new()
		var code=m.shader.code
		code=code.replace("void vertex(){", "#include \"res://shaders/sakura_paint.gdshaderinc\"\nvoid vertex(){")
		code=code.replace("ALBEDO=graybox?vec3(.55):col;", "col=sakura_painted(col,wp,wn);\n ALBEDO=graybox?vec3(.55):col;")
		shader.code=code;shaders[source]=shader
	m.shader=shaders[source]
	m.set_shader_parameter("paint_atlas",load("res://assets/textures/sakura_monet_atlas_v1.png"))
	m.set_shader_parameter("paint_bounded",bounded)
	var settings={
		"stone":[Vector2(0,0),Vector2(2.8,2.8),.68,1.0],
		"bark":[Vector2(1,0),Vector2(1.2,2.4),.80,.92],
		"leaf":[Vector2(0,1),Vector2(.65,.65),.48,1.1],
		"petal":[Vector2(1,1),Vector2(.3,.3),.55,1.0],
		"lawn":[Vector2(0,1),Vector2(3.7,3.7),.40,.95]}
	var s=settings[kind]
	m.set_shader_parameter("paint_cell",s[0]);m.set_shader_parameter("paint_meters",s[1])
	m.set_shader_parameter("paint_strength",s[2]);m.set_shader_parameter("paint_gain",s[3])
	return m
