uniform sampler2D lake_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 lake_cell=vec2(1,0);
uniform vec2 lake_meters=vec2(2.0);
uniform float lake_strength=.65;
uniform float lake_gain=1.0;
uniform bool lake_bounded=true;
uniform bool lake_sample=false;
vec3 lake_painted(vec3 original,vec3 position,vec3 normal){
 vec2 uv=position.xz/lake_meters;
 if(abs(normal.y)<.65)uv=(abs(normal.z)>abs(normal.x)?position.xy:position.zy)/lake_meters;
 vec2 mirrored=1.0-abs(mod(uv,2.0)-1.0);
 vec3 pigment=textureGrad(lake_atlas,lake_cell*.5+vec2(.004)+mirrored*.492,dFdx(uv)*.492,dFdy(uv)*.492).rgb*lake_gain;
 float mask=1.0;
 if(lake_bounded){
  mask=smoothstep(17.0,23.0,position.x)*(1.0-smoothstep(78.0,84.0,position.x))*smoothstep(49.0,54.0,position.z)*(1.0-smoothstep(133.0,139.0,position.z));
  if(lake_sample)mask*=smoothstep(55.0,58.0,position.x)*smoothstep(72.0,76.0,position.z)*(1.0-smoothstep(104.0,108.0,position.z));
 }
 return mix(original,pigment,mask*lake_strength);
}
