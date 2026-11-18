extends RefCounted
## Fittings use vestibule photographs and public floor information. Distances
## follow the facade's metric axes and are estimates where no survey exists.

const Tiles = preload("res://shaders/teaching5_tile.gdshader")
const CampusFont = preload("res://scripts/campus_font.gd")
static var _palettes: Dictionary = {}


static func material(tint: Color, roughness: float=.82, metallic: float=0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = roughness
	mat.metallic = metallic
	if tint.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func tiles(tint: Color, size: Vector2) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Tiles
	mat.set_shader_parameter("wall_color",tint)
	mat.set_shader_parameter("tile_size",size)
	mat.set_shader_parameter("tile_variation",.09)
	return mat


static func clear_glass(tint: Color) -> StandardMaterial3D:
	tint.a = .19
	return material(tint, .18)


static func door_palette(panel: String) -> Dictionary:
	if not _palettes.has(panel):
		var classroom := panel.begins_with("classroom")
		var wood := panel == "wood" or classroom
		var frame := Color("514d47") if panel == "charcoal" else Color("aaa99e")
		if wood:
			frame = Color("7e6a53") if classroom else Color("57242b")
		var wood_tint := Color("b0885c") if classroom else Color("792c3a")
		_palettes[panel]={
			"pane":material(wood_tint, .64) if wood else clear_glass(Color(.54, .67, .66)),
			"frame":material(frame,.42,.40 if not wood else 0),
			"stripe":material(Color("367cb6")),
			"inset":material(Color("6c2931")),
			"handle":material(Color("9ca6a6") if panel == "silver" or classroom else Color("813d36"),.29,.46)
		}
		if panel == "classroom_lite":
			_palettes[panel]["vision"] = clear_glass(Color("90aaa4"))
	return _palettes[panel]


static func mesh_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size=size
	var piece := MeshInstance3D.new()
	piece.mesh=mesh
	piece.material_override=mat
	piece.position=pos
	if mat is StandardMaterial3D and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(piece)


static func collider(parent: Node3D, label: String, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name=label
	body.position=pos
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	body.add_child(collision)


static func lettering(parent: Node3D, caption: String, position: Vector3, size: float, tint: Color) -> Label3D:
	var sign := Label3D.new()
	sign.position=position
	sign.rotation.y=PI
	sign.font=CampusFont.get_font()
	sign.font_size=32
	sign.pixel_size=size
	sign.text=caption
	sign.modulate=tint
	sign.outline_size=0
	parent.add_child(sign)
	return sign


static func build(parent: Node3D, info: Dictionary) -> void:
	var width := float(info.width)
	var depth := float(info.depth)
	var height := float(info.height)
	var pale := material(Color("d0cbbd"))
	var base := material(Color("625b55"))
	var floor_style := tiles(Color("a5a09a"),Vector2(.60,.60))
	var ceiling := material(Color("dfded4"))
	match info.style:
		"museum":
			pale=material(Color("dfd2b6"))
			base=material(Color("71423b"))
			floor_style=tiles(Color("ada394"),Vector2(.65,.65))
		"auditorium":
			pale=material(Color("dacdb7"))
			base=material(Color("704739"))
			floor_style=tiles(Color("a39283"),Vector2(.65,.65))
		"activity":
			pale=material(Color("cbc3b7"))
			base=material(Color("6d4945"))
			floor_style=tiles(Color("8e8980"),Vector2(.60,.60))
	var soffit_center := depth*.50
	mesh_box(parent,Vector3(0,-.04,soffit_center),Vector3(width,.09,depth),floor_style)
	mesh_box(parent,Vector3(0,height+.027,soffit_center),Vector3(width,.08,depth),ceiling)
	mesh_box(parent,Vector3(0,height*.50,depth+.014),Vector3(width,height,.098),pale)
	mesh_box(parent,Vector3(0,.09,depth-.045),Vector3(width,.18,.026),base)
	for side: int in [-1,1]:
		var x := width*.50*side
		mesh_box(parent,Vector3(x,height*.50,soffit_center),Vector3(.09,height,depth),pale)
		mesh_box(parent,Vector3(x-side*.06,.09,soffit_center),Vector3(.022,.18,depth),base)
	var diffuser := material(Color("efe4ce"))
	diffuser.emission_enabled=true
	diffuser.emission=Color("efe5d2")
	diffuser.emission_energy_multiplier=.55
	for z in [depth*.29,depth*.72]:
		var light := OmniLight3D.new()
		light.position=Vector3(0,height-.24,z)
		light.omni_range=maxf(width*.68,6.2)
		light.light_color=Color("fff7e7")
		light.light_energy=.75
		parent.add_child(light)
		for x in [-width*.26,0,width*.26]:
			mesh_box(parent,Vector3(x,height-.027,z),Vector3(.66,.058,.27),diffuser)
	match info.style:
		"teaching":
			_teaching(parent,width,depth,height,pale,base)
		"library":
			_library(parent,width,depth,pale)
		"museum":
			_museum(parent,width,depth,pale)
		"auditorium":
			_auditorium(parent,width,depth,height,pale,base)
		"activity":
			_activity(parent,width,depth,pale,base)
		"teaching-two":
			_teaching_two(parent,width,depth)
		"teaching-one":
			_teaching_one(parent,width,depth)
		"computing":
			_computing(parent,width,depth)


static func _computing(parent: Node3D, width: float, depth: float) -> void:
	var pale := material(Color("c8c5be"))
	var grain := material(Color("535956"),.45,.31)
	var aisle := Vector3(width*.21,1.15,depth-.053)
	mesh_box(parent,aisle,Vector3(2.41,2.30,.05),grain)
	for side in [-1,1]:
		mesh_box(parent,aisle+Vector3(side*1.28,0,-.032),Vector3(.16,2.31,.13),pale)


static func _teaching_one(parent: Node3D, width: float, depth: float) -> void:
	var wood := material(Color("62554a"))
	var surround := material(Color("988b76"))
	for side in [-1,1]:
		var panel := Vector3(width*.26*side,1.27,depth-.059)
		mesh_box(parent,panel,Vector3(1.55,2.54,.052),wood)
		mesh_box(parent,panel+Vector3(0,1.265,-.045),Vector3(1.68,.095,.055),surround)


static func _teaching_two(parent: Node3D, width: float, depth: float) -> void:
	var screen := material(Color("171e3b"))
	var glow := material(Color("395e9a"))
	glow.emission_enabled=true
	glow.emission=Color("326bad")
	glow.emission_energy_multiplier=.58
	var x := width*.24
	mesh_box(parent,Vector3(x,2.04,depth-.075),Vector3(1.65,.82,.09),screen)
	for row in range(4):
		for column in range(2):
			mesh_box(parent,Vector3(x-.4+.8*column,1.77+.16*row,depth-.129),
				Vector3(.62,.046,.01),glow)


static func _auditorium(parent: Node3D, width: float, depth: float, height: float, pale: Material, base: Material) -> void:
	var inner_portal := material(Color("583834"))
	for x in [-width*.31, -width*.14, width*.14, width*.32]:
		var offset := Vector3(x,1.26,depth-.056)
		mesh_box(parent,offset,Vector3(2.07,2.52,.057),inner_portal)
		mesh_box(parent,offset+Vector3(0,1.30,0),Vector3(2.15,.075,.11),base)
		mesh_box(parent,offset,Vector3(.08,2.51,.088),base)
	for x in [-width*.29, width*.29]:
		var center := Vector3(x,height*.5,depth-.27)
		mesh_box(parent,center,Vector3(.28,height,.31),pale)


static func _activity(parent: Node3D, width: float, depth: float, pale: Material, base: Material) -> void:
	var counter := Vector3(width*.30,.53,depth*.68)
	mesh_box(parent,counter,Vector3(1.83,1.06,.64),pale)
	mesh_box(parent,counter+Vector3(0,.54,0),Vector3(1.93,.075,.72),base)
	collider(parent,"ActivityEntryCounter",counter,Vector3(1.83,1.06,.64))


static func _teaching(parent: Node3D, width: float, depth: float, height: float, pale: Material, base: Material) -> void:
	var recess := material(Color("555954"))
	var display := material(Color("141f47"))
	var board := material(Color("373779"))
	board.emission_enabled=true
	board.emission=Color("343dbd")
	board.emission_energy_multiplier=.5
	# The west entrance photograph shows the security desk and information
	# screen on the right, with the open passage offset on the other side.
	var right := -width*.23
	var stand := Vector3(right,.53,depth*.66)
	mesh_box(parent,stand,Vector3(2.15,1.06,.69),pale)
	mesh_box(parent,stand+Vector3(0,.55,0),Vector3(2.21,.075,.74),base)
	collider(parent,"TeachingEntryDesk",stand,Vector3(2.15,1.1,.70))
	mesh_box(parent,Vector3(right,2.58,depth-.105),Vector3(2.63,1.21,.11),display)
	for row in range(6):
		mesh_box(parent,Vector3(right,2.12+row*.153,depth-.168),Vector3(2.42,.031,.012),board)
	var back := Vector3(width*.21,1.30,depth-.059)
	mesh_box(parent,back,Vector3(2.34,2.6,.083),recess)
	mesh_box(parent,Vector3(width*.21,height-.14,depth*.55),Vector3(width*.46,.24,depth*.71),pale)
	lettering(parent,"第五教学楼",Vector3(width*.18,3.03,depth-.103),.008,Color("4e514b"))


static func _library(parent: Node3D, width: float, depth: float, pale: Material) -> void:
	var maple := material(Color("a57954"))
	var dark := material(Color("535c54"))
	var service := Vector3(-width*.20,.56,depth*.70)
	mesh_box(parent,service,Vector3(3.65,1.12,.83),maple)
	mesh_box(parent,service+Vector3(0,.58,0),Vector3(3.79,.082,.94),pale)
	collider(parent,"LibraryServiceDesk",service,Vector3(3.73,1.12,.88))
	mesh_box(parent,Vector3(service.x+.82,1.34,service.z),Vector3(.36,.28,.21),dark)
	lettering(parent,"服务台",Vector3(service.x,1.91,depth-.086),.010,Color("4c594d"))
	for x in [width*.2,-width*.2]:
		mesh_box(parent,Vector3(x,1.65,depth-.052),Vector3(2.48,3.3,.038),dark)
		if x>0:
			lettering(parent,"英才书苑",Vector3(x,2.64,depth-.081),.008,Color("e7e0c8"))
	var strips := material(Color("b9b5a8"))
	for x in [-width*.34,width*.34]:
		mesh_box(parent,Vector3(x,4.42,depth*.50),Vector3(.15,.23,depth*.98),strips)


static func _museum(parent: Node3D, width: float, depth: float, pale: Material) -> void:
	var burgundy := material(Color("64292a"))
	var dark := material(Color("423836"))
	var glass := material(Color(.5,.55,.45,.21),.24)
	mesh_box(parent,Vector3(0,1.85,depth-.048),Vector3(width*.78,2.8,.095),burgundy)
	lettering(parent,"校史馆",Vector3(0,2.47,depth-.112),.021,Color("e2cd94"))
	for side: int in [-1,1]:
		var x := width*.33*side
		var z := depth*.65
		var case_pos := Vector3(x,.48,z)
		mesh_box(parent,case_pos,Vector3(1.31,.96,.62),dark)
		mesh_box(parent,Vector3(x,1.16,z),Vector3(1.32,.40,.62),glass)
		mesh_box(parent,Vector3(x,1.015,z),Vector3(.63,.042,.42),pale)
		collider(parent,"MuseumDisplayCase",Vector3(x,.68,z),Vector3(1.32,1.36,.62))
