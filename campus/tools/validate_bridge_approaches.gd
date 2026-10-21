extends SceneTree

const North=preload("res://scripts/north_axis_environment.gd")
const OUT="res://../renders/bridge_approaches/"
var campus
var player
var report={"routes":[],"checks":{},"surface_samples":0,"surface_mismatches":[]}

func _initialize():call_deferred("run")
func p3(p:Vector2,y:float)->Vector3:return Vector3(p.x,y,p.y)
func p2(p:Vector3)->Vector2:return Vector2(p.x,p.z)
func xyz(p:Vector3)->Array:return [p.x,p.y,p.z]

func frames(count:int):
	for i in range(count):
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		await physics_frame

func walk_route(id:String,points:Array)->Dictionary:
	player.frozen=false;player.enabled=true;player.set_free_camera(false)
	player.set_view(points[0]+Vector3.UP*.10,points[1]+Vector3.UP*1.4)
	await frames(20)
	var row={"id":id,"passed":true,"segments":[],"blockers":[],"min_feet_y":player.position.y,"max_world_step_m":0.0,"max_vertical_step_m":0.0}
	for target in points.slice(1):
		var budget=int(p2(player.position).distance_to(p2(target))/2.6*60)+150
		var reached=false;var stalled=0
		Input.action_press("forward")
		for frame in range(budget):
			var delta=target-player.position;player.orbit.rotation.y=atan2(-delta.x,-delta.z)
			var previous=player.position
			await frames(1)
			var step=player.position-previous
			row.min_feet_y=minf(row.min_feet_y,player.position.y)
			row.max_world_step_m=maxf(row.max_world_step_m,step.length())
			row.max_vertical_step_m=maxf(row.max_vertical_step_m,absf(step.y))
			if p2(player.position).distance_to(p2(target))<.14:reached=true;break
			stalled=stalled+1 if step.length()<.002 else 0
			if stalled>90:
				for j in range(player.get_slide_collision_count()):
					var name=String(player.get_slide_collision(j).get_collider().name)
					if name not in row.blockers:row.blockers.append(name)
				break
		Input.action_release("forward")
		row.segments.append({"target":xyz(target),"reached":reached,"remaining_m":p2(player.position).distance_to(p2(target))})
		if not reached:row.passed=false;break
	player.frozen=true;row.final=xyz(player.position)
	row.passed=row.passed and row.min_feet_y>-.10 and row.max_world_step_m<.15 and row.max_vertical_step_m<.05
	print("BRIDGE_WALK ",id," passed=",row.passed," final=",player.position)
	return row

func approach(bridge:Dictionary,end:String,offset:float):
	var profile=North._ramp_profile(bridge,end);var corners:PackedVector2Array=profile.corners
	var low=(corners[0]+corners[1])*.5;var high=(corners[2]+corners[3])*.5
	var low_side=(corners[0]-corners[1]).normalized();var high_side=(corners[3]-corners[2]).normalized()
	var pts=North.polygon(bridge.points);var tip=pts[0] if end=="start" else pts[-1]
	var inward=(pts[1]-tip).normalized() if end=="start" else (pts[-2]-tip).normalized()
	var outward=(low-high).normalized()
	var low_y:float=profile.heights[0]
	var route=[p3(high+inward*1.6+high_side*offset,bridge.top),p3(high+high_side*offset,bridge.top),p3(low+low_side*offset,low_y),p3(low+outward*.4+low_side*offset,low_y)]
	var id=String(bridge.id)+"_"+end+"_"+str(offset)
	report.routes.append(await walk_route(id+"_out",route));route.reverse()
	report.routes.append(await walk_route(id+"_in",route))

func check_surfaces():
	# Probe actual rendered triangle interiors against
	# the real scene's collision layer, rather than trusting profile data alone.
	for mesh in campus.world.get_children():
		if not mesh is MeshInstance3D or not mesh.has_meta("bridge_id"):continue
		var vertices=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for start in [0,3]:
			for weights in [Vector3(.2,.4,.4),Vector3(.4,.2,.4),Vector3(.4,.4,.2)]:
				var p=mesh.to_global(vertices[start]*weights.x+vertices[start+1]*weights.y+vertices[start+2]*weights.z)
				var hit=campus.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.5,p-Vector3.UP*.5,1))
				report.surface_samples+=1
				if hit.is_empty() or absf(hit.position.y-p.y)>.005:report.surface_mismatches.append({"bridge":mesh.get_meta("bridge_id"),"at":xyz(p)})
	report.checks.rendered_collision_alignment=report.surface_samples==24 and report.surface_mismatches.is_empty()

func run():
	# The dummy/headless display cannot capture the mouse, so the unchanged
	# gameplay controller intentionally ignores movement there. Use a native
	# window with 3D rendering disabled while testing real player input.
	if DisplayServer.get_name()=="headless":
		push_error("Run this player-input check without --headless; its viewport disables 3D during physics checks.");quit(2);return
	root.disable_3d=true
	# Preserve 1/60-second simulation steps while shortening this isolated run.
	Engine.time_scale=4;Engine.physics_ticks_per_second=240
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	campus=load("res://scenes/campus_game.tscn").instantiate();root.add_child(campus)
	player=campus.player;campus.set_process(false);player.frozen=true
	for layer_name in ["life_layer","wave2_layer","grove_life"]:
		var layer=campus.get(layer_name)
		if layer:layer.set_process(false)
	for body in campus.world.find_children("*","AnimatableBody3D",true,false):body.collision_layer=0
	if campus.hero_interactions:
		campus.hero_interactions.set_process(false);campus.hero_interactions.health_request.cancel_request()
	if campus.campus_agent:campus.campus_agent.set_process(false)
	await frames(3)
	check_surfaces()
	var ramps=0
	for bridge in North.layout().bridges:
		for end in bridge.ramps:
			ramps+=1
			var offsets=[-.55,0.0,.55] if bridge.id=="east_east" else [0.0]
			for offset in offsets:await approach(bridge,end,offset)
	report.checks.four_approaches=ramps==4
	report.checks.twelve_actual_third_person_routes=report.routes.size()==12 and report.routes.all(func(row):return row.passed)
	if "--bridge-capture" in OS.get_cmdline_user_args():
		Engine.time_scale=1;Engine.physics_ticks_per_second=60;Engine.max_fps=30
		root.disable_3d=false
		report.checks.native_screenshots=await load("res://../tools/capture_bridge_approach.gd").capture(campus,root)
	report.method="Actual campus_game, unmodified third_person_player, 1/60-second simulation. Four approaches walked both ways; east bridge includes center and +/-0.55m. No jumps or relocation during routes. Ambient actors paused only in this validation instance."
	report.passed=not report.checks.values().has(false)
	var path=OUT+"validation.json";var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BRIDGE_APPROACH_CHECKS ",JSON.stringify(report.checks)," report=",ProjectSettings.globalize_path(path))
	quit(0 if report.passed else 1)
