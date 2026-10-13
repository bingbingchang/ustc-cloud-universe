extends Node3D
var campus:Node3D
var actors={}
var registry={}
var time=0.0
var manual_time=-1.0
func setup(c:Node3D):
	campus=c
	for spec in load("res://scripts/west_grove.gd").config().actors:
		registry[spec.id]=spec
		var actor=load("res://assets/"+spec.asset+".glb").instantiate();add_child(actor);c.style(actor)
		actor.set_script(load("res://scripts/ambient_actor.gd"));actor.role=spec.role;actor.prepare()
		var body=AnimatableBody3D.new();body.name=spec.id+"_Contact";body.sync_to_physics=false;actor.add_child(body)
		body.position.y=.8;var cs=CollisionShape3D.new();var shape=CapsuleShape3D.new();shape.radius=.25;shape.height=1.6;cs.shape=shape;body.add_child(cs)
		actors[spec.id]={"root":actor,"body":body}
	pose(0)
func sample(id:String,t:float)->Dictionary:
	var s=registry[id];var at=Vector3(s.position[0],s.position[1],s.position[2]);var p=fposmod(t+s.phase,s.cycle_seconds);var angle=float(s.heading)
	if s.role=="study_walk":
		var end=Vector3(s.path_end[0],s.path_end[1],s.path_end[2]);var u=0.0
		if p<10:u=.5-.5*cos(PI*p/10)
		elif p<23:u=1
		elif p<33:u=.5+.5*cos(PI*(p-23)/10)
		at=at.lerp(end,u)
		if p>=20 and p<23:angle+=PI*smoothstep(20,23,p)
		elif p>=23 and p<43:angle+=PI
		elif p>=43:angle+=PI*(1-smoothstep(43,46,p))
	return {"position":at,"heading":angle,"phase":p}
func pose(t:float):
	for id in actors:
		var state=sample(id,t);var root=actors[id].root
		root.position=state.position;root.rotation.y=state.heading;root.pose(state.phase)
func _process(dt):
	time=manual_time if manual_time>=0 else time+dt;pose(time)
