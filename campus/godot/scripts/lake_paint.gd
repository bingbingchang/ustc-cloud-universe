extends RefCounted
static var shaders:Dictionary={}
static func enabled()->bool:return not "--lake-before" in OS.get_cmdline_user_args()
static func apply(m:ShaderMaterial,kind:String,bounded=true)->ShaderMaterial:
	if not enabled() or m.get_meta("lake_painted",false):return m
	m.set_meta("lake_painted",true)
	var source=m.shader.get_instance_id()
	if not shaders.has(source):
		var shader=Shader.new();var code=m.shader.code
		code=code.replace("void vertex(){","#include \"res://shaders/lake_paint.gdshaderinc\"\nvoid vertex(){")
		code=code.replace("ALBEDO=graybox?vec3(.55):col;","col=lake_painted(col,wp,wn);\n ALBEDO=graybox?vec3(.55):col;")
		shader.code=code;shaders[source]=shader
	m.shader=shaders[source]
	m.set_shader_parameter("lake_atlas",load("res://assets/textures/lake_monet_atlas_v1.png"));m.set_shader_parameter("lake_bounded",bounded)
	var s={"stone":[Vector2(1,0),Vector2(2.0,2.0),.65,1.0],"leaf":[Vector2(0,1),Vector2(.55,.55),.48,1.0],"lawn":[Vector2(0,1),Vector2(3.5,3.5),.35,.85],"roof":[Vector2(1,1),Vector2(1.6,1.6),.92,1.0]}[kind]
	m.set_shader_parameter("lake_cell",s[0]);m.set_shader_parameter("lake_meters",s[1]);m.set_shader_parameter("lake_strength",s[2]);m.set_shader_parameter("lake_gain",s[3])
	m.set_shader_parameter("lake_sample","--lake-sample" in OS.get_cmdline_user_args())
	return m
