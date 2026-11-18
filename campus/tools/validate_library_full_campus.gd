extends "res://../tools/validate_library_walkthrough.gd"
## Run once with other heavy test processes closed. This uses the full shipped
## gameplay scene and captures the library under its actual campus lighting.

func run() -> void:
	source_asset_sha256=FileAccess.get_sha256("res://assets/south_library.glb")
	if output.is_empty():output="res://../renders/library_full_campus"
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://scenes/campus_game.tscn").instantiate()
	root.add_child(game)
	player=game.player
	root.grab_focus()
	player.touch_mode=true
	player.toggle_view()
	await wait_physics(18)
	verify("full_campus_ready",game.game_ready)
	var room: Node3D
	for candidate in game.campus_visits.rooms:
		if candidate.spec.id=="new-library":room=candidate
	verify("new_library_room_registered",room!=null)
	if not room:
		quit(1);return
	for door in room.doors:
		await check_door(room,door,true)
	game.hero_interactions.layer.hide()
	game.campus_agent.layer.hide()
	game.locator.hide()
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/library_district_manifest.json"))
	var pose := District.asset_transform(manifest.assets.south_library)
	await photograph("campus-front",pose*Vector3(0,8,60),pose*Vector3(0,13,-3),57)
	await photograph("campus-entrance",pose*Vector3(15,5,25),pose*Vector3(0,8,-1),63)
	await photograph("campus-side",pose*Vector3(64,13,-12),pose*Vector3(0,13,-12),55)
	await photograph("campus-oblique",pose*Vector3(62,42,57),pose*Vector3(0,13,-10),57)
	var passed := not results.is_empty() and not results.values().has(false)
	var file=FileAccess.open(output.path_join("visits.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":results,"source_asset_sha256":source_asset_sha256,
		"scope":"Full campus_game scene, both production library doors and actual campus lighting."},"\t"))
	file.close()
	print("LIBRARY_FULL_CAMPUS_COMPLETE ",passed)
	quit(0 if passed else 1)
