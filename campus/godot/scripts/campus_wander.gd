extends RefCounted
## Deterministic routes and planted world-space feet. No navigation or asset edits.
## One gait unit is a complete stride. Every motion phase ends in double support.
var routes={}
var paths={}

func setup(registry:Dictionary):
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/wander_routes.json"))
	for raw in data.routes:
		if not registry.has(raw.id):continue
		var spec=raw.duplicate(true);var home=registry[raw.id].position
		spec.home=Vector3(home[0],home[1],home[2]);spec.heading=float(registry[raw.id].heading)
		spec.points=[]
		for offset in raw.offsets:spec.points.append(spec.home+Vector3(offset[0],offset[1],offset[2]))
		routes[raw.id]=spec;paths[raw.id]=_compile(spec)
	return paths.size()

func _append(phases:Array,a:Vector3,b:Vector3,ha:float,hb:float,seconds:float,units:float,kind:String):
	var start=0.0;var u=0.0;var distance=0.0
	if not phases.is_empty():
		var last=phases[-1];start=last.start+last.seconds;u=last.u+last.units;distance=last.distance+last.length
	phases.append({"a":a,"b":b,"ha":ha,"hb":hb,"start":start,"seconds":seconds,"u":u,"units":units,"kind":kind,"distance":distance,"length":a.distance_to(b)})

func _compile(s:Dictionary)->Dictionary:
	var phases=[];var p:Vector3=s.home;var heading:float=s.heading
	_append(phases,p,p,heading,heading,s.story_seconds,0.0,"story")
	for i in range(1,s.points.size()):
		var target:Vector3=s.points[i];var delta=target-p;var length=delta.length()
		if length<.001:continue
		var wanted=atan2(-delta.x,-delta.z);var angle=wrapf(wanted-heading,-PI,PI)
		if absf(angle)>.015:
			_append(phases,p,p,heading,heading+angle,maxf(.9,absf(angle)*1.5/s.turn_rate),ceilf(absf(angle)/.55),"turn")
			heading+=angle
		_append(phases,p,target,heading,heading,length*1.5/s.speed_mps,ceilf(length/s.stride_m),"walk")
		p=target
		if i<s.points.size()-1:
			_append(phases,p,p,heading,heading,float(s.pauses[(i-1)%s.pauses.size()]),0.0,"pause")
	var home_angle=wrapf(s.heading-heading,-PI,PI)
	if absf(home_angle)>.015:_append(phases,p,p,heading,heading+home_angle,maxf(.9,absf(home_angle)*1.5/s.turn_rate),ceilf(absf(home_angle)/.55),"turn")
	_append(phases,p,p,s.heading,s.heading,2.0,0.0,"settle")
	var last=phases[-1]
	return {"phases":phases,"seconds":last.start+last.seconds,"units":last.u+last.units,"length":last.distance+last.length}

func _body_at_units(id:String,units:float)->Dictionary:
	var path=paths[id];var u=fposmod(units,path.units)
	for phase in path.phases:
		if phase.units<=0 or u>phase.u+phase.units+.000001:continue
		var f=clampf((u-phase.u)/phase.units,0,1)
		return {"position":phase.a.lerp(phase.b,f),"heading":lerpf(phase.ha,phase.hb,f)}
	return {"position":routes[id].home,"heading":routes[id].heading}

func _foot(id:String,u:float,offset:float,rest_foot:Vector3,duty:float,lift:float)->Dictionary:
	var q=fposmod(u+offset,1.0);var base=u-q
	var first=_body_at_units(id,base+duty*.5)
	var next=_body_at_units(id,base+1+duty*.5)
	var a:Vector3=first.position+Basis(Vector3.UP,first.heading)*Vector3(rest_foot.x,0,rest_foot.z)
	var b:Vector3=next.position+Basis(Vector3.UP,next.heading)*Vector3(rest_foot.x,0,rest_foot.z)
	var swing=clampf((q-duty)/(1-duty),0,1);var f=smoothstep(0,1,swing)
	var target=a.lerp(b,f);target.y+=sin(swing*PI)*lift
	return {"position":target,"heading":lerp_angle(first.heading,next.heading,f),"stance":q<=duty,"phase":q,"lift":sin(swing*PI)*lift,"plant_id":int(floor(u+offset)),"gait_offset":offset}

func sample(id:String,t:float)->Dictionary:
	var s=routes[id];var path=paths[id];var p=fposmod(t+s.time_offset,path.seconds);var phase=path.phases[0]
	for entry in path.phases:
		if p<entry.start+entry.seconds:
			phase=entry;break
	var r=clampf((p-phase.start)/phase.seconds,0,1);var eased=smoothstep(0,1,r)
	var u=float(phase.u+phase.units*eased);var position:Vector3=phase.a.lerp(phase.b,eased)
	var heading=lerpf(phase.ha,phase.hb,eased);var weight=smoothstep(0,.85,u)*(1.0-smoothstep(path.units-.85,path.units,u))
	var speed=phase.length*6*r*(1-r)/phase.seconds
	var state={"id":id,"phase":phase.kind,"position":position,"heading":heading,"speed_mps":speed,"gait_units":u,"walking_weight":weight,"time":p,"cycle_seconds":path.seconds,"story_time":p if phase.kind=="story" else 0.0,"story_active":phase.kind=="story","at_home":position.distance_to(s.home)<.001 and absf(wrapf(heading-s.heading,-PI,PI))<.002,"feet":{},"distance_m":phase.distance+phase.length*eased,"route_length_m":path.length,"phase_progress":r}
	if id=="leaf_cat":
		for item in [["FrontL",0.0,-.088,-.159],["FrontR",.5,.088,-.159],["BackL",.75,-.088,.186],["BackR",.25,.088,.186]]:
			state.feet[item[0]]=_foot(id,u,item[1],Vector3(item[2],0,item[3]),.78,s.foot_lift_m)
	else:
		var width=.070;var toe=-.012
		if id=="meituan":width=.141;toe=-.069
		elif id=="doubao":width=.065;toe=-.025
		for side in ["L","R"]:
			state.feet[side]=_foot(id,u,0.0 if side=="L" else .5,Vector3(-width if side=="L" else width,0,toe),.64,s.foot_lift_m)
	return state

func duration(id:String)->float:return paths[id].seconds

func debug_lines()->PackedVector3Array:
	var lines=PackedVector3Array()
	for id in routes:
		var p=routes[id].points
		for i in range(p.size()-1):
			var a:Vector3=p[i]+Vector3.UP*.035;var b:Vector3=p[i+1]+Vector3.UP*.035
			lines.append(a);lines.append(b)
			var direction=(b-a).normalized();var side=direction.cross(Vector3.UP)
			var count=maxi(1,int(ceil(a.distance_to(b)/2.0)))
			for arrow in range(count):
				var center=a.lerp(b,(arrow+.5)/count)
				for sign_side in [-1,1]:lines.append(center);lines.append(center-direction*.24+side*.12*sign_side)
			# Small waypoint cross, no floor-filling meshes or labels.
			for axis in [Vector3.RIGHT,Vector3.FORWARD]:lines.append(a-axis*.10);lines.append(a+axis*.10)
	return lines
