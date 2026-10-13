extends RefCounted
## Runtime two-bone deformation of the existing mascot meshes. GLBs stay frozen.
## The original NPR material is extended only in vertex(); shoes are real nodes.
var actor:Node3D
var legs={}
var shader_cache={}
const UNIFORMS="""
uniform mat4 wander_mesh_to_leg;
uniform mat4 wander_leg_to_mesh;
uniform mat4 wander_upper;
uniform mat4 wander_lower;
uniform float wander_knee_y = -0.19;
uniform float wander_weight = 0.0;
"""
const DEFORM="""
 vec3 wander_v_wp=(wander_mesh_to_leg*vec4(VERTEX,1.0)).xyz;
 float wander_v_wk=1.0-smoothstep(wander_knee_y-0.045,wander_knee_y+0.045,wander_v_wp.y);
 vec3 wander_v_wu=(wander_upper*vec4(wander_v_wp,1.0)).xyz;
 vec3 wander_v_wl=(wander_lower*vec4(wander_v_wp,1.0)).xyz;
 vec3 wander_v_wn=transpose(inverse(mat3(wander_mesh_to_leg)))*NORMAL;
 vec3 wander_v_wnu=transpose(inverse(mat3(wander_upper)))*wander_v_wn;
 vec3 wander_v_wnl=transpose(inverse(mat3(wander_lower)))*wander_v_wn;
 vec3 wander_v_wv=(wander_leg_to_mesh*vec4(mix(wander_v_wu,wander_v_wl,wander_v_wk),1.0)).xyz;
 vec3 wander_v_wnormal=normalize(transpose(inverse(mat3(wander_leg_to_mesh)))*mix(wander_v_wnu,wander_v_wnl,wander_v_wk));
 VERTEX=mix(VERTEX,wander_v_wv,wander_weight);
 NORMAL=normalize(mix(NORMAL,wander_v_wnormal,wander_weight));
"""

func setup(owner_actor:Node3D,role:String,bones:Dictionary):
	actor=owner_actor
	var keys=["L","R"] if role!="leaf_cat" else ["FrontL","FrontR","BackL","BackR"]
	for key in keys:
		var leg:Node3D=bones[key if role=="leaf_cat" else "Leg"+key]
		var foot_center=Vector3(0,-.370,-.025);var sole=.036;var knee=-.19;var l1=.207;var l2=.203
		var foot_names=["PlainShoe","CreamSole"]
		if role=="meituan":
			foot_center=Vector3(-.016 if key=="L" else .016,-.230,-.095);sole=.07;knee=-.12;l1=.15;l2=.17;foot_names=["LongHindFoot"]
		elif role=="leaf_cat":
			foot_center=Vector3(0,-.169,-.019);sole=.031;knee=-.085;l1=.110;l2=.105;foot_names=["CatPaw"]
		var foot=Node3D.new();foot.name="WanderFoot_"+key;actor.add_child(foot)
		foot.position=actor.to_local(leg.to_global(foot_center))
		var mats=[]
		for mesh in leg.find_children("*","MeshInstance3D",true,false):
			var is_foot=false
			for prefix in foot_names:
				if String(mesh.name).begins_with(prefix):is_foot=true
			if is_foot:
				mesh.reparent(foot,true)
				continue
			var mesh_to_leg=leg.global_transform.affine_inverse()*mesh.global_transform
			mesh.extra_cull_margin=.4
			for surface in range(mesh.mesh.get_surface_count()):
				var original=mesh.get_active_material(surface);var mat:ShaderMaterial
				if original is ShaderMaterial:
					mat=original.duplicate();var source:String=original.shader.code
					if not shader_cache.has(source):
						var shader=Shader.new()
						var marker="void vertex()" if source.contains("void vertex()") else "void vertex ()"
						var at=source.find(marker)
						if at>=0:
							var brace=source.find("{",at)
							shader.code=source.substr(0,at)+UNIFORMS+source.substr(at,brace-at+1)+DEFORM+source.substr(brace+1)
						else:shader.code=source+UNIFORMS+"\nvoid vertex(){"+DEFORM+"}\n"
						shader_cache[source]=shader
					mat.shader=shader_cache[source]
				else:
					mat=ShaderMaterial.new();var shader=Shader.new()
					shader.code="shader_type spatial;\nuniform vec4 base_color:source_color=vec4(.25,.3,.35,1);\n"+UNIFORMS+"void vertex(){"+DEFORM+"}\nvoid fragment(){ALBEDO=base_color.rgb;ROUGHNESS=.85;}"
					mat.shader=shader
					if original is StandardMaterial3D:mat.set_shader_parameter("base_color",original.albedo_color)
				mat.set_shader_parameter("wander_mesh_to_leg",mesh_to_leg)
				mat.set_shader_parameter("wander_leg_to_mesh",mesh_to_leg.affine_inverse())
				mat.set_shader_parameter("wander_knee_y",knee)
				mat.set_shader_parameter("wander_upper",Transform3D())
				mat.set_shader_parameter("wander_lower",Transform3D())
				mesh.set_surface_override_material(surface,mat);mats.append(mat)
		legs[key]={"leg":leg,"foot":foot,"foot_rest":foot.transform,"sole":sole,"knee":Vector3(0,knee,0),"ankle":foot_center,"l1":l1,"l2":l2,"materials":mats}
	return legs.size()

func apply(state:Dictionary)->Dictionary:
	var result={"feet_world":{},"foot_error_m":{},"knee_world":{},"finite":true}
	var weight=float(state.walking_weight)
	for key in legs:
		var s=legs[key];var leg:Node3D=s.leg;var foot:Node3D=s.foot
		# During the stationary story the old paw reach remains intact.
		var neutral_world=leg.to_global(s.ankle)
		var target_world:Vector3=state.feet[key].position+Vector3.UP*float(s.sole)
		var blended:Vector3=neutral_world.lerp(target_world,weight)
		foot.global_position=blended
		foot.global_basis=leg.global_basis.slerp(Basis(Vector3.UP,state.feet[key].heading),weight)
		var target=leg.to_local(target_world);var d=clampf(target.length(),.005,s.l1+s.l2-.001)
		var direction=target.normalized();var pole=Vector3(0,0,-1)
		var bend=(pole-direction*direction.dot(pole)).normalized()
		var along=(s.l1*s.l1-s.l2*s.l2+d*d)/(2*d)
		var knee:Vector3=direction*along+bend*sqrt(maxf(0,s.l1*s.l1-along*along))
		var ankle:Vector3=direction*d
		var upper_basis=Basis(Quaternion(Vector3.DOWN,knee.normalized()))*Basis.from_scale(Vector3(1,s.l1/absf(s.knee.y),1))
		var upper=Transform3D(upper_basis,Vector3.ZERO)
		var rest_lower:Vector3=s.ankle-s.knee;var axis=rest_lower.normalized();var stretch=s.l2/rest_lower.length()-1.0
		var stretch_basis=Basis(Vector3.RIGHT+axis*axis.x*stretch,Vector3.UP+axis*axis.y*stretch,Vector3.BACK+axis*axis.z*stretch)
		var lower_basis=Basis(Quaternion(axis,(ankle-knee).normalized()))*stretch_basis
		var lower=Transform3D(lower_basis,knee-lower_basis*s.knee)
		for mat in s.materials:
			mat.set_shader_parameter("wander_upper",upper);mat.set_shader_parameter("wander_lower",lower);mat.set_shader_parameter("wander_weight",weight)
		result.feet_world[key]=foot.global_position-Vector3.UP*float(s.sole)
		# Validate the very same bind endpoint sent to the GPU, not just ideal IK.
		result.foot_error_m[key]=leg.to_global(lower*s.ankle).distance_to(target_world)*weight
		result.knee_world[key]=leg.to_global(knee)
		result.finite=result.finite and blended.is_finite() and knee.is_finite() and foot.global_basis.x.is_finite()
	return result

