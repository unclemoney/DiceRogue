shader_type canvas_item;

uniform float border_glow : hint_range(0.0, 2.0) = 0.15;
uniform vec4 neon_color : source_color = vec4(0.9, 0.35, 0.6, 1.0);
uniform vec4 chrome_tint : source_color = vec4(0.12, 0.10, 0.14, 0.98);
uniform vec4 highlight_tint : source_color = vec4(0.55, 0.62, 0.75, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.05, 0.04, 0.08, 1.0);
uniform vec4 env_tint_a : source_color = vec4(0.25, 0.45, 0.65, 1.0);
uniform vec4 env_tint_b : source_color = vec4(0.75, 0.30, 0.50, 1.0);
uniform float reflection_amount : hint_range(0.0, 1.0) = 0.12;
uniform float corner_radius : hint_range(0.0, 64.0) = 18.0;
uniform float bezel_width : hint_range(0.0, 32.0) = 10.0;
uniform float time : hint_range(0.0, 100000.0) = 0.0;
uniform bool draw_outer_bezel = true;
uniform vec2 rect_size = vec2(160.0, 240.0);

// Signed distance field rounded rectangle in pixel space.
float sd_rounded_rect(vec2 p, vec2 half_size, float radius) {
	vec2 d = abs(p - half_size) - max(half_size - vec2(radius), vec2(0.0));
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Smooth anti-aliased mask from an SDF value (distance in pixels).
float aa_mask(float dist, float edge_width) {
	return smoothstep(0.0, edge_width, dist);
}

void fragment() {
	vec2 uv = UV;
	vec2 size = max(rect_size, vec2(1.0));
	vec2 half_size = size * 0.5;
	vec2 pixel_pos = uv * size;
	float edge_width = 1.0;

	// Outer rounded rectangle (full tile footprint)
	float outer_dist = sd_rounded_rect(pixel_pos, half_size, corner_radius);
	float outer_mask = aa_mask(outer_dist, edge_width * 2.0);

	// Inner rounded rectangle (where the glossy panel begins inside the bezel)
	float inner_dist = sd_rounded_rect(pixel_pos, half_size - vec2(bezel_width), max(corner_radius - bezel_width, 0.0));
	float inner_mask = aa_mask(inner_dist, edge_width * 2.0);

	// Chrome vertical gradient
	float grad = mix(0.25, 0.45, uv.y);
	vec3 chrome = mix(chrome_tint.rgb, vec3(grad), 0.45);

	// Bevel: top edge lighter, bottom edge darker (only in the bezel band)
	float top_factor = smoothstep(0.0, 1.0, 1.0 - uv.y);
	vec3 bevel = mix(
		mix(shadow_tint.rgb, chrome, 0.45),
		mix(highlight_tint.rgb, chrome, 0.55),
		top_factor
	);

	// Fake environment reflection diagonal sweep
	float env_diag = (uv.x + uv.y) * 0.5 + sin(time * 0.15) * 0.05;
	vec3 env_reflection = mix(env_tint_a.rgb, env_tint_b.rgb, env_diag) * 0.12;

	// Glossy plastic panel gradient (inner area)
	float panel_grad = mix(0.30, 0.18, uv.y);
	vec3 panel = mix(chrome_tint.rgb, vec3(panel_grad), 0.55) + env_reflection;

	// Neon edge glow (stronger on the outer rim)
	float edge = 1.0 - smoothstep(0.0, bezel_width * 3.0, outer_dist);
	vec3 glow = neon_color.rgb * border_glow * edge * 2.5;

	// Subtle sheen overlay across the panel
	float scan = sin((uv.y + time * 0.05) * 60.0) * 0.5 + 0.5;
	float sheen = reflection_amount * scan * (1.0 - edge);

	// Compose layers
	vec3 color = chrome;
	if (draw_outer_bezel) {
		// Blend bevel into the bezel band (inside outer, outside inner)
		color = mix(color, bevel, inner_mask * (1.0 - outer_mask));
	}
	color = mix(color, panel, 1.0 - inner_mask);
	color += glow + sheen;

	float alpha = 1.0 - outer_mask;

	COLOR = vec4(color, alpha);
}
