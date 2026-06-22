shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.18, 0.16, 0.22, 0.98);
uniform vec4 accent_color : source_color = vec4(0.88, 0.36, 0.60, 1.0);
uniform float hover_strength : hint_range(0.0, 1.0) = 0.0;
uniform float selected_strength : hint_range(0.0, 1.0) = 0.0;
uniform float completion_strength : hint_range(0.0, 1.0) = 0.0;
uniform float locked_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	vec3 base = mix(base_color.rgb * 0.80, base_color.rgb * 1.10, 1.0 - uv.y);
	float scan = sin(uv.y * 74.0) * 0.5 + 0.5;
	float grain = fract(sin(dot(floor(uv * vec2(58.0, 42.0)), vec2(12.9898, 78.233))) * 43758.5453);
	float gloss = smoothstep(0.04, 0.18, uv.y) * (1.0 - smoothstep(0.18, 0.42, uv.y));
	float edge = min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y));
	float edge_mask = 1.0 - smoothstep(0.05, 0.20, edge);

	vec3 color = base;
	color *= mix(0.96, 1.02, scan * 0.28);
	color += (grain - 0.5) * 0.012;
	color += mix(vec3(1.0), accent_color.rgb, 0.18) * gloss * 0.14;

	float pulse = 0.5 + 0.5 * sin(TIME * 3.2 + uv.x * 5.0 + uv.y * 3.0);
	color += accent_color.rgb * hover_strength * 0.10;
	color += accent_color.rgb * selected_strength * (0.08 + pulse * 0.08);

	float complete_stripe = sin((uv.x + uv.y) * 22.0) * 0.5 + 0.5;
	vec3 complete_tint = mix(vec3(0.86, 0.98, 0.88), vec3(0.98, 1.0, 0.94), complete_stripe * 0.35);
	color = mix(color, complete_tint, completion_strength * 0.34);

	float shutter = sin(uv.y * 64.0) * 0.5 + 0.5;
	color = mix(color, vec3(0.08, 0.08, 0.10), locked_strength * 0.78);
	color = mix(color, color * (0.42 + shutter * 0.12), locked_strength);
	color += accent_color.rgb * edge_mask * (0.10 + hover_strength * 0.22 + selected_strength * 0.28);

	COLOR = vec4(color, COLOR.a);
}
