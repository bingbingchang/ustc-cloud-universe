shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform mat4 source_inverse;
varying flat vec2 tile;
void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 camera_delta = INV_VIEW_MATRIX[3].xyz - center;
	vec3 local_delta = mat3(source_inverse) * camera_delta;
	float yaw = atan(local_delta.x, local_delta.z);
	float column = mod(floor(yaw * 8.0 / 6.28318530718 + 0.5), 8.0);
	float pitch = atan(local_delta.y, length(local_delta.xz));
	tile = vec2(column, pitch > 0.1745329252 ? 1.0 : 0.0);
	// Each rendering camera (including the mirrored water camera) gets its own
	// view selection. No per-frame CPU material updates or main-camera lock.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec4 sample_color = texture(atlas, (UV + tile) / vec2(8.0, 2.0));
	ALBEDO = sample_color.rgb;
	ALPHA = sample_color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
}
