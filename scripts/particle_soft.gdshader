shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D turbulence : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color=vec4(1.0,0.6,0.2,1.0);
uniform float flame=0.0;
varying vec4 particle_color;
void vertex(){ particle_color=COLOR; }
void fragment(){
    vec2 p=UV*2.0-1.0;
    float n=texture(turbulence,UV*0.6).r;
    float shape=exp(-dot(p,p)*4.0)*(1.0-smoothstep(0.5,1.0,length(p)));
    if(flame>0.5) shape*=smoothstep(0.18,0.6,n+shape*0.35);
    ALBEDO=mix(tint.rgb,vec3(1.0,0.9,0.65),shape*0.5)*particle_color.rgb;
    ALPHA=shape*particle_color.a*tint.a*0.7;
}
