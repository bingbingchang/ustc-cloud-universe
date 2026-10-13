shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
// Calm water stays geometrically flat. Wide clipped triangles must never ripple
// independently; analytic world-space normals keep island/shore cells seamless.
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_position.xz;
 float a=p.x*.72+p.y*.40+TIME*.38;
 float b=p.y*1.17-p.x*.31-TIME*.31;
 float broad=sin(p.x*.058+p.y*.023)*cos(p.y*.067-p.x*.019);
 vec3 n=normalize(vec3(-cos(a)*.043+cos(b)*.017,1.0,-cos(a)*.023-cos(b)*.039));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
 float fresnel=pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),3.0);
 vec3 deep=mix(vec3(.025,.082,.075),vec3(.045,.105,.100),broad*.5+.5);
 ALBEDO=mix(deep,vec3(.13,.20,.22),fresnel*.55);
 float fine=sin(a)*sin(b)*.5+.5;
 ROUGHNESS=.25+fine*.05;SPECULAR=.5;METALLIC=0.0;
}
