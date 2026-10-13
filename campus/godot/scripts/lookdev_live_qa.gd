extends "res://scripts/north_axis_runtime_qa.gd"
## Reuses the native walker, continuity diagnostics, ray and barrier primitives.
## Never calls either archived validator: their output paths and quit are fixed.
const LIVE_DIR="res://../renders/lookdev_live/"
const VISUAL_LAYER=1<<20

func save_live(name:String,value):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LIVE_DIR))
	var file=FileAccess.open(LIVE_DIR+name,FileAccess.WRITE);file.store_string(JSON.stringify(value,"\t"));file.close()

func _reference_hashes()->Dictionary:
	var result={}
	for name in ["runtime_qa.json","validation.json","bridge_exit_fix.json","runtime_qa_failed_before_followup.json","runtime_qa_failed_with_trace.json"]:
		var path="res://../renders/north_axis/"+name
		if FileAccess.file_exists(path):result[path]=FileAccess.get_sha256(path)
	return result

func _asset_hashes()->Dictionary:
	var hashes={}
	for version in ["accepted_v0_4","accepted_v0_5"]:
		var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://../benchmarks/"+version+"/manifest.json"))
		for path in manifest.frozen_sha256:hashes[path]=FileAccess.get_sha256("res://../"+path)==manifest.frozen_sha256[path]
	return {"files":hashes,"count":hashes.size(),"passed":hashes.size()==59 and not hashes.values().has(false)}

func _geometry(c:Node3D)->Dictionary:
	var d=North.layout();var missing=[];var count=0;var excluded=0;var outer=North.polygon(d.polygon)
	for x in range(int(d.bounds[0])+1,int(d.bounds[2]),2):
		for z in range(int(d.bounds[1])+1,143,2):
			var p=Vector2(x+.173,z+.237)
			if not North.contains(p):continue
			var edge=false
			for i in range(outer.size()):
				var a=outer[i];var b=outer[(i+1)%outer.size()]
				var port=(is_equal_approx(a.y,118) and is_equal_approx(b.y,118)) or (is_equal_approx(a.x,80) and is_equal_approx(b.x,80))
				if not port and p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))<.45:edge=true
			if edge:excluded+=1;continue
			count+=1
			if ray(c,p,.35,-.18).is_empty():missing.append([p.x,p.y])
	var water_samples=0;var water_gaps=[]
	for pond in d.ponds:
		var bounds=North._bounds(North.polygon(pond.outer))
		for x in range(int(bounds.position.x),int(bounds.end.x),2):
			for z in range(int(bounds.position.y),int(bounds.end.y),2):
				var p=Vector2(x+.21,z+.19)
				if not North._inside_pond(p,d):continue
				water_samples+=1;var hit=ray(c,p,6,-.2)
				if hit.is_empty() or hit.position.y<.2:water_gaps.append([p.x,p.y])
	var wrong_triangles=[]
	for node in c.world.get_children():
		if not (node is MeshInstance3D) or not node.mesh or node.mesh.get_surface_count()==0:continue
		if not String(node.name).begins_with("NorthAxisLand") and not String(node.name).begins_with("NorthWater_"):continue
		var vertices=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in range(0,vertices.size(),3):
			var p=node.to_global((vertices[i]+vertices[i+1]+vertices[i+2])/3.0);var wet=North._inside_pond(Vector2(p.x,p.z),d)
			if String(node.name).begins_with("NorthAxisLand")==wet:wrong_triangles.append([String(node.name),p.x,p.z])
	var core_samples=0;var core_missing=[]
	for x in range(-76,77,4):
		for z in range(122,236,4):
			var p=Vector2(x+.19,z+.17)
			if North._inside_pond(p,d):continue
			core_samples+=1
			if ray(c,p,.35,-.18).is_empty():core_missing.append([p.x,p.y])
	return {"ground_samples":count,"missing_ground":missing,"outer_wall_exclusions":excluded,"water_samples":water_samples,"water_gaps":water_gaps,"wrong_surface_triangles":wrong_triangles,"core_samples":core_samples,"core_missing":core_missing,"passed":missing.is_empty() and water_gaps.is_empty() and wrong_triangles.is_empty() and core_missing.is_empty()}

func _pose(c:Node3D,t:float):
	c.life_layer.pose(t);c.wave2_layer.pose(t)

func _population(c:Node3D)->Dictionary:
	var totals={"Hero":0,"Ambient":0,"Creature":0};var entries=[]
	for layer in [c.life_layer,c.wave2_layer]:
		for id in layer.registry:
			var r=layer.registry[id];totals[r.tier]+=1;entries.append({"layer":layer,"id":id,"tier":r.tier})
	var violations=[]
	for t in range(0,361,12):
		_pose(c,t)
		for ax in entries:
			for az in entries:
				var x=ax.layer.actors[ax.id].root.position.x;var z=az.layer.actors[az.id].root.position.z;var counts={"Hero":0,"Ambient":0,"Creature":0}
				for actor in entries:
					var p=actor.layer.actors[actor.id].root.position
					if p.x>=x and p.x<=x+100 and p.z>=z and p.z<=z+100:counts[actor.tier]+=1
				for tier in counts:
					if counts[tier]>c.life_layer.budgets[tier]:violations.append({"time":t,"tier":tier,"count":counts[tier]})
	return {"count":entries.size(),"tiers":totals,"density_violations":violations,"passed":entries.size()==14 and totals=={"Hero":4,"Ambient":6,"Creature":4} and violations.is_empty()}

func _wander(c:Node3D)->Dictionary:
	var excluded=[c.player.get_rid()];var samples=[];var conflicts=[];var moving=true
	for body in c.world.find_children("*","PhysicsBody3D",true,false):
		if body is AnimatableBody3D:excluded.append(body.get_rid())
	for id in c.wave2_layer.actors:
		var duration=c.wave2_layer.wander.duration(id);var initial=c.wave2_layer.wander.sample(id,0).position
		var maximum=0.0;var max_speed=0.0;var phases=[];var count=0
		var shape=CapsuleShape3D.new();shape.radius=.18 if id=="leaf_cat" else .25;shape.height=.42 if id=="leaf_cat" else 1.35
		for step in range(int(duration*4)+1):
			var state=c.wave2_layer.wander.sample(id,step*.25);maximum=maxf(maximum,initial.distance_to(state.position));max_speed=maxf(max_speed,state.speed_mps)
			if not state.phase in phases:phases.append(state.phase)
			if state.phase!="walk":continue
			count+=1;var q=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.exclude=excluded;q.margin=.01
			q.transform=Transform3D(Basis.IDENTITY,state.position+Vector3.UP*(shape.height*.5+.04))
			for hit in c.get_world_3d().direct_space_state.intersect_shape(q,8):conflicts.append({"id":id,"time":step*.25,"obstacle":String(hit.collider.name),"at":[state.position.x,state.position.y,state.position.z]})
		moving=moving and maximum>3 and max_speed<=1.05 and "walk" in phases
		samples.append({"id":id,"period":duration,"max_displacement_m":maximum,"max_speed_mps":max_speed,"phases":phases,"walking_samples":count})
	return {"actors":samples,"conflicts":conflicts,"passed":samples.size()==5 and moving and conflicts.is_empty()}

func _extra_routes()->Array:
	return [
		{"id":"through_pavilion","points":[[26.703,.08,63.899],[28.635,.34,65.95],[34.35,.34,67.971],[36.413,.34,70.165],[40.32,.34,71.405],[42.539,.34,74.046],[43.025,.34,76.044],[41.7,.34,77],[41.3,.34,78.4],[42.501,.34,80.789],[44.8,.34,78],[45.9,.34,78.45],[46.521,.34,78.591],[52.296,.34,78.799],[57.33,.34,78.383],[59.275,.34,76.32],[60.468,.34,75.573],[68.84,.34,75.64],[76.804,.08,80.538]]},
		{"id":"union_east_seam","points":[[84,.08,142],[84,.08,145],[84,.08,150],[78,.08,151],[73,.10,158]]},
		{"id":"north_seam_to_hall","points":[[0,.08,112],[0,.08,121],[0,.08,148],[0,.10,159],[0,.10,164.2]]},
		{"id":"core_west_lawn","points":[[-31,.02,146],[-39,.02,147],[-54,.02,147]]},
		{"id":"core_courtyard_lawn","points":[[-26,.02,205],[-18,.02,209],[-11,.02,215]]}]

func _routes(c:Node3D)->Array:
	var results=[]
	for route in North.walk_routes()+_extra_routes():
		var points=[]
		for p in route.points:points.append(vector(p))
		if route.id=="west_spur":points[-1]=points[-1].move_toward(points[-2],.65)
		results.append(await walk(c,route.id,points))
	return results

func _barriers(c:Node3D)->Array:
	var d=North.layout();var results=[]
	results.append(await push_barrier(c,"west_water",Vector3(-12,.08,95),Vector3(-29,.08,95),North.polygon(d.ponds[0].outer)))
	results.append(await push_barrier(c,"east_water",Vector3(10,.08,102),Vector3(24,.08,102),North.polygon(d.ponds[1].outer)))
	var tests={"expert_house":[Vector3(72,0,37),Vector3(72,0,24)],"hightech_north":[Vector3(-30,0,27),Vector3(-47,0,25)],"residential_1":[Vector3(130,0,112),Vector3(130,0,125)],"residential_2":[Vector3(130,0,81),Vector3(130,0,67)]}
	for building in d.buildings:
		var pair=tests[building.id];results.append(await push_barrier(c,building.id,pair[0],pair[1],North.polygon(building.polygon)))
	results.append(await push_barrier(c,"outer_north",Vector3(40,0,-18),Vector3(40,0,-24),North._rect(-200,-100,400,80)))
	results.append(await push_barrier(c,"outer_east",Vector3(176,0,96),Vector3(182,0,96),North._rect(178,-30,100,240)))
	results.append(await push_barrier(c,"outer_south_residential",Vector3(135,0,141),Vector3(135,0,147),North._rect(105,143,90,80)))
	return results

func _visual_body(parent:Node3D,mesh:Mesh,transform:Transform3D)->StaticBody3D:
	var body=StaticBody3D.new();body.collision_layer=VISUAL_LAYER;body.collision_mask=0;parent.add_child(body);body.global_transform=transform
	var collision=CollisionShape3D.new();collision.shape=mesh.create_trimesh_shape();body.add_child(collision);return body

func _mesh_children(node:Node,result:Array):
	if node is MeshInstance3D and node.mesh:result.append(node)
	for child in node.get_children():_mesh_children(child,result)

func _visual_ray(c:Node3D,a:Vector3,b:Vector3,mask:int)->Dictionary:
	var query=PhysicsRayQueryParameters3D.create(a,b,mask);query.exclude=[c.player.get_rid()]
	return c.get_world_3d().direct_space_state.intersect_ray(query)

func _alignment(c:Node3D)->Dictionary:
	var temporary=Node3D.new();temporary.name="LookdevQA_VisualOnly";c.add_child(temporary)
	# A headless dummy RenderingServer returns identity for MultiMesh readback.
	# Use the exact CPU placement supplied to that upload plus the actual source
	# variant's mesh; the independent rays never use the authored collision radius.
	var records=c.world.get_meta("lookdev_tree_contacts",[]);var roots=[];var absent=[];var mesh_cache={};var stale=[]
	for body in c.world.find_children("*","StaticBody3D",true,false):
		if body.get_meta("lookdev_replaced_trunk",false):stale.append(String(body.get_path()))
	for index in range(records.size()):
		var item=records[index];var asset=String(item.get("actual_asset",item.get("asset","")))
		if not item.has("placement") or not item.placement is Transform3D or not c.asset_cache.has(asset):
			absent.append({"index":index,"asset":asset});continue
		if not mesh_cache.has(asset):
			var parts=[]
			for part in c.asset_cache[asset]:
				for surface in range(part.mesh.get_surface_count()):
					var material=part.mesh.surface_get_material(surface)
					if not material or not ("Trunk" in material.resource_name or "Bark" in material.resource_name):continue
					var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.mesh.surface_get_arrays(surface))
					parts.append({"mesh":mesh,"transform":part.transform})
			mesh_cache[asset]=parts
		for part in mesh_cache[asset]:_visual_body(temporary,part.mesh,item.placement*part.transform)
		roots.append({"batch":asset,"index":index,"origin":item.placement.origin})
	var architecture:Node=c.get_node_or_null(c.get_meta("lookdev_architecture_root",NodePath("World/Architecture")))
	if not architecture:architecture=c.world.find_child("Architecture",false,false)
	var meshes=[]
	if architecture:_mesh_children(architecture,meshes)
	for mesh in meshes:_visual_body(temporary,mesh.mesh,mesh.global_transform)
	await c.get_tree().physics_frame;await c.get_tree().physics_frame
	var tree_samples=[];var tree_failures=[]
	for item in roots:
		for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
			var center=item.origin+Vector3.UP*.65;var start=center+direction*2.0
			var visible=_visual_ray(c,start,center,VISUAL_LAYER)
			if visible.is_empty():continue
			var physical=_visual_ray(c,start,center,1)
			var error=999.0 if physical.is_empty() else visible.position.distance_to(physical.position)
			var row={"batch":item.batch,"instance":item.index,"direction":[direction.x,direction.z],"error_m":error,"visible_at":[visible.position.x,visible.position.y,visible.position.z],"physical_at":[] if physical.is_empty() else [physical.position.x,physical.position.y,physical.position.z],"body":"missing" if physical.is_empty() else String(physical.collider.name)}
			tree_samples.append(row)
			if error>.18:tree_failures.append(row)
	var entry_samples=[];var entry_failures=[]
	var points=c.get_meta("lookdev_entry_probe_points",[])
	if points.is_empty():
		for x in [-3.0,0.0,3.0]:
			for z in [165.0,165.6,166.2,166.8]:points.append(Vector2(x,z))
	for value in points:
		var p:Vector2=value if value is Vector2 else Vector2(value[0],value[1])
		var a=Vector3(p.x,1.1,p.y);var b=Vector3(p.x,-.25,p.y)
		var visible=_visual_ray(c,a,b,VISUAL_LAYER)
		if visible.is_empty():continue
		var physical=_visual_ray(c,a,b,1);var error=999.0 if physical.is_empty() else absf(physical.position.y-visible.position.y)
		var row={"at":[p.x,p.y],"visible_y":visible.position.y,"physical_y":null if physical.is_empty() else physical.position.y,"error_m":error}
		entry_samples.append(row)
		if error>.16:entry_failures.append(row)
	temporary.queue_free();await c.get_tree().physics_frame
	return {"method":"Temporary layer-21 triangle collision from actual source-variant mesh and exact CPU placement uploaded to the MultiMesh, avoiding identity readback from headless dummy RenderingServer. Production layer-1 rays compared at trunk height .65m and entry treads; collision radius is not used to create visual proof.","expected_tree_instances":c.tree_count,"tree_instances":roots.size(),"missing_source_records":absent,"old_trunk_bodies_remaining":stale,"tree_samples":tree_samples,"tree_failures":tree_failures,"entry_meshes":meshes.size(),"entry_samples":entry_samples,"entry_failures":entry_failures,"passed":records.size()==c.tree_count and roots.size()==records.size() and tree_samples.size()==roots.size()*4 and absent.is_empty() and stale.is_empty() and tree_failures.is_empty() and meshes.size()>0 and entry_samples.size()>=6 and entry_failures.is_empty()}

func validate(c:Node3D)->Dictionary:
	var started=Time.get_ticks_msec();var protected=_reference_hashes();var checks={}
	c.life_layer.set_process(false);c.wave2_layer.set_process(false);c.player.frozen=true;c.player.enabled=false
	await c.get_tree().physics_frame
	var assets=_asset_hashes();checks.fifty_nine_frozen_files=assets.passed
	var population=_population(c);checks.fourteen_population_and_density=population.passed
	var wander=_wander(c);checks.five_wanderers_and_clear_routes=wander.passed
	c.life_layer.pose(0);c.wave2_layer.pose_story(0)
	var actor_layers=[]
	for id in c.wave2_layer.actors:
		var body=c.wave2_layer.actors[id].collision;actor_layers.append([body,body.collision_layer]);body.collision_layer=0
	await c.get_tree().physics_frame
	var geometry=_geometry(c);checks.land_water_and_core_regression=geometry.passed
	var alignment=await _alignment(c);checks.actual_visual_collision_alignment=alignment.passed
	Engine.physics_ticks_per_second=240;Engine.time_scale=4
	var routes=await _routes(c);checks.seventeen_actual_continuous_routes=routes.size()==17 and routes.all(func(r):return r.reached and r.continuous and r.min_feet_y>-.15)
	var barriers=await _barriers(c);checks.nine_forbidden_region_tests=barriers.size()==9 and barriers.all(func(b):return b.blocked)
	Engine.time_scale=1;Engine.physics_ticks_per_second=60
	for row in actor_layers:row[0].collision_layer=row[1]
	c.player.frozen=true;c.player.enabled=false
	checks.north_axis_evidence_untouched=protected==_reference_hashes()
	var runtime={"geometry":geometry,"alignment":alignment,"routes":routes,"barriers":barriers,"walk_speed_mps":1.8,"integration_dt_seconds":1.0/60.0,"actor_policy":"Five wanderer bodies excluded only during static-world walk; preserved and separately checked in full route overlap proof.","passed":geometry.passed and alignment.passed and checks.seventeen_actual_continuous_routes and checks.nine_forbidden_region_tests}
	var report={"checks":checks,"passed":not checks.values().has(false),"frozen_assets":assets,"population":population,"wander":wander,"runtime":runtime,"protected_north_reports":protected,"elapsed_wall_seconds":(Time.get_ticks_msec()-started)/1000.0}
	save_live("runtime_qa.json",runtime);save_live("validation.json",report)
	print("LOOKDEV_LIVE_QA ",JSON.stringify(checks));return report
