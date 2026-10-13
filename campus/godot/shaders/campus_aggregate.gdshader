shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(.22,.24,.23,1);
uniform bool pebbles=false;
varying vec3 wp;
varying vec3 wn;
vec2 hash2(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}
float noise(vec2 p){vec2 a=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash2(a).x,hash2(a+vec2(1,0)).x,f.x),mix(hash2(a+vec2(0,1)).x,hash2(a+vec2(1,1)).x,f.x),f.y);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 p=wp.xz;vec3 col=base_color.rgb;vec3 normal=normalize(wn);
 if(!pebbles){
  float grain=noise(p*95.0);float aa=1.0-smoothstep(.006,.04,length(fwidth(p)));
  col*=.94+.10*noise(p*.38)+(.25*grain-.125)*aa;
  vec2 bump=(vec2(noise(p*52.0),noise(p*52.0+91.0))-.5)*.10;
  normal+=vec3(bump.x,0,bump.y);ROUGHNESS=.97;
 }else{
  vec2 uv=p*13.0;vec2 cell=floor(uv);vec2 frac=fract(uv);float nearest=4.0;vec2 center=vec2(0);vec2 rnd=vec2(0);
  for(int x=-1;x<=1;x++){for(int y=-1;y<=1;y++){
   vec2 q=vec2(float(x),float(y));vec2 h=hash2(cell+q);vec2 d=q+.2+.6*h-frac;
   float r=length(d*vec2(1.0,.78));if(r<nearest){nearest=r;center=d;rnd=h;}
  }}
  float aa=max(fwidth(nearest),.02);float edge=smoothstep(.34-aa,.42+aa,nearest);
  vec3 stone=mix(vec3(.43,.44,.40),vec3(.70,.66,.56),rnd.x);
  col=mix(stone*(1.0-nearest*.2),vec3(.29,.30,.27),edge)*base_color.rgb;
  normal+=vec3(center.x,0,center.y)*.38*(1.0-edge);ROUGHNESS=.91;
 }
 NORMAL=normalize(mat3(VIEW_MATRIX)*normal);ALBEDO=col;SPECULAR=.22;
}
void light(){float n=dot(NORMAL,LIGHT);float steps=.17+.22*smoothstep(-.1,.24,n)+.28*smoothstep(.2,.56,n)+.33*smoothstep(.54,.94,n);DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*mix(max(n,0.0),steps,.32)/PI;}
