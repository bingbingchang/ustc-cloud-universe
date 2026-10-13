shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;VERTEX.y+=sin(wp.x*1.7+TIME*.7)*.012+cos(wp.z*1.2+TIME*.9)*.008;}
void fragment(){
 float ripple=sin(wp.x*1.7+wp.z*1.1+TIME)*sin(wp.z*1.4-TIME*.8);
 ALBEDO=mix(vec3(.08,.18,.16),vec3(.12,.24,.21),ripple*.08+.40);
 ROUGHNESS=.42;METALLIC=.0;SPECULAR=.30;
 NORMAL=normalize(NORMAL+vec3(cos(wp.x*1.7+TIME)*.018,0,sin(wp.z*1.4-TIME)*.018));
}
