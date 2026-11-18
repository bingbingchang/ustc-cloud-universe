extends Node
## Download and verify independently of frames, instantiate bounded scene chunks.
const VegetationLOD = preload("res://scripts/vegetation_lod.gd")
signal changed
var game
var manifest={}
var loaded={}
var pending={}
var failures={}
var last_safe=Vector3(0,.16,12)
var last_safe_camera=Vector3.INF
var clock=0.0
var downloading=false
var status:Label
var retry:Button
var asset_base=""
var camera_shadow_materials={}
var visual_bounds: Dictionary = {}
var shadow_clock=0.0
var status_row:HBoxContainer
var download_bytes=0
var fetch_bridge
var active_fetch
var shared_resources={}
var ready_started=0
var progress_clock=0.0

func _ready():
	manifest=JSON.parse_string(FileAccess.get_file_as_string("res://web/regions.json"))
	asset_base=str(JavaScriptBridge.eval("window.location.origin",true))+"/game/releases/"+manifest.release+"/" if OS.has_feature("web") else ""
	if OS.has_feature("web"):
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://web/region_fetch.js"),true)
		fetch_bridge=JavaScriptBridge.get_interface("CampusRegionFetch")
	var layer=CanvasLayer.new();layer.layer=45;add_child(layer)
	var row=HBoxContainer.new();row.position=Vector2(16,80);layer.add_child(row);status_row=row
	var theme=Theme.new();theme.default_font=preload("res://scripts/campus_font.gd").get_font();row.theme=theme
	status=Label.new();row.add_child(status)
	status.add_theme_font_size_override("font_size",16);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	retry=Button.new();retry.text="重试加载";row.add_child(retry);retry.hide();retry.pressed.connect(retry_failed)
	retry.custom_minimum_size=Vector2(88,40);get_viewport().size_changed.connect(layout_status);layout_status()

func notify(stage:String,text:String,progress:float=-1):
	status.text=text
	if OS.has_feature("web"):fetch_bridge.notify(stage,text,progress)

func layout_status():
	status_row.position=Vector2(16,66);status_row.size.x=maxf(200,get_viewport().get_visible_rect().size.x-32)

func id_at(position:Vector3)->String:
	return "%d_%d"%[floori(position.x/manifest.cell_size),floori(position.z/manifest.cell_size)]

func distance_to(id:String,point:Vector3)->float:
	var bounds=manifest.regions[id].bounds
	if bounds.is_empty():return 0
	return Vector2(point.x-clampf(point.x,bounds[0],bounds[2]),point.z-clampf(point.z,bounds[1],bounds[3])).length()

func ensure_at(position:Vector3)->bool:return await ensure(id_at(position),true)

func start_fetch(spec:Dictionary,folder:String)->Dictionary:
	var result={"done":false,"code":0,"data":PackedByteArray()}
	var callback=JavaScriptBridge.create_callback(func(arguments:Array):
		result.code=int(arguments[0])
		if result.code==200:result.data=JavaScriptBridge.js_buffer_to_packed_byte_array(arguments[1])
		result.done=true)
	result.callback=callback
	var name=str(spec.scene).get_file().get_basename()+"."+str(spec.sha256).left(12)+"."+str(spec.scene).get_extension()
	result.progress=fetch_bridge.download(asset_base+folder+"/"+name,32*1024*1024,callback,spec.sha256)
	return result

func wait_fetch(job:Dictionary,bytes:int)->bool:
	active_fetch=job.progress;download_bytes=bytes
	while not job.done:await get_tree().process_frame
	active_fetch=null;job.erase("callback")
	return job.code==200

func save_temporary(path:String,bytes:PackedByteArray)->bool:
	var file=FileAccess.open(path,FileAccess.WRITE)
	if not file:return false
	file.store_buffer(bytes);file.close();return true

func ensure(id:String,interactive:bool=false)->bool:
	if loaded.has(id) and not pending.has(id):return true
	if not manifest.regions.has(id):return false
	if pending.has(id):
		if interactive:pending[id]=true
		while pending.has(id):await changed
		return loaded.has(id)
	pending[id]=interactive
	while downloading:await changed
	if game.game_ready and (game.hero_interactions.modal_active or game.campus_agent.panel_open) and not pending[id]:
		pending.erase(id);changed.emit();return false
	downloading=true;retry.hide()
	notify("regions","正在下载校园新区…")
	var spec=manifest.regions[id]
	var region_bytes=PackedByteArray()
	if OS.has_feature("web"):
		# Queue shared meshes and region together. Browser transport caps concurrency at three.
		var jobs={}
		for path in spec.get("shared",[]):
			if manifest.shared[path].get("bundled",false):continue
			if not shared_resources.has(path):jobs[path]=start_fetch(manifest.shared[path],"shared")
		var region_job=start_fetch(spec,"regions")
		var failed_code=0;var shared_failed=false
		var shared_slice=Time.get_ticks_usec()
		for path in jobs:
			var job=jobs[path]
			if not await wait_fetch(job,int(manifest.shared[path].bytes)):
				failed_code=int(job.code);shared_failed=true;continue
			var temporary="user://shared_download.res"
			if not save_temporary(temporary,job.data):failed_code=507;shared_failed=true;continue
			job.data=PackedByteArray()
			var resource=ResourceLoader.load(temporary,"",ResourceLoader.CACHE_MODE_IGNORE)
			DirAccess.remove_absolute(temporary)
			if not resource:failed_code=422;shared_failed=true;continue
			resource.take_over_path(path);shared_resources[path]=resource
			if Time.get_ticks_usec()-shared_slice>=4000:
				await get_tree().process_frame;shared_slice=Time.get_ticks_usec()
		var region_ok=await wait_fetch(region_job,int(spec.bytes))
		if not region_ok:failed_code=int(region_job.code)
		if shared_failed or not region_ok:
			print("WEB_REGION_DOWNLOAD_FAILED id=",id," http=",failed_code)
			finish(id,false,failed_code);return false
		region_bytes=region_job.data;region_job.data=PackedByteArray()
	else:region_bytes=FileAccess.get_file_as_bytes(spec.scene)
	notify("placing","正在分批布置新区…")
	var region=Node3D.new();region.name="Streamed_"+id.replace("-","m");region.hide();game.world.add_child(region)
	var shadow_materials=[];var count=0;var largest_slice_ms=0.0
	var track_bounds: bool = id not in manifest.core
	var bounds := AABB()
	var has_bounds := false
	var chunks=spec.get("chunks",[{"offset":0,"bytes":region_bytes.size()}])
	var frame_started=Time.get_ticks_usec()
	for part in chunks:
		# Budget actual work, rather than waiting one throttled frame for every small chunk.
		if Time.get_ticks_usec()-frame_started>=(35000 if not game.game_ready else 3000):
			await get_tree().process_frame;frame_started=Time.get_ticks_usec()
		var started=Time.get_ticks_usec()
		var temporary="user://region_chunk.scn"
		if not save_temporary(temporary,region_bytes.slice(int(part.offset),int(part.offset+part.bytes))):
			region.queue_free();finish(id,false,507);return false
		var scene=ResourceLoader.load(temporary,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		DirAccess.remove_absolute(temporary)
		if not scene:
			region.queue_free();finish(id,false,422);return false
		var staging=scene.instantiate();scene=null
		var use_hard_lod := RenderingServer.get_current_rendering_method() != "forward_plus"
		for child in staging.get_children():
			staging.remove_child(child);region.add_child(child);count+=1
			if use_hard_lod and child is MultiMeshInstance3D:
				VegetationLOD.adapt_baked_pair(child)
			if child is MultiMeshInstance3D and child.has_meta("render_asset"):
				var asset=str(child.get_meta("render_asset"))
				child.lod_bias=.12 if "tree" in asset or "canopy" in asset or "willow" in asset else .4
			if child is MultiMeshInstance3D and child.get_meta("runtime_camera_shadow",false):shadow_materials.append(child.multimesh.mesh.surface_get_material(0))
			if child is MultiMeshInstance3D and child.get_meta("far_canopy_footprint",false):
				# Baked on desktop; use this renderer's actual last shadow split.
				var material: ShaderMaterial = child.multimesh.mesh.surface_get_material(0)
				var limit: float = game.sun.directional_shadow_max_distance
				material.set_shader_parameter("shadow_handoff",Vector2(limit * game.sun.directional_shadow_fade_start,limit))
			if child is GeometryInstance3D and child.get_meta("lake_water",false):
				child.material_override=game.reflection_material;game.water_surfaces.append(weakref(child))
			if child is StaticBody3D and child.get_meta("water_entry_barrier",false):
				game.water_entry_barriers.append(weakref(child))
			if track_bounds and child is GeometryInstance3D:
				var geometry := child as GeometryInstance3D
				if geometry.layers & game.player.camera.cull_mask and geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
					var box := geometry.custom_aabb if geometry.custom_aabb.has_surface() else geometry.get_aabb()
					if box.has_surface():
						box = geometry.global_transform * box
						bounds = bounds.merge(box) if has_bounds else box
						has_bounds = true
		staging.free()
		largest_slice_ms=maxf(largest_slice_ms,float(Time.get_ticks_usec()-started)/1000)
		notify("placing","正在布置新区 %d%%"%roundi(float(count)/maxi(1,int(spec.nodes))*100),float(count)/maxi(1,int(spec.nodes)))
	region_bytes=PackedByteArray();loaded[id]=region;camera_shadow_materials[id]=shadow_materials
	if has_bounds:
		visual_bounds[id] = bounds
	if game.hero_interactions:game.hero_interactions.sync_streamed_actors()
	if game.game_ready:
		await game.shader_warmup.prepare_tree(region,id)
		region.show();await get_tree().physics_frame
	finish(id,true)
	print("WEB_REGION_READY id=",id," nodes=",count," chunks=",chunks.size()," max_slice_ms=",snappedf(largest_slice_ms,.1))
	return true

func finish(id:String,success:bool,code:int=0):
	pending.erase(id);downloading=false
	if success:failures.erase(id)
	else:failures[id]=code
	if failures.is_empty():notify("region-ready","")
	else:notify("region-error","新区加载失败（%s），可重试；当前位置已保留。"%("网络中断" if code==0 else "HTTP "+str(code)))
	retry.visible=not failures.is_empty();changed.emit()

func retry_failed():
	var ids=failures.keys();failures.clear();retry.hide()
	for id in ids:await ensure(id)


func _physics_process(_delta):
	if not game.game_ready:return
	if game.player.free_camera:
		var point=game.player.camera.global_position;var camera_region=id_at(point)
		if loaded.has(camera_region) and not pending.has(camera_region):last_safe_camera=point
		else:
			if last_safe_camera!=Vector3.INF:game.player.camera.global_position=last_safe_camera
			if not pending.has(camera_region) and not failures.has(camera_region):ensure(camera_region)
		return
	last_safe_camera=game.player.camera.global_position
	var id=id_at(game.player.global_position)
	if loaded.has(id) and not pending.has(id):last_safe=game.player.global_position
	else:
		game.player.global_position=last_safe;game.player.velocity=Vector3.ZERO
		if not pending.has(id) and not failures.has(id):ensure(id)

func _process(delta):
	if fetch_bridge!=null and fetch_bridge.retryRequested:
		fetch_bridge.retryRequested=false
		if not failures.is_empty():retry_failed()
	if active_fetch!=null and download_bytes>0:
		status.text="正在下载新区 %d%%%s"%[clampi(roundi(float(active_fetch.received)/download_bytes*100),0,99)," · 正在重试" if int(active_fetch.attempt)>1 else ""]
		progress_clock+=delta
		if progress_clock>.25:
			progress_clock=0
			if OS.has_feature("web"):fetch_bridge.notify("regions",status.text,minf(.99,float(active_fetch.received)/download_bytes))
	if not game.game_ready:return
	var modal=game.hero_interactions.modal_active or game.campus_agent.panel_open
	status_row.visible=not modal or get_viewport().get_visible_rect().size.y>=350
	shadow_clock+=delta
	if shadow_clock>.1:
		shadow_clock=0
		var camera=game.get_viewport().get_camera_3d()
		if camera:
			for materials in camera_shadow_materials.values():
				for material in materials:material.set_shader_parameter("main_camera",camera.global_position)
	if modal:return # Do not insert unrelated world geometry while opening/reading dialogue.
	clock+=delta
	if clock<.7:return
	clock=0
	var point=game.player.camera.global_position if game.player.free_camera else game.player.global_position
	var view := get_viewport().get_camera_3d()
	var eye: Vector3 = view.global_position if view else point
	var ids=manifest.regions.keys();ids.sort_custom(func(a,b):return distance_to(a,point)<distance_to(b,point))
	for id in ids:
		if id=="global" or id in manifest.core or distance_to(id,point)<85:
			if not loaded.has(id) and not pending.has(id) and not failures.has(id):ensure(id)
	var protected=""
	if game.hero_interactions and not game.hero_interactions.active_id.is_empty():
		protected=game.hero_interactions.region_for_npc(game.hero_interactions.active_id)
	for id in loaded.keys():
		if pending.has(id):continue
		if id in manifest.core or id==protected or id==id_at(game.player.global_position) or distance_to(id,point)<240:continue
		if not region_faded_out(id, eye):continue
		if game.hero_interactions:game.hero_interactions.remove_region_actors(id)
		loaded[id].queue_free();loaded.erase(id);camera_shadow_materials.erase(id)
		visual_bounds.erase(id)
	var required={}
	for id in loaded:
		for path in manifest.regions[id].get("shared",[]):required[path]=true
	if not downloading:
		for path in shared_resources.keys():
			if not required.has(path):shared_resources.erase(path)

func region_faded_out(id: String, eye: Vector3) -> bool:
	if not visual_bounds.has(id):
		return true
	# Meshes may cross their cell boundary. Wait for the actual closest geometry.
	var bounds: AABB = visual_bounds[id]
	var closest := eye.clamp(bounds.position, bounds.end)
	var fade_end: float = game.live_environment.fog_depth_end
	return eye.distance_squared_to(closest) >= fade_end * fade_end

