shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 main_camera=vec3(0.0);
varying flat float distance_to_view;
varying flat float column;
void vertex(){
	distance_to_view=length(main_camera-MODEL_MATRIX[3].xyz);
	column=INSTANCE_CUSTOM.x;
}
void fragment(){
	if(distance_to_view<15.0){discard;}
	vec4 color=texture(atlas,(UV+vec2(column,1.0))/vec2(8.0,2.0));
	ALBEDO=color.rgb;ALPHA=color.a;ALPHA_SCISSOR_THRESHOLD=.4;
}
