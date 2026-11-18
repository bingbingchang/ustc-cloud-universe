shader_type sky;
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform float rotation_offset=.10;
uniform float sky_time=0.0;
uniform vec4 horizon_haze : source_color = vec4(0.0);
uniform vec2 horizon_haze_range = vec2(.16, .28);
void sky(){
 vec2 uv=vec2(fract(atan(EYEDIR.x,EYEDIR.z)/TAU+.5+rotation_offset+sky_time*.0000014),clamp(.60-asin(clamp(EYEDIR.y,-1.0,1.0))/PI*1.2,0.0,1.0));
 vec3 c=texture(panorama,uv).rgb;
 c=mix(c,vec3(dot(c,vec3(.2126,.7152,.0722))),.13);
 COLOR=c*.98;
 if (!AT_CUBEMAP_PASS) {
  float haze=horizon_haze.a*(1.0-smoothstep(horizon_haze_range.x,horizon_haze_range.y,EYEDIR.y));
  COLOR=mix(COLOR,horizon_haze.rgb,haze);
 }
}
