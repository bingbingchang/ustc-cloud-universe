extends Node
## Draw one material/vertex-format family per browser frame before revealing a region.
## Resource loading alone does not compile Compatibility/WebGL programs.
var game
var viewport:SubViewport
var stage:Node3D
var warmed={}
var material_keys={}
var shared_shaders={}
var maximum_frame_ms=0.0

func _ready():
	viewport=SubViewport.new();viewport.name="WebMaterialWarmup";viewport.size=Vector2i(64,64)
	viewport.own_world_3d=true;viewport.msaa_3d=game.get_viewport().msaa_3d
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	viewport.positional_shadow_atlas_size=256;viewport.directional_shadow_atlas_size=256
	add_child(viewport)
	stage=Node3D.new();viewport.add_child(stage)
	var environment=WorldEnvironment.new();environment.environment=game.live_environment;stage.add_child(environment)
	var light=game.sun.duplicate(0);stage.add_child(light)
	var camera=Camera3D.new();camera.position=Vector3(0,1.4,4);camera.far=80;stage.add_child(camera)
	camera.look_at(Vector3.ZERO);camera.current=true

func material_key(material:Material)->String:
	if not material:return "default"
	var id=material.get_instance_id()
	if material_keys.has(id):return material_keys[id]
	var key=material.get_class()
	if material is ShaderMaterial:
		if material.shader:
			var code_key=material.shader.code.sha256_text()
			for uniform in material.shader.get_shader_uniform_list():
				if uniform.type==TYPE_ARRAY:code_key+="/array-source="+str(material.shader.get_instance_id())
				if uniform.type!=TYPE_OBJECT:continue
				var texture=material.shader.get_default_texture_parameter(uniform.name)
				if texture:code_key+="/"+str(uniform.name)+":"+str(texture.get_instance_id())
			if shared_shaders.has(code_key):material.shader=shared_shaders[code_key]
			else:shared_shaders[code_key]=material.shader
			key+=code_key
		else:key+="none"
	elif material is BaseMaterial3D:
		for feature in range(BaseMaterial3D.FEATURE_MAX):key+=str(int(material.get_feature(feature)))
		for flag in range(BaseMaterial3D.FLAG_MAX):key+=str(int(material.get_flag(flag)))
		for texture in range(BaseMaterial3D.TEXTURE_MAX):key+=str(int(material.get_texture(texture)!=null))
		for property in ["transparency","alpha_antialiasing_mode","shading_mode","diffuse_mode","specular_mode","blend_mode","cull_mode","depth_draw_mode","billboard_mode","texture_filter","texture_repeat","distance_fade_mode"]:
			key+="/"+str(material.get(property))
	else:key+=str(id)
	if material.next_pass:key+="/next="+material_key(material.next_pass)
	material_keys[id]=key
	return key

func mesh_of(node:GeometryInstance3D)->Mesh:
	if node is MeshInstance3D:return node.mesh
	if node is MultiMeshInstance3D and node.multimesh:return node.multimesh.mesh
	return null

func signature(node:GeometryInstance3D)->String:
	if node is Label3D:return "label/"+str(node.shaded)+"/"+str(node.outline_size>0)
	var mesh=mesh_of(node)
	if not mesh:return ""
	var key=node.get_class()+"/"+str(node.cast_shadow)+"/"+material_key(node.material_override)+"/"+material_key(node.material_overlay)
	for surface in range(mesh.get_surface_count()):
		var material=node.get_surface_override_material(surface) if node is MeshInstance3D else null
		if not material:material=mesh.surface_get_material(surface)
		key+="/"+str(mesh.surface_get_format(surface))+":"+material_key(material)
	if node is MultiMeshInstance3D:key+="/"+str(node.multimesh.use_colors)+"/"+str(node.multimesh.use_custom_data)
	return key

func prototype(source:GeometryInstance3D)->GeometryInstance3D:
	if source is Label3D:
		var label=Label3D.new();label.text="科大 · 校园人物";label.font=source.font;label.font_size=source.font_size
		label.outline_size=source.outline_size;label.shaded=source.shaded;label.billboard=source.billboard
		label.pixel_size=.012;return label
	var mesh=mesh_of(source)
	var instance:GeometryInstance3D
	if source is MultiMeshInstance3D:
		var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.use_colors=source.multimesh.use_colors;multi.use_custom_data=source.multimesh.use_custom_data
		multi.mesh=mesh;multi.instance_count=1;multi.set_instance_transform(0,Transform3D.IDENTITY)
		if multi.use_colors:multi.set_instance_color(0,Color.WHITE)
		if multi.use_custom_data:multi.set_instance_custom_data(0,source.multimesh.get_instance_custom_data(0))
		var item=MultiMeshInstance3D.new();item.multimesh=multi;instance=item
	else:
		var item=MeshInstance3D.new();item.mesh=mesh
		for surface in range(mesh.get_surface_count()):item.set_surface_override_material(surface,source.get_surface_override_material(surface))
		instance=item
	instance.material_override=source.material_override;instance.material_overlay=source.material_overlay
	instance.cast_shadow=source.cast_shadow;instance.layers=source.layers
	var box=mesh.get_aabb();var scale_factor=2.0/maxf(.01,box.size[box.size.max_axis_index()])
	instance.scale=Vector3.ONE*scale_factor;instance.position=-box.get_center()*scale_factor
	return instance

func prepare_tree(root:Node,label:String):
	var representatives={};var count=0
	for node in root.find_children("*","GeometryInstance3D",true,false):
		var key=signature(node)
		if not key.is_empty() and not warmed.has(key):representatives[key]=node
		count+=1
		if count%128==0:await get_tree().process_frame
	var done=0;var started=Time.get_ticks_msec()
	for key in representatives:
		var source=representatives[key]
		if not is_instance_valid(source):continue
		var instance=prototype(source);stage.add_child(instance)
		game.streaming.notify("shaders","正在准备画面 %d / %d"%[done+1,representatives.size()],float(done)/maxi(1,representatives.size()))
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		var frame_started=Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		maximum_frame_ms=maxf(maximum_frame_ms,float(Time.get_ticks_usec()-frame_started)/1000)
		instance.free();warmed[key]=true;done+=1
		await get_tree().process_frame
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	print("WEB_SHADER_WARMED region=",label," geometries=",count," families=",done," elapsed_ms=",Time.get_ticks_msec()-started," max_frame_ms=",snappedf(maximum_frame_ms,.1))
