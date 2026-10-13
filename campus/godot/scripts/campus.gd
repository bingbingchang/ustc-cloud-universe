extends Node3D

const Walker=preload("res://scripts/player.gd")
const ArtShader=preload("res://shaders/academic.gdshader")
var site:Dictionary
var world:Node3D
var player:CharacterBody3D
var rng=RandomNumberGenerator.new()
var mats={}
var art_mats:Array[ShaderMaterial]=[]
var locator:CanvasLayer
var original_mats={}
var asset_cache={}
var ponds:Array[PackedVector2Array]=[]
var hud:CanvasLayer
var mode_label:Label
var spot_label:Label
var map_panel:Control
var sun:DirectionalLight3D
var gray=false
var capture_mode=false
var tree_count=0
var instance_count=0
var birds:Array[Node3D]=[]
var walkers:Array[Node3D]=[]
var elapsed=0.0
var lookdev_mode=false
var photo_view:SubViewport
var photo_camera:Camera3D
var photo_spots=[
	{"name":"01 · 玉泉树影","pos":Vector3(-1,.12,105),"target":Vector3(0,8.0,177),"fov":62.0,"reason":"樱花树冠框景，轴线消失点落在一教，保留树影与人的尺度"},
	{"name":"02 · 天光一鉴","pos":Vector3(8,.14,92),"target":Vector3(42.5,2.8,80.8),"fov":51.0,"reason":"荷叶前景、折桥中景、红瓦亭与专家楼形成深度"},
	{"name":"03 · 老门长夏","pos":Vector3(2,.14,28),"target":Vector3(0,3.5,0),"fov":62.0,"reason":"沿树荫向北回望，紫藤与浅色门梁构成记忆入口"},
	{"name":"04 · 红砖与梧桐","pos":Vector3(-40,.14,155),"target":Vector3(-2,7,170),"fov":65.0,"reason":"一教横向体量、窄窗节奏、自行车与阔叶树形成校园近景"},
	{"name":"05 · 双池之间","pos":Vector3(-102,91,-37),"target":Vector3(6,0,105),"fov":56.0,"reason":"仅用于空间核查：老门、双湖、U形一教与周边道路关系"}
]

func _ready():
	rng.seed=1958
	lookdev_mode=use_lookdev()
	if "--ultra" in OS.get_cmdline_user_args():
		get_viewport().msaa_3d=Viewport.MSAA_8X
		RenderingServer.directional_shadow_atlas_set_size(8192,true)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
		RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_ULTRA,false,.5,4,80,300)
		RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_ULTRA,false,.5,4,80,300)
	if lookdev_mode:
		photo_spots=[
			{"name":"01 · 玉泉树影","pos":Vector3(-1,.12,105),"target":Vector3(0,8,177),"fov":62.0,"reason":"保持V0.1同机位，用来检验造型与光照提升"},
			{"name":"02 · 池畔云光","pos":Vector3(8,.14,92),"target":Vector3(42.5,2.8,80.8),"fov":51.0,"reason":"保持湖畔同机位，比较植被、屋顶和水面反射"},
			{"name":"03 · 老门长夏","pos":Vector3(1.3,.14,22),"target":Vector3(0,4.0,0),"fov":56.0,"reason":"门梁与树冠形成框景，校名是视觉主角"},
			{"name":"04 · 红砖与梧桐","pos":Vector3(-28,.14,149),"target":Vector3(2,6.5,170),"fov":58.0,"reason":"建筑凹窗与入口前场，路缘树影引导视线"},
			{"name":"05 · 一鉴清风","pos":Vector3(27,.44,76),"target":Vector3(42.5,3.4,80.8),"fov":56.0,"reason":"折桥引向亭子，检验近景材质和檐口"}]
	capture_mode="--capture" in OS.get_cmdline_user_args() or "--verify" in OS.get_cmdline_user_args()
	site=JSON.parse_string(FileAccess.get_file_as_string("res://assets/site.json"))
	for p in site.ponds:
		var poly=PackedVector2Array()
		for v in p.outline:poly.append(Vector2(v[0],v[1]))
		ponds.append(poly)
	setup_input()
	world=Node3D.new();world.name="North_Axis_Art_World";add_child(world)
	setup_materials()
	terrain()
	paths()
	load_art("architecture")
	load_art("background")
	load_art("sitedetail")
	build_collisions()
	planting()
	furniture()
	setup_environment()
	setup_life()
	player=create_player();add_child(player)
	if capture_mode and "--ultra" in OS.get_cmdline_user_args():
		photo_view=SubViewport.new();photo_view.name="Native_4K_Photography";photo_view.size=Vector2i(3840,2160);photo_view.world_3d=get_viewport().world_3d
		photo_view.msaa_3d=Viewport.MSAA_8X;photo_view.use_taa=true;photo_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(photo_view)
		photo_camera=Camera3D.new();photo_camera.near=.075;photo_camera.far=850;photo_view.add_child(photo_camera);photo_camera.current=true
		get_viewport().disable_3d=true
	setup_hud()
	locator=preload("res://scripts/scene_locator.gd").new();locator.campus=self
	if photo_view:photo_view.add_child(locator)
	else:add_child(locator)
	if lookdev_mode and not capture_mode:viewpoint(0)
	write_spots()
	print("CAMPUS_READY trees=",tree_count," instances=",instance_count)
	if capture_mode:
		player.enabled=false;player.frozen=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		call_deferred("run_capture")
	if "--bake" in OS.get_cmdline_user_args():call_deferred("bake")

func use_lookdev()->bool:
	return "--lookdev" in OS.get_cmdline_user_args()

func create_player()->CharacterBody3D:
	return Walker.new()

func setup_input():
	var b={"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"jog":KEY_SHIFT,"jump":KEY_SPACE,"up":KEY_E,"down":KEY_Q}
	for k in b:
		InputMap.add_action(k);var e=InputEventKey.new();e.physical_keycode=b[k];InputMap.action_add_event(k,e)

func material(c:Color,fol=0.0,g=0.0,br=0.0)->ShaderMaterial:
	var m=ShaderMaterial.new();m.shader=ArtShader;m.set_shader_parameter("base_color",c)
	m.set_shader_parameter("foliage",fol);m.set_shader_parameter("ground",g);m.set_shader_parameter("brick",br)
	art_mats.append(m);return m

func surface(m:ShaderMaterial,kind:String,meters:Vector2):
	m.set_shader_parameter("mapped",true);m.set_shader_parameter("base_color",Color.WHITE);m.set_shader_parameter("tile_meters",meters)
	for pair in [["surface_color","albedo"],["surface_normal","normal"],["surface_orm","orm"]]:
		m.set_shader_parameter(pair[0],load("res://assets/textures/"+kind+"_"+pair[1]+".png"))

func asset_material(key:String,c:Color)->ShaderMaterial:
	if original_mats.has(key):return original_mats[key]
	var m:ShaderMaterial
	if key in ["TikuSweater","TikuUniformBlue"]:
		m=ShaderMaterial.new();m.shader=preload("res://shaders/tiku_cloth.gdshader");m.set_shader_parameter("base_color",c)
	elif "Glass" in key:
		m=ShaderMaterial.new();m.shader=preload("res://shaders/glass.gdshader");art_mats.append(m)
	else:
		m=material(c,1 if "Leaf" in key else 0)
		if "Brick" in key:surface(m,"brick",Vector2(4,2))
		elif key in ["Stone","Plaster"]:surface(m,"stone",Vector2(2,2))
		elif key=="Trunk":surface(m,"bark",Vector2(1.2,3))
		elif key=="Wood":surface(m,"wood",Vector2(.7,2))
	original_mats[key]=m;return m

func setup_materials():
	mats.grass=material(Color("6c8740"))
	mats.path=material(Color("b2b2a0"),0,1)
	mats.road=material(Color("777e78"),0,1)
	mats.stone=material(Color("c3bca1"))
	mats.dark=material(Color("404e46"))
	mats.white=material(Color("ebe6cd"))
	mats.water=ShaderMaterial.new();mats.water.shader=preload("res://shaders/water.gdshader")
	surface(mats.grass,"grass",Vector2(16,16));surface(mats.path,"paving",Vector2(4.5,6));surface(mats.road,"paving",Vector2(4.5,6));surface(mats.stone,"stone",Vector2(2,2))
	mats.road.set_shader_parameter("base_color",Color(.76,.79,.78))

func style(n:Node):
	if n is MeshInstance3D:
		for s in n.mesh.get_surface_count():
			var old=n.mesh.surface_get_material(s)
			if old is StandardMaterial3D:
				var key=old.resource_name
				if key=="TikuFace":
					var face=ShaderMaterial.new();face.shader=preload("res://shaders/tiku_face.gdshader")
					face.set_shader_parameter("face_albedo",load("res://assets/textures/tiku_face_albedo.png"))
					n.set_surface_override_material(s,face)
				else:n.set_surface_override_material(s,asset_material(key,old.albedo_color))
	for ch in n.get_children():style(ch)

func load_art(asset:String):
	var n=load("res://assets/"+asset+".glb").instantiate()
	n.name=asset.capitalize();world.add_child(n);style(n)
	if asset=="background":
		for c in n.get_children():
			if c is GeometryInstance3D:c.visibility_range_end=650

func static_box(p:Vector3,s:Vector3,node_name="Collider"):
	var b=StaticBody3D.new();b.name=node_name;b.position=p;world.add_child(b)
	var cs=CollisionShape3D.new();var sh=BoxShape3D.new();sh.size=s;cs.shape=sh;b.add_child(cs)
	return b

func box(p:Vector3,s:Vector3,mat:Material,collision=false):
	var mi=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=s;mi.mesh=mesh;mi.material_override=mat;mi.position=p;world.add_child(mi)
	if collision:static_box(p,s)
	return mi

func strip(a:Vector2,b:Vector2,width:float,height:float,mat:Material,collision=false):
	var mid=(a+b)*.5;var len=a.distance_to(b)
	var n=box(Vector3(mid.x,height,mid.y),Vector3(width,.08,len),mat)
	n.rotation.y=atan2(b.x-a.x,b.y-a.y)
	if collision:
		var cb=static_box(Vector3(mid.x,height,mid.y),Vector3(width,.14,len));cb.rotation.y=n.rotation.y
	return n

func poly_mesh(poly:PackedVector2Array,y:float,mat:Material):
	var tri=Geometry2D.triangulate_polygon(poly)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,tri.size(),3):
		var a=poly[tri[i]];var b=poly[tri[i+1]];var c=poly[tri[i+2]]
		var vs=[Vector3(a.x,y,a.y),Vector3(b.x,y,b.y),Vector3(c.x,y,c.y)]
		if (vs[1]-vs[0]).cross(vs[2]-vs[0]).y<0:vs.reverse()
		for v in vs:st.set_normal(Vector3.UP);st.add_vertex(v)
	var mi=MeshInstance3D.new();mi.mesh=st.commit();mi.material_override=mat;world.add_child(mi);return mi

func pond_at(p:Vector2)->bool:
	for poly in ponds:
		if Geometry2D.is_point_in_polygon(p,poly):return true
	return false

func terrain():
	# Actual basin topography; continuous collision derived from the same mesh.
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step=2.0
	for x in range(-125,211,2):
		for z in range(-70,281,2):
			var vs=[]
			for p in [Vector2(x,z),Vector2(x+step,z),Vector2(x+step,z+step),Vector2(x,z+step)]:
				var y=-1.1 if pond_at(p) else -.045
				vs.append(Vector3(p.x,y,p.y))
			for i in [0,2,1,0,3,2]:st.add_vertex(vs[i])
	st.generate_normals();var mi=MeshInstance3D.new();mi.name="Terrain_Basins";mi.mesh=st.commit();mi.material_override=mats.grass;world.add_child(mi);mi.create_trimesh_collision()
	for poly in ponds:
		poly_mesh(poly,-.32,mats.water)
		for i in poly.size():
			var a=poly[i];var b=poly[(i+1)%poly.size()]
			strip(a,b,.75,-.025,mats.stone)
			# Retaining edge doubles as low water-entry blocker; not invisible tall walls.
			var len=a.distance_to(b);var mid=(a+b)*.5
			var n=box(Vector3(mid.x,-.22,mid.y),Vector3(.48,.62,len+.08),mats.stone)
			n.rotation.y=atan2(b.x-a.x,b.y-a.y)
			var cb=static_box(Vector3(mid.x,-.06,mid.y),Vector3(.48,.88,len+.08),"PondRetainingWall");cb.rotation.y=n.rotation.y
	# Walkable site bounds, visually screened with shrubs and hedges.
	for p in [Vector3(-124,1,105),Vector3(209,1,105)]:static_box(p,Vector3(1,3,351),"SampleBoundary")
	for p in [Vector3(42,1,-69),Vector3(42,1,279)]:static_box(p,Vector3(336,3,1),"SampleBoundary")

func paths():
	strip(Vector2(0,-25),Vector2(0,163),8,.022,mats.path,true)
	for x in [-4.2,4.2]:strip(Vector2(x,-18),Vector2(x,152),.22,.03,mats.stone)
	strip(Vector2(-81,152),Vector2(103,152),6,.022,mats.road,true)
	strip(Vector2(-72,142),Vector2(-72,237),5,.022,mats.road,true)
	strip(Vector2(73,26),Vector2(73,243),5,.022,mats.road,true)
	strip(Vector2(-81,232),Vector2(140,232),6,.025,mats.road,true)
	# Broad forecourt immediately before the teaching hall; narrow secondary routes.
	box(Vector3(0,.015,160),Vector3(123,.09,11),mats.path,true)
	strip(Vector2(0,221),Vector2(0,264),6,.02,mats.path,true)
	strip(Vector2(6,40),Vector2(38,42),3,.035,mats.path,true)
	strip(Vector2(6,64),Vector2(12,64),3,.16,mats.path,true)
	strip(Vector2(7,135),Vector2(72,132),2.5,.02,mats.path,true)
	strip(Vector2(-7,60),Vector2(-58,64),2.0,.015,mats.path,true)
	strip(Vector2(-64,69),Vector2(-64,139),2.2,.02,mats.path,true)
	# A few pale transverse pedestrian stripes where the axis crosses Hanhai Road.
	for z in range(150,155):box(Vector3(0,.071,z),Vector3(5,.01,.45),mats.white)

func build_collisions():
	static_box(Vector3(0,8.5,176),Vector3(124,17,16),"TeachingHallNorth")
	for x in [-55,55]:static_box(Vector3(x,8.5,201),Vector3(14,17,42),"TeachingHallWing")
	static_box(Vector3(0,8.5,183.8),Vector3(31,17,11),"TeachingHallCenter")
	for x in [-9.5,-5.6,5.6,9.5]:static_box(Vector3(x,2.9,0),Vector3(1.1,5.8,1.65),"OldGatePier")
	var p=site.pavilion;static_box(Vector3(p[0],.10,p[1]),Vector3(6.8,.56,6.8),"PavilionPlatform")
	var br=site.bridge
	for i in range(br.size()-1):
		var a=Vector2(br[i][0],br[i][1]);var b=Vector2(br[i+1][0],br[i+1][1]);var mid=(a+b)*.5
		var body=static_box(Vector3(mid.x,.28,mid.y),Vector3(2.6,.30,a.distance_to(b)+.2),"BridgeDeck");body.rotation.y=atan2(b.x-a.x,b.y-a.y)
		var perp=(b-a).normalized().orthogonal()*1.24
		for sign_v in [-1,1]:
			var pt=mid+perp*sign_v
			var rail=static_box(Vector3(pt.x,.90,pt.y),Vector3(.16,.96,a.distance_to(b)),"BridgeRail");rail.rotation.y=body.rotation.y
	for it in site.background:
		var outline=it.outline
		for i in range(outline.size()-1):
			var a=Vector2(outline[i][0],outline[i][1]);var b=Vector2(outline[i+1][0],outline[i+1][1]);var mid=(a+b)*.5
			var cb=static_box(Vector3(mid.x,it.height/2,mid.y),Vector3(.35,it.height,a.distance_to(b)),"BackgroundWall");cb.rotation.y=atan2(b.x-a.x,b.y-a.y)

func asset_parts(n:Node,t:Transform3D,parts:Array):
	if n is Node3D:t=t*n.transform
	if n is MeshInstance3D:parts.append({"mesh":n.mesh,"transform":t})
	for c in n.get_children():asset_parts(c,t,parts)

func multimesh(asset:String,transforms:Array):
	if asset in ["tree0","tree1","tree2"]:
		for variant in range(3):
			var batch=[]
			for i in range(transforms.size()):
				if i%3==variant:batch.append(transforms[i])
			multimesh_batch(asset+["","b","c"][variant],batch)
	else:multimesh_batch(asset,transforms)

func multimesh_batch(asset:String,transforms:Array):
	if transforms.is_empty():return
	if not asset_cache.has(asset):
		var n=load("res://assets/"+asset+".glb").instantiate();var parts=[];asset_parts(n,Transform3D.IDENTITY,parts);asset_cache[asset]=parts;n.free()
	var part_index=0
	for part in asset_cache[asset]:
		# One draw batch per source surface so each palette material survives.
		var mesh:Mesh=part.mesh
		for s in mesh.get_surface_count():
			var old=mesh.surface_get_material(s);var key=old.resource_name if old else "Leaf"
			var ar=render_batch_mesh(asset,part_index,s,mesh,key,old.albedo_color if old else Color(.3,.5,.2))
			for group in render_instance_groups(asset,transforms):
				var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=ar;mm.instance_count=group.size()
				for i in group.size():mm.set_instance_transform(i,group[i]*part.transform)
				var mi=MultiMeshInstance3D.new();mi.name=asset+"_"+key;mi.multimesh=mm;mi.set_meta("render_asset",asset);world.add_child(mi)
				mi.visibility_range_end=370 if asset.begins_with("tree") else 170
				mi.visibility_range_end_margin=15
		part_index+=1
	instance_count+=transforms.size()

func render_instance_groups(_asset:String,transforms:Array)->Array:return [transforms]

func render_batch_mesh(_asset:String,_part:int,s:int,mesh:Mesh,key:String,color:Color)->ArrayMesh:
	var ar=ArrayMesh.new();ar.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(s))
	ar.surface_set_material(0,asset_material(key,color));return ar

func placement(x:float,y:float,z:float,scale_v:Vector3=Vector3.ONE,angle:float=0)->Transform3D:
	return Transform3D(Basis(Vector3.UP,angle).scaled(scale_v),Vector3(x,y,z))

func safe_tree(p:Vector2)->bool:
	if pond_at(p):return false
	if absf(p.x)<6.0 and p.y<164:return false
	if p.y>145 and p.y<166:return false
	if absf(p.x)>69 and absf(p.x)<77:return false
	if p.y>163 and p.y<224 and absf(p.x)<64:return false
	for b in site.background:
		var poly=PackedVector2Array()
		for v in b.outline:poly.append(Vector2(v[0],v[1]))
		if Geometry2D.is_point_in_polygon(p,poly):return false
	return true

func planting():
	var ts=[[],[],[]]
	# Two low cherry rows defining the recognizable avenue, plus taller framing trees.
	for side in [-1,1]:
		for i in range(19):
			var z=6.0+i*7.45;var sc=rng.randf_range(.76,1.0)
			var x=side*(7.15+rng.randf_range(-.25,.25))
			ts[0].append(placement(x,0,z,Vector3(sc,sc,sc),rng.randf()*TAU))
			static_box(Vector3(x,1,z),Vector3(.45,2,.45),"CherryTrunk")
		for i in range(11):
			var z=14+i*12.7;var x=side*(side+1+12.0)
			if safe_tree(Vector2(x,z)):ts[1].append(placement(x,0,z,Vector3.ONE*rng.randf_range(.95,1.2),rng.randf()*TAU))
	for i in range(235):
		var p=Vector2(rng.randf_range(-112,185),rng.randf_range(-42,265))
		if not safe_tree(p):continue
		var type=i%3;var sc=rng.randf_range(.85,1.35)
		ts[type].append(placement(p.x,0,p.y,Vector3(sc,sc,sc),rng.randf()*TAU))
		static_box(Vector3(p.x,1,p.y),Vector3(.5,2,.5),"ShadeTreeTrunk")
	# Deliberate plane-tree rows along first teaching building, not random scattering.
	for x in range(-55,60,14):
		if abs(x)<8:continue
		ts[1].append(placement(x,0,145,Vector3.ONE*1.0,.4+x))
	# A continuous canopy screens background buildings around the east lake.
	for pos in [Vector2(17,51),Vector2(27,50),Vector2(40,48),Vector2(53,51),Vector2(64,57),Vector2(70,71),Vector2(69,85),Vector2(70,99),Vector2(67,116),Vector2(58,133),Vector2(44,134),Vector2(29,136),Vector2(-58,67),Vector2(-65,85),Vector2(-68,101),Vector2(-63,124)]:
		if safe_tree(pos):ts[1].append(placement(pos.x,0,pos.y,Vector3.ONE*1.15,rng.randf()*TAU))
	for z in range(55,140,9):
		for x in [81,90]:ts[1].append(placement(x,0,z,Vector3.ONE*rng.randf_range(1.12,1.45),rng.randf()*TAU))
	for x in range(-100,195,10):
		for z in [-40,-29,267]:
			if safe_tree(Vector2(x,z)):ts[1].append(placement(x,0,z,Vector3.ONE*1.25,rng.randf()*TAU))
	for z in range(20,143,10):
		if safe_tree(Vector2(-79,z)):ts[1].append(placement(-79,0,z,Vector3.ONE*1.3,rng.randf()*TAU))
	for k in range(3):multimesh("tree"+str(k),ts[k]);tree_count+=ts[k].size()
	# Vine clusters laid horizontally over the old gate. Reuse authored leaf mesh parts only.
	var vines=[]
	for x in range(-10,11,2):vines.append(placement(x,5.4,0,Vector3(.43,.17,.38),x))
	var vine_parts=[];var src=load("res://assets/tree0.glb").instantiate();asset_parts(src,Transform3D.IDENTITY,vine_parts);src.free()
	asset_cache.vine=vine_parts.filter(func(p):return p.mesh.surface_get_material(0).resource_name.begins_with("Leaf"))
	multimesh("vine",vines)
	var lotus=[];var rocks=[];var grass=[]
	for pi in range(ponds.size()):
		var poly=ponds[pi]
		for i in range(11000):
			var p=Vector2(rng.randf_range(-75,68),rng.randf_range(54,138))
			if Geometry2D.is_point_in_polygon(p,poly) and sin(p.x*.16+p.y*.08)>-.35:
				lotus.append(placement(p.x,-.23,p.y,Vector3.ONE*rng.randf_range(1.0,1.8),rng.randf()*TAU))
		for i in range(poly.size()):
			var p=poly[i]
			if i%3==0:rocks.append(placement(p.x,-.03,p.y,Vector3.ONE*rng.randf_range(.5,1.3),rng.randf()*TAU))
	for i in range(3800):
		var p=Vector2(rng.randf_range(-105,155),rng.randf_range(-25,260))
		if safe_tree(p) and not (absf(p.y-232)<5):grass.append(placement(p.x,.02,p.y,Vector3.ONE*rng.randf_range(.7,1.25),rng.randf()*TAU))
	multimesh("lotus",lotus);multimesh("rock",rocks);multimesh("grass",grass)
	# Understory shrubs use the small leafy crown batches, sunk down to shrub height.
	var shrubs=[]
	for i in range(82):
		var p=Vector2(rng.randf_range(-100,144),rng.randf_range(8,247))
		if safe_tree(p):shrubs.append(placement(p.x,-1.1,p.y,Vector3(.4,.25,.4),rng.randf()*TAU))
	var border=[]
	for z in range(57,129,3):
		for x in [67,69]:border.append(placement(x+rng.randf_range(-.3,.3),0,z,Vector3.ONE*rng.randf_range(1.0,1.6),rng.randf()*TAU))
	for x in range(20,62,3):border.append(placement(x,0,135,Vector3.ONE*rng.randf_range(.7,1.1),rng.randf()*TAU))
	for z in [24,49,132,144]:
		for side in [-1,1]:
			for i in range(3):border.append(placement(side*(8.4+i*1.4),0,z+1,Vector3.ONE*rng.randf_range(.6,.85),rng.randf()*TAU))
	multimesh("shrub",border)

func furniture():
	var benches=[];var lamps=[];var bikes=[]
	for z in [24,49,132,144]:
		for side in [-1,1]:
			benches.append(placement(side*5.25,0,z,Vector3.ONE,side*PI/2))
			static_box(Vector3(side*5.25,.52,z),Vector3(.65,1.04,1.9),"BenchBlocker")
	for z in range(16,151,24):
		for side in [-1,1]:lamps.append(placement(side*4.7,0,z,Vector3.ONE,-side*PI/2))
	for i in range(14):bikes.append(placement(-32+i*1.15,.03,165,Vector3.ONE,.9))
	for i in range(5):bikes.append(placement(8+i*1.1,.03,22,Vector3.ONE,.9))
	multimesh("bench",benches);multimesh("lamp",lamps);multimesh("bicycle",bikes)
	signpost(Vector3(5.3,0,30),"玉泉北路","Y U Q U A N   R O A D")
	signpost(Vector3(9,0,113),"眼镜湖 · 一鉴亭","S P E C T A C L E S   P O N D")

func signpost(p:Vector3,title:String,sub:String):
	box(p+Vector3(0,.8,0),Vector3(.08,1.6,.08),mats.dark)
	box(p+Vector3(0,1.46,0),Vector3(2.2,.78,.10),mats.dark)
	var label=Label3D.new();label.text=title+"\n"+sub;label.font_size=38;label.pixel_size=.0045;label.position=p+Vector3(0,1.48,-.065);label.rotation.y=PI
	var font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"]);label.font=font
	label.modulate=Color("eae4c8");label.outline_size=0;world.add_child(label)

func setup_environment():
	sun=DirectionalLight3D.new();sun.name="Afternoon_1610";sun.rotation_degrees=Vector3(-36,-128,0);sun.light_color=Color(1,.95,.85);sun.light_energy=1.85
	sun.shadow_enabled=true;sun.directional_shadow_max_distance=230;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS;sun.shadow_blur=1.5;sun.shadow_bias=.045;add_child(sun)
	var we=WorldEnvironment.new();var e=Environment.new();var sk=Sky.new();var sm=ShaderMaterial.new();sm.shader=preload("res://shaders/campus_sky.gdshader");sk.sky_material=sm
	sm.set_shader_parameter("panorama",load("res://assets/textures/academic_sky_v2.png"))
	sk.radiance_size=Sky.RADIANCE_SIZE_256;sk.process_mode=Sky.PROCESS_MODE_REALTIME
	e.background_mode=Environment.BG_SKY;e.sky=sk
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(.53,.58,.61);e.ambient_light_energy=.60;e.ambient_light_sky_contribution=.18
	e.reflected_light_source=0
	e.tonemap_mode=Environment.TONE_MAPPER_ACES;e.tonemap_exposure=.95
	e.ssao_enabled=true;e.ssao_radius=1.3;e.ssao_intensity=1.4;e.ssao_power=1.25;e.ssao_detail=.4
	e.ssil_enabled=true;e.ssil_radius=3.5;e.ssil_intensity=.65
	e.ssr_enabled=true;e.ssr_max_steps=48;e.ssr_fade_in=.15;e.ssr_fade_out=2.0
	e.fog_enabled=true;e.fog_light_color=Color(.64,.73,.77);e.fog_density=.00055;e.fog_sky_affect=.0
	e.glow_enabled=true;e.glow_intensity=.08;e.glow_bloom=.0
	we.environment=e;add_child(we)
	for p in [Vector3(0,9,144),Vector3(36,7,85)]:
		var probe=ReflectionProbe.new();probe.position=p;probe.size=Vector3(150,45,135);probe.origin_offset=Vector3(0,0,0);probe.box_projection=true;probe.max_distance=200;probe.intensity=1.0;probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED;probe.enable_shadows=true;add_child(probe)

func setup_life():
	# Six quiet distant bird silhouettes; procedural wing motion.
	for i in range(6):
		var b=Node3D.new();b.name="Bird";world.add_child(b)
		for side in [-1,1]:
			var wing=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=Vector3(.34,.018,.1);wing.mesh=mesh;wing.material_override=mats.dark;wing.position.x=side*.15;b.add_child(wing)
		birds.append(b)
	if ResourceLoader.exists("res://assets/campus_ambience.wav"):
		var a=AudioStreamPlayer.new();a.stream=load("res://assets/campus_ambience.wav");a.stream.loop_end=int(a.stream.get_length()*a.stream.mix_rate);a.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;a.volume_db=-16;add_child(a);a.play()
	# People deferred until a suitable authored character exists; keep the quiet campus uncluttered.
	for i in range(0):
		var person=Node3D.new();person.name="Student"+str(i);world.add_child(person);walkers.append(person)
		var shirt=material([Color("e4dfbe"),Color("79968e"),Color("a59b86")][i]);var pants=material(Color("34494d"));var skin=material(Color("b99c7f"))
		for spec in [[Vector3(0,1.14,0),Vector3(.39,.59,.23),shirt],[Vector3(0,1.61,0),Vector3(.23,.28,.23),skin],[Vector3(0,1.73,.015),Vector3(.24,.10,.24),mats.dark],[Vector3(-.12,.47,0),Vector3(.14,.84,.17),pants],[Vector3(.12,.47,0),Vector3(.14,.84,.17),pants],[Vector3(-.28,1.10,0),Vector3(.12,.59,.13),shirt],[Vector3(.28,1.10,0),Vector3(.12,.59,.13),shirt],[Vector3(0,1.13,.19),Vector3(.31,.40,.13),pants]]:
			var mi=MeshInstance3D.new();var mesh=CapsuleMesh.new();mesh.radius=1;mesh.height=2;mesh.radial_segments=8;mesh.rings=3;mi.mesh=mesh;mi.scale=spec[1]*Vector3(.5,.5,.5);mi.position=spec[0];mi.material_override=spec[2];person.add_child(mi)

func label(text:String,size:int,color:Color)->Label:
	var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);l.add_theme_color_override("font_shadow_color",Color(0,.05,.03,.8));l.add_theme_constant_override("shadow_offset_x",1);l.add_theme_constant_override("shadow_offset_y",2);return l

func setup_hud():
	hud=CanvasLayer.new();add_child(hud)
	var root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(root)
	var theme=Theme.new();var font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei","Segoe UI"]);theme.default_font=font;root.theme=theme
	var top=VBoxContainer.new();top.position=Vector2(38,30);top.add_theme_constant_override("separation",4);root.add_child(top)
	top.add_child(label("U S T C   /   E A S T   C A M P U S",13,Color("e2dfbd")))
	top.add_child(label("东区 · 普通下午",28,Color("fff9e5")))
	top.add_child(label("中国科学技术大学  /  夏末 16:10",13,Color("e5eadc")))
	spot_label=label("玉泉北路 · 沿树荫向前",16,Color("fff6d9"));spot_label.position=Vector2(38,768);root.add_child(spot_label)
	var help=label("WASD 行走   Shift 慢跑   Space 跳跃   鼠标 环顾   Esc 释放\n1–5 观景点   V 自由相机 · Q/E 升降   F 隐藏界面   F12 留影   G 灰模   M 导览",13,Color("e1e8dd"));help.position=Vector2(38,805);root.add_child(help)
	mode_label=label("",13,Color("faf2d8"));mode_label.position=Vector2(1320,38);root.add_child(mode_label)
	var credit=label("空间参考 © OpenStreetMap contributors · 艺术化复原 V0.1",10,Color(.95,.95,.87,.85));credit.position=Vector2(1180,866);root.add_child(credit)
	map_panel=Panel.new();map_panel.position=Vector2(1010,110);map_panel.size=Vector2(540,550);map_panel.visible=false;root.add_child(map_panel)
	var stylebox=StyleBoxFlat.new();stylebox.bg_color=Color(.07,.15,.14,.93);stylebox.corner_radius_top_left=12;stylebox.corner_radius_bottom_left=12;map_panel.add_theme_stylebox_override("panel",stylebox)
	var intro=label("北段漫游\n\n老北门\n    ↓\n玉泉北路 · 樱花大道\n    ↓\n眼镜湖西池  ┃  东池 · 一鉴亭\n    ↓\n瀚海路\n    ↓\n第一教学楼 · U形庭院\n\n1–4：地面镜头   5：空间总览\n此版本重点复原北段，周边为简化背景。\n公开资料与估算范围见 docs/SOURCE_LOG.md。",17,Color("eee7ce"));intro.position=Vector2(30,24);map_panel.add_child(intro)

func _process(dt):
	elapsed+=dt
	if player and mode_label:mode_label.text=("自由相机" if player.free_camera else "步行 · %.1f m/s" % Vector2(player.velocity.x,player.velocity.z).length())+"\n%d FPS" % Engine.get_frames_per_second()
	for i in birds.size():
		var a=elapsed*.055+i*.6;birds[i].position=Vector3(45+sin(a)*55,27+i*.8,85+cos(a)*42);birds[i].rotation.y=-a
		for j in range(2):birds[i].get_child(j).rotation.z=sin(elapsed*4.3+i)*.34*(1 if j==0 else -1)
	for i in walkers.size():
		var z=48+fmod(elapsed*.70+i*29,90.0);walkers[i].position=Vector3(-1.8+i*1.5,.06,z)
		walkers[i].rotation.y=PI if i%2==0 else 0
		for j in [3,4,5,6]:walkers[i].get_child(j).rotation.x=sin(elapsed*3.6+i)*.30*(1 if j%2==0 else -1)

func viewpoint(i:int):
	var s=photo_spots[i];player.set_view(s.pos,s.target);player.camera.fov=s.fov
	player.free_camera=i==4 and not lookdev_mode
	spot_label.text=s.name
	if photo_camera:photo_camera.global_transform=player.camera.global_transform;photo_camera.fov=s.fov

func _unhandled_input(e):
	if capture_mode:return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode>=KEY_1 and e.keycode<=KEY_5:viewpoint(e.keycode-KEY_1)
		match e.keycode:
			KEY_R:player.free_camera=false;player.set_view(Vector3(0,.1,12),Vector3(0,6,174));spot_label.text="玉泉北路 · 沿树荫向前"
			KEY_F:hud.visible=not hud.visible
			KEY_M:map_panel.visible=not map_panel.visible
			KEY_G:toggle_gray()
			KEY_F12:capture("walk_%d"%Time.get_unix_time_from_system())

func toggle_gray():
	gray=not gray
	for m in art_mats:m.set_shader_parameter("graybox",gray)

func capture(file:String):
	if DisplayServer.get_name()=="headless":return
	await get_tree().process_frame
	RenderingServer.force_draw()
	var im=(photo_view if photo_view else get_viewport()).get_texture().get_image()
	var directory="res://../renders/" if OS.has_feature("editor") else "user://screenshots/"
	var path=ProjectSettings.globalize_path(directory+file+".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var result=im.save_png(path);print("CAPTURE ",file," ",result," size=",im.get_size())
	locator.refresh()
	var context=FileAccess.open(path.get_basename()+".json",FileAccess.WRITE);context.store_string(JSON.stringify(locator.latest,"\t"));context.close()

func write_spots():
	var out=[]
	for s in photo_spots:out.append({"name":s.name,"feet":[s.pos.x,s.pos.y,s.pos.z],"eye":[s.pos.x,s.pos.y+1.65,s.pos.z],"target":[s.target.x,s.target.y,s.target.z],"fov":s.fov,"art_time":"16:10","composition":s.reason})
	var f=FileAccess.open("res://../renders/"+("lookdev/photo_spots.json" if lookdev_mode else "photo_spots.json"),FileAccess.WRITE);f.store_string(JSON.stringify(out,"\t"))

func run_capture():
	await get_tree().create_timer(2).timeout
	var report={"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"tree_count":tree_count,"instance_count":instance_count,"screenshots":[],"checks":{},"ultra":"--ultra" in OS.get_cmdline_user_args(),"viewport":str(get_viewport().size)}
	if "--verify" in OS.get_cmdline_user_args():await verify_walk(report)
	player.frozen=true;player.enabled=false
	for i in range(photo_spots.size()):
		viewpoint(i);hud.visible=false
		for frame in range(64):await get_tree().process_frame
		var fname=("lookdev/hero_%02d" if lookdev_mode else "campus_%02d")%(i+1);await capture(fname)
		report.screenshots.append({"file":fname+".png","fps":Engine.get_frames_per_second(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	if not lookdev_mode:
		print("CAPTURE_GRAY_BEGIN")
		viewpoint(4);toggle_gray();await get_tree().create_timer(.5).timeout;await capture("graybox_site");toggle_gray()
		viewpoint(0);hud.visible=true;await get_tree().create_timer(.5).timeout;await capture("campus_ui")
	report["capture_resolution"]=str(photo_view.size if photo_view else get_viewport().size)
	report["passed"]=true
	report["scope"]="Controller regression" if "--verify" in OS.get_cmdline_user_args() else "Capture completion only; not art approval"
	for k in report.checks:
		if not report.checks[k]:report.passed=false
	var report_name="validation" if "--verify" in OS.get_cmdline_user_args() else "capture_report"
	if DisplayServer.get_name()=="headless":report_name+="_headless"
	var f=FileAccess.open("res://../renders/"+("lookdev/" if lookdev_mode else "")+report_name+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("CAMPUS_VALIDATION ",JSON.stringify(report))
	birds.clear();walkers.clear();player=null;sun=null;world=null
	asset_cache.clear();original_mats.clear();art_mats.clear();mats.clear()
	for child in get_children():child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if report.passed else 1)

func verify_walk(report:Dictionary):
	player.frozen=false;player.enabled=true;player.free_camera=false
	player.set_view(Vector3(0,.2,8),Vector3(0,1.85,170));Input.action_press("forward");Input.action_press("jog")
	var frames=0;var grounded=0;var t=Time.get_ticks_msec()
	while player.position.z<159 and frames<2500:
		await get_tree().physics_frame;frames+=1
		if player.is_on_floor():grounded+=1
	Input.action_release("forward");Input.action_release("jog")
	report.checks["avenue_walk_151m"]=player.position.z>158
	report.checks["ground_contact"]=float(grounded)/maxi(frames,1)>.97
	report["walk"]={"end":str(player.position),"frames":frames,"grounded":grounded,"seconds":(Time.get_ticks_msec()-t)/1000.0}
	# Verify jump and landing using the actual shipped controller.
	Input.action_press("jump");await get_tree().physics_frame;await get_tree().physics_frame;Input.action_release("jump")
	var high=player.position.y
	for j in range(90):await get_tree().physics_frame;high=maxf(high,player.position.y)
	report.checks["jump_and_land"]=high>.6 and player.is_on_floor()
	player.set_view(Vector3(0,.15,160),Vector3(0,1.8,176));Input.action_press("forward")
	for j in range(330):await get_tree().physics_frame
	Input.action_release("forward");report.checks["building_collision"]=player.position.z<168
	var prev=player.rotation.y;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var motion=InputEventMouseMotion.new();motion.relative=Vector2(70,0);player._unhandled_input(motion)
	report.checks["mouse_look"]=absf(player.rotation.y-prev)>.05
	var esc=InputEventKey.new();esc.keycode=KEY_ESCAPE;esc.pressed=true;player._unhandled_input(esc)
	report.checks["escape_releases_mouse"]=Input.mouse_mode==Input.MOUSE_MODE_VISIBLE
	# Follow the actual angled bridge, including its low approach step.
	player.set_view(Vector3(6,.2,64),Vector3(12,1.85,64))
	var bridge_ok=true;var bridge_points=[Vector3(12,0,64),Vector3(22,0,69),Vector3(29,0,78),Vector3(42.5,0,80.8)]
	for dest in bridge_points:
		player.set_view(player.position,dest+Vector3(0,player.position.y+1.65,0));Input.action_press("forward")
		var count=0
		while Vector2(player.position.x-dest.x,player.position.z-dest.z).length()>.4 and count<650:
			await get_tree().physics_frame;count+=1
		Input.action_release("forward")
		if count>=650:bridge_ok=false;break
		print("BRIDGE_WAYPOINT ",player.position)
	report.checks["bridge_walk_to_pavilion"]=bridge_ok and player.position.y>.2
	report["bridge_end"]=str(player.position)
	# Actual controller strafe, backward movement and free-camera ascent.
	player.set_view(Vector3(0,.15,30),Vector3(0,1.8,60))
	Input.action_press("left")
	for j in range(45):await get_tree().physics_frame
	Input.action_release("left");report.checks["strafe_left"]=player.position.x>.8
	Input.action_press("right")
	for j in range(90):await get_tree().physics_frame
	Input.action_release("right");report.checks["strafe_right"]=player.position.x<-.8
	Input.action_press("back")
	for j in range(45):await get_tree().physics_frame
	Input.action_release("back");report.checks["backward"]=player.position.z<29.2
	var vkey=InputEventKey.new();vkey.keycode=KEY_V;vkey.pressed=true;player._unhandled_input(vkey)
	var old_y=player.position.y;Input.action_press("up")
	for j in range(30):await get_tree().physics_frame
	Input.action_release("up");report.checks["free_camera"]=player.free_camera and player.position.y>old_y+1
	player.enabled=false;player.frozen=true

func bake():
	set_owners(world,world)
	var scene=PackedScene.new();var err=scene.pack(world)
	if err==OK:err=ResourceSaver.save(scene,"res://scenes/campus_world.scn")
	print("WORLD_BAKE ",err)
	if not capture_mode:get_tree().quit(err)

func set_owners(n:Node,root:Node):
	for c in n.get_children():c.owner=root;set_owners(c,root)
