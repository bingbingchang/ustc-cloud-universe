extends "res://scripts/campus_performance.gd"

var game_ready=false
var balanced=true
var detail_batches:Array[GeometryInstance3D]=[]
var control_buttons:Array[Button]=[]
# --- 最小联机（仅当传入 --net-host / --net-join 时才创建） ---
var net
var remote_peers={}
var net_prune_clock=0.0
var net_state_count=0
var net_selftest=false
var net_motion_clock=0.0
var net_report_clock=0.0
var chat_log:RichTextLabel
var chat_input:LineEdit
var net_status:Label
var net_theme:Theme
var hero_interactions
var campus_agent

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
	setup_net()
	hero_interactions=preload("res://scripts/hero_interactions.gd").new()
	hero_interactions.game=self;hero_interactions.name="KnowledgeHeroes";add_child(hero_interactions)
	campus_agent=preload("res://scripts/campus_agent.gd").new()
	campus_agent.game=self;campus_agent.name="CampusGuideAgent";add_child(campus_agent)
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
	if net:
		net_prune_clock+=dt
		if net_prune_clock>=1.0:
			net_prune_clock=0.0
			prune_remote_peers()
	if net_selftest and net:
		# 自检时让本地角色沿广场绕圈，这样状态包的内容会持续变化，
		# 远端才能看到「真的在动」而不只是收到一串静止坐标。
		net_motion_clock+=dt
		player.global_position.x=24.0*sin(net_motion_clock*.6)
		player.global_position.z=258.0+18.0*cos(net_motion_clock*.6)
		net_report_clock+=dt
		if net_report_clock>=5.0:
			net_report_clock=0.0
			print("NET_STATE_REPORT from=%s remote_avatars=%d states_recv=%d" % [
				net.local_name,remote_peers.size(),net_state_count])
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
	if campus_agent and campus_agent.panel_open:return
	if hero_interactions and (hero_interactions.panel.visible or hero_interactions.journal.visible):return
	if e is InputEventKey and e.pressed and not e.echo:
		if net and e.keycode in [KEY_ENTER,KEY_KP_ENTER]:
			toggle_chat_focus();get_viewport().set_input_as_handled();return
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

# ============================================================================
# 最小联机版本
# ----------------------------------------------------------------------------
# 设计目标：证明「真人可以同时出现在同一场景里」，而不是做完整网游。
# 因此只做三件事：ENet 主机/加入、远端玩家位置与朝向复制、文字聊天。
# 全部 opt-in：不传 --net-* 参数时本段代码完全不会执行，单机行为不变。
#
# 用法：
#   A 机（主机）：--net-host            或 --net-host=45888
#   B 机（加入）：--net-join=192.168.1.5 或 --net-join=192.168.1.5:45888
#   可选：--net-name=你的名字
#   回车键打开/发送聊天，Esc 或再次回车收回鼠标。
# ============================================================================

func local_net_state()->Array:
	# 远端玩家只需要「位置 / 朝向 / 速度 / 是否着地」这四样东西，
	# 因为 player_avatar.gd 的 animate() 正好吃这四个参数。
	var heading=player.avatar.rotation.y if player.avatar else player.rotation.y
	return [player.global_position.x,player.global_position.y,player.global_position.z,
		heading,Vector2(player.velocity.x,player.velocity.z).length(),
		player.velocity.y,1.0 if player.is_on_floor() else 0.0]

func setup_net():
	var host_mode=false
	var address=""
	var port=45888
	var display_name="同学"
	for a in OS.get_cmdline_user_args():
		if a=="--net-host":
			host_mode=true
		elif a.begins_with("--net-host="):
			host_mode=true
			port=int(a.trim_prefix("--net-host="))
		elif a.begins_with("--net-join="):
			var v=a.trim_prefix("--net-join=")
			if ":" in v:
				var parts=v.split(":")
				address=parts[0]
				port=int(parts[1])
			else:
				address=v
		elif a.begins_with("--net-name="):
			display_name=a.trim_prefix("--net-name=")
		elif a=="--net-selftest":
			net_selftest=true
	if not host_mode and address=="":
		return
	setup_net_hud()
	net=preload("res://scripts/net_session.gd").new()
	net.name="NetSession"
	add_child(net)
	net.peer_state.connect(_on_peer_state)
	net.peer_joined.connect(_on_peer_joined)
	net.peer_left.connect(_on_peer_left)
	net.chat_message.connect(_on_chat_message)
	net.connected_ok.connect(func():_net_say("—— 已连接到主机 ——"))
	net.session_ended.connect(func(reason:String):_net_say("—— "+reason+" ——"))
	if not net.setup(host_mode,address,port,display_name):
		_net_say("—— 无法建立会话，检查地址/端口，或端口是否被占用 ——")
		net.queue_free()
		net=null
		return
	net.set_state_provider(Callable(self,"local_net_state"))
	_net_say("—— 你是%s，%s ——" % ["主机" if host_mode else "客户端",("%s:%d" % [address,port]) if not host_mode else "端口 %d"%port])
	_update_net_status()
	print("CAMPUS_GAME_NET mode=%s port=%d name=%s" % ["host" if host_mode else "client",port,display_name])
	if net_selftest:call_deferred("_net_selftest")

func _net_selftest():
	# 纯自动化自检：不用人手操作就能验证「状态复制 + 聊天往返」两条链路。
	await get_tree().create_timer(4.0).timeout
	if not net:return
	net.send_chat("自检消息A-from-"+net.local_name)
	print("NET_SELFTEST_SENT round=A from=%s peers=%d" % [net.local_name,net.remote_peer_ids().size()])
	await get_tree().create_timer(16.0).timeout
	if not net:return
	net.send_chat("自检消息B-from-"+net.local_name)
	print("NET_SELFTEST_SENT round=B from=%s peers=%d" % [net.local_name,net.remote_peer_ids().size()])
	await get_tree().create_timer(6.0).timeout
	var telemetry=[]
	for id in remote_peers:telemetry.append({str(id):remote_peers[id].telemetry()})
	print("NET_SELFTEST_REPORT from=%s remote_avatars=%d states_recv=%d telemetry=%s" % [
		net.local_name if net else "?",remote_peers.size(),net_state_count,JSON.stringify(telemetry)])

func setup_net_hud():
	if not hud:return
	net_theme=Theme.new()
	var font=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei","Segoe UI"])
	net_theme.default_font=font
	chat_log=RichTextLabel.new()
	chat_log.bbcode_enabled=false
	chat_log.scroll_following=true
	chat_log.position=Vector2(28,215)
	chat_log.size=Vector2(470,500)
	chat_log.mouse_filter=Control.MOUSE_FILTER_IGNORE
	chat_log.add_theme_font_size_override("normal_font_size",14)
	chat_log.add_theme_color_override("default_color",Color("edf1df"))
	chat_log.theme=net_theme
	hud.add_child(chat_log)
	chat_input=LineEdit.new()
	chat_input.placeholder_text="回车打开聊天，再按回车发送"
	chat_input.position=Vector2(28,175)
	chat_input.size=Vector2(470,32)
	chat_input.max_length=200
	chat_input.theme=net_theme
	chat_input.text_submitted.connect(_on_chat_submitted)
	hud.add_child(chat_input)
	net_status=label("联机中",14,Color("fff9e5"))
	net_status.position=Vector2(28,722)
	hud.add_child(net_status)

func _on_chat_submitted(text:String):
	if not net:return
	chat_input.text=""
	chat_input.release_focus()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if text.strip_edges()!="":
		net.send_chat(text)

func toggle_chat_focus():
	if not chat_input:return
	if chat_input.has_focus():
		var text=chat_input.text
		chat_input.text=""
		chat_input.release_focus()
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		if text.strip_edges()!="" and net:net.send_chat(text)
	else:
		chat_input.grab_focus()
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _on_peer_joined(id:int)->void:
	_net_say("玩家 %d 加入" % id)
	_update_net_status()

func _on_peer_left(id:int)->void:
	drop_remote_peer(id)
	_net_say("玩家 %d 离开" % id)
	_update_net_status()

func _on_peer_state(id:int,state:Array)->void:
	if not remote_peers.has(id):
		# 必须挂在校园根节点下：player_avatar.gd 里会调用 get_parent().get_parent().style()
		var remote:Node3D=preload("res://scripts/remote_player.gd").new()
		remote.name="Remote_%d" % id
		add_child(remote)
		remote_peers[id]=remote
		_net_say("玩家 %d 进入场景" % id)
	remote_peers[id].apply_state(state)
	net_state_count+=1
	_update_net_status()

func drop_remote_peer(id:int)->void:
	if remote_peers.has(id):
		var node=remote_peers[id]
		remote_peers.erase(id)
		node.queue_free()

func prune_remote_peers()->void:
	var now=float(Time.get_ticks_msec())/1000.0
	for id in remote_peers.keys():
		if remote_peers[id].stale(now):
			drop_remote_peer(id)
			_net_say("玩家 %d 超时移除" % id)
	_update_net_status()

func _on_chat_message(sender_name:String,text:String)->void:
	_net_say("%s：%s" % [sender_name,text])

func _net_say(text:String)->void:
	print("NET_CHAT ",text)
	if chat_log:chat_log.append_text(text+"\n")

func _update_net_status()->void:
	if not net_status or not net:return
	var peers=net.remote_peer_ids().size()
	net_status.text="联机 · %s · 在线 %d 人（含自己 %d 人） · 回车聊天" % [
		"主机" if net.hosting else "客户端",peers+1,remote_peers.size()+1]
