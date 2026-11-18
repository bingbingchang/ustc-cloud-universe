extends Node

const Room = preload("res://scripts/campus_visit_room.gd")
const Teaching = preload("res://scripts/teaching_interior.gd")
const North = preload("res://scripts/north_axis_environment.gd")
const MAX_REACH := 2.18
const PRELOAD_METRES := 16.0
const UNLOAD_METRES := 32.0

var game
var rooms: Array[Node3D] = []
var selected: Node3D
var _specs: Dictionary = {}
var _accepted: Dictionary = {}
var _teaching_plans: Dictionary = {}
var _request: Node3D
var _label: Label
var _preload_clock := 0.0


func configure(owner_game: Node3D) -> void:
	game = owner_game
	if not FileAccess.file_exists("res://data/campus_visits.json"):
		return
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/campus_visits.json"))
	if not catalog is Array:
		push_error("Campus visit entrance catalog is invalid.")
		return
	for plan: Dictionary in catalog:
		_specs[plan.shell] = plan
	if FileAccess.file_exists("res://data/teaching_interiors.json"):
		var plans: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/teaching_interiors.json"))
		if plans is Dictionary:
			_teaching_plans = plans


func replace_shell(outline: PackedVector2Array, bottom: float, top: float, label: String) -> bool:
	if not _specs.has(label):
		return false
	var plan: Dictionary = _specs[label]
	var model: Node3D = game.world.get_node_or_null(plan.model)
	if not model:
		push_error("Missing exterior for campus visit: "+str(plan.id))
		return false
	var fallback: Array[Node] = []
	for part in model.get_children():
		if part is MeshInstance3D and ("PhotoVisitGlass" in part.name or "PhotoVisitWood" in part.name):
			fallback.append(part)
	if fallback.is_empty():
		push_error("Missing door leaf export for campus visit: "+str(plan.id))
		return false
	var room := Room.new()
	room.configure(plan)
	var walls := room.shell_opening(outline)
	if walls.is_empty():
		room.free()
		push_error("Campus visit opening does not intersect its facade: "+str(plan.id))
		return false
	var teaching: Dictionary = _teaching_plans.get(plan.id, {})
	game.world.add_child(room)
	if teaching.is_empty():
		var floor_height := float(plan.floor)
		var ceiling_height := floor_height + float(plan.height)
		if floor_height > bottom:
			North._solid(game,[outline],bottom,floor_height,label+"_foundation")
		for wall in walls:
			North._solid(game,[wall],maxf(bottom,floor_height),minf(ceiling_height,top),label+"_wall")
		if ceiling_height < top:
			North._solid(game,[outline],ceiling_height,top,label+"_upper")
	else:
		room.teaching_layout = teaching
		room.building_outline = North.polygon(teaching.footprint) if teaching.has("footprint") else outline
		room.building_bounds = North._bounds(room.building_outline)
		_build_teaching_perimeter(room, bottom, top)
		_remove_old_teaching_backing(plan.id, model)
	for leaf in fallback:
		leaf.hide()
	room.build_entry()
	if plan.style=="teaching-one":
		_clear_teaching_one_shell(model, room)
	room.build_public_interior()
	rooms.append(room)
	_accepted[label] = true
	return true


func _build_teaching_perimeter(room: Node3D, bottom: float, top: float) -> void:
	var points: PackedVector2Array = room.building_outline
	var opening := Teaching.entry_cut(room)
	var wall_parts: Array = []
	for i in points.size():
		var edge := PackedVector2Array([points[i], points[(i + 1) % points.size()]])
		for strip: PackedVector2Array in North._stroke(edge, .19):
			wall_parts.append_array(Geometry2D.clip_polygons(strip, opening))
	North._solid(game, wall_parts, bottom, top, "TeachingExteriorPerimeter")


func _remove_old_teaching_backing(id: String, model: Node3D) -> void:
	var names: Array = {
		"teaching-two": ["PhotoDarkReveal"],
		"teaching-five": ["Teaching5EntryInterior", "Teaching5EntryInteriorShadow", "Teaching5EntryAtrium"]
	}.get(id, [])
	for mesh in model.get_children():
		for suffix: String in names:
			if str(mesh.name).ends_with("_" + suffix):
				mesh.hide()


func _clear_teaching_one_shell(model: Node3D, room: Node3D) -> void:
	# Cut the north facade only within the entrance. Its fixed glass reaches
	# the top frame at y=4.115, above the usable door opening in the room spec.
	var half := float(room.spec.width) * .5
	var has_floors: bool = not room.teaching_layout.is_empty()
	var depth := .99 if has_floors else float(room.spec.depth)
	var clearance := 4.13 - room.global_position.y if has_floors else float(room.spec.height) + .006
	var mins := PackedVector3Array([room.to_global(Vector3(-half - .012, -.01, -.025)),
		Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
	var maxs := PackedVector3Array([room.to_global(Vector3(half + .012, clearance, depth)),
		Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
	if has_floors:
		# Clear the old solids inside the public rooms, behind the facade glazing.
		mins[1] = Vector3(-61.91, .469, 168.31)
		maxs[1] = Vector3(61.91, 17.03, 183.91)
		mins[2] = Vector3(-61.91, .469, 179.81)
		maxs[2] = Vector3(-47.915, 17.03, 221.91)
		mins[3] = Vector3(47.915, .469, 179.81)
		maxs[3] = Vector3(61.91, 17.03, 221.91)
		mins[4] = Vector3(-15.41, .469, 178.40)
		maxs[4] = Vector3(15.41, 17.03, 189.20)
	var variants: Dictionary[Shader,Shader] = {}
	var finishes := ["Brick","Dark","Stone"]
	if has_floors:
		finishes.append("BrickWarm")
	for finish in finishes:
		var mesh := model.get_node_or_null("ArchivedLookDevHall_Architecture_"+finish) as MeshInstance3D
		if not mesh:
			continue
		var material := mesh.get_active_material(0) as ShaderMaterial
		if not material or not material.shader:
			continue
		var original := material.shader
		if not variants.has(original):
			var shader := Shader.new()
			shader.code="#define VISIT_OPENING\n"+original.code
			variants[original]=shader
		var clipped := material.duplicate() as ShaderMaterial
		clipped.shader=variants[original]
		clipped.set_shader_parameter("visit_clip_min", mins)
		clipped.set_shader_parameter("visit_clip_max", maxs)
		mesh.set_surface_override_material(0,clipped)
		game.art_mats.append(clipped)


func opened_shell(label: String) -> bool:
	return _accepted.has(label)


func teaching_building_open(id: String) -> bool:
	for room in rooms:
		if room.spec.id == id and not room.teaching_layout.is_empty():
			return true
	return false


func _ready() -> void:
	_label=game.label("",20,Color("fff9ec"))
	_label.add_theme_font_override("font",preload("res://scripts/campus_font.gd").get_font())
	_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	game.hud.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_label.position.y -= 155.0
	_label.position.x -= 180.0
	_label.custom_minimum_size.x=360.0
	_label.hide()


func _active() -> bool:
	var player: CharacterBody3D = game.player
	var heroes = game.hero_interactions
	var widget := get_viewport().gui_get_focus_owner()
	return (player.enabled and not player.frozen and not player.free_camera
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		and (not heroes or not heroes.modal_active)
		and (not game.campus_agent or not game.campus_agent.panel_open)
		and not (widget is LineEdit or widget is TextEdit))


func _can_reach(door: Node3D, player: CharacterBody3D) -> bool:
	var offset: Vector3 = door.global_position-player.global_position
	if absf(offset.y) > .95:
		return false
	offset.y = 0.0
	if offset.length_squared() > MAX_REACH*MAX_REACH:
		return false
	var facing: Vector3 = -player.orbit.global_basis.z
	facing.y=0
	return offset.is_zero_approx() or facing.normalized().dot(offset.normalized()) > .52


func _select(player: CharacterBody3D) -> Node3D:
	var closest: Node3D
	var best := INF
	var space := player.get_world_3d().direct_space_state
	var eyes: Vector3 = player.global_position + Vector3.UP*1.54
	for room in rooms:
		for door: Node3D in room.doors + room.classroom_doors():
			if not _can_reach(door,player):
				continue
			var point: Vector3 = door.global_position + Vector3.UP*1.24
			var distance := eyes.distance_squared_to(point)
			if distance >= best:
				continue
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eyes,point,1,[player.get_rid()]))
			if not hit.is_empty() and not door.is_ancestor_of(hit.collider):
				continue
			best=distance
			closest=door
	return closest


func interact() -> bool:
	if not is_instance_valid(selected) or not _active() or not _can_reach(selected,game.player):
		return false
	var room := selected.get_parent()
	if room.get_script() == Room and not room.contents:
		_request=selected
		room.prepare()
	else:
		selected.toggle(game.player)
	return true


func _physics_process(delta: float) -> void:
	var player: CharacterBody3D = game.player
	_preload_clock += delta
	if _preload_clock >= .25:
		_preload_clock=0
		for room in rooms:
			if room.teaching_layout.is_empty():
				continue
			var distance: float = room.distance_from(player.global_position)
			if distance < PRELOAD_METRES:
				room.prepare()
			elif distance > UNLOAD_METRES:
				room.release_contents()
	for room in rooms:
		for door in room.doors + room.classroom_doors():
			door.advance(delta,player)
	selected=_select(player) if _active() else null
	if _request and _request != selected:
		_request=null
	if _request and _request.get_parent().contents:
		_request.toggle(player)
		_request=null
	_label.visible=selected!=null
	if selected:
		if _request:
			_label.text="门厅加载中…"
		elif selected.contains_player(player):
			_label.text="请离开门扇范围"
		else:
			_label.text="E 关门" if selected.target_open else "E 开门"
