extends "res://scripts/lookdev_live.gd"
## Isolated composition study. Base campus and previous lake entry are unchanged.
const REFLECTION_LAYER=1<<17
var reflection_view:SubViewport
var reflection_camera:Camera3D
var reflection_material:ShaderMaterial
var study_ready=false
var study_records=[]
var study_stats={}

func _ready():
	super._ready()
	if not "--study-before" in OS.get_cmdline_user_args():
		compose_garden();setup_study_light();setup_reflection();study_ready=true
	photo_spots.append({"name":"一鉴亭 · 构图样段","pos":Vector3(24,.65,65),"target":Vector3(43,3.1,81),"fov":48.0,"ortho":false,"size":120.0,"reason":"浅色亭桥、深色林群、开阔倒影与前景花叶"})
	viewpoint(photo_spots.size()-1)
	print("LAKE_STUDY_READY ",JSON.stringify(study_stats))

func asset_material(key:String,c:Color)->ShaderMaterial:
	var m=super.asset_material(key,c)
	if key.begins_with("StudyLeaf"):
		m.shader=preload("res://shaders/study_foliage.gdshader");m.set_shader_parameter("base_color",c)
	if key=="StudyBark":SakuraPaint.apply(m,"bark")
	return m

func place_tree(asset:String,p:Vector2,scale:float):
	if not study_land_safe(p,maxf(.95,scale*.68)):return
	for t in NorthAxis.layout().trees:
		if p.distance_to(Vector2(t[0],t[1]))<2.8:return
	var tr=placement(p.x,0,p.y,Vector3.ONE*scale,rng.randf()*TAU);multimesh_batch(asset,[tr])
	var body=StaticBody3D.new();body.name="StudyTreeBark";body.transform=tr;world.add_child(body)
	var cs=CollisionShape3D.new();cs.shape=Sakura.low_bark(self,asset);body.add_child(cs)
	var record={"asset":asset,"actual_asset":asset,"placement":tr,"position":tr.origin,"body":body.get_path()}
	lookdev_tree_contacts.append(record);study_records.append(record);tree_count+=1

func study_land_safe(p:Vector2,r:float)->bool:
	if p.y<118:return Lake.land_safe(p,r)
	if p.x<18 or p.x>79-r or p.y>138:return false
	for q in [Vector2.ZERO,Vector2(r,0),Vector2(-r,0),Vector2(0,r),Vector2(0,-r)]:
		if NorthAxis._inside_pond(p+q,NorthAxis.layout()):return false
	if NorthAxis._distance_paths(NorthAxis.layout(),p)<r+.5:return false
	for b in NorthAxis.layout().benches:
		if p.distance_to(Vector2(b[0],b[1]))<r+1.65:return false
	return true

func compose_garden():
	rng.seed=20260909
	# A background with depth, staggered silhouettes and two height bands.
	for p in [Vector2(69,95),Vector2(72,102),Vector2(72,114),Vector2(70,125),Vector2(79,119),Vector2(78,96),Vector2(80,112),Vector2(54,133),Vector2(45,134)]:
		place_tree("study_canopy_"+str(study_records.size()%2),p,rng.randf_range(1.75,2.1))
	for p in [Vector2(67,108),Vector2(64,124),Vector2(32,56)]:place_tree("study_canopy_2",p,.68)
	for p in [Vector2(68,88),Vector2(66.3,97),Vector2(67,102),Vector2(69,111),Vector2(71,117),Vector2(59,129),Vector2(50.6,82.2),Vector2(48.5,74.5)]:
		place_tree("study_canopy_"+str(2 if study_records.size()%3==0 else 0),p,rng.randf_range(.36,.52))
	place_tree("lake_willow_0",Vector2(22,61),1.40)
	place_tree("lake_willow_1",Vector2(31,60),1.65)
	# Replace only the pond's new decoration batches; their original versions remain reusable.
	for n in world.get_children():
		if n is MultiMeshInstance3D and String(n.get_meta("render_asset",n.name)).begins_with("lake_lotus_"):n.visible=false
	var pads=[[],[],[],[]];var bank=[[],[]]
	# Deliberate overlapping islands of plants, with an open reflection lane to the pavilion.
	var islands=[[Vector2(22,79),Vector2(5,8),74],[Vector2(28,103),Vector2(7,11),115],[Vector2(48,119),Vector2(10,5),86],[Vector2(59,93),Vector2(3.2,9),85],[Vector2(53,65),Vector2(7,3.5),48]]
	for island in islands:
		for i in range(island[2]):
			var a=rng.randf()*TAU;var r=sqrt(rng.randf());var p=island[0]+Vector2(cos(a)*island[1].x,sin(a)*island[1].y)*r
			if not Lake.water_safe(p,.9):continue
			var kind=rng.randi_range(0,3);var sc=rng.randf_range(.70,1.08)
			pads[kind].append(placement(p.x,-.04,p.y,Vector3(sc,rng.randf_range(.55,1.05),sc),rng.randf()*TAU))
	for i in range(4):multimesh_batch("study_lotus_"+str(i),pads[i])
	for cluster in [Vector2(24,68),Vector2(23,67),Vector2(22,71),Vector2(19,76),Vector2(31,57),Vector2(65.5,94),Vector2(67,103),Vector2(57,131)]:
		for i in range(15):
			var p=cluster+Vector2(rng.randf_range(-2.6,2.6),rng.randf_range(-2.7,2.7))
			if not Lake.land_safe(p,.45):continue
			bank[0 if i%5 else 1].append(placement(p.x,0,p.y,Vector3.ONE*rng.randf_range(.95,1.65),rng.randf()*TAU))
	for i in range(2):multimesh_batch("study_bank_patch_"+str(i),bank[i])
	# Compose connected foreground and middle-ground groups, leaving the bridge clear.
	multimesh_batch("study_willow_bough",[placement(22,0,61,Vector3.ONE,0)])
	var rocks=[[],[]];var flowers=[[],[]]
	for p in [Vector2(23,76),Vector2(58,89),Vector2(52,121),Vector2(59,74),Vector2(24,94),Vector2(55,112)]:
		if Lake.water_safe(p,2.1):
			var k=rocks[0].size()%2;rocks[k].append(placement(p.x,-.26,p.y,Vector3.ONE*rng.randf_range(.85,1.25),rng.randf()*TAU))
	for anchor in [Vector2(22,66),Vector2(21,72),Vector2(19,79),Vector2(74,79),Vector2(76,86),Vector2(69,89),Vector2(68,105),Vector2(48,75),Vector2(51,83)]:
		for j in range(12):
			var p=anchor+Vector2(rng.randf_range(-2.7,2.7),rng.randf_range(-2.7,2.7))
			if not study_land_safe(p,.9):continue
			flowers[j%2].append(placement(p.x,0,p.y,Vector3.ONE*rng.randf_range(.65,1.05),rng.randf()*TAU))
	for i in range(2):
		multimesh_batch("study_rock_garden_"+str(i),rocks[i]);multimesh_batch("study_flower_mound_"+str(i),flowers[i])
	world.set_meta("lookdev_tree_contacts",lookdev_tree_contacts)
	world.set_meta("study_tree_records",study_records)
	for n in world.get_children():
		if n is GeometryInstance3D:n.visibility_range_end=0
	var count=0
	for b in pads:count+=b.size()
	study_stats={"new_trees":study_records.size(),"lotus_clusters":count,"bank_patches":bank[0].size()+bank[1].size(),"existing_map_changed":false,"population":14}
	study_stats["sculptural_rock_groups"]=rocks[0].size()+rocks[1].size();study_stats["flower_mounds"]=flowers[0].size()+flowers[1].size();study_stats["willow_overhang"]=true

func setup_study_light():
	live_environment.ambient_light_color=Color(.49,.60,.69);live_environment.ambient_light_energy=.47
	live_environment.tonemap_exposure=1.04;live_environment.ssao_intensity=.85
	live_environment.ssil_intensity=.8
	# Broad local bounce lifts the pavilion without lighting the entire campus flat.
	var fill=SpotLight3D.new();fill.name="PavilionWarmBounce";fill.position=Vector3(29,10,68);add_child(fill)
	fill.look_at(Vector3(42.5,2.5,80.8));fill.light_color=Color(1,.94,.79);fill.light_energy=1.6
	fill.spot_range=36;fill.spot_angle=31;fill.spot_attenuation=.4;fill.shadow_enabled=false

func reflectable(node:Node):
	if node is GeometryInstance3D:
		if node.visible and not node.get_meta("lake_water",false) and not String(node.name).begins_with("NorthWater"):
			var box=node.global_transform*node.get_aabb()
			if box.end.y>.60:node.layers|=REFLECTION_LAYER
	for ch in node.get_children():reflectable(ch)

func setup_reflection():
	reflectable(world)
	reflection_view=SubViewport.new();reflection_view.name="LakePlanarReflection";reflection_view.size=Vector2i(768,432)
	reflection_view.world_3d=get_world_3d();reflection_view.msaa_3d=Viewport.MSAA_2X;reflection_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(reflection_view)
	reflection_camera=Camera3D.new();reflection_camera.near=.08;reflection_camera.far=230;reflection_camera.cull_mask=REFLECTION_LAYER;reflection_view.add_child(reflection_camera);reflection_camera.current=true
	var e=live_environment.duplicate();e.ssr_enabled=false;e.ssao_enabled=false;e.ssil_enabled=false;e.glow_enabled=false;reflection_camera.environment=e
	reflection_material=ShaderMaterial.new();reflection_material.shader=preload("res://shaders/study_water.gdshader")
	reflection_material.set_shader_parameter("reflection_texture",reflection_view.get_texture())
	for n in world.get_children():
		if n is MeshInstance3D and n.get_meta("lake_water",false):n.material_override=reflection_material

func _process(dt):
	super._process(dt)
	if not study_ready:return
	sun.rotation_degrees=Vector3(-43,-131,0);sun.light_color=Color(1,.94,.81);sun.light_energy=1.95;sun.shadow_blur=1.6;sun.light_angular_distance=1.1
	update_reflection()

func update_reflection():
	var cam=photo_camera if photo_camera else player.camera
	if not cam:return
	var pos=cam.global_position;pos.y=-.10-pos.y
	var forward=-cam.global_basis.z;forward.y=-forward.y
	reflection_camera.global_position=pos;reflection_camera.look_at(pos+forward,Vector3.UP)
	reflection_camera.fov=cam.fov;reflection_camera.projection=cam.projection;reflection_camera.size=cam.size
	var matrix=reflection_camera.get_camera_projection()*Projection(reflection_camera.global_transform.affine_inverse())
	reflection_material.set_shader_parameter("reflection_vp",matrix)
