shader_type canvas_item;

uniform vec2 rect_size = vec2(256.0, 256.0);
uniform float effect_time : hint_range(0.0, 600.0) = 0.0;
uniform float effect_strength : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	vec4 base = texture(TEXTURE, uv);
	vec2 centered = uv - vec2(0.5);
	float radius = length(centered * vec2(1.0, 0.92));
	float pulse = 0.5 + 0.5 * sin(effect_time * 2.6 - radius * 18.0);
	float beacon = smoothstep(0.72, 0.0, radius) * pulse * effect_strength;
	vec2 halftone_uv = uv * rect_size * 0.09;
	float halftone = step(0.25, sin(halftone_uv.x) * sin(halftone_uv.y));
	vec3 beacon_color = vec3(0.28, 0.68, 1.0);
	vec3 color = base.rgb;
	color += beacon_color * beacon * 0.28;
	color = mix(color, color + beacon_color * 0.06, halftone * 0.24 * effect_strength);
	COLOR = vec4(color, base.a);
}