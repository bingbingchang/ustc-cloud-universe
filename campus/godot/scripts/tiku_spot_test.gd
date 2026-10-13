extends "res://scripts/diorama.gd"
func _ready():
	super._ready();call_deferred("test_spots")
func test_spots():
	player.enabled=false;player.frozen=true;hud.visible=false
	photo_view=SubViewport.new();photo_view.size=Vector2i(900,1100);photo_view.world_3d=get_world_3d();photo_view.msaa_3d=Viewport.MSAA_4X;photo_view.use_taa=true;photo_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(photo_view)
	photo_camera=Camera3D.new();photo_view.add_child(photo_camera);photo_camera.current=true;get_viewport().disable_3d=true
	var points=[Vector3(-10,1,151.8),Vector3(-10,.93,148),Vector3(-3.4,.978,134),Vector3(3.4,.978,145)]
	for i in range(points.size()):
		life_layer.actors.roadside.root.position=points[i];life_layer.manual_time=9.6
		photo_camera.position=points[i]+Vector3(-1.6,.8,-2.7);photo_camera.look_at(points[i]+Vector3(0,.20,0));photo_camera.fov=40
		for j in range(20):await get_tree().process_frame
		await capture("tiku_identity/spot_test_%d"%i)
	get_tree().quit()
