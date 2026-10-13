extends "res://scripts/lookdev_live_qa.gd"
func save_live(name:String,value):
	var dir="res://../renders/west_grove/qa/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f=FileAccess.open(dir+name,FileAccess.WRITE);f.store_string(JSON.stringify(value,"\t"))
func _pose(c:Node3D,t:float):
	super._pose(c,t);c.grove_life.pose(t)
func _population(c:Node3D)->Dictionary:
	var totals={"Hero":0,"Ambient":0,"Creature":0};var entries=[]
	for layer in [c.life_layer,c.wave2_layer,c.grove_life]:
		for id in layer.registry:
			var r=layer.registry[id];totals[r.tier]+=1;entries.append({"layer":layer,"id":id,"tier":r.tier})
	var violations=[]
	for t in range(0,361,12):
		_pose(c,t)
		for ax in entries:
			for az in entries:
				var x=ax.layer.actors[ax.id].root.position.x;var z=az.layer.actors[az.id].root.position.z;var counts={"Hero":0,"Ambient":0,"Creature":0}
				for actor in entries:
					var p=actor.layer.actors[actor.id].root.position
					if p.x>=x and p.x<=x+100 and p.z>=z and p.z<=z+100:counts[actor.tier]+=1
				for tier in counts:
					if counts[tier]>c.life_layer.budgets[tier]:violations.append({"time":t,"tier":tier,"count":counts[tier]})
	return {"count":entries.size(),"tiers":totals,"density_violations":violations,"passed":entries.size()==16 and totals=={"Hero":4,"Ambient":8,"Creature":4} and violations.is_empty()}

func validate(c:Node3D)->Dictionary:
	c.grove_life.set_process(false)
	var report=await super.validate(c)
	report.checks["sixteen_population_and_density"]=report.checks.fourteen_population_and_density
	report.checks.erase("fourteen_population_and_density")
	Engine.physics_ticks_per_second=240;Engine.time_scale=4
	var route=await walk(c,"west_grove_path",[Vector3(-5,.08,25),Vector3(-12,.08,38),Vector3(-19,.08,51),Vector3(-27,.08,66),Vector3(-33,.08,70),Vector3(-39,.08,75)])
	Engine.physics_ticks_per_second=60;Engine.time_scale=1
	report["grove_path"]=route;report.checks["new_grove_path"]=route.reached and route.continuous
	report.passed=not report.checks.values().has(false);save_live("validation.json",report)
	return report