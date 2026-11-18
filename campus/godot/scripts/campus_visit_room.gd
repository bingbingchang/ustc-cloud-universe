extends Node3D

const Door = preload("res://scripts/campus_visit_door.gd")
const North = preload("res://scripts/north_axis_environment.gd")
const Interior = preload("res://scripts/campus_visit_interior.gd")
const Teaching = preload("res://scripts/teaching_interior.gd")

var spec: Dictionary
var doors: Array[Node3D] = []
var contents: Node3D
var edge_length: float
var preload_pending := false
var teaching_layout: Dictionary = {}
var building_outline: PackedVector2Array
var building_bounds: Rect2
var _teaching_structure: Node3D


func configure(room: Dictionary) -> void:
	spec = room
	var a := Vector3(room.edge[0][0], room.floor, room.edge[0][1])
	var b := Vector3(room.edge[1][0], room.floor, room.edge[1][1])
	edge_length = a.distance_to(b)
	var along := (b-a).normalized()
	var center := a.lerp(b,.5+float(room.get("offset",0.0)))
	transform = Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), center)
	name = "Visit_" + str(room.id).to_snake_case()


func shell_opening(outline: PackedVector2Array) -> Array[PackedVector2Array]:
	var half := float(spec.width)*.5
	var cutting := PackedVector2Array()
	# The cut reaches the outside at this facade, so the difference has no
	# interior ring. The occupied volume ends at the back wall of the visit.
	for local: Vector2 in [Vector2(-half,-.7), Vector2(half,-.7),
			Vector2(half,spec.depth), Vector2(-half,spec.depth)]:
		var world := transform * Vector3(local.x,0,local.y)
		cutting.append(Vector2(world.x,world.z))
	var segments := Geometry2D.clip_polygons(outline, cutting)
	if segments.is_empty():
		return []
	var remaining_area := 0.0
	for segment in segments:
		if Geometry2D.is_polygon_clockwise(segment):
			return []
		remaining_area += polygon_area(segment)
	if polygon_area(outline) - remaining_area < 1.0:
		return []
	return segments


func polygon_area(points: PackedVector2Array) -> float:
	var origin := points[0]
	var area := 0.0
	for i in range(1, points.size()-1):
		area += (points[i]-origin).cross(points[i+1]-origin)
	return absf(area)*.5


func build_entry() -> void:
	var half := float(spec.width)*.5
	var ceiling := float(spec.height)
	var first := -half
	for row: Dictionary in spec.doors:
		var x := float(row.offset)*edge_length
		var width := float(row.span)*edge_length
		var sill := -float(row.outset)
		var door := Door.new()
		door.position = Vector3(x,0,sill)
		door.name = str(row.id).to_pascal_case()
		add_child(door)
		door.build(row, width, Interior.door_palette(row.panel))
		doors.append(door)
		_closing_box(first, x-width*.5, 0, ceiling, sill, "FixedFacade")
		_closing_box(x-width*.5, x+width*.5, row.height, ceiling, sill, "FixedLintel")
		first = x+width*.5
	_closing_box(first,half,0,ceiling,-float(spec.doors[-1].outset),"FixedFacade")


func _closing_box(start: float, end: float, low: float, high: float, depth: float, label: String) -> void:
	if end-start <= .015 or high-low <= .015:
		return
	Interior.collider(self,label,Vector3((start+end)*.5,(low+high)*.5,depth),
		Vector3(end-start, high-low, .15))


func distance_from(position_world: Vector3) -> float:
	if not teaching_layout.is_empty():
		var bounds := building_bounds
		var roof: float = float(spec.floor) + float(teaching_layout.floor_height) * teaching_layout.levels.size()
		return position_world.distance_to(Vector3(clampf(position_world.x, bounds.position.x, bounds.end.x),
			clampf(position_world.y, spec.floor, roof), clampf(position_world.z, bounds.position.y, bounds.end.y)))
	var local := to_local(position_world)
	return local.distance_to(Vector3(clampf(local.x,-float(spec.width)*.5,float(spec.width)*.5),
		clampf(local.y,0,float(spec.height)), clampf(local.z,0,float(spec.depth))))


func build_public_interior() -> void:
	# Keep the floor, walls and lighting visible through the exterior glass.
	# The public circulation stays available while classrooms load on approach.
	if teaching_layout.is_empty():
		contents = Node3D.new()
		contents.name = "PublicInterior"
		add_child(contents)
		Interior.build(contents, spec)
	else:
		_teaching_structure = Teaching.new()
		_teaching_structure.name = "PublicInterior"
		_teaching_structure.top_level = true
		add_child(_teaching_structure)
		_teaching_structure.global_transform = Transform3D.IDENTITY
		_teaching_structure.build(self, teaching_layout)


func prepare() -> void:
	if not _teaching_structure or contents or preload_pending:
		return
	preload_pending = true
	call_deferred("_populate")


func _populate() -> void:
	_teaching_structure.load_classrooms()
	await get_tree().physics_frame
	contents = _teaching_structure
	preload_pending = false


func classroom_doors() -> Array[Node3D]:
	if contents and not teaching_layout.is_empty():
		return contents.doors
	return []


func release_contents() -> void:
	if contents and _teaching_structure:
		_teaching_structure.release_classrooms()
		contents = null
