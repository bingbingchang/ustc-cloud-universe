extends CanvasLayer
var game
var root:Control
var movement_finger=-1
var look_finger=-1
var origin=Vector2.ZERO
var look_position=Vector2.ZERO
var joystick:Control
var buttons:HBoxContainer
var previous_size=Vector2.ZERO
var resize_clock=0.0
var previous_loading=false

func _ready():
	layer=25;root=Control.new();root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root)
	var theme=Theme.new();theme.default_font=preload("res://scripts/campus_font.gd").get_font();root.theme=theme
	game.player.touch_mode=bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0 && window.matchMedia('(pointer:coarse)').matches",true)) if OS.has_feature("web") else "--touch-test" in OS.get_cmdline_user_args()
	if game.player.touch_mode:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if OS.has_feature("web"):
		get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
		get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
		update_canvas_size()
	for panel in [game.hero_interactions.panel,game.hero_interactions.journal,game.hero_interactions.source_panel,game.hero_interactions.api_panel,game.campus_agent.panel]:
		var content=panel.get_child(0);panel.remove_child(content)
		if panel==game.hero_interactions.journal:
			var title=content.get_child(0);content.remove_child(title)
			var header=HBoxContainer.new();content.add_child(header);content.move_child(header,0)
			header.add_child(title);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var close=Button.new();close.text="关闭";close.pressed.connect(game.hero_interactions.close_ui);header.add_child(close)
		var scroll=ScrollContainer.new();scroll.set_meta("web_modal_scroll",true)
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true
		panel.add_child(scroll);scroll.add_child(content);content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.size_flags_vertical=Control.SIZE_EXPAND_FILL
	joystick=Control.new();joystick.mouse_filter=Control.MOUSE_FILTER_IGNORE;joystick.size=Vector2(136,136);root.add_child(joystick)
	joystick.draw.connect(func():
		joystick.draw_circle(Vector2(68,68),64,Color(.05,.12,.09,.35))
		joystick.draw_circle(Vector2(68,68)+game.player.touch_move*40,24,Color(.93,.95,.82,.72)))
	buttons=HBoxContainer.new();buttons.add_theme_constant_override("separation",10);root.add_child(buttons)
	for spec in [["跳跃",func():game.player.touch_jump=true],["交谈",func():
		if not game.hero_interactions.nearest.is_empty():game.hero_interactions.open_dialogue(game.hero_interactions.nearest)],
		["人物",func():game.hero_interactions.toggle_journal()],["向导",func():game.campus_agent.toggle_panel()]]:
		var button=Button.new();button.text=spec[0];button.custom_minimum_size=Vector2(68,56);button.pressed.connect(spec[1]);buttons.add_child(button)
	joystick.visible=game.player.touch_mode
	get_viewport().size_changed.connect(layout);layout()

func layout():
	var size=get_viewport().get_visible_rect().size
	if previous_size!=Vector2.ZERO and previous_size!=size:clear_fingers()
	previous_size=size
	joystick.position=Vector2(24,size.y-160);buttons.position=Vector2(size.x-338,size.y-78)
	var heroes=game.hero_interactions
	var top=112.0 if game.streaming.downloading or not game.streaming.failures.is_empty() else 64.0
	if size.y<350:top=16.0
	var rect=Rect2(Vector2(16,top),size-Vector2(32,top+16))
	for panel in [heroes.panel,heroes.journal,heroes.source_panel,heroes.api_panel,game.campus_agent.panel]:
		panel.position=rect.position;panel.custom_minimum_size=Vector2.ZERO;panel.size=rect.size
		for control in panel.find_children("*","Control",true,false):
			if control is ScrollContainer:control.custom_minimum_size=Vector2.ZERO if control.has_meta("web_modal_scroll") else Vector2(0,90)
			elif control is RichTextLabel:control.custom_minimum_size=Vector2(0,90)
			elif control is Label:
				control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
				control.add_theme_font_size_override("font_size",18 if game.player.touch_mode else 16)
			elif control is Button or control is LineEdit:
				control.custom_minimum_size.y=44 if game.player.touch_mode else 38
				control.add_theme_font_size_override("font_size",18 if game.player.touch_mode else 16)
	heroes.endpoint_input.hide()
	for button in heroes.journal.find_children("*","Button",true,false):
		if button.text=="连接服务":button.hide()
	heroes.prompt_label.position=Vector2(size.x*.4,size.y-115)
	# The compact bottom bar owns these actions on the Web; hide native fixed
	# coordinates so they cannot overlap small-screen dialogue panels.
	for child in heroes.layer.get_child(0).get_children():
		if child is HBoxContainer:child.hide()
	for child in game.campus_agent.layer.get_child(0).get_children():
		if child is Button:child.hide()
	# Container minimum sizes settle after child overrides and hidden rows.
	# reset_size() would shrink dialogue to its minimum width and clip rosters.
	fit_panels.call_deferred(rect)

func fit_panels(rect:Rect2):
	await get_tree().process_frame
	for panel in [game.hero_interactions.panel,game.hero_interactions.journal,game.hero_interactions.source_panel,game.hero_interactions.api_panel,game.campus_agent.panel]:
		panel.position=rect.position;panel.size=rect.size

func clear_fingers():
	movement_finger=-1;look_finger=-1;look_position=Vector2.ZERO;game.player.clear_touch()
	if is_instance_valid(joystick):joystick.queue_redraw()

func release_finger(index:int)->bool:
	var owned=false
	if index==movement_finger:
		movement_finger=-1;game.player.touch_move=Vector2.ZERO;joystick.queue_redraw();owned=true
	if index==look_finger:look_finger=-1;look_position=Vector2.ZERO;owned=true
	return owned

func _input(event):
	if not game.player.touch_mode:return
	# Finish owned gestures before GUI handling, even if the finger moved over
	# a button. New gestures are claimed later, after GUI has had first choice.
	if event is InputEventScreenTouch and (not event.pressed or event.canceled):
		if release_finger(event.index):get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if not game.player.enabled:clear_fingers();return
		if event.index==movement_finger:
			game.player.touch_move=((event.position-origin)/55.0).limit_length();joystick.queue_redraw()
			get_viewport().set_input_as_handled()
		elif event.index==look_finger:
			# Web changedTouches order is not stable between DOM events. Engine
			# relative can use another finger's previous position (batch slot).
			# Track the owned look finger from its own absolute touch-down point.
			var motion=event.position-look_position
			look_position=event.position
			game.player.touch_look(motion);get_viewport().set_input_as_handled()

func _process(_delta):
	resize_clock+=_delta
	if OS.has_feature("web") and resize_clock>.3:update_canvas_size();resize_clock=0
	var loading=game.streaming.downloading or not game.streaming.failures.is_empty()
	if loading!=previous_loading:previous_loading=loading;layout()
	var modal=game.hero_interactions.modal_active or game.campus_agent.panel_open
	joystick.visible=game.player.touch_mode and not modal;buttons.visible=not modal
	if not game.player.enabled:clear_fingers()

func update_canvas_size():
	var values=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify([window.innerWidth,window.innerHeight])",true)))
	if not values is Array or values.size()!=2:return
	var pixels=Vector2(maxf(320,float(values[0])),maxf(160,float(values[1])))
	var factor=minf(1.0,minf(1280.0/pixels.x,720.0/pixels.y))
	var target=Vector2i(pixels*factor)
	if get_window().content_scale_size!=target:get_window().content_scale_size=target

func _unhandled_input(event):
	if not game.player.enabled or not game.player.touch_mode:return
	var size=get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:return
		if event.index==movement_finger or event.index==look_finger:return
		if is_instance_valid(buttons) and buttons.visible and buttons.get_global_rect().has_point(event.position):return
		if event.position.x<size.x*.44 and event.position.y>size.y*.4 and movement_finger<0:
			movement_finger=event.index;origin=event.position
			get_viewport().set_input_as_handled()
		elif event.position.x>size.x*.44 and look_finger<0:
			look_finger=event.index;look_position=event.position
			get_viewport().set_input_as_handled()

func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(game):clear_fingers()
