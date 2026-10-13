// Material-space paint, never a screen-space filter. Each atlas cell has an inset
// and mirrored repeat, preventing adjacent materials bleeding into the sample.
uniform sampler2D paint_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 paint_cell=vec2(0.0);
uniform vec2 paint_meters=vec2(2.0);
uniform float paint_strength=.65;
uniform float paint_gain=1.0;
uniform bool paint_bounded=false;
vec3 sakura_paint_sample(vec2 coord){
 vec2 mirrored=1.0-abs(mod(coord,2.0)-1.0);
 vec2 at=paint_cell*.5+vec2(.004)+mirrored*.492;
 return textureGrad(paint_atlas,at,dFdx(coord)*.492,dFdy(coord)*.492).rgb;
}
vec3 sakura_painted(vec3 original,vec3 position,vec3 normal){
 vec2 coord=position.xz/paint_meters;
 if(abs(normal.y)<.65){
  coord=(abs(normal.z)>abs(normal.x)?position.xy:position.zy)/paint_meters;
 }
 vec3 pigment=sakura_paint_sample(coord)*paint_gain;
 float mask=1.0;
 if(paint_bounded){
  mask=(1.0-smoothstep(13.0,18.0,abs(position.x)))*smoothstep(10.0,16.0,position.z)*(1.0-smoothstep(146.0,153.0,position.z));
 }
 return mix(original,pigment,paint_strength*mask);
}
