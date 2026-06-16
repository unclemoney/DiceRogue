shader_type canvas_item;
render_mode blend_add;

uniform float glow_intensity : hint_range(0.0, 2.0) = 0.15;
uniform vec4 glow_color : source_color = vec4(0.9, 0.35, 0.6, 1.0);
uniform float corner_radius : hint_range(0.0, 64.0) = 22.0;
uniform float spread : hint_range(0.0, 64.0) = 16.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.0;
uniform float time : hint_range(0.0, 100000.0) = 0.0;
uniform vec2 rect_size = vec2(224.0, 324.0);

// Signed distance field rounded rectangle in pixel space.
float sd_rounded_rect(vec2 p, vec2 half_size, float radius) {
	vec2 d = abs(p - half_size) - max(half_size - vec2(radius), vec2(0.0));
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	vec2 size = max(rect_size, vec2(1.0));
	vec2 half_size = size * 0.5;
	vec2 pixel_pos = UV * size;

	float dist = sd_rounded_rect(pixel_pos, half_size, max(corner_radius, 0.0));
	float outer_halo = 1.0 - smoothstep(0.0, spread, max(dist, 0.0));
	float rim = 1.0 - smoothstep(0.0, 5.0, abs(dist));
	float core = 1.0 - smoothstep(-4.0, 4.0, dist);
	float pulse = 1.0 + sin(time * 3.0) * 0.07 * pulse_strength;
	float alpha = (outer_halo * 0.72 + rim * 0.34 + core * 0.12) * glow_color.a * glow_intensity * pulse;

	COLOR = vec4(glow_color.rgb * alpha, alpha);
}
