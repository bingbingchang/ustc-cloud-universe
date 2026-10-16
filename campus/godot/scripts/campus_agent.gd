extends Node
## The guide's action mode: model chooses tools; Godot executes world actions and reports observations.
signal task_finished(result: Dictionary)

var game
var guide_id="student"
var layer:CanvasLayer
var panel:PanelContainer
var transcript:RichTextLabel
var goal_input:LineEdit
var run_button:Button
var status_label:Label
var request:HTTPRequest
var busy=false
var goal=""
var agent_state:Dictionary={}
var last_result:Dictionary={}
var action_results:Array=[]
var sources:Array=[]
var locator_before=true
var panel_open=false
var trace_cursor=0

func _ready():
	build_ui()
	request=HTTPRequest.new();request.timeout=100;add_child(request)
	request.request_completed.connect(on_response)
	print("CAMPUS_AGENT_READY guide=student endpoint=",game.hero_interactions.base_url)
	if "--agent-focus" in OS.get_cmdline_user_args():open_panel()

func build_ui():
	layer=CanvasLayer.new();layer.layer=35;add_child(layer)
	var root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(root)
	var theme=Theme.new();var font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei","Segoe UI"])
	theme.default_font=font;theme.default_font_size=17;root.theme=theme
	var entry=Button.new();entry.text="叶新程 · 行动向导 K";entry.position=Vector2(470,178)
	entry.pressed.connect(toggle_panel);root.add_child(entry)
	panel=game.hero_interactions.card(Vector2(28,225),Vector2(465,555));root.add_child(panel);panel.hide()
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",10);panel.add_child(column)
	var header=HBoxContainer.new();column.add_child(header)
	var title=Label.new();title.text="叶新程 · 校园向导 Agent";title.add_theme_font_size_override("font_size",20)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	var close=Button.new();close.text="收起 · Esc";close.pressed.connect(close_panel);header.add_child(close)
	var subtitle=Label.new();subtitle.text="告诉我你的目标，我来查资料、找人物并执行校园操作。"
	subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(subtitle)
	transcript=RichTextLabel.new();transcript.bbcode_enabled=false;transcript.selection_enabled=true
	transcript.custom_minimum_size=Vector2(405,300);transcript.size_flags_vertical=Control.SIZE_EXPAND_FILL
	transcript.scroll_following=true;column.add_child(transcript)
	transcript.meta_clicked.connect(func(url):OS.shell_open(str(url)))
	goal_input=LineEdit.new();goal_input.placeholder_text="例如：查学生借书规则，带我找能解答的老师并打开对话"
	goal_input.text_submitted.connect(submit_goal);column.add_child(goal_input)
	var row=HBoxContainer.new();column.add_child(row)
	run_button=Button.new();run_button.text="交给向导";run_button.pressed.connect(func():submit_goal(goal_input.text));row.add_child(run_button)
	status_label=Label.new();status_label.text="模型选择工具 → 游戏执行 → 回传观察";status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(status_label)
	var hint=Label.new();hint.text="快速前往为位置切换；行动结果来自真实游戏状态。";hint.add_theme_font_size_override("font_size",13)
	hint.add_theme_color_override("font_color",Color("a4bfcc"));column.add_child(hint)

func toggle_panel():
	if panel_open:close_panel()
	else:open_panel()

func open_panel():
	if panel_open:return
	var heroes=game.hero_interactions
	heroes.close_ui()
	panel_open=true;panel.show();locator_before=game.locator.visible
	heroes.set_process_input(false)
	if heroes.actors.has(guide_id):heroes.actors[guide_id].begin_conversation()
	lock_controls();goal_input.grab_focus()

func lock_controls():
	game.player.enabled=false;game.player.velocity=Vector3.ZERO
	game.locator.visible=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func close_panel():
	panel_open=false;panel.hide();goal_input.release_focus()
	var heroes=game.hero_interactions
	heroes.set_process_input(true)
	if heroes.actors.has(guide_id):heroes.actors[guide_id].end_conversation()
	if not heroes.panel.visible and not heroes.journal.visible:
		game.player.enabled=true;game.locator.visible=locator_before;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func submit_goal(value:String):
	if busy or value.strip_edges().is_empty():return
	if not panel_open:open_panel()
	goal=value.strip_edges();goal_input.text=goal;goal_input.release_focus()
	action_results=[];sources=[];last_result={};transcript.clear()
	trace_cursor=agent_state.get("tool_trace",[]).size()
	append_line("你："+goal,Color("fff0c2"))
	append_line("叶新程：我来查找合适的人物，再确认游戏里的行动结果。",Color("c8dfd4"))
	busy=true;run_button.disabled=true;goal_input.editable=false
	send_step([])

func send_step(observations:Array):
	status_label.text="叶新程正在选择工具…"
	var payload={"message":goal,"npc_id":guide_id,"history":[],"state":agent_state,"observations":observations}
	var err=request.request(game.hero_interactions.base_url+"/agent",PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify(payload))
	if err!=OK:finish_error("无法发起 Agent 请求："+error_string(err))

func append_line(value:String,color:Color=Color.WHITE):
	transcript.push_color(color);transcript.add_text(value+"\n\n");transcript.pop()

func on_response(result:int,code:int,_headers:PackedStringArray,body:PackedByteArray):
	var data=JSON.parse_string(body.get_string_from_utf8()) if not body.is_empty() else null
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200 or not data is Dictionary:
		var detail=str(data.get("detail","")) if data is Dictionary else body.get_string_from_utf8().left(220)
		finish_error("Agent 服务失败（HTTP %d）：%s"%[code,detail]);return
	agent_state=data.get("state",{})
	var trace:Array=data.get("tool_trace",[])
	for item in trace.slice(trace_cursor):
		var tool=str(item.get("tool","tool"));var summary=str(item.get("summary",""))
		if summary.is_empty():summary=JSON.stringify(item.get("result",{})).left(180)
		append_line("[工具] "+tool+"\n"+summary,Color("9acbdd"))
	trace_cursor=trace.size()
	if not data.get("sources",[]).is_empty():sources=data.sources
	if data.get("status","")=="awaiting_game":
		var observations:Array=[]
		for action in data.get("actions",[]):
			var observation=execute_action(action);observations.append(observation);action_results.append(observation)
		if observations.is_empty():finish_error("模型请求执行，但没有返回游戏动作。");return
		send_step(observations);return
	if data.get("status","")!="completed":finish_error("Agent 返回了未知状态："+str(data.get("status","")));return
	last_result=data.duplicate(true);last_result["observations"]=action_results.duplicate(true);last_result["sources"]=sources.duplicate(true)
	if not sources.is_empty():
		append_line("[资料来源]",Color("9acbdd"))
		for source in sources.slice(0,2):
			transcript.push_meta(str(source.get("url","")))
			transcript.add_text("[%d] %s\n"%[int(source.get("citation",0)),str(source.get("title",""))]);transcript.pop()
	append_line("叶新程："+str(data.get("answer","")),Color("e0f0dd"))
	busy=false;run_button.disabled=false;goal_input.editable=true
	var has_failure=action_results.any(func(observation):return observation.get("status","")=="failed")
	status_label.text="任务结束 · 部分操作未完成" if has_failure else "已完成 · 游戏观察结果已回传模型"
	print("CAMPUS_AGENT_COMPLETED ",JSON.stringify(last_result))
	task_finished.emit(last_result)

func execute_action(action:Dictionary)->Dictionary:
	var action_id=str(action.get("id",""));var kind=str(action.get("type",""));var id=str(action.get("npc_id",""))
	var heroes=game.hero_interactions
	if not heroes.actors.has(id):
		append_line("[执行失败] 校园中没有角色："+id,Color("f0b2a6"))
		return {"action_id":action_id,"status":"failed","detail":{"error":"unknown_npc","npc_id":id}}
	if heroes.actors.has(guide_id):heroes.actors[guide_id].end_conversation()
	var actor=heroes.actors[id]
	if kind=="navigate_to_npc":
		heroes.travel_to(id)
		append_line("[游戏执行] 快速前往 "+str(actor.definition.name)+" · "+str(actor.definition.location),Color("c4e6ac"))
	elif kind=="open_npc_dialogue":
		var distance=game.player.global_position.distance_to(actor.global_position)
		if distance>3.5:
			append_line("[执行失败] 距离目标 %.1f 米，尚不能打开对话。"%distance,Color("f0b2a6"))
			return {"action_id":action_id,"status":"failed","detail":{"error":"npc_out_of_reach","npc_id":id,"distance_to_npc":distance}}
		heroes.open_dialogue(id)
		append_line("[游戏执行] 已打开 "+str(actor.definition.name)+" 的角色对话",Color("c4e6ac"))
	else:
		return {"action_id":action_id,"status":"failed","detail":{"error":"unknown_game_action","type":kind}}
	if panel_open:lock_controls()
	var position=game.player.global_position
	var detail={"npc_id":id,"player_position":[position.x,position.y,position.z],"distance_to_npc":game.player.global_position.distance_to(actor.global_position),"dialogue_open":heroes.active_id==id and heroes.panel.visible}
	append_line("[观察] 玩家坐标 (%.1f, %.1f, %.1f) · 距离 %.1f m"%[position.x,position.y,position.z,detail.distance_to_npc],Color("a4bfcc"))
	print("CAMPUS_AGENT_ACTION ",JSON.stringify({"action":action,"observation":detail}))
	return {"action_id":action_id,"status":"success","detail":detail}

func finish_error(message:String):
	busy=false;run_button.disabled=false;goal_input.editable=true;status_label.text="执行未完成"
	append_line(message,Color("f0b2a6"));last_result={"status":"error","answer":message}
	task_finished.emit(last_result)

func _input(event):
	if not event is InputEventKey or not event.pressed or event.echo:return
	if panel_open:
		if event.keycode==KEY_ESCAPE:
			close_panel();get_viewport().set_input_as_handled()
		elif event.keycode==KEY_K and not goal_input.has_focus():
			close_panel();get_viewport().set_input_as_handled()
	elif event.keycode==KEY_K:
		var heroes=game.hero_interactions
		if heroes.question.has_focus() or heroes.search_input.has_focus() or heroes.endpoint_input.has_focus():return
		if game.chat_input and game.chat_input.has_focus():return
		open_panel();get_viewport().set_input_as_handled()

func _unhandled_input(_event):
	if panel_open:get_viewport().set_input_as_handled()

func _process(_dt):
	if not panel_open:return
	var heroes=game.hero_interactions
	if not heroes.panel.visible or heroes.active_id.is_empty():return
	var actor=heroes.actors[heroes.active_id]
	heroes.dialogue_camera.look_at(actor.global_position+actor.global_basis*Vector3(-.65,1.25,0))
