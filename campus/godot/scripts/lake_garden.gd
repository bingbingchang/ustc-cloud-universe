extends RefCounted
## Art-directed planting; lake, island, paths and pavilion use existing map data.
const North=preload("res://scripts/north_axis_environment.gd")
const Sakura=preload("res://scripts/sakura_avenue.gd")
const Paint=preload("res://scripts/lake_paint.gd")
static func enabled()->bool:return not "--lake-before" in OS.get_cmdline_user_args()
static func segment(p:Vector2)->bool:
	if not enabled():return false
	if "--lake-sample" in OS.get_cmdline_user_args():return p.x>55 and p.x<78 and p.y>72 and p.y<108
	return p.x>18 and p.x<83 and p.y>51 and p.y<138
static func edge_distance(p:Vector2,ring:PackedVector2Array)->float:
	var result=INF
	for i in ring.size():result=minf(result,p.distance_to(Geometry2D.get_closest_point_to_segment(p,ring[i],ring[(i+1)%ring.size()])))
	return result
static func land_safe(p:Vector2,r:float)->bool:
	if not segment(p):return false
	for q in [Vector2.ZERO,Vector2(r,0),Vector2(-r,0),Vector2(0,r),Vector2(0,-r)]:
		if not North.contains(p+q):return false
	if North._distance_paths(North.layout(),p)<r+.5:return false
	for b in North.layout().benches:
		if p.distance_to(Vector2(b[0],b[1]))<r+1.65:return false
	for l in North.layout().lamps:
		if p.distance_to(Vector2(l[0],l[1]))<r+.6:return false
	if p.distance_to(Vector2(73,82.2))<r+2:return false
	return true
static func water_safe(p:Vector2,r:float)->bool:
	if not segment(p):return false
	var d=North.layout();var pond=d.ponds[1];var outer=North.polygon(pond.outer)
	if not Geometry2D.is_point_in_polygon(p,outer) or edge_distance(p,outer)<r:return false
	for h in pond.holes:
		var ring=North.polygon(h)
		if Geometry2D.is_point_in_polygon(p,ring) or edge_distance(p,ring)<r:return false
	for b in d.bridges:
		if edge_distance(p,North.polygon(b.points))<r+b.width*.5+.35:return false
	return true

static func build(c:Node3D):
	if not enabled():return
	var first=c.world.get_child_count();var rng=RandomNumberGenerator.new();rng.seed=19580513
	var pads=[[],[],[],[]];var reeds=[[],[]];var stones=[];var shrubs=[[],[],[]];var trees=[[],[]]
	var records=[];var positions=[]
	# Grouped fields have open channels. No blanket carpet over the entire pond.
	for ix in range(22):
		for iz in range(34):
			var p=Vector2(15+ix*2.25+rng.randf_range(-.45,.45),58+iz*2.1+rng.randf_range(-.45,.45))
			if not water_safe(p,1.05):continue
			var wave=sin(p.x*.18+p.y*.073)+cos(p.y*.24-p.x*.09)
			if wave<-.05:continue
			var variant=3 if rng.randf()<.12 else rng.randi_range(0,2)
			var sc=rng.randf_range(.85,1.32)
			pads[variant].append(c.placement(p.x,-.035,p.y,Vector3(sc,rng.randf_range(.6,1.15),sc),rng.randf()*TAU))
			positions.append({"type":"lotus","x":p.x,"z":p.y})
	var ring=North.polygon(North.layout().ponds[1].outer)
	for i in ring.size():
		var a=ring[i];var b=ring[(i+1)%ring.size()];var normal=(b-a).orthogonal().normalized()
		for j in range(int(a.distance_to(b)/1.25)+1):
			var p=a.lerp(b,(j+.5)/(int(a.distance_to(b)/1.25)+1));var outside=normal
			if Geometry2D.is_point_in_polygon(p+normal*.6,ring):outside=-normal
			var shore=p+outside*.76
			if land_safe(shore,.30) and rng.randf()<.53:
				reeds[j%2].append(c.placement(shore.x,0,shore.y,Vector3.ONE*rng.randf_range(.68,1.1),rng.randf()*TAU))
			var rock=p-outside*.55
			if water_safe(rock,.33) and rng.randf()<.24:
				stones.append(c.placement(rock.x,-.12,rock.y,Vector3.ONE*rng.randf_range(.72,1.22),atan2(b.x-a.x,b.y-a.y)))
	for j in range(330):
		var p=Vector2(rng.randf_range(24,81),rng.randf_range(53,135))
		if not land_safe(p,.72):continue
		if edge_distance(p,ring)>6.3:continue
		var clear=true
		for t in North.layout().trees:
			if p.distance_to(Vector2(t[0],t[1]))<1.35:clear=false;break
		if clear:shrubs[j%3].append(c.placement(p.x,0,p.y,Vector3.ONE*rng.randf_range(.8,1.2),rng.randf()*TAU))
	for p in [Vector2(67.5,91),Vector2(62,54),Vector2(37,132),Vector2(35,56)]:
		if not land_safe(p,1.0):continue
		var k=trees[0].size()%2;trees[k].append(c.placement(p.x,0,p.y,Vector3.ONE*rng.randf_range(1.15,1.4),rng.randf()*TAU))
	for i in range(4):c.multimesh_batch("lake_lotus_"+str(i),pads[i])
	for i in range(2):c.multimesh_batch("lake_reeds_"+str(i),reeds[i])
	c.multimesh_batch("lake_shore_stones",stones)
	for i in range(3):c.multimesh_batch("sakura_shrub_"+str(i),shrubs[i])
	for i in range(2):
		var asset="lake_willow_"+str(i);c.multimesh_batch(asset,trees[i])
		if trees[i].is_empty():continue
		var shape=Sakura.low_bark(c,asset)
		for tr in trees[i]:
			var body=StaticBody3D.new();body.name="LakeWillowBarkContact";body.transform=tr;c.world.add_child(body)
			var cs=CollisionShape3D.new();cs.shape=shape;body.add_child(cs)
			var record={"asset":asset,"actual_asset":asset,"placement":tr,"position":tr.origin,"body":body.get_path()};records.append(record)
			if "lookdev_tree_contacts" in c:c.lookdev_tree_contacts.append(record)
	c.tree_count+=records.size()
	for i in range(first,c.world.get_child_count()):
		var n=c.world.get_child(i);n.set_meta("lake_authored",true)
		if n is GeometryInstance3D:n.visibility_range_end=0
	# Retain the existing polygon meshes and water blockers, replace east water shading only.
	for n in c.world.get_children():
		if n is MeshInstance3D and String(n.name).begins_with("NorthWater_east"):
			var water=ShaderMaterial.new();water.shader=preload("res://shaders/lake_water.gdshader")
			water.set_shader_parameter("lake_atlas",load("res://assets/textures/lake_monet_atlas_v1.png"));n.material_override=water;n.set_meta("lake_water",true)
	var pad_count=0;var reed_count=0;var shrub_count=0
	for batch in pads:pad_count+=batch.size()
	for batch in reeds:reed_count+=batch.size()
	for batch in shrubs:shrub_count+=batch.size()
	c.world.set_meta("lake_bark_records",records)
	c.world.set_meta("yijian_garden",{"willows":records.size(),"lotus_clusters":pad_count,"reed_clumps":reed_count,"shore_stone_groups":stones.size(),"shrubs":shrub_count,"sample_only":"--lake-sample" in OS.get_cmdline_user_args(),"map_changed":false,"positions":positions})
	print("LAKE_READY willows=",records.size()," lotus=",pad_count," reeds=",reed_count," stones=",stones.size()," shrubs=",shrub_count)
