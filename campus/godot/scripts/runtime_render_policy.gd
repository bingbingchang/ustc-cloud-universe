extends Node
## Gameplay-only visibility policy. Original assets, placement and contacts stay intact.
var game
var vegetation:Array=[]
var water_watchers:Array=[]
var water_ray_exclusions: Array[RID] = []
var reflection_clock=1.0
var policy_clock=1.0
var reflection_updates=0
var reflection_skipped=0
var policy_cursor=0
var last_policy_position=Vector3.INF
var sky_clock=0.0
var water_visibility_elapsed=1.0
var visible_water_cached=true
var water_test_position := Vector3.INF
var last_reflection_camera := Transform3D.IDENTITY

func _ready():
	game.get_viewport().mesh_lod_threshold=1.0
	if is_instance_valid(game.reflection_view):game.reflection_view.mesh_lod_threshold=5.0
	if game.live_environment and game.live_environment.sky:
		game.live_environment.sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
	water_ray_exclusions.append(game.player.get_rid())
	for node in game.world.get_children():
		if node is StaticBody3D and (str(node.name).begins_with("NorthNoEntryWater_") or node.get_meta("water_entry_barrier",false)):
			# These volumes keep characters out of the pond. Rays for
			# reflection visibility should pass through them.
			water_ray_exclusions.append(node.get_rid())
		if node is MultiMeshInstance3D and node.has_meta("render_asset"):
			var asset=str(node.get_meta("render_asset"))
			var tree=is_tree(asset)
			if tree or is_detail(asset):
				node.visibility_range_end=420.0 if tree else 90.0
				node.visibility_range_end_margin=12.0 if tree else 8.0
				vegetation.append({"node":node,"tree":tree,"sakura":asset.begins_with("sakura_tree"),"bounds":node.global_transform*node.get_aabb()})
			if node.visibility_range_end > 0.0 and node.visibility_range_end_margin > 0.0:
				# The paired LOD setup below takes precedence for near/far replacements.
				node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if node is MeshInstance3D and node.visible and (node.get_meta("lake_water",false) or str(node.name).begins_with("NorthWater")):
			var watcher=VisibleOnScreenNotifier3D.new();watcher.name="MainCameraWaterVisibility"
			watcher.layers=1 # The reflection camera only sees REFLECTION_LAYER.
			watcher.aabb=node.get_aabb().grow(.12);node.add_child(watcher);water_watchers.append(watcher)
	add_mapped_occluders()
	if not "--no-static-batches" in OS.get_cmdline_user_args():
		var boxes=preload("res://scripts/static_box_batches.gd").new();boxes.game=game;add_child(boxes)
	if not "--no-tree-hlod" in OS.get_cmdline_user_args():
		var hlod=preload("res://scripts/tree_hlod.gd").new();hlod.game=game;add_child(hlod)
	if not "--no-detail-hlod" in OS.get_cmdline_user_args():
		var detail=preload("res://scripts/detail_hlod.gd").new();detail.game=game;add_child(detail)
	print("RUNTIME_RENDER_POLICY vegetation_batches=",vegetation.size()," water_regions=",water_watchers.size())

func is_tree(asset:String)->bool:
	return asset.begins_with("tree") or asset.begins_with("sakura_tree") or asset.begins_with("study_canopy") or asset.begins_with("lake_willow") or asset=="study_willow_bough"

func is_detail(asset:String)->bool:
	for word in ["flower","shrub","grass","bank","reed","lotus"]:
		if word in asset:return true
	return false

func active_camera()->Camera3D:
	return game.get_viewport().get_camera_3d()

func _process(delta):
	sky_clock+=delta
	if sky_clock>=10.0 and game.live_environment and game.live_environment.sky:
		game.live_environment.sky.sky_material.set_shader_parameter("sky_time",Time.get_ticks_msec()/1000.0)
		sky_clock=0.0
	policy_clock+=delta
	var camera=active_camera()
	if not is_instance_valid(camera):return
	if policy_cursor>=vegetation.size():
		if camera.global_position.distance_to(last_policy_position)<2.0:return
		policy_cursor=0;last_policy_position=camera.global_position;policy_clock=0
	var started=Time.get_ticks_usec()
	while policy_cursor<vegetation.size():
		var item=vegetation[policy_cursor];policy_cursor+=1
		var node=item.node
		if not is_instance_valid(node):continue
		var bounds:AABB=item.bounds
		var closest=Vector3(clampf(camera.global_position.x,bounds.position.x,bounds.end.x),clampf(camera.global_position.y,bounds.position.y,bounds.end.y),clampf(camera.global_position.z,bounds.position.z,bounds.end.z))
		var distance=camera.global_position.distance_to(closest)
		# Petal LOD error is ~0.1 m. With bias 1 it only becomes eligible beyond
		# the HLOD switch, so it never provided the intended middle distance tier.
		var near_range=7.0 if item.sakura else 9.0
		# A canopy's bounding box can contain a ground-level camera even when
		# every petal is well overhead. That falsely pinned it to full detail.
		var lod_distance=camera.global_position.distance_to(bounds.get_center()) if item.sakura else distance
		var wanted_lod=1.0 if lod_distance<near_range else (.12 if item.tree else .4)
		if not is_equal_approx(node.lod_bias,wanted_lod):node.lod_bias=wanted_lod
		var shadow_range=16.0 if node.get_meta("runtime_hlod",false) else (65.0 if item.tree else 12.0)
		var wanted_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if distance<shadow_range else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if node.cast_shadow!=wanted_shadow:node.cast_shadow=wanted_shadow
		if Time.get_ticks_usec()-started>1500:break

func update_reflection():
	if not is_instance_valid(game.reflection_view):return
	reflection_clock+=get_process_delta_time()
	var camera=active_camera()
	if not is_instance_valid(camera):return
	var visible_water=water_watchers.is_empty()
	for watcher in water_watchers:
		if is_instance_valid(watcher) and watcher.is_visible_in_tree() and watcher.is_on_screen():visible_water=true;break
	water_visibility_elapsed+=get_process_delta_time()
	if visible_water and (water_visibility_elapsed >= .2 or camera.global_position.distance_to(water_test_position) > 2.0):
		visible_water_cached=screen_has_visible_water(camera);water_visibility_elapsed=0
		water_test_position = camera.global_position
	visible_water=visible_water and (visible_water_cached or reflection_updates==0)
	if not visible_water:
		game.reflection_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		reflection_skipped+=1;return
	var close_water=false
	for watcher in water_watchers:
		if not is_instance_valid(watcher) or not watcher.is_on_screen():continue
		var surface: MeshInstance3D = watcher.get_parent()
		var bounds := surface.global_transform * surface.get_aabb()
		var closest: Vector3 = camera.global_position.clamp(bounds.position,bounds.end)
		if camera.global_position.distance_to(closest)<85.0:
			close_water=true;break
	var moving: bool = not camera.global_transform.is_equal_approx(last_reflection_camera)
	# The shader animates ripples each frame; the secondary scene pass is capped.
	var frequency=(12.0 if game.balanced else 20.0) if close_water else 8.0
	if not moving:frequency=4.0
	if reflection_clock<1.0/frequency:return
	game.reflection_view.size=(Vector2i(512,288) if game.balanced else Vector2i(768,432)) if close_water else Vector2i(256,144)
	game.render_reflection_frame()
	last_reflection_camera=camera.global_transform
	game.reflection_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	reflection_clock=0;reflection_updates+=1

func screen_has_visible_water(camera:Camera3D)->bool:
	if water_watchers.is_empty():return true
	var rectangles=[]
	for watcher in water_watchers:
		if is_instance_valid(watcher) and watcher.is_on_screen():
			var surface=watcher.get_parent();rectangles.append(surface.global_transform*surface.get_aabb())
	var size=camera.get_viewport().get_visible_rect().size
	var space=game.get_world_3d().direct_space_state
	for row in range(7):
		for column in range(10):
			var pixel=size*Vector2((column+.5)/10.0,.35+row*.1)
			var origin=camera.project_ray_origin(pixel);var direction=camera.project_ray_normal(pixel)
			if direction.y>=-.001:continue
			for bounds in rectangles:
				var height=bounds.get_center().y;var distance=(height-origin.y)/direction.y
				if distance<=.05 or distance>camera.far:continue
				var point=origin+direction*distance
				if point.x<bounds.position.x or point.x>bounds.end.x or point.z<bounds.position.z or point.z>bounds.end.z:continue
				var query=PhysicsRayQueryParameters3D.create(origin,point+Vector3.UP*.012,1,water_ray_exclusions)
				if space.intersect_ray(query).is_empty():
					game.reflection_plane_height=height
					return true
	return false

func add_mapped_occluders():
	if OS.has_feature("web"):return # Standard Web templates omit raycast occlusion.
	var path="res://assets/full_districts_manifest.json"
	if not FileAccess.file_exists(path):return
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(path))
	var count=0
	var door_heads: Dictionary = {}
	for solid in manifest.get("collision_solids",[]):
		if float(solid.top)-float(solid.bottom)<4:continue
		if game.campus_visits and game.campus_visits.opened_shell("MappedBuilding_"+str(solid.name)):
			continue
		var model_name := (str(solid.name).get_slice("_",0)+"_"+str(solid.name).get_slice("_",1)).to_pascal_case()
		if not door_heads.has(model_name):
			var head := 0.0
			var model: Node3D = game.world.get_node_or_null(model_name)
			if model:
				for piece in model.get_children():
					if piece is MeshInstance3D and str(piece.name).get_slice(".",0).ends_with("_PhotoDoorGlass"):
						var bounds: AABB = piece.global_transform * piece.get_aabb()
						head = maxf(head,bounds.end.y+.04)
			door_heads[model_name]=head
		var low := maxf(float(solid.bottom)+.15,door_heads[model_name])
		var high := float(solid.top)-.25
		if high <= low:
			continue
		var polygon=PackedVector2Array()
		for point in solid.polygon:polygon.append(Vector2(point[0],point[1]))
		# Use inward-offset real collision outlines, preserving concave courtyards.
		for inset in Geometry2D.offset_polygon(polygon,-.25):
			if inset.size()<3:continue
			var vertices=PackedVector3Array();var indices=PackedInt32Array();var n=inset.size()
			for y in [low,high]:
				for point in inset:vertices.append(Vector3(point.x,y,point.y))
			var triangles=Geometry2D.triangulate_polygon(inset)
			for i in range(0,triangles.size(),3):
				indices.append_array(PackedInt32Array([triangles[i],triangles[i+2],triangles[i+1],triangles[i]+n,triangles[i+1]+n,triangles[i+2]+n]))
			for i in range(n):
				var j=(i+1)%n
				indices.append_array(PackedInt32Array([i,j,j+n,i,j+n,i+n]))
			var occluder=ArrayOccluder3D.new();occluder.set_arrays(vertices,indices)
			var instance=OccluderInstance3D.new();instance.name="MappedOpaqueOccluder_"+str(count);instance.occluder=occluder
			game.world.add_child(instance);count+=1
	game.world.set_meta("runtime_mapped_occluders",count)
