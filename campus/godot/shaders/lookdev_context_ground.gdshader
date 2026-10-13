shader_type spatial;
// Distant visual continuation only: non-periodic, low-contrast color fields.
uniform vec4 dark_grass:source_color=vec4(.31,.38,.25,1.0);
uniform vec4 light_grass:source_color=vec4(.39,.46,.32,1.0);
varying vec2 ground_position;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float field(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void vertex(){ground_position=(MODEL_MATRIX*vec4(VERTEX,1)).xz;}
void fragment(){
 float variation=field(ground_position/90.0)*.78+field(ground_position/24.0)*.22;
 ALBEDO=mix(dark_grass.rgb,light_grass.rgb,variation);
 ROUGHNESS=1.0;SPECULAR=.18;
}
