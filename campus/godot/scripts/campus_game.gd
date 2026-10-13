extends "res://scripts/campus_performance.gd"

var game_ready=false
var balanced=true
var detail_batches:Array[GeometryInstance3D]=[]
var control_buttons:Array[Button]=[]

func use_lookdev()->bool:return true
func west_enabled()->bool:return true
func create_player()->CharacterBody3D:return preload("res://scripts/third_person_player.gd").new()
func write_spots():pass # Gameplay does not rewrite the historical photo reports.
func viewpoint(_i:int):pass # The game camera remains attached to the character.

func _ready():
	super._ready()
	game_ready=true
	player.respawn_position=Vector3(0,.16,12);player.respawn_target=Vector3(0,1.6,80)
	player.set_view(player.respawn_position,player.respawn_target)
	if "--plaza-focus" in OS.get_cmdline_user_args():
		player.set_view(Vector3(12,.16,258),Vector3(-.597,1.8,244.127))
	if "--north-campus-focus" in OS.get_cmdline_user_args():
		player.set_view(Vector3(170,.16,20),Vector3(199,2,6))
	if "--library-focus" in OS.get_cmdline_user_args():
		player.set_view(Vector3(20,.16,444),Vector3(2.1,6,430))
	if "--sports-focus" in OS.get_cmdline_user_args():
		player.set_view(Vector3(-187,.16,418),Vector3(-236,2,450))
	if "--south-sports-focus" in OS.get_cmdline_user_args():
		player.set_view(Vector3(-236,.16,589),Vector3(-207,1.5,607))
	spot_label.text="老北门 · 眼镜湖 · 一教 · 广场 · 五教 · 图书馆 · 运动场 · 东侧住宅 · 校史馆 · 南部科研区"
	reflectable(player.avatar)
	for n in world.get_children():
		if n is MultiMeshInstance3D:
			var asset=String(n.get_meta("render_asset",""))
			if "flower" in asset or "bank" in asset or "reeds" in asset or "lotus" in asset:detail_batches.append(n)
	apply_quality(not "--game-quality" in OS.get_cmdline_user_args())
	setup_building_occlusion()
	get_window().set_deferred("title","科大云宇宙 · 校园漫游 | 可操控人物")
	print("CLOUD_UNIVERSE_READY player=1 third_person=true detail_batches=",detail_batches.size())
	if "--release-smoke-test" in OS.get_cmdline_user_args():preload("res://scripts/release_smoke.gd").run(self)

func setup_building_occlusion():
	# These four opaque hall volumes block the buildings behind the main avenue.
	# Inset occluders stay inside the facade; the courtyard and entrances remain open.
	get_viewport().use_occlusion_culling=true
	if photo_view:photo_view.use_occlusion_culling=true
	if reflection_view:reflection_view.use_occlusion_culling=true
	for body in world.get_children():
		if not body is StaticBody3D or not String(body.name).begins_with("TeachingHall"):continue
		var collision=body.get_child(0)
		if not collision is CollisionShape3D or not collision.shape is BoxShape3D:continue
		var occluder=OccluderInstance3D.new();occluder.name="HallOcclusion_"+String(body.name)
		var box=BoxOccluder3D.new();box.size=collision.shape.size-Vector3(2,2,8)
		occluder.occluder=box;occluder.transform=body.transform;world.add_child(occluder)

func setup_hud():
	hud=CanvasLayer.new();add_child(hud)
	var root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(root)
	var theme=Theme.new();var font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei","Segoe UI"])
	theme.default_font=font;root.theme=theme
	var title=label("科大云宇宙 · 校园漫游",25,Color("fff9e5"));title.position=Vector2(28,22);root.add_child(title)
	spot_label=label("从老北门出发 · 樱花大道 → 双池与一鉴亭 → 第一教学楼",14,Color("edf1df"))
	spot_label.position=Vector2(28,60);root.add_child(spot_label)
	mode_label=label("",14,Color("fff9e5"));mode_label.position=Vector2(28,96);root.add_child(mode_label)
	var controls=HBoxContainer.new();controls.position=Vector2(28,130);root.add_child(controls)
	for choice in ["人物","自由相机"]:
		var button=Button.new();button.text=choice;button.toggle_mode=true;button.custom_minimum_size=Vector2(105,32)
		button.pressed.connect(func():player.set_free_camera(choice=="自由相机");Input.mouse_mode=Input.MOUSE_MODE_CAPTURED)
		controls.add_child(button);control_buttons.append(button)
	var copy=Button.new();copy.text="复制中心坐标";copy.pressed.connect(func():locator.copy_position());controls.add_child(copy)
	var destinations=OptionButton.new();destinations.text="选择查看区域";controls.add_child(destinations)
	for destination in ["老北门", "广场", "五教／新北门", "图书馆", "运动场", "南侧球场", "东侧住宅", "校史馆／行政楼", "南部科研楼群"]:destinations.add_item(destination)
	destinations.item_selected.connect(func(i):
		var locations=[[Vector3(0,.16,12),Vector3(0,1.6,80)],[Vector3(12,.16,258),Vector3(-.597,1.8,244.127)],
			[Vector3(170,.16,20),Vector3(199,2,6)],[Vector3(20,.16,444),Vector3(2.1,6,430)],
			[Vector3(-187,.16,418),Vector3(-236,2,450)],[Vector3(-236,.16,589),Vector3(-207,1.5,607)],
			[Vector3(255,.16,406),Vector3(225,4,414)],[Vector3(55.7,.16,523),Vector3(25,5,523)],
			[Vector3(97.6,.16,713.3),Vector3(165,28,707)]]
		player.set_view(locations[i][0],locations[i][1]);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED)
	var help=label("WASD 移动    Shift 加速    Space 人物跳跃    V 人物/自由相机    Q/E 相机下降/上升    滚轮 调整相机速度/距离\nTab 第一/第三人称    Esc 释放鼠标    R 北门    2—9 区域跳转    C 坐标    F 界面    F12 截图+坐标记录",14,Color("edf1df"))
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);help.position=Vector2(28,-64);root.add_child(help)

func _process(dt):
	super._process(dt)
	if not game_ready:return
	for i in range(control_buttons.size()):control_buttons[i].set_pressed_no_signal(player.free_camera if i==1 else not player.free_camera)
	if player.free_camera:
		mode_label.text="自由相机 · %.1f m/s · %s · %d FPS"%[player.fly_speed,"流畅" if balanced else "精细",Engine.get_frames_per_second()];return
	mode_label.text="%s · %s · %.1f m/s   |   %s   |   %d FPS"%[
		"第三人称" if player.third_person else "第一人称",
		{"idle":"站立","walk":"行走","run":"跑步","jump":"起跳","fall":"下落"}[player.avatar.locomotion],
		Vector2(player.velocity.x,player.velocity.z).length(),"流畅" if balanced else "精细",Engine.get_frames_per_second()]
	if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:mode_label.text+="\n单击画面开始操控"

func _unhandled_input(e):
	if not game_ready:return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_R:player.set_view(player.respawn_position,player.respawn_target)
			KEY_2:player.set_view(Vector3(12,.16,258),Vector3(-.597,1.8,244.127))
			KEY_3:player.set_view(Vector3(170,.16,20),Vector3(199,2,6))
			KEY_4:player.set_view(Vector3(20,.16,444),Vector3(2.1,6,430))
			KEY_5:player.set_view(Vector3(-187,.16,418),Vector3(-236,2,450))
			KEY_6:player.set_view(Vector3(-236,.16,589),Vector3(-207,1.5,607))
			KEY_7:player.set_view(Vector3(255,.16,406),Vector3(225,4,414))
			KEY_8:player.set_view(Vector3(55.7,.16,523),Vector3(25,5,523))
			KEY_9:player.set_view(Vector3(97.6,.16,713.3),Vector3(165,28,707))
			KEY_F:hud.visible=not hud.visible
			KEY_F3:apply_quality(not balanced)
			KEY_F12:capture("game_%d"%Time.get_unix_time_from_system())

func apply_quality(use_balanced:bool):
	balanced=use_balanced
	if reflection_view:reflection_view.size=Vector2i(512,288) if balanced else Vector2i(768,432)
	sun.directional_shadow_max_distance=100 if balanced else 180
	# The default 20 m caster slab clips the U-shaped hall at the first split.
	# Include the complete hall and 64 m north towers in every shadow cascade.
	sun.directional_shadow_pancake_size=120.0
	sun.directional_shadow_blend_splits=true
	for n in detail_batches:
		n.visibility_range_end=90.0 if balanced else 0.0
		n.visibility_range_end_margin=8.0 if balanced else 0.0
	reflection_elapsed=1.0

func update_reflection():
	if not game_ready or not balanced:
		super.update_reflection();return
	reflection_elapsed+=get_process_delta_time()
	# The water uses a coherent texture/projector pair; cap its second scene pass.
	if reflection_elapsed>=1.0/30.0:
		render_reflection_frame()
		reflection_view.render_target_update_mode=SubViewport.UPDATE_ONCE
		reflection_elapsed=0
