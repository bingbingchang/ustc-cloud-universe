shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;VERTEX.y+=sin(wp.x*1.7+TIME*.7)*.012+cos(wp.z*1.2+TIME*.9)*.008;}
void fragment(){
 float ripple=sin(wp.x*1.7+wp.z*1.1+TIME)*sin(wp.z*1.4-TIME*.8);
 ALBEDO=mix(vec3(.012,.036,.03),vec3(.027,.063,.054),ripple*.08+.40);
 ROUGHNESS=.18;METALLIC=.10;SPECULAR=.55;
 NORMAL=normalize(NORMAL+vec3(cos(wp.x*1.7+TIME)*.018,0,sin(wp.z*1.4-TIME)*.018));
}
