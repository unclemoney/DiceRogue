shader_type canvas_item;
render_mode blend_add;

uniform float glow_intensity : hint_range(0.0, 2.0) = 0.15;
uniform vec4 glow_color : source_color = vec4(0.9, 0.35, 0.6, 1.0);
uniform float corner_radius : hint_range(0.0, 64.0) = 22.0;
uniform float spread : hint_range(0.0, 64.0) = 16.0;
uniform vec2 rect_size = vec2(160.0, 240.0);

// Signed distance field rounded rectangle in pixel space.
float sd_rounded_rect(vec2 p, vec2 half_size, float radius) {
	vec2 d = abs(p - half_size) - max(half_size - vec2(radius), vec2(0.0));
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	vec2 size = max(rect_size, vec2(1.0));
	vec2 half_size = size * 0.5;
	vec2 pixel_pos = UV * size;

	float radius = max(corner_radius + spread, 0.0);
	float dist = sd_rounded_rect(pixel_pos, half_size, radius);
	// Glow is strongest inside the shape and fades outward
	float alpha = (1.0 - smoothstep(0.0, spread, dist)) * glow_color.a * glow_intensity;

	COLOR = vec4(glow_color.rgb * alpha, alpha);
}
