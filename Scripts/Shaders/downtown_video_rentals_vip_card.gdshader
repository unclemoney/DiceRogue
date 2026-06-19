shader_type canvas_item;

uniform vec2 rect_size = vec2(256.0, 256.0);
uniform float effect_time : hint_range(0.0, 600.0) = 0.0;
uniform float effect_strength : hint_range(0.0, 2.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(91.7, 257.3))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	float drift = sin(effect_time * 1.8 + uv.y * 38.0) * 0.0045 * effect_strength;
	vec4 alpha_sample = texture(TEXTURE, uv);
	float red = texture(TEXTURE, clamp(uv + vec2(drift, 0.0), vec2(0.0), vec2(1.0))).r;
	float green = texture(TEXTURE, uv).g;
	float blue = texture(TEXTURE, clamp(uv - vec2(drift * 0.75, 0.0), vec2(0.0), vec2(1.0))).b;
	vec3 color = vec3(red, green, blue);
	float band = smoothstep(0.72, 1.0, sin(uv.y * rect_size.y * 0.08 + effect_time * 2.5));
	float tracking = step(0.94, fract(uv.y * 4.5 + effect_time * 0.2)) * 0.09 * effect_strength;
	float noise = hash(vec2(floor(uv.x * rect_size.x * 0.35 + effect_time * 28.0), floor(uv.y * rect_size.y * 0.4)));
	color = mix(color, vec3(noise), 0.08 * effect_strength);
	color += vec3(0.07, 0.05, 0.08) * band * effect_strength;
	color -= vec3(tracking);
	COLOR = vec4(color, alpha_sample.a);
}