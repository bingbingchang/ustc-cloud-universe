extends CharacterBody3D

const WALK=1.8
const JOG=4.2
var camera:Camera3D
var pitch=0.0
var free_camera=false
var enabled=true
var frozen=false
var travelled=0.0
var respawn_position=Vector3(0,.1,12)
var respawn_target=Vector3(0,5,170)
var last_ground=Vector3(0,.1,12)

func _ready():
	name="Walker"
	floor_snap_length=.32
	var cs=CollisionShape3D.new()
	var cap=CapsuleShape3D.new();cap.radius=.28;cap.height=1.75
	cs.shape=cap;cs.position.y=.875;add_child(cs)
	camera=Camera3D.new();camera.name="Eyes";camera.position.y=1.65;camera.fov=64;camera.far=850;camera.near=.075;add_child(camera)
	camera.current=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	set_view(Vector3(0,.10,15),Vector3(0,8,174))

func set_view(pos:Vector3,target:Vector3):
	global_position=pos;velocity=Vector3.ZERO
	camera.look_at(target,Vector3.UP)
	rotation.y=camera.global_rotation.y;pitch=camera.global_rotation.x;camera.rotation=Vector3(pitch,0,0)

func _unhandled_input(e):
	if not enabled:return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode==KEY_ESCAPE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		if e.keycode==KEY_V:
			free_camera=not free_camera
			if not free_camera and position.y>18:position=last_ground
	if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if e is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		rotation.y-=e.relative.x*.0021;pitch=clampf(pitch-e.relative.y*.0021,-1.45,1.45);camera.rotation.x=pitch

func _physics_process(dt):
	if frozen:return
	var v=Input.get_vector("left","right","forward","back") if enabled else Vector2.ZERO
	var speed=JOG if Input.is_action_pressed("jog") else WALK
	if free_camera:
		var dir=camera.global_basis*Vector3(v.x,0,v.y)
		if Input.is_action_pressed("up"):dir.y+=1
		if Input.is_action_pressed("down"):dir.y-=1
		global_position+=dir*dt*(10.0 if Input.is_action_pressed("jog") else 4.5)
		return
	var dir=global_basis*Vector3(v.x,0,v.y)
	velocity.x=move_toward(velocity.x,dir.x*speed,dt*12)
	velocity.z=move_toward(velocity.z,dir.z*speed,dt*12)
	if is_on_floor():
		last_ground=position
		if enabled and Input.is_action_just_pressed("jump"):velocity.y=4.6
	else:velocity.y-=12.5*dt
	var before=position;var grounded=is_on_floor();move_and_slide()
	# Human-sized low steps (bridge approach); tall pond walls and rails remain solid.
	var horizontal=Vector3(dir.x,0,dir.z)*speed*dt
	if grounded and is_on_wall() and horizontal.length()>.001:
		var raised=global_transform.translated(Vector3.UP*.30)
		if not test_move(raised,horizontal*2):
			position.y+=.30
			velocity.x=dir.x*speed;velocity.z=dir.z*speed
			move_and_slide()
	travelled+=Vector2(position.x-before.x,position.z-before.z).length()
	if position.y < -4:set_view(respawn_position,respawn_target)
