extends "res://scripts/campus.gd"
var life_layer:Node3D
var wave2_layer:Node3D
var verification_failed=false
var population_photo_index=0
const NorthAxis=preload("res://scripts/north_axis_environment.gd")
const Sakura=preload("res://scripts/sakura_avenue.gd")
const SakuraPaint=preload("res://scripts/sakura_paint.gd")
const Lake=preload("res://scripts/lake_garden.gd")
const LakePaint=preload("res://scripts/lake_paint.gd")

func sakura_replaces(p:Vector2)->bool:
	return Sakura.in_segment(p)

func _ready():
	super._ready()
	# The player is created after setup_life() in the base scene.
	life_layer.actors.solver.root.passerby=player;life_layer.actors.roadside.root.passerby=player
	lookdev_mode=true
	photo_spots=[
		{"name":"01 · 收藏一段春日 / 正交","pos":Vector3(-152,145,2),"target":Vector3(0,2,177),"fov":32.0,"ortho":true,"size":150.0,"reason":"完整一教U形、短樱花轴线与展台边界；3/4正交"},
		{"name":"02 · 同方向普通透视 / A-B","pos":Vector3(-100,96,62),"target":Vector3(0,2,177),"fov":50.0,"ortho":false,"size":150.0,"reason":"相同方位与俯角，普通透视与01正交比较"},
		{"name":"03 · 樱花与红楼","pos":Vector3(-24,27,113),"target":Vector3(0,3,159),"fov":44.0,"ortho":false,"size":90.0,"reason":"花团前景、铺装树影、红砖入口；低位长焦"},
		{"name":"04 · 午后门厅","pos":Vector3(24,6,143),"target":Vector3(0,3.5,168),"fov":46.0,"ortho":false,"size":55.0,"reason":"窗洞、雨棚、台阶与自行车尺度"},
		{"name":"05 · 庭院一隅 / 弱透视","pos":Vector3(123,101,303),"target":Vector3(0,2,178),"fov":44.0,"ortho":false,"size":200.0,"reason":"从南侧看真实U形院落，长焦压缩模型层次"}]
	photo_spots.append_array([
		{"name":"06 · 一道题的下午","pos":Vector3(-20.3,2.1,143.4),"target":Vector3(-17,1.02,146.9),"fov":40.0,"ortho":false,"size":12.0,"reason":"长椅、写题、资料与晒太阳的猫组成微型叙事"},
		{"name":"07 · 留住花开的时间","pos":Vector3(8.5,2.2,136.4),"target":Vector3(10.4,1.0,140.8),"fov":42.0,"ortho":false,"size":12.0,"reason":"举手机、微调构图、樱花与路灯的校园切片"},
		{"name":"08 · 猫的午后","pos":Vector3(-19.7,1.15,144.1),"target":Vector3(-18.2,.27,146.3),"fov":44.0,"ortho":false,"size":10.0,"reason":"低视点观察猫的呼吸、舔爪与附近学习场景"},
		{"name":"09 · 慢慢记住的一页","pos":Vector3(23.0,2.05,153.3),"target":Vector3(19.3,1.0,155.6),"fov":42.0,"ortho":false,"size":12.0,"reason":"背资料、停步、翻页与重新起步"}])
	player.last_ground=Vector3(0,.16,127)
	photo_spots.append({"name":"10 · 路灯旁的一点深思","pos":Vector3(1.8,1.72,142.35),"target":Vector3(3.4,1.14,145.0),"fov":38.0,"ortho":false,"size":12.0,"reason":"同一做题家的蓝白运动校服变体，夹书、侧目、路灯与铺装边界"})
	photo_spots.append_array([
		{"name":"11 · 骑车归来的同学","pos":Vector3(50,2.6,153),"target":Vector3(55.9,1.0,157),"fov":42.0,"ortho":false,"size":12.0,"reason":"缓行与推车停靠，在东侧前场保留安静的校园活动"},
		{"name":"12 · 庭院里读完一页","pos":Vector3(-23,2.3,223.4),"target":Vector3(-27,1.0,218.8),"fov":42.0,"ortho":false,"size":12.0,"reason":"长椅读者与背后院墙、树影组成静区"},
		{"name":"13 · 玉泉北路接续","pos":Vector3(-18,20,88),"target":Vector3(0,1,122),"fov":46.0,"ortho":false,"size":55.0,"reason":"12米连续陆地通路连接现有樱花轴线；湖面尚未扩建"}])
	player.respawn_position=Vector3(0,.16,127);player.respawn_target=Vector3(0,6,170)
	if "--audit-ground" in OS.get_cmdline_user_args():call_deferred("audit_ground")
	if "--motion" in OS.get_cmdline_user_args():call_deferred("capture_motion")
	if "--population-qa" in OS.get_cmdline_user_args():call_deferred("population_qa")
	if "--population-motion" in OS.get_cmdline_user_args():call_deferred("population_motion")
	if "--population-profile" in OS.get_cmdline_user_args():call_deferred("population_profile")
	if "--wave2-qa" in OS.get_cmdline_user_args():call_deferred("wave2_qa")
	if "--wave2-motion" in OS.get_cmdline_user_args():call_deferred("wave2_motion")
	if "--wave2-profile" in OS.get_cmdline_user_args():call_deferred("wave2_profile")
	if "--north-qa" in OS.get_cmdline_user_args():call_deferred("north_qa")
	if "--north-motion" in OS.get_cmdline_user_args():call_deferred("north_motion")
	photo_spots.append_array(wave2_layer.spots())
	photo_spots.append({"name":"19 · 五处小故事 / 第二波总览","pos":Vector3(-218,183,-27),"target":Vector3(0,0,194),"fov":38.0,"ortho":true,"size":208.0,"reason":"相邻花园与西南、南侧接段保持建筑主角和角色留白"})
	photo_spots[12]={"name":"13 · 玉泉北路接续","pos":Vector3(-18,20,88),"target":Vector3(0,1,122),"fov":46.0,"ortho":false,"size":55.0,"reason":"双池之间连续校园轴线接入现有樱花与一教"}
	photo_spots.append({"name":"20 · 老北门—双池—第一教学楼","pos":Vector3(-258,232,-171),"target":Vector3(27,0,122),"fov":38.0,"ortho":true,"size":310.0,"reason":"真实核心轴线与相邻建筑群共同组成完整校园切片"})
	for spot in NorthAxis.camera_spots():
		spot.pos.y-=1.65
		photo_spots.append(spot)
	player.respawn_position=Vector3(0,.16,12);player.respawn_target=Vector3(0,3,168)
	write_spots();viewpoint(19)
	if "--character-focus" in OS.get_cmdline_user_args():viewpoint(5)
	if "--wave2-focus" in OS.get_cmdline_user_args():viewpoint(18)
	for node in world.get_children():
		if node is GeometryInstance3D:node.visibility_range_end=0
	spot_label.text="[ ] 切换全部%d机位 · P 老北门步行 · L 漫步路线"%photo_spots.size()
	if "--lake-focus" in OS.get_cmdline_user_args():
		photo_spots.append({"name":"一鉴亭 · 春日湖园","pos":Vector3(73,.20,78),"target":Vector3(42.5,3,80.8),"fov":56.0,"ortho":false,"size":120.0,"reason":"湖园曲桥与水岸"})
		viewpoint(photo_spots.size()-1)

func material(c:Color,fol=0.0,g=0.0,br=0.0)->ShaderMaterial:
	var m=super.material(c,fol,g,br);m.shader=preload("res://shaders/diorama.gdshader");return m

func asset_material(key:String,c:Color)->ShaderMaterial:
	if key.begins_with("SakuraBloom"):
		if original_mats.has(key):return original_mats[key]
		var blossom=ShaderMaterial.new();blossom.shader=preload("res://shaders/sakura_blossom.gdshader");blossom.set_shader_parameter("base_color",c)
		blossom.set_shader_parameter("paint_enabled",SakuraPaint.enabled())
		if SakuraPaint.enabled():blossom.set_shader_parameter("paint_atlas",load("res://assets/textures/sakura_monet_atlas_v1.png"))
		original_mats[key]=blossom;art_mats.append(blossom);return blossom
	if (key.begins_with("Ambient") or key.begins_with("Cameo") or key.begins_with("Mascot")) and ("Cloth" in key or "Sage" in key or "BlueGrey" in key):
		if original_mats.has(key):return original_mats[key]
		var cloth=ShaderMaterial.new();cloth.shader=preload("res://shaders/tiku_cloth.gdshader");cloth.set_shader_parameter("base_color",c);original_mats[key]=cloth;return cloth
	var m=super.asset_material(key,c)
	if key=="SakuraBark":
		surface(m,"bark",Vector2(1.4,3.2));m.set_shader_parameter("base_color",Color(.82,.72,.64))
	if "Brick" in key:m.set_shader_parameter("brick",1.0)
	if "Bloom" in key or "DioLeaf" in key:
		m.set_shader_parameter("foliage",.65);m.set_shader_parameter("rough",.9)
	if key=="Roof":m.set_shader_parameter("base_color",Color(.48,.51,.47))
	if key=="LifeWood":surface(m,"wood",Vector2(.7,2))
	if key in ["NorthGateIvory","NorthSoffit","NorthColumn","NorthStone","NorthRender"]:surface(m,"stone",Vector2(2,2))
	if key=="NorthCourtWood":surface(m,"wood",Vector2(.7,2))
	if key=="Frame":m.set_shader_parameter("base_color",Color(.72,.70,.60))
	if key.begins_with("SakuraBark"):SakuraPaint.apply(m,"bark")
	elif key.begins_with("SakuraLeaf"):SakuraPaint.apply(m,"leaf")
	elif key=="SakuraFlowerCream":SakuraPaint.apply(m,"petal")
	if key in ["NorthStone","NorthColumn","NorthSoffit"]:LakePaint.apply(m,"stone")
	if LakePaint.enabled() and key in ["NorthColumn","NorthSoffit"]:m.set_shader_parameter("lake_strength",.20)
	if key=="Stone":
		LakePaint.apply(m,"stone")
		if LakePaint.enabled():m.set_shader_parameter("lake_strength",.38)
	if key in ["PavilionRoof","NorthTileWarm"]:LakePaint.apply(m,"roof")
	if key in ["LakeWillow","LakeWillowLight","LakeLeaf","LakeLeafLight","LakeReed","LakeVein"]:
		m.set_shader_parameter("foliage",.65);LakePaint.apply(m,"leaf",false)
	if key=="LakeStone":LakePaint.apply(m,"stone",false)
	if key=="LakeBark":SakuraPaint.apply(m,"bark")
	if key in ["LakePetal","LakePink"]:SakuraPaint.apply(m,"petal")
	return m

func setup_materials():
	super.setup_materials()
	mats.grass.set_shader_parameter("lawn",true)
	mats.water.shader=preload("res://shaders/north_water.gdshader")
	for key in ["path","road","stone"]:SakuraPaint.apply(mats[key],"stone",true)
	SakuraPaint.apply(mats.grass,"lawn",true)
	for key in ["path","road","stone"]:LakePaint.apply(mats[key],"stone")
	LakePaint.apply(mats.grass,"lawn")

func load_art(asset:String):
	if asset=="architecture":
		super.load_art("dioarchitecture")
		super.load_art("north_axis_architecture")
		super.load_art("north_axis_surroundings")
	if asset=="sitedetail":super.load_art("diositedetail")

func terrain():
	ponds=[]
	for pond in NorthAxis.layout().ponds:ponds.append(NorthAxis.polygon(pond.outer))
	super.load_art("diobase")
	# Render to the exact shared boundary. An inset here leaves visible cracks even
	# when the full-size collision slab makes the join walkable.
	var rect=NorthAxis._core()
	var lawns=NorthAxis._pieces(rect,ponds+[NorthAxis.polygon(NorthAxis.layout().polygon)])
	NorthAxis._surface(self,lawns,0,mats.grass,"CoreContinuousLand")
	# Physics is independent of visual triangle winding and decorative surface changes.
	var core_bounds=NorthAxis._bounds(rect);var core_center=core_bounds.get_center()
	static_box(Vector3(core_center.x,-.35,core_center.y),Vector3(core_bounds.size.x,.70,core_bounds.size.y),"ContinuousWalkableLand")
	var backdrop=StandardMaterial3D.new();backdrop.albedo_color=Color(.46,.48,.47);backdrop.roughness=1.0
	box(Vector3(0,-4.25,178),Vector3(3000,.20,3000),backdrop)
	# Every cut in the former border is tied to a researched, enabled module port.
	for side in ["north","south","east","west"]:model_boundary(side)
	preload("res://scripts/scene_modules.gd").build(self)

func model_boundary(side:String):
	var horizontal=side in ["north","south"]
	var cursor=-80.0 if horizontal else 118.0
	var end=80.0 if horizontal else 238.0
	var fixed=118.0 if side=="north" else 238.0 if side=="south" else 80.0 if side=="east" else -80.0
	var spans=preload("res://scripts/scene_modules.gd").boundary_openings(side)
	spans.append(Vector2(end,end))
	for span in spans:
		var lo=clampf(span.x,cursor,end)
		if lo>cursor:
			var mid=(lo+cursor)*.5;var length=lo-cursor
			static_box(Vector3(mid,1,fixed) if horizontal else Vector3(fixed,1,mid),Vector3(length,3,.4) if horizontal else Vector3(.4,3,length),"ModelBoundary")
		cursor=maxf(cursor,span.y)

func build_collisions():
	preload("res://scripts/north_axis_solids.gd").build(self)
	static_box(Vector3(0,8.5,176),Vector3(124,17,16),"TeachingHallNorth")
	for x in [-55,55]:static_box(Vector3(x,8.5,201),Vector3(14,17,42),"TeachingHallWing")
	static_box(Vector3(0,8.5,183.8),Vector3(31,17,11),"TeachingHallCenter")
	for i in range(4):
		var h=.12*(i+1);static_box(Vector3(0,h/2,165+i*.45),Vector3(12,h,.48),"EntryTread")
	static_box(Vector3(0,.24,166.85),Vector3(12,.48,.75),"EntryLanding")
	for x in [-10.2,10.2]:static_box(Vector3(x,.28,166.4),Vector3(4.3,.56,1.5),"EntryPlanter")
	static_box(Vector3(0,2,167.5),Vector3(9,4,.4),"EntranceGlass")

func paths():
	box(Vector3(0,.03,143),Vector3(8,.10,50),mats.path,true)
	box(Vector3(0,.045,158),Vector3(151,.12,14),mats.path,true)
	box(Vector3(0,.04,197),Vector3(74,.1,26),mats.path,true)
	box(Vector3(0,.055,218),Vector3(6,.12,38),mats.path,true)
	for x in [-45,45]:box(Vector3(x,.055,207),Vector3(7,.12,60),mats.path,true)
	for x in [-4.25,4.25]:
		for z in range(119,150):box(Vector3(x,.09,z),Vector3(.23,.18,.96),mats.stone)
	for z in [150.9,165.1]:
		for x in range(-74,75):
			if abs(x)>5:box(Vector3(x,.12,z),Vector3(.96,.23,.28),mats.stone)

func planting():
	var batches={}
	for s in range(3):
		for v in range(3):batches["diotree%d%d"%[s,v]]=[]
	for side in [-1,1]:
		for i in range(4):
			var z=123+i*7.45;var x=side*7.15;var sc=rng.randf_range(.94,1.06)
			if sakura_replaces(Vector2(x,z)):continue
			batches["diotree0%d"%(i%3)].append(placement(x,0,z,Vector3.ONE*sc,side+i*.7))
			static_box(Vector3(x,1,z),Vector3(.5,2,.5),"CherryTrunk")
	# Frame the red building without hiding its central entrance.
	for i in range(8):
		var x=-68+i*19.4
		if abs(x)<12:continue
		batches["diotree1%d"%(i%3)].append(placement(x,0,144,Vector3.ONE*.94,i*.72))
	for i in range(12):
		var x=([-69,69][i%2]);var z=176+(i/2)*10
		batches["diotree2%d"%(i%3)].append(placement(x,0,z,Vector3.ONE*rng.randf_range(.85,1.05),i*.9))
	for i in range(6):
		var x=-32+i*12.8
		batches["diotree1%d"%(i%3)].append(placement(x,0,225,Vector3.ONE*.75,i))
	for key in batches:
		multimesh(key,batches[key]);tree_count+=batches[key].size()
		if not key.begins_with("diotree0"):
			for t in batches[key]:static_box(t.origin+Vector3(0,1,0),Vector3(.55,2,.55),"TreeTrunk")
	var shrubs=[]
	for side in [-1,1]:
		for i in range(18):shrubs.append(placement(side*(18+i*2.65),0,149,Vector3.ONE*.80,i))
		for z in range(178,233,3):shrubs.append(placement(side*49,0,z,Vector3.ONE*.85,z))
	multimesh("dioshrub",shrubs)
	var grass=[]
	for i in range(300):
		var x=rng.randf_range(-75,75);var z=rng.randf_range(121,148)
		if abs(x)>10 and not pond_at(Vector2(x,z)):grass.append(placement(x,.02,z,Vector3.ONE*.7,rng.randf()*TAU))
	multimesh("grass",grass)
	Sakura.build(self)
	Lake.build(self)

func furniture():
	var benches=[];var lamps=[];var bikes=[]
	for x in [-32,-17,17,32]:
		benches.append(placement(x,.08,147,Vector3.ONE,0));static_box(Vector3(x,.54,147),Vector3(1.86,.98,.60),"BenchBody")
	for side in [-1,1]:
		for z in [123,146]:lamps.append(placement(side*5.0,0,z,Vector3.ONE,0 if side<0 else PI))
	for i in range(7):bikes.append(placement(-31+i*2,.1,165,Vector3.ONE,.80+i*.025))
	multimesh("bench",benches);multimesh("lamp",lamps);multimesh("bicycle",bikes)
	signpost(Vector3(10,.02,153),"第一教学楼","F I R S T   T E A C H I N G   H A L L")
	for p in [Vector3(25.15,0,151.3),Vector3(-27,0,215.5)]:
		var board=load("res://assets/bulletin.glb").instantiate();world.add_child(board);board.position=p;style(board)
		if p.z>200:board.rotation.y=PI
		for x in [-1.06,1.06]:static_box(p+Vector3(x,1.2,0),Vector3(.1,2.4,.12),"BulletinPost")
		static_box(p+Vector3(0,1.65,0),Vector3(2.5,1.4,.20),"BulletinBoard")
	for p in [Vector3(-36,.05,149),Vector3(29,.05,151.6),Vector3(31,.05,218.8)]:
		var bin=load("res://assets/campus_bin.glb").instantiate();world.add_child(bin);bin.position=p;style(bin);static_box(p+Vector3(0,.5,0),Vector3(.6,1,.5),"CampusBin")
	multimesh("bench",[placement(-27,.08,218.8,Vector3.ONE,PI),placement(27,.08,218.8,Vector3.ONE,PI)])
	for x in [-27,27]:
		static_box(Vector3(x,.60,218.8),Vector3(1.86,1.1,.6),"CourtyardBench")
		static_box(Vector3(x,.035,218.8),Vector3(4.5,.07,2.5),"CourtyardBenchPad")
	# Ordered parking pocket, away from the main axis and pedestrian story.
	for x in [55.0,56.1,57.2]:
		for z in [160.0,160.5]:box(Vector3(x,.38,z),Vector3(.05,.76,.05),mats.dark)
		box(Vector3(x,.76,160.25),Vector3(.05,.05,.55),mats.dark)
		static_box(Vector3(x,.4,160.25),Vector3(.12,.8,.65),"CycleRack")
	var title=Label3D.new();title.text="第一教学楼";title.position=Vector3(0,5.55,167.54);title.rotation.y=PI;title.font_size=64;title.pixel_size=.008;title.modulate=Color("ede0bb");title.outline_size=0;world.add_child(title)

func setup_environment():
	super.setup_environment()
	sun.rotation_degrees=Vector3(-49,-132,0);sun.light_energy=1.45;sun.light_angular_distance=1.4;sun.directional_shadow_max_distance=400
	for c in get_children():
		if c is WorldEnvironment:
			var e=c.environment;e.ambient_light_energy=.72;e.ambient_light_color=Color(.60,.65,.71)
			e.ssao_radius=2.3;e.ssao_intensity=2.4;e.ssao_power=1.6;e.ssil_intensity=.65;e.fog_enabled=false;e.tonemap_exposure=1.0

func setup_hud():
	super.setup_hud()
	for item in hud.find_children("*","Label",true,false):
		item.text=item.text.replace("夏末","春日").replace("东区 · 普通下午","东区 · 北门与双池").replace("艺术化复原 V0.1","Diorama 0.7 · 校园漫步")

func setup_life():
	life_layer=preload("res://scripts/scene_life.gd").new();life_layer.name="CampusLife";world.add_child(life_layer);life_layer.setup(self)
	wave2_layer=preload("res://scripts/wave2_life.gd").new();wave2_layer.name="CampusStories";world.add_child(wave2_layer);wave2_layer.setup(self)
	# A few original mesh petals, no imported effects or characters.
	for i in range(24):
		var petal=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=.045;mesh.height=.015;mesh.radial_segments=8;mesh.rings=4;petal.mesh=mesh
		petal.material_override=material(Color(.90,.67,.65));petal.position=Vector3(rng.randf_range(-8,8),rng.randf_range(1,7),rng.randf_range(121,146));petal.name="Petal";world.add_child(petal)

func _process(dt):
	super._process(dt)
	if sun:
		sun.rotation_degrees.y=-132+sin(elapsed*.012)*.28
		sun.light_energy=1.45+sin(elapsed*.045)*.012
	if not world:return
	for c in world.get_children():
		if c.name.begins_with("Petal"):
			c.position.y-=dt*.13;c.position.x+=sin(elapsed*.8+c.position.z)*dt*.07
			if c.position.y<.15:c.position.y=7

func viewpoint(i:int):
	if i>=13 and i<13+wave2_layer.spots().size():photo_spots[i]=wave2_layer.spots()[i-13]
	if not photo_spots[i].has("ortho"):return
	population_photo_index=i
	var close_view=i in [5,6,7,8,9,10,11,13,14,15,16,17,24]
	sun.directional_shadow_max_distance=70 if close_view else 600
	sun.light_angular_distance=.4 if close_view else 1.4;sun.shadow_blur=1.0 if close_view else 1.5
	var s=photo_spots[i];player.set_view(s.pos,s.target);player.free_camera=true
	player.camera.projection=Camera3D.PROJECTION_ORTHOGONAL if s.ortho else Camera3D.PROJECTION_PERSPECTIVE
	player.camera.size=s.size;player.camera.fov=s.fov
	if photo_camera:
		photo_camera.global_transform=player.camera.global_transform;photo_camera.projection=player.camera.projection;photo_camera.size=s.size;photo_camera.fov=s.fov
	spot_label.text=s.name+" · P 步行模式"

func _unhandled_input(e):
	super._unhandled_input(e)
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
		viewpoint(posmod(population_photo_index+(1 if e.keycode==KEY_BRACKETRIGHT else -1),photo_spots.size()))
	if e is InputEventKey and e.pressed and not e.echo and e.keycode>=KEY_6 and e.keycode<=KEY_9:viewpoint(e.keycode-KEY_1)
	if e is InputEventKey and e.pressed and not e.echo and e.keycode==KEY_0:viewpoint(9)
	if e is InputEventKey and e.pressed and not e.echo and e.keycode==KEY_L:
		if wave2_layer.has_method("toggle_routes"):wave2_layer.toggle_routes()
	if e is InputEventKey and e.pressed and e.keycode in [KEY_P,KEY_R,KEY_V]:
		sun.directional_shadow_max_distance=80
		player.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;player.camera.fov=64
		if e.keycode!=KEY_V:player.free_camera=false;player.set_view(Vector3(0,.16,12),Vector3(0,3,168))

func write_spots():
	var out=[]
	for s in photo_spots:
		out.append({"name":s.name,"feet":[s.pos.x,s.pos.y,s.pos.z],"target":[s.target.x,s.target.y,s.target.z],"fov":s.fov,"projection":"orthogonal" if s.get("ortho",false) else "perspective","size":s.get("size",0),"art_time":"spring 16:10","reason":s.reason})
	var f=FileAccess.open("res://../renders/life/photo_spots.json",FileAccess.WRITE);f.store_string(JSON.stringify(out,"\t"))

func wave2_profile():
	await preload("res://scripts/wave2_profile.gd").new().run(self)

func north_qa():
	await preload("res://scripts/north_axis_proof.gd").new().validate(self)

func north_motion():
	await preload("res://scripts/north_axis_proof.gd").new().capture_motion(self)

func run_capture():
	if "--north-capture" in OS.get_cmdline_user_args():
		await preload("res://scripts/north_axis_proof.gd").new().capture_stills(self)
		return
	if "--wave2-capture" in OS.get_cmdline_user_args():
		await preload("res://scripts/wave2_proof.gd").new().capture_stills(self)
		return
	if "--population-capture" in OS.get_cmdline_user_args():
		await preload("res://scripts/population_proof.gd").new().capture_stills(self)
		return
	await get_tree().create_timer(3).timeout
	if "--verify" in OS.get_cmdline_user_args():await verify_diorama()
	player.frozen=true;player.enabled=false;hud.visible=false
	var report={"scope":"Native rendering; not automatic art approval","resolution":"3840x2160" if photo_view else str(get_viewport().size),"tree_count":tree_count,"screenshots":[]}
	for i in range(photo_spots.size()):
		life_layer.manual_time=[6.0,6.0,5.0,10.0,14.0,3.0,7.0,12.0,12.0,9.6,30.0,12.0,6.0][i%13]
		viewpoint(i)
		for frame in range(60):await get_tree().process_frame
		await capture("life/hero_%02d"%(i+1))
		report.screenshots.append({"view":i+1,"fps":Engine.get_frames_per_second(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	var f=FileAccess.open("res://../renders/life/capture_report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("DIORAMA_CAPTURE_OK ",JSON.stringify(report));get_tree().quit()

func verify_diorama():
	var checks={}
	player.enabled=true;player.frozen=false
	var p=InputEventKey.new();p.pressed=true;p.keycode=KEY_P;_unhandled_input(p)
	checks.photo_to_walk=player.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and not player.free_camera
	player.set_view(Vector3(0,.16,127),Vector3(0,1.81,168))
	Input.action_press("forward");Input.action_press("jog")
	var grounded=0
	for i in range(410):
		await get_tree().physics_frame
		if player.is_on_floor():grounded+=1
	Input.action_release("forward");Input.action_release("jog")
	checks.axis_walk=player.position.z>151 and player.position.z<158
	checks.ground_contact=grounded>398
	Input.action_press("jump");await get_tree().physics_frame;await get_tree().physics_frame;Input.action_release("jump")
	var high=player.position.y
	for i in range(90):await get_tree().physics_frame;high=maxf(high,player.position.y)
	checks.jump_land=high>.65 and player.is_on_floor()
	player.set_view(Vector3(0,.16,161),Vector3(0,1.81,175));Input.action_press("forward")
	for i in range(300):await get_tree().physics_frame
	Input.action_release("forward");checks.entrance_collision=player.position.z<167.3 and player.position.z>165
	var yaw=player.rotation.y;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var motion=InputEventMouseMotion.new();motion.relative=Vector2(50,0);player._unhandled_input(motion)
	checks.mouse_look=abs(player.rotation.y-yaw)>.03
	p.keycode=KEY_ESCAPE;player._unhandled_input(p);checks.escape=Input.mouse_mode==Input.MOUSE_MODE_VISIBLE
	viewpoint(0);checks.orthogonal_photo=player.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and player.free_camera
	viewpoint(1);checks.perspective_photo=player.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and player.free_camera
	var passed=true
	for k in checks:passed=passed and checks[k]
	var f=FileAccess.open("res://../renders/life/validation.json",FileAccess.WRITE);f.store_string(JSON.stringify({"scope":"Diorama controller regression","passed":passed,"checks":checks},"\t"));f.close()
	print("DIORAMA_CONTROLS ",checks)
	if not passed:push_error("Diorama controller regression failed")


func block_water(poly:PackedVector2Array):
	var triangles=Geometry2D.triangulate_polygon(poly)
	var body=StaticBody3D.new();body.name="Water_NoEntry";world.add_child(body)
	for i in range(0,triangles.size(),3):
		var points=PackedVector3Array()
		for j in range(3):
			var p=poly[triangles[i+j]];points.append(Vector3(p.x,-.6,p.y));points.append(Vector3(p.x,3.0,p.y))
		var shape=ConvexPolygonShape3D.new();shape.points=points
		var node=CollisionShape3D.new();node.shape=shape;body.add_child(node)

func in_building(p:Vector2)->bool:
	return (absf(p.x)<62 and p.y>168 and p.y<184) or (absf(p.x)>48 and absf(p.x)<62 and p.y>180 and p.y<222) or (absf(p.x)<15.5 and p.y>180 and p.y<189.4)

func audit_ground(quit_after=true):
	player.frozen=true
	await get_tree().physics_frame
	var report={"scope":"All-land ray grid and actual grass traversal","samples":0,"missing":[],"routes":[],"checks":{}}
	var space=get_world_3d().direct_space_state
	for x in range(-78,79,4):
		for z in range(120,237,4):
			var p=Vector2(x,z)
			if pond_at(p) or in_building(p):continue
			var q=PhysicsRayQueryParameters3D.create(Vector3(x,.5,z),Vector3(x,-1.5,z));q.exclude=[player.get_rid()]
			var hit=space.intersect_ray(q);report.samples+=1
			if hit.is_empty():report.missing.append([x,z])
	report.checks.land_grid=report.missing.is_empty()
	player.enabled=true;player.free_camera=false;player.frozen=false
	for route in [[Vector2(0,140),Vector2(-25,140)],[Vector2(0,140),Vector2(25,140)],[Vector2(0,211),Vector2(30,211)],[Vector2(20,233),Vector2(-20,233)],[Vector2(-74,188),Vector2(-74,219)],[Vector2(22,159),Vector2(22,140)],[Vector2(0,127),Vector2(0,108)],[Vector2(-5.3,112),Vector2(-5.3,126)]]:
		var start=route[0];var end=route[1];player.set_view(Vector3(start.x,.20,start.y),Vector3(end.x,1.85,end.y))
		Input.action_press("forward");Input.action_press("jog");var frames=0;var min_y=1.0
		while Vector2(player.position.x,player.position.z).distance_to(end)>.35 and frames<1000:
			await get_tree().physics_frame;frames+=1;min_y=minf(min_y,player.position.y)
		Input.action_release("forward");Input.action_release("jog")
		var passed=Vector2(player.position.x,player.position.z).distance_to(end)<.5 and min_y>-.10
		report.routes.append({"start":str(start),"target":str(end),"end":str(player.position),"minimum_y":min_y,"passed":passed})
		report.checks["grass_route_%d"%report.routes.size()]=passed
	# Water and outside bounds must remain blocked, not merely supported by the slab.
	for test in [[Vector3(45,.2,135),Vector3(45,1.85,118),"water_blocked",129.0],[Vector3(78,.2,228),Vector3(90,1.85,228),"boundary_blocked",79.8]]:
		player.set_view(test[0],test[1]);Input.action_press("forward");Input.action_press("jog")
		for i in range(250):await get_tree().physics_frame
		Input.action_release("forward");Input.action_release("jog")
		report.checks[test[2]]=not pond_at(Vector2(player.position.x,player.position.z)) if test[2]=="water_blocked" else player.position.x<79.8
	var passed=true
	for key in report.checks:passed=passed and report.checks[key]
	report.passed=passed
	var f=FileAccess.open("res://../renders/life/ground_validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("GROUND_VALIDATION ",JSON.stringify(report))
	if quit_after:get_tree().quit(0 if passed else 1)
	return passed

func verify_life()->Dictionary:
	var snapshots=[];var finite=true;var on_land=true
	for t in [0.0,3.0,7.0,10.0,13.0,16.0,24.0,30.0,39.0,46.0]:
		life_layer.pose(t);life_layer.time=t;snapshots.append(life_layer.snapshot())
		var p=life_layer.actors.reader.root.position
		finite=finite and p.is_finite();on_land=on_land and not pond_at(Vector2(p.x,p.z)) and not in_building(Vector2(p.x,p.z))
	var report={"scope":"Procedural life state coverage","passed":finite and on_land,"students":6,"cats":1,"birds":2,"samples":snapshots}
	var f=FileAccess.open("res://../renders/life/life_validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();return report

func population_qa():
	await preload("res://scripts/population_proof.gd").new().validate(self)

func wave2_qa():
	await preload("res://scripts/wave2_proof.gd").new().validate(self)

func wave2_motion():
	await preload("res://scripts/wave2_proof.gd").new().capture_motion(self)

func population_motion():
	await preload("res://scripts/population_proof.gd").new().capture_motion(self)

func population_profile():
	await preload("res://scripts/population_profile.gd").new().run(self)

func capture_motion():
	player.enabled=false;player.frozen=true;hud.visible=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	photo_view=SubViewport.new();photo_view.name="Life_Motion_1280";photo_view.size=Vector2i(1280,720);photo_view.world_3d=get_viewport().world_3d
	photo_view.msaa_3d=Viewport.MSAA_4X;photo_view.use_taa=true;photo_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(photo_view)
	photo_camera=Camera3D.new();photo_camera.near=.075;photo_camera.far=850;photo_view.add_child(photo_camera);photo_camera.current=true;get_viewport().disable_3d=true
	var directory=ProjectSettings.globalize_path("res://../renders/life/motion_frames");DirAccess.make_dir_recursive_absolute(directory)
	var clips=[[5,12.0,3.0,"写题与思考"],[8,7.0,4.0,"慢走与背资料"],[6,6.0,0.0,"举起手机"],[7,5.0,9.0,"猫的午后"]]
	var manifest={"width":1280,"height":720,"fps":20,"source":"Godot viewport frames, no generated animation","clips":[]};var frame_index=0
	for clip in clips:
		viewpoint(clip[0]);life_layer.manual_time=clip[2]
		for warm in range(24):await get_tree().process_frame
		var start_frame=frame_index
		for i in range(int(clip[1]*20)):
			life_layer.manual_time=clip[2]+i/20.0;life_layer.pose(life_layer.manual_time)
			await RenderingServer.frame_post_draw
			var im=photo_view.get_texture().get_image();im.save_jpg(directory+"/frame_%05d.jpg"%frame_index,.94);frame_index+=1
		manifest.clips.append({"name":clip[3],"start_frame":start_frame,"frames":frame_index-start_frame,"pose_start":clip[2]})
		print("MOTION_CLIP ",clip[3]," frames=",frame_index-start_frame)
	manifest.frames=frame_index
	var f=FileAccess.open("res://../renders/life/motion_manifest.json",FileAccess.WRITE);f.store_string(JSON.stringify(manifest,"\t"));f.close();verify_life();print("MOTION_CAPTURE_OK ",frame_index);get_tree().quit()
