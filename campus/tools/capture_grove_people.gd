extends SceneTree
func _initialize():call_deferred("run")
func run():
	var args=OS.get_cmdline_user_args()
	var variant="diorama" if "--lake-diorama" in args else "live"
	var stage="before" if "--grove-before" in args else "after"
	if "--lake-sample" in args:stage="sample"
	var dir="res://../renders/west_grove/"+stage+"_"+variant+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var c=load("res://scenes/campus_performance.tscn").instantiate();root.add_child(c)
	await process_frame
	var proof=load("res://scripts/north_axis_proof.gd").new();proof.prepare(c);proof.pose(c,12.0)
	if c.grove_life:c.grove_life.manual_time=0;c.grove_life.pose(0)
	c.photo_view=SubViewport.new();c.photo_view.world_3d=c.get_viewport().world_3d;c.photo_view.size=Vector2i(1024,768)
	c.photo_view.msaa_3d=Viewport.MSAA_4X;c.photo_view.use_taa=true;c.photo_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;c.add_child(c.photo_view)
	c.photo_camera=Camera3D.new();c.photo_camera.near=.075;c.photo_camera.far=850;c.photo_view.add_child(c.photo_camera);c.photo_camera.current=true;c.get_viewport().disable_3d=true

	var dir2="res://../renders/west_grove/people/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir2))
	var report=[]
	for id in c.grove_life.actors:
		for t in [0.0,8.0,15.0,25.0,36.0,45.999]:
			c.grove_life.manual_time=t;c.grove_life.pose(t)
			var actor=c.grove_life.actors[id].root
			proof.aim(c,actor.position+actor.basis*Vector3(.9,1.5,-3.3),actor.position+Vector3.UP*.95,43,160)
			for i in range(12):await process_frame
			await RenderingServer.frame_post_draw
			var file=id+"_"+str(t)+".png"
			c.photo_view.get_texture().get_image().save_png(dir2+file)
			report.append({"id":id,"time":t,"file":file,"state":actor.last_state()})
	var f=FileAccess.open(dir2+"report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));quit()