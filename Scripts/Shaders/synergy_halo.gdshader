shader_type canvas_item;
render_mode blend_add;

// Synergy halo: rounded-rect SDF effect for active PowerUp synergies.
// Ring mode (fill_mode = 0): bright rim + outer glow for card borders.
// Fill mode (fill_mode = 1): soft translucent background fill that sits
// behind icons (compact slot backgrounds).
// Flat rating-color mode (rainbow_mode = 0) or animated hue-cycle
// rainbow mode (rainbow_mode = 1) for the Rainbow Bonus.

uniform vec4 glow_color : source_color = vec4(1.0, 0.66, 0.35, 1.0);
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.9;
uniform float corner_radius : hint_range(0.0, 64.0) = 16.0;
uniform float spread : hint_range(0.0, 64.0) = 10.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.6;
uniform float rainbow_mode : hint_range(0.0, 1.0) = 0.0;
uniform float rainbow_speed : hint_range(0.0, 2.0) = 0.35;
uniform float fill_mode : hint_range(0.0, 1.0) = 0.0;
uniform float fill_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec2 rect_size = vec2(88.0, 96.0);

// Signed distance field rounded rectangle in pixel space.
float sd_rounded_rect(vec2 p, vec2 half_size, float radius) {
	vec2 d = abs(p - half_size) - max(half_size - vec2(radius), vec2(0.0));
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

vec3 hsv2rgb(vec3 c) {
	vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return c.z * mix(vec3(1.0), rgb, c.y);
}

void fragment() {
	vec2 size = max(rect_size, vec2(1.0));
	vec2 half_size = size * 0.5;
	vec2 pixel_pos = UV * size;

	float dist = sd_rounded_rect(pixel_pos, half_size, max(corner_radius, 0.0));
	// Bright rim hugging the rect edge.
	float rim = 1.0 - smoothstep(0.0, 3.0, abs(dist));
	// Outer glow falls off outside the rect only.
	float outer = (1.0 - smoothstep(0.0, spread, max(dist, 0.0))) * step(0.0, dist);
	// Faint inner edge glow, so the effect reads as a ring, not a fill.
	float inner = smoothstep(-8.0, 0.0, dist) * (1.0 - step(0.0, dist));
	// Soft translucent fill of the whole rounded rect (background mode).
	float fill = smoothstep(2.0, -2.0, dist);
	float pulse = 1.0 + sin(TIME * 3.0) * 0.12 * pulse_strength;

	// Rainbow mode: hue cycles around the rect perimeter (ring) or over
	// time (fill).
	float angle = atan(pixel_pos.y - half_size.y, pixel_pos.x - half_size.x) / TAU;
	float hue = fract(mix(angle, 0.0, fill_mode) + TIME * rainbow_speed);
	vec3 rainbow_rgb = hsv2rgb(vec3(hue, 0.85, 1.0));
	vec3 base_rgb = mix(glow_color.rgb, rainbow_rgb, rainbow_mode);

	float ring_alpha = rim * 0.8 + outer * 0.45 + inner * 0.25;
	float alpha = mix(ring_alpha, fill * fill_strength, fill_mode) * glow_color.a * glow_intensity * pulse;

	COLOR = vec4(base_rgb * alpha, alpha);
}
