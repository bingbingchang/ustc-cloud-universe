shader_type spatial;
render_mode cull_disabled;
void fragment() {
	vec2 p = UV*12.0;
	float a = sin(p.x*6.0+p.y*3.0+TIME*.55);
	float b = sin(p.y*9.0-p.x*4.0-TIME*.42);
	ALBEDO = mix(vec3(.18,.32,.27),vec3(.33,.46,.36),.5+.15*a+.10*b);
	ROUGHNESS = .23;
	METALLIC = .18;
	NORMAL_MAP = normalize(vec3(a*.055,b*.065,1.0))*.5+.5;
	NORMAL_MAP_DEPTH = .65;
}
