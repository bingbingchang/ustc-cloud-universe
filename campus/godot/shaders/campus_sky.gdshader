shader_type sky;
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform float rotation_offset=.10;
void sky(){
 vec2 uv=vec2(fract(atan(EYEDIR.x,EYEDIR.z)/TAU+.5+rotation_offset+TIME*.0000014),clamp(.60-asin(clamp(EYEDIR.y,-1.0,1.0))/PI*1.2,0.0,1.0));
 vec3 c=texture(panorama,uv).rgb;
 c=mix(c,vec3(dot(c,vec3(.2126,.7152,.0722))),.13);
 COLOR=c*.98;
}
