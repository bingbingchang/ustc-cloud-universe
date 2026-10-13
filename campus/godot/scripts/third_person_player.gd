extends "res://scripts/player.gd"

const WALK_SPEED=2.6
const RUN_SPEED=5.0
const GRAVITY=16.0
const JUMP_SPEED=5.6
var orbit:Node3D
var arm:SpringArm3D
var avatar:Node3D
var third_person=true
var jump_buffer=0.0
var floor_grace=0.0
var jump_count=0
var fly_speed=12.0

func set_free_camera(flying:bool):
	if flying==free_camera:return
	free_camera=flying;velocity=Vector3.ZERO
	if flying:
		camera.reparent(self,true);camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.far=1800
	else:
		camera.reparent(arm,false);camera.position=Vector3.ZERO;camera.rotation=Vector3.ZERO
	avatar.visible=third_person

func toggle_free_camera():set_free_camera(not free_camera)

func _ready():
	super._ready()
	name="StudentPlayer"
	orbit=Node3D.new();orbit.name="CameraPivot";orbit.position.y=1.42;add_child(orbit)
	arm=SpringArm3D.new();arm.name="CameraArm";arm.spring_length=4.2;arm.margin=.15
	arm.collision_mask=1;arm.add_excluded_object(get_rid());orbit.add_child(arm)
	camera.reparent(arm);camera.position=Vector3.ZERO;camera.rotation=Vector3.ZERO;camera.fov=66
	avatar=preload("res://scripts/player_avatar.gd").new();avatar.name="StudentAvatar";add_child(avatar)
	pitch=-.18;arm.rotation.x=pitch
	set_view(respawn_position,respawn_target)

func set_view(pos:Vector3,target:Vector3):
	# The inherited ready uses set_view before the third-person rig exists.
	if not orbit:
		super.set_view(pos,target)
		return
	global_position=pos;velocity=Vector3.ZERO;rotation=Vector3.ZERO
	jump_buffer=0;floor_grace=0
	var dir=target-pos;dir.y=0
	orbit.rotation.y=atan2(-dir.x,-dir.z)
	avatar.rotation.y=orbit.rotation.y
	pitch=-.18 if third_person else 0.0
	arm.rotation.x=pitch
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	last_ground=pos
	if free_camera:
		camera.global_position=pos+Vector3.UP*1.65
		camera.look_at(target)

func toggle_view():
	third_person=not third_person
	avatar.visible=third_person
	orbit.position.y=1.42 if third_person else 1.65
	arm.spring_length=4.2 if third_person else 0.0
	pitch=-.18 if third_person else 0.0;arm.rotation.x=pitch

func _unhandled_input(e):
	if not enabled:return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode==KEY_ESCAPE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		if e.keycode==KEY_V:toggle_free_camera();get_viewport().set_input_as_handled()
		if e.keycode==KEY_TAB and not free_camera:toggle_view();get_viewport().set_input_as_handled()
	if e is InputEventMouseButton and e.pressed:
		if e.button_index==MOUSE_BUTTON_LEFT:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		if free_camera and e.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			fly_speed=clampf(fly_speed*(1.2 if e.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.2),2,120)
		elif third_person and e.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			arm.spring_length=clampf(arm.spring_length+(-.4 if e.button_index==MOUSE_BUTTON_WHEEL_UP else .4),2.0,6.5)
	if e is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		if free_camera:
			camera.rotation.y-=e.screen_relative.x*.0021;camera.rotation.x=clampf(camera.rotation.x-e.screen_relative.y*.0021,-1.5,1.5);return
		orbit.rotation.y-=e.screen_relative.x*.0021
		pitch=clampf(pitch-e.screen_relative.y*.0021,-1.05,.65)
		arm.rotation.x=pitch

func _physics_process(dt):
	if frozen:return
	var active=enabled and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED
	var input=Input.get_vector("left","right","forward","back") if active else Vector2.ZERO
	if free_camera:
		var flight=camera.global_basis*Vector3(input.x,0,input.y)
		if active and Input.is_action_pressed("up"):flight.y+=1
		if active and Input.is_action_pressed("down"):flight.y-=1
		camera.global_position+=flight*dt*fly_speed*(3.5 if active and Input.is_action_pressed("jog") else 1.0)
		return
	var speed=RUN_SPEED if active and Input.is_action_pressed("jog") else WALK_SPEED
	var dir=orbit.global_basis*Vector3(input.x,0,input.y);dir.y=0
	var acceleration=18.0 if is_on_floor() else 7.0
	velocity.x=move_toward(velocity.x,dir.x*speed,acceleration*dt)
	velocity.z=move_toward(velocity.z,dir.z*speed,acceleration*dt)
	jump_buffer=maxf(0,jump_buffer-dt)
	floor_grace=.10 if is_on_floor() else maxf(0,floor_grace-dt)
	if active and Input.is_action_just_pressed("jump"):jump_buffer=.12
	velocity.y=-.5 if is_on_floor() else velocity.y-GRAVITY*dt
	if jump_buffer>0 and floor_grace>0:
		velocity.y=JUMP_SPEED;jump_buffer=0;floor_grace=0;jump_count+=1
	var before=global_position;var grounded=is_on_floor()
	move_and_slide()
	# Retain the existing campus controller's 30 cm bridge/curb step support.
	var horizontal=Vector3(dir.x,0,dir.z)*speed*dt
	if grounded and velocity.y<=0 and is_on_wall() and horizontal.length()>.001:
		var raised=global_transform.translated(Vector3.UP*.30)
		if not test_move(global_transform,Vector3.UP*.30) and not test_move(raised,horizontal*2):
			global_position.y+=.30
			velocity.x=dir.x*speed;velocity.z=dir.z*speed
			move_and_slide()
	travelled+=Vector2(global_position.x-before.x,global_position.z-before.z).length()
	if is_on_floor():last_ground=global_position
	var actual=Vector2(global_position.x-before.x,global_position.z-before.z).length()/dt
	if actual>.10:
		var heading=atan2(-(global_position.x-before.x),-(global_position.z-before.z))
		avatar.rotation.y=lerp_angle(avatar.rotation.y,heading,1-exp(-dt*12))
	avatar.animate(actual,velocity.y,is_on_floor(),dt)
	if position.y < -4:set_view(respawn_position,respawn_target)

func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
