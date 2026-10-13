extends SceneTree
func _initialize():call_deferred("run")
func run():
	var args=OS.get_cmdline_user_args()
	var variant="diorama" if "--lake-diorama" in args else "live"
	var stage="before" if "--lake-before" in args else "after"
	if "--lake-sample" in args:stage="sample"
	var dir="res://../renders/yijian_garden/"+stage+"_"+variant+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var c=load("res://scenes/diorama.tscn" if variant=="diorama" else "res://scenes/lookdev_live.tscn").instantiate();root.add_child(c)
	await process_frame
	var proof=load("res://scripts/north_axis_proof.gd").new();proof.prepare(c);proof.pose(c,12.0)
	c.photo_view=SubViewport.new();c.photo_view.world_3d=c.get_viewport().world_3d;c.photo_view.size=Vector2i(1920,1080)
	c.photo_view.msaa_3d=Viewport.MSAA_4X;c.photo_view.use_taa=true;c.photo_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;c.add_child(c.photo_view)
	c.photo_camera=Camera3D.new();c.photo_camera.near=.075;c.photo_camera.far=850;c.photo_view.add_child(c.photo_camera);c.photo_camera.current=true;c.get_viewport().disable_3d=true
	var shots=[
		["01_east_bridge",Vector3(73,1.85,78),Vector3(42.5,3,80.8),56.0],
		["02_water_edge",Vector3(65.8,1.4,101),Vector3(42.5,3,80.8),58.0],
		["03_north_approach",Vector3(27,1.85,61),Vector3(43,3,81),57.0],
		["04_from_pavilion",Vector3(44,1.95,80),Vector3(70,1.1,100),58.0],
		["05_cherry_connection",Vector3(9.4,1.85,106),Vector3(43,3.5,81),60.0],
		["06_overview",Vector3(109,64,137),Vector3(40,0,94),50.0]]
	if "--lake-quick" in args:shots=shots.slice(0,2)
	var report={"variant":variant,"stage":stage,"native_pixels":true,"resolution":[1920,1080],"shots":[]}
	for s in shots:
		proof.aim(c,s[1],s[2],s[3],260)
		for i in range(20):await process_frame
		await RenderingServer.frame_post_draw
		c.photo_view.get_texture().get_image().save_png(dir+s[0]+".png")
		report.shots.append({"file":s[0]+".png","position":str(s[1]),"target":str(s[2]),"fov":s[3],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
		print("LAKE_SHOT ",stage," ",variant," ",s[0])
	if c.world.has_meta("yijian_garden"):report["landscape"]=c.world.get_meta("yijian_garden")
	var f=FileAccess.open(dir+"report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));quit()
