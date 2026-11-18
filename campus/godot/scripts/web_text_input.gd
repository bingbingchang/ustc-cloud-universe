extends Node
## Web text is edited by the browser; gameplay state stays in the existing controls.
var game
var bridge
var callback
func _ready():
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://web/text_input.js"),true)
	bridge=JavaScriptBridge.get_interface("CampusTextInput")
	callback=JavaScriptBridge.create_callback(on_edit);bridge.init(callback)
	for control in [game.hero_interactions.question,game.hero_interactions.search_input,game.hero_interactions.api_key_input,game.campus_agent.goal_input]:
		control.focus_mode=Control.FOCUS_NONE;control.virtual_keyboard_enabled=false

func request_focus(name:String):bridge.focus(name)

func on_edit(arguments:Array):
	if arguments.size()!=3 or not game.game_ready:return
	var name=str(arguments[0]);var value=str(arguments[1]).left(1200);var action=str(arguments[2])
	var heroes=game.hero_interactions;var agent=game.campus_agent
	if name=="settings" and action=="open":heroes.open_api_settings()
	elif name=="api_key" and heroes.api_panel.visible:
		heroes.api_key_input.text=value.left(512)
		if action=="submit":heroes.apply_api_key()
	elif name=="search" and heroes.journal.visible:
		heroes.search_input.text=value;heroes.filter_roster(value)
	elif name=="question" and heroes.panel.visible and not agent.panel_open:
		heroes.question.text=value
		if action=="submit":heroes.send_question()
	elif name=="agent" and agent.panel_open:
		if agent.busy:return
		agent.goal_input.text=value
		if action=="submit":agent.submit_goal(value)
	if action=="escape":
		if agent.panel_open:agent.close_panel()
		else:heroes.close_ui()

func sync_control(name:String,label:String,control:LineEdit,visible:bool):
	var rect=control.get_global_rect()
	var scale=float(JavaScriptBridge.eval("window.innerWidth",true))/maxf(1,get_viewport().get_visible_rect().size.x)
	bridge.sync(name,label,control.text,control.placeholder_text,rect.position.x,rect.position.y,rect.size.x,rect.size.y,scale,visible and game.game_ready,control.editable,18 if game.player.touch_mode else 16,control.secret)

func _process(_delta):
	var heroes=game.hero_interactions;var agent=game.campus_agent
	sync_control("api_key","科大 API Key",heroes.api_key_input,heroes.api_panel.visible)
	sync_control("search","查找校园人物",heroes.search_input,heroes.journal.visible)
	sync_control("question","向 NPC 提问",heroes.question,heroes.panel.visible and not heroes.source_panel.visible and not agent.panel_open)
	sync_control("agent","校园向导目标",agent.goal_input,agent.panel_open)
