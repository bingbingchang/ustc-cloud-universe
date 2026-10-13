extends Node3D
## Original ambient cast. The caller owns world position, heading and shared time.
## Asset origin is the ground; forward is -Z. No root motion is applied here.
var role="cyclist"
var wheel_distance=-1.0 # Optional accumulated root travel in metres; negative uses closed default.
var reader_seat_y=.53 # Matches build_campus bench seat top, before scene placement.
var reader_ground_y=-.005 # Root at .08; shoes meet the rear pad surface at .075.
var bones={}
var rest={}
var _state={}
var _errors={}

func prepare():
	bones.clear();rest.clear()
	for n in find_children("*","Node3D",true,false):
		if String(n.name).begins_with("Ambient_"):
			var key=String(n.name).trim_prefix("Ambient_")
			bones[key]=n;rest[key]=n.transform
	return bones.size()

func _pulse(t:float,a:float,b:float,edge:float=.6)->float:
	return smoothstep(a,a+edge,t)*(1.0-smoothstep(b-edge,b,t))

func motion_state(t:float)->Dictionary:
	if role=="study_walk":
		var p=fposmod(t,46.0);var walking=0.0;var phase="reading"
		if p<10:walking=sin(PI*p/10.0);phase="walk_out"
		elif p>=23 and p<33:walking=sin(PI*(p-23)/10.0);phase="walk_back"
		elif (p>=20 and p<23) or p>=43:phase="turn_in_place"
		return {"phase":phase,"time":p,"cycle_seconds":46.0,"walking":walking,"speed_mps":.65*walking}
	if role=="photographer":
		var p=fposmod(t,22.0);var lift=smoothstep(2,4,p)*(1.0-smoothstep(15,17,p))
		var review=_pulse(p,17,22,1.0);var stepping=_pulse(p,18,21,.45)
		return {"phase":"photographing" if lift>.5 else "reviewing_phone" if review>.2 else "resting","time":p,"cycle_seconds":22.0,"phone_lift":lift,"review":review,"walking":stepping,"speed_mps":0.0}
	if role=="bench_reader":return {"phase":"reading","time":fposmod(t,32.0),"cycle_seconds":32.0,"walking":0.0,"speed_mps":0.0}
	var p=fposmod(t,64.0)
	var phase="ride";var speed=1.4;var push=0.0
	if p>=14.0 and p<18.0:phase="brake";speed=1.4*(1.0-smoothstep(14,18,p))
	elif p>=18.0 and p<22.0:phase="dismount";speed=0.0;push=smoothstep(18,22,p)
	elif p>=22.0 and p<29.0:phase="push";speed=.5;push=1.0
	elif p>=29.0 and p<38.0:phase="pause";speed=0.0;push=1.0
	elif p>=38.0 and p<45.0:phase="mount_turn";speed=0.0;push=1.0-smoothstep(39,44,p)
	elif p>=45.0 and p<59.0:phase="ride_back";speed=1.6
	elif p>=59.0 and p<62.0:phase="settle";speed=1.4*(1.0-smoothstep(59,62,p))
	elif p>=62.0:phase="reorient";speed=0.0
	return {"phase":phase,"time":p,"cycle_seconds":64.0,"speed_mps":speed,"push_weight":push,"seated_weight":1.0-push,"return_leg":p>=38.0}

func _restore():
	for key in bones:bones[key].transform=rest[key]
	_errors.clear()

func _spine(lean:float,sway:float,breath:float):
	var spine=Basis(Quaternion(Vector3.UP,Vector3(0,cos(lean),-sin(lean))))*Basis.from_euler(Vector3(0,0,sway))
	for key in ["Torso","Head","ArmL","ArmR"]:
		bones[key].transform=Transform3D(spine*rest[key].basis,spine*rest[key].origin)
	bones.Torso.scale.y*=1.0+breath*.002

func _solve(upper_key:String,lower_key:String,target:Vector3,l1:float,l2:float,pole:Vector3):
	var upper=bones[upper_key];var lower=bones[lower_key]
	var start=upper.position;var delta=target-start
	var d=clampf(delta.length(),absf(l1-l2)+.001,l1+l2-.001)
	var direction=delta.normalized() if delta.length_squared()>.000001 else Vector3.DOWN
	var bend=pole-direction*direction.dot(pole)
	if bend.length_squared()<.000001:bend=direction.cross(Vector3.RIGHT)
	bend=bend.normalized()
	var along=(l1*l1-l2*l2+d*d)/(2*d)
	var elbow=start+direction*along+bend*sqrt(maxf(0.0,l1*l1-along*along))
	upper.quaternion=Quaternion(Vector3.DOWN,(elbow-start).normalized())
	lower.quaternion=upper.quaternion.inverse()*Quaternion(Vector3.DOWN,(start+direction*d-elbow).normalized())
	var reached=upper.transform*(lower.transform*Vector3(0,-l2,0))
	_errors[upper_key]=reached.distance_to(target)

func _orient_tip(side:String,arm:bool,basis:Basis):
	var a=("Arm" if arm else "Leg")+side
	var b=("Fore" if arm else "Knee")+side
	var tip=("Hand" if arm else "Foot")+side
	bones[tip].basis=(bones[a].basis*bones[b].basis).inverse()*basis

func _endpoint(side:String,arm:bool)->Vector3:
	var a=("Arm" if arm else "Leg")+side
	var b=("Fore" if arm else "Knee")+side
	var tip=("Hand" if arm else "Foot")+side
	return bones.Human.transform*(bones[a].transform*(bones[b].transform*bones[tip].position))

func _ride_units(p:float)->float:
	# Integrated cadence; pedals stop for the route's 62-64 s in-place turn.
	if p<14:return p
	if p<18:
		var x=(p-14.0)/4.0
		return 14.0+4.0*(x-x*x*x+.5*x*x*x*x)
	if p<45:return 16.0
	if p<59:return 16.0+p-45.0
	if p>=62.0:return 31.5
	var x=(p-59.0)/3.0
	return 30.0+3.0*(x-x*x*x+.5*x*x*x*x)

func _pedal(side:String)->Vector3:
	return bones.Bike.transform*(bones.Crank.transform*bones["Pedal"+side].position)

func _cyclist(p:float):
	var motion=motion_state(p);var w=float(motion.push_weight)
	var breath=sin(p*TAU/8.0)
	var walking=_pulse(p,22,29,.6)
	var stride=sin((p-22)*TAU*3.0/7.0)*walking
	var human_pos=Vector3(0,.92,.16).lerp(Vector3(-.50,.731,.05),w)
	human_pos.y+=absf(stride)*.006*w
	bones.Human.position=human_pos
	_spine(lerpf(.34,.025,w),sin(p*TAU/16)*.008,breath)
	bones.Head.basis=bones.Head.basis*Basis.looking_at(Vector3(0,-sin(.05),-cos(.05)),Vector3.UP)
	bones.Head.rotation.y+=_pulse(p,31,34,1)*.09
	var crank_angle=TAU*18.0*_ride_units(p)/31.5
	bones.Crank.rotation.x=crank_angle
	for side in ["L","R"]:bones["Pedal"+side].rotation.x=-crank_angle
	var wheel_angle=wheel_distance/.34 if wheel_distance>=0 else TAU*(20.0*_ride_units(p)/31.5+clampf((p-22)/7.0,0,1)*2.0)
	bones.WheelFront.rotation.x=wheel_angle;bones.WheelRear.rotation.x=wheel_angle
	var pedal_errors={};var hand_errors={};var ankle_positions={}
	for side in ["L","R"]:
		var s=-1.0 if side=="L" else 1.0
		var pedal=_pedal(side)
		var riding_ankle=pedal+Vector3(0,.075,.043)
		var standing_ankle=human_pos+Vector3(s*.073,.064-human_pos.y,-.025+stride*s*.135)
		standing_ankle.y+=maxf(0,stride*s)*.035
		var target=riding_ankle.lerp(standing_ankle,w)
		# Lift the outside leg while moving off/onto the saddle, not a seated push.
		if side=="L":target.y+=sin(w*PI)*.075
		_solve("Leg"+side,"Knee"+side,bones.Human.transform.affine_inverse()*target,.36,.34,Vector3(0,0,-1))
		_orient_tip(side,false,Basis())
		pedal_errors[side]=_endpoint(side,false).distance_to(riding_ankle)
		ankle_positions[side]=_endpoint(side,false)
		var riding_hand=Vector3(s*.25,1.04,-.43)
		var push_hand=Vector3(-.25,1.04,-.43) if side=="R" else human_pos+Vector3(-.16,-.12,-.01-stride*.04)
		var hand_target=riding_hand.lerp(push_hand,w)
		_solve("Arm"+side,"Fore"+side,bones.Human.transform.affine_inverse()*hand_target,.28,.27,Vector3(s,-.2,.25))
		_orient_tip(side,true,Basis())
		hand_errors[side]=_endpoint(side,true).distance_to(hand_target)
	_state=motion.duplicate()
	_state.merge({"role":role,"pelvis":bones.Human.position,"pedal_contact_m":pedal_errors,"hand_target_error_m":hand_errors,"ankles":ankle_positions,"on_saddle":w<.05,"walking":walking,"root_motion_applied":false})

func _reader(p:float):
	var look=_pulse(p,13,18,1.1)
	var breath=sin(p*TAU/8.0)
	var page_up=smoothstep(5,9,p);var page_return=smoothstep(23,27,p)
	bones.Human.position=Vector3(sin(p*TAU/32)*.006,reader_seat_y+.10,0)
	_spine(.105-look*.035,sin(p*TAU/32)*.008,breath)
	bones.Head.basis=bones.Head.basis*Basis.looking_at(Vector3(0,-sin(.26-look*.25),-cos(.26-look*.25)),Vector3.UP)
	bones.Head.rotation.y+=look*.07
	bones.Book.position=Vector3(0,.025,-.28)
	bones.Page.rotation.z=PI*(page_up-page_return)
	var page=_pulse(p,5,9,.7)+_pulse(p,23,27,.7)
	var feet={};var hands={}
	for side in ["L","R"]:
		var s=-1.0 if side=="L" else 1.0
		var foot_target=Vector3(s*.08,reader_ground_y+.064,-.48)
		_solve("Leg"+side,"Knee"+side,bones.Human.transform.affine_inverse()*foot_target,.42,.50,Vector3(0,0,-1))
		_orient_tip(side,false,Basis())
		feet[side]=_endpoint(side,false).y-.064-reader_ground_y
		var hand_target=Vector3(s*.095,.068,-.28)
		if side=="R":hand_target+=Vector3(-.03,.035,.015)*page
		_solve("Arm"+side,"Fore"+side,hand_target,.28,.27,Vector3(s,-.2,.2))
		_orient_tip(side,true,Basis.from_euler(Vector3(PI*.5,0,0)))
		hands[side]=float(_errors["Arm"+side])
		bones["Pupil"+side].position.x=rest["Pupil"+side].origin.x+look*.002
	_state={"role":role,"phase":"looking_up" if look>.2 else "turning_page" if page>.2 else "reading","time":p,"cycle_seconds":32.0,"page":page,"look_up":look,"foot_ground_error_m":feet,"hand_target_error_m":hands,"seat_height_m":reader_seat_y,"ground_y":reader_ground_y,"root_motion_applied":false}

func _standing_feet(p:float,walking:float,cycle:float,lateral:bool=false)->Dictionary:
	var wave=sin(p*PI)*walking
	bones.Human.position=Vector3(sin(p*TAU/cycle)*.006,.731+absf(wave)*.006,0)
	var feet={}
	for side in ["L","R"]:
		var s=-1.0 if side=="L" else 1.0
		var target=Vector3(s*.080,.064+maxf(0,wave*s)*.03,-.01)
		if lateral:target.x+=wave*s*.052
		else:target.z+=wave*s*.13
		_solve("Leg"+side,"Knee"+side,bones.Human.transform.affine_inverse()*target,.36,.34,Vector3(0,0,-1))
		_orient_tip(side,false,Basis())
		feet[side]=_endpoint(side,false).distance_to(target)
	return feet

func _photographer(p:float):
	var motion=motion_state(p);var lift=float(motion.phone_lift);var review=float(motion.review)
	var feet=_standing_feet(p,float(motion.walking),22.0,true)
	_spine(.025+review*.035,sin(p*TAU/22)*.01,sin(p*TAU*3/22))
	bones.Head.basis=bones.Head.basis*Basis.looking_at(Vector3(0,-sin(.04+review*.23),-cos(.04+review*.23)),Vector3.UP)
	bones.Head.rotation.y+=sin(p*TAU/22)*.035*lift
	bones.Phone.position=Vector3(.015,.13,-.24).lerp(Vector3(0,.56,-.36),lift)
	bones.Phone.position=bones.Phone.position.lerp(Vector3(0,.30,-.29),review)
	bones.Phone.rotation=Vector3(-.10*review,.025*sin(p*TAU/22)*lift,.025*(1-lift))
	var hands={}
	for side in ["L","R"]:
		var s=-1.0 if side=="L" else 1.0
		var target=bones.Phone.transform*Vector3(s*.047,-.026,.004)
		_solve("Arm"+side,"Fore"+side,target,.28,.27,Vector3(s,-.3,.2))
		_orient_tip(side,true,bones.Phone.basis)
		hands[side]=_endpoint(side,true).distance_to(bones.Human.transform*target)
	_state=motion.duplicate()
	_state.merge({"role":role,"hand_target_error_m":hands,"foot_target_error_m":feet,"phone_position":bones.Phone.position,"shutter":_pulse(p,7.8,8.2,.1)+_pulse(p,11.5,11.9,.1),"root_motion_applied":false})

func _study_walker(p:float):
	var motion=motion_state(p);var walking=float(motion.walking)
	var feet=_standing_feet(p,walking,46.0)
	_spine(.055,sin(p*TAU/46)*.008,sin(p*TAU*6/46))
	var down=.23-walking*.10
	bones.Head.basis=bones.Head.basis*Basis.looking_at(Vector3(0,-sin(down),-cos(down)),Vector3.UP)
	bones.Book.position=Vector3(0,.18,-.265)
	bones.Book.rotation.x=.43
	var flip_a=smoothstep(14,16,p);var flip_b=smoothstep(36,38,p)
	bones.Page.rotation.z=PI*(flip_a-flip_b)
	var page=_pulse(p,14,16,.35)+_pulse(p,36,38,.35)
	var hands={}
	for side in ["L","R"]:
		var s=-1.0 if side=="L" else 1.0
		var grip=Vector3(s*.12,.027,.033)
		if side=="R":grip+=Vector3(-.02,.030,-.01)*page
		var target=bones.Book.transform*grip
		_solve("Arm"+side,"Fore"+side,target,.28,.27,Vector3(s,-.3,.2))
		_orient_tip(side,true,bones.Book.basis*Basis.from_euler(Vector3(PI*.5,0,0)))
		hands[side]=_endpoint(side,true).distance_to(bones.Human.transform*target)
	_state=motion.duplicate()
	_state.merge({"role":role,"hand_target_error_m":hands,"foot_target_error_m":feet,"page":page,"book_position":bones.Book.position,"root_motion_applied":false})

func pose(t:float):
	if bones.is_empty():prepare()
	_restore()
	if role=="bench_reader":_reader(fposmod(t,32.0))
	elif role=="photographer":_photographer(fposmod(t,22.0))
	elif role=="study_walk":_study_walker(fposmod(t,46.0))
	else:_cyclist(fposmod(t,64.0))
	var finite=true
	for key in bones:
		var x=bones[key].transform
		finite=finite and x.origin.is_finite() and x.basis.x.is_finite() and x.basis.y.is_finite() and x.basis.z.is_finite()
	_state["finite"]=finite
	_state["ik_error_m"]=_errors.duplicate()

func last_state()->Dictionary:
	return _state.duplicate(true)

func validate_loop()->Dictionary:
	var duration={"bench_reader":32.0,"cyclist":64.0,"photographer":22.0,"study_walk":46.0}.get(role,64.0)
	var old_distance=wheel_distance;wheel_distance=-1.0
	pose(0);var start={}
	for key in bones:start[key]=bones[key].transform
	pose(duration)
	var pos_error=0.0;var basis_error=0.0
	for key in bones:
		var a=start[key];var b=bones[key].transform
		pos_error=maxf(pos_error,a.origin.distance_to(b.origin))
		basis_error=maxf(basis_error,maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
	# Also inspect the actual limit before wrap, rather than testing fposmod(64)=0 only.
	pose(duration-.001)
	var boundary_position=0.0;var boundary_basis=0.0
	for key in bones:
		var a=start[key];var b=bones[key].transform
		boundary_position=maxf(boundary_position,a.origin.distance_to(b.origin))
		boundary_basis=maxf(boundary_basis,maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
	wheel_distance=old_distance
	return {"closed":pos_error<.00001 and basis_error<.00001 and boundary_position<.002 and boundary_basis<.002,"position_error_m":pos_error,"basis_error":basis_error,"pre_wrap_position_error_m":boundary_position,"pre_wrap_basis_error":boundary_basis,"duration_seconds":duration,"external_root_and_wheel_distance_excluded":true}
