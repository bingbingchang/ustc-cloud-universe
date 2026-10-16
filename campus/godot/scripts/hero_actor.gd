extends "res://scripts/ambient_actor.gd"
## Each Blender character has six keyed joint animations and its own work routine.
const CLIPS={"idle":8.0,"work":6.0,"greet":2.8,"talk":5.0,"walk":1.2,"listen":5.0}
var definition:Dictionary
var appearance:Dictionary
var player:Node3D
var speaking=false
var thinking=false
var clock=0.0
var routine_clock=0.0
var home:Vector3
var home_heading=0.0
var nameplate:Label3D
var contact:AnimatableBody3D
var animator:AnimationPlayer
var current_state="idle"
var greet_left=0.0
var reply_left=0.0
var greeting_cooldown=0.0
var manual_time=-1.0
var manual_state=""

func _ready():
	appearance=JSON.parse_string(FileAccess.get_file_as_string("res://data/npc_appearance.json"))[definition.id]
	home=position;home_heading=deg_to_rad(float(definition.get("heading",0)));rotation.y=home_heading
	var model=load("res://assets/npc_"+definition.id+".glb").instantiate()
	model.name="CharacterModel";model.scale=Vector3.ONE*float(appearance.height)/1.503;add_child(model)
	for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.layers=mesh.layers|16
	prepare();bones.Book.hide()
	nameplate=Label3D.new();nameplate.text=definition.name+"\n"+definition.title
	nameplate.position.y=float(appearance.height)+.30;nameplate.font_size=32;nameplate.pixel_size=.0035
	nameplate.modulate=Color(definition.color).lightened(.4);nameplate.outline_size=6
	nameplate.billboard=BaseMaterial3D.BILLBOARD_ENABLED;nameplate.visibility_range_end=22;add_child(nameplate)
	contact=AnimatableBody3D.new();contact.name="CharacterContact";contact.sync_to_physics=false
	var shape=CollisionShape3D.new();var capsule=CapsuleShape3D.new()
	capsule.radius=.27;capsule.height=float(appearance.height);shape.shape=capsule;shape.position.y=capsule.height*.5
	contact.add_child(shape);add_child(contact)
	make_clips();routine_clock=float(definition.get("phase",0))
	animator.play("idle");animator.advance(routine_clock*.2)

func feet_pose(t:float,walking:bool):
	var wave=sin(t*TAU)
	bones.Human.position=rest.Human.origin+Vector3(sin(t*TAU)*.018,.009*cos(t*TAU*2),0)
	if walking:bones.Human.position.y+=absf(wave)*.008
	for side in ["L","R"]:
		var s=-1.0 if side=="L" else 1.0
		var target=Vector3(s*.080,.064,-.01)
		if walking:target.z+=wave*s*.15;target.y+=maxf(0,wave*s)*.055
		_solve("Leg"+side,"Knee"+side,bones.Human.transform.affine_inverse()*target,.36,.34,Vector3(0,0,-1))
		_orient_tip(side,false,Basis())

func pose_clip(state:String,t:float):
	_restore()
	var phase=t/float(CLIPS[state])*TAU
	feet_pose(t/1.2 if state=="walk" else t/float(CLIPS[state]),state=="walk")
	var lean=.025;var head_down=0.0
	var left=Vector3(-.16,.08,-.22);var right=Vector3(.20,-.14,-.035)
	var wrist_left=Basis();var wrist_right=Basis()
	match state:
		"work":
			match String(appearance.activity):
				"calculate","type","repair","write":
					left=Vector3(-.13,.13,-.24);right=Vector3(-.035,.17+.023*absf(sin(phase*4)),-.27);head_down=.22;lean=.07
				"cook":
					left=Vector3(-.14,.13,-.24);right=Vector3(-.01+.045*cos(phase*2),.37,-.23+.04*sin(phase*2))
					wrist_right=Basis.from_euler(Vector3(0,0,PI));head_down=.13;lean=.065
				"read":
					left=Vector3(-.10,.17,-.28);right=Vector3(.065+.045*sin(phase),.19,-.28);head_down=.25
				"inspect":right=Vector3(.16,.36+.06*sin(phase),-.18);head_down=-.08
				"plant":left=Vector3(-.12,.17,-.25);right=Vector3(.035,.32+.025*sin(phase),-.26);head_down=.12;lean=.09
				"warmup":
					left=Vector3(-.18,.09+.08*sin(phase*2),-.19);right=Vector3(.26+.08*sin(phase),.25+.15*sin(phase),-.12);lean=.045+.035*sin(phase)
				"teach","guide","welcome","demonstrate":right=Vector3(.15+.10*sin(phase),.28+.09*cos(phase),-.23);left.y+=.045*sin(phase)
				"keys":
					left=Vector3(-.14,.12,-.24);right=Vector3(.15,.03,-.21);wrist_right=Basis.from_euler(Vector3(0,0,.35*sin(phase*2)));head_down=.17
		"greet":
			var lift=sin(PI*t/float(CLIPS.greet));right=right.lerp(Vector3(.25+.065*sin(phase*4),.66,-.10),lift)
			wrist_right=Basis.from_euler(Vector3(.1,0,.30*sin(phase*4)*lift))
		"talk":
			right=Vector3(.22+.065*sin(phase),.24+.10*sin(phase*2),-.25+.04*cos(phase));left.y+=.025*sin(phase);head_down=.06*sin(phase*2)
			wrist_right=Basis.from_euler(Vector3(0,.22*sin(phase),-.15))
		"listen":head_down=.06*sin(phase);right=Vector3(.18,-.13,-.02)
		"walk":right=Vector3(.17,-.12,-.02+.12*sin(phase));left.y+=.012*cos(phase*2)
		_:
			head_down=.12*maxf(0,sin(phase));right=right.lerp(Vector3(.14,.33,-.03),maxf(0,sin(phase))*.65)
	_spine(lean,sin(phase)*.018,sin(phase))
	bones.Head.rotation.x+=head_down;bones.Head.rotation.y+=.18*sin(phase)
	for side in ["L","R"]:
		var s=-1.0 if side=="L" else 1.0
		_solve("Arm"+side,"Fore"+side,left if side=="L" else right,.28,.27,Vector3(s,-.5,-.15))
		_orient_tip(side,true,wrist_left if side=="L" else wrist_right)

func make_clips():
	animator=AnimationPlayer.new();animator.name="CharacterAnimations";animator.callback_mode_process=2;add_child(animator)
	var library=AnimationLibrary.new()
	for state in CLIPS:
		var animation=Animation.new();animation.length=float(CLIPS[state])
		animation.loop_mode=Animation.LOOP_NONE if state=="greet" else Animation.LOOP_LINEAR
		var tracks={}
		for key in bones:
			var indices=[]
			for kind in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
				var index=animation.add_track(kind);animation.track_set_path(index,get_path_to(bones[key]));indices.append(index)
			tracks[key]=indices
		for i in range(33):
			var time=animation.length*float(i)/32.0;pose_clip(state,time)
			for key in bones:
				var transform=bones[key].transform
				animation.track_insert_key(tracks[key][0],time,transform.origin)
				animation.track_insert_key(tracks[key][1],time,transform.basis.orthonormalized().get_rotation_quaternion())
				animation.track_insert_key(tracks[key][2],time,transform.basis.get_scale())
		library.add_animation(state,animation)
	_restore();animator.add_animation_library("",library)

func begin_conversation():
	speaking=true;greet_left=2.6;reply_left=0;thinking=false

func end_conversation():
	speaking=false;thinking=false;reply_left=0;greet_left=0

func answer_received():
	thinking=false;reply_left=5.0

func _physics_process(dt):
	clock+=dt;greet_left=maxf(0,greet_left-dt);reply_left=maxf(0,reply_left-dt);greeting_cooldown=maxf(0,greeting_cooldown-dt)
	var distance=player.global_position.distance_to(global_position) if is_instance_valid(player) else 1000.0
	if not speaking and distance<3.8 and greeting_cooldown<=0:greet_left=2.6;greeting_cooldown=18.0
	if not speaking and distance>4.0:routine_clock+=dt
	var p=fposmod(routine_clock,18.0);var roaming=float(appearance.roam)
	var state="work" if p<8.0 else "idle";var offset=0.0
	if roaming>0 and p>=11.0 and p<16.0:
		state="walk";var progress=(p-11.0)/5.0;offset=roaming*sin(progress*PI)*sin(progress*PI)
		if distance>4:rotation.y=lerp_angle(rotation.y,home_heading if progress<.5 else home_heading+PI,1-exp(-dt*5))
	position=home+Basis(Vector3.UP,home_heading)*Vector3(0,0,-offset)
	if distance<4 and state=="walk":state="idle"
	if speaking:state="talk" if reply_left>0 else "work" if thinking else "listen"
	if greet_left>0:state="greet"
	if distance<6.0:
		var direction=player.global_position-global_position;direction.y=0
		if direction.length_squared()>.01:rotation.y=lerp_angle(rotation.y,atan2(-direction.x,-direction.z),1-exp(-dt*5))
	elif state!="walk":rotation.y=lerp_angle(rotation.y,home_heading,1-exp(-dt*2))
	if not manual_state.is_empty():state=manual_state
	if state!=current_state or not animator.is_playing():current_state=state;animator.play(state,0 if manual_time>=0 else .32)
	if manual_time>=0:animator.seek(manual_time,true)
	else:animator.advance(dt)
	nameplate.visible=not speaking
	var blink=1.0-.94*_pulse(fposmod(clock+float(definition.get("phase",0)),4.3),3.8,4.05,.08)
	for side in ["L","R"]:bones["Eye"+side].scale.y*=blink

func animation_snapshot()->Dictionary:
	return {"state":current_state,"clips":animator.get_animation_list(),"position":position,"head":bones.Head.transform,"right_hand":bones.HandR.global_position,"left_hand":bones.HandL.global_position}
