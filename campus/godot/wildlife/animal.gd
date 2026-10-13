extends Node3D
## Standalone creature. Habitat nodes and observer use world coordinates.
signal behavior_changed(previous: String, current: String)

@export_enum("cat", "duck", "sparrow", "squirrel", "hedgehog") var species: String = "cat"
@export var asset_name: String = "cat_tabby"
@export var random_seed: int = 1958
@export var boldness: float = 0.5
@export var activity_nodes: Array[Vector3] = []
@export var node_modes: Array[String] = [] # ground, shore, water, perch
@export var route_links: Array[Vector2i] = [] # undirected local habitat graph
@export var water_polygon: PackedVector2Array = [] # X,Z footprint, world space
@export var water_height: float = 0.0
@export var observer: Node3D
@export var manual_simulation: bool = false

var model: Node3D
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var current_behavior: String = "rest"
var current_clip: String = "idle"
var rng := RandomNumberGenerator.new()
var elapsed: float = 0.0
var state_time: float = 0.0
var wait_time: float = 3.0
var node_index: int = 0
var target_index: int = 0
var route_start := Vector3.ZERO
var route_end := Vector3.ZERO
var route_time: float = 0.0
var route_duration: float = 1.0
var flight_duration: float = 1.0
var moving: bool = false
var fleeing: bool = false
var threat_latched: bool = false
var notice_latched: bool = false
var reaction_cooldown: float = 0.0
var measured_speed: float = 0.0
var observer_last := Vector3.ZERO
var observer_speed: float = 0.0
var observer_known: bool = false
var clip_override: String = ""
var animation_rate: float = 1.0
var animation_accumulator: float = 0.0
var wake: MeshInstance3D
var pending_motion: bool = false
var transition_time: float = 0.0
var transition_next: String = ""
var camera_distance: float = 0.0
var initial_node_index: int = 0
var preview_had_route: bool = false
var hidden_route: bool = false

func _ready() -> void:
	model = load("res://wildlife/assets/" + asset_name + ".glb").instantiate()
	model.name = "Visual"; add_child(model)
	animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for child in model.find_children("*", "Skeleton3D", true, false):
		skeleton = child; break
	assert(animation_player != null and skeleton != null, "Wildlife asset requires a skeleton and animations")
	# Each instance owns loop settings; external campus style() must not replace textures.
	for library_name in animation_player.get_animation_library_list():
		var library := animation_player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		animation_player.remove_animation_library(library_name)
		animation_player.add_animation_library(library_name, library)
	var machine := AnimationNodeStateMachine.new()
	for clip in animation_player.get_animation_list():
		if clip == "RESET": continue
		var animation := animation_player.get_animation(clip)
		animation.loop_mode = Animation.LOOP_LINEAR if clip in ["idle", "walk", "trot", "sit", "lie", "lick", "swim", "rest", "fly", "preen", "observe", "peck", "hop", "sniff", "forage"] else Animation.LOOP_NONE
		var node := AnimationNodeAnimation.new(); node.animation = clip
		machine.add_node(clip, node)
	for a in machine.get_node_list():
		if a in ["Start", "End"]: continue
		for b in machine.get_node_list():
			if b in [a, "Start", "End"]: continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = .16 if species == "cat" else .10
			machine.add_transition(a, b, transition)
	animation_tree = AnimationTree.new(); animation_tree.name = "AnimationTree"; add_child(animation_tree)
	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	animation_tree.tree_root = machine
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_tree.active = true
	playback = animation_tree.get("parameters/playback")
	if species == "duck": create_wake()
	reset_behavior()

func reset_behavior() -> void:
	rng.seed = random_seed; elapsed = 0; state_time = 0; moving = false; fleeing = false
	threat_latched = false; notice_latched = false; reaction_cooldown = 0; clip_override = ""
	pending_motion = false; transition_time = 0; observer_known = false; animation_accumulator = 0
	hidden_route = false
	node_index = initial_node_index; target_index = initial_node_index; measured_speed = 0; animation_rate = 1
	if not activity_nodes.is_empty(): global_position = activity_nodes[initial_node_index]
	current_behavior = "rest"; current_clip = "idle"; playback.start("idle", true)
	wait_time = rng.randf_range(2.5, 5.0)
	animation_tree.advance(0)

func configure_habitat(nodes: Array, modes: Array, links: Array, start: int = 0) -> void:
	activity_nodes.assign(nodes); node_modes.assign(modes); route_links.assign(links)
	assert(nodes.size() == modes.size() and start < nodes.size())
	initial_node_index = start; node_index = start; target_index = start; global_position = nodes[start]
	if modes[start] == "water": play_clip("swim")

func mode_at(index: int) -> String:
	return node_modes[index] if index < node_modes.size() else "ground"

func set_behavior(next: String) -> void:
	if current_behavior != next:
		var previous := current_behavior; current_behavior = next
		behavior_changed.emit(previous, next)
	state_time = 0

func play_clip(clip: String, restart: bool = false) -> void:
	assert(animation_player.has_animation(clip), "Missing animal animation: " + clip)
	if current_clip == clip and not restart: return
	current_clip = clip
	if restart: playback.start(clip, true)
	else: playback.travel(clip)

func available_clips() -> PackedStringArray:
	var clips := animation_player.get_animation_list()
	if "RESET" in clips: clips.remove_at(clips.find("RESET"))
	return clips

func preview_clip(clip: String) -> void:
	if clip_override.is_empty(): preview_had_route = moving or pending_motion
	clip_override = clip; moving = false; pending_motion = false; measured_speed = 0; animation_rate = 1
	transition_time = 0
	play_clip(clip, true); set_behavior("preview")

func resume_behavior() -> void:
	clip_override = ""; pending_motion = false; transition_time = 0
	if preview_had_route:
		preview_had_route = false; start_motion()
	else: set_behavior("rest"); wait_time = 1.5; play_clip("idle")

func neighbors(index: int) -> Array[int]:
	var result: Array[int] = []
	for edge in route_links:
		if edge.x == index: result.append(edge.y)
		elif edge.y == index: result.append(edge.x)
	return result

func choose_destination(avoid: bool = false) -> int:
	var choices := neighbors(node_index)
	if choices.is_empty(): return node_index
	if avoid and is_instance_valid(observer):
		var best := choices[0]; var farthest: float = -1
		for index in choices:
			var distance := activity_nodes[index].distance_squared_to(observer.global_position)
			if distance > farthest: best = index; farthest = distance
		return best
	return choices[rng.randi_range(0, choices.size()-1)]

func begin_route(destination: int, avoid: bool = false) -> void:
	if destination == node_index: return
	target_index = destination; fleeing = avoid
	# Getting up is an action before displacement, not a crossfade through the floor.
	if species == "cat" and current_clip in ["lie", "lick", "sit"]:
		pending_motion = true; transition_next = "move"
		play_clip("stand_up" if current_clip == "sit" else "rise", true)
		transition_time = animation_player.get_animation(current_clip).length
		set_behavior("get_up"); return
	start_motion()

func start_motion() -> void:
	pending_motion = false; route_start = global_position; route_end = activity_nodes[target_index]; route_time = 0
	var length := route_start.distance_to(route_end)
	var speed: float = {"cat": .25 if not fleeing else .75, "duck": .30 if not fleeing else .52, "sparrow": 1.6, "squirrel": .12 if not fleeing else .30, "hedgehog": .045}[species]
	flight_duration = maxf(.5, 1.5*length/speed)
	route_duration = flight_duration
	if species == "sparrow" and (length > .55 or mode_at(node_index) == "perch" or mode_at(target_index) == "perch"):
		route_duration += .7; play_clip("takeoff", true)
	elif species == "sparrow": route_duration = .36; play_clip("hop", true)
	elif species == "duck":
		if mode_at(node_index) == "water" and mode_at(target_index) != "water": play_clip("exit_water", true)
		elif mode_at(node_index) != "water" and mode_at(target_index) == "water": play_clip("enter_water", true)
		else: play_clip("swim" if mode_at(target_index) == "water" else "walk")
	elif species == "hedgehog": play_clip("walk")
	else: play_clip("trot" if fleeing else "walk")
	moving = true; set_behavior("avoid" if fleeing else "travel")

func visible_observer() -> bool:
	if not is_inside_tree() or not is_instance_valid(observer): return false
	var from := global_position + Vector3.UP*(.30 if species == "cat" else .20)
	var target := observer.global_position + Vector3.UP*.65
	var query := PhysicsRayQueryParameters3D.create(from, target, 1)
	if observer is CollisionObject3D: query.exclude = [observer.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func react_to_observer(dt: float) -> void:
	if not is_instance_valid(observer): observer_known = false; return
	if observer_known: observer_speed = observer.global_position.distance_to(observer_last)/dt
	else: observer_speed = 0; observer_known = true
	observer_last = observer.global_position
	var distance := Vector2(global_position.x, global_position.z).distance_to(Vector2(observer_last.x, observer_last.z))
	var notice: float = {"cat": 2.6, "duck": 3.1, "sparrow": 2.2, "squirrel": 2.4, "hedgehog": 1.5}[species]
	var escape: float = {"cat": .85, "duck": 1.45, "sparrow": 1.05, "squirrel": 1.0, "hedgehog": .65}[species]*(1.20-boldness*.4)
	if distance > notice+1:
		threat_latched = false; notice_latched = false
	if pending_motion or reaction_cooldown > 0 or fleeing or (moving and species == "sparrow"): return
	if distance < escape+(.65 if observer_speed>2.5 else 0) and not threat_latched and visible_observer():
		threat_latched = true; reaction_cooldown = 4.5
		if species == "hedgehog":
			hidden_route = moving
			moving = false; measured_speed = 0; animation_rate = 1
			play_clip("hide",true); set_behavior("hide"); wait_time = 3.2
			return
		if moving:
			# Reverse or continue along this already valid edge; never cut a new diagonal.
			var source_distance := activity_nodes[node_index].distance_squared_to(observer_last)
			var target_distance := activity_nodes[target_index].distance_squared_to(observer_last)
			target_index = target_index if target_distance>=source_distance else node_index
			fleeing = true; start_motion()
		else: begin_route(choose_destination(true), true)
	elif not moving and distance < notice and not notice_latched and visible_observer():
		notice_latched = true; play_clip("observe"); set_behavior("watch"); wait_time = 1.5

func update_route(dt: float) -> void:
	route_time = minf(route_time+dt, route_duration)
	var before := global_position
	var flight := species == "sparrow" and route_duration > .7
	var u: float = clampf((route_time-.3)/flight_duration, 0, 1) if flight else route_time/route_duration
	var q := u*u*(3-2*u)
	global_position = route_start.lerp(route_end, q)
	if flight:
		global_position.y += sin(PI*u)*(.32+minf(route_start.distance_to(route_end)*.11, .45))
		if route_time < .3: play_clip("takeoff")
		elif route_time > route_duration-.4: play_clip("land")
		else: play_clip("fly")
	var direction := global_position-before; measured_speed = direction.length()/dt
	if species=="duck" and mode_at(node_index)!=mode_at(target_index) and route_time>.4:
		var on_water: bool=Geometry2D.is_point_in_polygon(Vector2(global_position.x,global_position.z),water_polygon) if water_polygon.size()>2 else false
		if on_water and global_position.y<=water_height-.075:play_clip("swim")
		elif not on_water:play_clip("walk")
	if direction.length() > .00005:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1-exp(-dt*9))
	if species == "cat":
		var nominal: float = (.235 if fleeing else .16)/((.52 if fleeing else .64)*animation_player.get_animation("trot" if fleeing else "walk").length)
		animation_rate = clampf(measured_speed/nominal, .0, 2.2)
	elif species == "duck":
		if current_clip == "walk": animation_rate = clampf(measured_speed/(.12/(.63*animation_player.get_animation("walk").length)),0,2.4)
		else: animation_rate = clampf(measured_speed/.30,.25,1.8)
	elif species in ["squirrel", "hedgehog"]:
		var stride: float = .056 if species == "squirrel" else .027
		var duty: float = .5 if fleeing else .63
		animation_rate = clampf(measured_speed/(stride/(duty*animation_player.get_animation(current_clip).length)),0,2.5)
	else: animation_rate = 1
	if route_time >= route_duration:
		node_index = target_index; moving = false; fleeing = false; measured_speed = 0; animation_rate = 1
		global_position = route_end
		choose_rest()

func choose_rest() -> void:
	set_behavior("rest"); wait_time = rng.randf_range(3.5, 8.5)
	if species == "cat":
		var choice := rng.randi_range(0,3)
		if choice == 0: transition_next = "sit"; play_clip("sit_down",true)
		elif choice == 1: transition_next = "lie"; play_clip("lie_down",true)
		elif choice == 2: transition_next = "idle"; play_clip("stretch",true)
		else: play_clip("idle"); return
		transition_time = animation_player.get_animation(current_clip).length
	elif species == "duck":
		play_clip("swim" if mode_at(node_index)=="water" else ("preen" if rng.randf()<.5 else "rest"))
	elif species == "squirrel":
		wait_time = rng.randf_range(2.0,5.5)
		play_clip("forage" if rng.randf()<.5 else "observe")
	elif species == "hedgehog":
		wait_time = rng.randf_range(4.0,9.0)
		play_clip("sniff" if rng.randf()<.7 else "idle")
	else: play_clip("peck" if mode_at(node_index)!="perch" and rng.randf()<.6 else "preen")

func simulate(dt: float) -> void:
	elapsed += dt; state_time += dt; reaction_cooldown = maxf(0,reaction_cooldown-dt)
	if clip_override.is_empty():
		react_to_observer(dt)
		if transition_time > 0:
			transition_time -= dt
			if transition_time <= 0:
				if pending_motion: start_motion()
				else: play_clip(transition_next)
		elif moving: update_route(dt)
		elif state_time >= wait_time:
			if species == "hedgehog" and hidden_route:
				hidden_route = false; moving = true; play_clip("walk"); set_behavior("travel")
			elif species == "cat" and current_clip == "lie" and rng.randf()<.35:
				play_clip("lick"); state_time = 0; wait_time = 4
			else: begin_route(choose_destination())
	else: animation_rate = 1
	var camera := get_viewport().get_camera_3d()
	camera_distance = camera.global_position.distance_to(global_position) if camera else 0
	animation_accumulator += dt*animation_rate
	var interval := 1.0/15 if camera_distance>35 else (1.0/30 if camera_distance>18 else 0.0)
	if animation_accumulator >= interval:
		animation_tree.advance(animation_accumulator); animation_accumulator = 0
	if species == "duck":
		var water := Geometry2D.is_point_in_polygon(Vector2(global_position.x,global_position.z),water_polygon) if water_polygon.size()>2 else mode_at(node_index)=="water"
		wake.visible = water and moving and current_clip not in ["enter_water","exit_water"]
		wake.position.y = water_height-global_position.y+.007
		model.rotation.z = lerpf(model.rotation.z, sin(elapsed*2.1)*.012 if water else 0, .10)

func _physics_process(dt: float) -> void:
	if not manual_simulation: simulate(dt)

func create_wake() -> void:
	wake = MeshInstance3D.new(); wake.name = "Wake"
	var plane := PlaneMesh.new(); plane.size = Vector2(.46,.78); wake.mesh = plane
	var mat := ShaderMaterial.new(); mat.shader = preload("res://wildlife/wake.gdshader"); wake.material_override = mat
	wake.position.z = .34; wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(wake)

func snapshot() -> Dictionary:
	return {"species":species,"asset":asset_name,"behavior":current_behavior,"clip":current_clip,
		"position":[global_position.x,global_position.y,global_position.z],"node":node_index,
		"target":target_index,"moving":moving,"speed":measured_speed,"animation_rate":animation_rate,
		"observer_speed":observer_speed,"bones":skeleton.get_bone_count(),"clips":available_clips(),
		"finite":global_position.is_finite(),"camera_distance":camera_distance}
