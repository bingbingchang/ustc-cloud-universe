extends Node3D
## Local reference-led cameos; the scene owns deployment and collision.
var role="meituan"
var bones={}
var rest={}
var _state={}
var _errors={}
var wander_legs

func duration()->float:return {"meituan":32.0,"doubao":30.0,"leaf_cat":28.0}[role]

func prepare():
	for n in find_children("*","Node3D",true,false):
		if String(n.name).begins_with("Mascot_"):
			var key=String(n.name).trim_prefix("Mascot_");bones[key]=n;rest[key]=n.transform
	return bones.size()

func pulse(t:float,a:float,b:float,edge:float=1.0)->float:
	return smoothstep(a,a+edge,t)*(1.0-smoothstep(b-edge,b,t))

func solve(side:String,target:Vector3,l1:float,l2:float):
	var upper=bones["Arm"+side];var lower=bones["Fore"+side]
	var start=upper.position;var delta=target-start
	var d=clampf(delta.length(),absf(l1-l2)+.001,l1+l2-.001)
	var direction=delta.normalized();var pole=Vector3(-1 if side=="L" else 1,-.3,.3)
	var bend=(pole-direction*direction.dot(pole)).normalized()
	var along=(l1*l1-l2*l2+d*d)/(2*d)
	var elbow=start+direction*along+bend*sqrt(maxf(0,l1*l1-along*along))
	upper.quaternion=Quaternion(Vector3.DOWN,(elbow-start).normalized())
	lower.quaternion=upper.quaternion.inverse()*Quaternion(Vector3.DOWN,(start+direction*d-elbow).normalized())
	bones["Hand"+side].basis=(upper.basis*lower.basis).inverse()
	var actual=upper.transform*(lower.transform*Vector3(0,-l2,0))
	_errors[side]=actual.distance_to(target)

func pose(t:float):
	if bones.is_empty():prepare()
	for key in bones:bones[key].transform=rest[key]
	_errors.clear()
	var p=fposmod(t,duration());var phase="rest"
	if role=="meituan":
		var check=pulse(p,2,12,1.5);var unpack=pulse(p,15,25,2)
		bones.Head.rotation.x=-.10*check; bones.Head.rotation.y=.12*pulse(p,26,30,1)
		bones.Head.position.y+=sin(p*TAU/8)*.002
		bones.Tail.rotation.y=sin(p*TAU/32)*.045
		bones.EarR.rotation.z+=sin(p*TAU/16)*.018
		bones.Lid.rotation.x=.62*unpack
		var left=bones.Phone.transform*Vector3(-.040,-.035,0)
		var tap=bones.Phone.transform*Vector3(.022,-.01,.020)
		var lid=bones.Parcel.transform*(bones.Lid.transform*Vector3(-.07,.078,-.19))
		var right=Vector3(.21,.44,-.10).lerp(tap,check).lerp(lid,unpack)
		solve("L",left,.24,.25);solve("R",right,.24,.25)
		phase="check_order" if check>.2 else "open_and_tidy_box" if unpack>.2 else "look_for_recipient"
	elif role=="doubao":
		var point=pulse(p,9,17,1.5);var lookup=pulse(p,21,27,1.8)
		bones.Head.rotation.x=-.20*(1-lookup)+.025*lookup;bones.Head.rotation.y=.065*lookup
		bones.Head.position.y+=sin(p*TAU/10)*.0015
		bones.Tablet.rotation.x=-.08
		var left=bones.Tablet.transform*Vector3(-.113,-.032,0)
		var line_x=lerpf(-.04,.06,smoothstep(10.5,15.5,p))
		var right=bones.Tablet.transform*Vector3(.113,-.032,0).lerp(Vector3(line_x,.015,.018),point)
		solve("L",left,.20,.20);solve("R",right,.20,.20)
		phase="trace_a_line" if point>.2 else "look_up" if lookup>.2 else "shared_reading"
	else:
		var sniff=pulse(p,3,11,2);var paw=pulse(p,11,17,1.4);var look=pulse(p,19,25,2)
		bones.Head.rotation.x=-.20*sniff+.07*look;bones.Head.rotation.y=.16*look
		bones.Head.position.z-=.025*sniff
		bones.FrontR.rotation.x=.30*paw
		bones.Tail.rotation.y=.11*sin(p*TAU/28)
		bones.Leaf.position+=Vector3(.02,0,-.025)*pulse(p,12,26,2)
		bones.Leaf.rotation.y=sin(p*TAU/28)*.09
		phase="sniff_leaf" if sniff>.2 else "reach_toward_leaf" if paw>.2 else "listen" if look>.2 else "settle"
	var finite=true
	for key in bones:
		var x=bones[key].transform;finite=finite and x.origin.is_finite() and x.basis.x.is_finite() and x.basis.y.is_finite() and x.basis.z.is_finite()
	_state={"role":role,"time":p,"phase":phase,"cycle_seconds":duration(),"finite":finite,"ik_error_m":_errors.duplicate()}

func last_state()->Dictionary:return _state.duplicate(true)

func validate_loop()->Dictionary:
	pose(0);var initial={}
	for key in bones:initial[key]=bones[key].transform
	var max_pos=0.0;var max_basis=0.0
	for t in [duration(),duration()-.001]:
		pose(t)
		for key in bones:
			var a=initial[key];var b=bones[key].transform
			max_pos=maxf(max_pos,a.origin.distance_to(b.origin))
			max_basis=maxf(max_basis,maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
	return {"closed":max_pos<.002 and max_basis<.002,"position_error_m":max_pos,"basis_error":max_basis,"duration_seconds":duration(),"pre_wrap_checked":true}

func apply_locomotion(m:Dictionary):
	if wander_legs==null:
		wander_legs=preload("res://scripts/wander_legs.gd").new();wander_legs.setup(self,role,bones)
	var w=float(m.walking_weight)
	if not m.story_active:
		bones.Head.rotation.y+=sin(m.time*.29)*.045*w
		if role=="doubao":bones.Head.rotation.x+=.17*w
		elif role=="meituan":
			# The right hand swings gently; the left retains its phone grip.
			solve("R",Vector3(.23,.43,-.07+sin(m.gait_units*TAU)*.025*w),.24,.25)
		else:
			bones.Head.position.y+=sin(m.gait_units*TAU)*.003*w
			bones.Tail.rotation.y+=sin(m.gait_units*TAU*.5)*.035*w
	var legs_state=wander_legs.apply(m)
	_state.merge(legs_state,true)
	_state["locomotion"]=m.duplicate(true)
	_state["root_motion_applied"]=true
