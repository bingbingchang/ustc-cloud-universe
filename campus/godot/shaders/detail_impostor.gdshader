shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float max_distance=0.0;
varying flat vec2 tile;
varying flat float view_distance;
void vertex() {
	vec3 center=MODEL_MATRIX[3].xyz;
	vec3 delta=INV_VIEW_MATRIX[3].xyz-center;
	view_distance=length(delta);
	float yaw=atan(delta.x,delta.z)-INSTANCE_CUSTOM.x;
	tile=vec2(mod(floor(yaw*8.0/6.28318530718+0.5),8.0),atan(delta.y,length(delta.xz))>0.1745329252?1.0:0.0);
	vec3 scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),1.0);
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*scale.x,INV_VIEW_MATRIX[1]*scale.y,INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX=mat3(MODELVIEW_MATRIX);
}
void fragment(){
	if(max_distance>0.0 && view_distance>max_distance){discard;}
	vec4 color=texture(atlas,(UV+tile)/vec2(8.0,2.0));
	ALBEDO=color.rgb;ALPHA=color.a;ALPHA_SCISSOR_THRESHOLD=0.4;
}
