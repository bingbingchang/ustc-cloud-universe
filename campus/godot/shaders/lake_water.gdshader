shader_type spatial;
render_mode cull_disabled;
uniform sampler2D lake_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=wp.xz;
 float a=p.x*.72+p.y*.40+TIME*.38;
 float b=p.y*1.17-p.x*.31-TIME*.31;
 vec3 n=normalize(vec3(-cos(a)*.030+cos(b)*.014,1.0,-cos(a)*.022-cos(b)*.031));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
 vec2 uv=p/vec2(5.0,4.0)+vec2(TIME*.001,-TIME*.0013);
 vec2 mirror=1.0-abs(mod(uv,2.0)-1.0);
 vec3 pigment=textureGrad(lake_atlas,vec2(.004)+mirror*.492,dFdx(uv)*.492,dFdy(uv)*.492).rgb;
 float fresnel=pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),3.0);
 ALBEDO=mix(vec3(.035,.10,.087),pigment,.21)+vec3(.028,.038,.047)*fresnel;
 ROUGHNESS=.48;SPECULAR=.08;METALLIC=0.0;
}
