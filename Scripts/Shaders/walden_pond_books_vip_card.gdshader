shader_type canvas_item;

uniform vec2 rect_size = vec2(256.0, 256.0);
uniform float effect_time : hint_range(0.0, 600.0) = 0.0;
uniform float effect_strength : hint_range(0.0, 2.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.7, 289.3))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	vec2 texel = 1.0 / max(rect_size, vec2(1.0));
	vec4 base = texture(TEXTURE, uv);
	float lum_center = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	float lum_right = dot(texture(TEXTURE, clamp(uv + vec2(texel.x, 0.0), vec2(0.0), vec2(1.0))).rgb, vec3(0.299, 0.587, 0.114));
	float lum_down = dot(texture(TEXTURE, clamp(uv + vec2(0.0, texel.y), vec2(0.0), vec2(1.0))).rgb, vec3(0.299, 0.587, 0.114));
	float emboss = (lum_center - lum_right) + (lum_center - lum_down);
	float grain = hash(floor(uv * rect_size * 0.45 + effect_time * 0.15)) - 0.5;
	vec3 paper = mix(base.rgb, vec3(0.93, 0.89, 0.81), 0.24);
	paper += grain * 0.06;
	paper += emboss * 0.18 * effect_strength;
	paper -= (1.0 - lum_center) * 0.05 * effect_strength;
	COLOR = vec4(paper, base.a);
}