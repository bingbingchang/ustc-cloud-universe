extends "res://scripts/campus_game.gd"
## Web uses baked static regions; none of the native synchronous map builders
## are called. Native Forward+ keeps its existing main scene and ENet session.
const WEB_SCENE_FADE_DISTANCE := Vector2(110.0, 214.0)

var streaming
var touch_controls
var water_surfaces=[]
var water_entry_barriers: Array[WeakRef] = []
var water_check_clock=0.0
var water_visible=false
var shader_warmup
var web_text_input
func is_streamed_web()->bool:return true

func _ready():
	game_ready=false;lookdev_mode=true;balanced=true;rng.seed=1958
	get_viewport().disable_3d=true
	site=JSON.parse_string(FileAccess.get_file_as_string("res://assets/site.json"))
	setup_input();world=Node3D.new();world.name="StreamedCampus";add_child(world)
	setup_materials();setup_environment();setup_study_light();setup_reflection();study_ready=true
	# Web already uses the sky environment and visible-water planar reflection.
	# Two native probes otherwise capture the entire streamed scene six times each on entry.
	for child in get_children():
		if child is ReflectionProbe:child.queue_free()
	reflection_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS;sun.directional_shadow_max_distance=75
	get_viewport().msaa_3d=Viewport.MSAA_2X;get_viewport().use_taa=false;get_viewport().mesh_lod_threshold=2
	live_environment.ssil_enabled=false;live_environment.ssr_enabled=false
	live_environment.sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
	player=create_player();add_child(player);player.enabled=false;player.frozen=true
	player.camera.cull_mask &= ~REFLECTION_LAYER
	configure_scene_fade()
	setup_hud()
	locator=preload("res://scripts/scene_locator.gd").new();locator.campus=self;add_child(locator);locator.hide()
	streaming=preload("res://scripts/web_regions.gd").new();streaming.game=self;add_child(streaming)
	shader_warmup=preload("res://scripts/web_shader_warmup.gd").new();shader_warmup.game=self;add_child(shader_warmup)
	for id in ["global","0_0","-1_0"]:
		while not streaming.loaded.has(id):
			if streaming.failures.has(id):await streaming.changed
			else:await streaming.ensure(id)
	await get_tree().physics_frame
	player.respawn_position=Vector3(0,.16,12);player.respawn_target=Vector3(0,1.6,80)
	player.set_view(player.respawn_position,player.respawn_target)
	hero_interactions=preload("res://scripts/hero_interactions.gd").new();hero_interactions.game=self;add_child(hero_interactions)
	campus_agent=preload("res://scripts/campus_agent.gd").new();campus_agent.game=self;add_child(campus_agent)
	touch_controls=preload("res://scripts/web_controls.gd").new();touch_controls.game=self;add_child(touch_controls)
	web_text_input=preload("res://scripts/web_text_input.gd").new();web_text_input.game=self;add_child(web_text_input)
	streaming.notify("warming","正在准备人物与交谈界面…")
	await hero_interactions.prewarm_web_dialogue()
	for id in streaming.loaded:
		await shader_warmup.prepare_tree(streaming.loaded[id],id)
		streaming.loaded[id].show()
	await shader_warmup.prepare_tree(player,"player")
	get_viewport().disable_3d=false
	streaming.notify("shaders","正在完成首帧画面…")
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	player.frozen=false;player.enabled=true
	game_ready=true;mode_label.text="点击画面开始漫游 · WASD 移动 · J 人物 · K 向导"
	setup_net()
	streaming.notify("ready","校园已就绪",1)
	# Core skyline and nearby regions are queued after actual first-frame readiness.
	print("CAMPUS_WEB_READY initial_regions=",streaming.loaded.size())

func setup_hud():
	hud=CanvasLayer.new();add_child(hud)
	var column=VBoxContainer.new();column.position=Vector2(16,14);hud.add_child(column)
	var theme=Theme.new();theme.default_font=preload("res://scripts/campus_font.gd").get_font();column.theme=theme
	var title=Label.new();title.text="科大云宇宙 · 校园漫游";title.add_theme_font_size_override("font_size",22);column.add_child(title)
	mode_label=Label.new();mode_label.text="正在准备老北门与樱花路…";mode_label.add_theme_font_size_override("font_size",14);column.add_child(mode_label)
	spot_label=Label.new();spot_label.hide();column.add_child(spot_label)

func _process(delta):
	elapsed+=delta
	if not game_ready:return
	update_scene_fade()
	if sun:sun.rotation_degrees=Vector3(-43,-131,0);sun.light_color=Color(1,.94,.81);sun.light_energy=1.95
	reflection_elapsed+=delta
	water_check_clock+=delta
	if water_check_clock>.25:
		water_check_clock=0;water_visible=screen_has_water()
	if reflection_elapsed>.15 and water_visible and not (hero_interactions.modal_active or campus_agent.panel_open):
		render_reflection_frame();reflection_view.render_target_update_mode=SubViewport.UPDATE_ONCE;reflection_elapsed=0
	else:reflection_view.render_target_update_mode=SubViewport.UPDATE_DISABLED

func scene_fade_distance(_camera: Camera3D) -> Vector2:
	return WEB_SCENE_FADE_DISTANCE

func screen_has_water()->bool:
	var camera=get_viewport().get_camera_3d()
	if not camera:return false
	var bounds=[]
	for surface in water_surfaces:
		var node=surface.get_ref()
		if is_instance_valid(node):bounds.append(node.global_transform*node.get_aabb())
	if bounds.is_empty():return false
	var size=get_viewport().get_visible_rect().size
	var space=get_world_3d().direct_space_state
	var exclusions: Array[RID] = [player.get_rid()]
	water_entry_barriers=water_entry_barriers.filter(func(barrier):return is_instance_valid(barrier.get_ref()))
	for barrier in water_entry_barriers:exclusions.append(barrier.get_ref().get_rid())
	for row in range(4):
		for column in range(7):
			var pixel=size*Vector2((column+.5)/7.0,.4+row*.15)
			var origin=camera.project_ray_origin(pixel);var direction=camera.project_ray_normal(pixel)
			if direction.y>=-.001:continue
			for box in bounds:
				var distance=(box.get_center().y-origin.y)/direction.y
				if distance<=.05 or distance>camera.far:continue
				var point=origin+direction*distance
				if point.x<box.position.x or point.x>box.end.x or point.z<box.position.z or point.z>box.end.z:continue
				var query=PhysicsRayQueryParameters3D.create(origin,point+Vector3.UP*.06,1,exclusions)
				if space.intersect_ray(query).is_empty():
					reflection_plane_height=box.get_center().y
					return true
	return false

func _unhandled_input(event):
	if not game_ready:return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_R:
		if await streaming.ensure_at(player.respawn_position):player.set_view(player.respawn_position,player.respawn_target)

func setup_net():
	if not OS.has_feature("web"):return
	var room=preload("res://scripts/web_room_sync.gd").new()
	room.game=self
	add_child(room)
