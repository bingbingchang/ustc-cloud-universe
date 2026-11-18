shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
varying flat vec2 columns;
varying flat vec2 weights;

void vertex() {
	vec3 offset = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	float yaw = atan(offset.x, offset.z) - INSTANCE_CUSTOM.x;
	float heading = mod(yaw * (8.0 / TAU), 8.0);
	float pitch = atan(offset.y, max(length(offset.xz), 0.0001));
	columns = vec2(floor(heading), mod(floor(heading) + 1.0, 8.0));
	// The bake has eight compass views at each of -10 and +30 degrees.
	// Hold the closest photograph around its exact angle to keep its fine detail.
	weights = smoothstep(vec2(0.12), vec2(0.88),
		vec2(fract(heading), (degrees(pitch) + 10.0) / 40.0));
	vec2 size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size.x,
		INV_VIEW_MATRIX[1] * size.y, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

vec4 sample_view(vec2 uv, float col, float row) {
	vec4 s = texture(atlas, (uv + vec2(col, row)) / vec2(8.0, 2.0));
	// Sample as a cutout, then mix covered colors only: an empty neighbouring
	// view must reveal the background, never tint a leaf with its empty RGB.
	float coverage = smoothstep(0.30, 0.50, s.a);
	return vec4(s.rgb * coverage, coverage);
}

vec4 sample_row(vec2 uv, vec2 cols, float row, float weight) {
	if (weight == 0.0) { return sample_view(uv, cols.x, row); }
	if (weight == 1.0) { return sample_view(uv, cols.y, row); }
	return mix(sample_view(uv, cols.x, row), sample_view(uv, cols.y, row), weight);
}

void fragment() {
	vec2 half_texel = vec2(4.0, 1.0) / vec2(textureSize(atlas, 0));
	vec2 uv = clamp(UV, half_texel, vec2(1.0) - half_texel);
	vec4 s;
	if (weights.y == 0.0) {
		s = sample_row(uv, columns, 0.0, weights.x);
	} else if (weights.y == 1.0) {
		s = sample_row(uv, columns, 1.0, weights.x);
	} else {
		s = mix(sample_row(uv, columns, 0.0, weights.x),
			sample_row(uv, columns, 1.0, weights.x), weights.y);
	}
	// Fixed screen-door coverage lets even isolated twigs dissolve gradually
	// across views while retaining depth writes between overlapping trees.
	float threshold = fract(52.9829189 * fract(dot(floor(FRAGCOORD.xy),
		vec2(0.06711056, 0.00583715))));
	if (s.a <= threshold) { discard; }
	ALBEDO = s.rgb / s.a;
}
