shader_type canvas_item;
render_mode blend_add;

uniform float glow_intensity : hint_range(0.0, 2.0) = 0.25;
uniform vec4 glow_color : source_color = vec4(0.9, 0.35, 0.6, 1.0);
uniform float circle_radius : hint_range(0.0, 256.0) = 80.0;
uniform float spread : hint_range(0.0, 64.0) = 16.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.0;
uniform float time : hint_range(0.0, 100000.0) = 0.0;
uniform vec2 rect_size = vec2(200.0, 200.0);

void fragment() {
	vec2 size = max(rect_size, vec2(1.0));
	vec2 pixel_pos = UV * size;
	float dist = length(pixel_pos - size * 0.5) - circle_radius;
	float outer_halo = (1.0 - smoothstep(0.0, spread, max(dist, 0.0))) * step(0.0, dist);
	float rim = 1.0 - smoothstep(0.0, 2.5, abs(dist));
	float pulse = 1.0 + sin(time * 3.0) * 0.07 * pulse_strength;
	float alpha = (outer_halo * 0.72 + rim * 0.34) * glow_color.a * glow_intensity * pulse;
	COLOR = vec4(glow_color.rgb * alpha, alpha);
}
