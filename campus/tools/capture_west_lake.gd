extends SceneTree
func _initialize():call_deferred("run")
func run():
	var args=OS.get_cmdline_user_args()
	var variant="diorama" if "--lake-diorama" in args else "live"
	var stage="before" if not "--expand-west" in args else "after"
	if "--lake-sample" in args:stage="sample"
	var dir="res://../renders/west_lake/"+stage+"_"+variant+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var c=load("res://scenes/campus_performance.tscn").instantiate();root.add_child(c)
	await process_frame
	var proof=load("res://scripts/north_axis_proof.gd").new();proof.prepare(c);proof.pose(c,12.0)
	c.photo_view=SubViewport.new();c.photo_view.world_3d=c.get_viewport().world_3d;c.photo_view.size=Vector2i(1920,1080)
	c.photo_view.msaa_3d=Viewport.MSAA_4X;c.photo_view.use_taa=true;c.photo_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;c.add_child(c.photo_view)
	c.photo_camera=Camera3D.new();c.photo_camera.near=.075;c.photo_camera.far=850;c.photo_view.add_child(c.photo_camera);c.photo_camera.current=true;c.get_viewport().disable_3d=true
	var shots=[
        ["01_south_bank",Vector3(-43,1.8,139),Vector3(-39,2,108),58.0],
        ["02_bridge",Vector3(-15,1.8,105),Vector3(-45,1.5,110),58.0],
        ["03_west_bank",Vector3(-68,1.8,119),Vector3(-35,2,109),58.0],
        ["04_overview",Vector3(-85,45,158),Vector3(-38,0,110),52.0]]
	if "--study-quick" in args:shots=shots.slice(0,2)
	var report={"variant":variant,"stage":stage,"native_pixels":true,"resolution":[1920,1080],"shots":[]}
	for s in shots:
		proof.aim(c,s[1],s[2],s[3],260)
		for i in range(36):await process_frame
		await RenderingServer.frame_post_draw
		c.photo_view.get_texture().get_image().save_png(dir+s[0]+".png")
		report.shots.append({"file":s[0]+".png","position":str(s[1]),"target":str(s[2]),"fov":s[3],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
		print("LAKE_SHOT ",stage," ",variant," ",s[0])
	if c.world.has_meta("yijian_garden"):report["landscape"]=c.world.get_meta("yijian_garden")
	report["study"]=c.study_stats
	var render_instances={}
	for n in c.world.get_children():
		if n is MultiMeshInstance3D and n.visible:
			var asset=String(n.get_meta("render_asset","other"));render_instances[asset]=render_instances.get(asset,0)+n.multimesh.instance_count
	report["visible_instances_by_asset_across_surfaces"]=render_instances
	var f=FileAccess.open(dir+"report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"))
	if c.reflection_view:c.reflection_view.get_texture().get_image().save_png(dir+"reflection_debug.png")
	quit()
