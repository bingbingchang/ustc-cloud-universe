extends RefCounted
## Photo-based fitting groups use the existing room shell and door apertures.

const Fit = preload("res://scripts/campus_visit_interior.gd")
const Finish = preload("res://shaders/teaching_fitting_finish.gdshader")
const BENCH_PITCH := .614
const HALF_AISLE := .67
const SIDE_AISLE := .83

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _curtain_meshes: Dictionary = {}
static var _clock: CylinderMesh

var _host: Node3D
var _room: Node3D
var _origin: Transform3D
var _size: Vector2
var _top: float
var _style: String
var _props: Dictionary = {}


static func profile(building: String, label: String, kind: String) -> String:
	var number := label.get_slice(" ", 0)
	if kind == "language":
		return "language"
	if label == "2721":
		return "recording"
	if label == "2207":
		return "two"
	if not number.is_valid_int() or kind != "classroom":
		return ""
	if building == "teaching-five":
		return "north" if int(number) % 10 >= 5 else "south"
	if building == "teaching-one" and int(number) % 100 <= 2:
		return "one"
	return ""


static func decorate_door(host: Node3D, door: Node3D, number: String,
		digital: bool, wall_space: float) -> void:
	_prepare_library()
	var width: float = door.width
	for side in [-1.0, 1.0]:
		host._placed_box(door.transform.translated_local(Vector3(side*(width*.5+.031),1.109,-.093)),
			Vector3(.065,2.215,.046), _materials.jamb, false)
	host._placed_box(door.transform.translated_local(Vector3(0,2.224,-.093)),
		Vector3(width+.127,.079,.048), _materials.jamb, false)
	if digital and wall_space > .48:
		var x := width * .5 + minf(wall_space*.48,.44)
		host._placed_box(door.transform.translated_local(Vector3(x,1.52,-.106)),
			Vector3(.385,.253,.048), _materials.device, false)
		host._placed_box(door.transform.translated_local(Vector3(x,1.535,-.134)),
			Vector3(.340,.191,.008), _materials.sign, false)
		Fit.lettering(door, number, Vector3(x,1.547,-.143), .0035, Color("f2f9ff"))
		host._placed_box(door.transform.translated_local(Vector3(x,1.461,-.140)),
			Vector3(.24,.009,.006), _materials.sign_line, false)
	else:
		var plate_width := clampf(number.length() * .150 + .10,.33,width-.04)
		host._placed_box(door.transform.translated_local(Vector3(0,2.45,-.093)),
			Vector3(plate_width,.169,.028), _materials.plaque, false)
		Fit.lettering(door, number, Vector3(0,2.450,-.112), .0053, Color("f1f2ee"))


func furnish(host: Node3D, storey: Node3D, door: Node3D, rect: Rect2, height: float,
		style: String) -> bool:
	_prepare_library()
	if _meshes.is_empty():
		return false
	_host = host
	_style = style
	var frame: Basis = door.basis
	# In 2207 the curtained long side is left of the lectern, across from the door.
	if style == "two":
		frame = Basis(Vector3.UP,-PI*.5)
	var middle := rect.get_center()
	_origin = Transform3D(frame, Vector3(middle.x,0,middle.y))
	_size = Vector2(absf(frame.x.x)*rect.size.x + absf(frame.x.z)*rect.size.y,
		absf(frame.z.x)*rect.size.x + absf(frame.z.z)*rect.size.y)
	_top = height - .21
	if style == "one":
		_top = minf(_top,3.15)
	elif style in ["two","recording","language"]:
		_top = minf(_top,2.86)
	_room = Node3D.new()
	_room.name = "Fittings_" + str(door.door_id).get_slice(" ",0)
	_room.transform = _origin
	storey.add_child(_room)
	_box(Vector3(0,0,0), Vector3(_size.x-.095,.012,_size.y-.095),
		_materials.terrazzo if style in ["one","south"] else _materials.vinyl)
	_front()
	_ceiling()
	_curtains()
	_seating()
	for mesh: Mesh in _props:
		_host.add_interior_instances(_room,mesh,_props[mesh])
	return true


static func _prepare_library() -> void:
	if not _materials.is_empty():
		return
	_materials = {
		"jamb": Fit.material(Color("877661"),.52), "plaque": Fit.material(Color("3f5c66"),.48),
		"device": Fit.material(Color("242932"),.38), "sign": _emissive(Color("226593"),.33),
		"sign_line": _emissive(Color("86bdd8"),.30), "screen": Fit.material(Color("d8ddda"),.67),
		"board": Fit.material(Color("25483c"),.73), "metal": Fit.material(Color("aaaca1"),.31,.45),
		"dark": Fit.material(Color("28292b"),.82), "beam": Fit.material(Color("d9d5c9"),.74),
		"slat": Fit.material(Color("4d4b46"),.79,.03),
		"trim": Fit.material(Color("b9b1a0"),.62), "lamp": _emissive(Color("fff3df"),.42),
		"terrazzo": _finish(2,Color("b8b5ad"),.67), "vinyl": _finish(2,Color("67727a"),.60),
		"stage": Fit.tiles(Color("a68156"),Vector2(1.12,.20)),
		"drop_tiles": Fit.tiles(Color("d0d0c6"),Vector2(.61,.61)),
		"oak": Fit.material(Color("9e784f"),.52), "white": Fit.material(Color("e7e2d3"),.52),
		"beige_cloth": Fit.material(Color("90857c"),.94), "gray_cloth": Fit.material(Color("aaa7a2"),.94),
		"blue_cloth": Fit.material(Color("3c5570"),.90), "acoustic": Fit.tiles(Color("b3997a"),Vector2(.55,2.25)),
	}
	_materials.stage.set_shader_parameter("staggered_rows",true)
	_materials.stage.set_shader_parameter("joint_strength",.10)
	_materials.drop_tiles.set_shader_parameter("joint_strength",.14)
	_materials.acoustic.set_shader_parameter("joint_strength",.11)
	for cloth in [_materials.beige_cloth,_materials.gray_cloth,_materials.blue_cloth]:
		cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	_clock = CylinderMesh.new()
	_clock.top_radius = .143
	_clock.bottom_radius = .143
	_clock.height = .025
	_clock.radial_segments = 24
	_clock.rings = 0
	_clock.material = _materials.white

	var asset := load("res://assets/teaching_fittings.glb") as PackedScene
	if not asset:
		return
	var library := asset.instantiate()
	var replacement: Dictionary = {}
	for child in library.get_children():
		if not child is MeshInstance3D:
			continue
		var mesh: Mesh = child.mesh
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i) as StandardMaterial3D
			if not material:
				continue
			var key := str(material.resource_name)
			if not replacement.has(key):
				if key in ["PaleAsh","DarkWalnut","OakVeneer","WarmLaminate"]:
					replacement[key] = _finish(0,material.albedo_color,material.roughness)
				elif key == "PerforatedSteel":
					replacement[key] = _finish(1,material.albedo_color,material.roughness)
			if replacement.has(key):
				mesh.surface_set_material(i,replacement[key])
		_meshes[str(child.name)] = mesh
	library.free()


static func _folded_curtain(cloth: Material) -> Mesh:
	if _curtain_meshes.has(cloth):
		return _curtain_meshes[cloth]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(73):
		var z := float(i)/72.0 - .5
		var phase := z*TAU*10.0
		points.append(Vector3(-.037-.021*cos(phase),0,z))
		normals.append(Vector3(-1,0,.021*TAU*10.0*sin(phase)).normalized())
	for i in range(72):
		for corner: Vector2i in [Vector2i(i,0),Vector2i(i,1),Vector2i(i+1,1),
				Vector2i(i,0),Vector2i(i+1,1),Vector2i(i+1,0)]:
			var at := points[corner.x]
			at.y = .5 if corner.y == 1 else -.5+.004*cos(at.z*TAU*10.0)
			surface.set_normal(normals[corner.x])
			surface.add_vertex(at)
	var mesh := surface.commit()
	mesh.surface_set_material(0,cloth)
	_curtain_meshes[cloth] = mesh
	return mesh


static func _finish(pattern: int, color: Color, roughness: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Finish
	material.set_shader_parameter("finish",pattern)
	material.set_shader_parameter("tint",color)
	material.set_shader_parameter("roughness",roughness)
	material.set_shader_parameter("wood_grain",preload("res://assets/textures/wood_albedo.png"))
	return material


static func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := Fit.material(color,.44)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _front() -> void:
	var z := _size.y*.5-.135
	var stage_height := .135 if _style in ["north","south"] else 0.0
	if stage_height > 0:
		_box(Vector3(0,stage_height*.5,z-.78),Vector3(_size.x-.28,stage_height,1.60),_materials.stage,0.0,true)
		_box(Vector3(0,stage_height+.003,z-1.575),Vector3(_size.x-.29,.012,.032),_materials.metal)
	var split_panel := minf(_size.x*.42,4.28)
	var space := .12
	var board := split_panel*.5+space*.5
	_box(Vector3(board,1.732+stage_height,z),Vector3(split_panel,1.43,.076),_materials.metal)
	for y in [1.393,2.065]:
		_box(Vector3(board,y+stage_height,z-.050),Vector3(split_panel-.074,.648,.034),_materials.board)
	_box(Vector3(board,1.014+stage_height,z-.090),Vector3(split_panel,.034,.108),_materials.metal)
	_box(Vector3(-board,1.78+stage_height,z-.10),Vector3(split_panel,1.51,.045),_materials.device)
	_box(Vector3(-board,1.78+stage_height,z-.129),Vector3(split_panel-.069,1.42,.014),_materials.screen)
	_box(Vector3(-board,2.552+stage_height,z-.112),Vector3(split_panel+.073,.066,.065),_materials.device)
	var lectern := Vector3(_size.x*.30,stage_height,z-1.13)
	var facing: Material = _materials.white if stage_height>0 else _materials.trim
	_box(lectern+Vector3(0,.453,0),Vector3(.63,.906,.48),facing,0.0,true)
	_box(lectern+Vector3(0,.95,0),Vector3(1.05,.115,.62),_materials.white if _style in ["north","south"] else _materials.oak)
	_box(lectern+Vector3(0,.899,-.322),Vector3(.58,.128,.034),_materials.oak)
	_box(lectern+Vector3(-.31,1.019,-.072),Vector3(.23,.033,.158),_materials.device)
	_box(lectern+Vector3(-.31,1.039,-.072),Vector3(.186,.009,.116),_materials.sign)
	for side in [-1.0,1.0]:
		_box(Vector3(side*(_size.x*.5-.35),2.30+stage_height,z-.055),
			Vector3(.226,.278,.186),_materials.white)
		_box(Vector3(side*(_size.x*.5-.35),2.28+stage_height,z-.153),
			Vector3(.171,.178,.013),_materials.dark)
	var clock := Vector3(board*.15, minf(_top-.20,2.71+stage_height), z-.05)
	_instance(_clock,Transform3D(Basis(Vector3.RIGHT,PI*.5),clock))
	_box(clock+Vector3(0,.030,-.017),Vector3(.013,.073,.006),_materials.dark)
	_box(clock+Vector3(-.031,-.019,-.017),Vector3(.071,.010,.006),_materials.dark)


func _ceiling() -> void:
	var slatted := _style == "south"
	var tiled := _style in ["one","two","recording","language"]
	_box(Vector3(0,_top+.035,0),Vector3(_size.x-.085,.07,_size.y-.085),
		_materials.drop_tiles if tiled else _materials.beam, 0.0, true)
	if slatted:
		var span := _size.x*.245
		for x in [-_size.x*.33,0.0,_size.x*.33]:
			_box(Vector3(x,_top-.019,0),Vector3(span,.044,_size.y-.50),_materials.dark)
			var slats := ceili(span/.145)
			for i in slats:
				_ceiling_slat(x+((i+.5)/slats-.5)*span)
	else:
		for z in [-_size.y*.30,0.0,_size.y*.30]:
			if _style != "one":
				_box(Vector3(0,_top-.082,z),Vector3(_size.x-.10,.19,.17),_materials.beam)

	var rows := clampi(ceili(_size.y/2.95),2,4)
	var lanes := 3 if slatted else 2
	for row in rows:
		var z := lerpf(-_size.y*.38,_size.y*.37,float(row)/float(rows-1))
		for lane in lanes:
			var room_x := lerpf(-_size.x*.33,_size.x*.33,float(lane)/float(lanes-1))
			var lamp_size := Vector3(.14,.044,1.57) if slatted else Vector3(.54,.041,1.12)
			var lamp_y := _top-(.159 if slatted else .055)
			_box(Vector3(room_x,lamp_y,z),lamp_size+Vector3(.051,.013,.065),_materials.metal)
			_box(Vector3(room_x,lamp_y-.027,z),lamp_size,_materials.lamp)
			if _style=="one":
				for offset in [-.35,-.176,0.0,.176,.35]:
					_box(Vector3(room_x,_top-.106,z+offset),Vector3(.54,.014,.020),_materials.metal)
	_light(Vector3(-_size.x*.20,_top-.66,-_size.y*.22),7.8,.93)
	_light(Vector3(_size.x*.18,_top-.66,_size.y*.20),7.5,.95)
	_prop("Projector",Vector3(0,_top-.05,_size.y*.11))
	if _style == "one":
		for x in [-_size.x*.29,_size.x*.29]:
			_prop("CeilingFan",Vector3(x,_top-.04,-_size.y*.07))
	elif _style in ["south","north","recording"]:
		_prop("Camera",Vector3(0,_top-.11,-_size.y*.5+.28))


func _ceiling_slat(x: float) -> void:
	var length := _size.y-.59
	for i in range(4):
		var t0 := float(i)/4
		var t1 := float(i+1)/4
		var start := Vector3(x,_top-.080-.077*sin(t0*PI),(t0-.5)*length)
		var end := Vector3(x,_top-.080-.077*sin(t1*PI),(t1-.5)*length)
		var span := end-start
		var slat := Transform3D(Basis(Vector3.RIGHT,-atan2(span.y,span.z)),(start+end)*.5)
		_host._placed_box(_origin*slat,Vector3(.024,.094,span.length()+.028),_materials.slat,false)


func _curtains() -> void:
	# In 2207, the window and curtain wall is on the left when facing the screen.
	var hem := .77
	var top := _top-.24
	var cloth: Material = _materials.gray_cloth
	if _style in ["south","north"]:
		cloth = _materials.beige_cloth if _style=="south" else _materials.blue_cloth
	for face: float in [1.0,-1.0]:
		if face < 0 and _style not in ["south","north"]:
			break
		var x := face*(_size.x*.5-.105)
		var length := _size.y-1.98
		var panels := maxi(2,roundi(length/1.85))
		var bay := length/panels
		for i in panels:
			var center := -.5*length + bay*(i+.5)
			if face < 0 and _style in ["south","north"]:
				_box(Vector3(x,.5*top,center),Vector3(.047,top,bay-.026),_materials.acoustic)
				_box(Vector3(x+.036,top*.5,center+bay*.5-.018),Vector3(.048,top,.056),_materials.oak)
				continue
			var panel := Transform3D(Basis.from_scale(Vector3(1.0,top-hem,bay-.068)),
				Vector3(x,(top+hem)*.5,center))
			_instance(_folded_curtain(cloth),panel)
			if _style == "south" and i%2==0:
				_box(Vector3(x-.033,_top*.48,center+bay*.5-.021),
					Vector3(.106,_top*.96,.154),_materials.oak)
		_box(Vector3(x,top+.018,0),Vector3(.075,.046,length+.063),_materials.trim)


func _seating() -> void:
	var tiered := _style == "south"
	var back := -_size.y*.5 + (2.31 if tiered else 1.58)
	var forward := _size.y*.5 - (2.36 if _style in ["south","north"] else 1.98)
	var available := maxf(.0,forward-back)
	var row_count := clampi(floori(available/1.005)+1,1,9)
	if row_count == 1:
		back = minf(back,forward)
	var pitch := available/maxi(1,row_count-1)
	var room_width := _size.x-.17
	var rear_riser := minf(.69,(row_count-1)*.137) if tiered else 0.0
	if rear_riser > 0.0:
		var takeoff := back-pitch*.5
		var steps := ceili(rear_riser/.166)
		for i in steps:
			var step_height := rear_riser*float(i+1)/float(steps)
			_box(Vector3(0,step_height*.5,takeoff-(steps-i-.5)*.26),
				Vector3(1.36,step_height,.265),_materials.terrazzo,0.0,true)
	var bank_width := _size.x*.5-SIDE_AISLE-HALF_AISLE
	for row in row_count:
		var z := back+row*pitch
		var elevation := minf(.69,(row_count-1-row)*.137) if tiered else 0.0
		if elevation > 0.0:
			_box(Vector3(0,elevation*.5,z),Vector3(room_width,elevation,pitch+.008),_materials.terrazzo,0.0,true)
			_box(Vector3(0,elevation+.003,z+pitch*.5-.027),
				Vector3(1.36,.008,.043),_materials.metal)
		if _style == "north":
			_small_class_row(bank_width,z)
		else:
			_fixed_row(bank_width,z,elevation)


func _fixed_row(bank_width: float, z: float, elevation: float) -> void:
	var seats := clampi(floori(bank_width/BENCH_PITCH),1,8)
	var bench: String = {"one":"OneBench","south":"FiveBench"}.get(_style,"TwoBench")
	for side: float in [-1.0,1.0]:
		var center := side*(HALF_AISLE+seats*BENCH_PITCH*.5)
		_box(Vector3(center,elevation+.745,z+.231),Vector3(seats*BENCH_PITCH-.035,.13,.419),null,0,true)
		for seat in seats:
			var x := side*(HALF_AISLE+(seat+.5)*BENCH_PITCH)
			_prop(bench,Vector3(x,elevation,z))
			if _style=="language":
				_box(Vector3(x,.929,z+.312),Vector3(.346,.246,.055),_materials.device)
				_box(Vector3(x,.941,z+.279),Vector3(.302,.181,.013),_materials.sign)
				_box(Vector3(x,.785,z+.130),Vector3(.281,.021,.074),_materials.device)


func _small_class_row(bank_width: float, z: float) -> void:
	const DESK_PITCH := 1.53
	var groups := clampi(floori(bank_width/DESK_PITCH),1,4)
	for side: float in [-1.0,1.0]:
		for group in groups:
			var x := side*(HALF_AISLE+(group+.5)*DESK_PITCH)
			_prop("NorthDesk",Vector3(x,0,z+.225))
			_box(Vector3(x,.746,z+.225),Vector3(1.445,.12,.462),null,0,true)
			for seat in [-1.0,1.0]:
				_prop("NorthChair",Vector3(x+seat*.348,0,z-.289),seat*.047)


func _box(center: Vector3, size: Vector3, material: Material, yaw := 0.0, collision := false) -> void:
	_host._placed_box(_origin*Transform3D(Basis(Vector3.UP,yaw),center),size,material,collision)


func _prop(name: String, center: Vector3, yaw := 0.0) -> void:
	if _meshes.has(name):
		_instance(_meshes[name],Transform3D(Basis(Vector3.UP,yaw),center))


func _instance(mesh: Mesh, pose: Transform3D) -> void:
	if not _props.has(mesh):
		_props[mesh] = []
	_props[mesh].append(pose)


func _light(center: Vector3, radius: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = center
	light.omni_range = radius
	light.omni_attenuation = 1.23
	light.light_energy = energy
	light.light_specular = .23
	light.light_color = Color("fff4e5")
	light.distance_fade_enabled = true
	light.distance_fade_begin = 14
	light.distance_fade_length = 8
	_room.add_child(light)
