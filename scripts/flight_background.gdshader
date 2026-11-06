shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D scene_texture : source_color, filter_linear_mipmap;
uniform sampler2D next_texture : source_color, filter_linear_mipmap;
uniform float transition = 0.0;
uniform float flight_time = 0.0;
uniform float steer = 0.0;
void fragment() {
	// Stationary distant plates never tile or travel through the screen.
	vec2 uv = clamp(UV + vec2(steer * 0.006 + sin(flight_time * 0.025) * 0.0015, 0.0), vec2(0.0), vec2(1.0));
	ALBEDO = mix(texture(scene_texture, uv).rgb, texture(next_texture, uv).rgb, transition) * 0.6 + vec3(0.004,0.008,0.018);
}
