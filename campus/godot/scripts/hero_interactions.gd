extends Node
## Client owns per-NPC histories. The server owns retrieval and model credentials.
var game
var definitions:Array=[]
var actors:Dictionary={}
var histories:Dictionary={}
var completed:Dictionary={}
var active_id=""
var nearest=""
var base_url="http://127.0.0.1:8787"
var layer:CanvasLayer
var panel:PanelContainer
var journal:PanelContainer
var transcript:RichTextLabel
var question:LineEdit
var send_button:Button
var heading:Label
var progress_label:Label
var prompt_label:Label
var status_label:Label
var suggestions:HBoxContainer
var endpoint_input:LineEdit
var chat_request:HTTPRequest
var health_request:HTTPRequest
var busy=false
var pending_question=""
var pending_id=""
var cancelled=false
var dialogue_camera:Camera3D
var portrait_light:DirectionalLight3D
var source_panel:PanelContainer
var source_text:RichTextLabel
var source_button:Button
var last_sources:Dictionary={}
var modal_active=false
var locator_before_modal=true
var roster:VBoxContainer
var search_input:LineEdit
var roster_buttons:Dictionary={}

func _ready():
	definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/hero_npcs.json"))
	if OS.has_environment("CAMPUS_AI_URL"):base_url=OS.get_environment("CAMPUS_AI_URL").trim_suffix("/")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ai-url="):base_url=arg.trim_prefix("--ai-url=").trim_suffix("/")
	for hero in definitions:
		var actor=preload("res://scripts/hero_actor.gd").new();actor.definition=hero;actor.name="Hero_"+hero.id
		actor.player=game.player;actor.position=Vector3(hero.position[0],hero.position[1],hero.position[2]);game.world.add_child(actor)
		actors[hero.id]=actor;histories[hero.id]=[]
	build_ui()
	chat_request=HTTPRequest.new();chat_request.timeout=100;add_child(chat_request)
	chat_request.request_completed.connect(on_answer)
	health_request=HTTPRequest.new();health_request.timeout=15;add_child(health_request)
	health_request.request_completed.connect(on_health)
	check_health()
	dialogue_camera=Camera3D.new();dialogue_camera.fov=54;game.add_child(dialogue_camera)
	portrait_light=DirectionalLight3D.new();portrait_light.name="SoftPortraitFill";portrait_light.light_color=Color("e4e9e4");portrait_light.hide()
	portrait_light.light_energy=.55;portrait_light.light_cull_mask=16
	dialogue_camera.add_child(portrait_light)
	print("HERO_NPCS_READY count=",actors.size()," endpoint=",base_url)
	if "--heroes-focus" in OS.get_cmdline_user_args():toggle_journal()

func button(text:String,callback:Callable)->Button:
	var b=Button.new();b.text=text;b.pressed.connect(callback);return b

func card(at:Vector2,size:Vector2)->PanelContainer:
	var p=PanelContainer.new();p.position=at;p.size=size
	var style=StyleBoxFlat.new();style.bg_color=Color(.035,.065,.10,.97)
	style.set_border_width_all(1);style.border_color=Color("647e91");style.set_corner_radius_all(12)
	style.content_margin_left=22;style.content_margin_right=22;style.content_margin_top=18;style.content_margin_bottom=18
	p.add_theme_stylebox_override("panel",style);return p

func build_ui():
	layer=CanvasLayer.new();layer.layer=30;add_child(layer)
	var root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(root)
	var theme=Theme.new();var font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei","Segoe UI"])
	theme.default_font=font;theme.default_font_size=17;root.theme=theme
	var top=HBoxContainer.new();top.position=Vector2(28,178);root.add_child(top)
	top.add_child(button("知识英雄 · J",toggle_journal))
	progress_label=Label.new();top.add_child(progress_label);update_progress()
	prompt_label=Label.new();prompt_label.position=Vector2(540,730);prompt_label.add_theme_font_size_override("font_size",23);root.add_child(prompt_label)
	journal=card(Vector2(28,210),Vector2(660,610));root.add_child(journal);journal.hide()
	var list=VBoxContainer.new();list.add_theme_constant_override("separation",12);journal.add_child(list)
	var title=Label.new();title.text="校园人物 · %d 位相遇"%definitions.size();title.add_theme_font_size_override("font_size",23);list.add_child(title)
	search_input=LineEdit.new();search_input.placeholder_text="找人物、职业或地点…";search_input.text_changed.connect(filter_roster);list.add_child(search_input)
	var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(610,310);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;list.add_child(scroll)
	roster=VBoxContainer.new();roster.size_flags_horizontal=Control.SIZE_EXPAND_FILL;roster.add_theme_constant_override("separation",8);scroll.add_child(roster)
	for hero in definitions:
		var visit=button(hero.name+" · "+hero.title+"   → 前往\n"+hero.location,func():travel_to(hero.id))
		visit.alignment=HORIZONTAL_ALIGNMENT_LEFT;visit.custom_minimum_size.y=62;roster.add_child(visit);roster_buttons[hero.id]=visit
	var hint=Label.new();hint.text="走近按 E 交谈 · 每位都有自己的工作、知识和对话记忆";hint.add_theme_font_size_override("font_size",14);list.add_child(hint)
	endpoint_input=LineEdit.new();endpoint_input.text=base_url;endpoint_input.placeholder_text="RAG 服务地址";list.add_child(endpoint_input)
	list.add_child(button("连接服务",func():base_url=endpoint_input.text.strip_edges().trim_suffix("/");check_health()))
	status_label=Label.new();status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status_label.add_theme_font_size_override("font_size",14);list.add_child(status_label)
	list.add_child(button("返回校园",close_ui))
	panel=card(Vector2(770,110),Vector2(800,650));root.add_child(panel);panel.hide()
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);panel.add_child(column)
	var row=HBoxContainer.new();column.add_child(row)
	heading=Label.new();heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_theme_font_size_override("font_size",25);row.add_child(heading)
	row.add_child(button("关闭 · Esc",close_ui))
	transcript=RichTextLabel.new();transcript.bbcode_enabled=false;transcript.selection_enabled=true
	transcript.custom_minimum_size=Vector2(740,350);transcript.size_flags_vertical=Control.SIZE_EXPAND_FILL
	transcript.scroll_following=true;transcript.meta_clicked.connect(func(url):OS.shell_open(str(url)))
	column.add_child(transcript)
	source_button=button("查看检索原文",func():source_panel.visible=not source_panel.visible);source_button.disabled=true;column.add_child(source_button)
	suggestions=HBoxContainer.new();column.add_child(suggestions)
	var input_row=HBoxContainer.new();column.add_child(input_row)
	question=LineEdit.new();question.placeholder_text="输入问题，回车发送…";question.max_length=1200
	question.size_flags_horizontal=Control.SIZE_EXPAND_FILL;question.text_submitted.connect(func(_text):send_question());input_row.add_child(question)
	send_button=button("发送",send_question);input_row.add_child(send_button)
	source_panel=card(Vector2(28,230),Vector2(705,480));root.add_child(source_panel);source_panel.hide()
	var source_column=VBoxContainer.new();source_panel.add_child(source_column)
	var source_header=HBoxContainer.new();source_column.add_child(source_header)
	var source_title=Label.new();source_title.text="本次回答 · 检索原文";source_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;source_header.add_child(source_title)
	source_header.add_child(button("收起",func():source_panel.hide()))
	source_text=RichTextLabel.new();source_text.custom_minimum_size=Vector2(660,400);source_text.selection_enabled=true
	source_text.meta_clicked.connect(func(url):OS.shell_open(str(url)));source_column.add_child(source_text)

func update_progress():
	progress_label.text="  本次知识探索 %d / %d"%[completed.size(),definitions.size()]
	for id in roster_buttons:roster_buttons[id].modulate=Color("b5d49c") if completed.has(id) else Color.WHITE

func filter_roster(value:String):
	for hero in definitions:roster_buttons[hero.id].visible=value.is_empty() or value.to_lower() in (hero.name+hero.title+hero.location).to_lower()

func set_modal(open:bool):
	game.player.enabled=not open;game.player.velocity=Vector3.ZERO
	if open and not modal_active:locator_before_modal=game.locator.visible
	game.locator.visible=false if open else locator_before_modal
	modal_active=open
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED

func toggle_journal():
	if panel.visible:return
	journal.visible=not journal.visible;set_modal(journal.visible)
	if journal.visible:health_request.cancel_request();check_health()

func close_ui():
	if busy:
		chat_request.cancel_request();busy=false;cancelled=true;send_button.disabled=false;send_button.text="发送"
	for actor in actors.values():actor.end_conversation()
	game.player.avatar.visible=game.player.third_person
	if dialogue_camera:dialogue_camera.current=false;game.player.camera.current=true
	if portrait_light:portrait_light.hide()
	panel.hide();journal.hide();source_panel.hide();active_id="";set_modal(false)

func travel_to(id:String):
	close_ui();var actor=actors[id]
	game.player.set_free_camera(false)
	var forward=-actor.global_basis.z
	game.player.set_view(actor.global_position+forward*2.8+Vector3.UP*.1,actor.global_position+Vector3.UP*1.5)

func open_dialogue(id:String):
	if busy:return
	active_id=id;journal.hide();panel.show();set_modal(true);actors[id].begin_conversation()
	portrait_light.show()
	game.player.avatar.hide()
	position_dialogue_camera()
	var hero=actors[id].definition;heading.text=hero.name+" · "+hero.title
	source_panel.hide();show_sources(last_sources.get(id,[]))
	transcript.clear();transcript.add_text(hero.greeting+"\n")
	for turn in histories[id]:transcript.add_text("\n"+("你：" if turn.role=="user" else hero.name+"：")+turn.content+"\n")
	for child in suggestions.get_children():child.queue_free()
	for sample in hero.questions:
		var b=button(sample,func():question.text=sample;send_question());b.add_theme_font_size_override("font_size",13);suggestions.add_child(b)
	question.text="";question.grab_focus()

func send_question():
	var text=question.text.strip_edges()
	if text.is_empty() or busy or active_id.is_empty():return
	busy=true;cancelled=false;pending_question=text;pending_id=active_id;send_button.disabled=true;send_button.text="回答中…"
	actors[active_id].thinking=true
	transcript.add_text("\n你："+text+"\n");question.text=""
	var payload={"npc_id":active_id,"message":text,"history":histories[active_id].slice(-10)}
	var err=chat_request.request(base_url+"/chat",PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify(payload))
	if err!=OK:
		busy=false;send_button.disabled=false;send_button.text="发送";transcript.add_text("无法发起请求："+error_string(err)+"\n")

func on_answer(result:int,code:int,_headers:PackedStringArray,body:PackedByteArray):
	if cancelled:return
	busy=false;send_button.disabled=false;send_button.text="发送"
	actors[pending_id].thinking=false
	var data=JSON.parse_string(body.get_string_from_utf8()) if not body.is_empty() else null
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200 or not data is Dictionary:
		var detail=str(data.get("detail","")) if data is Dictionary else ""
		transcript.add_text("服务连接失败（HTTP %d）。%s\n按 J 可配置地址；确认 RAG 与 Qwen 已启动。\n"%[code,detail]);return
	var history=histories[pending_id];history.append({"role":"user","content":pending_question});history.append({"role":"assistant","content":data.answer})
	actors[pending_id].answer_received()
	while history.size()>10:history.pop_front()
	transcript.add_text("\n"+actors[pending_id].definition.name+"："+str(data.answer)+"\n")
	var sources=data.get("sources",[])
	last_sources[pending_id]=sources;show_sources(sources)
	if sources.size()>0:
		transcript.push_color(Color("9ec6d2"));transcript.add_text("\n检索依据 · "+str(data.get("model",""))+"\n")
		for source in sources:
			transcript.push_meta(source.url);transcript.add_text("[%d] %s · %s\n"%[source.citation,source.title,source.location]);transcript.pop()
		transcript.pop()
	if data.get("has_valid_citations",false):completed[pending_id]=true;update_progress()
	transcript.scroll_to_line(maxi(0,transcript.get_line_count()-14))

func show_sources(sources:Array):
	source_button.disabled=sources.is_empty();source_button.text="查看检索原文（%d份资料）"%sources.size();source_text.clear()
	for source in sources:
		source_text.push_meta(source.url);source_text.add_text("[%d] %s · %s\n"%[source.citation,source.title,source.location]);source_text.pop()
		source_text.add_text(str(source.version)+"\n\n"+str(source.text)+"\n\n")

func check_health():
	status_label.text="正在连接 "+base_url
	var err=health_request.request(base_url+"/health")
	if err!=OK:status_label.text="连接请求失败："+error_string(err)

func on_health(result:int,code:int,_headers:PackedStringArray,body:PackedByteArray):
	var data=JSON.parse_string(body.get_string_from_utf8()) if not body.is_empty() else null
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200 or not data is Dictionary:
		status_label.text="RAG 未连接 · 启动 campus/ai 服务后重连";return
	status_label.text=("已就绪 · " if data.get("model_ready",false) else "检索已就绪，Qwen 模型未连接 · ")+str(data.get("model",""))+"\n"+str(data.get("retrieval",""))

func _process(_dt):
	if not is_instance_valid(game.player):return
	if panel.visible and not active_id.is_empty():position_dialogue_camera()
	nearest="";var distance=3.2
	for id in actors:
		var d=game.player.global_position.distance_to(actors[id].global_position)
		if d<distance:distance=d;nearest=id
	prompt_label.visible=not panel.visible and not journal.visible and not nearest.is_empty() and not game.player.free_camera
	if not nearest.is_empty():prompt_label.text="E 交谈 · "+actors[nearest].definition.name

func position_dialogue_camera():
	var actor=actors[active_id];var basis=actor.global_basis
	dialogue_camera.global_position=actor.global_position+basis*Vector3(0,1.65,-3.7)
	dialogue_camera.look_at(actor.global_position+basis*Vector3(-1.25,1.25,0));dialogue_camera.current=true

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if (question.has_focus() or endpoint_input.has_focus() or search_input.has_focus()) and event.keycode!=KEY_ESCAPE:return
		if event.keycode==KEY_ESCAPE and (panel.visible or journal.visible):close_ui();get_viewport().set_input_as_handled()
		elif event.keycode==KEY_J and not panel.visible:toggle_journal();get_viewport().set_input_as_handled()
		elif event.keycode==KEY_E and prompt_label.visible:open_dialogue(nearest);get_viewport().set_input_as_handled()
		elif (panel.visible or journal.visible) and not event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
			# GUI receives typing; world hotkeys must not teleport the player while typing.
			if not question.has_focus() and not endpoint_input.has_focus():get_viewport().set_input_as_handled()
