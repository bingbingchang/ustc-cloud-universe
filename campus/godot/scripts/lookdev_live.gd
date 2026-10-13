extends "res://scripts/diorama.gd"
## Shared present-day layout/gameplay, with the retained immersive LookDev assets.
## Original main.tscn and Diorama remain independently reproducible.
var lookdev_tree_contacts:Array=[]
var lookdev_tree_batches:Array=[]
var tree_measurements:Dictionary={}
var trunk_shapes:Dictionary={}
var context_mode=false
var live_initialized=false
var live_environment:Environment

func _ready():
	super._ready()
	get_window().set_deferred("title","科大东区 · LookDev Live | 人高游览 · 共享校园内容")
	# Replace display-stage presentation, not the tested walkable surfaces.
	for n in world.get_children():
		if n is GeometryInstance3D and ("Plinth" in String(n.name) or "Wave2Rim" in String(n.name)):
			n.visible=false
		if String(n.name).begins_with("Diobase"):n.visible=false
		if n is MeshInstance3D and n.position.y < -4:n.visible=false
		if n is StaticBody3D and n.get_meta("lookdev_replaced_trunk",false):
			n.free();continue
		if n is MeshInstance3D and n.mesh and n.material_override!=mats.water and not n.get_meta("lake_water",false) and n.mesh.get_aabb().end.y+n.position.y<-.03:n.visible=false
	world.set_meta("lookdev_tree_contacts",lookdev_tree_contacts)
	set_meta("lookdev_tree_batches",lookdev_tree_batches)
	context_landscape()
	var shots=[
		["01 · 玉泉北路 / 人高",Vector3(-1,.12,105),Vector3(0,8,177),62.0],
		["02 · 眼镜湖与一鉴亭",Vector3(72,.50,78),Vector3(42.7,2,80.5),52.0],
		["03 · 老北门外",Vector3(-.8,1.55,-24),Vector3(-.8,3.35,3),54.0],
		["04 · 红砖与梧桐 / 原LookDev视角",Vector3(-28,.14,149),Vector3(2,6.5,170),58.0],
		["05 · 亭中看校园",Vector3(42.5,.38,80.8),Vector3(0,4,168),60.0]]
	for i in range(shots.size()):
		var s=shots[i];photo_spots[i]={"name":s[0],"pos":s[1],"target":s[2],"fov":s[3],"ortho":false,"size":120.0,"reason":"人高视角比较同一校园的建筑、细叶树、角色与地面"}
	photo_spots[19].name="20 · 共享核心 / 空间核查"
	live_initialized=true
	write_spots();viewpoint(3)
	if "--sakura-focus" in OS.get_cmdline_user_args():viewpoint(0)
	if "--lake-focus" in OS.get_cmdline_user_args():viewpoint(1)
	if not capture_mode:player.free_camera=false
	print("LOOKDEV_LIVE_READY population=14 wanderers=5 tree_contacts=",lookdev_tree_contacts.size())
	if "--lookdev-live-qa" in OS.get_cmdline_user_args():call_deferred("lookdev_live_qa")
	if "--lookdev-live-motion" in OS.get_cmdline_user_args():call_deferred("lookdev_live_motion")

func material(c:Color,fol=0.0,g=0.0,br=0.0)->ShaderMaterial:
	var m=ShaderMaterial.new();m.shader=preload("res://shaders/academic.gdshader")
	m.set_shader_parameter("base_color",c);m.set_shader_parameter("foliage",fol)
	m.set_shader_parameter("ground",g);m.set_shader_parameter("brick",br);art_mats.append(m)
	return m

func asset_material(key:String,c:Color)->ShaderMaterial:
	var m=super.asset_material(key,c)
	# Keep the accepted character face/cloth shaders, while restoring building colors.
	if key in ["Roof","Frame"]:m.set_shader_parameter("base_color",c)
	return m

func load_art(asset:String):
	var names=[]
	if asset=="architecture":names=["lookdev_teaching_hall","north_axis_architecture","north_axis_surroundings"]
	elif asset=="sitedetail":names=["diositedetail"]
	elif asset=="background":names=["lookdev_context"]
	for key in names:
		var n=load("res://assets/"+key+".glb").instantiate();n.name=key.to_pascal_case();world.add_child(n);style(n)
		if key=="lookdev_context":
			for part in n.find_children("Context_268207470*","Node3D",true,false):
				if preload("res://scripts/plaza_environment.gd").enabled():part.hide()
			for part in n.find_children("Context_270537512*","Node3D",true,false):
				if preload("res://scripts/campus_network.gd").enabled():part.hide()
		if key=="lookdev_teaching_hall":set_meta("lookdev_architecture_root",n.get_path())

func multimesh(asset:String,transforms:Array):
	if (asset.begins_with("tree") or asset.begins_with("diotree")) and not asset.begins_with("tree_plane") and asset not in ["tree_conifer","tree_garden"] and not context_mode:
		transforms=transforms.filter(func(t):return preload("res://scripts/campus_network.gd").legacy_tree_allowed(Vector2(t.origin.x,t.origin.z)))
	var old_count=world.get_child_count()
	var source=asset
	if asset.begins_with("diotree"):
		source="tree"+asset.substr(7,1)+["","b","c"][int(asset.substr(8,1))]
	elif asset=="dioshrub":source="shrub"
	# diotree already specifies an authored individual; do not randomize it twice.
	if asset.begins_with("diotree"):super.multimesh_batch(source,transforms)
	else:super.multimesh(source,transforms)
	if source.begins_with("tree") and not context_mode:
		for i in range(old_count,world.get_child_count()):
			var n=world.get_child(i)
			if n is MultiMeshInstance3D:
				n.set_meta("lookdev_source_asset",source);lookdev_tree_batches.append(n.get_path())
		for index in transforms.size():
			var transform=transforms[index]
			var actual=source+["","b","c"][index%3] if asset in ["tree0","tree1","tree2"] else source
			var local_radius=measure_trunk(actual)
			var radius=local_radius*maxf(transform.basis.get_scale().x,transform.basis.get_scale().z)
			var body=StaticBody3D.new();body.name="LookDevTreeContact";world.add_child(body);body.transform=transform
			var sh=CollisionShape3D.new();sh.shape=low_trunk_shape(actual);body.add_child(sh)
			body.set_meta("source_asset",actual);body.set_meta("measured_radius",radius)
			lookdev_tree_contacts.append({"asset":actual,"actual_asset":actual,"position":transform.origin,"placement":transform,"radius":radius,"shape":"cached low bark triangles","cut_height":2.4,"body":body.get_path()})

func measure_trunk(asset:String)->float:
	if tree_measurements.has(asset):return tree_measurements[asset]
	var radius=0.0
	for part in asset_cache[asset]:
		var mesh:Mesh=part.mesh
		for s in mesh.get_surface_count():
			var mat=mesh.surface_get_material(s)
			if mat==null or not ("Trunk" in mat.resource_name or "Bark" in mat.resource_name):continue
			for v in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p=part.transform*v
				if p.y>=0 and p.y<=2.2:radius=maxf(radius,Vector2(p.x,p.z).length())
	assert(radius>.05,"A real low trunk mesh must define the collision radius")
	tree_measurements[asset]=radius;return radius

func low_trunk_shape(asset:String)->ConcavePolygonShape3D:
	# Root flares stay at ground height; their radius must not become a full cylinder.
	if trunk_shapes.has(asset):return trunk_shapes[asset]
	var faces=PackedVector3Array()
	for part in asset_cache[asset]:
		for s in part.mesh.get_surface_count():
			var mat=part.mesh.surface_get_material(s)
			if mat==null or not ("Trunk" in mat.resource_name or "Bark" in mat.resource_name):continue
			var arrays=part.mesh.surface_get_arrays(s);var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
			var count=indices.size() if indices!=null and not indices.is_empty() else vertices.size()
			for i in range(0,count,3):
				var tri=[]
				for k in range(3):tri.append(part.transform*vertices[indices[i+k] if indices!=null and not indices.is_empty() else i+k])
				# Clip the actual bark triangle to the player-height section.
				var clipped=[]
				for k in range(3):
					var a:Vector3=tri[k];var b:Vector3=tri[(k+1)%3]
					if a.y<=2.4:clipped.append(a)
					if (a.y<=2.4)!=(b.y<=2.4):clipped.append(a.lerp(b,(2.4-a.y)/(b.y-a.y)))
				for k in range(1,clipped.size()-1):faces.append(clipped[0]);faces.append(clipped[k]);faces.append(clipped[k+1])
	assert(not faces.is_empty(),"A real bark mesh is required for collision")
	var shape=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces)
	trunk_shapes[asset]=shape;return shape

func static_box(p:Vector3,s:Vector3,node_name="Collider"):
	var b=super.static_box(p,s,node_name)
	b.set_meta("source_label",node_name)
	if "Trunk" in node_name:b.set_meta("lookdev_replaced_trunk",true)
	return b

func build_collisions():
	super.build_collisions()
	var path="res://assets/lookdev_teaching_hall_manifest.json"
	if FileAccess.file_exists(path):
		var data=JSON.parse_string(FileAccess.get_file_as_string(path))
		for s in data.get("new_collision_proposals",[]):
			var p=Vector3(s.center[0],s.center[1],s.center[2])
			if s.type=="box":static_box(p,Vector3(s.size[0],s.size[1],s.size[2]),s.name)
			else:
				var b=StaticBody3D.new();b.name=s.name;b.position=p;world.add_child(b)
				var cs=CollisionShape3D.new();var cylinder=CylinderShape3D.new();cylinder.radius=s.radius;cylinder.height=s.height;cs.shape=cylinder;b.add_child(cs)

func setup_environment():
	preload("res://scripts/lookdev_live_visuals.gd").environment(self)

func setup_life():
	super.setup_life()
	if ResourceLoader.exists("res://assets/campus_ambience.wav"):
		var audio_player=AudioStreamPlayer.new();audio_player.name="LookDevCampusAmbience"
		audio_player.stream=load("res://assets/campus_ambience.wav");audio_player.stream.loop_end=int(audio_player.stream.get_length()*audio_player.stream.mix_rate)
		audio_player.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;audio_player.volume_db=-16;add_child(audio_player);audio_player.play()

func _process(dt):
	super._process(dt)
	if sun:
		sun.rotation_degrees=Vector3(-36,-128+sin(elapsed*.012)*.28,0)
		sun.light_energy=1.85+sin(elapsed*.045)*.012
	if live_environment and player:
		var camera=photo_camera if photo_camera else player.camera
		# Retain human-eye air perspective without washing out the spatial overview.
		live_environment.fog_density=lerpf(.00075,.00016,clampf((camera.global_position.y-15.0)/120.0,0,1))

func setup_hud():
	super.setup_hud()
	for item in hud.find_children("*","Label",true,false):
		item.text=item.text.replace("Diorama 0.7 · 校园漫步","LookDev Live · 春日樱花大道")
		item.text=item.text.replace("1–5 观景点","1–5 环境机位 · [ ] 全部25机位 · L 行动线")
		if item.text.begins_with("北段漫游"):
			item.text="北段漫游\n\n老北门\n    ↓\n玉泉北路\n    ↓\n眼镜湖双池 · 一鉴亭\n    ↓\n第一教学楼 · U形庭院\n\nP：从老北门步行\n[ ]：25个环境与人物机位\nL / F8：查看角色漫步路线\nV：自由镜头\n\n围栏标示本次可游览范围。\n建筑内部与湖水暂不开放。"

func viewpoint(i:int):
	super.viewpoint(i)
	if not sun or not player:return
	var height=player.camera.global_position.y
	sun.directional_shadow_max_distance=95 if height<12 else 260 if height<60 else 650
	sun.light_angular_distance=.5;sun.shadow_blur=1.25

func write_spots():
	# The inherited ready chain calls this early; never overwrite the Diorama gallery.
	var dir="res://../renders/lookdev_live/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out=[]
	for s in photo_spots:out.append({"name":s.name,"feet":[s.pos.x,s.pos.y,s.pos.z],"target":[s.target.x,s.target.y,s.target.z],"fov":s.fov,"ortho":s.get("ortho",false),"size":s.get("size",0)})
	var f=FileAccess.open(dir+"photo_spots.json",FileAccess.WRITE);f.store_string(JSON.stringify(out,"\t"))

func context_landscape():
	preload("res://scripts/lookdev_live_visuals.gd").context(self)

func run_capture():
	await preload("res://scripts/lookdev_live_proof.gd").new().capture_stills(self)

func lookdev_live_qa():
	var result=await load("res://scripts/lookdev_live_qa.gd").new().validate(self)
	get_tree().quit(0 if result.passed else 1)

func lookdev_live_motion():
	await preload("res://scripts/lookdev_live_proof.gd").new().capture_motion(self)
