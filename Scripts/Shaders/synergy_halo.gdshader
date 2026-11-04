shader_type canvas_item;
render_mode blend_add;

// Active PowerUp synergy ring around the circular POG artwork.
// SET uses glow_color; RAINBOW cycles hue around the circumference.

uniform vec4 glow_color : source_color = vec4(1.0, 0.66, 0.35, 1.0);
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.9;
uniform float circle_radius : hint_range(0.0, 256.0) = 88.0;
uniform float spread : hint_range(0.0, 64.0) = 10.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.6;
uniform float rainbow_mode : hint_range(0.0, 1.0) = 0.0;
uniform float rainbow_speed : hint_range(0.0, 2.0) = 0.35;
uniform vec2 rect_size = vec2(200.0, 200.0);

vec3 hsv2rgb(vec3 c) {
	vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return c.z * mix(vec3(1.0), rgb, c.y);
}

void fragment() {
	vec2 size = max(rect_size, vec2(1.0));
	vec2 half_size = size * 0.5;
	vec2 pixel_pos = UV * size;
	vec2 from_center = pixel_pos - half_size;
	float dist = length(from_center) - circle_radius;
	float rim = 1.0 - smoothstep(0.0, 3.0, abs(dist));
	float outer = (1.0 - smoothstep(0.0, spread, max(dist, 0.0))) * step(0.0, dist);
	float inner = smoothstep(-6.0, 0.0, dist) * (1.0 - step(0.0, dist));
	float pulse = 1.0 + sin(TIME * 3.0) * 0.12 * pulse_strength;
	float angle = atan(from_center.y, from_center.x) / TAU;
	float hue = fract(angle + TIME * rainbow_speed);
	vec3 rainbow_rgb = hsv2rgb(vec3(hue, 0.85, 1.0));
	vec3 base_rgb = mix(glow_color.rgb, rainbow_rgb, rainbow_mode);
	float alpha = (rim * 0.8 + outer * 0.45 + inner * 0.25) * glow_color.a * glow_intensity * pulse;
	COLOR = vec4(base_rgb * alpha, alpha);
}
