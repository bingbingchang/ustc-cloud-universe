extends SceneTree
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1600,1000);root.msaa_3d=Viewport.MSAA_4X
	var world=Node3D.new();root.add_child(world)
	var env=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("bac6c5")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c3d7e8");env.environment.ambient_light_energy=.72
	env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.environment.ssao_enabled=true;world.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-28,0);sun.light_color=Color("fff0d6");sun.light_energy=1.5;sun.shadow_enabled=true;world.add_child(sun)
	var camera=Camera3D.new();world.add_child(camera);camera.fov=38;camera.current=true
	var ground=MeshInstance3D.new();ground.mesh=PlaneMesh.new();ground.mesh.size=Vector2(70,70);var mat=StandardMaterial3D.new();mat.albedo_color=Color("9da894");mat.roughness=.9;ground.material_override=mat;world.add_child(ground)
	var stylist=preload("res://scripts/campus.gd").new();stylist.setup_materials()
	var registry={};var points=preload("res://scripts/scene_modules.gd").story_nodes()
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/wave2_nodes.json"))
	for entry in data.actors:
		var s=entry.duplicate(true);s.merge(points[entry.node_ref],true);s.id=entry.id;registry[s.id]=s
	var walker=preload("res://scripts/campus_wander.gd").new();walker.setup(registry)
	var output=ProjectSettings.globalize_path("res://../renders/wandering/proof");DirAccess.make_dir_recursive_absolute(output)
	var report={"renderer":"actual Godot Forward+; same NPR material as the campus","shots":[]}
	for id in registry:
		var s=registry[id];var actor=load("res://assets/"+s.asset+".glb").instantiate();world.add_child(actor);stylist.style(actor)
		actor.set_script(load("res://scripts/"+s.script));actor.role=s.role;actor.prepare()
		# A full swing phase exposes feet, flexing knee silhouette and prop grip.
		var t=0.0;var m=walker.sample(id,t)
		while t<walker.duration(id):
			m=walker.sample(id,t)
			var foot_key="FrontL" if id=="leaf_cat" else "L"
			if m.phase=="walk" and m.speed_mps>.15 and m.feet[foot_key].lift>.018:break
			t+=.025
		actor.position=m.position;actor.rotation.y=m.heading;actor.pose(m.story_time);actor.apply_locomotion(m)
		if id=="meituan":actor.bones.Parcel.visible=false
		elif id=="leaf_cat":actor.bones.Leaf.visible=false
		ground.position=actor.position;ground.position.y=.08
		for angle in ([.65,1.35] if id in ["doubao","leaf_cat"] else [.75]):
			var height=.3 if id=="leaf_cat" else float(s.height)*.5
			var radius=1.45 if id=="leaf_cat" else 3.05
			var direction=Basis(Vector3.UP,m.heading+angle)*Vector3(0,0,-radius)
			camera.position=actor.position+direction+Vector3.UP*(height+.40);camera.look_at(actor.position+Vector3.UP*height)
			for i in range(12):await process_frame
			await RenderingServer.frame_post_draw
			var file=id+"_stride_"+str(report.shots.size()+1)+".png"
			var pic=root.get_texture().get_image();var status=pic.save_png(output+"/"+file)
			report.shots.append({"file":file,"actor":id,"t":t,"phase":m.phase,"saved":status==OK});print("WANDER_PROOF ",file)
		actor.queue_free();await process_frame
	var f=FileAccess.open(output+"/capture_report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close();stylist.free();quit()
