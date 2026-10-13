shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(.5,.5,.5,1);
uniform sampler2D surface_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool mapped=false;
uniform bool lawn=false;
uniform vec2 tile_meters=vec2(4.0,2.0);
uniform float rough=.8;
uniform float foliage=0.0;
uniform float ground=0.0;
uniform float brick=0.0;
uniform bool graybox=false;
varying vec3 wp;
varying vec3 wn;
varying float leaf_light;
varying float shading_roughness;
void vertex(){
 wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 if(foliage>0.0){
  float phase=wp.x*.7+wp.z*.38;
  float amp=clamp(VERTEX.y*.008,.002,.075)*foliage;
  VERTEX.x+=sin(TIME*.8+phase)*amp;
  VERTEX.z+=sin(TIME*1.17+phase*.7)*amp*.45;
  NORMAL=normalize(mix(NORMAL,vec3(0,1,0),.24));
 }
 wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 leaf_light=.94+.08*sin(wp.x*1.1+wp.z*.83+wp.y*.62);
}
void fragment(){
 vec3 normal=normalize(wn);vec3 tx=vec3(1,0,0);vec3 ty=vec3(0,0,1);vec2 uv=wp.xz/tile_meters;
 if(abs(normal.y)<.65){
  ty=vec3(0,1,0);
  if(abs(normal.z)>abs(normal.x)){uv=wp.xy/tile_meters;tx=vec3(1,0,0);}
  else{uv=wp.zy/tile_meters;tx=vec3(0,0,1);}
 }
 vec3 col=base_color.rgb;float ao=1.0;float r=rough;
 if(mapped){
  col*=texture(surface_color,uv).rgb;
  vec3 orm=texture(surface_orm,uv).rgb;ao=orm.r;r=orm.g;
  vec2 bump=(texture(surface_normal,uv).xy*2.0-1.0)*(lawn?.12:.4);
  normal=normalize(normal+tx*bump.x+ty*bump.y);
 }
 if(brick>.5){col=mix(col,vec3(.43,.235,.166),.77);col*=1.0+.045*sin(wp.x*.11+sin(wp.y*.25))+.016*sin(wp.y*.53+wp.z*.3);}
 if(foliage>.0){col*=leaf_light;ao=.73+.27*smoothstep(2.0,11.0,wp.y);}
 if(lawn){col=mix(col,vec3(.25,.34,.14),.58);col*=1.0+.065*sin(wp.x*.075+sin(wp.z*.083))+.025*sin(wp.x*.16-wp.z*.12);}
 if(ground>.5){col=mix(col,vec3(.48,.47,.40),.45);}
 NORMAL=normalize(mat3(VIEW_MATRIX)*normal);
 ALBEDO=graybox?vec3(.55):col;
 ROUGHNESS=r;SPECULAR=.3;AO=ao;AO_LIGHT_AFFECT=.55;
 shading_roughness=r;
 BACKLIGHT=col*foliage*.65;
}
void light(){
 float n=dot(NORMAL,LIGHT);
 float steps=.17+.22*smoothstep(-.1,.24,n)+.28*smoothstep(.2,.56,n)+.33*smoothstep(.54,.94,n);
 float diffuse=mix(max(n,0.0),steps,.48);
 if(foliage>0.0)diffuse=max(diffuse,max(0.0,(n+.35)/1.35)*.9);
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*diffuse/PI;
 float back=pow(max(dot(-LIGHT,VIEW),0.0),4.0)*foliage*.34;
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*back/PI;
 // Restrained GGX reflection keeps stone, paint and foliage physically distinct.
 vec3 half_dir=normalize(LIGHT+VIEW);
 float nl=max(n,.001),nv=max(dot(NORMAL,VIEW),.001),nh=max(dot(NORMAL,half_dir),0.0),vh=max(dot(VIEW,half_dir),0.0);
 float a=shading_roughness*shading_roughness;float a2=a*a;
 float denom=nh*nh*(a2-1.0)+1.0;
 float d=a2/(PI*denom*denom);
 float k=(shading_roughness+1.0)*(shading_roughness+1.0)/8.0;
 float g=(nl/(nl*(1.0-k)+k))*(nv/(nv*(1.0-k)+k));
 float f=.035+.965*pow(1.0-vh,5.0);
 SPECULAR_LIGHT+=LIGHT_COLOR*ATTENUATION*d*g*f/(4.0*nv)*mix(1.0,.18,foliage);
}
