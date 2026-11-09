shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform vec4 tint : source_color = vec4(0.25,0.8,1.0,1.0);
uniform vec4 secondary : source_color = vec4(0.25,0.8,1.0,1.0);
uniform float energy = 0.0;
uniform float clock = 0.0;
uniform float detail = 1.0;
uniform int kind = 0;
void fragment() {
	float x=abs(UV.x-.5+sin(UV.y*42.0-clock*28.0)*.012*detail)*2.0;
	float core=exp(-x*x*180.0);
	float body=exp(-x*x*25.0);
	float halo=exp(-x*x*6.0);
	float stream=pow(max(0.0,sin(UV.y*85.0+clock*60.0)),8.0);
	float filament=exp(-pow((x-.27)*20.0,2.0));
	float a=(core*.85+body*.4+halo*.09+filament*.12*detail)*(0.8+stream*.35*detail);
	if(kind!=0) {
		vec2 p=(UV-.5)*2.0;
		float r=length(p);
		float cross=exp(-abs(p.x)*22.0)*exp(-abs(p.y)*3.0)+exp(-abs(p.y)*22.0)*exp(-abs(p.x)*3.0);
		a=(exp(-r*r*20.0)+cross*.45)*(1.0-smoothstep(.7,1.0,r));
		core=exp(-r*r*40.0);
	}
	ALBEDO=mix(mix(tint.rgb,secondary.rgb,smoothstep(.45,.55,UV.x)),vec3(0.9,0.98,1.0),core*.8);
	ALPHA=clamp(a*energy,0.0,1.0);
}
