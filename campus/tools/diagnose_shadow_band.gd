extends SceneTree
const OUT="res://../renders/shadow_band/"
func _initialize():call_deferred("run")
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var c=load("res://scenes/campus_game.tscn").instantiate();root.add_child(c)
	await process_frame
	c.hud.visible=false;c.player.frozen=true
	var cam=Camera3D.new();c.add_child(cam);cam.current=true;c.photo_camera=cam
	cam.fov=66
	var report=[]
	for view in [["court",Vector3(0,4.6,206),Vector3(0,.5,192)],["court_back",Vector3(0,4.6,214),Vector3(0,.5,201)]]:
		cam.position=view[1];cam.look_at(view[2],Vector3.UP)
		for test in [["ortho",false,20.0,0],["ortho_no_pancake",false,0.0,0],["pancake60",true,60.0,2],["pancake100",true,100.0,2]]:
			c.sun.directional_shadow_mode=test[3]
			c.sun.directional_shadow_blend_splits=test[1];c.sun.directional_shadow_pancake_size=test[2]
			for i in range(24):await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+view[0]+"_"+test[0]+".png")
			report.append({"view":view[0],"case":test[0],"blend":test[1],"pancake":test[2],"distance":c.sun.directional_shadow_max_distance})
			print("SHADOW_DIAG ",view[0]," ",test[0])
	var f=FileAccess.open(OUT+"diagnosis.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"))
	quit()
