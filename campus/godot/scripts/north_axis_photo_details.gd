extends RefCounted

const North=preload("res://scripts/north_axis_environment.gd")
const Geometry=preload("res://scripts/wave2_environment.gd")
const Surfaces=preload("res://scripts/road_surfaces.gd")
const OVERLOOK:=Rect2(16.63,122.5,4.4,4.4)
const EXPERT_ENTRY:=Rect2(64.6,37.2,9.8,8.7)

static func matte(color:Color)->StandardMaterial3D:
	var result:=StandardMaterial3D.new()
	result.albedo_color=color
	result.roughness=.87
	return result

static func road_paint(c:Node3D,parts:Array,label:String,height:float=.143)->void:
	var paint:=matte(Color(.64,.53,.238))
	paint.cull_mode=BaseMaterial3D.CULL_DISABLED
	North._surface(c,parts,height,paint,label)

static func old_gate(c:Node3D)->void:
	var line:=PackedVector2Array([Vector2(11.0,-8.40),Vector2(7.1,-8.08),Vector2(4.49,-6.48),
		Vector2(2.18,-3.25),Vector2(.48,-.73),Vector2(.025,2.8),Vector2(.04,11.1)])
	road_paint(c,North._stroke(line,.075),"OldGateYellowCenter")
	var piers=[]
	var paving=[]
	for x in [-11.17,-5.1,3.10,9.18]:
		piers.append(Geometry._box_transform(Vector3(x,.255,2.65),Vector3(1.41,.39,1.96),0))
		for side in [-1,1]:
			paving.append(North._rect(x-.85,2.65+side*1.39-.23,1.7,.46))
	Geometry._box_batch(c,piers,matte(Color(.43,.403,.359)),"OldGateStonePlinths")
	North._surface(c,paving,.084,Surfaces.material(c,"pavers"),"OldGatePierPaving")
	for x in [-5.9,5.91]:
		var shell:MeshInstance3D=c.box(Vector3(x,.56,-.27),Vector3(.13,.91,.17),matte(Color(.18,.21,.20)))
		shell.name="OldGatePedestrianBollard"
		c.static_box(Vector3(x,.56,-.27),Vector3(.13,.91,.17),"OldGateBollardContact")

static func teaching_one(c:Node3D, open_visit: bool)->void:
	var asphalt:=North._rect(-15.5,153.8,31.0,10.90)
	North._surface(c,[asphalt],.112,Surfaces.material(c,"asphalt"),"TeachingOneEntranceCourt")
	North._solid(c,[asphalt],.08,.112,"TeachingOneEntranceCourtContact")
	teaching_one_keep_clear(c)
	teaching_one_side_ramps(c)
	teaching_one_clear_legacy_entry(c)
	var stone:=matte(Color(.52,.48,.413))
	var bronze:=matte(Color(.48,.345,.158))
	var dark:=matte(Color(.22,.181,.123))
	var canopy=c.box(Vector3(0,4.68,165.85),Vector3(12.34,.45,3.98),stone)
	canopy.name="TeachingOneDeepStoneCanopy"
	c.box(Vector3(0,4.52,163.85),Vector3(12.39,.122,.15),dark)
	for x in [-5.50,5.50]:
		c.box(Vector3(x,2.36,164.43),Vector3(.44,4.30,.50),stone)
		c.static_box(Vector3(x,2.36,164.43),Vector3(.44,4.30,.50),"TeachingOnePorticoPier")
	if open_visit:
		teaching_one_glazing(c,stone,bronze)
		return
	var bars=[]
	for x in [-4.42,-2.95,-1.48,0.0,1.48,2.95,4.42]:
		bars.append(Geometry._box_transform(Vector3(x,2.34,167.245),Vector3(.065,3.78,.054),0))
	for y in [.49,2.76,4.16]:
		bars.append(Geometry._box_transform(Vector3(0,y,167.245),Vector3(8.91,.061,.055),0))
	Geometry._box_batch(c,bars,bronze,"TeachingOneDoorBrassFrames")


static func teaching_one_keep_clear(c: Node3D) -> void:
	# The two entrance photos show a broad diamond hatch, not a filled panel.
	# A closed offset_polyline returns an outer loop AND a hole; _surface treats
	# each loop as solid. Build each border separately so the asphalt stays visible.
	var area := Rect2(-11.2,156.0,22.4,7.0)
	var outline := North._rect(area.position.x,area.position.y,area.size.x,area.size.y)
	var yellow: Array = []
	for i in 4:
		var edge := PackedVector2Array([outline[i],outline[(i+1)%4]])
		yellow.append_array(North._stroke(edge,.078))
	for direction in [-1.0,1.0]:
		for i in range(-3,11):
			var x := area.position.x + float(i)*3.2
			var line := PackedVector2Array([Vector2(x,area.position.y),
				Vector2(x+direction*area.size.y,area.end.y)])
			for strip in North._stroke(line,.065):
				yellow.append_array(Geometry2D.intersect_polygons(strip,outline))
	var paint := matte(Color("c8b573"))
	paint.cull_mode=BaseMaterial3D.CULL_DISABLED
	var mesh := North._surface(c,yellow,.117,paint,"TeachingOneYellowKeepClear")
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.set_meta("teaching_one_approach",true)


static func teaching_one_side_ramps(c: Node3D) -> void:
	# Photo-estimated dimensions tied to the existing measured entrance heights:
	# 1.60 m clear width, 6.5 m run, 0.112 -> 0.48 m (about 1:18).
	# The turn landings go around the portico columns, joining the original
	# top tread/landing behind them. Keep the planting beds and stairs intact.
	var stone := Surfaces.material(c,"concrete")
	for side in [-1.0,1.0]:
		var suffix := "West" if side<0.0 else "East"
		var ramp := Rect2(-14.0 if side<0.0 else 7.5,163.25,6.5,1.60)
		var heights := [.112,.48,.48,.112] if side<0.0 else [.48,.112,.112,.48]
		_entry_wedge(c,ramp,heights,stone,"TeachingOneSideRamp"+suffix)
		var landing := Rect2(-7.5 if side<0.0 else 6.0,163.25,1.5,3.975)
		_entry_wedge(c,landing,[.48,.48,.48,.48],stone,"TeachingOneSideLanding"+suffix)
		var kerb_heights: Array = []
		for height: float in heights:
			kerb_heights.append(height+.10)
		for z in [163.13,164.85]:
			_entry_wedge(c,Rect2(ramp.position.x,z,6.5,.12),kerb_heights,stone,
				"TeachingOneRampEdge"+suffix+str(z))
		_entry_wedge(c,Rect2(landing.position.x,163.13,1.5,.12),[.58,.58,.58,.58],stone,
			"TeachingOneLandingFrontEdge"+suffix)
		_entry_wedge(c,Rect2(-7.62 if side<0.0 else 7.5,164.85,.12,2.375),
			[.58,.58,.58,.58],stone,"TeachingOneLandingOuterEdge"+suffix)
	c.world.set_meta("teaching_one_side_ramps",true)


static func teaching_one_clear_legacy_entry(c: Node3D) -> void:
	# The archived model has another pair of thin posts at z=166.75, plus
	# stair rails. They block the side approach behind the photo-based columns.
	# Remove only whole triangles belonging to these narrow old components.
	var model: Node3D = c.world.get_node_or_null("LookdevTeachingHall")
	if not model:
		return
	var removed := 0
	for part in model.get_children():
		if not part is MeshInstance3D or not (part.name.ends_with("_Stone") or part.name.ends_with("_Metal")):
			continue
		var replacement := ArrayMesh.new()
		for surface in part.mesh.get_surface_count():
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for index in points.size():
					indices.append(index)
			var masked := PackedByteArray()
			masked.resize(points.size())
			for index in points.size():
				var p: Vector3 = part.to_global(points[index])
				var post := absf(absf(p.x)-5.6)<.131 and p.y>=.039 and p.y<=4.761 and p.z>=166.619 and p.z<=166.881
				var rail := absf(absf(p.x)-5.6)<.031 and p.y>=.22 and p.y<=1.20 and p.z>=164.269 and p.z<=166.331
				masked[index]=int(post or rail)
			var kept := PackedInt32Array()
			for offset in range(0,indices.size(),3):
				if masked[indices[offset]] and masked[indices[offset+1]] and masked[indices[offset+2]]:
					removed+=1
				else:
					kept.append_array(indices.slice(offset,offset+3))
			if not kept.is_empty():
				arrays[Mesh.ARRAY_INDEX]=kept
				replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				replacement.surface_set_material(replacement.get_surface_count()-1,part.mesh.surface_get_material(surface))
		if replacement.get_surface_count()>0:
			part.mesh=replacement
		else:
			part.hide()
	c.world.set_meta("teaching_one_removed_legacy_triangles",removed)


static func _entry_wedge(c: Node3D, area: Rect2, heights: Array, material: Material, label: String) -> void:
	var footprint := North._rect(area.position.x,area.position.y,area.size.x,area.size.y)
	var vertices := PackedVector3Array()
	for i in 4:
		vertices.append(Vector3(footprint[i].x,heights[i],footprint[i].y))
	for point: Vector2 in footprint:
		vertices.append(Vector3(point.x,.08,point.y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]
	for face: Array in faces:
		var normal := (vertices[face[1]]-vertices[face[0]]).cross(vertices[face[2]]-vertices[face[0]]).normalized()
		for index in [0,1,2,0,2,3]:
			var vertex := vertices[face[index]]
			st.set_normal(normal)
			st.set_uv(Vector2(vertex.x,vertex.z) if absf(normal.y)>.5 else Vector2(vertex.x+vertex.z,vertex.y))
			st.add_vertex(vertex)
	var mesh := MeshInstance3D.new()
	mesh.name=label
	mesh.mesh=st.commit()
	mesh.material_override=material
	mesh.set_meta("teaching_one_approach",true)
	c.world.add_child(mesh)
	# The visible plane and collider use the same four elevations.
	North._sloped_solid(c,footprint,.08,heights,label+"Contact")


static func teaching_one_glazing(c: Node3D, stone: Material, bronze: StandardMaterial3D) -> void:
	var edge := Vector3(0,.245,167.61)
	var size := Vector3(9,.47,.8)
	c.box(edge,size,stone)
	c.static_box(edge,size,"TeachingOneThreshold")
	var glass := preload("res://scripts/campus_visit_interior.gd").clear_glass(Color(.38,.51,.51))
	var panes=[]
	for opening in [Vector2(-4.49,-2.56),Vector2(-.151,.151),Vector2(2.56,4.49)]:
		panes.append(Geometry._box_transform(Vector3((opening.x+opening.y)*.5,1.65,167.46),
			Vector3(opening.y-opening.x,2.34,.052),0))
	panes.append(Geometry._box_transform(Vector3(0,3.46,167.46),Vector3(8.98,1.31,.055),0))
	Geometry._box_batch(c,panes,glass,"TeachingOneFixedGlazing")
	var frames=[]
	for x in [-4.49,-2.56,-.151,.151,2.56,4.49]:
		frames.append(Geometry._box_transform(Vector3(x,2.31,167.421),Vector3(.057,3.62,.063),0))
	for y in [2.80,4.115]:
		frames.append(Geometry._box_transform(Vector3(0,y,167.42),Vector3(9.01,.066,.064),0))
	Geometry._box_batch(c,frames,bronze,"TeachingOneFixedDoorFrames")
	fixed_sign(c,"第一教学楼",Vector3(0,4.76,163.76),.015,Color("c7a76a"),PI)

static func new_gate(c:Node3D)->void:
	var pale:=matte(Color(.53,.51,.454))
	var tarmac:=Surfaces.material(c,"asphalt")
	# Huangshan Road continues outside the playable map. Keep the gateway open
	# to the broad near-side pavement, with a planted corner on its eastern edge.
	var paving:=North.polygon([[103.3,-70.5],[117.3,-70.5],[117.2,-82.1],[103.8,-82.0]])
	North._surface(c,[paving],.119,tarmac,"HuangshanGateApron")
	North._solid(c,[paving],-.12,.119,"HuangshanGateApronWalkable")
	var kerb=[]
	for endpoints in [[Vector2(117.55,-71.10),Vector2(117.73,-75.43)],
			[Vector2(117.73,-75.43),Vector2(118.60,-77.03)],
			[Vector2(118.60,-77.03),Vector2(121.83,-77.47)]]:
		var a:Vector2=endpoints[0]
		var b:Vector2=endpoints[1]
		var p:Vector2=(a+b)*.5
		kerb.append(Geometry._box_transform(Vector3(p.x,.122,p.y),Vector3(.195,.23,a.distance_to(b)+.035),atan2(b.x-a.x,b.y-a.y)))
	Geometry._box_batch(c,kerb,pale,"HuangshanGateCurvedKerb")
	var marks=[]
	for i in range(7):
		marks.append(North._rect(103.70+i*1.64,-80.0,.64,2.88))
	var marking:=matte(Color(.71,.71,.66))
	marking.cull_mode=BaseMaterial3D.CULL_DISABLED
	North._surface(c,marks,.123,marking,"HuangshanGatePedestrianMarking")

static func expert_hotel(c:Node3D)->void:
	# GIS #91 shows the canopy opening onto the parking court east of the short
	# projecting bay. The south wall of the long wing faces the pond.
	var silver:=matte(Color(.52,.54,.52))
	silver.metallic=.2
	silver.roughness=.54
	var ivory:=matte(Color(.52,.432,.327))
	var render:=matte(Color(.53,.353,.278))
	var glass:=matte(Color(.094,.142,.131))
	glass.roughness=.32
	var red:=matte(Color(.31,.061,.046))
	red.cull_mode=BaseMaterial3D.CULL_DISABLED
	var court:=North.polygon([[64.74,35.53],[69.3,33.4],[83.8,35.84],[93.6,38.22],
		[94.15,44.16],[86.0,49.2],[79.0,51.85],[65.7,51.15],[61.35,47.18],
		[64.75,44.58]])
	const floor_y:=.149
	const center_z:=41.48
	North._surface(c,[court],floor_y,Surfaces.material(c,"pavers"),"ExpertHotelPavedForecourt")
	North._solid(c,[court],-.20,floor_y,"ExpertHotelForecourtWalk")
	for i in range(2):
		var top:=floor_y+.085*(2-i)
		var depth:=1.67+i*.33
		var p:=Vector3(64.65+depth*.5,(floor_y+top)*.5,center_z)
		var size:=Vector3(depth,top-floor_y,5.80)
		c.box(p,size,ivory)
		c.static_box(p,size,"ExpertHotelEntranceStep")
	var carpet:=North._rect(64.78,center_z-1.94,1.35,3.88)
	North._surface(c,[carpet],floor_y+.176,red,"ExpertHotelRedEntranceMat")
	var roof:=c.box(Vector3(66.27,3.51,center_z),Vector3(3.37,.23,6.13),silver) as MeshInstance3D
	roof.name="ExpertHotelSilverCanopy"
	c.box(Vector3(67.83,3.44,center_z),Vector3(.30,.42,6.16),silver)
	c.box(Vector3(67.66,3.25,center_z),Vector3(.22,.12,6.03),silver)
	var facets=[]
	for i in range(1,5):
		var z:=center_z-3.07+i*1.23
		facets.append(Geometry._box_transform(Vector3(66.29,3.382,z),Vector3(3.32,.026,.018),0))
		facets.append(Geometry._box_transform(Vector3(67.995,3.45,z),Vector3(.022,.41,.025),0))
	Geometry._box_batch(c,facets,glass,"ExpertHotelCanopyJoints")
	for side in [-1.0,1.0]:
		var pier:=Vector3(66.39,1.83,center_z+side*2.59)
		c.box(pier,Vector3(.51,3.13,.54),ivory)
		c.static_box(pier,Vector3(.51,3.13,.54),"ExpertHotelPorticoPier")
		c.box(Vector3(64.86,1.68,center_z+side*1.99),Vector3(.24,2.82,.43),ivory)
		c.box(Vector3(67.61,3.78,center_z+side*2.05),Vector3(.11,.42,.09),silver)
	var door:=Vector3(64.91,1.64,center_z)
	var door_size:=Vector3(.07,2.65,3.67)
	c.box(door,door_size,glass)
	c.static_box(door,door_size,"ExpertHotelClosedGlass")
	for i in range(5):
		c.box(Vector3(64.96,1.64,center_z-1.83+i*.915),Vector3(.055,2.65,.053),silver)
	c.box(Vector3(64.97,3.10,center_z),Vector3(.10,.29,3.78),glass)
	fixed_sign(c,"中科大专家楼欢迎您",Vector3(65.04,3.10,center_z),.008,Color("ff6f48"),PI*.5)
	fixed_sign(c,"中国科学技术大学专家楼",Vector3(68.01,3.98,center_z),.0125,Color("e1dfd2"),PI*.5)
	fixed_sign(c,"University of Science and Technology of China Guesthouse",
		Vector3(68.02,3.73,center_z),.0044,Color("c5c3b8"),PI*.5)
	var sills=[]
	var infill=[]
	for bay in range(8):
		var x:=61.19+3.558*bay
		var wall_z:=30.61+(x-59.41)*.0343
		for level in range(2):
			var y:=3.27+3.125*level
			sills.append(Geometry._box_transform(Vector3(x,y-.36,wall_z+.112),Vector3(1.94,.12,.21),-.0343))
			infill.append(Geometry._box_transform(Vector3(x,y,wall_z+.096),Vector3(1.85,.56,.101),-.0343))
		sills.append(Geometry._box_transform(Vector3(x-1.20,3.52,wall_z+.083),Vector3(.105,6.78,.21),-.0343))
	Geometry._box_batch(c,sills,ivory,"ExpertHotelCourtWindowTrim")
	Geometry._box_batch(c,infill,render,"ExpertHotelCourtInfill")

static func fixed_sign(c:Node3D,caption:String,position:Vector3,pixel_size:float,color:Color,rotation:float=0.0)->void:
	var sign:=Label3D.new()
	sign.text=caption
	sign.font=preload("res://scripts/campus_font.gd").get_font()
	sign.font_size=32
	sign.pixel_size=pixel_size
	sign.outline_size=0
	sign.modulate=color
	sign.position=position
	sign.rotation.y=rotation
	c.world.add_child(sign)

static func expert_apartments(c:Node3D)->void:
	# Album 10626 shows the separate gatehouse. Album 10627 shows the long approach
	# between small planted beds, running from the southern roadway toward No. 1.
	var brick:=matte(Color(.38,.147,.10))
	var render:=matte(Color(.55,.47,.368))
	var glass:=matte(Color(.107,.171,.175))
	glass.roughness=.28
	var roof:=matte(Color(.39,.357,.314))
	var stone:=Surfaces.material(c,"pavers")
	var positions: Array[Vector3]=[Vector3(128.9,.14,78.0),Vector3(136.5,.14,136.45)]
	for pos in positions:
		var pad:=North._rect(pos.x-3.43,pos.z-1.88,6.86,7.35)
		North._surface(c,[pad],.111,stone,"ExpertApartmentStoneApron")
		North._solid(c,[pad],-.10,.111,"ExpertApartmentApronWalk")
		for side in [-1,1]:
			var x:float=pos.x+side*2.52
			var pot:=North._rect(x-.65,pos.z+1.33,1.3,3.0)
			North._surface(c,[pot],.19,render,"ExpertApartmentSquarePlanter")
	var booth:=positions[0]+Vector3(-4.3,0,1.22)
	c.box(booth+Vector3(0,.19,0),Vector3(3.82,.38,3.01),render)
	c.box(booth+Vector3(0,1.63,-1.4),Vector3(3.64,2.66,.21),brick)
	for x in [-1.69,1.69]:
		c.box(booth+Vector3(x,1.61,0),Vector3(.35,2.69,2.91),brick)
	c.box(booth+Vector3(0,2.95,0),Vector3(3.90,.29,3.30),roof)
	for x in [-.96,.92]:
		c.box(booth+Vector3(x,1.73,1.45),Vector3(1.17,1.43,.066),glass)
		c.box(booth+Vector3(x,2.52,1.48),Vector3(1.26,.12,.14),render)
	c.box(booth+Vector3(0,.88,1.43),Vector3(3.50,.98,.18),render)
	c.static_box(booth+Vector3(0,1.5,0),Vector3(3.70,2.86,2.96),"ExpertApartmentGatehouse")

static func lake_viewing_bank(c:Node3D)->void:
	# GIS panorama 90 shows a red deck on the near south-west shore of the east pond.
	var tile:=matte(Color(.365,.149,.110))
	var stone:=matte(Color(.50,.47,.403))
	var pad:=North.polygon([[17.5,122.65],[20.84,123.38],[20.06,126.75],[16.76,125.94]])
	var deck:=SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0,1,2,0,2,3]:
		var p:=pad[i]
		deck.set_normal(Vector3.UP)
		deck.add_vertex(Vector3(p.x,.153,p.y))
	var mesh:=MeshInstance3D.new()
	mesh.mesh=deck.commit()
	tile.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.material_override=tile
	mesh.name="LakeOverlookBrickPad"
	c.world.add_child(mesh)
	North._solid(c,[pad],-.16,.153,"LakeOverlookBrickWalk")
	var seams=[]
	for i in range(1,7):
		var a:=pad[0].lerp(pad[3],float(i)/7)
		var b:=pad[1].lerp(pad[2],float(i)/7)
		seams.append_array(North._stroke(PackedVector2Array([a,b]),.016))
	for i in range(1,10):
		var a:=pad[0].lerp(pad[1],float(i)/10)
		var b:=pad[3].lerp(pad[2],float(i)/10)
		seams.append_array(North._stroke(PackedVector2Array([a,b]),.012))
	North._surface(c,seams,.156,matte(Color(.23,.14,.117)),"LakeBrickOpenJoints")
	var seats=[]
	var rims=[]
	for i in [0,1,2]:
		var a:=pad[i]
		var b:=pad[(i+1)%pad.size()]
		var middle:=(a+b)*.5
		var heading:=atan2(b.x-a.x,b.y-a.y)
		rims.append(Geometry._box_transform(Vector3(middle.x,.129,middle.y),Vector3(.23,.105,a.distance_to(b)+.16),heading))
		if i==2:continue
		seats.append(Geometry._box_transform(Vector3(middle.x,.67,middle.y),Vector3(.27,.14,a.distance_to(b)+.19),heading))
		var body:StaticBody3D=c.static_box(Vector3(middle.x,.43,middle.y),Vector3(.25,.59,a.distance_to(b)+.13),"LakeOverlookStoneRail")
		body.rotation.y=heading
		for t in [.085,.50,.915]:
			var p:=a.lerp(b,t)
			seats.append(Geometry._box_transform(Vector3(p.x,.37,p.y),Vector3(.24,.43,.24),heading))
	Geometry._box_batch(c,rims,stone,"LakeOverlookStoneEdging")
	Geometry._box_batch(c,seats,stone,"LakeOverlookStoneSeat")
	var trail:=North._stroke(PackedVector2Array([Vector2(14.55,127.35),Vector2(16.02,126.56),Vector2(17.4,125.47)]),1.10)
	North._surface(c,trail,.104,Surfaces.material(c,"stone"),"LakeOverlookTrail")
	North._solid(c,trail,-.08,.104,"LakeOverlookTrailWalk")
