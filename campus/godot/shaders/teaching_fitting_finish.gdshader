shader_type spatial;

uniform vec4 tint : source_color = vec4(1.0);
uniform int finish = 0;
uniform float roughness = .53;
uniform sampler2D wood_grain : source_color, repeat_enable, filter_linear_mipmap;
varying vec3 world_position;

float grain_hash(vec2 cell) {
	return fract(52.9829189 * fract(dot(cell, vec2(.06711056, .00583715))));
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float tone = 1.0;
	if (finish == 0) {
		vec3 grain = texture(wood_grain, UV * vec2(.85, 2.8)).rgb;
		tone = .87 + dot(grain, vec3(.21, .72, .07)) * .45;
	} else if (finish == 1) {
		vec2 pattern = UV * 58.0;
		float edge = max(length(fwidth(pattern)), .018);
		float hole = 1.0 - smoothstep(.11, .11 + edge, length(fract(pattern) - .5));
		tone = 1.0 - .61 * hole * (1.0 - smoothstep(.16, .47, edge));
	} else {
		vec2 pattern = world_position.xz * 151.0;
		float edge = length(fwidth(pattern));
		tone += (grain_hash(floor(pattern)) - .5) * .25 * (1.0 - smoothstep(.13, .70, edge));
	}
	ALBEDO = tint.rgb * tone;
	ROUGHNESS = roughness;
	SPECULAR = .26;
}
