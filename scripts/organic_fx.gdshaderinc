uniform sampler2D turbulence : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color=vec4(1.0,0.5,0.15,1.0);
uniform float progress=0.0;
uniform float seed=0.0;
uniform float mode=0.0;
void fragment(){
    vec2 p=UV*2.0-1.0;
    vec2 uv=UV*0.7+vec2(seed,seed*0.37);
    vec2 warp=texture(turbulence,uv+vec2(0.0,-progress*0.17)).rg-0.5;
    vec2 flowing=uv+warp*0.34+vec2(progress*0.025,-progress*0.22);
    float n=texture(turbulence,flowing).r;
    float fine=texture(turbulence,flowing*2.6+warp*0.12).g;
    float r=length(p+warp*0.35);
    float density=(1.0-smoothstep(0.10,0.98,r))*(0.45+n*0.85);
    float fade=smoothstep(0.0,0.07,progress)*(1.0-smoothstep(0.42,1.0,progress));
    if(mode<0.5){ // Rolling smoke: dark interior, rim lighting, eroding thin wisps.
        float edge=smoothstep(progress*0.35,progress*0.35+0.28,density+fine*0.12);
        float light=clamp(0.45+n*0.7+warp.y*0.6,0.22,1.0);
        ALBEDO=tint.rgb*light;
        ALPHA=density*edge*fade*tint.a*0.72;
    }else if(mode<1.5){ // Hot interior and irregular flame front; never a regular ring.
        float heat=density*1.2+n*0.32-progress*0.60;
        vec3 flame=mix(tint.rgb*0.32,tint.rgb,smoothstep(0.12,0.4,heat));
        flame=mix(flame,vec3(1.0,0.74,0.27),smoothstep(0.70,1.3,heat)*0.65);
        ALBEDO=flame;
        ALPHA=smoothstep(0.12,0.48,heat)*fade*tint.a*0.43;
    }else if(mode<2.5){ // Brief contact glare: soft core with directional lens streak.
        float core=exp(-dot(p,p)*22.0);
        float streak=exp(-abs(p.y)*55.0-abs(p.x)*3.8)*0.4;
        ALBEDO=mix(tint.rgb,vec3(1.0,0.94,0.78),core*0.65);
        ALPHA=(core+streak)*pow(1.0-progress,2.8)*tint.a;
    }else{ // Soft spark/arc strip, with a narrow hot center.
        float edge=exp(-p.x*p.x*12.0)*(1.0-smoothstep(0.65,1.0,abs(p.y)));
        ALBEDO=mix(tint.rgb,vec3(0.87,0.96,1.0),exp(-p.x*p.x*130.0)*0.8);
        ALPHA=edge*fade*tint.a;
    }
}
