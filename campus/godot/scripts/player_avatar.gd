extends "res://scripts/ambient_actor.gd"
## Reuses the ordinary student mesh. Only this instance loses the reading prop.
var phase=0.0
var blend=0.0
var locomotion="idle"

func _ready():
	var model=preload("res://assets/ambient_study_walk.glb").instantiate()
	add_child(model)
	model.scale=Vector3.ONE*1.12
	model.position.y=.04
	prepare()
	bones.Book.hide()
	get_parent().get_parent().style(model)

func animate(speed:float,vertical:float,grounded:bool,dt:float):
	_restore()
	blend=move_toward(blend,clampf(speed/2.6,0,1),dt*7)
	phase+=speed*dt*3.5
	var stride=sin(phase)*blend
	locomotion="idle" if speed<.12 else "run" if speed>3.3 else "walk"
	if not grounded:locomotion="jump" if vertical>0 else "fall"
	if grounded:
		bones.Human.position.y+=absf(stride)*.016
		bones.Torso.rotation.x=-.025*speed
		for side in ["L","R"]:
			var wave=stride*(1 if side=="L" else -1)
			bones["Leg"+side].rotation.x=wave*.50
			bones["Knee"+side].rotation.x=-maxf(0,-wave)*.65
			bones["Foot"+side].rotation.x=-wave*.20
			bones["Arm"+side].rotation.x=-wave*.38
			bones["Arm"+side].rotation.z=.06*(1 if side=="L" else -1)
			bones["Fore"+side].rotation.x=-.14-absf(wave)*.22
	else:
		for side in ["L","R"]:
			bones["Leg"+side].rotation.x=.35
			bones["Knee"+side].rotation.x=-.70
			bones["Foot"+side].rotation.x=.20
			bones["Arm"+side].rotation.x=-.65
			bones["Arm"+side].rotation.z=.18*(1 if side=="L" else -1)
			bones["Fore"+side].rotation.x=-.35
