shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(.42,.16,.11,1.0);
uniform bool turf = false;
varying vec3 wp;
varying vec3 wn;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
    float grain=hash(floor(wp.xz*110.0));
    float aa=1.0-smoothstep(.006,.05,length(fwidth(wp.xz)));
    vec3 col=base_color.rgb*(.98+aa*(grain-.5)*.13);
    if(turf){
        float stripe=mod(floor((wp.z-403.66)/8.75),2.0);
        col*=mix(.91,1.03,stripe);
    }
    NORMAL=normalize(mat3(VIEW_MATRIX)*wn);
    ALBEDO=col;ROUGHNESS=.98;SPECULAR=.12;
}
