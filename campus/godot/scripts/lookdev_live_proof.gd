extends "res://scripts/north_axis_proof.gd"
## Same cameras/time/people for both scene variants, native Godot pixels only.
const LIVE="res://../renders/lookdev_live/"
func output()->String:return LIVE+"diorama_ab/" if "--compare-diorama" in OS.get_cmdline_user_args() else LIVE

func save(name:String,data):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output()))
	var f=FileAccess.open(output()+name,FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"))

func photography(c:Node3D,size:Vector2i):
	prepare(c)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output()))
	if not c.photo_view:
		c.photo_view=SubViewport.new();c.photo_view.world_3d=c.get_viewport().world_3d
		c.photo_view.msaa_3d=Viewport.MSAA_8X;c.photo_view.use_taa=true;c.photo_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;c.add_child(c.photo_view)
		c.photo_camera=Camera3D.new();c.photo_camera.near=.075;c.photo_camera.far=850;c.photo_view.add_child(c.photo_camera);c.photo_camera.current=true
		c.get_viewport().disable_3d=true
	c.photo_view.size=size

func shot(c:Node3D,id:String):
	match id:
		"hall":aim(c,Vector3(-28,1.79,149),Vector3(2,6.5,170),58,110)
		"axis":aim(c,Vector3(-1,1.77,105),Vector3(0,8,177),62,140)
		"photo":aim(c,Vector3(8.5,3.85,136.4),Vector3(10.4,1,140.8),42,90)
		"cyclist":aim(c,Vector3(50,4.25,153),Vector3(55.9,1,157),42,90)
		"reader":aim(c,Vector3(-23,3.95,223.4),Vector3(-27,1,218.8),42,90)
		_:super.shot(c,id)

func capture_stills(c:Node3D):
	photography(c,Vector2i(3840,2160))
	var shots=["hall","axis","gate","bridge","pavilion_front","pools","tiku","photo","cyclist","reader","raiden","march7","meituan","doubao","leaf_cat","whole","routes"]
	var report={"variant":"Diorama" if "--compare-diorama" in OS.get_cmdline_user_args() else "LookDev Live","resolution":[3840,2160],"shots":[],"same_content":true}
	for i in range(shots.size()):
		var id=shots[i];var t=walking_time(c,id) if c.wave2_layer.actors.has(id) else 3.0 if id=="tiku" else 30.0 if id=="cyclist" else 12.0
		pose(c,t);shot(c,id);c.wave2_layer.set_route_debug(id=="routes")
		for warm in range(36):await c.get_tree().process_frame
		var file="%02d_%s.png"%[i+1,id]
		await RenderingServer.frame_post_draw
		c.photo_view.get_texture().get_image().save_png(output()+file)
		var camera=c.photo_camera
		report.shots.append({"id":id,"file":file,"time":t,"camera":str(camera.global_transform),"fov":camera.fov,"projection":camera.projection,"size":camera.size,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
		print("LOOKDEV_STILL ",report.variant," ",file)
	save("capture_report.json",report);c.get_tree().quit()

func capture_motion(c:Node3D):
	photography(c,Vector2i(1280,720));DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output()+"motion_frames"))
	var report={"fps":12,"width":1280,"height":720,"frames":0,"segments":[]};var frame_no=0
	for id in ["hall","axis","bridge","raiden","march7","meituan","doubao","leaf_cat"]:
		var start=walking_time(c,id)-2 if c.wave2_layer.actors.has(id) else 18.0
		report.segments.append({"id":id,"first_frame":frame_no,"time":start,"seconds":8.0})
		for frame in range(96):
			pose(c,start+frame/12.0);shot(c,id)
			if c.wave2_layer.actors.has(id):actor_view(c,id,false)
			for warm in range(2):await c.get_tree().process_frame
			await RenderingServer.frame_post_draw
			c.photo_view.get_texture().get_image().save_jpg(output()+"motion_frames/frame_%04d.jpg"%frame_no,.94);frame_no+=1
		print("LOOKDEV_MOTION ",id)
	report.frames=frame_no;save("motion_manifest.json",report);c.get_tree().quit()
