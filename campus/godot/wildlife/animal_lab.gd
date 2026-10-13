extends Node3D
const OUT := "res://../renders/wildlife/"
const Animal = preload("res://wildlife/animal.gd")
var animals: Array[Node3D] = []
var camera: Camera3D
var player: CharacterBody3D
var hud: CanvasLayer
var caption: Label
var status: Label
var inspector: bool = true
var selected: int = 0
var clip_index: int = -1
var orbit_yaw: float = -2.5
var orbit_pitch: float = .15
var orbit_distance: float = 1.3
var capture_mode: bool = false
var automatic: bool = true

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_window().title = "校园小动物 · 独立试验场"
	get_window().size = Vector2i(1600,900)
	setup_environment(); setup_habitat(); setup_animals(); setup_input(); setup_player(); setup_hud()
	camera = Camera3D.new(); camera.name = "AnimalCamera"; camera.near = .015; camera.fov = 44; camera.far = 100
	add_child(camera); camera.current = true
	select_animal(0)
	var args := OS.get_cmdline_user_args()
	capture_mode = "--wildlife-capture" in args or "--wildlife-motion" in args or "--wildlife-new-motion" in args or "--wildlife-qa" in args or "--wildlife-performance" in args
	if capture_mode:
		player.frozen = true; automatic = false
		for animal in animals: animal.manual_simulation = true
		call_deferred("run_evidence",args)
	else: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("WILDLIFE_LAB_READY animals=",animals.size()," independent=true")

func material(color: Color, rough: float = .85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = rough; return mat

func box(label: String, pos: Vector3, size: Vector3, color: Color, collision: bool = false) -> MeshInstance3D:
	var object := MeshInstance3D.new(); object.name = label
	var mesh := BoxMesh.new(); mesh.size = size; object.mesh = mesh; object.material_override = material(color)
	object.position = pos; add_child(object)
	if collision:
		var body := StaticBody3D.new(); object.add_child(body)
		var shape := CollisionShape3D.new(); var bounds := BoxShape3D.new(); bounds.size = size; shape.shape = bounds; body.add_child(shape)
	return object

func ellipsoid(label: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var object := MeshInstance3D.new(); object.name = label
	var mesh := SphereMesh.new(); mesh.radius = 1; mesh.height = 2; mesh.radial_segments = 24; mesh.rings = 12
	object.mesh = mesh; object.scale = size; object.position = pos; object.material_override = material(color); add_child(object); return object

func branch(a: Vector3, b: Vector3, radius: float) -> void:
	var object := MeshInstance3D.new(); var mesh := CylinderMesh.new()
	mesh.top_radius = radius*.7; mesh.bottom_radius = radius; mesh.height = a.distance_to(b); mesh.radial_segments = 12
	object.mesh = mesh; object.position = (a+b)*.5; object.material_override = material(Color("685847")); add_child(object)
	object.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func setup_environment() -> void:
	var world := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new(); var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("7597aa"); sky_mat.sky_horizon_color = Color("dde2d3")
	sky_mat.ground_bottom_color = Color("777769"); sky_mat.ground_horizon_color = Color("d4d5c5"); sky.sky_material = sky_mat; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("a6bac4"); env.ambient_light_energy = .58
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.ssao_enabled = true; env.ssao_intensity = 1.2
	env.ssr_enabled = true
	world.environment = env; add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-42,-32,0); sun.light_color = Color("fff1d5"); sun.light_energy = 1.8
	sun.light_energy = 1.25; sun.shadow_enabled = true; sun.directional_shadow_max_distance = 30; add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-25,140,0); fill.light_color = Color("b7cbd1"); fill.light_energy = .28; add_child(fill)

func setup_habitat() -> void:
	box("Grass",Vector3(-1,-.13,0),Vector3(20,.26,15),Color("81916a"),true)
	box("WalkingPath",Vector3(-3,.005,1.1),Vector3(6,.012,1.15),Color("c2bda5"))
	box("LakeBed",Vector3(3,-.20,-.2),Vector3(4.8,.15,5.4),Color("747f66"))
	# A raised water surface and a shallow sloping bank; animal routes use its nodes.
	var water := MeshInstance3D.new(); water.name = "Water"
	var plane := PlaneMesh.new(); plane.size = Vector2(4.8,5.0); plane.subdivide_width = 12; plane.subdivide_depth = 12; water.mesh = plane
	water.position = Vector3(3,.08,-.2)
	var mat := ShaderMaterial.new(); mat.shader = preload("res://wildlife/water.gdshader"); water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(water)
	var bank:=box("ShallowBank",Vector3(.5,.001,-.25),Vector3(.80,.02,5.3),Color("b4ac8e"),true)
	bank.rotation.z=-.10
	for i in range(14):
		var z := -2.7+i*.40
		ellipsoid("BankStone",Vector3(.52,.026,z),Vector3(.08,.045,.11),Color("989886"))
	box("BenchSeat",Vector3(-4.8,.45,-2.4),Vector3(1.5,.08,.43),Color("958065"),true)
	for x in [-5.35,-4.25]: box("BenchLeg",Vector3(x,.21,-2.4),Vector3(.07,.45,.35),Color("4b5350"),true)
	box("BenchBack",Vector3(-4.8,.73,-2.56),Vector3(1.5,.34,.055),Color("958065"),true)
	branch(Vector3(-2.6,0,3.8),Vector3(-2.5,2.9,3.7),.10)
	branch(Vector3(-2.55,1.35,3.75),Vector3(-2.2,1.56,2.8),.025)
	branch(Vector3(-2.5,2.2,3.7),Vector3(-3.5,2.45,3.2),.040)
	branch(Vector3(-2.5,2.2,3.7),Vector3(-1.5,2.6,3.6),.036)
	for i in range(7):
		ellipsoid("LeafCanopy",Vector3(-2.5+sin(i*2.2)*.8,2.8+cos(i)*.3,3.6+cos(i*2.2)*.6),Vector3(.72,.35,.65),Color("6d8459"))
	branch(Vector3(-.5,0,3.35),Vector3(-.5,.78,3.35),.07)
	branch(Vector3(-1.0,.78,3.35),Vector3(.08,.78,3.35),.035)
	var grass_rng := RandomNumberGenerator.new(); grass_rng.seed = 715
	for i in range(85):
		var x := grass_rng.randf_range(-6,.05); var z := grass_rng.randf_range(-3.8,4.8)
		if z>.4 and z<1.8: continue
		var grass := box("GrassBlade",Vector3(x,.035,z),Vector3(.012,.07,.013),Color("647c49")); grass.rotation.z = grass_rng.randf_range(-.35,.35)
	for i in range(10):
		var z := -2.5+i*.54
		branch(Vector3(5.1,0,z),Vector3(5.1+sin(i)*.04,.48,z+.03),.008)
		ellipsoid("ReedHead",Vector3(5.1+sin(i)*.04,.51,z+.03),Vector3(.014,.057,.014),Color("806c45"))

func setup_animals() -> void:
	var cat := preload("res://wildlife/cat.tscn").instantiate(); cat.random_seed = 7; add_child(cat); animals.append(cat)
	cat.configure_habitat([Vector3(-3,0,-.6),Vector3(-3.9,0,-1.7),Vector3(-2.1,0,-2.3),Vector3(-1.3,0,-.15)],["ground","ground","ground","ground"],[Vector2i(0,1),Vector2i(1,2),Vector2i(2,3),Vector2i(3,0)])
	cat.rotation.y = -.4
	var polygon := PackedVector2Array([Vector2(.6,-2.7),Vector2(5.4,-2.7),Vector2(5.4,2.3),Vector2(.6,2.3)])
	var duck_nodes: Array[Vector3] = [Vector3(.15,.04,-1.0),Vector3(.85,-.03,-1.0),Vector3(2.1,-.03,-1.5),Vector3(3.7,-.03,-.1),Vector3(2.0,-.03,1.5),Vector3(.85,-.03,.8),Vector3(.15,.04,.8)]
	var duck_modes: Array[String] = ["shore","water","water","water","water","water","shore"]
	var duck_links: Array[Vector2i] = [Vector2i(0,1),Vector2i(1,2),Vector2i(2,3),Vector2i(3,4),Vector2i(4,5),Vector2i(5,6),Vector2i(6,0)]
	for i in range(2):
		var duck := preload("res://wildlife/mallard.tscn").instantiate()
		duck.asset_name = "mallard_male" if i==0 else "mallard_female"; duck.random_seed = 31+i*17; duck.boldness = .4+i*.3
		duck.water_height = .08; duck.water_polygon = polygon; add_child(duck); animals.append(duck)
		# Parallel lanes prevent overlap without coupling the reusable actor to a flock manager.
		var lane: Array[Vector3] = []
		for point in duck_nodes: lane.append(point+Vector3(0,0,.20 if i==1 else -.20))
		duck.configure_habitat(lane,duck_modes,duck_links,2 if i==0 else 6); duck.rotation.y = .7
	var bird_nodes: Array[Vector3] = [Vector3(-1.5,0,2.0),Vector3(-1.05,0,1.85),Vector3(-.7,0,2.15),Vector3(-.5,.815,3.35),Vector3(-2.2,1.585,2.8)]
	var bird_links: Array[Vector2i] = [Vector2i(0,1),Vector2i(1,2),Vector2i(0,3),Vector2i(2,3),Vector2i(3,4),Vector2i(4,0)]
	for i in range(3):
		var bird := preload("res://wildlife/sparrow.tscn").instantiate(); bird.random_seed = 82+i*53; bird.boldness = .2+i*.25; add_child(bird); animals.append(bird)
		bird.configure_habitat(bird_nodes,["ground","ground","ground","perch","perch"],bird_links,[0,2,4][i]); bird.rotation.y = -.6+i*.9
	var squirrel := preload("res://wildlife/squirrel.tscn").instantiate()
	squirrel.random_seed = 147; squirrel.boldness = .35; add_child(squirrel); animals.append(squirrel)
	squirrel.configure_habitat([Vector3(-3.8,0,3.7),Vector3(-3.1,0,3.15),Vector3(-2.5,0,3.35),Vector3(-2.9,0,4.3)],["ground","ground","ground","ground"],[Vector2i(0,1),Vector2i(1,2),Vector2i(2,3),Vector2i(3,0)])
	squirrel.rotation.y = -.7
	var hedgehog := preload("res://wildlife/hedgehog.tscn").instantiate()
	hedgehog.random_seed = 236; hedgehog.boldness = .6; add_child(hedgehog); animals.append(hedgehog)
	hedgehog.configure_habitat([Vector3(-5.3,0,.1),Vector3(-4.8,0,-.35),Vector3(-4.5,0,-.95),Vector3(-5.5,0,-.85)],["ground","ground","ground","ground"],[Vector2i(0,1),Vector2i(1,2),Vector2i(2,3),Vector2i(3,0)])
	hedgehog.rotation.y = -.6

func setup_input() -> void:
	for item in [["forward",KEY_W],["back",KEY_S],["left",KEY_A],["right",KEY_D],["jog",KEY_SHIFT],["jump",KEY_SPACE],["up",KEY_E],["down",KEY_Q]]:
		if not InputMap.has_action(item[0]): InputMap.add_action(item[0])
		var event := InputEventKey.new(); event.physical_keycode = item[1]
		if not InputMap.action_has_event(item[0],event): InputMap.action_add_event(item[0],event)

func setup_player() -> void:
	player = preload("res://scripts/player.gd").new(); add_child(player)
	player.set_view(Vector3(-3,.05,3.5),Vector3(-2,.5,0)); player.enabled = false

func setup_hud() -> void:
	hud = CanvasLayer.new(); add_child(hud)
	var panel := ColorRect.new(); panel.color = Color(.08,.12,.10,.82); panel.position = Vector2(28,28); panel.size = Vector2(570,142); panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.add_child(panel)
	var theme := Theme.new(); var font := SystemFont.new(); font.font_names = PackedStringArray(["Microsoft YaHei","Segoe UI"]); theme.default_font = font
	caption = Label.new(); caption.theme = theme; caption.add_theme_font_size_override("font_size",24); caption.position = Vector2(48,42); hud.add_child(caption)
	status = Label.new(); status.theme = theme; status.add_theme_font_size_override("font_size",14); status.position = Vector2(48,80); hud.add_child(status)
	var help := Label.new(); help.theme = theme; help.add_theme_font_size_override("font_size",15); help.position = Vector2(32,830)
	help.text = "1 猫  ·  2 鸭  ·  3 麻雀  ·  4 自由漫游  ·  5 松鼠  ·  6 刺猬  ·  Tab 下一个体\nSpace 下一动作  ·  B 日常行为  ·  R 重置  ·  拖动 / 滚轮观察  ·  F 隐藏界面  ·  F12 截图"; hud.add_child(help)
	var credit := Label.new(); credit.theme=theme; credit.add_theme_font_size_override("font_size",12); credit.position=Vector2(32,800)
	credit.text="松鼠 / 刺猬原模型：Poly by Google · CC BY 3.0 · poly.pizza（来源及修改记录见接入说明）"; hud.add_child(credit)

func select_animal(index: int) -> void:
	selected = index; inspector = true; player.enabled = false; player.frozen = true
	for animal in animals: animal.observer = null
	camera.current = true; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	orbit_distance = {"cat":1.4,"duck":1.55,"sparrow":.40,"squirrel":.70,"hedgehog":.60}[animals[index].species]
	orbit_pitch = .12; clip_index = -1; update_camera()

func update_camera() -> void:
	if not inspector: return
	var animal: Node3D = animals[selected]
	var y: float = {"cat":.22,"duck":.26,"sparrow":.08,"squirrel":.07,"hedgehog":.06}[animal.species]
	var target := animal.global_position+Vector3.UP*y
	var offset := Vector3(sin(orbit_yaw)*cos(orbit_pitch),sin(orbit_pitch),cos(orbit_yaw)*cos(orbit_pitch))*orbit_distance
	camera.position = target+offset; camera.look_at(target)

func _process(_dt: float) -> void:
	if not automatic: return
	update_camera()
	var animal: Node3D = animals[selected]
	caption.text = {"cat":"狸花猫 · 草边的熟客","duck":"绿头鸭 · 浅岸与水面","sparrow":"麻雀 · 地面与枝头","squirrel":"灰松鼠 · 树根与草地","hedgehog":"刺猬 · 草边慢慢探索"}[animal.species]
	status.text = "%s  |  %s  |  真实体型 / 独立蒙皮\n行为：%s   动作：%s   %.2f m/s\n%d FPS   ·   拖动镜头观察侧面与脚步"%[animal.asset_name,"近景观察" if inspector else "漫游与接近反应",animal.current_behavior,animal.current_clip,animal.measured_speed,Engine.get_frames_per_second()]

func _unhandled_input(event: InputEvent) -> void:
	if capture_mode: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: select_animal(0)
			KEY_2: select_animal(1)
			KEY_3: select_animal(3)
			KEY_5: select_animal(6)
			KEY_6: select_animal(7)
			KEY_TAB: select_animal((selected+1)%animals.size())
			KEY_4:
				inspector = false; player.frozen = false; player.enabled = true; player.camera.current = true
				player.set_view(Vector3(-3,.05,3.5),Vector3(-2,.5,0)); Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				for animal in animals: animal.observer = player
			KEY_SPACE:
				if inspector:
					var clips: PackedStringArray = animals[selected].available_clips(); clip_index = (clip_index+1)%clips.size()
					animals[selected].preview_clip(clips[clip_index]); get_viewport().set_input_as_handled()
			KEY_B: animals[selected].resume_behavior()
			KEY_R:
				for animal in animals: animal.reset_behavior()
			KEY_F: hud.visible = not hud.visible
			KEY_F12:
				get_viewport().get_texture().get_image().save_png(OUT+"manual_%s.png"%Time.get_unix_time_from_system())
	if inspector and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		orbit_yaw -= event.relative.x*.006; orbit_pitch = clampf(orbit_pitch+event.relative.y*.004,-.05,1.1)
	if inspector and event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: orbit_distance = maxf(.17,orbit_distance*.9)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: orbit_distance = minf(8,orbit_distance*1.1)

func run_evidence(args: PackedStringArray) -> void:
	var evidence := preload("res://wildlife/evidence.gd").new(); add_child(evidence)
	await evidence.run(self,args)
