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
var suggestions:Container
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
var web_warming=false
var reconnect_button:Button
var health_clock=0.0
var personal_api_key=""
var api_panel:PanelContainer
var api_key_input:LineEdit
var api_status:Label
var api_show:CheckButton
var api_remember:CheckButton
var remembered_key=false
var key_store="user://campus_ai_key.cfg"

func _ready():
	definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/hero_npcs.json"))
	if OS.has_feature("web"):base_url=str(JavaScriptBridge.eval("window.location.origin",true))+"/api"
	if OS.has_environment("CAMPUS_AI_URL"):base_url=OS.get_environment("CAMPUS_AI_URL").trim_suffix("/")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ai-url="):base_url=arg.trim_prefix("--ai-url=").trim_suffix("/")
	for hero in definitions:
		histories[hero.id]=[]
		if not game.has_method("is_streamed_web"):spawn_actor(hero,game.world)
	if game.has_method("is_streamed_web"):sync_streamed_actors()
	load_personal_key()
	build_ui()
	chat_request=HTTPRequest.new();chat_request.timeout=100;add_child(chat_request)
	chat_request.accept_gzip=not OS.has_feature("web")
	chat_request.request_completed.connect(on_answer)
	health_request=HTTPRequest.new();health_request.timeout=15;add_child(health_request)
	health_request.accept_gzip=not OS.has_feature("web")
	health_request.request_completed.connect(on_health)
	check_health()
	dialogue_camera=Camera3D.new();dialogue_camera.fov=54;game.add_child(dialogue_camera)
	dialogue_camera.cull_mask &= ~game.REFLECTION_LAYER
	portrait_light=DirectionalLight3D.new();portrait_light.name="SoftPortraitFill";portrait_light.light_color=Color("e4e9e4");portrait_light.hide()
	portrait_light.light_energy=.55;portrait_light.light_cull_mask=16
	dialogue_camera.add_child(portrait_light)
	print("HERO_NPCS_READY count=",actors.size()," endpoint=",base_url)
	if "--heroes-focus" in OS.get_cmdline_user_args():toggle_journal()

func spawn_actor(hero:Dictionary,parent:Node):
	var actor=preload("res://scripts/hero_actor.gd").new();actor.definition=hero;actor.name="Hero_"+hero.id
	actor.player=game.player;actor.position=Vector3(hero.position[0],hero.position[1],hero.position[2]);parent.add_child(actor);actors[hero.id]=actor

func region_for_npc(id:String)->String:
	for hero in definitions:
		if hero.id==id:return game.streaming.id_at(Vector3(hero.position[0],hero.position[1],hero.position[2]))
	return ""

func sync_streamed_actors():
	for hero in definitions:
		var region=region_for_npc(hero.id)
		if not actors.has(hero.id) and game.streaming.loaded.has(region):spawn_actor(hero,game.streaming.loaded[region])

func remove_region_actors(region:String):
	for id in actors.keys():
		if region_for_npc(id)==region:actors[id].queue_free();actors.erase(id)
	nearest=""

func ensure_actor(id:String)->bool:
	if actors.has(id):
		if game.has_method("is_streamed_web") and game.streaming.pending.has(region_for_npc(id)):
			return await game.streaming.ensure(region_for_npc(id),true)
		return true
	if not game.has_method("is_streamed_web"):return false
	var region=region_for_npc(id)
	if region.is_empty() or not await game.streaming.ensure(region,true):return false
	sync_streamed_actors();return actors.has(id)

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
	var theme=Theme.new();var font=preload("res://scripts/campus_font.gd").get_font()
	theme.default_font=font;theme.default_font_size=17;root.theme=theme
	var top=HBoxContainer.new();top.position=Vector2(28,178);root.add_child(top)
	top.add_child(button("知识英雄 · J",toggle_journal))
	progress_label=Label.new();top.add_child(progress_label);update_progress()
	top.add_child(button("AI 设置",open_api_settings))
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
	list.add_child(button("API Key 设置",open_api_settings))
	if OS.has_feature("web"):endpoint_input.hide()
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
	suggestions=HFlowContainer.new() if game.has_method("is_streamed_web") else HBoxContainer.new();column.add_child(suggestions)
	var input_row=HBoxContainer.new();column.add_child(input_row)
	question=LineEdit.new();question.placeholder_text="输入问题，回车发送…";question.max_length=1200
	question.size_flags_horizontal=Control.SIZE_EXPAND_FILL;question.text_submitted.connect(func(_text):send_question());input_row.add_child(question)
	send_button=button("发送",send_question);input_row.add_child(send_button)
	reconnect_button=button("重连 AI",check_health);input_row.add_child(reconnect_button)
	reconnect_button.visible=OS.has_feature("web")
	source_panel=card(Vector2(28,230),Vector2(705,480));root.add_child(source_panel);source_panel.hide()
	var source_column=VBoxContainer.new();source_panel.add_child(source_column)
	var source_header=HBoxContainer.new();source_column.add_child(source_header)
	var source_title=Label.new();source_title.text="本次回答 · 检索原文";source_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;source_header.add_child(source_title)
	source_header.add_child(button("收起",func():source_panel.hide()))
	source_text=RichTextLabel.new();source_text.custom_minimum_size=Vector2(660,400);source_text.selection_enabled=true
	source_text.meta_clicked.connect(func(url):OS.shell_open(str(url)));source_column.add_child(source_text)
	api_panel=card(Vector2(445,210),Vector2(700,410));root.add_child(api_panel);api_panel.hide()
	var settings=VBoxContainer.new();settings.add_theme_constant_override("separation",14);api_panel.add_child(settings)
	var api_heading=Label.new();api_heading.text="AI 设置 · 科大 API Key";api_heading.add_theme_font_size_override("font_size",24);settings.add_child(api_heading)
	var note=Label.new();note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	note.text="Key 仅供你使用，不修改主机配置；默认退出后清除。\n请求经校园 AI 后台转发至科大平台；网页 Key 会经过本站服务器。\n留空使用主机配置。勾选记住后保存在此设备，共享设备请勿勾选。";settings.add_child(note)
	api_key_input=LineEdit.new();api_key_input.secret=true;api_key_input.max_length=512
	api_key_input.placeholder_text="粘贴科大 API Key（不自动保存）";api_key_input.text_submitted.connect(func(_text):apply_api_key());settings.add_child(api_key_input)
	api_show=CheckButton.new();api_show.text="显示正在填写的 Key";api_show.toggled.connect(func(visible):api_key_input.secret=not visible);settings.add_child(api_show)
	api_remember=CheckButton.new();api_remember.text="在此设备记住 Key";api_remember.button_pressed=remembered_key
	api_remember.toggled.connect(func(enabled):
		if not enabled:remembered_key=false;save_personal_key())
	settings.add_child(api_remember)
	var api_actions=HFlowContainer.new();settings.add_child(api_actions)
	api_actions.add_child(button("应用并测试",apply_api_key));api_actions.add_child(button("测试当前连接",check_health))
	api_actions.add_child(button("清除个人 Key",clear_api_key));api_actions.add_child(button("关闭 · Esc",close_ui))
	api_status=Label.new();api_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;settings.add_child(api_status)

func load_personal_key():
	var value=""
	if OS.has_feature("web"):
		value=str(JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('campus.personal-api-key')||''}catch{return ''}})()",true))
	else:
		var config=ConfigFile.new()
		if config.load(key_store)==OK:value=str(config.get_value("ustc","api_key",""))
	var pattern=RegEx.new();pattern.compile("^[!-~]{1,512}$")
	if pattern.search(value)!=null:personal_api_key=value;remembered_key=true

func save_personal_key()->bool:
	var value=personal_api_key if remembered_key else ""
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("(()=>{try{const key="+JSON.stringify(value)+";if(key)localStorage.setItem('campus.personal-api-key',key);else localStorage.removeItem('campus.personal-api-key');return true}catch{return false}})()",true))
	if value.is_empty():
		return not FileAccess.file_exists(key_store) or DirAccess.remove_absolute(ProjectSettings.globalize_path(key_store))==OK
	var config=ConfigFile.new();config.set_value("ustc","api_key",value)
	return config.save(key_store)==OK

func key_destination_allowed()->bool:
	if OS.has_feature("web"):return base_url==str(JavaScriptBridge.eval("window.location.origin",true))+"/api"
	var pattern=RegEx.new();pattern.compile("^https?://(127\\.0\\.0\\.1|localhost|\\[::1\\])(:[0-9]{1,5})?(/[^?#]*)?$")
	return pattern.search(base_url.to_lower())!=null

func api_headers(json_body:bool=true)->PackedStringArray:
	var headers=PackedStringArray(["Content-Type: application/json"]) if json_body else PackedStringArray()
	if not personal_api_key.is_empty() and key_destination_allowed():headers.append("X-Campus-API-Key: "+personal_api_key)
	return headers

func open_api_settings():
	if busy or (game.campus_agent and game.campus_agent.busy):return
	if game.campus_agent and game.campus_agent.panel_open:game.campus_agent.close_panel()
	close_ui();api_show.button_pressed=false;api_key_input.secret=true;api_key_input.text=personal_api_key
	api_status.text="正在使用本次会话的个人 Key。" if not personal_api_key.is_empty() else "正在使用主机已有配置。"
	api_panel.show();set_modal(true)
	if not OS.has_feature("web"):api_key_input.grab_focus()
	elif not game.player.touch_mode and game.web_text_input:game.web_text_input.request_focus("api_key")

func apply_api_key():
	var value=api_key_input.text.strip_edges()
	var pattern=RegEx.new();pattern.compile("^[!-~]{1,512}$")
	if not value.is_empty() and pattern.search(value)==null:
		api_status.text="Key 格式无效，请勿包含空格、换行或中文。";return
	if not value.is_empty() and not key_destination_allowed():
		api_status.text="个人 Key 仅可发送到本机后台或当前网站。请先检查后台地址。";return
	personal_api_key=value;remembered_key=api_remember.button_pressed and not value.is_empty()
	var saved=save_personal_key();check_health()
	if not saved:api_status.text+="\n无法更新本地保存设置；本次运行的 Key 仍有效。"

func clear_api_key():
	personal_api_key="";remembered_key=false;api_remember.button_pressed=false;api_key_input.text="";api_show.button_pressed=false
	var saved=save_personal_key();check_health()
	if not saved:api_status.text+="\n未能删除本地保存，请检查存储权限。"

func update_progress():
	progress_label.text="  本次知识探索 %d / %d"%[completed.size(),definitions.size()]
	for id in roster_buttons:roster_buttons[id].modulate=Color("b5d49c") if completed.has(id) else Color.WHITE

func filter_roster(value:String):
	for hero in definitions:roster_buttons[hero.id].visible=value.is_empty() or value.to_lower() in (hero.name+hero.title+hero.location).to_lower()

func set_modal(open:bool):
	game.player.enabled=not open;game.player.velocity=Vector3.ZERO
	game.player.clear_touch()
	if open and not modal_active:locator_before_modal=game.locator.visible
	game.locator.visible=false if open else locator_before_modal
	modal_active=open
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if open or OS.has_feature("web") else Input.MOUSE_MODE_CAPTURED

func toggle_journal():
	if panel.visible:return
	if api_panel.visible:close_ui()
	journal.visible=not journal.visible;set_modal(journal.visible)
	if journal.visible:health_request.cancel_request();check_health()
	if journal.visible:
		if not OS.has_feature("web"):search_input.grab_focus()
		elif not game.player.touch_mode and game.web_text_input:game.web_text_input.request_focus("search")

func close_ui():
	if busy:
		chat_request.cancel_request();busy=false;cancelled=true;send_button.disabled=false;send_button.text="发送"
	for actor in actors.values():actor.end_conversation()
	game.player.avatar.visible=game.player.third_person
	if dialogue_camera:dialogue_camera.current=false;game.player.camera.current=true
	if portrait_light:portrait_light.hide()
	panel.hide();journal.hide();source_panel.hide();api_panel.hide();api_key_input.text="";active_id="";set_modal(false)

func travel_to(id:String)->bool:
	if not await ensure_actor(id):status_label.text="目标区域加载失败，请重试。";return false
	close_ui();var actor=actors[id]
	game.player.set_free_camera(false)
	var forward=-actor.global_basis.z
	var approach=actor.global_position+forward*2.8
	approach.y=float(actor.definition.position[1])+.1
	game.player.set_view(approach,actor.global_position+Vector3.UP*1.5)
	if game.has_method("is_streamed_web"):game.streaming.last_safe=game.player.global_position
	return true

func open_dialogue(id:String):
	if busy:return
	if not await ensure_actor(id):status_label.text="目标区域加载失败，请重试。";return
	active_id=id;journal.hide();panel.show();set_modal(true);actors[id].begin_conversation()
	if not OS.has_feature("web"):portrait_light.show() # A new WebGL light variant would compile every visible material.
	game.player.avatar.hide()
	position_dialogue_camera()
	var hero=actors[id].definition;heading.text=hero.name+" · "+hero.title
	source_panel.hide();show_sources(last_sources.get(id,[]))
	transcript.clear();transcript.add_text(hero.greeting+"\n")
	for turn in histories[id]:transcript.add_text("\n"+("你：" if turn.role=="user" else hero.name+"：")+turn.content+"\n")
	for child in suggestions.get_children():child.queue_free()
	for sample in hero.questions:
		var b=button(sample,func():question.text=sample;send_question());b.add_theme_font_size_override("font_size",13);suggestions.add_child(b)
	question.text=""
	if not web_warming:
		if not OS.has_feature("web"):question.grab_focus()
		elif not game.player.touch_mode and game.web_text_input:game.web_text_input.request_focus("question")

func prewarm_web_dialogue():
	if not OS.has_feature("web") or actors.is_empty():return
	web_warming=true
	await open_dialogue(actors.keys()[0])
	await get_tree().process_frame
	await get_tree().process_frame
	close_ui();web_warming=false

func send_question():
	var text=question.text.strip_edges()
	if text.is_empty() or busy or active_id.is_empty():return
	busy=true;cancelled=false;pending_question=text;pending_id=active_id;send_button.disabled=true;send_button.text="回答中…"
	actors[active_id].thinking=true
	transcript.add_text("\n你："+text+"\n");question.text=""
	var payload={"npc_id":active_id,"message":text,"history":histories[active_id].slice(-10)}
	if OS.has_feature("web"):
		await get_tree().process_frame # Present the panel/thinking state before starting the request.
		if cancelled or not busy:return
	var err=chat_request.request(base_url+"/chat",api_headers(),HTTPClient.METHOD_POST,JSON.stringify(payload))
	if err!=OK:
		busy=false;send_button.disabled=false;send_button.text="发送";transcript.add_text("无法发起请求："+error_string(err)+"\n")

func on_answer(result:int,code:int,_headers:PackedStringArray,body:PackedByteArray):
	if cancelled:return
	busy=false;send_button.disabled=false;send_button.text="发送"
	if actors.has(pending_id):actors[pending_id].thinking=false
	var data=JSON.parse_string(body.get_string_from_utf8()) if not body.is_empty() else null
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200 or not data is Dictionary:
		var detail=str(data.get("detail","")) if data is Dictionary else ""
		if OS.has_feature("web"):
			transcript.add_text(service_error(code,detail)+"\n")
			if question.text.is_empty():question.text=pending_question
		else:transcript.add_text("服务连接失败（HTTP %d）。%s\n按 J 可配置地址；确认校园 AI 后台已启动。\n"%[code,detail])
		return
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
	health_request.cancel_request()
	status_label.text="正在连接 "+base_url
	api_status.text="正在测试个人 Key…" if not personal_api_key.is_empty() else "正在测试主机已有配置…"
	if reconnect_button:reconnect_button.text="连接中…";reconnect_button.disabled=true
	var headers=api_headers(false);headers.append("Cache-Control: no-cache")
	var err=health_request.request(base_url+"/health",headers)
	if err!=OK:
		status_label.text="连接请求失败："+error_string(err)
		api_status.text="连接请求失败，请检查本机后台或校园网络。"
		if reconnect_button:reconnect_button.disabled=false;reconnect_button.text="重连 AI"

func on_health(result:int,code:int,_headers:PackedStringArray,body:PackedByteArray):
	if reconnect_button:reconnect_button.text="重连 AI";reconnect_button.disabled=false
	var data=JSON.parse_string(body.get_string_from_utf8()) if not body.is_empty() else null
	var model_ready=result==HTTPRequest.RESULT_SUCCESS and code==200 and data is Dictionary and data.get("model_ready",false)
	api_status.text=("个人 Key 已验证，可用于 NPC 和向导。" if not personal_api_key.is_empty() else "主机配置已连接，可用于 NPC 和向导。") if model_ready else "连接未就绪，请检查校园网、Key 和主机服务。"
	if not model_ready and data is Dictionary and not str(data.get("detail","")).is_empty():api_status.text+="\n"+str(data.detail)
	if OS.has_feature("web"):
		var ready=result==HTTPRequest.RESULT_SUCCESS and code==200 and data is Dictionary and data.get("model_ready",false)
		JavaScriptBridge.eval("window.parent.postMessage({type:'campus-ai-state',ready:"+("true" if ready else "false")+"},window.location.origin)",true)
		status_label.text="校园伙伴已就绪，可以提问或请向导带路。" if ready else "AI 暂时离线：需主机开启 AI 服务并连接校园网；漫游和人物介绍可继续。"
		if reconnect_button:reconnect_button.text="AI 已连接" if ready else "重连 AI"
		return
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200 or not data is Dictionary:
		status_label.text="RAG 未连接 · 启动 campus/ai 服务后重连";return
	status_label.text=("已就绪 · " if data.get("model_ready",false) else "检索已就绪，模型未连接 · ")+str(data.get("model",""))+"\n"+str(data.get("retrieval",""))
	if not str(data.get("detail","")).is_empty():status_label.text+="\n"+str(data.detail)

func _process(_dt):
	if not is_instance_valid(game.player):return
	if OS.has_feature("web"):
		health_clock+=_dt
		if health_clock>=30:
			health_clock=0
			if modal_active and health_request.get_http_client_status()==HTTPClient.STATUS_DISCONNECTED:check_health()
	if panel.visible and not active_id.is_empty():position_dialogue_camera()
	nearest="";var distance=3.2
	for id in actors:
		var d=game.player.global_position.distance_to(actors[id].global_position)
		if d<distance:distance=d;nearest=id
	var door_selected:bool=game.has_method("has_selected_visit_door") and game.has_selected_visit_door()
	prompt_label.visible=not modal_active and not nearest.is_empty() and not game.player.free_camera and not door_selected
	if not nearest.is_empty():prompt_label.text="E 交谈 · "+actors[nearest].definition.name

func position_dialogue_camera():
	var actor=actors[active_id];var basis=actor.global_basis
	dialogue_camera.global_position=actor.global_position+basis*Vector3(0,1.65,-3.7)
	dialogue_camera.look_at(actor.global_position+basis*Vector3(-1.25,1.25,0));dialogue_camera.current=true

func service_error(code:int,detail:String)->String:
	if code==429:return "当前提问较多，请稍候再发送；问题已保留。"
	if code in [0,502,503,504,530]:return "AI 当前离线或网络中断。请主机开启 AI 服务并连接校园网，再点“重连 AI”后发送；问题已保留，校园漫游可继续。"
	return detail if not detail.is_empty() else "本次提问未完成，请稍后重试；问题已保留。"

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if api_panel.visible:
			if event.keycode==KEY_ESCAPE:close_ui();get_viewport().set_input_as_handled()
			return
		if (question.has_focus() or endpoint_input.has_focus() or search_input.has_focus() or api_key_input.has_focus()) and event.keycode!=KEY_ESCAPE:return
		if event.keycode==KEY_ESCAPE and (panel.visible or journal.visible):close_ui();get_viewport().set_input_as_handled()
		elif event.keycode==KEY_J and not panel.visible:toggle_journal();get_viewport().set_input_as_handled()
		elif event.keycode==KEY_E and game.has_method("activate_visit_door") and game.activate_visit_door():
			get_viewport().set_input_as_handled()
		elif event.keycode==KEY_E and prompt_label.visible and not game.player.free_camera:
			open_dialogue(nearest);get_viewport().set_input_as_handled()
		elif (panel.visible or journal.visible) and not event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
			# GUI receives typing; world hotkeys must not teleport the player while typing.
			if not question.has_focus() and not endpoint_input.has_focus():get_viewport().set_input_as_handled()
