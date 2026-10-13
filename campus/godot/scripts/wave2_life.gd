extends Node3D
var campus:Node3D
var actors={}
var registry={}
var manual_time=-1.0
var time=0.0
var wander=preload("res://scripts/campus_wander.gd").new()
var route_debug:MeshInstance3D

func setup(c:Node3D):
	campus=c
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/wave2_nodes.json"))
	var points=preload("res://scripts/scene_modules.gd").story_nodes()
	for entry in data.actors:
		assert(points.has(entry.node_ref),"Missing researched story location: "+entry.node_ref)
		var s=entry.duplicate(true);s.merge(points[entry.node_ref]);registry[s.id]=s
		var actor=load("res://assets/"+s.asset+".glb").instantiate();actor.name="Wave2_"+s.id;add_child(actor)
		actor.position=Vector3(s.position[0],s.position[1],s.position[2]);actor.rotation.y=s.heading;campus.style(actor)
		actor.set_script(load("res://scripts/"+s.script));actor.role=s.role;actor.prepare()
		actors[s.id]={"root":actor}
		var size=Vector3(.42,1.46,.37)
		if s.id=="doubao":size=Vector3(.36,1.1,.31)
		elif s.id=="meituan":size=Vector3(.47,1.15,.60)
		elif s.id=="leaf_cat":size=Vector3(.25,.45,.56)
		var contact=AnimatableBody3D.new();contact.name="Wave2Character_"+s.id;contact.sync_to_physics=false
		actor.add_child(contact);contact.position=Vector3(0,size.y*.5,0)
		var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size;shape.shape=box;contact.add_child(shape)
		actors[s.id]["collision"]=contact
		if s.id=="meituan":
			var parcel=campus.static_box(actor.to_global(Vector3(.59,.26,0)),Vector3(.46,.52,.43),"DeliveryBoxContact");parcel.rotation.y=s.heading
		if s.id in ["meituan","leaf_cat"]:
			var anchor=Node3D.new();anchor.name="FixedStoryProp_"+s.id;add_child(anchor);anchor.global_transform=actor.global_transform
			actor.bones["Parcel" if s.id=="meituan" else "Leaf"].reparent(anchor,true)
			actors[s.id]["prop_anchor"]=anchor
	wander.setup(registry)
	_make_debug_routes()
	pose(0)

func _process(dt:float):
	time=manual_time if manual_time>=0 else time+dt
	pose(time)

func pose(t:float):
	for id in actors:
		var actor=actors[id].root;var m=wander.sample(id,t)
		actor.position=m.position;actor.rotation.y=m.heading
		actor.pose(m.story_time)
		actor.apply_locomotion(m)

func pose_story(t:float):
	## Explicit stationary identity proof, never the default game behavior.
	for id in actors:
		var actor=actors[id].root;var s=registry[id];var m=wander.sample(id,-float(wander.routes[id].time_offset))
		actor.position=Vector3(s.position[0],s.position[1],s.position[2]);actor.rotation.y=s.heading
		actor.pose(t+float(s.time_offset));m.story_time=t;m.walking_weight=0.0
		actor.apply_locomotion(m)

func _make_debug_routes():
	route_debug=MeshInstance3D.new();route_debug.name="WanderRoutes_DebugOnly";add_child(route_debug)
	var mesh=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines=wander.debug_lines()
	for i in range(0,lines.size(),2):
		var a=lines[i];var b=lines[i+1];var side=(b-a).normalized().cross(Vector3.UP)*.045
		for p in [a-side,b-side,b+side,a-side,b+side,a+side]:mesh.surface_add_vertex(p)
	mesh.surface_end();route_debug.mesh=mesh
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(.59,.32,.76);mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	route_debug.material_override=mat;route_debug.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;route_debug.visible=false

func set_route_debug(enabled:bool):
	if is_instance_valid(route_debug):route_debug.visible=enabled

func toggle_routes():
	if is_instance_valid(route_debug):set_route_debug(not route_debug.visible)

func _unhandled_key_input(event:InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F8:
		set_route_debug(not route_debug.visible)

func snapshot()->Dictionary:
	var state={}
	for id in actors:state[id]=actors[id].root.last_state()
	return state

func spots()->Array:
	var result=[]
	for id in registry:
		var s=registry[id];var p=actors[id].root.position;var b=Basis(Vector3.UP,actors[id].root.rotation.y)
		var offset=Vector3(-.60,float(s.height)*1.3,-3.3)
		if id=="leaf_cat":offset=Vector3(-.3,.75,-1.50)
		elif id=="meituan":offset=Vector3(-.7,1.9,-3.0)
		result.append({"name":s.name,"pos":p+b*offset-Vector3.UP*1.65,"target":p+Vector3.UP*s.height*.52,"fov":42.0,"ortho":false,"size":12.0,"reason":s.story})
	return result
