extends SceneTree
## Exercise client tool execution without loading the campus or requiring a model server.

class Actor extends Node3D:
	var definition={"name":"测试馆员","location":"图书馆前"}
	func end_conversation():pass

class Heroes extends Node:
	var actors:Dictionary={}
	var active_id=""
	var panel=PanelContainer.new()
	var player:Node3D
	func travel_to(id:String):
		player.global_position=actors[id].global_position+Vector3(2.8,.1,0)
	func open_dialogue(id:String):
		active_id=id;panel.show()

class Game extends Node:
	var player:Node3D
	var hero_interactions

func _initialize():call_deferred("run")

func run():
	var game=Game.new();root.add_child(game)
	game.player=Node3D.new();game.add_child(game.player)
	var heroes=Heroes.new();game.add_child(heroes);heroes.player=game.player;heroes.add_child(heroes.panel);heroes.panel.hide()
	game.hero_interactions=heroes
	var actor=Actor.new();game.add_child(actor);actor.global_position=Vector3(5,.2,436)
	heroes.actors["library"]=actor
	var agent=load("res://scripts/campus_agent.gd").new();agent.game=game
	agent.transcript=RichTextLabel.new();root.add_child(agent.transcript)
	var unknown=agent.execute_action({"id":"x","type":"navigate_to_npc","npc_id":"missing"})
	assert(unknown.status=="failed")
	var too_far=agent.execute_action({"id":"y","type":"open_npc_dialogue","npc_id":"library"})
	assert(too_far.status=="failed" and heroes.active_id.is_empty())
	var travel=agent.execute_action({"id":"a","type":"navigate_to_npc","npc_id":"library"})
	assert(travel.status=="success" and game.player.global_position.z==436)
	assert(travel.detail.player_position[0]==game.player.global_position.x)
	assert(travel.detail.distance_to_npc<3.5 and not travel.detail.dialogue_open)
	var dialogue=agent.execute_action({"id":"b","type":"open_npc_dialogue","npc_id":"library"})
	assert(dialogue.status=="success" and dialogue.detail.dialogue_open)
	print("CAMPUS_AGENT_ACTIONS_PASS unknown_rejected out_of_reach_rejected actual_position_reported dialogue_opened")
	agent.transcript.free();agent.free();game.free();quit()
