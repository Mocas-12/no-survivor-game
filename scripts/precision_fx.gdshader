shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.5,0.9,1.0,1.0);
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform float mode = 0.0;
uniform float style = 0.0;
uniform float radius_from = 0.1;
uniform float radius_to = 0.87;
void fragment(){
    vec2 p=(UV-vec2(0.5))*2.0;
    float r=length(p);
    float aa=max(fwidth(r),0.008);
    float radius=mix(0.10,0.87,pow(progress,0.55));
    float ring=(1.0-smoothstep(0.018,0.018+aa,abs(r-radius)))*pow(1.0-progress,1.7);
    float core=exp(-r*r*45.0)*pow(1.0-progress,5.0);
    float angle=atan(p.y,p.x);
    float spokes=pow(max(0.0,cos(angle*8.0+progress*1.8)),20.0);
    float rays=spokes*exp(-abs(r-radius*0.7)*18.0)*pow(1.0-progress,2.0);
    float glow=exp(-r*r*8.0)*pow(1.0-progress,3.0)*0.10;
    float strength=ring*0.6+core*0.65+rays*0.35+glow;
    if(mode>0.5){
        strength=ring*0.7+core*0.8+rays*0.5+glow;
    }
    if(style>0.5 && style<1.5){
        float flame=radius+sin(angle*7.0-progress*12.0)*0.07*(1.0-progress);
        float tongues=exp(-abs(r-flame)*22.0)*pow(max(cos(angle*7.0-progress*2.0),0.0),4.0);
        strength=tongues*pow(1.0-progress,1.8)+core*0.8+glow;
    }else if(style>1.5 && style<2.5){
        float second=(1.0-smoothstep(0.012,0.012+aa,abs(r-radius*0.68)));
        float droplets=pow(max(cos(angle*10.0),0.0),24.0)*exp(-abs(r-radius*1.1)*65.0);
        strength=ring*0.5+(second*0.3+droplets*0.6)*pow(1.0-progress,1.5)+core*0.25;
    }else if(style>2.5 && style<3.5){
        float hex=max(abs(p.x)*0.866+abs(p.y)*0.5,abs(p.y));
        float facet=(1.0-smoothstep(0.018,0.035,abs(hex-radius*0.8)));
        float crystals=pow(max(cos(angle*6.0),0.0),32.0)*exp(-abs(r-radius)*20.0);
        strength=(facet*0.5+crystals)*pow(1.0-progress,1.8)+core*0.4;
    }else if(style>3.5 && style<4.5){
        float zig=radius+sin(angle*15.0+progress*30.0)*0.045+sin(angle*31.0)*0.018;
        strength=(1.0-smoothstep(0.014,0.025,abs(r-zig)))*pow(1.0-progress,1.6)+rays*0.6+core*0.4;
    }else if(style>4.5 && style<5.5){
        float debris=pow(max(cos(angle*11.0+0.6),0.0),35.0)*exp(-abs(r-radius*0.95)*30.0);
        strength=ring*0.65+core*0.9+(debris*0.8+rays*0.5)*pow(1.0-progress,1.3)+glow;
    }else if(style>5.5 && style<7.5){
        strength=ring*max(0.0,sin(angle*3.0+progress*8.0))+glow*0.2;
    }else if(style>7.5){
        float edge=mix(radius_from,radius_to,progress);
        strength=(1.0-smoothstep(0.012,0.012+aa,abs(r-edge)))*pow(1.0-progress,1.3)*0.7;
    }
    strength*=1.0-smoothstep(0.94,1.0,r);
    ALBEDO=mix(tint.rgb,vec3(1.0),core*0.4);
    EMISSION=tint.rgb*strength*0.25;
    ALPHA=clamp(strength*tint.a,0.0,0.85);
}
