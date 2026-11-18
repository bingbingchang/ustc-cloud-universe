extends SceneTree
## Native Godot bake from the original models/materials; never edits source GLBs.
const DIRECTORY="res://assets/runtime_hlod/"
var tile=512
var selected=PackedStringArray(["sakura_tree_0","sakura_tree_1","sakura_tree_2"])
const YAWS=8
const ELEVATIONS=[-10.0,30.0]
var material_owner

func _initialize():call_deferred("run")

func bounds_of(model:Node3D)->AABB:
	var bounds=AABB();var first=true
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		var box:AABB=mesh.global_transform*mesh.get_aabb()
		bounds=box if first else bounds.merge(box);first=false
	return bounds


# Make the far footprints from the actual 30-degree bake. One 32px coverage
# tile averages up to 256 original alpha texels; no full-resolution leaf
# texture fetches or additional sun shadow draws at long range.
func bake_ground_shadow_atlas(report: Dictionary) -> bool:
	var policy := preload("res://scripts/runtime_render_policy.gd").new()
	var names: Array = report.assets.keys().filter(policy.is_tree)
	policy.free()
	names.sort()
	if names.is_empty(): return false
	const TILE := 32
	var sheet := Image.create(8*TILE,names.size()*TILE,false,Image.FORMAT_L8)
	for row in names.size():
		var spec: Dictionary = report.assets[names[row]]
		var src := Image.load_from_file(ProjectSettings.globalize_path(spec.texture))
		if src == null or src.is_empty(): return false
		var size := int(src.get_width()/8)
		if src.get_size() != Vector2i(8,2)*size: return false
		for column in 8:
			var tile := src.get_region(Rect2i(column*size,size,size,size))
			tile.resize(TILE,TILE,Image.INTERPOLATE_TRILINEAR)
			for y in TILE:
				for x in TILE:
					var a := tile.get_pixel(x,y).a
					sheet.set_pixel(column*TILE+x,row*TILE+y,Color(a,a,a))
	if sheet.save_png(DIRECTORY+"canopy_shadow_coverage.png") != OK: return false
	var rows := FileAccess.open(DIRECTORY+"canopy_shadow_rows.json",FileAccess.WRITE)
	if not rows: return false
	rows.store_line(JSON.stringify(names))
	return true

func run():
	if "--ground-shadow-only" in OS.get_cmdline_user_args():
		var existing = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"manifest.json"))
		quit(0 if bake_ground_shadow_atlas(existing) else 1)
		return
	if DisplayServer.get_name()=="headless":push_error("Impostor bake needs actual rendering");quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--assets="):selected=arg.trim_prefix("--assets=").split(",")
		if arg.begins_with("--tile-size="):tile=int(arg.trim_prefix("--tile-size="))
	root.disable_3d=true;Engine.max_fps=30
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	material_owner=load("res://scripts/campus_game.gd").new();material_owner.setup_materials()
	var viewport=SubViewport.new();viewport.size=Vector2i(tile,tile);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg=true;viewport.msaa_3d=Viewport.MSAA_2X;root.add_child(viewport)
	var scene=Node3D.new();viewport.add_child(scene)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-43,-131,0);sun.light_color=Color(1,.94,.81);sun.light_energy=1.95;scene.add_child(sun)
	var world=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR
	env.background_color=Color(0,0,0,0);env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(.49,.60,.69);env.ambient_light_energy=.47
	env.tonemap_mode=Environment.TONE_MAPPER_ACES;env.tonemap_exposure=1.04;world.environment=env;scene.add_child(world)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.05;camera.far=100;scene.add_child(camera);camera.current=true
	var report={"version":1,"yaw_count":YAWS,"elevations":ELEVATIONS,"assets":{}}
	if FileAccess.file_exists(DIRECTORY+"manifest.json"):report=JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"manifest.json"))
	for asset in selected:
		var model=load("res://assets/"+asset+".glb").instantiate();scene.add_child(model);material_owner.style(model)
		var bounds=bounds_of(model);var center=bounds.get_center();var size=maxf(bounds.size.y,maxf(bounds.size.x,bounds.size.z))*1.08
		camera.size=size
		var atlas=Image.create(tile*YAWS,tile*ELEVATIONS.size(),false,Image.FORMAT_RGBA8);atlas.fill(Color.TRANSPARENT)
		for elevation in range(ELEVATIONS.size()):
			for yaw in range(YAWS):
				var angle=TAU*yaw/YAWS;var pitch=deg_to_rad(ELEVATIONS[elevation])
				camera.position=center+Vector3(sin(angle)*cos(pitch),sin(pitch),cos(angle)*cos(pitch))*35
				camera.look_at(center)
				await process_frame;await process_frame;await RenderingServer.frame_post_draw
				var image=viewport.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
				if not image.get_used_rect().has_area():push_error("Empty tree render; refuse an invalid HLOD atlas");quit(1);return
				atlas.blit_rect(image,Rect2i(0,0,tile,tile),Vector2i(yaw*tile,elevation*tile))
		var path=DIRECTORY+asset+".png";var error=atlas.save_png(path)
		if error!=OK:push_error("Cannot save tree atlas");quit(1);return
		report.assets[asset]={"texture":path,"tile_size":tile,"size":size,"center":[center.x,center.y,center.z],"source_sha256":FileAccess.get_sha256("res://assets/"+asset+".glb")}
		print("TREE_IMPOSTOR_BAKED ",asset," size=",size)
		model.free()
	FileAccess.open(DIRECTORY+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	material_owner.free()
	if not bake_ground_shadow_atlas(report): push_error("Failed to bake canopy shadow coverage");quit(1);return
	print("TREE_IMPOSTORS_COMPLETE");quit()
