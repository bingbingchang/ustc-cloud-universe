extends SceneTree

# Run only after the game's final scene/assets are imported. Uses the real
# SpringArm gameplay camera, then samples fixed points of courtyard paving.
const OUT="res://../renders/shadow_band/"
const Z_POSITIONS=[196.0,202.0,208.0,214.0]
const VIEWS=[
	{"id":"third_default","third_person":true,"pitch":-.18},
	{"id":"third_down","third_person":true,"pitch":-.40},
	{"id":"third_steep","third_person":true,"pitch":-.68},
	{"id":"first_person","third_person":false,"pitch":-.18},
]
var campus:Node3D
var player:CharacterBody3D
var camera:Camera3D
var ground_points:Array[Vector3]=[]
var report={"method":"Freeze the world and sunlight. Move the real gameplay camera through the courtyard. Project the same 24 cm ground patches into each native image and compare their luminance. A moving cascade cutoff changes a fixed patch's light level; a real building shadow remains tied to world geometry.",
	"profiles":[],"groups":[],"screenshots":[],"checks":{}}

func _initialize():call_deferred("run")

func freeze_motion(n:Node):
	n.set_process(false)
	n.set_physics_process(false)
	if n is AnimationPlayer:n.pause()
	for child in n.get_children():freeze_motion(child)

func frames(count:int):
	for i in range(count):await process_frame
	await RenderingServer.frame_post_draw

func percentile(values:Array,fraction:float)->float:
	if values.is_empty():return 0.0
	var copy=values.duplicate();copy.sort()
	return float(copy[mini(copy.size()-1,int((copy.size()-1)*fraction))])

func set_pose(view:Dictionary,z:float):
	if player.third_person!=view.third_person:player.toggle_view()
	player.set_view(Vector3(0,.15,z),Vector3(0,1,z-15))
	player.pitch=float(view.pitch)
	player.arm.rotation.x=float(view.pitch)
	camera.current=true
	await frames(20)

func luminance(image:Image,point:Vector3)->float:
	if camera.is_position_behind(point):return -1.0
	var screen=camera.unproject_position(point)
	if screen.x<3 or screen.y<3 or screen.x>=image.get_width()-3 or screen.y>=image.get_height()-3:return -1.0
	var color=image.get_pixel(int(screen.x),int(screen.y))
	return color.r*.2126+color.g*.7152+color.b*.0722

func sample_ground(image:Image)->Dictionary:
	var samples={}
	for i in range(ground_points.size()):
		var point=ground_points[i]
		# Reject pixels where a wall/tree hides the requested ground patch.
		# The extension follows the same ray, retaining the exact X/Z sample.
		var direction=(point-camera.global_position).normalized()
		var query=PhysicsRayQueryParameters3D.create(camera.global_position,point+direction,1,[player.get_rid()])
		var hit=camera.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.position.distance_to(point)>.4 or hit.normal.y<.8:continue
		var values=[]
		for dx in [-.12,0.0,.12]:
			for dz in [-.12,0.0,.12]:
				var value=luminance(image,point+Vector3(dx,0,dz))
				if value>=0:values.append(value)
		if values.size()!=9:continue
		var sum=0.0
		for v in values:sum+=float(v)
		samples[str(i)]=sum/values.size()
	return samples

func group_metrics(observations:Dictionary)->Dictionary:
	var ranges=[];var unstable=[];var count=0
	for key in observations:
		var values:Array=observations[key]
		if values.size()<2:continue
		count+=1
		var delta=float(values.max())-float(values.min());ranges.append(delta)
		if delta>.08:
			var p=ground_points[int(key)]
			unstable.append({"world":[p.x,p.y,p.z],"min_luminance":values.min(),"max_luminance":values.max(),"range":delta,"observed_pose_count":values.size()})
	return {"comparable_ground_patches":count,"p50_luminance_range":percentile(ranges,.50),
		"p95_luminance_range":percentile(ranges,.95),"max_luminance_range":percentile(ranges,1.0),
		"patches_changed_over_008":unstable.size(),"changed_fraction":float(unstable.size())/maxi(count,1),
		"worst_patches":unstable.slice(0,16)}

func capture_group(profile:String,quality:String,view:Dictionary)->Dictionary:
	var observations={};var poses=[]
	for z in Z_POSITIONS:
		await set_pose(view,float(z))
		var image=root.get_texture().get_image()
		var filename="regression_%s_%s_%s_z%d.png"%[profile,quality,view.id,int(z)]
		var err=image.save_png(OUT+filename)
		var samples=sample_ground(image)
		for key in samples:
			if not observations.has(key):observations[key]=[]
			observations[key].append(samples[key])
		poses.append({"player_z":z,"camera_position":[camera.global_position.x,camera.global_position.y,camera.global_position.z],
			"camera_pitch":view.pitch,"sample_count":samples.size()})
		report.screenshots.append({"file":filename,"saved":err==OK,"size":[image.get_width(),image.get_height()]})
	var result=group_metrics(observations)
	result.merge({"profile":profile,"quality":quality,"view":view.id,"poses":poses})
	print("SHADOW_REGRESSION ",profile," ",quality," ",view.id," p95=",result.p95_luminance_range," fraction=",result.changed_fraction)
	return result

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if DisplayServer.get_name()=="headless":
		push_error("Shadow regression requires native graphics rendering; headless cannot validate shadow images.");quit(2);return
	campus=load("res://scenes/campus_game.tscn").instantiate();root.add_child(campus)
	await frames(30)
	player=campus.player;camera=player.camera
	player.frozen=true;player.enabled=false;campus.hud.visible=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	freeze_motion(campus)
	var fixed_sun=campus.sun.global_transform
	report.sun_rotation_degrees=[campus.sun.rotation_degrees.x,campus.sun.rotation_degrees.y,campus.sun.rotation_degrees.z]
	report.viewport=[root.size.x,root.size.y]
	report.samples=[]
	# The central six metres are excluded: the character and its moving shadow
	# must not be mistaken for the building's camera-dependent clipping.
	for x in [-12.0,-9.0,-6.0,6.0,9.0,12.0]:
		for i in range(85):
			var p=Vector3(x,.095,188.0+i*.35)
			var query=PhysicsRayQueryParameters3D.create(p+Vector3.UP*2,p-Vector3.UP,1,[player.get_rid()])
			var ground=camera.get_world_3d().direct_space_state.intersect_ray(query)
			if ground.is_empty() or ground.normal.y<.8 or ground.position.y<-.1 or ground.position.y>.35:continue
			p.y=ground.position.y+.015;ground_points.append(p)
			report.samples.append([p.x,p.y,p.z])
	var settings_ok=true
	for quality in ["balanced","quality"]:
		for profile in ["original","final"]:
			campus.apply_quality(quality=="balanced")
			if profile=="original":
				campus.sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				campus.sun.directional_shadow_blend_splits=false
				campus.sun.directional_shadow_pancake_size=20.0
			else:
				settings_ok=settings_ok and campus.sun.directional_shadow_mode==DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and campus.sun.directional_shadow_blend_splits and campus.sun.directional_shadow_pancake_size>=120.0
			report.profiles.append({"id":profile,"quality":quality,"mode":campus.sun.directional_shadow_mode,
				"blend_splits":campus.sun.directional_shadow_blend_splits,"pancake_size":campus.sun.directional_shadow_pancake_size,
				"shadow_distance":campus.sun.directional_shadow_max_distance})
			for view in VIEWS:report.groups.append(await capture_group(profile,quality,view))
	report.comparisons=[]
	var stable_count=0;var reproduced=false;var meaningful_improvement=false
	for quality in ["balanced","quality"]:
		for view in VIEWS:
			var before={};var after={}
			for g in report.groups:
				if g.quality==quality and g.view==view.id:
					if g.profile=="original":before=g
					else:after=g
			var stable=after.comparable_ground_patches>=30 and after.p95_luminance_range<.08 and after.changed_fraction<.06
			if stable:stable_count+=1
			if before.p95_luminance_range>.08 or before.changed_fraction>.06:reproduced=true
			if before.p95_luminance_range>.08 and after.p95_luminance_range<before.p95_luminance_range*.55:meaningful_improvement=true
			report.comparisons.append({"quality":quality,"view":view.id,"original_p95":before.p95_luminance_range,
				"final_p95":after.p95_luminance_range,"original_changed_fraction":before.changed_fraction,
				"final_changed_fraction":after.changed_fraction,"final_world_shadow_stable":stable})
	report.checks={"final_settings_loaded":settings_ok,"sun_frozen":campus.sun.global_transform.is_equal_approx(fixed_sun),
		"original_camera_dependent_shadow_reproduced":reproduced,"measured_reduction_in_ground_light_changes":meaningful_improvement,
		"all_eight_final_gameplay_views_have_stable_world_shadows":stable_count==8,
		"native_images_saved":report.screenshots.all(func(s):return s.saved)}
	report.passed=not report.checks.values().has(false)
	var file=FileAccess.open(OUT+"validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SHADOW_CHECKS ",JSON.stringify(report.checks))
	quit(0 if report.passed else 1)
