extends SceneTree
## Interview capture only: actual campus UI and live HTTP responses; no canned answers.
const FPS=12
const OUTPUT="res://../renders/heroes/interview"
var game
var heroes
var frame_number=0
var title:Label
var caption:Label
var film_camera:Camera3D
var answers:Array=[]
var chapters:Array=[]

func _initialize():call_deferred("run")

func banner(canvas:CanvasLayer,y:float,height:float,size:int)->Label:
	var panel=ColorRect.new();panel.color=Color(.025,.045,.065,.92)
	panel.position=Vector2(0,y);panel.size=Vector2(1600,height);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(panel)
	var label=Label.new();label.position=Vector2(34,y+12);label.size=Vector2(1532,height-20)
	var font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei"])
	label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("edf5ef"));label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(label);return label

func chapter(heading:String,explanation:String):
	title.text=heading;caption.text=explanation
	chapters.append({"title":heading,"frame":frame_number,"seconds":float(frame_number)/FPS})
	print("RAG_FILM_CHAPTER ",heading," frame=",frame_number)

func capture_frame():
	await process_frame
	await RenderingServer.frame_post_draw
	var result=root.get_texture().get_image().save_jpg(OUTPUT+"/frames/frame_%05d.jpg"%frame_number,.93)
	if result!=OK:
		push_error("Interview frame save failed");quit(1)
	frame_number+=1

func hold(seconds:float):
	for i in range(int(seconds*FPS)):await capture_frame()

func photo(name:String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+name+".png")

func ask(question:String)->bool:
	heroes.question.text=question
	await hold(1.5)
	var npc_id=heroes.active_id
	var previous=heroes.histories[npc_id].size()
	var started=Time.get_ticks_msec()
	heroes.send_question()
	while heroes.busy and Time.get_ticks_msec()-started<90000:
		await capture_frame()
	if heroes.busy or heroes.histories[npc_id].size()!=previous+2:
		push_error("Live interview question failed: "+npc_id+" "+question)
		await photo("failed_"+npc_id);quit(1);return false
	var history=heroes.histories[npc_id]
	answers.append({"npc_id":npc_id,"question":question,"answer":history[-1].content,
		"wall_seconds":float(Time.get_ticks_msec()-started)/1000.0,"sources":heroes.last_sources.get(npc_id,[])})
	await hold(5)
	return true

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT+"/frames"))
	game=load("res://scenes/campus_game.tscn").instantiate();root.add_child(game)
	for i in range(16):await physics_frame
	heroes=game.hero_interactions
	game.hud.hide();game.locator.hide();heroes.close_ui();heroes.layer.hide()
	game.player.enabled=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	film_camera=Camera3D.new();film_camera.fov=58;film_camera.far=1800;game.add_child(film_camera);film_camera.current=true
	var canvas=CanvasLayer.new();canvas.layer=90;game.add_child(canvas)
	title=banner(canvas,0,94,30);caption=banner(canvas,834,66,22)
	chapter("科大校园 × AI NPC｜从角色知识问答走向 Agent", "Godot 实机 · 云端 Qwen3-8B · 15位角色 · 本片问答实时请求RAG服务")
	for i in range(FPS*5):
		var t=float(i)/(FPS*5)
		film_camera.position=Vector3(-78+50*t,62-25*t,358+32*t)
		film_camera.look_at(Vector3(0,5,430));await capture_frame()
	heroes.layer.show();heroes.travel_to("library");game.hud.hide();game.locator.hide()
	film_camera.current=false;game.player.camera.current=true
	heroes.toggle_journal()
	chapter("01｜在校园中找到有职业、动作和知识的角色", "按 J 搜索人物并前往；走近按 E 交谈。不同角色共用模型服务，分别检索自己的资料。")
	await hold(4);await photo("01_roster")
	heroes.close_ui();heroes.travel_to("library");game.player.enabled=false;game.locator.hide()
	await hold(3)
	heroes.open_dialogue("library")
	chapter("02｜图书馆员：从校园规则中找答案", "问题 → 角色资料过滤 → 向量检索 + BM25 → RRF融合 → 带证据生成回答")
	if not await ask("我是本科生，最多能借几本书，借多久？"):return
	await photo("02_library_answer")
	heroes.source_button.pressed.emit()
	chapter("03｜展开原文：把回答和依据放在同一屏", "可查看检索原文与来源；引用编号对应资料，仍可由面试官直接对照核查。")
	await hold(7);await photo("03_library_sources")
	heroes.source_panel.hide()
	chapter("04｜连续追问：保留每个角色自己的会话上下文", "当前已实现短期对话历史；跨会话长期记忆与经历检索属于后续 Agent 工作。")
	if not await ask("那我如果还没看完，可以续借吗？"):return
	await photo("04_follow_up")
	heroes.close_ui();heroes.travel_to("solar");heroes.open_dialogue("solar");game.locator.hide()
	chapter("05｜太阳物理研究员：用中文解释英文论文", "同一套RAG服务切换角色知识范围；研究员检索论文，图书馆员检索借阅规则。")
	if not await ask("这篇论文重点讨论哪颗卫星的X射线观测？请按原文回答。"):return
	await photo("05_solar_answer")
	heroes.source_button.pressed.emit();await hold(5);await photo("06_solar_sources")
	heroes.close_ui();heroes.layer.hide();game.player.enabled=false;game.locator.hide()
	film_camera.current=true;film_camera.position=Vector3(-18,15,92);film_camera.look_at(Vector3(42,3,81))
	chapter("下一步｜让 NPC 从回答问题走向执行任务", "已实现：角色RAG + 动作 + 会话上下文。规划：经历记忆检索 + 工具调用 + 执行结果反馈。")
	var roadmap=PanelContainer.new();roadmap.position=Vector2(230,245);roadmap.size=Vector2(1140,330)
	var box=StyleBoxFlat.new();box.bg_color=Color(.025,.045,.065,.94);box.set_content_margin_all(30);roadmap.add_theme_stylebox_override("panel",box);canvas.add_child(roadmap)
	var text=Label.new();text.text="当前 · 知道什么\n角色资料检索 → 根据原文回答 → 保留本次对话\n\n后续 Agent · 能做什么\n理解目标 → 检索知识与经历 → 调用游戏工具 → 观察结果"
	var font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei"]);text.add_theme_font_override("font",font);text.add_theme_font_size_override("font_size",28);roadmap.add_child(text)
	await hold(8);await photo("07_agent_roadmap")
	var report={"fps":FPS,"frames":frame_number,"width":root.size.x,"height":root.size.y,
		"duration_seconds":float(frame_number)/FPS,"source":"Godot actual rendered frames and live HTTP RAG responses",
		"agent_status":"roadmap_only_no_agent_tool_execution_demonstrated","chapters":chapters,"answers":answers}
	FileAccess.open(OUTPUT+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RAG_INTERVIEW_COMPLETE frames=",frame_number," questions=",answers.size());quit()
