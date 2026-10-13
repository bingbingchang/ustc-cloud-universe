shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color=vec4(.13,.18,.16,1);
uniform bool graybox=false;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 float pane=fract(sin(floor(wp.x/4.0)*3.7+floor(wp.y/4.05)*5.3)*12.13);
 float curtains=smoothstep(.15,.24,fract(wp.x*.73))*smoothstep(.86,.76,fract(wp.x*.73));
 vec3 room=mix(vec3(.029,.038,.035),vec3(.065,.069,.057),curtains*.55+pane*.20);
 ALBEDO=graybox?vec3(.55):room;
 ROUGHNESS=.10+.065*pane;METALLIC=.38;SPECULAR=.90;
 CLEARCOAT=.45;CLEARCOAT_ROUGHNESS=.12;AO=.88;
}
