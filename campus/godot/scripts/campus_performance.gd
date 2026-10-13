extends "res://scripts/lake_garden_expanded.gd"
var render_mesh_cache={}
var reflection_elapsed=1.0
var last_reflection_transform=Transform3D.IDENTITY
var last_reflection_fov=-1.0
var last_reflection_projection=-1
var last_reflection_size=-1.0
var lod_sources={}
var lod_checked={}
var motion_clock=0.0
const West=preload("res://scripts/west_lake_garden.gd")
const Grove=preload("res://scripts/west_grove.gd")
var grove_life:Node3D
func study_land_safe(p:Vector2,r:float)->bool:
	if p.x<0 and p.y<73:return Grove.safe(p,r)
	return West.safe_land(p,r) if p.x<0 else super.study_land_safe(p,r)

func compose_garden():
	super.compose_garden()
	if west_enabled():West.build(self)
	if west_enabled() and not "--northwest-before" in OS.get_cmdline_user_args():load("res://scripts/northwest_lake_garden.gd").build(self)
	if west_enabled() and not "--grove-before" in OS.get_cmdline_user_args():Grove.build(self)
func west_enabled()->bool:
	return "--expand-west" in OS.get_cmdline_user_args()
func optimized()->bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-case="):return arg in ["--perf-case=optimized","--perf-case=optimized_motion","--perf-case=lod_only","--perf-case=reflection_only","--perf-case=expanded","--perf-case=expanded_motion"]
	return true

func render_instance_groups(asset:String,transforms:Array)->Array:
	if not optimized() or "--perf-case=reflection_only" in OS.get_cmdline_user_args():return super.render_instance_groups(asset,transforms)
	var groups={}
	for tr in transforms:
		var cell=Vector2i(floor(tr.origin.x/24.0),floor(tr.origin.z/24.0))
		if not groups.has(cell):groups[cell]=[]
		groups[cell].append(tr)
	return groups.values()

func render_batch_mesh(asset:String,part:int,s:int,mesh:Mesh,key:String,color:Color)->ArrayMesh:
	if not optimized() or "--perf-case=reflection_only" in OS.get_cmdline_user_args():return super.render_batch_mesh(asset,part,s,mesh,key,color)
	var id=asset+"_"+str(part)+"_"+str(s)
	if render_mesh_cache.has(id):return render_mesh_cache[id]
	var path="res://assets/render_lods/"+id+".res"
	var ar:ArrayMesh
	if ResourceLoader.exists(path) and valid_lod_source(asset):
		ar=load(path).duplicate();ar.surface_set_material(0,asset_material(key,color))
	else:ar=super.render_batch_mesh(asset,part,s,mesh,key,color)
	render_mesh_cache[id]=ar;return ar

func valid_lod_source(asset:String)->bool:
	if lod_checked.has(asset):return lod_checked[asset]
	if not OS.has_feature("editor"):return true # Export uses the matched imported resources and LOD cache.
	if lod_sources.is_empty():
		for row in JSON.parse_string(FileAccess.get_file_as_string("res://assets/render_lods/manifest.json")):lod_sources[row.asset]=row.source_sha256
	lod_checked[asset]=lod_sources.get(asset,"")==FileAccess.get_sha256("res://assets/"+asset+".glb")
	if not lod_checked[asset]:push_warning("Stale render LOD; using original mesh for "+asset)
	return lod_checked[asset]

func _process(dt):
	super._process(dt)
	if "--perf-motion" in OS.get_cmdline_user_args():
		motion_clock+=dt;player.position.x+=cos(motion_clock*.7)*dt*.8

func render_reflection_frame():
	super.update_reflection()

func update_reflection():
	if not optimized() or "--perf-case=lod_only" in OS.get_cmdline_user_args():super.update_reflection();return
	var cam=photo_camera if photo_camera else player.camera
	if not cam:return
	reflection_elapsed+=get_process_delta_time()
	var moved=not cam.global_transform.is_equal_approx(last_reflection_transform) or not is_equal_approx(cam.fov,last_reflection_fov) or cam.projection!=last_reflection_projection or not is_equal_approx(cam.size,last_reflection_size)
	# Moving views update each frame. Still views retain a coherent texture/matrix
	# pair while water waves animate independently, capped at 12 reflection Hz.
	if moved or reflection_elapsed>=1.0/12.0:
		super.update_reflection();reflection_view.render_target_update_mode=SubViewport.UPDATE_ONCE
		last_reflection_transform=cam.global_transform;last_reflection_fov=cam.fov;reflection_elapsed=0
		last_reflection_projection=cam.projection;last_reflection_size=cam.size

func _ready():
	super._ready()
	var args=OS.get_cmdline_user_args()
	if west_enabled() and not "--grove-before" in args:
		grove_life=load("res://scripts/grove_life.gd").new();grove_life.name="GroveLife";add_child(grove_life);grove_life.setup(self)
		study_stats["population"]=16
	if west_enabled():
		for n in world.get_children():
			if n is MeshInstance3D and String(n.name).begins_with("NorthWater_west"):
				n.material_override=reflection_material;n.set_meta("lake_water",true)
		photo_spots.append({"name":"西池 · 南岸花石","pos":Vector3(-43,.15,139),"target":Vector3(-39,2,108),"fov":58.0,"ortho":false,"size":120.0,"reason":"优化后的下一分区"})
		viewpoint(photo_spots.size()-1)
	if "--basin-focus" in args:
		photo_spots.append({"name":"樱花大道 · 对齐树池","pos":Vector3(3.7,.15,126),"target":Vector3(7.15,.45,123),"fov":58.0,"ortho":false,"size":120.0,"reason":"树干、根部与树池共用定位"})
		photo_spots.append({"name":"西池 · 西北岸","pos":Vector3(-67,.15,99),"target":Vector3(-44,1.4,86),"fov":58.0,"ortho":false,"size":120.0,"reason":"延伸北岸花草与水生群落"})
		viewpoint(photo_spots.size()-2)
	if "--perf-case=no_reflection" in args:reflection_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if "--grove-focus" in args:
		photo_spots.append({"name":"西侧林荫步道 · 慢行与取景","pos":Vector3(-29,.15,66),"target":Vector3(-19,2,39),"fov":58.0,"ortho":false,"size":120.0,"reason":"由西池向北门方向延伸"})
		viewpoint(photo_spots.size()-1)
	if "--perf-case=no_ssil" in args:live_environment.ssil_enabled=false
	if "--perf-case=no_trees" in args:
		for n in world.get_children():
			if n is MultiMeshInstance3D:
				var name=String(n.get_meta("render_asset",n.name))
				if "tree" in name or "canopy" in name or "willow" in name:n.visible=false
