shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
uniform sampler2D face_albedo:source_color,filter_linear_mipmap_anisotropic;
uniform float eye_look=0.0;
uniform float eye_down=0.0;
void fragment(){
 ALBEDO=texture(face_albedo,UV).rgb;
 // glTF flips Blender's V coordinate at export.
 vec2 l=(UV-vec2(.308+eye_look*.0546,.395+eye_down))/vec2(.019,.023);
 vec2 r=(UV-vec2(.713+eye_look*.0546,.395+eye_down))/vec2(.019,.023);
 float ink=1.0-smoothstep(.90,1.10,min(dot(l,l),dot(r,r)));
 ink*=smoothstep(.44,.52,ALBEDO.b);
 ALBEDO=mix(ALBEDO,vec3(.023,.027,.026),ink);
 ALBEDO=mix(ALBEDO,vec3(dot(ALBEDO,vec3(.2126,.7152,.0722))),.09);
 ROUGHNESS=.88;SPECULAR=.18;
}
void light(){
 float n=dot(NORMAL,LIGHT);
 float levels=.10+.26*smoothstep(-.12,.16,n)+.30*smoothstep(.20,.49,n)+.32*smoothstep(.55,.85,n);
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*levels/3.14159265;
}
