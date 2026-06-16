shader_type canvas_item;

uniform float border_glow : hint_range(0.0, 2.0) = 0.15;
uniform vec4 neon_color : source_color = vec4(0.9, 0.35, 0.6, 1.0);
uniform vec4 chrome_tint : source_color = vec4(0.12, 0.10, 0.14, 0.98);
uniform vec4 highlight_tint : source_color = vec4(0.55, 0.62, 0.75, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.05, 0.04, 0.08, 1.0);
uniform vec4 env_tint_a : source_color = vec4(0.25, 0.45, 0.65, 1.0);
uniform vec4 env_tint_b : source_color = vec4(0.75, 0.30, 0.50, 1.0);
uniform float reflection_amount : hint_range(0.0, 1.0) = 0.22;
uniform float corner_radius : hint_range(0.0, 64.0) = 18.0;
uniform float bezel_width : hint_range(8.0, 32.0) = 12.0;
uniform float inner_lip_width : hint_range(0.0, 8.0) = 2.5;
uniform float time : hint_range(0.0, 100000.0) = 0.0;
uniform bool draw_outer_bezel = true;
uniform vec2 rect_size = vec2(224.0, 324.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 34.45);
	return fract(p.x * p.y);
}

// Signed distance field rounded rectangle in pixel space.
float sd_rounded_rect(vec2 p, vec2 half_size, float radius) {
	vec2 d = abs(p - half_size) - max(half_size - vec2(radius), vec2(0.0));
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	vec2 uv = UV;
	vec2 size = max(rect_size, vec2(1.0));
	vec2 half_size = size * 0.5;
	vec2 pixel_pos = uv * size;
	float outer_dist = sd_rounded_rect(pixel_pos, half_size, corner_radius);
	float outer_fill = 1.0 - smoothstep(0.0, 1.6, outer_dist);
	vec2 inner_half = max(half_size - vec2(bezel_width), vec2(1.0));
	float inner_radius = max(corner_radius - bezel_width * 0.92, 0.0);
	float inner_dist = sd_rounded_rect(pixel_pos, inner_half, inner_radius);
	float inner_fill = 1.0 - smoothstep(0.0, 1.6, inner_dist);
	float bezel_mask = clamp(outer_fill - inner_fill, 0.0, 1.0);

	float brushed = hash21((pixel_pos + vec2(time * 18.0, -time * 9.0)) * vec2(0.18, 0.05)) - 0.5;
	float chrome_gradient = mix(0.26, 0.52, uv.y);
	vec3 chrome = mix(shadow_tint.rgb, chrome_tint.rgb, chrome_gradient);

	float env_phase_a = fract(uv.x * 0.88 + uv.y * 0.28 + time * 0.045);
	float env_phase_b = fract(uv.x * 0.45 - uv.y * 0.38 - time * 0.03);
	float env_band_a = 1.0 - smoothstep(0.0, 0.22, abs(env_phase_a - 0.18));
	float env_band_b = 1.0 - smoothstep(0.0, 0.28, abs(env_phase_b - 0.72));
	vec3 env_reflection = env_tint_a.rgb * env_band_a * 0.24 + env_tint_b.rgb * env_band_b * 0.18;

	float top_bevel = pow(1.0 - uv.y, 2.1) * bezel_mask;
	float bottom_bevel = pow(uv.y, 1.75) * bezel_mask;
	float left_sheen = pow(max(1.0 - abs(uv.x - 0.24) * 2.2, 0.0), 3.0) * bezel_mask;
	float inner_line = (1.0 - smoothstep(inner_lip_width, inner_lip_width + 1.4, abs(inner_dist))) * outer_fill;
	float outer_rim = (1.0 - smoothstep(0.0, 2.25, abs(outer_dist))) * outer_fill;
	float neon_pulse = 0.74 + sin(time * 2.1 + uv.x * 8.0) * 0.08;
	vec3 neon = neon_color.rgb * border_glow * (outer_rim * 1.1 + inner_line * 0.85) * neon_pulse;

	vec3 bezel_color = chrome;
	bezel_color += env_reflection * reflection_amount;
	bezel_color += highlight_tint.rgb * top_bevel * 0.78;
	bezel_color += highlight_tint.rgb * left_sheen * 0.16;
	bezel_color -= shadow_tint.rgb * bottom_bevel * 0.38;
	bezel_color += highlight_tint.rgb * inner_line * 0.44;
	bezel_color += vec3(brushed) * 0.05;
	bezel_color += neon;

	vec3 fill_color = mix(chrome_tint.rgb, highlight_tint.rgb, 0.18 + (1.0 - uv.y) * 0.35);
	fill_color += env_reflection * reflection_amount * 0.7;
	fill_color += highlight_tint.rgb * inner_line * 0.15;
	fill_color += vec3(brushed) * 0.03;
	fill_color += neon_color.rgb * border_glow * outer_rim * 0.25;

	vec3 final_color = bezel_color;
	float final_alpha = bezel_mask * outer_fill;
	if (!draw_outer_bezel) {
		final_color = fill_color;
		final_alpha = outer_fill;
	}

	COLOR = vec4(final_color, final_alpha);
}
