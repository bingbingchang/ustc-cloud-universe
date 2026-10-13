shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color=vec4(.92,.7,.73,1);
uniform bool graybox=false;
uniform float foliage=.65;
uniform float rough=.9;
varying vec3 wp;
#include "res://shaders/sakura_paint.gdshaderinc"
uniform bool paint_enabled=false;
void vertex(){
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float amp=clamp(VERTEX.y*.005,0.0,.038);
 VERTEX.x+=sin(TIME*.8+wp.x*.7+wp.z*.38)*amp;
 VERTEX.z+=sin(TIME*1.1+wp.z*.4)*amp*.4;
 NORMAL=normalize(mix(NORMAL,vec3(0,1,0),.42));
}
void fragment(){
 vec3 col=base_color.rgb*(.96+.04*sin(wp.x*2.1+wp.y*1.7+wp.z));
 if(paint_enabled){
  vec2 at=vec2(.504)+(1.0-abs(mod((wp.xy+wp.zy*.37)/.38,2.0)-1.0))*.492;
  vec3 pigment=texture(paint_atlas,at).rgb;
  col*=mix(vec3(1.0),pigment/vec3(.86,.65,.63),.55);
 }
 ALBEDO=graybox?vec3(.55):col;
 ROUGHNESS=.95;SPECULAR=.12;BACKLIGHT=base_color.rgb*.48;
}
void light(){
 float n=dot(NORMAL,LIGHT);
 float diffuse=.35+.65*smoothstep(-.4,.85,n);
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*diffuse/PI;
}
