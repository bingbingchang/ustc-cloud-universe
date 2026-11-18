shader_type spatial;
render_mode cull_disabled;

uniform sampler2D reflection_texture : source_color, filter_linear_mipmap;
uniform sampler2D ripple_normals : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform mat4 reflection_vp;
varying vec3 world_position;

void vertex() {
	// Keep the shoreline and triangulated pond surface at the same water level.
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 position = world_position.xz;
	// Two filtered, drifting scales break up the regular grid of sine waves.
	vec2 swell_uv = position / 12.0 + TIME * vec2(0.008, -0.005);
	vec2 ripple_uv = vec2(position.y, -position.x) / 5.5 + TIME * vec2(-0.013, 0.009);
	vec2 swell = texture(ripple_normals, swell_uv).xy * 2.0 - 1.0;
	vec2 ripple = texture(ripple_normals, ripple_uv).xy * 2.0 - 1.0;
	vec2 slope = swell * 0.18 + vec2(-ripple.y, ripple.x) * 0.10;
	vec3 water_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(water_normal, 0.0)).xyz);

	// Sample the same mirrored camera as the retained reflection frame.
	vec3 ripple_position = world_position + vec3(slope.x, 0.0, slope.y) * 1.5;
	vec4 clip = reflection_vp * vec4(ripple_position, 1.0);
	vec2 uv = clip.xy / max(clip.w, 0.0001) * 0.5 + 0.5;
	uv.y = 1.0 - uv.y;
	vec2 edge = min(uv, vec2(1.0) - uv);
	float coverage = step(0.0001, clip.w) * smoothstep(0.0, 0.025, min(edge.x, edge.y));
	vec3 reflected = texture(reflection_texture, clamp(uv, vec2(0.004), vec2(0.996))).rgb;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float reflection_weight = (0.16 + 0.64 * fresnel) * coverage;
	float water_variation = 0.5 + 0.5 * sin(position.x * 0.058 + position.y * 0.023) * cos(position.y * 0.067);
	vec3 tint = mix(vec3(0.018, 0.060, 0.045), vec3(0.030, 0.085, 0.068), water_variation);
	ALBEDO = tint * (1.0 - reflection_weight);
	EMISSION = reflected * vec3(0.86, 0.97, 0.92) * reflection_weight;
	ROUGHNESS = 0.24;
	SPECULAR = 0.12;
	METALLIC = 0.0;
}
