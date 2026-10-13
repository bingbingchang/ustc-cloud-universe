extends SceneTree
func _initialize():call_deferred("run")
func run():
	var args=OS.get_cmdline_user_args()
	var variant="diorama" if "--sakura-diorama" in args else "live"
	var stage="before" if "--sakura-before" in args else "after"
	if "--sakura-sample" in args:stage="sample"
	var dir="res://../renders/sakura_avenue/"+stage+"_"+variant+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var c=load("res://scenes/diorama.tscn" if variant=="diorama" else "res://scenes/lookdev_live.tscn").instantiate();root.add_child(c)
	await process_frame
	var proof=load("res://scripts/north_axis_proof.gd").new();proof.prepare(c);proof.pose(c,12.0)
	c.photo_view=SubViewport.new();c.photo_view.world_3d=c.get_viewport().world_3d;c.photo_view.size=Vector2i(1920,1080)
	c.photo_view.msaa_3d=Viewport.MSAA_4X;c.photo_view.use_taa=true;c.photo_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;c.add_child(c.photo_view)
	c.photo_camera=Camera3D.new();c.photo_camera.near=.075;c.photo_camera.far=850;c.photo_view.add_child(c.photo_camera);c.photo_camera.current=true;c.get_viewport().disable_3d=true
	var shots=[
		["01_avenue",Vector3(-.7,1.8,68),Vector3(0,6.8,170),56.0],
		["02_human",Vector3(-1,1.77,105),Vector3(0,8,177),62.0],
		["03_layering",Vector3(-4.8,2.3,90),Vector3(9,3.8,111),60.0],
		["04_gate",Vector3(.8,1.8,42),Vector3(0,3.2,3),58.0],
		["05_garden",Vector3(9.4,1.85,106),Vector3(43,3.5,81),60.0],
		["06_overview",Vector3(-100,115,-20),Vector3(6,0,94),48.0]]
	if "--sakura-quick" in args:shots=shots.slice(0,2)
	var report={"variant":variant,"stage":stage,"native_pixels":true,"resolution":[1920,1080],"shots":[]}
	for s in shots:
		proof.aim(c,s[1],s[2],s[3],260)
		for i in range(20):await process_frame
		await RenderingServer.frame_post_draw
		c.photo_view.get_texture().get_image().save_png(dir+s[0]+".png")
		report.shots.append({"file":s[0]+".png","position":str(s[1]),"target":str(s[2]),"fov":s[3],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
		print("SAKURA_SHOT ",stage," ",variant," ",s[0])
	if c.world.has_meta("sakura_avenue"):report["landscape"]=c.world.get_meta("sakura_avenue")
	var f=FileAccess.open(dir+"report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));quit()
