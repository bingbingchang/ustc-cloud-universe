extends SceneTree
## Render one actual plaza tree on paving. Keep its screen size constant while
## changing the camera angle/distance so projection alone cannot pass the tests.

class Garden extends "res://scripts/campus_game.gd":
	func _ready():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		world = Node3D.new()
		add_child(world)
		sun = DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-38,-135,0)
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 100
		add_child(sun)

class TreePolicy extends "res://scripts/runtime_render_policy.gd":
	func add_mapped_occluders(): pass

var garden: Garden
var camera: Camera3D
var center: Vector3

func _initialize(): call_deferred("run")

func shoot(radius: float, yaw: float, pitch: float) -> Image:
	var y := deg_to_rad(yaw)
	var p := deg_to_rad(pitch)
	camera.position = center + radius * Vector3(sin(y)*cos(p),sin(p),cos(y)*cos(p))
	camera.look_at(center)
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func difference(a: Image, b: Image) -> float:
	var total := 0.0
	for y in range(1,a.get_height(),3):
		for x in range(1,a.get_width(),3):
			var c := a.get_pixel(x,y)-b.get_pixel(x,y)
			total += absf(c.r)+absf(c.g)+absf(c.b)
	return total*3.0 / (a.get_width()*a.get_height())

func run():
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	root.use_taa = false
	garden = Garden.new()
	root.add_child(garden)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.62,.72,.79)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.62,.62,.62)
	garden.get_world_3d().environment = env
	var ground := MeshInstance3D.new()
	var tile := PlaneMesh.new()
	tile.size = Vector2(1200,1200)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(.67,.67,.67)
	tile.material = stone
	ground.mesh = tile
	garden.world.add_child(ground)
	garden.player = CharacterBody3D.new()
	garden.add_child(garden.player)
	camera = Camera3D.new()
	camera.cull_mask &= ~garden.REFLECTION_LAYER
	camera.set_orthogonal(19,.1,650)
	garden.add_child(camera)
	camera.current = true
	var species := "tree_plane_a"
	garden.multimesh_batch(species,[Transform3D.IDENTITY])
	var policy := TreePolicy.new()
	policy.game = garden
	garden.add_child(policy)
	if not garden.world.find_child("SakuraFar_*",false,false):
		push_error("Actual near/far tree pair was not built")
		quit(1)
		return
	for node in garden.world.get_children():
		if node.get_meta("render_asset","") == species:
			center = (node.global_transform*node.get_aabb()).get_center()
			break
	var far_tree: MultiMeshInstance3D = garden.world.find_child("SakuraFar_*",false,false)
	# Aim at the billboard pivot for angular checks; the shared bounds center
	# can differ from that pivot when several trees form an LOD batch.
	var range_center := center
	center = far_tree.multimesh.get_instance_transform(0).origin
	await shoot(50,0,10)
	var errors := []
	var angles := {}
	var legacy := ShaderMaterial.new()
	legacy.shader = load("res://shaders/detail_impostor.gdshader")
	legacy.set_shader_parameter("atlas",far_tree.multimesh.mesh.material.get_shader_parameter("atlas"))
	for test in [[22.5,0.0,0.08,0.0],[0.0,10.0,0.0,0.08],[337.5,0.0,.08,0.0]]:
		var a := await shoot(70,test[0]-test[2],test[1]-test[3])
		var b := await shoot(70,test[0]+test[2],test[1]+test[3])
		var jump := difference(a,b)
		far_tree.material_override = legacy
		var old_a := await shoot(70,test[0]-test[2],test[1]-test[3])
		var old_b := await shoot(70,test[0]+test[2],test[1]+test[3])
		far_tree.material_override = null
		var old_jump := difference(old_a,old_b)
		angles[str(test)] = [old_jump,jump]
		if jump > .012 or jump > old_jump*.6: errors.append("angle discontinuity "+str(test))
	center = range_center
	var biggest := 0.0
	var total := 0.0
	var previous := await shoot(28,0,7)
	for r in range(29,51):
		var frame := await shoot(r,0,7)
		var change := difference(previous,frame)
		total += change
		biggest = maxf(biggest,change)
		previous = frame
	if total <= .001 or biggest > total*.60: errors.append("abrupt or missing geometry transition")
	# Compare only the footprint; wind in the tree must not register as shadow.
	for n in garden.world.get_children():
		if n is MultiMeshInstance3D and not n.has_meta("far_canopy_footprint"): n.hide()
	var footprints := garden.world.get_children().filter(func(n): return n.has_meta("far_canopy_footprint"))
	if footprints.is_empty(): errors.append("no far canopy projection exists")
	var shadows := {}
	for profile in [true,false]:
		garden.apply_quality(profile)
		var strengths := []
		for r in [150.0 if profile else 200.0,340.0,445.0]:
			var on := await shoot(r,-70,22)
			for n in footprints: n.hide()
			var off := await shoot(r,-70,22)
			for n in footprints: n.show()
			strengths.append(difference(on,off))
		shadows[str(profile)] = strengths
		if strengths[0]<.0002 or strengths[1]<=.00002 or strengths[1]>=strengths[0] or strengths[2]>.0001:
			errors.append("missing or non-fading ground shadow "+str(profile))
	print("TREE_TRANSITION_CHECK ",JSON.stringify({"angle_differences":angles,"largest_step":biggest,
		"sum_steps":total,"ground_shadow_differences":shadows,"errors":errors}))
	garden.queue_free()
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)
