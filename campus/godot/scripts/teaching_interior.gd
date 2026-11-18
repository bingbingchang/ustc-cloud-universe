extends Node3D
## The public plans establish the room order and circulation. Metre dimensions
## fit the existing campus footprint and portal rather than a survey drawing.

const North = preload("res://scripts/north_axis_environment.gd")
const Fit = preload("res://scripts/campus_visit_interior.gd")
const Door = preload("res://scripts/campus_visit_door.gd")
const RoomDetails = preload("res://scripts/teaching_room_details.gd")
const STAIR_WIDTH := 3.6
const STAIR_DEPTH := 6.6
const STAIR_LANDING := 1.58
const DOOR_HEIGHT := 2.24
const SIDES := {"north": 0, "east": 1, "south": 2, "west": 3}

var doors: Array[Node3D] = []
var level_data: Array[Dictionary] = []
var _batches: Dictionary = {}
var _solid: StaticBody3D
var _materials: Dictionary = {}
var _stairs: Transform3D
var _entry: PackedVector2Array
var _fixed_glass: PackedVector2Array
var _curtain_wall: PackedVector2Array
var _classroom_plans: Dictionary = {}
var _classrooms: Array[Node3D] = []


static func entry_cut(visit: Node3D) -> PackedVector2Array:
	var width := float(visit.spec.width) + .20
	var passage := PackedVector2Array()
	for point in North._rect(-width * .5, -.75, width, 2.10):
		var world: Vector3 = visit.to_global(Vector3(point.x, 0, point.y))
		passage.append(Vector2(world.x, world.z))
	return passage


func build(visit: Node3D, layout: Dictionary) -> void:
	var base_height := float(visit.spec.floor)
	var rise := float(layout.floor_height)
	var stair: Array = layout.stair
	_stairs = Transform3D(Basis(Vector3.UP, stair[2]), Vector3(stair[0], 0, stair[1]))
	_entry = entry_cut(visit)
	var footprint: PackedVector2Array = visit.building_outline
	var setback := float(layout.get("interior_setback", 0.0))
	if setback > 0.0:
		# Keep the interior walls and slabs behind the exterior cladding and glass.
		var inset := Geometry2D.offset_polygon(footprint, -setback, Geometry2D.JOIN_MITER)
		if inset.size() == 1:
			footprint = inset[0]
	var glazing_cut_width := .36 + 2.0 * setback
	if layout.has("fixed_glazing"):
		var glazing: Array = layout.fixed_glazing
		var edge: int = glazing[0]
		var facade: PackedVector2Array = visit.building_outline
		var a := facade[edge]
		var b := facade[(edge + 1) % facade.size()]
		var half := (b - a).normalized() * float(glazing[1]) * .5
		var center := (a + b) * .5
		_fixed_glass = North._stroke(PackedVector2Array([center - half, center + half]), glazing_cut_width)[0]
	if layout.get("entry_curtain_wall", false):
		_curtain_wall = North._stroke(North.polygon(visit.spec.edge), glazing_cut_width)[0]
	_prepare_materials()
	var stair_hole := PackedVector2Array()
	for point in North._rect(-STAIR_WIDTH * .5, -STAIR_DEPTH * .5, STAIR_WIDTH, STAIR_DEPTH):
		var p := _stairs * Vector3(point.x, 0, point.y)
		stair_hole.append(Vector2(p.x, p.z))
	var atrium := North.polygon(layout.get("void", []))
	for index in layout.levels.size():
		var level: Dictionary = layout.levels[index]
		var storey := Node3D.new()
		storey.name = "Floor%d" % (index + 1)
		storey.position.y = base_height + rise * index
		add_child(storey)
		_solid = StaticBody3D.new()
		_solid.name = "PartitionsAndStairs"
		storey.add_child(_solid)
		_batches.clear()
		var plan := _outline(footprint, level, index == 0)
		var has_upper: bool = index + 1 < layout.levels.size()
		var cuts: Array = [] if atrium.is_empty() else [atrium]
		var floor_cuts := cuts.duplicate()
		var ceiling_cuts := cuts.duplicate()
		if index > 0:
			floor_cuts.append(stair_hole)
		if has_upper:
			ceiling_cuts.append(stair_hole)
		_build_surface(storey, plan, floor_cuts, 0, _materials.floor, Vector3.UP, "FloorSlab")
		_build_surface(storey, plan, ceiling_cuts, rise - .19, _materials.ceiling, Vector3.DOWN, "Ceiling")
		_perimeter(plan, rise - .17, index == 0)
		if not atrium.is_empty():
			for edge in atrium.size():
				_rail(atrium[edge], atrium[(edge + 1) % atrium.size()], 0)
		var classroom_centers: Dictionary = {}
		for row: Array in level.rooms:
			classroom_centers[row[0]] = Vector2((row[1] + row[3]) * .5, (row[2] + row[4]) * .5)
		_classroom_plans[storey] = {"rows": level.rooms, "height": rise - .17, "building": visit.spec.id}
		_stairwell(storey, rise, has_upper, index, layout.heading)
		for source: Array in [layout.get("hall_lights", []), level.get("hall_lights", [])]:
			for point: Array in source:
				var center := Vector2(point[0], point[1])
				if plan.any(func(part): return Geometry2D.is_point_in_polygon(center, part)) and (atrium.is_empty() or not Geometry2D.is_point_in_polygon(center, atrium)):
					_light(storey, center, rise - .36, 9)
		for point: Array in level.get("stair_signs", []):
			Fit.lettering(storey, "↑ 楼梯", Vector3(point[0], 2.42, point[1]),
				.008, Color("45392c")).rotation.y = 0
		_flush_boxes(storey)
		level_data.append({
			"floor": index + 1, "height": storey.position.y, "rooms": classroom_centers,
			"stair_start": _stairs * Vector3(-STAIR_WIDTH * .25, storey.position.y, STAIR_DEPTH * .5 + .60),
			"stair_turn_a": _stairs * Vector3(-STAIR_WIDTH * .25, storey.position.y + rise * .5, -STAIR_DEPTH * .5 + .45),
			"stair_turn_b": _stairs * Vector3(STAIR_WIDTH * .25, storey.position.y + rise * .5, -STAIR_DEPTH * .5 + .45),
			"stair_finish": _stairs * Vector3(STAIR_WIDTH * .25, storey.position.y + rise, STAIR_DEPTH * .5 + .60)
		})


func load_classrooms() -> void:
	for floor_node: Node3D in _classroom_plans:
		var plan: Dictionary = _classroom_plans[floor_node]
		var group := Node3D.new()
		group.name = "Classrooms"
		floor_node.add_child(group)
		_solid = StaticBody3D.new()
		group.add_child(_solid)
		_batches.clear()
		for row: Array in plan.rows:
			_classroom(group, row, plan.height, plan.building)
		_flush_boxes(group)
		_classrooms.append(group)


func release_classrooms() -> void:
	for group in _classrooms:
		group.queue_free()
	_classrooms.clear()
	doors.clear()


func _outline(shell: PackedVector2Array, level: Dictionary, ground: bool) -> Array[PackedVector2Array]:
	var parts: Array[PackedVector2Array] = [shell]
	if level.get("omit_south", false):
		parts = Geometry2D.intersect_polygons(shell, North._rect(90, 285, 100, 32.0))
	if level.get("omit_east", false):
		var trimmed: Array[PackedVector2Array] = []
		for part in parts:
			trimmed.append_array(Geometry2D.clip_polygons(part, North._rect(159.12, 285, 30, 33.0)))
		parts = trimmed
	if ground:
		var entrance := _entry.duplicate()
		# Trim the approach outside the actual door plane. The larger cut is used
		# separately on the facade so closed leaves supply the visible boundary.
		entrance[0] = entrance[0].lerp(entrance[3], .25)
		entrance[1] = entrance[1].lerp(entrance[2], .25)
		var joined := Geometry2D.merge_polygons(parts[0], entrance)
		if not joined.is_empty():
			parts = joined
	return parts


func _build_surface(parent: Node3D, outline: Array, cuts: Array, y: float, material: Material,
		normal: Vector3, label: String) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon: PackedVector2Array in outline:
		var fragments := [polygon] if cuts.is_empty() else North._pieces(polygon, cuts)
		for part: PackedVector2Array in fragments:
			var triangles := Geometry2D.triangulate_polygon(part)
			for i in range(0, triangles.size(), 3):
				var triangle := PackedVector3Array()
				for offset in range(3):
					var p := part[triangles[i + offset]]
					triangle.append(Vector3(p.x, y, p.y))
				if (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).dot(normal) > 0:
					triangle.reverse()
				for point in triangle:
					surface.set_normal(normal)
					surface.set_uv(Vector2(point.x, point.z))
					surface.add_vertex(point)
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	if not mesh.mesh:
		mesh.free()
		return
	mesh.material_override = material
	parent.add_child(mesh)
	var shape := mesh.mesh.create_trimesh_shape()
	if shape:
		shape.backface_collision = true
		var collision := CollisionShape3D.new()
		collision.shape = shape
		_solid.add_child(collision)


func _prepare_materials() -> void:
	_materials.floor = Fit.tiles(Color("b0a89b"), Vector2(.62, .62))
	_materials.ceiling = Fit.material(Color("e4e0d8"))
	_materials.ceiling.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials.wall = Fit.material(Color("ddd5c7"))
	_materials.plinth = Fit.material(Color("716962"))
	_materials.rail = Fit.material(Color("5d7175"), .50, .35)
	_materials.step = Fit.material(Color("aaa397"))
	_materials.nosing = Fit.material(Color("594e43"), .63)
	_materials.desk = Fit.material(Color("ad8a61"), .56)
	_materials.seat = Fit.material(Color("5c777e"), .64)
	_materials.board = Fit.material(Color("315455"), .68)
	_materials.lamp = Fit.material(Color("ece9e0"))
	_materials.lamp.emission_enabled = true
	_materials.lamp.emission = Color("fff2d6")
	_materials.lamp.emission_energy_multiplier = .40


func _perimeter(parts: Array, height: float, ground: bool) -> void:
	var openings: Array[PackedVector2Array] = []
	if not _curtain_wall.is_empty():
		openings.append(_curtain_wall)
	if ground:
		openings.append(_entry)
		if not _fixed_glass.is_empty():
			openings.append(_fixed_glass)
	for part: PackedVector2Array in parts:
		for i in part.size():
			var a := part[i]
			var b := part[(i + 1) % part.size()]
			var offsets: Array[float] = [0.0, 1.0]
			for pane: PackedVector2Array in openings:
				for j in pane.size():
					var contact = Geometry2D.segment_intersects_segment(a, b, pane[j], pane[(j + 1) % pane.size()])
					if contact != null:
						offsets.append(a.distance_to(contact) / a.distance_to(b))
			offsets.sort()
			for j in range(offsets.size() - 1):
				var from := a.lerp(b, offsets[j])
				var to := a.lerp(b, offsets[j + 1])
				if from.distance_squared_to(to) < .0025:
					continue
				var center := (from + to) * .5
				if ground and Geometry2D.is_point_in_polygon(center, _entry):
					continue
				if not _curtain_wall.is_empty() and Geometry2D.is_point_in_polygon(center, _curtain_wall):
					# The exterior model supplies the glass. Guard the edge of
					# the walkable slab on every floor, including above the doors.
					_span(from, to, height * .5, .16, height, null, true)
					continue
				var bottom := 2.18 if ground and not _fixed_glass.is_empty() and Geometry2D.is_point_in_polygon(center, _fixed_glass) else 0.0
				_wall(from, to, bottom, height)


func _classroom(storey: Node3D, row: Array, height: float, building: String) -> void:
	var rect := Rect2(row[1], row[2], row[3] - row[1], row[4] - row[2])
	var outline := North._rect(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	var edge := int(SIDES[row[5]])
	var opening := minf(1.74, minf(rect.size.x, rect.size.y) * .56)
	var kind := str(row[6]) if row.size() > 6 else "classroom"
	var style := RoomDetails.profile(building, row[0], kind)
	var panel := "classroom_lite" if style in ["one","two","north","south"] else "classroom"
	var door := Door.new()
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		if i != edge:
			_wall(a, b, 0, height)
			continue
		var along := (b - a).normalized()
		var center := a.lerp(b, .5)
		var left := center - along * opening * .5
		var right := center + along * opening * .5
		_wall(a, left, 0, height)
		_wall(right, b, 0, height)
		_wall(left, right, DOOR_HEIGHT, height)
		door.name = "ClassroomDoor"
		var x := Vector3(along.x, 0, along.y)
		door.transform = Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), Vector3(center.x, 0, center.y))
		storey.add_child(door)
		door.build({"id": row[0], "height": DOOR_HEIGHT, "panel": panel, "motion": "hinged"},
			opening, Fit.door_palette(panel))
		doors.append(door)
		RoomDetails.decorate_door(self,door,row[0],style in ["north","south"],(a.distance_to(b)-opening)*.5)
	if style.is_empty() or not RoomDetails.new().furnish(self,storey,door,rect,height,style):
		_furnish(rect, edge, kind)
		_light(storey, rect.get_center(), height - .22, clampf(rect.size.length() * .62, 7, 9))


func _furnish(rect: Rect2, entrance: int, kind: String) -> void:
	var center := rect.get_center()
	if kind in ["staff", "office"]:
		_box(Vector3(center.x, .42, center.y), Vector3(1.55, .84, .74), _materials.desk, 0, true)
		return
	var direction := -1.0 if entrance == 2 else 1.0
	var front_z := center.y + direction * (rect.size.y * .5 - .16)
	_box(Vector3(center.x, 1.63, front_z), Vector3(minf(rect.size.x * .55, 4.4), 1.20, .068), _materials.board)
	var columns := clampi(floori((rect.size.x - 2.1) / 1.97), 1, 5)
	var rows := clampi(floori((rect.size.y - 2.8) / 1.45), 1, 5)
	for row in rows:
		for column in columns:
			var x := center.x + (column - (columns - 1) * .5) * 1.93
			var z := center.y + direction * ((row - (rows - 1) * .5) * 1.36 - .28)
			_box(Vector3(x, .747, z), Vector3(1.13, .064, .49), _materials.desk, 0, true)
			for side in [-1, 1]:
				_box(Vector3(x + side * .47, .355, z), Vector3(.052, .71, .365), _materials.rail)
			var seat_z := z - .53 * direction
			_box(Vector3(x, .45, seat_z), Vector3(.50, .082, .38), _materials.seat)
			_box(Vector3(x, .59, seat_z - direction * .155), Vector3(.49, .43, .065), _materials.seat)
			for side in [-1.0, 1.0]:
				_box(Vector3(x + side * .20, .21, seat_z),
					Vector3(.041, .42, .32), _materials.rail)
			if kind == "language":
				_box(Vector3(x, .91, z + direction * .15), Vector3(.46, .24, .045), _materials.rail)


func _stairwell(storey: Node3D, rise: float, has_upper: bool, index: int, building: String) -> void:
	var half := STAIR_WIDTH * .5
	var start := STAIR_DEPTH * .5
	var turn := -start + STAIR_LANDING
	for side in [-1.0, 1.0]:
		var a := _stairs * Vector3(side * half, 0, -start)
		var b := _stairs * Vector3(side * half, 0, start)
		_rail(Vector2(a.x,a.z), Vector2(b.x,b.z), 0)
	var back_a := _stairs * Vector3(-half, 0, -start)
	var back_b := _stairs * Vector3(half, 0, -start)
	_rail(Vector2(back_a.x,back_a.z), Vector2(back_b.x,back_b.z), 0)
	if not has_upper and index > 0:
		var guard_a := _stairs * Vector3(-half, 0, start)
		var guard_b := _stairs * Vector3(0, 0, start)
		_rail(Vector2(guard_a.x,guard_a.z), Vector2(guard_b.x,guard_b.z), 0)
	if has_upper:
		_stair_flight(-half * .5, start, turn, 0, rise * .5)
		_stair_box(Vector3(0, rise * .5 - .085, (turn - start) * .5),
			Vector3(STAIR_WIDTH, .17, STAIR_LANDING + .035), _materials.step, true)
		_stair_flight(half * .5, turn, start, rise * .5, rise)
	var entrance := _stairs * Vector3(0, 0, start + 1.25)
	_light(storey, Vector2(entrance.x,entrance.z), rise - .39, 11)
	var sign := Node3D.new()
	sign.transform = _stairs
	storey.add_child(sign)
	Fit.lettering(sign, "%s  %dF" % [building, index + 1], Vector3(0, 2.49, start + .16),
		.009, Color("543c30")).rotation.y = 0


func _stair_flight(x: float, from_z: float, to_z: float, low: float, high: float) -> void:
	var count := ceili((high - low) / .19)
	var tread := (to_z - from_z) / float(count)
	var width := STAIR_WIDTH * .5
	for i in count:
		var y := lerpf(low, high, float(i + 1) / count)
		var z := from_z + (i + .5) * tread
		_stair_box(Vector3(x, y - .105, z), Vector3(width, .21, absf(tread) + .025), _materials.step, true)
		_stair_box(Vector3(x, y + .003, z - tread * .44), Vector3(width - .11, .009, .037), _materials.nosing)
		if i % 3 == 1:
			for side in [-1.0, 1.0]:
				_stair_box(Vector3(x + side * (width * .5 - .05), y + .48, z),
					Vector3(.045, .96, .045), _materials.rail)
	var pitch := -atan2(high - low, to_z - from_z)
	var length := Vector2(to_z - from_z, high - low).length()
	var slope := Basis(Vector3.RIGHT, pitch)
	var midpoint := Vector3(x, (low + high) * .5, (from_z + to_z) * .5)
	for side in [-1.0, 1.0]:
		var rail := midpoint + Vector3(side * (width * .5 - .05), 1.05, 0)
		_placed_box(_stairs * Transform3D(slope, rail), Vector3(.063, .066, length), _materials.rail, false)
		_placed_box(_stairs * Transform3D(slope, rail - Vector3.UP * .51),
			Vector3(.055, .87, length), null, true)
	_placed_box(_stairs * Transform3D(slope, midpoint - Vector3.UP * .16),
		Vector3(width, .20, length), _materials.step, false)


func _stair_box(pos: Vector3, size: Vector3, material: Material, collision: bool = false) -> void:
	var forward := _stairs.basis.z
	_box(_stairs * pos, size, material, atan2(forward.x, forward.z), collision)


func _wall(a: Vector2, b: Vector2, bottom: float, top: float) -> void:
	if a.distance_squared_to(b) < .0025:
		return
	_span(a, b, (bottom + top) * .5, .16, top - bottom, _materials.wall, true)
	if bottom < .03:
		_span(a, b, .064, .174, .128, _materials.plinth)


func _rail(a: Vector2, b: Vector2, y: float) -> void:
	if a.distance_squared_to(b) < .01:
		return
	_span(a, b, y + 1.04, .072, .07, _materials.rail)
	_span(a, b, y + .53, .07, 1.10, null, true)
	var count := maxi(1, ceili(a.distance_to(b) / 1.10))
	for i in range(count + 1):
		var p := a.lerp(b, float(i) / count)
		_box(Vector3(p.x, y + .51, p.y), Vector3(.052, 1.03, .052), _materials.rail)


func _span(a: Vector2, b: Vector2, y: float, width: float, height: float, material: Material,
		collision: bool = false) -> void:
	var midpoint := (a + b) * .5
	var axis := b - a
	_box(Vector3(midpoint.x, y, midpoint.y), Vector3(width, height, axis.length() + .045),
		material, atan2(axis.x, axis.y), collision)


func _light(parent: Node3D, point: Vector2, height: float, reach: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(point.x, height, point.y)
	lamp.omni_range = reach
	lamp.omni_attenuation = 1.45
	lamp.light_energy = 1.12
	lamp.light_color = Color("fff1dc")
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 15
	lamp.distance_fade_length = 8
	parent.add_child(lamp)
	_box(lamp.position + Vector3.UP * .12, Vector3(1.22,.065,.32), _materials.lamp)


func _box(pos: Vector3, size: Vector3, material: Material, yaw: float = 0.0, collision: bool = false) -> void:
	_placed_box(Transform3D(Basis(Vector3.UP, yaw), pos), size, material, collision)


func _placed_box(pose: Transform3D, size: Vector3, material: Material, collision: bool) -> void:
	if material:
		if not _batches.has(material):
			_batches[material] = []
		_batches[material].append(pose * Transform3D(Basis.from_scale(size), Vector3.ZERO))
	if collision:
		var shape := BoxShape3D.new()
		shape.size = size
		var bound := CollisionShape3D.new()
		bound.transform = pose
		bound.shape = shape
		_solid.add_child(bound)


func _flush_boxes(parent: Node3D) -> void:
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	for material: Material in _batches:
		add_interior_instances(parent,unit,_batches[material],material)


func add_interior_instances(parent: Node3D, mesh: Mesh, transforms: Array, material: Material = null) -> void:
	var instances := MultiMesh.new()
	instances.mesh = mesh
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.instance_count = transforms.size()
	for i in transforms.size():
		instances.set_instance_transform(i, transforms[i])
	var drawable := MultiMeshInstance3D.new()
	drawable.multimesh = instances
	drawable.material_override = material
	parent.add_child(drawable)
