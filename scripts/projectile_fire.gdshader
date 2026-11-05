shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D turbulence : filter_linear_mipmap, repeat_enable;
void fragment(){
    vec2 p=(UV-vec2(0.5))*2.0;
    float n=texture(turbulence,UV*0.6+vec2(0.0,TIME*0.7)).r;
    float body=exp(-p.x*p.x*9.0-p.y*p.y*2.8);
    float flame=smoothstep(0.2,0.65,body+n*0.25);
    float core=exp(-p.x*p.x*32.0-p.y*p.y*10.0);
    ALBEDO=mix(vec3(1.0,0.23,0.04),vec3(1.0,0.86,0.5),core);
    ALPHA=(flame*0.55+core*0.4)*(1.0-smoothstep(0.65,1.0,length(p)));
}
