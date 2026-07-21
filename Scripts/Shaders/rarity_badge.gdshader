shader_type canvas_item;
// Rarity Badge Juice - animated sheen sweep, pulsing rarity-tinted edge glow,
// and faint sparkle for shop item rarity badges. Additive blend over the badge
// stylebox so the themed border/background stay visible.
// Created for DiceRogue (Guhtzee)
render_mode blend_add;

uniform vec4 rarity_color : source_color = vec4(0.776471, 0.815686, 0.862745, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float sheen_speed : hint_range(0.0, 3.0) = 0.9;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec2 rect_size = vec2(36.0, 28.0);
uniform float corner_radius = 12.0;

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

	// Diagonal sheen sweep crossing the badge.
	float diag = UV.x + UV.y * 0.5;
	float sweep_pos = fract(TIME * sheen_speed * 0.22) * 2.2 - 0.6;
	float sheen = 1.0 - smoothstep(0.0, 0.16, abs(diag - sweep_pos));

	// Pulsing rarity-tinted edge glow.
	float edge = 1.0 - smoothstep(0.0, 4.0, abs(sdf));
	float pulse = 0.55 + 0.45 * sin(TIME * 2.6);

	// Sparse twinkling sparkle.
	float sparkle = step(0.985, hash21(floor(px / 2.0) + floor(TIME * 6.0))) * 0.6;

	vec3 col = glow_color.rgb * sheen * 0.35;
	col += rarity_color.rgb * edge * pulse * pulse_strength;
	col += rarity_color.rgb * sparkle;

	COLOR = vec4(col * mask, 1.0);
}
