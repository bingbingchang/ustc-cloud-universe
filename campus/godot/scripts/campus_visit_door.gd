extends Node3D
## Move the physical leaf with the mesh. The protected area covers the swing,
## including both sides of the threshold while someone is in the doorway.
const DURATION := .45
const LeafDepth := .055

var door_id: String
var width: float
var height: float
var sliding: bool
var open_amount := 0.0
var target_open := false
var _leaves: Array[AnimatableBody3D] = []


func build(spec: Dictionary, opening_width: float, palette: Dictionary) -> void:
	door_id = spec.id
	width = opening_width
	height = spec.height
	sliding = spec.motion == "sliding"
	var half := width * .5
	for side: int in [-1, 1]:
		var leaf := AnimatableBody3D.new()
		leaf.name = "DoorLeafWest" if side < 0 else "DoorLeafEast"
		leaf.sync_to_physics = false
		add_child(leaf)
		_leaves.append(leaf)
		var center := -side * half * .5
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(half, height - .045, .091)
		collision.shape = shape
		collision.position = Vector3(center, .021 + shape.size.y * .5, 0.0)
		leaf.add_child(collision)
		if palette.has("vision"):
			_install_vision_panel(leaf,center,half-.065,palette)
		else:
			_panel(leaf, Vector3(center, height*.5, 0), Vector3(half-.065,height-.09,LeafDepth), palette.pane)
		for x in [center-half*.5+.018, center+half*.5-.018]:
			_panel(leaf, Vector3(x, height*.5, 0), Vector3(.037,height-.04,.078), palette.frame)
		for y in [.046, height-.040]:
			_panel(leaf, Vector3(center, y, 0), Vector3(half-.015,.046,.079), palette.frame)
		if spec.panel not in ["wood", "classroom", "classroom_lite"]:
			_panel(leaf, Vector3(center,.98,-.034),Vector3(half-.091,.043,.017),palette.stripe)
		elif spec.panel == "wood":
			for y in [.57, 1.84]:
				_panel(leaf,Vector3(center,y,-.038),Vector3(half-.17,.48,.027),palette.inset)
		var handle_x := -side * (half-.17)
		for face in [-1,1]:
			_panel(leaf,Vector3(handle_x,1.07,.064*face),Vector3(.035,.44,.038),palette.handle)
	_pose()


func _install_vision_panel(leaf: Node3D, center: float, span: float, palette: Dictionary) -> void:
	var glass := minf(.128,span*.31)
	var low := .80
	var high := minf(height-.26,1.99)
	var side_width := (span-glass)*.5
	for side: float in [-1.0,1.0]:
		var x := center + side*(glass+side_width)*.5
		_panel(leaf,Vector3(x,height*.5,0),Vector3(side_width,height-.09,LeafDepth),palette.pane)
		_panel(leaf,Vector3(center+side*glass*.5,(low+high)*.5,0),Vector3(.019,high-low,.066),palette.frame)
	_panel(leaf,Vector3(center,(low+.045)*.5,0),Vector3(glass,low-.045,LeafDepth),palette.pane)
	_panel(leaf,Vector3(center,(high+height-.045)*.5,0),Vector3(glass,height-.045-high,LeafDepth),palette.pane)
	_panel(leaf,Vector3(center,(low+high)*.5,0),Vector3(glass-.018,high-low,.026),palette.vision)


func _panel(parent: Node3D, center: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var panel := MeshInstance3D.new()
	panel.mesh = mesh
	panel.material_override = material
	panel.position = center
	if material is StandardMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(panel)


func contains_player(player: CharacterBody3D) -> bool:
	var foot := to_local(player.global_position)
	if foot.y > height + .06 or foot.y < -1.75:
		return false
	var half := width * .5
	if sliding:
		return absf(foot.x) < width+.32 and absf(foot.z)<.38
	return absf(foot.x) < half+.32 and foot.z > -.38 and foot.z < half+.32


func toggle(player: CharacterBody3D) -> void:
	if is_moving() or contains_player(player):
		return
	target_open = not target_open


func is_moving() -> bool:
	return open_amount != (1.0 if target_open else 0.0)


func advance(delta: float, player: CharacterBody3D) -> void:
	if not is_moving():
		return
	if contains_player(player):
		target_open = true
		return
	open_amount = move_toward(open_amount, 1.0 if target_open else 0.0, delta / DURATION)
	_pose()


func _pose() -> void:
	var half := width*.5
	var motion := smoothstep(0.0,1.0,open_amount)
	for i in _leaves.size():
		var side := -1.0 if i == 0 else 1.0
		var leaf := _leaves[i]
		leaf.position.x = side * half * (1.0+motion if sliding else 1.0)
		if not sliding:
			leaf.rotation.y = side * deg_to_rad(93.0) * motion
