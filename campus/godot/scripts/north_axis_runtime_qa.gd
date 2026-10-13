extends RefCounted
## Native CharacterBody3D integration proof, independent of the capture pipeline.
const North=preload("res://scripts/north_axis_environment.gd")
const OUT="res://../renders/north_axis/runtime_qa.json"

func vector(value:Array)->Vector3:return Vector3(value[0],value[1],value[2])

func ray(c:Node3D,p:Vector2,top:float,bottom:float)->Dictionary:
	var q=PhysicsRayQueryParameters3D.create(Vector3(p.x,top,p.y),Vector3(p.x,bottom,p.y));q.exclude=[c.player.get_rid()]
	return c.get_world_3d().direct_space_state.intersect_ray(q)

func walk(c:Node3D,id:String,points:Array)->Dictionary:
	var p=c.player;p.frozen=false;p.enabled=true;p.free_camera=false
	p.set_view(points[0]+Vector3.UP*.10,points[1]+Vector3.UP*1.65)
	for k in range(8):await c.get_tree().physics_frame
	var steps=0;var min_y=p.position.y;var max_y=p.position.y;var reached=true;var segments=[];var blockers=[];var trace=[]
	var max_horizontal_step=0.0;var max_world_step=0.0;var travelled=0.0;var horizontal_contacts=[]
	for target in points.slice(1):
		var distance=Vector2(p.position.x-target.x,p.position.z-target.z).length()
		var budget=int(ceil(distance/1.8*60))+150
		var hit=false;var last_position=p.position;var stalled=0
		p.set_view(p.position,Vector3(target.x,p.position.y+1.65,target.z));Input.action_press("forward")
		for frame in range(budget):
			var delta=target-p.position
			p.rotation.y=atan2(-delta.x,-delta.z)
			await c.get_tree().physics_frame;steps+=1;min_y=minf(min_y,p.position.y);max_y=maxf(max_y,p.position.y)
			var displacement=p.position-last_position
			var horizontal_step=Vector2(displacement.x,displacement.z).length()
			max_horizontal_step=maxf(max_horizontal_step,horizontal_step);max_world_step=maxf(max_world_step,displacement.length());travelled+=horizontal_step
			if frame%2==0:
				var contacts=[]
				for j in range(p.get_slide_collision_count()):
					var contact=p.get_slide_collision(j);var normal=contact.get_normal();var cp=contact.get_position()
					contacts.append({"body":String(contact.get_collider().name),"shape":contact.get_collider_shape(),"normal":[normal.x,normal.y,normal.z],"at":[cp.x,cp.y,cp.z]})
					if absf(normal.y)<.5 and not String(contact.get_collider().name) in horizontal_contacts:horizontal_contacts.append(String(contact.get_collider().name))
				trace.append({"step":steps,"at":[p.position.x,p.position.y,p.position.z],"velocity":[p.velocity.x,p.velocity.y,p.velocity.z],"yaw":p.rotation.y,"floor":p.is_on_floor(),"wall":p.is_on_wall(),"forward_strength":Input.get_action_strength("forward"),"window_focus":c.get_window().has_focus(),"enabled":p.enabled,"frozen":p.frozen,"contacts":contacts})
				if trace.size()>150:trace.pop_front()
			# Use a close waypoint tolerance so a curve test follows the real bends.
			if Vector2(p.position.x-target.x,p.position.z-target.z).length()<.14:hit=true;break
			if p.position.distance_to(last_position)<.002:stalled+=1
			else:stalled=0
			last_position=p.position
			if stalled>90:
				for j in range(p.get_slide_collision_count()):
					var other=p.get_slide_collision(j).get_collider()
					if other and not String(other.name) in blockers:blockers.append(String(other.name))
				break
		Input.action_release("forward")
		segments.append({"target":[target.x,target.y,target.z],"reached":hit,"remaining_m":Vector2(p.position.x-target.x,p.position.z-target.z).length()})
		if not hit:reached=false;break
	p.frozen=true
	var result={"id":id,"reached":reached,"min_feet_y":min_y,"max_feet_y":max_y,"physics_steps":steps,"final":[p.position.x,p.position.y,p.position.z],"segments":segments,"blockers":blockers}
	result.continuous=max_horizontal_step<.15 and max_world_step<.5
	result.max_horizontal_step_m=max_horizontal_step;result.max_world_step_m=max_world_step;result.travelled_horizontal_m=travelled
	result.horizontal_contacts=horizontal_contacts
	if not reached:result.failure_trace=trace
	print("NORTH_WALK ",id," ",reached," steps=",steps," final=",p.position)
	return result

func push_barrier(c:Node3D,id:String,start:Vector3,target:Vector3,forbidden:PackedVector2Array)->Dictionary:
	var p=c.player;p.frozen=false;p.enabled=true;p.free_camera=false
	p.set_view(start+Vector3.UP*.10,target+Vector3.UP*1.65)
	for k in range(8):await c.get_tree().physics_frame
	Input.action_press("forward")
	var steps=int(start.distance_to(target)/1.8*60)+150;var contacts=[]
	for k in range(steps):
		await c.get_tree().physics_frame
		for j in range(p.get_slide_collision_count()):
			var other=p.get_slide_collision(j).get_collider()
			if other and not String(other.name) in contacts:contacts.append(String(other.name))
	Input.action_release("forward");p.frozen=true
	var inside=Geometry2D.is_point_in_polygon(Vector2(p.position.x,p.position.z),forbidden)
	var remaining=Vector2(p.position.x-target.x,p.position.z-target.z).length()
	return {"id":id,"blocked":not inside and remaining>.35,"entered_forbidden":inside,"remaining_m":remaining,"final":[p.position.x,p.position.y,p.position.z],"contacts":contacts}

func validate(c:Node3D)->Dictionary:
	var start_ms=Time.get_ticks_msec();var checks={};var d=North.layout()
	var report={"scope":"Imported native Godot world, existing human-scale CharacterBody3D, physical movement and rays","checks":checks,"walk_speed_mps":1.8,"physics_ticks_per_second":240,"time_scale":4,"integration_dt_seconds":1.0/60.0}
	# Freeze the five wanderers at their story homes while retaining their collisions.
	c.life_layer.manual_time=0;c.life_layer.pose(0);c.life_layer.set_process(false)
	c.wave2_layer.manual_time=0;c.wave2_layer.pose_story(0);c.wave2_layer.set_process(false)
	var actor_layers=[]
	for id in c.wave2_layer.actors:
		var actor_collision=c.wave2_layer.actors[id].collision
		actor_layers.append([actor_collision,actor_collision.collision_layer]);actor_collision.collision_layer=0
	report.actor_collision_policy="Five wanderers frozen at story homes; only their bodies are temporarily excluded to isolate static-world route validation. Separate wander proof retains obstacle checks."
	c.player.frozen=true;c.player.enabled=false
	await c.get_tree().physics_frame;await c.get_tree().physics_frame
	var missing=[];var sampled=0;var outer=North.polygon(d.polygon);var skipped_edge=0
	for x in range(int(d.bounds[0])+1,int(d.bounds[2]),2):
		for z in range(int(d.bounds[1])+1,143,2):
			var p=Vector2(x+.173,z+.237)
			if not North.contains(p):continue
			var near_edge=false
			for i in range(outer.size()):
				var a=outer[i];var b=outer[(i+1)%outer.size()]
				var port=(is_equal_approx(a.y,118) and is_equal_approx(b.y,118)) or (is_equal_approx(a.x,80) and is_equal_approx(b.x,80))
				if not port and p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))<.45:near_edge=true
			if near_edge:skipped_edge+=1;continue
			sampled+=1
			if ray(c,p,.35,-.18).is_empty():missing.append([p.x,p.y])
	checks.continuous_land=missing.is_empty();report.ground_samples=sampled;report.missing_ground=missing;report.outer_edge_clearance_exclusions=skipped_edge
	var water_missing=[];var water_samples=0;var grass_over_water=[];var water_over_island=[]
	for pond in d.ponds:
		var poly=North.polygon(pond.outer);var bounds=North._bounds(poly)
		for x in range(int(bounds.position.x),int(bounds.end.x),2):
			for z in range(int(bounds.position.y),int(bounds.end.y),2):
				var p=Vector2(x+.21,z+.19)
				if not North._inside_pond(p,d):continue
				var h=ray(c,p,6,-.2);water_samples+=1
				if h.is_empty() or h.position.y<.2:water_missing.append([p.x,p.y])
	for node in c.world.get_children():
		if not (node is MeshInstance3D) or not node.mesh or node.mesh.get_surface_count()==0:continue
		if not String(node.name).begins_with("NorthAxisLand") and not String(node.name).begins_with("NorthWater_"):continue
		var vertices=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in range(0,vertices.size(),3):
			var center=node.to_global((vertices[i]+vertices[i+1]+vertices[i+2])/3.0);var p=Vector2(center.x,center.z)
			if String(node.name).begins_with("NorthAxisLand") and North._inside_pond(p,d):grass_over_water.append([p.x,p.y])
			if String(node.name).begins_with("NorthWater_") and not North._inside_pond(p,d):water_over_island.append([p.x,p.y])
	checks.water_exclusion=water_missing.is_empty();checks.visible_lake_holes=grass_over_water.is_empty() and water_over_island.is_empty()
	report.water_samples=water_samples;report.water_gaps=water_missing;report.grass_triangles_over_water=grass_over_water;report.water_triangles_over_island=water_over_island
	Engine.physics_ticks_per_second=240;Engine.time_scale=4
	var routes=[]
	for route in d.walk_routes:
		var points=[]
		for p in route.points:points.append(vector(p))
		if route.id=="west_spur":
			# The finite deck ends here; capsule centers must stop before the water edge.
			points[-1]=points[-1].move_toward(points[-2],.65)
		routes.append(await walk(c,route.id,points))
	# A genuine bridge->pavilion->other bridge traversal. The six columns stand
	# inward of the six vertices; enter beside them rather than aiming at a column.
	routes.append(await walk(c,"through_pavilion",[
		Vector3(26.703,.08,63.899),Vector3(28.635,.34,65.95),Vector3(34.35,.34,67.971),Vector3(36.413,.34,70.165),Vector3(40.32,.34,71.405),Vector3(42.539,.34,74.046),Vector3(43.025,.34,76.044),
		Vector3(41.7,.34,77.0),Vector3(41.3,.34,78.4),Vector3(42.501,.34,80.789),Vector3(44.8,.34,78.0),Vector3(45.9,.34,78.45),Vector3(46.521,.34,78.591),
		Vector3(52.296,.34,78.799),Vector3(57.33,.34,78.383),Vector3(59.275,.34,76.32),Vector3(60.468,.34,75.573),Vector3(68.84,.34,75.64),Vector3(76.804,.08,80.538)]))
	routes.append(await walk(c,"union_east_seam",[Vector3(84,.08,142),Vector3(84,.08,145),Vector3(84,.08,150),Vector3(78,.08,151),Vector3(73,.10,158)]))
	routes.append(await walk(c,"north_seam_to_hall",[Vector3(0,.08,112),Vector3(0,.08,121),Vector3(0,.08,148),Vector3(0,.10,159),Vector3(0,.10,164.2)]))
	routes.append(await walk(c,"core_west_lawn",[Vector3(-31,.02,146),Vector3(-39,.02,147),Vector3(-54,.02,147)]))
	routes.append(await walk(c,"core_courtyard_lawn",[Vector3(-26,.02,205),Vector3(-18,.02,209),Vector3(-11,.02,215)]))
	checks.actual_walk_routes=routes.all(func(r):return r.reached and r.min_feet_y>-.15 and r.continuous);report.routes=routes
	report.continuity_policy="Each original waypoint must be reached within .14m; no in-route relocation; maximum horizontal displacement <.15m and world displacement <.50m per physics tick, allowing the existing .30m low-step helper. Route starts are explicitly placed before observation."
	var barriers=[]
	barriers.append(await push_barrier(c,"west_water",Vector3(-12,.08,95),Vector3(-29,.08,95),North.polygon(d.ponds[0].outer)))
	barriers.append(await push_barrier(c,"east_water",Vector3(10,.08,102),Vector3(24,.08,102),North.polygon(d.ponds[1].outer)))
	var building_tests={"expert_house":[Vector3(72,0,37),Vector3(72,0,24)],"hightech_north":[Vector3(-30,0,27),Vector3(-47,0,25)],"residential_1":[Vector3(130,0,112),Vector3(130,0,125)],"residential_2":[Vector3(130,0,81),Vector3(130,0,67)]}
	for building in d.buildings:
		var test=building_tests[building.id];barriers.append(await push_barrier(c,building.id,test[0],test[1],North.polygon(building.polygon)))
	# Forbidden half planes lie just outside the measured display edges.
	barriers.append(await push_barrier(c,"outer_north",Vector3(40,0,-18),Vector3(40,0,-24),North._rect(-200,-100,400,80)))
	barriers.append(await push_barrier(c,"outer_east",Vector3(176,0,96),Vector3(182,0,96),North._rect(178,-30,100,240)))
	barriers.append(await push_barrier(c,"outer_south_residential",Vector3(135,0,141),Vector3(135,0,147),North._rect(105,143,90,80)))
	checks.forbidden_regions_blocked=barriers.all(func(b):return b.blocked);report.barrier_tests=barriers
	Engine.time_scale=1;Engine.physics_ticks_per_second=60
	for entry in actor_layers:entry[0].collision_layer=entry[1]
	c.player.frozen=true;c.player.enabled=false
	report.elapsed_wall_seconds=(Time.get_ticks_msec()-start_ms)/1000.0;report.passed=not checks.values().has(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../renders/north_axis"))
	var file=FileAccess.open(OUT,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("NORTH_RUNTIME_QA ",JSON.stringify(checks))
	return report
