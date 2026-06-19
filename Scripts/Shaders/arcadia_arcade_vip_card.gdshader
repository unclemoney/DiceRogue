shader_type canvas_item;

uniform vec2 rect_size = vec2(256.0, 256.0);
uniform float effect_time : hint_range(0.0, 600.0) = 0.0;
uniform float effect_strength : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	float drift = sin(effect_time * 2.0 + uv.y * 34.0) * 0.0035 * effect_strength;
	vec4 alpha_sample = texture(TEXTURE, uv);
	float red = texture(TEXTURE, clamp(uv + vec2(drift, 0.0), vec2(0.0), vec2(1.0))).r;
	float green = texture(TEXTURE, uv).g;
	float blue = texture(TEXTURE, clamp(uv - vec2(drift, 0.0), vec2(0.0), vec2(1.0))).b;
	vec3 color = vec3(red, green, blue);
	float scanline = 0.9 + 0.1 * sin(uv.y * rect_size.y * 0.65);
	float flicker = 0.96 + 0.04 * sin(effect_time * 25.0);
	float edge_glow = pow(1.0 - clamp(length((uv - 0.5) * vec2(1.2, 1.0)), 0.0, 1.0), 3.0);
	color *= scanline * flicker;
	color += vec3(0.05, 0.16, 0.19) * edge_glow * effect_strength;
	COLOR = vec4(color, alpha_sample.a);
}