extends SceneTree
## Actual model-selected tools, game execution and observations, captured for the interview.
const OUTPUT="res://../renders/agent_interview"
const FPS=12
var game
var agent
var frame_number=0
var heading:Label
var caption:Label
var before_position:Vector3
var checkpoints:Array=[]

func _initialize():call_deferred("run")

func strip(canvas:CanvasLayer,y:float,height:float,size:int)->Label:
	var background=ColorRect.new();background.position=Vector2(0,y);background.size=Vector2(1600,height)
	background.color=Color(.025,.045,.065,.94);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(background)
	var label=Label.new();label.position=Vector2(32,y+12);label.size=Vector2(1536,height-20)
	var font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei"])
	label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",size);canvas.add_child(label);return label

func capture():
	await process_frame;await RenderingServer.frame_post_draw
	var error=root.get_texture().get_image().save_jpg(OUTPUT+"/frames/frame_%05d.jpg"%frame_number,.94)
	if error!=OK:push_error("Agent capture save failed");quit(1)
	frame_number+=1

func hold(seconds:float):
	for i in range(int(FPS*seconds)):await capture()

func photo(name:String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+"/"+name+".png")

func stage(title:String,detail:String):
	heading.text=title;caption.text=detail
	checkpoints.append({"title":title,"frame":frame_number,"seconds":float(frame_number)/FPS})
	print("AGENT_DEMO_STAGE ",title," frame=",frame_number)

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT+"/frames"))
	game=load("res://scenes/campus_game.tscn").instantiate();root.add_child(game)
	for i in range(16):await physics_frame
	agent=game.campus_agent
	game.hero_interactions.travel_to("student");game.hud.hide();game.locator.hide()
	agent.open_panel();before_position=game.player.global_position
	var canvas=CanvasLayer.new();canvas.layer=90;game.add_child(canvas)
	heading=strip(canvas,0,92,30);caption=strip(canvas,832,68,22)
	stage("科大云宇宙｜叶新程：从知识NPC到行动Agent", "一句自然语言目标 → 模型选择工具 → 游戏执行 → 回传实际结果")
	var goal="查学生能借几本书、借多久，带我找对应老师并打开对话"
	agent.goal_input.text=goal;agent.goal_input.release_focus()
	await hold(2);await photo("01_goal")
	stage("Agent 执行中｜查找人物、检索规则、调用游戏操作", "快速前往复用现有校园能力；工具选择来自云端模型，执行结果来自真实游戏。")
	var started=Time.get_ticks_msec()
	agent.submit_goal(goal)
	while agent.busy and Time.get_ticks_msec()-started<120000:
		await capture()
	var wall_seconds=float(Time.get_ticks_msec()-started)/1000.0
	var success=not agent.busy and agent.last_result.get("status","")=="completed"
	success=success and game.hero_interactions.active_id=="library" and game.hero_interactions.panel.visible
	success=success and before_position.distance_to(game.player.global_position)>100 and agent.action_results.size()>=2
	var tools=[]
	for row in agent.last_result.get("tool_trace",[]):tools.append(row.get("tool",""))
	success=success and "search_npcs" in tools and "query_npc_knowledge" in tools
	for observation in agent.action_results:success=success and observation.get("status","")=="success"
	if not success:
		await photo("failed");print("AGENT_DEMO_FAILED ",JSON.stringify(agent.last_result));quit(1);return
	stage("已执行｜找到图书馆员，快速前往并打开对话", "模型收到真实坐标与对话状态后，才给出完成答复；借阅规则附资料来源。")
	await hold(4);await photo("02_result")
	agent.transcript.scroll_to_line(0)
	stage("工具轨迹｜角色搜索 · 资料检索 · 前往 · 打开对话", "这是已接入的轻量Agent闭环；会话工作记忆保留目标、工具结果和游戏回执。")
	await hold(4);await photo("03_tools")
	agent.transcript.scroll_to_line(maxi(0,agent.transcript.get_line_count()-10))
	await hold(2);await photo("04_final")
	var report={"frames":frame_number,"fps":FPS,"width":root.size.x,"height":root.size.y,
		"wall_seconds":wall_seconds,"checkpoints":checkpoints,"goal":goal,
		"before_position":[before_position.x,before_position.y,before_position.z],
		"after_position":[game.player.global_position.x,game.player.global_position.y,game.player.global_position.z],
		"result":agent.last_result,"passed":success,
		"source":"Actual Godot gameplay; live model decisions, RAG retrieval, executed tools and game observations"}
	FileAccess.open(OUTPUT+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("AGENT_DEMO_COMPLETE frames=",frame_number," wall_seconds=",wall_seconds," passed=",success);quit()
