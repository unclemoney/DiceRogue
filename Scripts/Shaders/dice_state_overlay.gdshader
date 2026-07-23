shader_type canvas_item;
render_mode unshaded;

uniform int overlay_mode : hint_range(0, 3) = 0;
uniform float overlay_strength : hint_range(0.0, 1.0) = 0.0;
uniform float hover_boost : hint_range(0.0, 1.0) = 0.0;

uniform vec4 locked_color : source_color = vec4(1.0, 0.84, 0.24, 1.0);
uniform vec4 lockout_color : source_color = vec4(1.0, 0.32, 0.18, 1.0);
uniform vec4 disabled_color : source_color = vec4(0.70, 0.78, 0.94, 1.0);
uniform float rim_thickness : hint_range(0.0, 0.2) = 0.02;
uniform float line_thickness : hint_range(0.0, 0.4) = 0.02;

float sd_circle(vec2 p, float radius) {
	return length(p) - radius;
}

float sd_line(vec2 p, vec2 a, vec2 b, float width) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - width;
}

float sd_rounded_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float sd_upper_ring(vec2 p, float radius, float thickness) {
	float d = abs(length(p) - radius) - thickness;
	if (p.y < 0.0) {
		d = 1e5;
	}
	return d;
}

float sd_outline(float d, float thickness) {
	return abs(d) - thickness;
}

float lock_glyph(vec2 p) {
	float post_width = line_thickness * 0.72;
	float body = sd_outline(sd_rounded_box(p - vec2(0.0, -0.22), vec2(0.30, 0.23), 0.10), line_thickness);
	float shackle = sd_upper_ring(p - vec2(0.0, 0.08), 0.28, rim_thickness);
	float left_post = sd_line(p, vec2(-0.22, 0.08), vec2(-0.22, -0.04), post_width);
	float right_post = sd_line(p, vec2(0.22, 0.08), vec2(0.22, -0.04), post_width);
	float keyhole_circle = sd_circle(p - vec2(0.0, -0.18), line_thickness * 0.55);
	float keyhole_stem = sd_line(p, vec2(0.0, -0.18), vec2(0.0, -0.32), line_thickness * 0.40);
	float keyhole = min(keyhole_circle, keyhole_stem);
	return min(body, min(keyhole, min(shackle, min(left_post, right_post))));
}

float lockout_glyph(vec2 p) {
	float ring = sd_outline(sd_circle(p, 0.56), rim_thickness);
	float slash = sd_line(p, vec2(-0.48, -0.48), vec2(0.48, 0.48), line_thickness * 0.90);
	return min(ring, slash);
}

float disabled_glyph(vec2 p) {
	float slash_width = line_thickness * 0.82;
	float slash_a = sd_line(p, vec2(-0.46, -0.46), vec2(0.46, 0.46), slash_width);
	float slash_b = sd_line(p, vec2(-0.46, 0.46), vec2(0.46, -0.46), slash_width);
	float center_bar = sd_line(p, vec2(-0.56, 0.0), vec2(0.56, 0.0), line_thickness * 0.55);
	return min(center_bar, min(slash_a, slash_b));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y *= -1.0;

	vec4 accent = locked_color;
	float glyph_dist = 1.0;
	float pulse_speed = 2.6;
	float active_overlay = 1.0;
	float line_softness = max(line_thickness, 0.001);
	float rim_softness = max(rim_thickness, 0.001);

	if (overlay_mode == 0 || overlay_strength <= 0.0) {
		active_overlay = 0.0;
	}

	if (overlay_mode == 1) {
		accent = locked_color;
		glyph_dist = lock_glyph(p);
		pulse_speed = 2.2;
	} else if (overlay_mode == 2) {
		accent = lockout_color;
		glyph_dist = lockout_glyph(p);
		pulse_speed = 3.8;
	} else {
		accent = disabled_color;
		glyph_dist = disabled_glyph(p);
		pulse_speed = 1.8;
	}

	float shell = sd_rounded_box(p, vec2(0.78, 0.78), 0.26);
	float rim = 1.0 - smoothstep(rim_softness, rim_softness + 0.07, abs(shell));
	float halo = 1.0 - smoothstep(0.0, 0.42, max(shell, 0.0));
	float glyph = 1.0 - smoothstep(line_softness * 0.30, line_softness * 0.85, glyph_dist);
	float pulse = 0.88 + 0.12 * sin(TIME * pulse_speed);
	float hover_scale = 1.0 + hover_boost * 0.18;

	float alpha = active_overlay * overlay_strength * pulse * ((halo * 0.24 + rim * 0.44) * hover_scale + glyph * 0.94);
	vec3 rgb = accent.rgb * ((halo * 0.38 + rim * 0.80) * hover_scale + glyph * 1.18);

	COLOR = vec4(rgb, clamp(alpha * accent.a, 0.0, 1.0));
}