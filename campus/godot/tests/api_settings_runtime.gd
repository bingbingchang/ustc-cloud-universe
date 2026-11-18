extends SceneTree
## Exercise real campus controls, actors and settings without writing a credential.
var game
var report={"passed":true,"checks":{},"npcs":[]}
var output=""
func _initialize():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="):output=argument.trim_prefix("--qa-output=")
	if output.is_empty():push_error("Pass --qa-output=<workspace directory>");quit(2);return
	call_deferred("run")
func check(name:String,passed:bool):
	report.checks[name]=passed
	if not passed:report.passed=false;push_error("QA failed: "+name)
func wait_seconds(seconds:float):
	await create_timer(seconds).timeout
func capture(name:String):
	await process_frame;RenderingServer.force_draw()
	check("capture_"+name,root.get_texture().get_image().save_png(output+"/"+name+".png")==OK)
func run():
	game=load("res://scenes/campus_game.tscn").instantiate();root.add_child(game)
	await process_frame;await physics_frame
	Engine.max_fps=30;root.size=Vector2i(1440,810)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;game.player.touch_mode=true
	var heroes=game.hero_interactions
	heroes.key_store=output+"/qa-key-store.cfg"
	check("all_15_actors",heroes.actors.size()==15)
	check("settings_default_masked",heroes.api_key_input.secret)
	check("remember_default_off",not heroes.api_remember.button_pressed)
	heroes.open_api_settings();await process_frame
	check("settings_lock_player",heroes.api_panel.visible and not game.player.enabled)
	heroes.api_key_input.text="bad key";heroes.apply_api_key()
	check("invalid_key_rejected",heroes.personal_api_key.is_empty() and "格式无效" in heroes.api_status.text)
	# Set only the in-memory test value; never persist a dummy credential.
	heroes.personal_api_key="qa-session-only-fake"
	check("session_header",heroes.api_headers().has("X-Campus-API-Key: qa-session-only-fake"))
	var original=heroes.base_url;heroes.base_url="https://unapproved.example"
	check("unapproved_destination_blocked",not heroes.key_destination_allowed() and heroes.api_headers().size()==1)
	heroes.base_url=original;heroes.personal_api_key=""
	heroes.personal_api_key="qa-remember-only-fake";heroes.remembered_key=true
	check("remember_write",heroes.save_personal_key() and FileAccess.file_exists(heroes.key_store))
	heroes.personal_api_key="";heroes.remembered_key=false;heroes.load_personal_key()
	check("remember_reload",heroes.personal_api_key=="qa-remember-only-fake" and heroes.remembered_key)
	heroes.personal_api_key="";heroes.remembered_key=false
	check("remember_clear",heroes.save_personal_key() and not FileAccess.file_exists(heroes.key_store))
	heroes.close_ui();check("closing_clears_input",heroes.api_key_input.text.is_empty() and game.player.enabled)
	heroes.open_api_settings();await wait_seconds(.3);await capture("native-api-settings")
	heroes.close_ui()
	var walked=0.0;var jumped=false
	for hero in heroes.definitions:
		var travelled=await heroes.travel_to(hero.id);await wait_seconds(.6)
		check("travel_"+hero.id,travelled and game.player.is_on_floor())
		var start=game.player.position;game.player.touch_move=Vector2(0,-1)
		await wait_seconds(.25);game.player.touch_move=Vector2.ZERO
		walked+=game.player.position.distance_to(start)
		var y=game.player.position.y;game.player.touch_jump=true;await wait_seconds(.22)
		jumped=jumped or game.player.position.y-y>.3
		await wait_seconds(.5);await heroes.open_dialogue(hero.id);await process_frame
		check("dialogue_"+hero.id,heroes.panel.visible and heroes.active_id==hero.id and not game.player.enabled)
		if hero.id=="solar":await capture("native-npc-dialogue")
		heroes.close_ui();check("release_"+hero.id,game.player.enabled and not heroes.modal_active)
		report.npcs.append(hero.id)
	check("walking",walked>3);check("jumping",jumped)
	game.campus_agent.open_panel();await process_frame
	check("guide_open",game.campus_agent.panel_open and not game.player.enabled)
	game.campus_agent.close_panel();check("guide_close",game.player.enabled)
	for spec in [["sakura",Vector3(0,.2,108),Vector3(0,1.8,139)],["lake",Vector3(70,.2,72),Vector3(90,1.5,110)],["south",Vector3(97.6,.2,713.3),Vector3(100,3,750)]]:
		game.player.set_view(spec[1],spec[2]);await wait_seconds(.8);await capture("native-"+spec[0])
	report.walked_m=walked
	FileAccess.open(output+"/native-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("API_SETTINGS_RUNTIME_QA ",JSON.stringify(report));quit(0 if report.passed else 1)
