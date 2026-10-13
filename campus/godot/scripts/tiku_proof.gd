extends "res://scripts/diorama.gd"
func _ready():
	super._ready()
	call_deferred("proof")

func proof():
	sun.directional_shadow_max_distance=60
	sun.light_angular_distance=.4;sun.shadow_blur=1.0
	player.enabled=false;player.frozen=true;hud.visible=false
	photo_view=SubViewport.new();photo_view.size=Vector2i(1920,1440);photo_view.world_3d=get_world_3d();photo_view.msaa_3d=Viewport.MSAA_4X;photo_view.use_taa=true;photo_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(photo_view)
	photo_camera=Camera3D.new();photo_camera.near=.03;photo_camera.far=2000;photo_view.add_child(photo_camera);photo_camera.current=true;get_viewport().disable_3d=true
	var study=life_layer.actors.solver.root
	var model=load("res://assets/tiku_boy1.glb").instantiate();world.add_child(model);model.set_script(preload("res://scripts/tiku_actor.gd"));model.prepare();style(model);model.position=Vector3(1000,.89,0);model.standing=true
	var floor_mesh=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=Vector3(16,.1,16);floor_mesh.mesh=mesh;floor_mesh.position=Vector3(1000,-.06,0)
	var mat=StandardMaterial3D.new();mat.albedo_color=Color(.62,.64,.59);mat.roughness=1;floor_mesh.material_override=mat;world.add_child(floor_mesh)
	var shots=[
		["01_front",Vector3(0,1.0,-3.8),Vector3(0,.95,0),32.0,"neutral",0.0],
		["02_three_quarter",Vector3(-2.3,1.25,-3.3),Vector3(0,.95,0),32.0,"neutral",0.0],
		["03_side",Vector3(-3.8,1.1,0),Vector3(0,.95,0),32.0,"neutral",0.0],
		["04_back",Vector3(0,1.1,3.8),Vector3(0,.95,0),32.0,"neutral",0.0],
		["05_neutral",Vector3(0,1.62,-1.05),Vector3(0,1.61,-.01),32.0,"neutral",0.0],
		["06_side_eye",Vector3(-.25,1.64,-1.05),Vector3(0,1.61,-.01),32.0,"side_eye",12.0],
		["07_thinking",Vector3(-.40,1.63,-1.0),Vector3(0,1.60,-.01),32.0,"thinking",9.0]]
	for shot in shots:
		model.expression=shot[4];model.pose(shot[5]);photo_camera.global_position=Vector3(1000,0,0)+shot[1];photo_camera.look_at(Vector3(1000,0,0)+shot[2]);photo_camera.fov=shot[3]
		for i in range(32):await get_tree().process_frame
		await capture("tiku_identity/"+shot[0])
	model.visible=false
	photo_camera.global_position=Vector3(-18.3,1.45,145.1);photo_camera.look_at(Vector3(-17,1.05,146.85));photo_camera.fov=38;life_layer.manual_time=3.0
	for i in range(32):await get_tree().process_frame
	await capture("tiku_identity/08_study")
	photo_camera.global_position=Vector3(-20.3,2.1,143.4);photo_camera.look_at(Vector3(-17,.9,146.85));photo_camera.fov=40
	for i in range(32):await get_tree().process_frame
	await capture("tiku_identity/09_campus")
	photo_camera.global_position=Vector3(-17.20,1.42,145.72);photo_camera.look_at(Vector3(-17,1.34,146.90));photo_camera.fov=32;life_layer.manual_time=12.15
	for i in range(32):await get_tree().process_frame
	await capture("tiku_identity/10_study_side_eye_close")
	photo_camera.global_position=Vector3(-18.3,1.45,145.1);photo_camera.look_at(Vector3(-17,1.04,146.85));photo_camera.fov=38;life_layer.manual_time=14.4
	for i in range(32):await get_tree().process_frame
	await capture("tiku_identity/11_study_adjust_glasses")
	var uniform=load("res://assets/tiku_boy1_uniform.glb").instantiate();world.add_child(uniform);uniform.set_script(preload("res://scripts/tiku_actor.gd"));uniform.prepare();style(uniform);uniform.position=Vector3(1000,.89,0);uniform.standing=true;uniform.pose(0)
	for shot in [["12_uniform_front",Vector3(0,1,-3.8),Vector3(0,.95,0)],["13_uniform_three_quarter",Vector3(-2.3,1.25,-3.3),Vector3(0,.95,0)],["14_uniform_face",Vector3(-.25,1.64,-1.05),Vector3(0,1.61,-.01)]]:
		photo_camera.global_position=Vector3(1000,0,0)+shot[1];photo_camera.look_at(Vector3(1000,0,0)+shot[2]);photo_camera.fov=32
		for i in range(32):await get_tree().process_frame
		await capture("tiku_identity/"+shot[0])
	uniform.visible=false
	for shot in [["15_roadside_thinking",4.5],["16_roadside_side_eye",9.6],["17_roadside_glasses",12.5]]:
		photo_camera.global_position=Vector3(1.8,1.72,142.35);photo_camera.look_at(Vector3(3.4,1.14,145.0));photo_camera.fov=38;life_layer.manual_time=shot[1]
		for i in range(32):await get_tree().process_frame
		await capture("tiku_identity/"+shot[0])
	var samples=[];var passed=true
	for i in range(641):
		study.pose(i/20.0);passed=passed and study.last_state.finite
		if i%10==0:samples.append(study.last_state.duplicate())
	var coverage={}
	for key in ["thinking","side_eye","glasses","page","fatigue"]:
		coverage[key]=false
		for sample in samples:coverage[key]=coverage[key] or sample[key]>.8
		passed=passed and coverage[key]
	var roadside=life_layer.actors.roadside.root
	var road_samples=[];var road_finite=true
	for i in range(641):
		roadside.pose(i/20.0);road_finite=road_finite and roadside.last_state.finite
		if i%10==0:road_samples.append(roadside.last_state.duplicate())
	var report={"passed":passed and road_finite,"duration":32,"poses_checked":1282,"state_coverage":coverage,"samples":samples,"loop_closure":study.validate_loop(),"roadside_loop":roadside.validate_loop(),"roadside_samples":road_samples}
	var f=FileAccess.open("res://../renders/tiku_identity/animation_validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("TIKU_PROOF_OK ",passed)
	if "--tiku-motion" in OS.get_cmdline_user_args():
		photo_view.size=Vector2i(1280,720);photo_camera.global_position=Vector3(-18.3,1.45,145.1);photo_camera.look_at(Vector3(-17,1.04,146.85));photo_camera.fov=38
		var dir=ProjectSettings.globalize_path("res://../renders/tiku_identity/motion_frames");DirAccess.make_dir_recursive_absolute(dir)
		for i in range(640):
			life_layer.manual_time=i/20.0;study.pose(i/20.0);await RenderingServer.frame_post_draw
			photo_view.get_texture().get_image().save_jpg(dir+"/frame_%05d.jpg"%i,.95)
		var mf=FileAccess.open("res://../renders/tiku_identity/motion_manifest.json",FileAccess.WRITE);mf.store_string(JSON.stringify({"width":1280,"height":720,"fps":20,"frames":640}));mf.close()
		print("TIKU_MOTION_OK 640")
		photo_camera.global_position=Vector3(1.8,1.72,142.35);photo_camera.look_at(Vector3(3.4,1.14,145.0));photo_camera.fov=38
		dir=ProjectSettings.globalize_path("res://../renders/tiku_identity/roadside/motion_frames");DirAccess.make_dir_recursive_absolute(dir)
		for i in range(640):
			life_layer.manual_time=i/20.0;roadside.pose(i/20.0);await RenderingServer.frame_post_draw
			photo_view.get_texture().get_image().save_jpg(dir+"/frame_%05d.jpg"%i,.95)
		mf=FileAccess.open("res://../renders/tiku_identity/roadside/motion_manifest.json",FileAccess.WRITE);mf.store_string(JSON.stringify({"width":1280,"height":720,"fps":20,"frames":640}));mf.close()
		print("TIKU_ROADSIDE_MOTION_OK 640")
	get_tree().quit()
