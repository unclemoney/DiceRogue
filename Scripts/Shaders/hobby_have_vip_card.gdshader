shader_type canvas_item;

uniform vec2 rect_size = vec2(256.0, 256.0);
uniform float effect_time : hint_range(0.0, 600.0) = 0.0;
uniform float effect_strength : hint_range(0.0, 2.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	vec4 base = texture(TEXTURE, uv);
	float blotch_a = smoothstep(0.62, 0.98, hash(floor(uv * 9.0) + vec2(2.0, 4.0)) + sin(effect_time * 0.8 + uv.x * 7.0) * 0.08);
	float blotch_b = smoothstep(0.7, 1.0, hash(floor(uv * 13.0) + vec2(6.0, 1.0)) + cos(effect_time * 0.6 + uv.y * 8.0) * 0.06);
	vec3 tint_a = vec3(0.93, 0.27, 0.39);
	vec3 tint_b = vec3(0.24, 0.77, 0.92);
	vec3 color = base.rgb;
	color = mix(color, color * 0.84 + tint_a * 0.34, blotch_a * 0.42 * effect_strength);
	color = mix(color, color * 0.86 + tint_b * 0.3, blotch_b * 0.34 * effect_strength);
	float gloss = pow(max(0.0, 1.0 - length((uv - vec2(0.3, 0.28)) * vec2(1.2, 1.4))), 4.0);
	float shimmer = 0.04 + 0.05 * sin(effect_time * 1.5 + uv.x * 9.0 + uv.y * 6.0);
	color += vec3(1.0) * gloss * shimmer * effect_strength;
	COLOR = vec4(color, base.a);
}