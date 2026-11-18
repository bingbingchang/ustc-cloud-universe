shader_type spatial;

uniform vec4 wall_color : source_color = vec4(0.76, 0.735, 0.65, 1.0);
uniform vec2 tile_size = vec2(0.11);
uniform float joint_strength = 0.16;
uniform bool staggered_rows = false;
uniform float tile_variation = 0.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec2 tangent = normalize(vec2(n.z, -n.x) + vec2(0.00001, 0.0));
	vec2 wall_uv = vec2(dot(world_position.xz, tangent), world_position.y);
	vec2 uv = mix(wall_uv, world_position.xz, step(0.7, abs(n.y))) / tile_size;
	vec2 footprint = fwidth(uv);
	if (staggered_rows) {
		uv.x += 0.5 * mod(floor(uv.y), 2.0);
	}
	vec2 edge = min(fract(uv), 1.0 - fract(uv));
	vec2 face = smoothstep(vec2(0.012), vec2(0.012) + max(vec2(0.01), footprint), edge);
	float close_up = 1.0 - smoothstep(0.15, 0.55, max(footprint.x, footprint.y));
	float joint = (1.0 - face.x * face.y) * close_up;
	float grain = fract(sin(dot(floor(uv), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	ALBEDO = wall_color.rgb * (1.0 - joint * joint_strength + grain * close_up * tile_variation);
	ROUGHNESS = 0.84;
	SPECULAR = 0.22;
}
