extends Node3D
var campus:Node3D
var actors={}
var time=0.0
var manual_time=-1.0
var animal_rest={}
var registry={}
var cyclist_time=0.0
var cyclist_yielding=false
var live_tick=false
var budgets={}

func vector(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])

func spawn_config(id:String)->Node3D:
	var s=registry[id]
	return prop(s.asset,vector(s.position),s.heading)

func part(root:Node,suffix:String)->Node3D:
	for n in root.find_children("*","Node3D",true,false):
		if n.name.ends_with(suffix):return n
	return null

func prop(asset:String,pos:Vector3,angle=0.0)->Node3D:
	var n=load("res://assets/"+asset+".glb").instantiate();add_child(n);n.position=pos;n.rotation.y=angle;campus.style(n);return n

func setup(owner_campus:Node3D):
	campus=owner_campus
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/population.json"))
	budgets=data.budgets_per_100m_square
	for s in data.actors:
		assert(not registry.has(s.id),"Duplicate actor ID");registry[s.id]=s
	# Periods are asset contracts; unsupported edits must fail clearly rather than drift.
	for item in [["cyclist",64],["bench_reader",32],["photo",22],["reader",46],["cat",24]]:
		assert(registry[item[0]].cycle_seconds==item[1],"Cycle duration requires corresponding animation change: "+item[0])
	for id in ["solver","reader","photo"]:
		var s=registry[id];var n=spawn_config(id);n.name="Student_"+id
		if id=="solver":n.set_script(preload("res://scripts/tiku_actor.gd"));n.prepare()
		else:n.set_script(preload("res://scripts/ambient_actor.gd"));n.role=s.role;n.prepare()
		var bones={}
		for key in ["Head","Torso","ArmL","ArmR","ForeL","ForeR","LegL","LegR","KneeL","KneeR","Page","Pen","Phone","Book"]:
			bones[key]=part(n,"_"+key)
		actors[id]={"root":n,"bones":bones,"rest":vector(s.position),"heading":s.heading}
	prop("book_bag",Vector3(-17.9,.03,147.03),.2)
	var cat=spawn_config("cat");cat.name="CampusCat";actors.cat={"root":cat,"head":part(cat,"_Head"),"paw":part(cat,"_PawR"),"tail":part(cat,"_Tail")}
	for i in range(2):
		var id="bird%d"%i;var p=vector(registry[id].position)
		var bird=spawn_config(id);bird.name="Sparrow%d"%i;actors[id]={"root":bird,"rest":p,"left":part(bird,"_WingL"),"right":part(bird,"_WingR"),"phase":i*4.2}
	actors.solver.root.passerby=campus.player
	var roadside=spawn_config("roadside")
	roadside.name="TikuRoadside";roadside.set_script(preload("res://scripts/tiku_actor.gd"));roadside.prepare();roadside.roadside=true;roadside.passerby=campus.player
	actors.roadside={"root":roadside}
	campus.static_box(roadside.position+Vector3(0,-.068,0),Vector3(.43,1.66,.38),"RoadsideCharacter")
	for id in ["cyclist","bench_reader"]:
		var n=spawn_config(id);n.name=id.to_pascal_case()
		n.set_script(preload("res://scripts/ambient_actor.gd"));n.role=id;n.prepare()
		actors[id]={"root":n,"rest":vector(registry[id].position)}
	var seated=vector(registry.bench_reader.position)
	campus.static_box(Vector3(seated.x,1.10,seated.z+.10),Vector3(.44,.94,.38),"CourtyardReaderContact")
	var body=AnimatableBody3D.new();body.name="CyclistContact";body.sync_to_physics=false
	actors.cyclist.root.add_child(body);body.position.y=.8
	var shape=CollisionShape3D.new();var bounds=BoxShape3D.new();bounds.size=vector(registry.cyclist.collision_size);shape.shape=bounds;body.add_child(shape)
	pose(0)

func _process(dt):
	time=manual_time if manual_time>=0 else time+dt
	cyclist_yielding=should_yield()
	if manual_time>=0:cyclist_time=manual_time
	elif not cyclist_yielding:cyclist_time+=dt
	live_tick=true
	pose(time)
	live_tick=false

func should_yield()->bool:
	if not actors.has("cyclist") or manual_time>=0:return false
	var p=actors.cyclist.root.global_position
	if is_instance_valid(campus.player) and not campus.player.free_camera:
		if p.distance_to(campus.player.global_position)<registry.cyclist.yield_distance:return true
	for id in ["solver","roadside","reader","photo","bench_reader"]:
		if p.distance_to(actors[id].root.global_position)<registry.cyclist.yield_distance:return true
	return false

func cycle_route(t:float)->Dictionary:
	# Hermite velocity ramps avoid teleporting at the closed route endpoints.
	var p=fposmod(t,64.0);var x=0.0;var heading=-PI/2
	if p<14:
		var u=p/14.0;x=19.6*(-u*u*u+2*u*u)
	elif p<18:
		var d=p-14.0;x=19.6+1.4*d-.175*d*d
	elif p<22:x=22.4
	elif p<29:x=22.4+3.5*smoothstep(22,29,p)
	elif p<38:x=25.9
	elif p<45:x=25.9;heading=lerp_angle(-PI/2,PI/2,smoothstep(39,44,p))
	elif p<59:
		var u=(p-45.0)/14.0;x=25.9-23.8*(3*u*u-2*u*u*u)-19.6*(u*u*u-u*u);heading=PI/2
	else:
		var d=minf(p-59.0,3.0);x=2.1-1.4*d+(1.4/6.0)*d*d;heading=lerp_angle(PI/2,-PI/2,smoothstep(62,64,p))
	var origin=vector(registry.cyclist.position)
	var route_scale=(registry.cyclist.path_end[0]-origin.x)/25.9
	return {"position":origin+Vector3(x*route_scale,0,0),"heading":heading,"distance":(floor(t/64.0)*51.8+(x if p<45 else 51.8-x))*route_scale}

func pose(t:float):
	if actors.is_empty():return
	actors.solver.root.pose(t)
	actors.roadside.root.pose(t)
	var ct=cyclist_time if live_tick else t;var route=cycle_route(ct)
	actors.cyclist.root.position=route.position;actors.cyclist.root.rotation.y=route.heading
	actors.cyclist.root.wheel_distance=route.distance;actors.cyclist.root.pose(ct)
	actors.bench_reader.root.pose(t)
	var phase
	var g=actors.reader;phase=fmod(t+4.0,46.0)
	var rx=registry.reader.position[0];var length=registry.reader.path_end[0]-rx
	var x=rx;var heading=-PI/2;var moving=false
	if phase<10:x=rx+length*smoothstep(0,10,phase);moving=true
	elif phase<20:x=rx+length
	elif phase<23:x=rx+length;heading=lerp_angle(-PI/2,PI/2,smoothstep(20,23,phase))
	elif phase<33:x=rx+length-length*smoothstep(23,33,phase);heading=PI/2;moving=true
	elif phase<43:heading=PI/2
	else:heading=lerp_angle(PI/2,-PI/2,smoothstep(43,46,phase))
	g.root.position=Vector3(x,g.rest.y,g.rest.z);g.root.rotation.y=heading;g.root.pose(t+4.0)
	var p=actors.photo;phase=fmod(t+3.0,22.0)
	var step_weight=smoothstep(18,19,phase)*(1-smoothstep(20,21,phase))
	p.root.position=p.rest+Vector3(.16*step_weight,0,0)
	p.root.rotation.y=p.heading+.06*sin(phase*TAU/22);p.root.pose(t+3.0)
	var c=actors.cat;phase=fmod(t,24.0)
	var lick=smoothstep(9,10,phase)*(1.0-smoothstep(14,15,phase))
	c.head.rotation.x=-.25*lick+sin(t*3.0)*.035*lick;c.head.rotation.z=sin(t*.7)*.018
	c.paw.rotation.x=-.55*lick;c.tail.rotation.y=sin(t*.7)*.12;c.root.scale.y=1+sin(t*1.35)*.016
	for i in range(2):
		var bird=actors["bird%d"%i];phase=fmod(t+bird.phase,16.0)
		var a=smoothstep(3,3.6,phase)*(1-smoothstep(10,10.6,phase))
		var hop=sin(clampf((phase-3)/.6,0,1)*PI)*.12+sin(clampf((phase-10)/.6,0,1)*PI)*.12
		bird.root.position=bird.rest+Vector3(a*.16,hop,0)
		bird.root.rotation.y=-.3+i+sin(t*.6+i)*.17
		bird.left.rotation.z=sin(t*22)*hop*3;bird.right.rotation.z=-sin(t*22)*hop*3

func snapshot()->Dictionary:
	return {"time":time,"solver_head":actors.solver.bones.Head.rotation.x,"solver_page":actors.solver.bones.Page.rotation.z,"reader_position":str(actors.reader.root.position),"photographer_phone":str(actors.photo.bones.Phone.position),"cat_paw":actors.cat.paw.rotation.x,"bird_position":str(actors.bird1.root.position),"cyclist_position":str(actors.cyclist.root.position),"cyclist":actors.cyclist.root.last_state(),"bench_reader":actors.bench_reader.root.last_state(),"photo":actors.photo.root.last_state(),"reader":actors.reader.root.last_state(),"cyclist_yielding":cyclist_yielding}
