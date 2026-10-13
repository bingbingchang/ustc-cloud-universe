extends Node3D
const LOOP_SECONDS=32.0
const UPPER_ARM_LENGTH=.29
const FOREARM_TO_HAND=.28
const PAPER_SURFACE_OFFSET=.021
var bones={}
var rest={}
var standing=false
var roadside=false
var expression=""
var last_state={}
var passerby:Node3D
var attention_until=-10.0
var next_attention=10.0
var _attention_start=-10.0
var _attention_direction=-1.0
var _validation_mode=false
var _arm_errors={}
var face_materials=[]
var _eye_down=0.0

func prepare():
	bones.clear();rest.clear();face_materials.clear()
	for n in find_children("*","Node3D",true,false):
		if n.name.begins_with("Tiku_"):
			var key=String(n.name).trim_prefix("Tiku_")
			bones[key]=n;rest[key]=n.transform
	_cache_face_materials()

func _cache_face_materials():
	for mesh_node in find_children("*","MeshInstance3D",true,false):
		if mesh_node.mesh==null:continue
		for surface in range(mesh_node.mesh.get_surface_count()):
			var mat=mesh_node.get_surface_override_material(surface)
			if mat is ShaderMaterial and mat.shader and mat.shader.resource_path.ends_with("tiku_face.gdshader"):
				# Uniforms belong to this actor, even if two variants share a GLB.
				var own_material=mat.duplicate()
				mesh_node.set_surface_override_material(surface,own_material)
				face_materials.append(own_material)

func arm(side:String,target:Vector3,pole_hint=Vector3.ZERO):
	var upper=bones["Arm"+side];var fore=bones["Fore"+side]
	var start=upper.position;var delta=target-start
	var d=clampf(delta.length(),.03,UPPER_ARM_LENGTH+FOREARM_TO_HAND-.001)
	var direction=delta.normalized() if delta.length_squared()>.000001 else Vector3.DOWN
	var pole=Vector3(-1 if side=="L" else 1,-.35,.4)
	if target.y>.4:pole=Vector3(-.3 if side=="L" else .3,-1.0,-.2)
	if pole_hint.length_squared()>.00001:pole=pole_hint
	var bend=pole-direction*direction.dot(pole)
	if bend.length_squared()<.00001:bend=direction.cross(Vector3.FORWARD)
	bend=bend.normalized()
	var along=(UPPER_ARM_LENGTH*UPPER_ARM_LENGTH-FOREARM_TO_HAND*FOREARM_TO_HAND+d*d)/(2*d)
	var elbow=start+direction*along+bend*sqrt(maxf(0,UPPER_ARM_LENGTH*UPPER_ARM_LENGTH-along*along))
	upper.quaternion=Quaternion(Vector3.DOWN,(elbow-start).normalized())
	var reached=start+direction*d
	fore.quaternion=upper.quaternion.inverse()*Quaternion(Vector3.DOWN,(reached-elbow).normalized())
	var actual=upper.transform*(fore.transform*Vector3(0,-FOREARM_TO_HAND,0))
	_arm_errors[side]=actual.distance_to(target)

func _orient_hand(side:String,root_basis:Basis):
	if bones.has("Hand"+side):
		var fore_basis=bones["Arm"+side].basis*bones["Fore"+side].basis
		bones["Hand"+side].basis=fore_basis.inverse()*root_basis

func _hand_point(side:String,point:Vector3)->Vector3:
	if bones.has("Hand"+side):
		return bones["Arm"+side].transform*(bones["Fore"+side].transform*(bones["Hand"+side].transform*point))
	return bones["Arm"+side].transform*(bones["Fore"+side].transform*Vector3(0,-FOREARM_TO_HAND,0))

func pulse(t:float,a:float,b:float,edge=.5)->float:
	return smoothstep(a,a+edge,t)*(1.0-smoothstep(b-edge,b,t))

func _restore_pose():
	for key in bones:bones[key].transform=rest[key]
	_arm_errors.clear()

func _spine(lean:float,sway:float,breath:float):
	# Neck, head and shoulders move with the sweater instead of floating above it.
	# Positive lean explicitly moves the crown toward -Z, the character's front.
	var spine=Basis(Quaternion(Vector3.UP,Vector3(0,cos(lean),-sin(lean))))*Basis.from_euler(Vector3(0,0,sway))
	for key in ["Torso","Head","ArmL","ArmR"]:
		bones[key].transform=Transform3D(spine*rest[key].basis,spine*rest[key].origin)
	bones.Torso.scale.y*=1.0+breath*.0025

func _head(pitch:float,yaw:float,roll:float,look:float,down:float=0.0):
	# Define downward gaze in vectors so Blender/Godot Euler conventions cannot
	# turn a study bow into a chin-up pose after asset import.
	var down_gaze=Basis.looking_at(Vector3(0,-sin(pitch),-cos(pitch)),Vector3.UP)
	bones.Head.basis=bones.Head.basis*Basis.from_euler(Vector3(0,yaw,roll))*down_gaze
	if expression=="neutral":
		bones.Head.basis=rest.Head.basis;look=0.0;down=0.0
	elif expression=="side_eye":
		bones.Head.basis=rest.Head.basis*Basis.from_euler(Vector3(0,.035,0));look=-1.0;down=0.0
	elif expression=="thinking":
		bones.Head.basis=rest.Head.basis*Basis.from_euler(Vector3(-.02,-.025,.02));look=-.15;down=0.0
	for side in ["L","R"]:
		bones["Pupil"+side].position.x=rest["Pupil"+side].origin.x+look*.013
	if face_materials.is_empty():_cache_face_materials()
	_eye_down=down
	for mat in face_materials:
		mat.set_shader_parameter("eye_look",look)
		mat.set_shader_parameter("eye_down",down)

func _attention(t:float)->Vector2:
	# A nearby person can prompt a brief look; eyes lead the head by 0.16 seconds.
	if not _validation_mode and is_instance_valid(passerby) and t>next_attention:
		if global_position.distance_to(passerby.global_position)<6.5:
			_attention_start=t;attention_until=t+1.3;next_attention=t+18.0
			_attention_direction=1.0 if to_local(passerby.global_position).x>0 else -1.0
	if not _validation_mode and t>=_attention_start and t<attention_until:
		var elapsed=t-_attention_start
		return Vector2(pulse(elapsed,0,1.3,.18),pulse(elapsed,.16,1.25,.23))*_attention_direction
	return Vector2.ZERO

func pose(t:float):
	if bones.is_empty():prepare()
	_restore_pose()
	var p=fposmod(t,LOOP_SECONDS)
	var breath=sin(p*TAU/8.0)
	var think=pulse(p,8.0,11.5,.7)
	var eyes=-pulse(p,11.55,13.0,.16)+pulse(p,28.8,30.1,.20)*.70
	var head_look=-pulse(p,11.73,12.92,.25)+pulse(p,28.98,30.02,.27)*.70
	var attention=_attention(t)
	if absf(attention.x)>absf(eyes):eyes=attention.x;head_look=attention.y
	var glasses=pulse(p,13.2,16.2,.85)
	var page=pulse(p,20.0,23.2,.55)
	var fatigue=pulse(p,25.8,28.4,.9)
	var write_weight=0.0
	var paper_contact=0.0
	var mode="seated"
	var activity="writing"
	var torso_lean=0.0
	var grip_error=0.0

	if roadside:
		mode="roadside";activity="quiet_standing"
		think=pulse(p,3.0,7.0,1.0)
		eyes=-pulse(p,9.0,10.4,.18)+pulse(p,23.8,25.0,.20)*.65
		head_look=-pulse(p,9.2,10.34,.25)+pulse(p,24.0,24.94,.27)*.65
		if absf(attention.x)>absf(eyes):eyes=attention.x;head_look=attention.y
		glasses=pulse(p,11.3,14.0,.85)
		fatigue=pulse(p,18.0,22.0,1.2);page=0.0
		torso_lean=.035-fatigue*.018
		_spine(torso_lean,sin(p*TAU/32.0)*.012,breath)
		_head(.025-think*.055+fatigue*.035,-head_look*.035,0,eyes)
		bones.LegL.rotation=Vector3.ZERO;bones.LegR.rotation=Vector3.ZERO
		bones.KneeL.rotation=Vector3.ZERO;bones.KneeR.rotation=Vector3.ZERO
		# Vertical book against the left ribs, held by the forearm.
		bones.Book.visible=true;bones.Book.position=Vector3(-.177,.277,-.025)
		bones.Book.rotation=Vector3(0,0,PI*.5)
		bones.Page.visible=false;bones.Pen.visible=false
		arm("L",Vector3(-.207,.205,-.025),Vector3(-.10,-1.0,.2))
		var right_hand=Vector3(.19,-.035,.006)
		var frame=bones.Head.transform*Vector3(.084,.19,-.103)
		var glasses_hand=bones.Head.basis*Basis.from_euler(Vector3(0,0,PI))
		var glasses_palm=frame-glasses_hand*Vector3(.017,-.045,-.018)
		arm("R",right_hand.lerp(glasses_palm,glasses))
		if bones.has("HandR"):
			var relaxed=bones.ArmR.basis*bones.ForeR.basis
			_orient_hand("R",Basis(relaxed.get_rotation_quaternion().slerp(glasses_hand.get_rotation_quaternion(),glasses)))
		if think>.1:activity="holding_a_thought"
		if absf(eyes)>.1:activity="side_eye"
		if glasses>.1:activity="adjusting_glasses"
		if fatigue>.1:activity="slow_exhale"
	elif standing:
		# Static identity proof stays motionless at every sample time.
		mode="static_proof";activity="static_identity_check"
		think=0.0;eyes=0.0;head_look=0.0;glasses=0.0;page=0.0;fatigue=0.0
		_head(0,0,0,0)
		for side in ["L","R"]:
			bones["Leg"+side].rotation=Vector3.ZERO;bones["Knee"+side].rotation=Vector3.ZERO
			bones["Arm"+side].rotation=Vector3(-.05,0,.045 if side=="L" else -.045);bones["Fore"+side].rotation=Vector3(.06,0,0)
		bones.Book.visible=false;bones.Pen.visible=false;bones.Page.visible=false
	else:
		torso_lean=.16-think*.085-fatigue*.105
		_spine(torso_lean,sin(p*TAU/32.0)*.003,breath)
		# Eyes follow the page while working and lift before the thinking/glance
		# gestures.  Extra head pitch is limited to five degrees while focused.
		var study_focus=1.0-maxf(think,maxf(absf(eyes),maxf(glasses,fatigue)))
		_head(.34+deg_to_rad(5.0)*study_focus-think*.24-glasses*.20-fatigue*.25,-head_look*.04,think*.008,eyes,.014*study_focus)
		bones.LegL.rotation.x=1.20;bones.LegR.rotation.x=1.25
		bones.KneeL.rotation.x=-1.20;bones.KneeR.rotation.x=-1.25
		bones.Book.visible=true;bones.Book.position=Vector3(0,.005,-.25)
		bones.Page.rotation.z=PI*smoothstep(20.5,22.75,p);bones.Page.visible=p>20.5 and p<22.75
		bones.Page.rotation.x=sin(p*TAU/4.0)*.007
		var pause=maxf(think,maxf(absf(eyes),maxf(glasses,maxf(page,fatigue))))
		write_weight=1.0-pause
		# Integer harmonics close both stroke position and velocity at 32 seconds.
		var tip=Vector3(.062+sin(p*TAU*22.0/32.0)*.007*write_weight,bones.Book.position.y+PAPER_SURFACE_OFFSET+.001,-.275+sin(p*TAU*29.0/32.0)*.007*write_weight)
		tip.y+=pause*.025
		bones.Pen.position=tip;bones.Pen.visible=true
		var pen_direction=Vector3(.36,.86,.36).normalized()
		pen_direction.x+=sin(p*TAU*22.0/32.0)*.015*write_weight
		bones.Pen.quaternion=Quaternion(Vector3(.022,.13,.022).normalized(),pen_direction.normalized())
		var writing_hand=Basis.from_euler(Vector3(.42,.10,-.08))
		var pinch_local=Vector3(-.008,-.028,-.028)
		var grip=tip+pen_direction.normalized()*.030
		arm("R",grip-writing_hand*pinch_local)
		_orient_hand("R",writing_hand)
		grip_error=_hand_point("R",pinch_local).distance_to(grip) if bones.has("HandR") else 0.0
		var pin_hand=Basis.from_euler(Vector3(1.05,0,.05))
		var hand=Vector3(-.095,.045,-.24)
		hand=hand.lerp(Vector3(-.015,.064,-.255),page)
		var frame=bones.Head.transform*Vector3(-.084,.19,-.103)
		var glasses_hand=bones.Head.basis*Basis.from_euler(Vector3(0,0,PI))
		var glasses_palm=frame-glasses_hand*Vector3(-.017,-.045,-.018)
		hand=hand.lerp(glasses_palm,glasses)
		arm("L",hand)
		_orient_hand("L",Basis(pin_hand.get_rotation_quaternion().slerp(glasses_hand.get_rotation_quaternion(),glasses)))
		paper_contact=absf(tip.y-(bones.Book.position.y+PAPER_SURFACE_OFFSET)) if write_weight>.95 else 0.0
		if think>.1:activity="thinking"
		if absf(eyes)>.1:activity="side_eye"
		if glasses>.1:activity="adjusting_glasses"
		if page>.1:activity="turning_page"
		if fatigue>.1:activity="resting_back_and_wrist"

	var finite=true
	for key in bones:finite=finite and bones[key].transform.is_finite()
	last_state={"time":t,"phase":p,"mode":mode,"activity":activity,"thinking":think,"side_eye":absf(eyes),"look_direction":eyes,"head_follow":head_look,"glasses":glasses,"page":page,"fatigue":fatigue,"writing":write_weight,"torso_lean_radians":torso_lean,"pen_tip":str(bones.Pen.position),"paper_contact_error_m":paper_contact,"arm_target_error_m":_arm_errors.duplicate(),"finite":finite,"cycle_seconds":LOOP_SECONDS,"cycle_pose_periodic":not is_instance_valid(passerby) or _validation_mode,"external_attention_active":t>=_attention_start and t<attention_until and not _validation_mode}
	last_state["head_forward"]=str(-bones.Head.basis.z)
	last_state["head_shift_front_m"]=rest.Head.origin.z-bones.Head.position.z
	last_state["painted_face_materials"]=face_materials.size()
	last_state["pinch_to_pen_error_m"]=grip_error
	last_state["eye_down_uv"]=_eye_down

func validate_loop()->Dictionary:
	# Compare actual transforms and restore the current displayed pose afterwards.
	if bones.is_empty():prepare()
	var saved_time=float(last_state.get("time",0.0))
	_validation_mode=true
	pose(0.0)
	var start={}
	for key in bones:start[key]=bones[key].transform
	pose(LOOP_SECONDS)
	var position_error=0.0;var basis_error=0.0
	for key in bones:
		position_error=maxf(position_error,start[key].origin.distance_to(bones[key].position))
		for axis in range(3):basis_error=maxf(basis_error,start[key].basis[axis].distance_to(bones[key].basis[axis]))
	var result={"duration_seconds":LOOP_SECONDS,"position_error_m":position_error,"basis_error":basis_error,"closed":position_error<.00001 and basis_error<.00001,"external_attention_excluded":true}
	_validation_mode=false;pose(saved_time)
	return result
