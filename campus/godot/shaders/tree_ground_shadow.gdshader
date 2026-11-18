shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, depth_draw_never, shadows_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D atlas : filter_linear, repeat_disable;
uniform float row_count = 1.0;
uniform vec3 sun_right;
uniform vec3 sun_up;
uniform vec2 shadow_handoff = vec2(80.0, 100.0);
const float fade_start = 260.0;
const float fade_end = 410.0;
varying flat vec3 footprint_center;
varying flat float inverse_width;
varying flat vec4 footprint_info;

void vertex() {
	footprint_center = MODEL_MATRIX[3].xyz;
	inverse_width = 1.0 / length(MODEL_MATRIX[0].xyz);
	footprint_info = INSTANCE_CUSTOM;
	float extent = (length(MODEL_MATRIX[0].xyz) + length(MODEL_MATRIX[2].xyz)) * 0.5 + 2.0;
	float view_depth = -(VIEW_MATRIX * vec4(footprint_center,1.0)).z;
	// Sun cascades fade in view-space depth, rather than radial tree distance.
	if (view_depth + extent < shadow_handoff.x || distance(CAMERA_POSITION_WORLD,footprint_center) - extent > fade_end) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	} else {
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
}

void fragment() {
	float depth = texture(scene_depth, SCREEN_UV).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV,depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc,1.0);
	view /= view.w;
	vec3 world = (INV_VIEW_MATRIX * view).xyz;
	vec3 rel = world - footprint_center;
	vec3 normal = cross(dFdx(world),dFdy(world));
	// Never project a box on a wall, roof, or the neighbouring lake.
	if (abs(rel.y) > 1.35 || abs(normal.y) < .72 * length(normal) ||
		abs(world.y - footprint_info.z) < .030) { discard; }
	vec2 uv = vec2(.5 + dot(rel,sun_right)*inverse_width,
		.5 - dot(rel,sun_up)*footprint_info.y);
	if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) { discard; }
	float handoff = smoothstep(shadow_handoff.x, max(shadow_handoff.x+.01,shadow_handoff.y), -view.z);
	float range_fade = 1.0 - smoothstep(fade_start,fade_end,length(view.xyz));
	vec2 safe_uv = clamp(uv,vec2(.5/32.0),vec2(1.0-.5/32.0));
	float coverage = texture(atlas,(safe_uv + footprint_info.xw)/vec2(8.0,row_count)).r;
	ALBEDO = vec3(0.0);
	ALPHA = .50 * handoff * range_fade * coverage;
}
