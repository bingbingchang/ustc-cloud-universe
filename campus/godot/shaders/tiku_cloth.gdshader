shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
uniform vec4 base_color:source_color=vec4(.3,.43,.6,1.0);
varying vec3 cloth_pos;
void vertex(){cloth_pos=VERTEX;}
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.54);}
float noise(vec3 p){vec3 a=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(a),hash(a+vec3(1,0,0)),f.x),mix(hash(a+vec3(0,1,0)),hash(a+vec3(1,1,0)),f.x),f.y),mix(mix(hash(a+vec3(0,0,1)),hash(a+vec3(1,0,1)),f.x),mix(hash(a+vec3(0,1,1)),hash(a+vec3(1,1,1)),f.x),f.y),f.z);}
void fragment(){
 float dye=noise(cloth_pos*31.0)*.06+noise(cloth_pos*120.0)*.018;
 ALBEDO=base_color.rgb*(.960+dye);
 ROUGHNESS=.87+noise(cloth_pos*180.0)*.08;SPECULAR=.16;
}
void light(){
 float n=dot(NORMAL,LIGHT);
 float bands=.08+.28*smoothstep(-.15,.15,n)+.32*smoothstep(.18,.47,n)+.30*smoothstep(.55,.85,n);
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*bands/3.14159265;
}
