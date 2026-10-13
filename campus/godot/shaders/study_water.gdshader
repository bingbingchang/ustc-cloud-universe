shader_type spatial;
render_mode cull_disabled;
uniform sampler2D reflection_texture : source_color, filter_linear_mipmap;
uniform mat4 reflection_vp;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec4 clip=reflection_vp*vec4(wp,1.0);
 vec2 uv=clip.xy/clip.w*.5+.5;uv.y=1.0-uv.y;
 float wave=sin(wp.x*2.3+wp.z*.63+TIME*.75)*sin(wp.z*3.4-TIME*.42);
 uv.x+=wave*.0011;uv.y+=sin(wp.z*4.6+TIME*.38)*.0006;
 uv=clamp(uv,vec2(.004),vec2(.996));
 vec3 reflected=texture(reflection_texture,uv).rgb*.5;
 reflected+=texture(reflection_texture,uv+vec2(.0025,.0008)).rgb*.25;
 reflected+=texture(reflection_texture,uv-vec2(.0025,.0008)).rgb*.25;
 float fresnel=pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),2.0);
 float weight=.17+fresnel*.24;
 reflected=mix(reflected*vec3(.73,.88,.79),vec3(.065,.16,.13),.15);
 vec3 tint=mix(vec3(.028,.10,.083),vec3(.074,.14,.15),.5+.5*sin(wp.z*.11+wp.x*.09));
 ALBEDO=tint*(1.0-weight);EMISSION=reflected*weight;
 ROUGHNESS=.30;SPECULAR=.12;
}
