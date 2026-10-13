extends RefCounted
## Visual-only surroundings: no extra playable campus or invented landmark claim.
static func environment(c:Node3D):
	c.sun=DirectionalLight3D.new();c.sun.name="LookDev_Afternoon";c.sun.rotation_degrees=Vector3(-36,-128,0)
	c.sun.light_color=Color(1,.95,.85);c.sun.light_energy=1.85;c.sun.shadow_enabled=true
	c.sun.directional_shadow_max_distance=110;c.sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	c.sun.shadow_blur=1.25;c.sun.shadow_bias=.045;c.add_child(c.sun)
	var we=WorldEnvironment.new();var e=Environment.new();var sk=Sky.new();var sm=ShaderMaterial.new()
	sm.shader=preload("res://shaders/campus_sky.gdshader");sm.set_shader_parameter("panorama",load("res://assets/textures/academic_sky_v2.png"))
	sk.sky_material=sm;sk.radiance_size=Sky.RADIANCE_SIZE_256;sk.process_mode=Sky.PROCESS_MODE_REALTIME
	e.background_mode=Environment.BG_SKY;e.sky=sk;e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color(.53,.58,.61);e.ambient_light_energy=.60;e.ambient_light_sky_contribution=.18
	e.reflected_light_source=0;e.tonemap_mode=Environment.TONE_MAPPER_ACES;e.tonemap_exposure=.95
	e.ssao_enabled=true;e.ssao_radius=1.3;e.ssao_intensity=1.4;e.ssao_power=1.25;e.ssao_detail=.4
	e.ssil_enabled=true;e.ssil_radius=3.5;e.ssil_intensity=.65
	e.ssr_enabled=true;e.ssr_max_steps=48;e.ssr_fade_in=.15;e.ssr_fade_out=2.0
	e.fog_enabled=true;e.fog_light_color=Color(.64,.73,.77);e.fog_density=.00075;e.fog_sky_affect=0
	e.glow_enabled=true;e.glow_intensity=.08;e.glow_bloom=0;we.environment=e;c.add_child(we)
	c.live_environment=e
	for p in [Vector3(0,9,144),Vector3(36,7,85)]:
		var probe=ReflectionProbe.new();probe.position=p;probe.size=Vector3(150,45,135);probe.box_projection=true
		probe.max_distance=200;probe.intensity=1;probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED;probe.enable_shadows=true;c.add_child(probe)

static func context(c:Node3D):
	# Shallow continuation removes the stage silhouette; sample limits have visible rails.
	var distant_grass=ShaderMaterial.new();distant_grass.shader=preload("res://shaders/lookdev_context_ground.gdshader")
	var floor=c.box(Vector3(20,-.25,130),Vector3(1800,.10,1800),distant_grass)
	floor.name="LookDev_DistantGround_VisualOnly";floor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bars=[];var footings=[];var Geometry=preload("res://scripts/wave2_environment.gd")
	for node in c.world.get_children():
		if not node is StaticBody3D:continue
		var name=String(node.get_meta("source_label",node.name))
		if not (name.begins_with("ModelBoundary") or name.begins_with("NorthOuterBoundary") or name.begins_with("Wave2OuterBoundary")):continue
		var shape:BoxShape3D=node.get_child(0).shape
		var along_x=shape.size.x>shape.size.z;var length=shape.size.x if along_x else shape.size.z
		var direction=node.basis.x if along_x else node.basis.z;var heading=atan2(direction.x,direction.z)
		var center=Vector3(node.position.x,0,node.position.z)
		for y in [.46,1.18]:bars.append(Geometry._box_transform(center+Vector3.UP*y,Vector3(.045,.045,length),heading))
		footings.append(Geometry._box_transform(center+Vector3.UP*.035,Vector3(.24,.10,length),heading))
		var count=maxi(1,int(ceil(length/1.8)))
		for i in range(count+1):
			var p=center+direction*length*(float(i)/count-.5)
			bars.append(Geometry._box_transform(p+Vector3.UP*.60,Vector3(.055,1.2,.055),heading))
	Geometry._box_batch(c,bars,c.asset_material("LookDevBoundaryMetal",Color(.22,.29,.25)),"LookDevSampleBoundaryRails")
	Geometry._box_batch(c,footings,c.mats.stone,"LookDevSampleBoundaryFooting")
	var rng=RandomNumberGenerator.new();rng.seed=19580920;var trees=[]
	for i in range(110):
		var p:Vector2
		match i%4:
			0:p=Vector2(rng.randf_range(-120,215),rng.randf_range(-75,-48))
			1:p=Vector2(rng.randf_range(-170,165),rng.randf_range(300,326))
			2:p=Vector2(rng.randf_range(-158,-135),rng.randf_range(-20,270))
			_:p=Vector2(rng.randf_range(209,236),rng.randf_range(-20,270))
		var blocked=false
		if preload("res://scripts/scene_modules.gd").contains(p):blocked=true
		for building in c.site.background:
			var polygon=PackedVector2Array()
			for v in building.outline:polygon.append(Vector2(v[0],v[1]))
			if Geometry2D.is_point_in_polygon(p,polygon):blocked=true;break
		if not blocked:trees.append(c.placement(p.x,-.2,p.y,Vector3.ONE*rng.randf_range(1.10,1.48),rng.randf()*TAU))
	c.context_mode=true;c.multimesh("tree1",trees);c.context_mode=false
	c.world.set_meta("lookdev_context",{"trees":trees.size(),"boundary_rails":bars.size(),"playable_extension":false})
