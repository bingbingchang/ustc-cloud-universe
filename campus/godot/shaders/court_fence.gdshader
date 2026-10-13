shader_type spatial;
render_mode cull_disabled;
void fragment(){
    float a=abs(fract((UV.x+UV.y)*4.0)-.5);
    float b=abs(fract((UV.x-UV.y)*4.0)-.5);
    ALPHA=1.0-smoothstep(.025,.075,min(a,b));
    ALPHA_SCISSOR_THRESHOLD=.5;
    ALBEDO=vec3(.06,.19,.12);ROUGHNESS=.90;
}
