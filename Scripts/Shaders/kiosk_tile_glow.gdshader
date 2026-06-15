shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 2.0) = 0.15;
uniform vec4 glow_color : source_color = vec4(0.9, 0.35, 0.6, 1.0);
uniform float corner_radius : hint_range(0.0, 64.0) = 22.0;
uniform float spread : hint_range(0.0, 64.0) = 16.0;

// Signed distance field rounded rectangle.
float sd_rounded_rect(vec2 uv, vec2 half_size, float radius) {
	vec2 d = abs(uv - vec2(0.5)) - (half_size - vec2(radius / min(half_size.x, half_size.y)));
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	vec2 size = vec2(1.0) / TEXTURE_PIXEL_SIZE;
	float min_side = min(size.x, size.y);
	float edge_width = 1.0 / min_side;

	float radius_pixels = max(corner_radius + spread, 1.0);
	float dist = sd_rounded_rect(UV, vec2(0.5), radius_pixels);
	// Glow is strongest inside the shape and fades outward
	float alpha = (1.0 - smoothstep(0.0, spread / min_side, dist)) * glow_color.a * glow_intensity;

	// Treat output as additive: pre-multiply so the standard blend mode
	// effectively adds light to the background.
	COLOR = vec4(glow_color.rgb * alpha, alpha);
}
