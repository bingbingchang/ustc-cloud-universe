extends SceneTree
## Real player camera and input dispatcher; no campus/map/models are loaded.
class Game extends Node:
	var player
var player
var controls
var output=""
var button_presses=0
var test_size=Vector2i(960,540)
var report={"passed":true,"checks":{}}
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
		if arg.begins_with("--qa-size="):
			var dimensions=arg.trim_prefix("--qa-size=").split("x");test_size=Vector2i(int(dimensions[0]),int(dimensions[1]))
	call_deferred("run")
func scaled(value:Vector2)->Vector2:return value*Vector2(test_size)/Vector2(960,540)
func check(name:String,ok:bool):
	report.checks[name]=ok
	if not ok:report.passed=false
func send(event:InputEvent):
	Input.parse_input_event(event);await process_frame
func touch(index:int,position:Vector2,pressed:bool,canceled:bool=false):
	var event=InputEventScreenTouch.new();event.index=index;event.position=scaled(position);event.pressed=pressed;event.canceled=canceled
	await send(event)
func drag(index:int,position:Vector2,relative:Vector2):
	var event=InputEventScreenDrag.new();event.index=index;event.position=scaled(position);event.relative=scaled(relative)
	await send(event)
func mouse_motion():
	var event=InputEventMouseMotion.new();event.device=-1;event.relative=Vector2(40,10);event.screen_relative=event.relative;event.button_mask=MOUSE_BUTTON_MASK_LEFT
	return event
func run():
	if DisplayServer.get_name()=="headless":push_error("Use a native window for pointer-capture regression");quit(2);return
	root.disable_3d=true;root.size=test_size;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.grab_focus()
	# Attach scripts after these lightweight nodes are ready, avoiding avatar/map setup.
	player=CharacterBody3D.new();root.add_child(player);player.set_script(load("res://scripts/third_person_player.gd"));player.set_physics_process(false)
	player.orbit=Node3D.new();player.add_child(player.orbit);player.arm=SpringArm3D.new();player.orbit.add_child(player.arm)
	player.camera=Camera3D.new();player.arm.add_child(player.camera);player.touch_mode=true
	controls=CanvasLayer.new();root.add_child(controls);controls.set_script(load("res://scripts/web_controls.gd"));controls.set_process(false)
	var game=Game.new();root.add_child(game);game.player=player;controls.game=game
	controls.root=Control.new();controls.root.mouse_filter=Control.MOUSE_FILTER_IGNORE;controls.add_child(controls.root)
	controls.joystick=Control.new();controls.joystick.mouse_filter=Control.MOUSE_FILTER_IGNORE;controls.root.add_child(controls.joystick)
	controls.set_process_input(true);controls.set_process_unhandled_input(true);player.set_process_unhandled_input(true)
	Input.emulate_mouse_from_touch=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var yaw=player.orbit.rotation.y;player._unhandled_input(mouse_motion())
	check("touch_mouse_emulation_cannot_turn_camera",is_equal_approx(yaw,player.orbit.rotation.y))
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await touch(0,Vector2(80,470),true);yaw=player.orbit.rotation.y
	await drag(0,Vector2(120,470),Vector2(40,0))
	check("left_stick_moves_only",player.touch_move.length()>.2 and is_equal_approx(yaw,player.orbit.rotation.y))
	await touch(1,Vector2(760,210),true);yaw=player.orbit.rotation.y
	await drag(1,Vector2(800,230),Vector2(40,20))
	check("right_finger_turns_while_walking",not is_equal_approx(yaw,player.orbit.rotation.y) and player.touch_move.length()>.2)
	yaw=player.orbit.rotation.y;await drag(0,Vector2(850,390),Vector2(730,-80))
	check("left_crossing_midline_keeps_movement_role",is_equal_approx(yaw,player.orbit.rotation.y) and controls.movement_finger==0)
	yaw=player.orbit.rotation.y;await drag(1,Vector2(70,390),Vector2(-730,160))
	check("right_crossing_midline_keeps_look_role",not is_equal_approx(yaw,player.orbit.rotation.y) and controls.look_finger==1)
	await touch(2,Vector2(820,190),true);yaw=player.orbit.rotation.y
	await drag(2,Vector2(840,190),Vector2(20,0))
	check("third_finger_does_not_steal_camera",is_equal_approx(yaw,player.orbit.rotation.y) and controls.look_finger==1)
	# GUI consumes raw events here: owned drag/release must still arrive via _input.
	var blocker=Control.new();blocker.position=scaled(Vector2(600,350));blocker.size=scaled(Vector2(350,180))
	blocker.gui_input.connect(func(event):
		if event is InputEventScreenTouch or event is InputEventScreenDrag:blocker.accept_event())
	controls.root.add_child(blocker);await process_frame
	await drag(0,Vector2(700,400),Vector2(-150,10));check("owned_drag_survives_gui_overlap",player.touch_move.is_equal_approx(scaled(Vector2(620,-70)).normalized()))
	await touch(0,Vector2(700,400),false)
	check("release_over_gui_stops_movement_only",player.touch_move==Vector2.ZERO and controls.movement_finger==-1 and controls.look_finger==1)
	await touch(1,Vector2(710,410),true,true)
	check("touch_cancel_releases_camera",controls.look_finger==-1)
	await touch(2,Vector2(840,190),false);blocker.queue_free();await process_frame
	await touch(3,Vector2(80,470),true);await touch(4,Vector2(760,210),true)
	controls._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("focus_loss_clears_both_hands",controls.movement_finger==-1 and controls.look_finger==-1 and player.touch_move==Vector2.ZERO)
	await touch(3,Vector2(80,470),false);await touch(4,Vector2(760,210),false)
	# Web changedTouches batches can each contain just one finger. The engine
	# reuses batch slot 0's previous position, so relative may come from the
	# other hand. Absolute position + identifier must be authoritative.
	await touch(17,Vector2(80,470),true);await drag(17,Vector2(120,470),Vector2(40,0))
	yaw=player.orbit.rotation.y;var start_pitch=player.pitch
	await touch(42,Vector2(760,210),true)
	check("second_hand_down_does_not_turn",is_equal_approx(yaw,player.orbit.rotation.y) and is_equal_approx(start_pitch,player.pitch))
	await drag(17,Vector2(125,465),Vector2(-635,255))
	await drag(42,Vector2(760,210),Vector2(635,-255))
	check("stationary_right_ignores_other_hand_relative",is_equal_approx(yaw,player.orbit.rotation.y) and is_equal_approx(start_pitch,player.pitch))
	await drag(42,Vector2(764,212),Vector2(639,-253))
	check("alternating_hands_use_right_position_delta",is_equal_approx(player.orbit.rotation.y,yaw-scaled(Vector2(4,2)).x*.003) and is_equal_approx(player.pitch,start_pitch-scaled(Vector2(4,2)).y*.003) and player.touch_move.length()>.2)
	yaw=player.orbit.rotation.y;start_pitch=player.pitch
	await touch(17,Vector2(125,465),false)
	await drag(42,Vector2(768,214),Vector2(643,-251))
	check("left_release_cannot_reset_right_baseline",is_equal_approx(player.orbit.rotation.y,yaw-scaled(Vector2(4,2)).x*.003) and is_equal_approx(player.pitch,start_pitch-scaled(Vector2(4,2)).y*.003))
	await touch(42,Vector2(768,214),false)
	await touch(17,Vector2(80,470),true);await drag(17,Vector2(120,470),Vector2(40,0))
	await touch(42,Vector2(870,150),true);yaw=player.orbit.rotation.y;start_pitch=player.pitch
	await drag(42,Vector2(874,152),Vector2(754,-318))
	check("reused_right_id_starts_at_new_position",is_equal_approx(player.orbit.rotation.y,yaw-scaled(Vector2(4,2)).x*.003) and is_equal_approx(player.pitch,start_pitch-scaled(Vector2(4,2)).y*.003))
	# One gesture cannot own both roles, even if a repeated start crosses sides.
	await touch(17,Vector2(780,250),true)
	check("duplicate_start_cannot_steal_look",controls.movement_finger==17 and controls.look_finger==42)
	await touch(42,Vector2(874,152),false);await touch(17,Vector2(780,250),false)
	await touch(17,Vector2(80,470),true);await touch(17,Vector2(780,250),true)
	check("one_finger_cannot_own_both_roles",controls.movement_finger==17 and controls.look_finger==-1)
	await touch(17,Vector2(780,250),false)
	controls.buttons=HBoxContainer.new();controls.buttons.position=scaled(Vector2(600,430));controls.root.add_child(controls.buttons)
	var action=Button.new();action.text="跳跃";action.custom_minimum_size=scaled(Vector2(120,60));controls.buttons.add_child(action)
	action.pressed.connect(func():button_presses+=1);await process_frame
	await process_frame
	yaw=player.orbit.rotation.y;await touch(0,Vector2(650,460),true);await touch(0,Vector2(650,460),false)
	check("touch_buttons_work_without_claiming_camera",button_presses==1 and controls.look_finger==-1 and is_equal_approx(yaw,player.orbit.rotation.y))
	await touch(0,Vector2(80,470),true);await drag(0,Vector2(120,470),Vector2(40,0))
	await touch(1,Vector2(650,460),true);await touch(1,Vector2(650,460),false)
	check("action_button_works_while_walking",button_presses==2 and controls.movement_finger==0 and player.touch_move.length()>.2)
	await touch(0,Vector2(120,470),false)
	player.touch_mode=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;yaw=player.orbit.rotation.y
	player._unhandled_input(mouse_motion());check("desktop_mouse_look_preserved",not is_equal_approx(yaw,player.orbit.rotation.y))
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	report.button_presses=button_presses;report.button_rect=str(action.get_global_rect());report.viewport=[test_size.x,test_size.y]
	FileAccess.open(output+"/mobile-touch-%dx%d.json"%[test_size.x,test_size.y],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MOBILE_TOUCH_QA ",JSON.stringify(report));quit(0 if report.passed else 1)
