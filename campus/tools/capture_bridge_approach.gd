extends SceneTree

const OUT="res://../renders/bridge_approaches/"

func _initialize():call_deferred("run")

func run():
	var campus=load("res://scenes/campus_game.tscn").instantiate();root.add_child(campus)
	var saved=await capture(campus,root)
	quit(0 if saved else 1)

static func capture(campus:Node3D,viewport:Window)->bool:
	campus.player.frozen=true;campus.player.enabled=false;campus.hud.visible=false
	if campus.locator:campus.locator.visible=false
	if campus.hero_interactions:campus.hero_interactions.layer.hide()
	if campus.campus_agent:campus.campus_agent.layer.hide()
	campus.player.set_free_camera(true)
	viewport.size=Vector2i(1440,810)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var shots=[
		["east_bridge_fixed",Vector3(71.88,3.57,71.91),Vector3(70.10,.19,76.41)],
		["east_bridge_path",Vector3(75.3,2.5,81),Vector3(67.5,.3,75.5)]]
	var saved=true
	for shot in shots:
		campus.player.camera.global_position=shot[1]
		campus.player.camera.look_at(shot[2]);campus.player.camera.fov=66
		for i in range(16):await campus.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var result=viewport.get_texture().get_image().save_png(OUT+shot[0]+".png")
		saved=saved and result==OK
		print("BRIDGE_CAPTURE ",shot[0]," result=",result)
	return saved
