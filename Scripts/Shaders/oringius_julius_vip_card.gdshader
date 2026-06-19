shader_type canvas_item;

uniform vec2 rect_size = vec2(256.0, 256.0);
uniform float effect_time : hint_range(0.0, 600.0) = 0.0;
uniform float effect_strength : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	vec2 wave = vec2(
		sin((uv.y + effect_time * 0.12) * 18.0),
		cos((uv.x - effect_time * 0.09) * 16.0)
	) * 0.004 * effect_strength;
	float bubble_a = smoothstep(0.55, 1.0, sin(uv.x * 15.0 + effect_time * 0.7) * cos(uv.y * 12.0 - effect_time * 0.3));
	float bubble_b = smoothstep(0.6, 1.0, cos(uv.y * 19.0 - effect_time * 0.9) * sin(uv.x * 9.0 + effect_time * 0.2));
	vec2 refract_offset = wave + vec2(bubble_a - bubble_b, bubble_b - bubble_a) * 0.008 * effect_strength;
	vec2 sample_uv = clamp(uv + refract_offset, vec2(0.0), vec2(1.0));
	vec4 base = texture(TEXTURE, sample_uv);
	float shimmer = 0.06 + 0.05 * sin(effect_time * 0.8 + uv.y * 7.0 + uv.x * 6.0);
	vec3 juice_tint = vec3(1.0, 0.67, 0.22);
	vec3 color = mix(base.rgb, base.rgb * juice_tint, 0.18);
	color += bubble_a * 0.035 * juice_tint * effect_strength;
	color += shimmer * vec3(1.0, 0.92, 0.72) * effect_strength;
	COLOR = vec4(color, base.a);
}