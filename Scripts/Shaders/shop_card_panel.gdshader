shader_type canvas_item;
// Shop Card Panel Depth - subtle vertical gradient, soft vignette, faint grain
// and a slow low-alpha sheen laid over the shop item card background. Kept
// deliberately quiet so card content stays legible.
// Created for DiceRogue (Guhtzee)

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.12;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec2 rect_size = vec2(213.0, 275.0);
uniform float corner_radius = 10.0;

float rounded_box_sdf(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 78.233);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 half_size = rect_size * 0.5;
	float sdf = rounded_box_sdf(px - half_size, half_size, corner_radius);
	float mask = 1.0 - smoothstep(-1.5, 0.5, sdf);

	// Vertical depth gradient: faint warm lift on top, cool sink at the bottom.
	vec3 grad = mix(vec3(1.0, 0.98, 0.93), vec3(0.03, 0.02, 0.07), smoothstep(0.0, 1.0, UV.y));
	float grad_alpha = mix(0.10, 0.34, UV.y);

	// Soft inner vignette.
	vec2 d = (UV - 0.5) * vec2(rect_size.x / rect_size.y, 1.0) * 2.0;
	float vig = smoothstep(0.55, 1.2, length(d)) * vignette_strength;

	// Faint animated grain.
	float grain = (hash21(px + fract(TIME) * 7.0) - 0.5) * 0.05 * grain_strength;

	// Slow low-alpha sheen sweep.
	float sweep_pos = fract(TIME * 0.05) * 2.6 - 0.8;
	float sheen = 1.0 - smoothstep(0.0, 0.20, abs((UV.x + UV.y * 0.3) - sweep_pos));

	vec3 col = grad + vec3(grain) + vec3(1.0, 0.95, 0.8) * sheen * sheen_strength;
	col = mix(col, vec3(0.01, 0.01, 0.03), vig);
	float alpha = clamp(grad_alpha + vig * 0.5 + sheen * sheen_strength * 0.5, 0.0, 0.6);

	COLOR = vec4(col, alpha * mask);
}
