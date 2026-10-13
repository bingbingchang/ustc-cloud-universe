shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	vec2 p = UV;
	float spread = .045 + p.y*.38;
	float edge = abs(abs(p.x-.5)-spread);
	float ripples = exp(-edge*edge*1600.0);
	float cross_wave = .35+.65*sin((p.y*26.0-TIME*2.5))*sin((p.y*26.0-TIME*2.5));
	ALBEDO = vec3(.69,.77,.66);
	ALPHA = ripples * cross_wave * sin(p.y*3.14159) * .32;
}
