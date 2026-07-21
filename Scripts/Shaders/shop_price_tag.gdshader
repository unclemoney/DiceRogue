shader_type canvas_item;
// Shop Price Tag - warm gradient fill with a top-edge highlight and a gentle
// periodic shine sweep for shop price badges. Palette is pushed per state
// (normal / free / max) via uniforms from shop_item.gd.
// Created for DiceRogue (Guhtzee)

uniform vec4 base_color : source_color = vec4(0.38, 0.26, 0.09, 0.95);
uniform vec4 top_color : source_color = vec4(0.58, 0.42, 0.15, 0.95);
uniform vec4 accent_color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float shine_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec2 rect_size = vec2(74.0, 28.0);
uniform float corner_radius = 12.0;

float rounded_box_sdf(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 half_size = rect_size * 0.5;
	float sdf = rounded_box_sdf(px - half_size, half_size, corner_radius);
	float mask = 1.0 - smoothstep(-1.5, 0.5, sdf);

	// Vertical gradient: lighter top, deeper base toward the bottom.
	vec3 col = mix(top_color.rgb, base_color.rgb, smoothstep(0.0, 1.0, UV.y));

	// Top-edge highlight and a soft bottom shade for a pressed-tag feel.
	float top_edge = smoothstep(3.0, 0.5, px.y);
	col += accent_color.rgb * top_edge * 0.22;
	col *= 1.0 - smoothstep(rect_size.y - 4.0, rect_size.y, px.y) * 0.22;

	// Gentle diagonal shine sweep.
	float sweep_pos = fract(TIME * 0.12) * 2.4 - 0.7;
	float shine = 1.0 - smoothstep(0.0, 0.10, abs((UV.x + UV.y * 0.35) - sweep_pos));
	col += accent_color.rgb * shine * 0.18 * shine_strength;

	COLOR = vec4(col, base_color.a * mask);
}
