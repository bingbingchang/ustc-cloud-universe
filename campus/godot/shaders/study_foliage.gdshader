shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color=vec4(.2,.35,.18,1);
varying vec3 wp;
void vertex(){
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x+=sin(TIME*.7+wp.z*.45+wp.x*.31)*clamp(VERTEX.y*.005,0.0,.055);
 NORMAL=normalize(mix(NORMAL,vec3(0,1,0),.38));
}
void fragment(){
 float variation=.93+.07*sin(wp.x*1.3+wp.z*.85+wp.y*.6);
 ALBEDO=base_color.rgb*variation*.78;ROUGHNESS=.95;SPECULAR=.10;BACKLIGHT=base_color.rgb*.45;
}
void light(){
 float n=dot(NORMAL,LIGHT);
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*(.3+.7*smoothstep(-.35,.9,n))/PI;
}
