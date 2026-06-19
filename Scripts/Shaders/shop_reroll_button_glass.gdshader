shader_type canvas_item;

uniform float aspect_ratio : hint_range(1.0, 6.0) = 2.6875;
uniform float hover_strength : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.0;
uniform float press_flash : hint_range(0.0, 1.5) = 0.0;
uniform float disabled_factor : hint_range(0.0, 1.0) = 0.0;

uniform vec4 base_color : source_color = vec4(0.10, 0.22, 0.18, 0.98);
uniform vec4 mid_color : source_color = vec4(0.16, 0.32, 0.26, 0.98);
uniform vec4 glow_color : source_color = vec4(0.95, 0.88, 0.34, 1.0);
uniform vec4 accent_color : source_color = vec4(0.16, 0.82, 0.48, 1.0);
uniform vec4 rim_color : source_color = vec4(0.96, 0.97, 0.88, 1.0);
uniform vec4 specular_color : source_color = vec4(0.96, 0.99, 0.98, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 78.233);
	return fract(p.x * p.y);
}

float rounded_box_sdf(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = vec2((uv.x - 0.5) * aspect_ratio, uv.y - 0.5);
	vec2 half_size = vec2(aspect_ratio * 0.5 - 0.08, 0.34);
	float radius = 0.18;
	float sdf = rounded_box_sdf(p, half_size, radius);
	float panel_mask = 1.0 - smoothstep(0.0, 0.018, sdf);
	float border = 1.0 - smoothstep(0.01, 0.05, abs(sdf));
	float inner_rim = smoothstep(-0.05, -0.015, -sdf);

	float pulse = pulse_strength * (0.5 + 0.5 * sin(TIME * 2.2));
	float glow_mix = 0.14 + hover_strength * 0.42 + pulse * 0.26 + press_flash * 0.42;
	float sweep = 1.0 - smoothstep(0.0, 0.24, abs((uv.x + uv.y * 0.32) - fract(TIME * 0.16)));
	float scan = 0.5 + 0.5 * sin(uv.y * 138.0 + TIME * 2.2);
	float grain = hash21(uv * vec2(180.0, 88.0) + TIME * 0.05);
	float frost = mix(scan, grain, 0.32);
	float top_reflection = smoothstep(0.34, -0.06, uv.y - 0.12) * panel_mask;
	float core_glow = exp(-dot(p * vec2(0.62, 1.18), p * vec2(0.62, 1.18)) * 3.4) * (0.10 + hover_strength * 0.24 + pulse * 0.18);
	float flash_band = exp(-pow((uv.x - 0.5) * 2.1, 2.0) * 3.8) * press_flash;

	vec3 base = mix(mid_color.rgb, base_color.rgb, smoothstep(0.0, 1.0, uv.y));
	base += accent_color.rgb * (0.04 + frost * 0.04);
	base += specular_color.rgb * (0.07 * top_reflection + sweep * 0.14);
	base += glow_color.rgb * (core_glow * 0.22 + flash_band * 0.28);

	vec3 border_color = mix(glow_color.rgb, accent_color.rgb, 0.5 + 0.5 * sin(TIME * 1.8 + uv.x * 5.0));
	vec3 panel_color = base;
	panel_color += border_color * border * (0.4 + glow_mix * 1.28);
	panel_color += rim_color.rgb * inner_rim * 0.08;
	panel_color += specular_color.rgb * press_flash * 0.18;

	float aura = exp(-max(sdf, 0.0) * 8.0) * (0.05 + glow_mix * 0.78);
	vec3 aura_color = mix(accent_color.rgb, glow_color.rgb, 0.38 + 0.25 * sin(TIME * 1.7 + uv.y * 4.0));
	vec3 color = aura_color * aura * 0.84;
	color = mix(color, panel_color, panel_mask);

	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(luma) * 0.82, disabled_factor * 0.8);

	float alpha = max(panel_mask * 0.98, aura * 0.32);
	alpha *= mix(1.0, 0.78, disabled_factor);

	COLOR = vec4(color, alpha);
}
